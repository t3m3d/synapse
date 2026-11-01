/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Gecko owns session serialization and restoration. This small adapter only
// changes presentation: keep the complete crashed session in LastSession,
// open the configured homepage, and let browser chrome offer restoration.
let popupClaimed = false;

export function claimRecoveryPopup() {
  if (popupClaimed) {
    return false;
  }
  popupClaimed = true;
  return true;
}

export function prepareRecoveryPopup(state, startURL, principal) {
  if (typeof startURL !== "string" ||
      !/^(?:https?:\/\/|about:(?:home|newtab|blank)$)/i.test(startURL)) {
    return null;
  }
  // Never reinterpret an ordinary session, a private window, or multiple
  // visible tabs as a crash-recovery interstitial.
  if (state?.windows?.length !== 1) {
    return null;
  }
  const win = state.windows[0];
  const tab = win.tabs?.[0];
  const entry = tab?.entries?.[(tab.index || 1) - 1];
  if (win.isPrivate || win.tabs?.length !== 1 ||
      entry?.url !== "about:sessionrestore" ||
      tab.formdata?.url !== "about:sessionrestore") {
    return null;
  }
  let recovery = tab.formdata?.id?.sessionData;
  if (typeof recovery === "string") {
    try {
      recovery = JSON.parse(recovery);
    } catch {
      return null;
    }
  }
  if (!Array.isArray(recovery?.windows) || !recovery.windows.length ||
      !recovery.windows.every(w => Array.isArray(w.tabs) && w.tabs.length)) {
    // Leave Gecko's original recovery page intact if its payload is absent
    // or malformed. Never replace it with a fresh session in that case.
    return null;
  }
  return {
    recoveryState: { ...structuredClone(recovery), synapseRecoveryPending: true },
    startupState: {
      ...state,
      windows: [{
        ...win,
        selected: 1,
        tabs: [{
          entries: [{ url: startURL, triggeringPrincipal_base64: principal }],
          index: 1,
        }],
      }],
    },
  };
}

// A postponed crash recovery takes priority over the next ordinary deferred
// startup. Gecko still stores it in lastSessionState; no separate file or
// copied cookie database is introduced.
export function recoveryForDeferredStartup(state) {
  const pending = state?.lastSessionState;
  if (pending?.synapseRecoveryPending && Array.isArray(pending.windows) &&
      pending.windows.length) {
    return structuredClone(pending);
  }
  return prepareRecoveryPopup(state, "about:blank", "")?.recoveryState ?? state;
}
