# Synapse privacy model

Synapse aims for strong, understandable privacy. It must not make anonymity,
classification, or certification claims that the active route and audited build
cannot support.

## Non-negotiable defaults

- Synapse telemetry and crash-content submission are off. Supported launchers
  suppress the reporter UI and retain local minidumps for diagnosis.
- Upstream country lookup and nearby Wi-Fi scanning are disabled.
- Cookies, cache, storage, and network state are partitioned by top-level site.
- Tracking protection is enabled. Direct contexts use HTTPS-only; I2P mode
  allows HTTP because many I2P services do not offer HTTPS.
- Speculative connections, link prefetch, and DNS prefetch are disabled.
- Permission grants are narrow, visible, and revocable.
- Private, Tor, and Blackout are blocked until their isolated-profile and route
  controls are enforced. I2P launches only through its dedicated profile after
  the local I2P+ proxy readiness gate passes.
- Search suggestions do not leave the device until the user enables them.
- Extension installation is disabled by default outside Shield and is a denial
  goal for Blackout. I2P does not yet have immutable or attested extension
  denial.

## Security-service boundary

Synapse currently retains Gecko's Safe Browsing and signed Remote Settings
security feeds. Those services may contact upstream infrastructure, but they
deliver phishing, malware, certificate, add-on, and other blocklists. Synapse
will not silently remove those protections merely to claim zero upstream
connections; replacement services need authenticated data and equivalent tests.

Application updates are locked off only while this is an unsigned development
build. A public release requires a signed Synapse update channel.

Objective-K and KryptScript launch paths suppress crash UI and upload. Current
ZIP, NSIS, and MSIX shortcuts launch the engine directly, so a parent-process
crash may still show Gecko's reporter UI; its reserved `.invalid` endpoint
prevents successful submission. Public packages require a Synapse launcher or
build-level no-report enforcement.

## Route truthfulness

The interface always shows one of these route labels:

| Context | Network route | State | Claim |
|---|---|---|---|
| Shield | Direct | Partitioned | Hardened browsing, not anonymous |
| Private | Direct | Ephemeral | Private state, not anonymous |
| Tor | Tor-only | Ephemeral | Tor context only |
| I2P | Local I2P+ HTTP proxy | Durable, isolated by mode and identity | Traffic is handed to I2P+; router outproxy policy may permit clearnet |
| Blackout | Tor-only | Ephemeral, locked egress | Maximum-isolation goal |

When an enforced Tor, I2P, or Blackout route is unavailable, Synapse blocks
launch or navigation instead of silently falling back to direct networking.
The current I2P readiness gate proves only that the local proxy port accepts TCP.

## Windows I2P+ development profile

Windows I2P mode creates a durable Gecko profile for each mode-and-identity pair,
so I2P Personal never shares browser state with Shield Personal. The launcher
requires a TCP connection to `127.0.0.1:4444` before it creates or opens the
profile. That check neither authenticates the listener nor proves the router has
bootstrapped.

Both HTTP and HTTPS use the I2P+ HTTP proxy on port 4444; SOCKS is unused. The
generated `user.js` disables direct proxy failover and bypass, native DNS, DoH,
WebRTC, HTTP/3, speculative connections, prefetch, connectivity checks, and
captive-portal checks. Most `.i2p` sites need an explicit `http://` URL. The
installation preference is disabled because proxy-capable extensions can replace
the route, but existing or sideloaded extensions are not yet immutably blocked or
attested.

This mode hands browser traffic to I2P+ while startup prefs disable ordinary
DIRECT fallback. It must not be described as `.i2p`-only: the router may send clearnet
destinations through its configured outproxy. `user.js` and live preferences
are also mutable browser controls. Authenticated router readiness, build-level
immutable proxy enforcement, router outproxy policy, operating-system egress
rules, and leak tests for proxy loss, DNS/DoH, WebRTC/STUN, HTTP/3/QUIC,
WebTransport, WebSocket, extensions, updates, captive portal, localhost/LAN,
and IPv4/IPv6 remain release gates.

## Blackout

Blackout is Synapse's strongest privacy ability. It is designed toward the
operational discipline expected on highly sensitive or classified workstations:

- fresh ephemeral profile per session;
- Tor-only networking with no direct fallback;
- no public extensions, clipboard, printing, WebRTC, password storage, form
  autofill, local-network access, or external protocol launches;
- downloads quarantined behind an explicit export boundary;
- screen capture denied where the operating system permits enforcement;
- history and session restoration disabled;
- fail-closed startup when required isolation controls are unavailable.

"Blackout" is a product mode, not a government security classification. Synapse
must not call it military-certified, Top Secret–approved, FIPS-validated, or
accredited until the exact build and deployment have passed the applicable
independent evaluation.

## Isolation invariants

- Route selection is fixed when a context is created.
- Direct and anonymity contexts never share cookie jars, caches, DNS caches,
  TLS session tickets, service workers, history, or extension processes.
- Downloads crossing an isolation boundary require a clear warning and policy
  check.
- Release target: localhost, LAN, `file:`, and OS protocol access are denied in
  Tor, I2P, and Blackout unless a mode defines a narrower safe operation. Current
  I2P browser prefs proxy localhost/LAN HTTP and block external handlers by
  default; immutable engine and OS enforcement remain pending.

## Threat model

Synapse targets routine cross-site tracking, accidental route leaks,
over-privileged extensions, unwanted telemetry, and common fingerprinting. It
does not promise protection from a compromised operating system, hostile
hardware, malicious browser-engine code, global traffic correlation, endpoint
surveillance, or unsafe files opened outside Synapse.

Security-sensitive preferences are enforced by `src/core/privacy.k` and must be
mirrored by engine-side and operating-system checks. UI state alone is never a
security boundary.
