"use strict";

browser.runtime.onInstalled.addListener(async () => {
  await browser.storage.local.set({
    synapseCompatibilityProbe: "installed"
  });
});

browser.runtime.onMessage.addListener(message => {
  if (message === "synapse:ping") {
    return Promise.resolve({
      ok: true,
      runtime: "firefox-webextension"
    });
  }
  return false;
});
