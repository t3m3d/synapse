/* SPDX-License-Identifier: MPL-2.0 */

/* The Library window keeps its native titlebar by default, which follows the
 * system appearance and stays light against Synapse's dark chrome: hiding the
 * separator only makes it transparent, revealing the window background.
 * Chrome ignores a static customtitlebar attribute during document init, so
 * add it after load.  The widget then draws content into the window frame and
 * chrome owns the titlebar strip, matching the main window. */
{
  const root = document.documentElement;

  const trace = message => {
    try {
      if (Services.prefs.getBoolPref("browser.synapse.debugStartpage", false)) {
        dump("SynapsePlacesTitlebar: " + message + "\n");
      }
    } catch (e) {}
  };

  const measure = label => {
    const cs = getComputedStyle(root);
    const toolbar = document.getElementById("placesToolbar");
    trace(
      label + " customtitlebar=" + root.hasAttribute("customtitlebar") +
        " outer=" + window.outerHeight + " inner=" + window.innerHeight +
        " delta=" + (window.outerHeight - window.innerHeight) +
        " bg=" + cs.backgroundColor + " pad=" + cs.paddingTop +
        " tbBg=" + (toolbar ? getComputedStyle(toolbar).backgroundColor : "none") +
        " tbPad=" + (toolbar ? getComputedStyle(toolbar).paddingTop : "none") +
        " nativeTheme=" + matchMedia("(-moz-native-theme)").matches +
        " forced=" + matchMedia("(forced-colors)").matches
    );
  };

  const enable = () => {
    if (!root || root.id !== "places") {
      return;
    }
    measure("before");
    root.setAttribute("customtitlebar", "true");
    // Setting customtitlebar resizes the frame but does not, on its own,
    // recompute whether the native titlebar is transparent. Re-asserting the
    // separator runs the widget's transparency update, which hides the native
    // titlebar so the chrome strip below is what draws.
    setTimeout(() => {
      root.removeAttribute("hidetitlebarseparator");
      root.setAttribute("hidetitlebarseparator", "true");
      measure("after-separator");
    }, 0);
    setTimeout(() => measure("after"), 700);
  };

  if (document.readyState === "complete") {
    enable();
  } else {
    window.addEventListener("load", enable, { once: true });
  }
}
