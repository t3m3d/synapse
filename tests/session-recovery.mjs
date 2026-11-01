// Run with Node.js. Exercises the pure Gecko adapter and actual chrome prompt
// callback without launching or touching any personal browser profile.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import { prepareRecoveryPopup, claimRecoveryPopup, recoveryForDeferredStartup } from '../overlay/browser/modules/SynapseSessionRecovery.sys.mjs';

const previous = {
  version: ['sessionrestore', 1],
  windows: [
    { tabs: [{ entries: [{ url: 'about:robots' }] }], selected: 1 },
    { tabs: [{ entries: [{ url: 'about:mozilla' }] }], selected: 1 },
  ],
  cookies: [{ name: 'test-session', value: 'retained' }],
};
const wrapper = data => ({ windows: [{
  screenX: 100, tabs: [{ entries: [{ url: 'about:sessionrestore' }], index: 1,
    formdata: { url: 'about:sessionrestore', id: { sessionData: data } } }],
}] });
let passed = 0;
function check(name, callback) { callback(); passed++; console.log('PASS', name); }
check('ordinary sessions remain unchanged', () => assert.equal(prepareRecoveryPopup(previous, 'https://krypton-lang.org/s.html', 'principal'), null));
check('recovery opens actual start page and retains all windows and cookies', () => {
  const original = wrapper(previous), snapshot = structuredClone(original);
  const result = prepareRecoveryPopup(original, 'https://krypton-lang.org/s.html', 'principal');
  assert.deepEqual(result.recoveryState, { ...previous, synapseRecoveryPending: true });
  assert.equal(result.startupState.windows[0].tabs[0].entries[0].url, 'https://krypton-lang.org/s.html');
  assert.equal(result.startupState.windows[0].screenX, 100);
  result.recoveryState.windows[0].tabs.pop();
  assert.deepEqual(original, snapshot);
});
check('serialized recovery payload supported', () => assert.deepEqual(prepareRecoveryPopup(wrapper(JSON.stringify(previous)), 'about:home', 'p').recoveryState, { ...previous, synapseRecoveryPending: true }));
check('invalid JSON keeps recovery page intact', () => assert.equal(prepareRecoveryPopup(wrapper('{'), 'about:home', 'p'), null));
check('missing payload keeps recovery page intact', () => assert.equal(prepareRecoveryPopup(wrapper(undefined), 'about:home', 'p'), null));
check('empty recovery keeps recovery page intact', () => assert.equal(prepareRecoveryPopup(wrapper({ windows: [] }), 'about:home', 'p'), null));
check('multiple visible tabs are not replaced', () => { const s=wrapper(previous);s.windows[0].tabs.push({entries:[{url:'about:blank'}]});assert.equal(prepareRecoveryPopup(s,'about:home','p'),null); });
check('private recovery not converted', () => { const s=wrapper(previous);s.windows[0].isPrivate=true;assert.equal(prepareRecoveryPopup(s,'about:home','p'),null); });
check('unsafe startup URL rejected', () => assert.equal(prepareRecoveryPopup(wrapper(previous), 'javascript:alert(1)', 'p'), null));
check('I2P console homepage preserved', () => assert.equal(prepareRecoveryPopup(wrapper(previous), 'http://127.0.0.1:7657', 'p').startupState.windows[0].tabs[0].entries[0].url, 'http://127.0.0.1:7657'));
check('explicit blank homepage respected', () => assert.equal(prepareRecoveryPopup(wrapper(previous), 'about:blank', 'p').startupState.windows[0].tabs[0].entries[0].url, 'about:blank'));
check('popup claimed only once per app process', () => { assert.equal(claimRecoveryPopup(), true);assert.equal(claimRecoveryPopup(), false); });

const chrome = await readFile(new URL('../overlay/browser/base/content/browser-synapse-startpage.js', import.meta.url), 'utf8');
async function promptScenario(choice, { recoverable = true, privateWindow = false } = {}) {
  const loads=[];let restored=0,prompts=0,claims=0;
  const store={promiseAllWindowsRestored:Promise.resolve(),canRestoreLastSession:recoverable,synapseRecoveryPending:true,restoreLastSession(){restored++}};
  const context={
    window:{addEventListener(type,fn){if(type==='load')loads.push(fn)},closed:false,requestAnimationFrame(fn){fn()},browsingContext:{}},
    Services:{prefs:{getBoolPref(){return true}},prompt:{
      BUTTON_TITLE_IS_STRING:127,BUTTON_POS_0:1,BUTTON_POS_1:256,BUTTON_POS_1_DEFAULT:16777216,MODAL_TYPE_INTERNAL_WINDOW:3,
      async asyncConfirmEx(){prompts++;return{QueryInterface(){return{get(){return choice}}}}},
    }},
    ChromeUtils:{importESModule(uri){return uri.includes('SessionStore.')?{SessionStore:store}:{claimRecoveryPopup(){claims++;return true}}}},
    PrivateBrowsingUtils:{isWindowPrivate(){return privateWindow}},Ci:{nsIPropertyBag2:{}},console,
  };
  vm.runInNewContext(chrome,context);
  await loads.at(-1)();
  return {restored,prompts,claims,canRestore:store.canRestoreLastSession};
}
for(const [name,choice,opts,expected] of [
  ['Not now retains pending recovery',1,{}, {restored:0,prompts:1,claims:1,canRestore:true}],
  ['Restore delegates to Gecko',0,{}, {restored:1,prompts:1,claims:1,canRestore:true}],
  ['no saved session means no popup',1,{recoverable:false},{restored:0,prompts:0,claims:0,canRestore:false}],
  ['private window does not show popup',1,{privateWindow:true},{restored:0,prompts:0,claims:0,canRestore:true}],
]){assert.deepEqual(await promptScenario(choice,opts),expected);passed++;console.log('PASS',name)}
console.log(`${passed} recovery checks passed`);

check('postponed recovery survives ordinary deferred startup', () => {
  const state = { ...previous, lastSessionState: { ...previous, synapseRecoveryPending: true } };
  assert.deepEqual(recoveryForDeferredStartup(state), state.lastSessionState);
});
check('old saved recovery page migrates on clean startup', () => {
  assert.deepEqual(recoveryForDeferredStartup(wrapper(previous)), { ...previous, synapseRecoveryPending: true });
});
console.log(`${passed} total recovery checks passed`);
