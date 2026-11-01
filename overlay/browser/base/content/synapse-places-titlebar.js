/* SPDX-License-Identifier: MPL-2.0 */

/* The Library window keeps its native titlebar by default, which follows the
 * system appearance and stays light against Synapse's dark chrome: hiding the
 * separator only makes it transparent, revealing the window background.
 * Chrome ignores a static customtitlebar attribute during document init, so
 * add it after load.  The widget then draws content into the window frame and
 * chrome owns the titlebar strip, matching the main window.
 *
 * macOS paints the native traffic lights itself and offers no way to tint
 * them, so the window deliberately declares no -moz-window-button-box: with
 * content drawn into the frame and an empty button rect the widget moves the
 * native buttons off-window.  Synapse draws its own dark controls in their
 * place. */
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
    const hit = document.elementFromPoint(16, 12);
    trace(
      label + " customtitlebar=" + root.hasAttribute("customtitlebar") +
        " outer=" + window.outerHeight + " inner=" + window.innerHeight +
        " delta=" + (window.outerHeight - window.innerHeight) +
        " bg=" + cs.backgroundColor + " pad=" + cs.paddingTop +
        " tbBg=" + (toolbar ? getComputedStyle(toolbar).backgroundColor : "none") +
        " tbPad=" + (toolbar ? getComputedStyle(toolbar).paddingTop : "none") +
        " bb=" + (() => {
          const box = document.querySelector(".synapse-titlebar-buttons");
          return box ? JSON.stringify(box.getBoundingClientRect().toJSON()) : "none";
        })() +
        " hit=" + (hit ? hit.className || hit.localName : "none") +
        " win=" + window.windowState +
        " api=" + typeof window.minimize + "/" + typeof window.maximize +
        "/" + typeof window.restore +
        " nativeTheme=" + matchMedia("(-moz-native-theme)").matches +
        " forced=" + matchMedia("(forced-colors)").matches
    );
  };

  const addButton = (box, cls, label, action) => {
    const button = document.createXULElement("toolbarbutton");
    button.setAttribute("class", "synapse-titlebar-button " + cls);
    button.setAttribute("tooltiptext", label);
    button.setAttribute("aria-label", label);
    button.setAttribute("skipintoolbarset", "true");
    button.addEventListener("command", event => {
      event.stopPropagation();
      action();
    });
    box.appendChild(button);
  };

  /* The native buttons are gone, so recreate their three actions.  Close is
   * the window itself; minimize and zoom use the chrome window methods the
   * main window's own Mac menu commands call. */
  const createControls = toolbar => {
    if (toolbar.querySelector(".synapse-titlebar-buttons")) {
      return;
    }
    const box = document.createXULElement("hbox");
    box.setAttribute("class", "synapse-titlebar-buttons");
    box.setAttribute("skipintoolbarset", "true");

    addButton(box, "synapse-close", "Close", () => window.close());
    addButton(box, "synapse-minimize", "Minimize", () => window.minimize());
    addButton(box, "synapse-zoom", "Zoom", () => {
      if (window.windowState === window.STATE_MAXIMIZED) {
        window.restore();
      } else {
        window.maximize();
      }
    });

    toolbar.append(box);
  };

  const enable = () => {
    if (!root || root.id !== "places") {
      return;
    }
    measure("before");
    const toolbar = document.getElementById("placesToolbar");
    if (toolbar) {
      createControls(toolbar);
    }

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
