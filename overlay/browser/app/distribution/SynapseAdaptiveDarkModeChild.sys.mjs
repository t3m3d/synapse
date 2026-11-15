/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import { PREF } from "./SynapseAdaptiveDarkMode.sys.mjs";

// A document-level user sheet keeps the DOM intact. Restore the colors of
// photos, video, canvas and embedded documents with the inverse filter.
const MEDIA = ":is(img, video, canvas, iframe, object, embed)";
const SHEET = "data:text/css," + encodeURIComponent(`
  @media screen and (prefers-color-scheme: dark) and (forced-colors: none) {
    :root { filter: invert(1) hue-rotate(180deg) !important; }
    ${MEDIA}:not(${MEDIA} *) {
      filter: hue-rotate(-180deg) invert(1) !important;
    }
  }
`);

function luminance(color) {
  // Gecko serializes ordinary computed sRGB colors as rgb()/rgba().
  const match = /^rgba?\((\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)(?:,\s*([\d.]+))?\)$/.exec(color);
  if (!match || (match[4] !== undefined && Number(match[4]) < 0.9)) {
    return null;
  }
  const [red, green, blue] = match.slice(1, 4).map(channel => {
    const srgb = Number(channel) / 255;
    return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

export function shouldAdapt(window) {
  const { document } = window;
  const root = document.documentElement;
  if (!root || !document.body || document.contentType !== "text/html" ||
      document.mozSyntheticDocument || document.designMode === "on") {
    return false;
  }
  const rootStyle = window.getComputedStyle(root);
  const colorScheme = document.querySelector('meta[name="color-scheme" i]')?.content ?? "";
  if (/\bdark\b/i.test(rootStyle.colorScheme + " " + colorScheme) ||
      rootStyle.filter !== "none" || window.matchMedia("(forced-colors: active)").matches) {
    return false;
  }

  // Sample the visible page to recognize dark layouts whose body is transparent.
  // Use the body's canvas color as the fallback for unpainted viewport samples.
  const bodyStyle = window.getComputedStyle(document.body);
  const canvas = luminance(bodyStyle.backgroundColor) ?? luminance(rootStyle.backgroundColor) ?? 1;
  let bright = 0;
  for (const [x, y] of [[0.5, 0.2], [0.25, 0.5], [0.5, 0.5], [0.75, 0.5], [0.5, 0.8]]) {
    let level = null;
    let node = document.elementFromPoint(window.innerWidth * x, window.innerHeight * y);
    for (let depth = 0; node && depth < 16 && level === null; depth++, node = node.parentElement) {
      level = luminance(window.getComputedStyle(node).backgroundColor);
    }
    if ((level ?? canvas) > 0.32) {
      bright++;
    }
  }
  return bright >= 3;
}

export class SynapseAdaptiveDarkModeChild extends JSWindowActorChild {
  #dark;
  #forcedColors;
  #observer;
  #frame = null;
  #active = false;

  handleEvent(event) {
    const win = this.contentWindow;
    const document = this.document;
    if (!win || !document || event.target !== document || document.contentType !== "text/html" ||
        document.mozSyntheticDocument) {
      return;
    }
    if (!this.#dark) {
      this.#dark = win.matchMedia("(prefers-color-scheme: dark)");
      this.#forcedColors = win.matchMedia("(forced-colors: active)");
      this.#dark.addEventListener("change", this.#schedule);
      this.#forcedColors.addEventListener("change", this.#schedule);
      Services.prefs.addObserver(PREF, this.#schedule);
    }
    this.#schedule();
  }

  #schedule = () => {
    const win = this.contentWindow;
    if (!win || this.#frame !== null) {
      return;
    }
    this.#frame = win.requestAnimationFrame(() => {
      this.#frame = null;
      this.#update(win);
    });
  };

  #update(win) {
    this.#observer?.disconnect();
    this.#removeSheet(win);
    if (!Services.prefs.getBoolPref(PREF, false) || !this.#dark.matches || this.#forcedColors.matches) {
      return;
    }
    if (shouldAdapt(win)) {
      win.windowUtils.loadSheetUsingURIString(SHEET, Ci.nsIDOMWindowUtils.USER_SHEET);
      this.#active = true;
    }
    // Watch common website theme switches without observing every DOM mutation.
    this.#observer ??= new win.MutationObserver(this.#schedule);
    const attributes = { attributes: true, attributeFilter: ["class", "style", "data-theme", "data-color-mode"] };
    this.#observer.observe(this.document.documentElement, attributes);
    if (this.document.body) {
      this.#observer.observe(this.document.body, attributes);
    }
  }

  #removeSheet(win) {
    if (this.#active) {
      win.windowUtils.removeSheetUsingURIString(SHEET, Ci.nsIDOMWindowUtils.USER_SHEET);
      this.#active = false;
    }
  }

  didDestroy() {
    if (!this.#dark) {
      return;
    }
    Services.prefs.removeObserver(PREF, this.#schedule);
    this.#dark.removeEventListener("change", this.#schedule);
    this.#forcedColors.removeEventListener("change", this.#schedule);
    this.#observer?.disconnect();
    const win = this.contentWindow;
    if (win && this.#frame !== null) {
      win.cancelAnimationFrame(this.#frame);
    }
    if (win) {
      this.#removeSheet(win);
    }
  }
}
