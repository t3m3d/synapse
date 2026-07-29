# Synapse roadmap

## M0 — Foundation

- [x] Synapse name and product commitments.
- [x] Working-first Firefox/Krypton ownership boundary.
- [x] Krypton privacy, navigation, and WebExtension policy core.
- [x] Shield, Private, Tor, I2P, and Blackout contracts.
- [x] Krypton-native policy tests.
- [x] MozillaBuild environment installed.

## M1 — Working browser

- [ ] Bootstrap canonical Firefox Git source in artifact mode.
- [ ] Build and launch the untouched upstream baseline.
- [ ] Apply Synapse display name, development branding, and safe defaults.
- [ ] Launch Synapse with a clean dedicated profile.
- [ ] Load a normal Firefox WebExtension and verify toolbar/content behavior.
- [ ] Package the Windows build.

## M2 — Krypton integration

- [ ] KryptScript owns checkout pinning, overlay, build, run, package, and tests.
- [ ] Objective-K launcher manages profiles, privacy contexts, and diagnostics.
- [ ] Implement Firefox native-message framing in pure Krypton.
- [ ] Bundle an allowlisted Synapse system extension and one-shot Krypton host.
- [ ] Add provenance, license, and update-policy reports.

## M3 — Privacy enforcement

- [ ] Apply hardened Gecko defaults with automated assertions.
- [ ] Implement immutable Shield and Private profile contexts.
- [ ] Integrate Tor and I2P with fail-closed routing tests.
- [ ] Implement Blackout egress controls and ephemeral lifecycle.
- [ ] Partition state and extension processes across context boundaries.
- [ ] Add fingerprinting, DNS, WebRTC, proxy-failure, and crash-recovery tests.
- [ ] Commission an independent security assessment before certification claims.

## M4 — Beautiful Synapse chrome

- [ ] Establish color, typography, motion, spacing, and icon tokens.
- [ ] Redesign tabs, omnibox, identity panel, downloads, history, and settings.
- [ ] Preserve Firefox extension action IDs, menus, permission flows, and APIs.
- [ ] Add keyboard-first navigation and accessible focus behavior.
- [ ] Run contrast, high-DPI, screen-reader, and reduced-motion checks.

## M5 — Greater separation

- [ ] Switch to full builds for compiled identity and native integration.
- [ ] Move suitable product services from privileged JS into Krypton.
- [ ] Keep the Gecko patch series small and upstream security merges routine.
- [ ] Re-evaluate the future C ABI/custom embedder only after parity tests exist.
- [ ] Design public Synapse extensions after Krypton WASM capability isolation is
  ready; Firefox WebExtensions remain supported unless deliberately migrated.

## M6 — Release engineering

- [ ] Reproducible signed builds and installers.
- [ ] Signed updates with rollback protection.
- [ ] Software bill of materials and complete license bundle.
- [ ] Emergency upstream-security merge and release procedure.
