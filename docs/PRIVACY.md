# Synapse privacy model

Synapse aims for strong, understandable privacy. It must not make anonymity,
classification, or certification claims that the active route and audited build
cannot support.

## Non-negotiable defaults

- Synapse telemetry and crash-content submission are off. Supported launchers
  suppress the reporter UI and retain local minidumps for diagnosis.
- Upstream country lookup and nearby Wi-Fi scanning are disabled.
- Cookies, cache, storage, and network state are partitioned by top-level site.
- Tracking protection and HTTPS-only behavior are enabled.
- Speculative connections, link prefetch, and DNS prefetch are disabled.
- Permission grants are narrow, visible, and revocable.
- Private, Tor, I2P, and Blackout are blocked until their isolated-profile and
  route controls are enforced.
- Search suggestions do not leave the device until the user enables them.
- Extension access is denied outside Shield unless explicitly supported; it is
  always denied in Blackout.

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
| I2P | I2P-only | Isolated | I2P context only |
| Blackout | Tor-only | Ephemeral, locked egress | Maximum-isolation goal |

A failed Tor, I2P, or Blackout bootstrap blocks navigation instead of silently
falling back to direct networking.

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
- Localhost, LAN, `file:`, and OS protocol access are denied in Tor, I2P, and
  Blackout unless that mode explicitly defines a narrower safe operation.

## Threat model

Synapse targets routine cross-site tracking, accidental route leaks,
over-privileged extensions, unwanted telemetry, and common fingerprinting. It
does not promise protection from a compromised operating system, hostile
hardware, malicious browser-engine code, global traffic correlation, endpoint
surveillance, or unsafe files opened outside Synapse.

Security-sensitive preferences are enforced by `src/core/privacy.k` and must be
mirrored by engine-side and operating-system checks. UI state alone is never a
security boundary.
