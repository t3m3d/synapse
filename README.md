# Synapse

Synapse is an original, privacy-first desktop browser powered by Gecko and
written in the Krypton language family wherever the current platform boundary
permits. Development starts from a working Firefox Desktop source tree so web
compatibility, sandboxing, accessibility, and Firefox WebExtensions work before
we replace product layers.

## Product commitments

- A calm, beautiful interface designed specifically for Synapse.
- Strict privacy defaults with honest, visible network-route state.
- Shield, Private, Tor, I2P, and maximum-isolation Blackout contexts.
- No direct-network fallback from Tor, I2P, or Blackout.
- Firefox WebExtension compatibility in the first working releases.
- A Synapse extension system later, after compatibility is stable.
- No Synapse telemetry, advertising identifier, or silent data collection.
- Fast upstream Gecko security updates.

## Architecture

The first milestone keeps the Firefox Desktop application intact and applies a
Synapse-owned overlay. New services and orchestration use Krypton. The diagram
below is the target process shape; the system extension and native host are not
implemented yet.

```text
Firefox Desktop application
  Gecko + existing browser chrome + WebExtensions
                    |
  bundled, allowlisted Synapse system extension
                    |
     one-shot native messaging (JSON framing)
                    |
          Krypton policy/service host

Objective-K / OKUI launcher
  profiles · privacy contexts · updates · diagnostics

KryptScript
  checkout · overlay · build · package · test · provenance
```

Firefox chrome remains temporarily because extension toolbar actions, menus,
permission prompts, and privileged APIs depend on it. Replacement happens
incrementally without breaking those contracts.

## Verified milestone

The current Windows development build:

- builds in Gecko artifact mode and launches with Synapse branding;
- passes the Krypton core privacy/navigation/extension contracts; and
- passes Gecko's Firefox WebExtension `browserAction` test.

Artifact mode rebuilds the frontend and branding layers while reusing downloaded
compiled Gecko application artifacts. The running development build therefore
still has inherited internal executable names, application identity, diagnostic
strings, and Gecko-required resource filenames. Full native builds and the
compiled-identity work in M5 remove those development-stage inheritances.

Blackout is currently a policy contract and fail-closed launcher choice, not an
enforced anonymity environment. Tor-only routing, operating-system egress
controls, ephemeral profile destruction, and leak tests must all land before
Blackout can launch. Synapse makes no security certification or classification
claim for the current build.

## Repository

```text
src/core/            Krypton privacy, navigation, and extension policy
src/bridge/          Future versioned engine protocol
src/control/         Objective-K launcher and privacy manager
overlay/             Files applied to the Firefox source checkout
tools/               KryptScript build and source orchestration
engine/bridge/       Future custom-embedder ABI
docs/                Architecture, privacy, extensions, roadmap
tests/               Krypton-native contract tests
```

The local Firefox checkout lives at `C:\mozilla-source\firefox`. Keeping it
outside this small overlay repository preserves upstream history and avoids
committing multi-gigabyte build output.

## Build

Prerequisites are MozillaBuild 4.2+ and Krypton 2.4+. Bootstrap uses Firefox
artifact mode first; full native builds begin when compiled branding or engine
changes are required. Run these commands from the Synapse repository root:

```powershell
dist\synapse-tool.exe doctor
dist\synapse-tool.exe apply
dist\synapse-tool.exe build
dist\synapse-tool.exe run
dist\synapse-tool.exe test-core
dist\synapse-tool.exe test-extension
```

`apply` copies the tracked overlay into `C:\mozilla-source\firefox` without
deleting upstream files, applies the small privacy-loader patch, and installs
the generated `mozconfig`. `build`, `run`, and `test-extension` call `apply`
automatically. Use `dist\synapse-tool.exe faster` for later frontend-only
rebuilds.

The extension command runs Gecko's existing `browserAction` browser test. Its
test-only preference overrides allow the local harness to run; they are not
changes to Synapse's shipped privacy defaults. `package` is exposed by the
controller for development, but packaging, signing, update delivery, and
release verification are not complete.

See [Architecture](docs/ARCHITECTURE.md), [Privacy](docs/PRIVACY.md),
[Extensions](docs/EXTENSIONS.md), and the [Roadmap](docs/ROADMAP.md).

## Licensing

Original Synapse source in this repository is licensed under GPL-3.0. Gecko
source retains its existing file-level licenses, principally MPL-2.0. See
`LICENSES/README.md` before distributing a build.
