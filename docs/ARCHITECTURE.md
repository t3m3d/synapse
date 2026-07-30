# Synapse architecture

## Decision

Synapse is a browser product built around upstream Gecko, not a new rendering
engine. First milestone deliberately begins as a Firefox Desktop application
fork: make it run, retain Firefox WebExtensions, then replace product layers
without breaking working contracts. Upstream security merges remain a primary
constraint.

## Ownership

| Layer | Owner | Primary language |
|---|---|---|
| Browser state and commands | Synapse | Krypton |
| Privacy and route policy | Synapse | Krypton |
| Launcher/profile manager | Synapse | Objective-K / OKUI |
| Build, packaging, releases | Synapse | KryptScript |
| Native policy/services host | Synapse | Krypton |
| Public extensions, first releases | Gecko | Firefox WebExtensions |
| Privileged browser chrome, temporary | Firefox application | JS/XHTML/CSS |
| Future engine adapter | Synapse | Small Rust/C++ component |
| Web engine | Upstream Mozilla | C++ and Rust |

Krypton is the default for original product logic. Non-Krypton code needs a
platform or Gecko-boundary justification.

## Working-first process model

```text
Firefox Desktop application
  Gecko + browser chrome + AddonManager
       |
       | allowlisted bundled system extension
       v
Firefox native messaging
  one request -> one bounded process
       |
       v
synapse-host
  Krypton policy and services
```

Objective-K/OKUI initially owns a separate launcher and privacy/profile manager,
not the browser window. Current OKUI and desktop Gecko do not yet provide a
stable event-loop/embedding boundary. This keeps WebExtension toolbar actions,
menus, permission prompts, accessibility, and process isolation working.

One-shot native messaging is intentional for the first Krypton host. It limits
lifetime and memory pressure while the Krypton compiler's long-running GC roots
and stream framing mature.

## Future custom-embedder rules

1. The ABI is C, versioned, and contains opaque handles only.
2. Commands are UTF-8 JSON owned by the caller.
3. Events are owned UTF-8 strings copied by Krypton and freed exactly once.
4. Gecko does not invoke Krypton callbacks.
5. Every command carries a profile/context identifier.
6. Unknown fields are ignored; unknown command types return a structured error.
7. Privileged operations are checked again inside the engine adapter.

The future contract is in `engine/bridge/include/synapse_gecko.h`; Krypton
message construction is in `src/bridge/protocol.k`.

## Profiles and routes

A tab belongs to an immutable browsing context:

- `shield`: direct route, hardened and partitioned.
- `private`: direct route, ephemeral storage.
- `tor`: Tor route, ephemeral storage and Tor-safe constraints.
- `i2p`: local I2P+ proxy route, dedicated persistent storage, and DIRECT
  fallback prefs disabled; the router's outproxy policy may allow clearnet.
- `blackout`: Tor-only maximum isolation, ephemeral state, extensions disabled,
  and controlled data egress.

Changing route creates a new context rather than mutating an existing tab.
This prevents direct-route connections, DNS state, service workers, caches, or
extensions from leaking into an anonymity context.

## Upstream strategy

- Track a release-quality Gecko branch and ingest security updates promptly.
- Keep product work outside Gecko directories whenever possible.
- Carry Synapse changes as a small, reviewable overlay and patch series.
- Never modify a deep engine subsystem when a product service or preference is
  sufficient.
- Run Mozilla tests plus Synapse privacy and integration tests before releasing.

The canonical local checkout is `C:\mozilla-source\firefox`; Synapse-owned
overlay files stay in this repository. Later, a dedicated remote fork can carry
the full source history without mixing Gecko object files into this repo.
