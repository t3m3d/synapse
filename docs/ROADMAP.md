# Synapse roadmap

## Verified development state

- [x] A Synapse-branded Windows artifact build launches.
- [x] Krypton core contracts pass.
- [x] Gecko's Firefox WebExtension `browserAction` test passes.
- [x] An unsigned Windows ZIP and NSIS development installer are packaged and inspected.
- [x] An unsigned Windows MSIX is packaged and its manifest is inspected.

Artifact mode still reuses compiled upstream application identity and
executables. Blackout remains a non-certified policy contract and does not
launch until Tor-only routing, egress controls, ephemeral cleanup, and leak
tests enforce it end to end. The unsigned packages are development outputs,
not a public release.

## M0 — Foundation

- [x] Synapse name and product commitments.
- [x] Working-first Firefox/Krypton ownership boundary.
- [x] Krypton privacy, navigation, and WebExtension policy core.
- [x] Shield, Private, Tor, I2P, and Blackout contracts.
- [x] Krypton-native policy tests.
- [x] MozillaBuild environment installed.

## M1 — Working browser

- [x] Bootstrap canonical Firefox Git source in artifact mode.
- [ ] Record a separate untouched-upstream baseline comparison.
- [x] Apply Synapse display name, development branding, and hardened defaults.
- [x] Build and launch the branded artifact application.
- [x] Pass Gecko's Firefox WebExtension `browserAction` test.
- [ ] Verify signed-XPI install, toolbar action, and content script behavior in
  a clean dedicated Synapse profile.
- [x] Package the Windows build.

## M2 — Krypton integration

- [x] KryptScript owns diagnostics, additive overlay application, artifact
  build, run, ZIP/NSIS/MSIX packaging, core-test, and WebExtension-test entry
  points.
- [ ] Add checkout pinning, verified packaging, and provenance reporting.
- [x] Objective-K launcher starts separate Personal, Work, School, Creator, and
  Second account Gecko profiles.
- [x] Store Objective-K identity profiles in durable per-user application data
  and preserve earlier build-tree profiles during one-time migration.
- [x] Separate Windows Gecko profiles by both privacy mode and browser identity.
- [ ] Fix Krypton's Windows quoted-argv parsing before Program Files packaging.
- [ ] Replace Objective-K's ANSI browser launch with `ShellExecuteExW` after
  Krypton's native wide-process path is stable.
- [ ] Replace the bounded PowerShell loopback probe with native Krypton Winsock
  after the Windows host's direct Winsock import path is repaired and covered by
  integration tests.
- [ ] Register or migrate Objective-K identities into Gecko's selectable-profile
  service without hiding previously created profiles.
- [ ] Connect Objective-K privacy contexts and diagnostics to engine enforcement.
- [ ] Implement Firefox native-message framing in pure Krypton.
- [ ] Bundle an allowlisted Synapse system extension and one-shot Krypton host.
- [ ] Add provenance, license, and update-policy reports.

## M3 — Privacy enforcement

- [ ] Apply hardened Gecko defaults with automated assertions.
- [ ] Implement immutable Shield and Private profile contexts.
- [x] Add the initial Windows I2P+ profile: dedicated durable mode-and-identity
  state, `127.0.0.1:4444` TCP gate, explicit HTTP/HTTPS proxying, no-DIRECT
  preferences, and native DNS/WebRTC/HTTP3 disabled.
- [ ] Authenticate and attest I2P+ listener ownership, router bootstrap, and
  router outproxy policy.
- [ ] Integrate Tor with fail-closed routing tests.
- [ ] Add build-level immutable proxy controls and per-process OS egress rules.
- [ ] Implement Blackout egress controls and ephemeral lifecycle.
- [ ] Partition state and extension processes across context boundaries.
- [ ] Add fingerprinting, DNS/DoH, WebRTC/STUN, QUIC/WebTransport, proxy-loss,
  localhost/LAN, IPv4/IPv6, outproxy, extension, and crash-recovery leak tests.
- [ ] Commission an independent security assessment before certification claims.

## M4 — Beautiful Synapse chrome

- [ ] Establish color, typography, motion, spacing, and icon tokens.
- [ ] Redesign tabs, omnibox, identity panel, downloads, history, and settings.
- [ ] Preserve Firefox extension action IDs, menus, permission flows, and APIs.
- [ ] Add keyboard-first navigation and accessible focus behavior.
- [ ] Run contrast, high-DPI, screen-reader, and reduced-motion checks.

## M5 — Greater separation

- [ ] Switch to full builds and replace inherited compiled application identity.
- [ ] Move suitable product services from privileged JS into Krypton.
- [ ] Keep the Gecko patch series small and upstream security merges routine.
- [ ] Re-evaluate the future C ABI/custom embedder only after parity tests exist.
- [ ] Design public Synapse extensions after Krypton WASM capability isolation is
  ready; Firefox WebExtensions remain supported unless deliberately migrated.

## M6 — Release engineering

- [ ] Reproducible signed builds and installers.
- [ ] Signed updates with rollback protection.
- [ ] Package a Synapse launcher or enforce no-report crash handling at build
  level for direct ZIP, NSIS, and MSIX shortcuts.
- [ ] Software bill of materials and complete license bundle.
- [ ] Emergency upstream-security merge and release procedure.
