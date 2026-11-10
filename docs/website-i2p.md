# I2P+ for the macOS website edition

Synapse ships its browser and I2P Settings helper together. The router is a
separate, opt-in download. Use **Install or update I2P+** in Synapse I2P
Settings, then **Refresh status** for the result. To update an installed
component, stop its router first. Start it explicitly when ready. Existing
manual I2P+ installations remain usable until a managed component is selected.

## Stage the browser

From the Synapse checkout, pass an arm64 Synapse app, a new staging path, and
the release public key. Keep the matching private key off the web server.

```sh
tools/synapse-macos.sh stage-website-i2p ./Synapse.app ./staging/Synapse.app ./public.pem
```

Sign the settings controller and helper before signing the outer app. Use
Developer ID and the hardened runtime, with the entitlements appropriate to
each executable. Notarize and staple before distributing. Open the packaged
helper with Finder via **Show Package Contents → Contents → Helpers → Synapse
I2P Settings**. The helper runs the bundled controller without a compiler.

## Prepare and publish a router release

The router publisher supplies a Developer ID-signed and notarized
`SynapseI2PRouter.app` built from verified I2P+ sources or release assets.
Include applicable source and license notices and validate the Java runtime
used by the release on a clean Apple Silicon Mac.

The app exposes `Contents/MacOS/i2p-router` with a command and one argument
for its separate user data directory. `start` and `stop` return zero on
success. `status` returns zero while running and three when stopped. Other
errors return another nonzero value. `ready` returns zero only after that
router owns the expected loopback HTTP proxy on 4444 and console on 7657 and
is ready to serve traffic. Refuse conflicting listeners and never create a
privileged service or launch at login.

The feed lives at
`https://krypton-lang.org/synapse/components/i2p/macos-arm64/`. Upload
`i2p-<sequence>.tar.gz` first. The gzip archive must contain exactly one
top-level `SynapseI2PRouter.app`, with ordinary files and directories and
no AppleDouble sidecars. The signed metadata consists of five LF-terminated
lines in `manifest.v1`.

1. `synapse-i2p-macos-arm64-v1`
2. An increasing positive release sequence, up to nine digits
3. Expiry as UTC Unix seconds, at most 14 days ahead
4. The archive's lowercase SHA-256 digest
5. The exact compressed byte count, at most 256 MiB

Sign those exact bytes with the release private key.

```sh
openssl dgst -sha256 -sign /path/to/private.pem -out manifest.sig manifest.v1
```

Publish the manifest and signature together after verifying the archive at the
download URL. Refresh the signed metadata at least weekly, even when the
archive is unchanged. Keep the same sequence and hash for a metadata renewal.
Publish a higher sequence for any changed archive, including a recovery build.
Package or signature failures leave the active version selected.

Run the local signed-fixture check with `bash tests/macos-i2p-component.sh`.
For a public release, also test installation, launch, routing, updates and
retries against the real notarized router and website feed on a clean Mac.
