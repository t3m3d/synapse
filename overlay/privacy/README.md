# Synapse privacy overlay

This overlay has two deliberately separate layers:

1. `browser/app/profile/synapse.js` supplies practical hardened Firefox defaults.
2. `privacy/blackout/` defines a fail-closed, Tor-only mode that remains disabled
   until every runtime attestation in `contract.json` is implemented.

This is an engineering privacy target. It is not a claim of military approval,
government classification handling, formal verification, or certification.

## Build integration

Apply `privacy-loader.patch` at the Firefox source root, then copy the `browser/`
overlay onto `browser/`. The patch adds `synapse.js` to
`JS_PREFERENCE_PP_FILES` and the package manifest. The overlaid
`browser/app/distribution/moz.build` packages the normal Synapse
`policies.json` for both official and developer builds.

The normal policy intentionally leaves Firefox WebExtensions available. It
locks the no-telemetry, no-studies, no-sponsored-content floor. Blackout's
alternate policy blocks installation and uninstalls non-system profile add-ons;
the runtime must additionally attest that no non-builtin add-on is active.

## Windows I2P+ profile

The Objective-K controller generates a `user.js` for each dedicated
`%LOCALAPPDATA%\Synapse\Profiles\synapse-i2p-<identity>` profile rather than
changing the shared `synapse.js`. It requires a TCP listener on
`127.0.0.1:4444`, assigns both HTTP and HTTPS to that I2P+ proxy, and disables
ordinary direct failover, native DNS, WebRTC, HTTP/3, speculative connections,
and network probes. The sole proxy exception is numeric loopback `127.0.0.1`,
which lets `C:\Program Files\i2p\docs\startconsole.html` reach the local router
console without exempting localhost names or private LAN ranges. The
extension-install preference is disabled, but existing or sideloaded extensions
are not yet immutably blocked or attested; a proxy extension can replace the
route.

This is a fail-closed browser preference layer, not a complete egress boundary.
The TCP probe does not authenticate I2P+, prove router bootstrap, or constrain
the router's clearnet outproxy. `user.js` and runtime preferences are mutable.
Build-level immutable controls, operating-system process egress, router outproxy
policy, and the comprehensive leak suite remain required before a release claim.

## Blackout launch contract

`blackout/user.js` and `blackout/policies.template.json` are templates, not a
launchable profile. Both use SOCKS port `0`, so an accidental launch is offline.
A future Objective-K launcher must:

1. refuse concurrent Synapse instances;
2. create a fresh restricted, preferably memory-backed profile;
3. probe a trusted Tor listener and wait for a usable circuit;
4. materialize the user and alternate-policy templates with that exact port;
5. arrange `browser.policies.alternatePath` before Gecko policy startup;
6. activate an OS egress rule that permits only the Tor loopback connection;
7. start Gecko, attest every item in `contract.json`, and only then enable use;
8. kill the browser immediately if Tor, policy, firewall, or another invariant
   fails; and
9. remove the ephemeral profile and any crash/download residue on exit.

Until this exists, the launcher must refuse Blackout. Prefs alone cannot prove
Tor-only routing or prevent every native socket path.

Clipboard denial and download quarantine are intentionally not represented as
Firefox prefs: this source tree has no stable global pref that provides either
guarantee. They require Synapse chrome/runtime enforcement. Local Network Access
prefs are defense in depth; the OS egress rule is the authoritative LAN/direct
network boundary.

## Audited pref provenance

Audited against Firefox source commit `272c6937c93bf6c3f132ce962d9ad7d798fce830`.

| Control | Source evidence |
| --- | --- |
| HTTPS-only | `modules/libpref/init/StaticPrefList.yaml` (`dom.security.https_only_mode*`) |
| Cookie behavior and partitioning | `modules/libpref/init/StaticPrefList.yaml`; `browser/app/profile/firefox.js` uses value `5` |
| Tracking/fingerprinting defenses | `modules/libpref/init/StaticPrefList.yaml` (`privacy.trackingprotection.*`, FPP, RFP) |
| DNS/prefetch/speculative connections | `modules/libpref/init/all.js`, `StaticPrefList.yaml`, and `browser/app/profile/firefox.js` |
| WebRTC IP controls | `modules/libpref/init/all.js` and `dom/media/webrtc/jsapi/` |
| Local Network Access | `modules/libpref/init/StaticPrefList.yaml` (`network.lna.*`) |
| SOCKS remote DNS and bypass protection | `modules/libpref/init/StaticPrefList.yaml` (`network.proxy.*`) |
| TRR off-by-choice value `5` | `modules/libpref/init/StaticPrefList.yaml` |
| External protocol blocking | `modules/libpref/init/all.js` and `uriloader/exthandler/` |
| Password and form autofill | `modules/libpref/init/all.js` |
| Printing | `modules/libpref/init/StaticPrefList.yaml` (`print.enabled`) |
| Extension wildcard blocking | `browser/components/enterprisepolicies/Policies.sys.mjs` |
| Policy schema | `browser/components/enterprisepolicies/schemas/policies-schema.json` |

`browser.newtabpage.activity-stream.feeds.telemetry` and the sponsored-content
prefs are dynamically registered by `browser/extensions/newtab/lib/ActivityStream.sys.mjs`
and consumed through the Activity Stream pref branch.

