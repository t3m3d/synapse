/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Synapse start page address bar label.
//
// When the selected tab is showing the Synapse start page (the
// browser.newtab.url page), the address bar shows a friendly "Start
// Page" label instead of the URL.  The label is presentation-only:
// focusing the bar restores the real URL so it remains fully editable,
// and the identity box (padlock), security state, and history all
// continue to use the real location.

// prettier-ignore
// eslint-disable-next-line no-lone-blocks
{
  const LABEL = "Start Page";
  const PREF = "browser.newtab.url";
  let overridden = false;

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
    let spec = startPageSpec();
    // The newtab channel serves the Synapse start page while the
    // document URI stays about:newtab (where Firefox normally hides the
    // URL bar text), so count about:newtab as the start page too.
    console.error(
      "SynapseStartPage:trace",
      JSON.stringify({
        cur: currentSpec(),
        docURI: gBrowser?.selectedBrowser?.documentURI?.spec,
        value: gURLBar.value,
      })
    );
    let onStartPage =
      !!spec &&
      (currentSpec() === spec ||
        currentSpec() === "about:newtab" ||
        currentSpec() === "about:home");
    if (onStartPage && !gURLBar.focused) {
      overridden = true;
      gURLBar.value = LABEL;
      // Setting .value marks the bar as edited; restoring the page proxy
      // state keeps the identity glyph (padlock) and treats the bar as
      // showing the loaded page rather than a pending edit.
      gURLBar.setPageProxyState("valid", false);
    } else {
      showRealURL();
    }
  };

  let init = () => {
    if (!gURLBar || !gBrowser) {
      return;
    }

    // While the bar is focused the real URL is restored so the user can
    // edit / select it; the label is reapplied on blur.
    gURLBar.addEventListener("focus", showRealURL);
    gURLBar.addEventListener("blur", updateLabel);

    // Gecko's own startup and tab-switch code calls gURLBar.setURI after
    // the label was applied, which resets the bar text. Re-evaluate after
    // every setURI so the label is reasserted while the start page is
    // showing; when the user is editing, updateLabel is a no-op.
    let origSetURI = gURLBar.setURI;
    gURLBar.setURI = (options) => {
      origSetURI(options);
      updateLabel();
    };

    // Location changes (including simulated ones when switching tabs)
    // determine whether the label should be shown.
    gBrowser.addTabsProgressListener({
      onLocationChange() {
        // Skip while the user is composing in the bar; the label returns
        // on blur anyway.
        if (!gURLBar.focused) {
          updateLabel();
        }
      },
    });

    gBrowser.tabContainer.addEventListener("TabSelect", () => {
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
  };

  // gURLBar and gBrowser exist by the time the window finishes loading.
  window.addEventListener("load", () => init(), { once: true });
}
