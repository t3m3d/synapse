/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

export const PREF = "browser.synapse.adaptiveDarkMode";
let registered = false;

export function installAdaptiveDarkMode(window) {
  if (!registered) {
    ChromeUtils.registerWindowActor("SynapseAdaptiveDarkMode", {
      child: {
        esModuleURI: "resource:///modules/SynapseAdaptiveDarkModeChild.sys.mjs",
        events: {
          DOMContentLoaded: { mozSystemGroup: true },
          pageshow: { mozSystemGroup: true },
        },
      },
      matches: ["http://*/*", "https://*/*"],
      // The child reads page styles and never sends data to the parent.
      safeForUntrustedWebProcess: true,
    });
    registered = true;
  }

  if (window.document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", () => installMenu(window), {
      once: true,
    });
  } else {
    installMenu(window);
  }
}

function installMenu(window) {
  const menu = window.document.getElementById("menu_viewPopup");
  if (!menu) {
    return;
  }
  const item = window.document.createXULElement("menuitem");
  item.id = "synapse-adaptive-dark-mode";
  item.setAttribute("label", "Adaptive Dark Mode");
  item.setAttribute("type", "checkbox");
  menu.appendChild(item);
  menu.addEventListener("popupshowing", event => {
    if (event.target === menu) {
      item.setAttribute("checked", Services.prefs.getBoolPref(PREF, false));
    }
  });
  item.addEventListener("command", () => {
    Services.prefs.setBoolPref(PREF, item.getAttribute("checked") === "true");
  });
}
