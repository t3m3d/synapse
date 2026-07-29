"use strict";

browser.runtime.sendMessage("synapse:ping").then(response => {
  const status = document.querySelector("#status");
  status.textContent = response?.ok
    ? "Synapse compatibility probe passed."
    : "No response from the extension runtime.";
});
