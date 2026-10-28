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
- passes Gecko's Firefox WebExtension `browserAction` test; and
- produces an inspected unsigned ZIP and NSIS development installer.

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
dist\synapse-tool.exe package
dist\synapse-tool.exe store-dev
dist\synapse-tool.exe test-core
dist\synapse-tool.exe test-extension
```

`apply` copies the tracked overlay into `C:\mozilla-source\firefox` without
deleting upstream files, applies the small privacy-loader patch, and installs
the generated `mozconfig`. `build`, `run`, and `test-extension` call `apply`
automatically. Use `dist\synapse-tool.exe faster` for later frontend-only
rebuilds.

The extension command runs Gecko's existing `browserAction` browser test. Its
test-only preference overrides and longer timeout allow the local harness to
run; they do not change Synapse's shipped privacy defaults. `package` produces
Gecko's ZIP and NSIS outputs; the current copies are
`dist\Synapse-dev-win64.zip` and `dist\Synapse-dev-win64-setup.exe`.
`store-dev` performs a fresh build and produces the unsigned development MSIX
at `.synapse-build\release\SynapseBrowser_1.0.0.0_x64.msix` with the
`t3m3d.SynapseBrowser` package identity. Set `SYNAPSE_MAKEAPPX` if the Windows
SDK is installed somewhere other than the detected development path. These are
development artifacts, not a public release. Signing, Store submission, update
delivery, and release verification remain future work.

Objective-K identities live under `%LOCALAPPDATA%\Synapse\Profiles`; older
profiles under `.synapse-build\profiles` are copied forward without deleting
the recovery source. Direct shortcuts in current development packages may show
Gecko's crash dialog after a parent-process crash, but their reserved `.invalid`
endpoint prevents successful upload. Release packaging still needs a Synapse
launcher or build-level no-report enforcement.

### Windows I2P+ development mode

Start I2P+ before opening I2P mode in Synapse Control. The controller requires
a TCP listener at `127.0.0.1:4444`, then sends both HTTP and HTTPS through that
local I2P+ proxy. Every I2P identity uses a durable profile such as
`%LOCALAPPDATA%\Synapse\Profiles\synapse-i2p-personal`, separate from the same
identity in Shield. Its generated `user.js` disables ordinary direct proxy
fallback, WebRTC, native DNS, HTTP/3, prefetch, and network probes. The I2P
profile opens the local I2P+ Router Console at `http://127.0.0.1:7657`,
where its curated starter links are available after router bootstrap. The
I2P-only launcher also offers a shortcut to SusiDNS subscriptions at
`http://127.0.0.1:7657/susidns/subscriptions`. The optional I2P+ curated hosts
feed is `http://skank.i2p/hosts.txt`; adding it is a user-controlled trust
decision, not an automatic setting. The sole intentional proxy exception is
numeric loopback `127.0.0.1`, allowing the browser to reach the local router
console. I2P sites commonly need an explicit `http://` address. Run
`dist\synapse-tool.exe i2p-check` to test the local listener.

This is a development integration, not an `.i2p`-only guarantee. I2P+ may send
clearnet destinations through a router outproxy, and a successful TCP check
proves only that something is listening on the expected port. Profile
preferences are mutable browser controls, not immutable engine or operating
system policy. The extension-install preference is disabled inside I2P profiles
because a proxy-capable extension can replace routing, but existing or sideloaded
extensions are not yet attested; Firefox WebExtensions remain supported in
Shield. OS egress enforcement and the full proxy-failure,
DNS, WebRTC, QUIC, localhost, LAN, extension, and outproxy leak suite remain
release gates.

See [Architecture](docs/ARCHITECTURE.md), [Privacy](docs/PRIVACY.md),
[Extensions](docs/EXTENSIONS.md), and the [Roadmap](docs/ROADMAP.md).

### macOS development

On macOS, keep the Firefox checkout at `~/mozilla-source/firefox` (or set
`SYNAPSE_FIREFOX_ROOT`) and run:

```bash
tools/synapse-macos.sh doctor
tools/synapse-macos.sh test-core
tools/synapse-macos.sh apply
tools/synapse-macos.sh build
tools/synapse-macos.sh run
# With I2P+ installed and bootstrapped:
tools/synapse-macos.sh i2p-settings
tools/synapse-macos.sh i2p-setup-check
tools/synapse-macos.sh i2p-install-guide
tools/synapse-macos.sh i2p-router-status
tools/synapse-macos.sh i2p-router-start
tools/synapse-macos.sh i2p-router-stop
tools/synapse-macos.sh i2p-check
tools/synapse-macos.sh i2p-open personal
tools/synapse-macos.sh i2p-open personal subscriptions
```

The macOS controller uses the same tracked overlay and privacy patch as the
Windows controller. It keeps build state under `.synapse-build` and does not
delete files from the upstream Firefox checkout. `i2p-settings` builds and opens
a standalone Synapse I2P Network settings window with setup diagnostics,
official download link, router status, explicit start/graceful-stop, identity
selection, browser launch, and SusiDNS actions. Its router-action bridge uses
Krypton's current synchronous `exec()` API with a fixed allowlist of actions, so
the window can pause while a router command runs; a native nonblocking
argv-based process API is not yet available in the current Krypton framework.
It is not yet embedded in Firefox `about:preferences`. `i2p-setup-check` reports
Java runtime, installation script, and proxy-listener status separately;
`i2p-install-guide` opens the [official I2P+ download page](https://i2pplus.github.io/download.html).
The I2P+ router management commands use the installed `i2prouter` script (default install locations
`/Applications/i2p` and `~/i2p`; set `SYNAPSE_I2P_ROUTER_DIR` for another path).
Start and graceful stop are explicit user actions; Synapse does not install a
launchd service or configure login autostart. Router status and proxy readiness
are reported separately: a TCP listener does not prove bootstrap or router
identity. The macOS browser launch still requires the proxy at `127.0.0.1:4444`;
it creates a persistent, mode-and-identity-isolated profile under
`~/Library/Application Support/Synapse/Profiles/` and opens the local Router
Console. It never adds the optional `http://skank.i2p/hosts.txt` address-book
subscription automatically. This is a local development path; the TCP probe
confirms only that a listener exists, not that the router has bootstrapped or
that traffic is protected by operating-system egress controls.

### Durable agent and sandbox workspace (Archil)

CI runners and sandboxed coding agents discard their file system when a run
ends. `tools/archil_workspace.py` keeps that work on an
[Archil](https://docs.archil.com/sdks/python) disk instead, so sources, logs,
and small build outputs written by one agent or sandbox run are still there for
the next one, from any machine:

```bash
python3 -m venv .venv
.venv/bin/pip install archil
export ARCHIL_API_KEY=key-...        # account API key, not a disk token
.venv/bin/python tools/archil_workspace.py status
.venv/bin/python tools/archil_workspace.py run -- sh -c 'date > last-run'
.venv/bin/python tools/archil_workspace.py run -- cat last-run
```

The workspace disk is found by name (`synapse-build-workspace` by default; set
`SYNAPSE_ARCHIL_DISK` for another) and created on first use. `.env.example`
declares the variables; `ARCHIL_API_KEY` is read from the environment and never
written to the repository. Commands run in an Archil microVM with the disk as
the working directory, which suits short workspace tasks and file inspection
rather than a full Gecko build: the SDK's default request timeout applies and
the service caps a single command at five minutes.

## Licensing

Original Synapse source in this repository is licensed under GPL-3.0. Gecko
source retains its existing file-level licenses, principally MPL-2.0. See
`LICENSES/README.md` before distributing a build.
