import assert from "node:assert/strict";

globalThis.JSWindowActorChild = class {};
globalThis.Ci = { nsIDOMWindowUtils: { USER_SHEET: 1 } };
const { PREF, installAdaptiveDarkMode } = await import(
  "../overlay/browser/app/distribution/SynapseAdaptiveDarkMode.sys.mjs"
);
const { shouldAdapt, SynapseAdaptiveDarkModeChild } = await import(
  "../overlay/browser/app/distribution/SynapseAdaptiveDarkModeChild.sys.mjs"
);

function page({ background = "rgb(255, 255, 255)", scheme = "normal", meta, panels = [] } = {}) {
  const root = { style: { backgroundColor: "rgba(0, 0, 0, 0)", colorScheme: scheme, filter: "none" } };
  const body = { style: { backgroundColor: background }, parentElement: root };
  let sample = 0;
  const document = {
    documentElement: root,
    body,
    contentType: "text/html",
    querySelector: () => meta && { content: meta },
    elementFromPoint: () => {
      const color = panels[(sample++) % 5];
      return color ? { style: { backgroundColor: color }, parentElement: body } : body;
    },
  };
  return {
    document, innerWidth: 800, innerHeight: 600,
    getComputedStyle: element => element.style,
    matchMedia: () => ({ matches: false }),
  };
}

assert.equal(shouldAdapt(page()), true);
assert.equal(shouldAdapt(page({ background: "rgb(18, 18, 18)" })), false);
assert.equal(shouldAdapt(page({ scheme: "light dark" })), false);
assert.equal(shouldAdapt(page({ meta: "light dark" })), false);
assert.equal(shouldAdapt(page({ panels: ["rgb(18, 18, 18)", "rgb(18, 18, 18)", "rgb(18, 18, 18)"] })), false);
assert.equal(shouldAdapt(page({ background: "rgba(0, 0, 0, 0)" })), true);
const image = page();
image.document.mozSyntheticDocument = true;
assert.equal(shouldAdapt(image), false);

let enabled = false;
let prefObserver;
globalThis.Services = {
  prefs: {
    getBoolPref: key => (assert.equal(key, PREF), enabled),
    addObserver: (key, observer) => { prefObserver = observer; },
    removeObserver: () => { prefObserver = undefined; },
  },
};
const loaded = new Set();
const win = page();
const dark = new EventTarget();
dark.matches = true;
const forced = new EventTarget();
forced.matches = false;
win.matchMedia = query => query.includes("forced-colors") ? forced : dark;
win.MutationObserver = class { observe() {} disconnect() {} };
win.requestAnimationFrame = callback => setImmediate(callback);
win.cancelAnimationFrame = clearImmediate;
win.windowUtils = {
  loadSheetUsingURIString(sheet, type) {
    assert.equal(type, 1);
    assert.match(decodeURIComponent(sheet), /img, video, canvas, iframe/);
    assert.equal(loaded.has(sheet), false);
    loaded.add(sheet);
  },
  removeSheetUsingURIString: sheet => assert.equal(loaded.delete(sheet), true),
};

const actor = new SynapseAdaptiveDarkModeChild();
actor.contentWindow = win;
actor.document = win.document;
const paint = () => new Promise(resolve => setImmediate(resolve));
actor.handleEvent({ target: win.document });
await paint();
assert.equal(loaded.size, 0, "opt-in defaults to off");
enabled = true;
prefObserver();
await paint();
assert.equal(loaded.size, 1, "bright site and dark appearance");
forced.matches = true;
forced.dispatchEvent(new Event("change"));
await paint();
assert.equal(loaded.size, 0, "forced colors take priority");
forced.matches = false;
forced.dispatchEvent(new Event("change"));
await paint();
assert.equal(loaded.size, 1, "adapts again after forced colors end");
dark.matches = false;
dark.dispatchEvent(new Event("change"));
await paint();
assert.equal(loaded.size, 0, "switching to light appearance restores the original");
dark.matches = true;
dark.dispatchEvent(new Event("change"));
await paint();
assert.equal(loaded.size, 1);
actor.didDestroy();
assert.equal(loaded.size, 0);
assert.equal(prefObserver, undefined);

const menus = [];
let registrations = 0;
globalThis.ChromeUtils = {
  registerWindowActor(name, options) {
    assert.equal(name, "SynapseAdaptiveDarkMode");
    assert.deepEqual(options.matches, ["http://*/*", "https://*/*"]);
    registrations++;
  },
};
for (let i = 0; i < 2; i++) {
  const menu = new EventTarget();
  menu.appendChild = item => menus.push(item);
  installAdaptiveDarkMode({
    document: {
      getElementById: () => menu,
      createXULElement: () => Object.assign(new EventTarget(), { setAttribute() {} }),
    },
  });
}
const loadingWindow = new EventTarget();
loadingWindow.document = {
  readyState: "loading",
  getElementById: () => Object.assign(new EventTarget(), {
    appendChild: item => menus.push(item),
  }),
  createXULElement: () => Object.assign(new EventTarget(), { setAttribute() {} }),
};
installAdaptiveDarkMode(loadingWindow);
assert.equal(menus.length, 2, "menu installation waits for document parsing");
loadingWindow.dispatchEvent(new Event("DOMContentLoaded"));
assert.equal(registrations, 1, "one registration across browser windows");
assert.equal(menus.length, 3, "each browser window gets a menu item");
console.log("Adaptive Dark Mode checks passed.");
