/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Synapse start page address bar label.
//
// When the selected tab is showing the Synapse start page (the
// browser.newtab.url page), the address bar shows a "Start Page" label
// instead of the URL.  The label is presentation-only: focusing the bar
// restores the real URL so it remains fully editable, and the identity box
// (padlock), security state, and history all continue to use the real
// location.

// prettier-ignore
// eslint-disable-next-line no-lone-blocks
{
  // Text shown in the bar while the start page is displayed.  The real URL
  // returns as soon as the user touches the bar, so this stays a label rather
  // than a fake address.
  const DISPLAY_TEXT = "Start Page";
  const PREF = "browser.newtab.url";
  let overridden = false;

  // Temporary diagnostics: set browser.synapse.debugStartpage=true in a
  // user.js to emit the display decision trail via dump() (stderr).
  let trace = (message) => {
    try {
      if (Services.prefs.getBoolPref("browser.synapse.debugStartpage", false)) {
        dump("SynapseStartPage: " + message + "\n");
      }
    } catch (e) {}
  };

  // Firefox auto-focuses the URL bar on the first tab at startup
  // (_setInitialFocus calls gURLBar.select() for blank/newtab pages), and
  // that focus is not a user action.  Treat focus as editing only after
  // the user has actually made contact: a focus that was user-caused, a
  // keydown, or a mouse press.  The window interaction tracker is what
  // tells those apart: mayHaveInteract() is false until the user performs
  // a real input action in this window, and the synthetic startup focus
  // never sets it.
  let userTouched = false;

  let realUserContact = () => {
    try {
      return window.windowUtils?.mayHaveInteract ?? false;
    } catch (e) {
      // If the interaction API is unavailable, err on the side of the
      // previous behavior and treat focus as user contact, so editing
      // always restores the real URL.
      return true;
    }
  };

  let startPageSpec = () => {
    let startPage = Services.prefs.getStringPref(PREF, "about:newtab").trim();
    if (!startPage || startPage === "about:newtab") {
      // No Synapse start page configured; show real URLs as usual.
      return null;
    }
    // Normalize so a trailing slash in the pref doesn't break matching.
    try {
      return Services.io.newURI(startPage).spec.replace(/\/$/, "");
    } catch (e) {
      return null;
    }
  };

  let currentSpec = () => {
    let uri = gBrowser?.selectedBrowser?.currentURI;
    if (!uri) {
      return null;
    }
    try {
      return Services.io.newURI(uri.spec).spec.replace(/\/$/, "");
    } catch (e) {
      return null;
    }
  };

  let showRealURL = () => {
    if (!gURLBar || !overridden) {
      return;
    }
    overridden = false;
    let uri = gBrowser?.selectedBrowser?.currentURI;
    if (uri) {
      gURLBar.setURI({ uri, isSameDocument: true });
    }
  };

  let updateLabel = () => {
    if (!gURLBar || !gBrowser) {
      return;
    }
    try {
    let spec = startPageSpec();
    // The newtab channel serves the Synapse start page while the
    // document URI stays about:newtab (where Firefox normally hides the
    // URL bar text), so count about:newtab as the start page too.
    let keystep = currentSpec();
    let onStart =
      !!spec &&
      (keystep === spec ||
        keystep === "about:newtab" ||
        keystep === "about:home");
    trace(
      "updateLabel spec=" + spec + " cur=" + keystep + " focused=" +
        gURLBar.focused + " touched=" + userTouched + " overridden=" +
        overridden + " value=" + JSON.stringify(gURLBar.value)
    );
    // While the user is editing (bar focused after a user action), the
    // real URL is shown.  The synthetic startup focus is excluded: apply
    // the override there too, so the first tab isn't left showing a URL.
    if (onStart && (!gURLBar.focused || !userTouched)) {
      overridden = true;
      gURLBar.value = DISPLAY_TEXT;
      // Setting .value marks the bar as edited; restoring the page proxy
      // state keeps the identity glyph (padlock) and treats the bar as
      // showing the loaded page rather than a pending edit.
      gURLBar.setPageProxyState("valid", false);
      // A location change may have left the bar flagged as user-typed, which
      // suppresses the placeholder and leaves a blank strip instead of the
      // "Search or enter web address" prompt. The value here is ours, not typed.
      gURLBar.removeAttribute("usertyping");
      trace(
        "override proxystate=" + gURLBar.getAttribute("pageproxystate") +
          " usertyping=" + gURLBar.hasAttribute("usertyping") +
          " value=" + JSON.stringify(gURLBar.value)
      );
    } else {
      showRealURL();
    }
    trace("updateLabel done overridden=" + overridden + " value=" + JSON.stringify(gURLBar.value));
    } catch (e) {
      // Never let a transient chrome error abort a startup sweep or
      // progress-listener call chain.
      trace("updateLabel error " + e);
    }
  };

  let init = () => {
    trace("init start gURLBar=" + (gURLBar ? "yes" : "no") + " gBrowser=" + (gBrowser ? "yes" : "no"));
    if (!gURLBar || !gBrowser) {
      return;
    }

    // While the bar is focused the real URL is restored so the user can
    // edit / select it; the label is reapplied on blur.
    gURLBar.addEventListener("focus", () => {
      userTouched = realUserContact();
      trace("focus event touched=" + userTouched + " value=" + JSON.stringify(gURLBar.value));
      if (userTouched) {
        showRealURL();
      } else {
        // Synthetic startup focus: the user has not touched anything yet,
        // so keep the URL hidden while the start page is showing instead of
        // leaving the real URL in place until the user opens another tab.
        updateLabel();
      }
    });
    gURLBar.addEventListener("blur", () => {
      trace("blur event");
      updateLabel();
    });

    // A mouse press in the bar is always real contact: restore the real
    // URL so clicking into the bar for editing shows what is editable.
    gURLBar.addEventListener("mousedown", () => {
      userTouched = true;
      if (overridden) {
        showRealURL();
      }
    });

    // A keydown is real editing contact: restore the real URL before the
    // keystroke lands.  Printable characters are reapplied after the
    // restore so typing right after launch picks the URL up cleanly.
    gURLBar.addEventListener("keydown", (event) => {
      userTouched = true;
      if (!overridden) {
        return;
      }
      showRealURL();
      if (
        event.key.length === 1 &&
        !event.ctrlKey &&
        !event.metaKey &&
        !event.altKey
      ) {
        event.preventDefault();
        let restored = gURLBar.value || "";
        gURLBar.value = restored + event.key;
        let inputField = gURLBar.inputField;
        try {
          inputField.setSelectionRange(
            gURLBar.value.length,
            gURLBar.value.length
          );
        } catch (e) {
          // Selection side effects are cosmetic; ignore failures.
        }
      }
      // Editing keys (Backspace, Delete, arrows, Enter) land on the
      // restored URL and do not need extra handling.
    });

    // Gecko's own startup and tab-switch code calls gURLBar.setURI after
    // the label was applied, which resets the bar text. Re-evaluate after
    // every setURI so the label is reasserted while the start page is
    // showing; when the user is editing, updateLabel is a no-op.
    let origSetURI = gURLBar.setURI;
    gURLBar.setURI = (options = {}) => {
      // Preserve the receiver: a plain call on the extracted method leaves
      // `this` undefined inside setURI, whose private-field access then
      // throws ("can't convert undefined to object") for every caller,
      // including Gecko's own onStateChange/onLocationChange paths.
      origSetURI.call(gURLBar, options);
      updateLabel();
    };

    // Location changes (including simulated ones when switching tabs)
    // determine whether the label should be shown.
    gBrowser.addTabsProgressListener({
      onLocationChange() {
        trace("onLocationChange");
        // Skip while the user is composing in the bar; the label returns
        // on blur anyway.
        if (!gURLBar.focused || !userTouched) {
          updateLabel();
        }
      },
    });

    gBrowser.tabContainer.addEventListener("TabSelect", () => {
      trace("TabSelect focused=" + gURLBar.focused + " touched=" + userTouched);
      // The bar keeps focus across tab switches; when it is focused,
      // first restore the newly selected tab's URL, then decide on a
      // fresh label.
      if (gURLBar.focused) {
        overridden = false;
        let uri = gBrowser.selectedBrowser?.currentURI;
        if (uri) {
          gURLBar.setURI({ uri, isSameDocument: true });
        }
      }
      updateLabel();
    });

    // Never leak the label into session-restore or crash-restore paths
    // that may read the visible URL bar contents.
    window.addEventListener("beforeunload", showRealURL);

    updateLabel();
    trace("init done overridden=" + overridden + " value=" + JSON.stringify(gURLBar?.value));

    // The initial tab swaps the about:blank placeholder for the start page
    // without firing location-change progress events by the time init runs,
    // so Gecko-side events can never assert this first-tab label. A short
    // startup sweep re-attempts once the initial tab settles (about:blank
    // -> start page) and stops at the first real user interaction, or at
    // the sweep budget (60s).  Tab switches and
    // later navigations are covered by the normal listeners above.
    let sweeps = 0;
    let settledTicks = 0;
    let startupSweep = () => {
      if (window.closed) {
        return;
      }
      // Schedule the next tick before doing any work: an exception in an
      // updateLabel/setURI chain must not kill the sweep loop, otherwise
      // the first-tab label is lost whenever the start page loads slowly.
      sweeps++;
      if (sweeps < 240 && settledTicks < 3) {
        setTimeout(startupSweep, 250);
      }
      let sweepSpec = currentSpec();
      let stillWaiting =
        (!sweepSpec || sweepSpec === "about:blank") &&
        !userTouched &&
        !overridden;
      // Stop the sweep shortly after the first tab has settled (label
      // asserted or page committed); further fixes come from listeners.
      settledTicks = stillWaiting ? 0 : settledTicks + 1;
      let selectedTab = gBrowser?.selectedTab;
      let selectedBrowser = gBrowser?.selectedBrowser;
      if (sweepSpec !== "about:blank" || userTouched || overridden) {
        updateLabel();
      }
      trace(
        "startupSweep " +
          sweeps +
          " cur=" + sweepSpec +
          " doc=" + (selectedBrowser?.documentURI?.spec ?? "none") +
          " tabIndex=" + gBrowser.tabs?.indexOf?.(selectedTab) +
          " label=" + JSON.stringify(selectedTab?.label) +
          " remote=" + selectedBrowser?.isRemoteBrowser +
          " tabs=" + (() => { try { return JSON.stringify((gBrowser.tabs ?? []).map(t => (t.linkedBrowser?.currentURI?.spec ?? "?") + "|" + t.label)); } catch (e) { return "<unavailable>"; } })() +
          " stillWaiting=" + stillWaiting
      );
    };
    setTimeout(startupSweep, 250);
  };

  // gURLBar and gBrowser exist by the time the window finishes loading.
  window.addEventListener("load", () => init(), { once: true });
}

// Present crash recovery in trusted browser chrome, never in the hosted start
// page. "Not now" and Escape leave LastSession untouched, including cookies,
// tabs, and additional windows; History > Restore Previous Session still works.
window.addEventListener("load", async () => {
  if (!Services.prefs.getBoolPref("browser.synapse.sessionRestorePopup", false)) {
    return;
  }
  try {
    const { SessionStore } = ChromeUtils.importESModule(
      "moz-src:///browser/components/sessionstore/SessionStore.sys.mjs"
    );
    await SessionStore.promiseAllWindowsRestored;
    if (window.closed || !SessionStore.canRestoreLastSession ||
        !SessionStore.synapseRecoveryPending ||
        PrivateBrowsingUtils.isWindowPrivate(window)) {
      return;
    }
    const { claimRecoveryPopup } = ChromeUtils.importESModule(
      "resource:///modules/SynapseSessionRecovery.sys.mjs"
    );
    if (!claimRecoveryPopup()) {
      return;
    }
    // Let the first browser window paint before opening a nonblocking sheet.
    await new Promise(resolve => window.requestAnimationFrame(() =>
      window.requestAnimationFrame(resolve)));
    if (window.closed) {
      return;
    }
    const flags =
      Services.prompt.BUTTON_TITLE_IS_STRING * Services.prompt.BUTTON_POS_0 +
      Services.prompt.BUTTON_TITLE_IS_STRING * Services.prompt.BUTTON_POS_1 +
      Services.prompt.BUTTON_POS_1_DEFAULT;
    const result = await Services.prompt.asyncConfirmEx(
      window.browsingContext,
      Services.prompt.MODAL_TYPE_INTERNAL_WINDOW,
      "Restore previous session?",
      "Your previous tabs and windows are still saved. Restore them now, or keep browsing from your start page. You can restore them later from History > Restore Previous Session.",
      flags,
      "Restore session",
      "Not now",
      null,
      null,
      false
    );
    if (result.QueryInterface(Ci.nsIPropertyBag2).get("buttonNumClicked") === 0 &&
        SessionStore.canRestoreLastSession) {
      SessionStore.restoreLastSession();
    }
  } catch (error) {
    // SessionStore retains recovery data if the prompt cannot be displayed.
    console.error("Synapse recovery prompt unavailable", error);
  }
}, { once: true });
