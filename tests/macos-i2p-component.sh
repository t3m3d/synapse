#!/bin/bash
# Local security regression fixture. Uses a disposable key and inert runner.
set -euo pipefail

compiler=${SYNAPSE_KCC:-/usr/local/bin/kcc}
repo=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

app="$fixture/payload/SynapseI2PRouter.app"
mkdir -p "$app/Contents/MacOS" "$fixture/installed/versions" "$fixture/stage" "$fixture/next-stage"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.synapse.i2p.fixture</string>
<key>CFBundleExecutable</key><string>i2p-router</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
cat > "$fixture/runner.c" <<'SOURCE'
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    if (!strcmp(argv[1], "start")) {
        FILE *state = fopen(argv[2], "w");
        return state ? fclose(state) : 2;
    }
    if (!strcmp(argv[1], "stop")) return unlink(argv[2]) == 0 ? 0 : 2;
    if (!strcmp(argv[1], "status") || !strcmp(argv[1], "ready"))
        return access(argv[2], F_OK) == 0 ? 0 : 3;
    return 2;
}
SOURCE
/usr/bin/clang "$fixture/runner.c" -o "$app/Contents/MacOS/i2p-router"
codesign --force --sign - "$app"
COPYFILE_DISABLE=1 tar -czf "$fixture/router.tar.gz" -C "$fixture/payload" SynapseI2PRouter.app
cp "$fixture/router.tar.gz" "$fixture/changed.tar.gz"
printf '\000' | dd of="$fixture/changed.tar.gz" bs=1 seek=1 conv=notrunc 2>/dev/null
openssl ecparam -name prime256v1 -genkey -noout -out "$fixture/private.pem"
openssl pkey -in "$fixture/private.pem" -pubout -out "$fixture/public.pem"
openssl ecparam -name prime256v1 -genkey -noout | openssl pkey -pubout -out "$fixture/wrong.pem"
now=$(date +%s)
hash=$(shasum -a 256 "$fixture/router.tar.gz" | cut -c1-64)
size=$(stat -f %z "$fixture/router.tar.gz")
manifest() {
    printf 'synapse-i2p-macos-arm64-v1\n%s\n%s\n%s\n%s\n' "$1" "$2" "$hash" "$size"
}
manifest 2 "$((now + 86400))" > "$fixture/manifest.v1"
manifest 3 "$((now + 86400))" > "$fixture/changed.v1"
manifest 2 "$((now - 60))" > "$fixture/expired.v1"
for name in manifest expired; do
    openssl dgst -sha256 -sign "$fixture/private.pem" -out "$fixture/$name.sig" "$fixture/$name.v1"
done
"$compiler" "$repo/tests/macos-i2p-component.ks" -o "$fixture/test"
"$fixture/test" "$fixture" | tee "$fixture/test.log"
grep -Fxq 'macOS I2P+ component tests passed.' "$fixture/test.log"
