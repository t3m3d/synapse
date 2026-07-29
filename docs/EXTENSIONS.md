# Synapse extensions

## First-release contract

Synapse initially supports Firefox-compatible WebExtensions through Gecko's
existing AddonManager and extension processes. Keeping this machinery intact is
a release requirement, not a temporary demo shortcut.

- Signed `.xpi` packages use normal Firefox WebExtension manifests and APIs.
- Toolbar actions, menus, sidebars, content scripts, storage, and permission
  prompts continue through the existing Firefox application integration.
- Temporary unsigned extensions load only in a clearly marked developer profile.
- Legacy XUL add-ons and arbitrary binary injection are not supported.
- Private, Tor, I2P, and Blackout access is denied by default per extension.
- Blackout never permits public extensions.

Compatibility means API compatibility, not automatic trust. Synapse presents
requested permissions clearly and may deny APIs that would violate an isolated
privacy context.

## Synapse system extension

Synapse may bundle one allowlisted internal WebExtension to connect browser
chrome to a Krypton native host. It is product code, not a public extension API.
The first host uses one-shot `runtime.sendNativeMessage` requests and a strict
native-messaging manifest limited to the system extension ID.

The native wire format is one UTF-8 JSON message prefixed by an unsigned 32-bit
native-endian byte length. Message size, command names, paths, and context IDs
are validated on both sides.

## Future Synapse extensions

The public `.sxp`/Krypton-WASM extension system is deferred. It will begin only
after Krypton WASM has named exports, bounded memory, cancellation, a general
capability ABI, signature verification, and isolation tests. Until then,
`src/core/extensions.k` intentionally rejects non-`.xpi` packages.

Future work must not weaken Firefox WebExtension compatibility unless a change
is explicitly documented and migrated.
