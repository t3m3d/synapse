#!/usr/bin/env bash
# Host-side Linux driver for Gecko's mach build system.
set -euo pipefail

fail() { printf 'Synapse Linux: %s\n' "$*" >&2; exit 1; }

usage() {
    printf '%s\n' 'Usage: tools/synapse-linux.sh {apply|build|run|package|build-launcher} [mach arguments...]'
    printf '%s\n' 'Set SYNAPSE_FIREFOX_ROOT to a dedicated Firefox checkout on Linux.'
    printf '%s\n' 'Build the optional Wayland launcher with tools/synapse-linux.sh build-launcher.'
}

action=${1:-help}
case "$action" in
    help|-h|--help) usage; exit 0 ;;
    apply|build|run|package|build-launcher) shift ;;
    *) usage >&2; exit 2 ;;
esac
if [[ "$action" != run && "$action" != build && $# -ne 0 ]]; then
    fail 'only build and run accept additional arguments'
fi
[[ "$(uname -s)" == Linux ]] || fail 'run this inside the Linux build host'

workspace=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# Keep Linux's generated config, Gecko objects and downloads apart from the
# Windows and macOS workflows. The source directory holds only the overlay.
arch=$(uname -m)
state="$workspace/.synapse-build/linux-$arch"

if [[ "$action" == build-launcher ]]; then
    [[ "$arch" == x86_64 ]] || fail 'the Choc and libobjk launcher currently targets Linux x86-64'
    compiler=${SYNAPSE_KCC:-kcc}
    command -v "$compiler" >/dev/null || fail 'set SYNAPSE_KCC to the KryptOS compiler'
    mkdir -p -- "$state"
    stage=$(mktemp -d -- "$state/.launcher.XXXXXXXX")
    trap 'rm -rf -- "$stage"' EXIT
    "$compiler" "$workspace/src/control/linux/launcher.ks" -o "$stage/synapse-launcher"
    [[ -x "$stage/synapse-launcher" ]] || fail 'the compiler did not produce a launcher'
    mv -fT -- "$stage/synapse-launcher" "$state/synapse-launcher"
    printf 'Built %s\n' "$state/synapse-launcher"
    exit 0
fi

[[ -n "${SYNAPSE_FIREFOX_ROOT:-}" ]] || fail 'set SYNAPSE_FIREFOX_ROOT first'
firefox=$(cd -- "$SYNAPSE_FIREFOX_ROOT" && pwd -P)
[[ "$firefox" != "$workspace" && -x "$firefox/mach" && -d "$firefox/browser" ]] ||
    fail 'SYNAPSE_FIREFOX_ROOT must point to a dedicated Firefox source tree'

mkdir -p -- "$state/mozbuild"
export MOZCONFIG="$state/mozconfig"
export MOZBUILD_STATE_PATH="$state/mozbuild"
export SYNAPSE_LINUX_OBJDIR="$state/obj-synapse"

apply_overlay() {
    command -v git >/dev/null && command -v rsync >/dev/null || fail 'git and rsync are required'
    local patch path
    for patch in privacy-loader synapse-theme synapse-places-theme synapse-places-titlebar \
        synapse-newtaburl synapse-startpage-label synapse-session-recovery; do
        path="$workspace/overlay/privacy/$patch.patch"
        if git -C "$firefox" apply --reverse --check "$path" 2>/dev/null; then
            continue
        fi
        git -C "$firefox" apply "$path" || fail "overlay patch no longer applies: $patch"
    done
    rsync -a -- "$workspace/overlay/browser/" "$firefox/browser/"
    install -m 644 -- "$workspace/config/mozconfig.linux" "$MOZCONFIG"
    printf 'Linux overlay ready. Gecko objects will go to %s\n' "$SYNAPSE_LINUX_OBJDIR"
}

apply_overlay
cd -- "$firefox"
case "$action" in
    build) exec ./mach build "$@" ;;
    run)
        export MOZ_CRASHREPORTER_NO_REPORT=1
        exec ./mach run --no-remote "$@"
        ;;
    package)
        ./mach build faster
        exec ./mach package
        ;;
esac
