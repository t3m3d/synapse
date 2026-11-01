#!/usr/bin/env bash
# Thin launcher for the KryptScript controller in tools/synapse-macos.ks.
#
# Commands, arguments and exit codes belong to the controller. This shim exists
# only because `kr` and `kcc -r` both discard the program's exit status, which
# callers here depend on (the I2P settings app appends `echo __SYNAPSE_EXIT__$?`
# after running this script, and shell users chain commands with &&). It
# compiles the controller once, recompiles when the source changes, then hands
# over with exec so the real status is preserved.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
source_file="$here/synapse-macos.ks"
binary="$root/.synapse-build/tools/synapse-macos"

if [[ ! -f "$source_file" ]]; then
  printf 'Synapse: missing KryptScript controller: %s\n' "$source_file" >&2
  exit 1
fi

# macOS ships a Kerberos credential-cache tool named kcc in /usr/bin, which can
# shadow the Krypton compiler when /usr/local/bin is later in PATH. Select the
# compiler by its version banner instead of by name alone.
kcc=""
for candidate in "${SYNAPSE_KCC:-}" "$(command -v kcc 2>/dev/null || true)" \
                 /usr/local/bin/kcc /opt/homebrew/bin/kcc; do
  [[ -n "$candidate" && -x "$candidate" ]] || continue
  if "$candidate" --version 2>/dev/null | head -n 1 | grep -q '^kcc version '; then
    kcc="$candidate"
    break
  fi
done

if [[ -z "$kcc" ]]; then
  printf 'Synapse: Krypton compiler is missing (install Krypton 2.4+ or set SYNAPSE_KCC)\n' >&2
  exit 1
fi

if [[ ! -x "$binary" || "$source_file" -nt "$binary" ]]; then
  mkdir -p "$(dirname "$binary")"
  if ! build_log="$("$kcc" "$source_file" -o "$binary" 2>&1)"; then
    printf 'Synapse: could not build the KryptScript controller\n%s\n' "$build_log" >&2
    exit 1
  fi
fi

exec "$binary" "$@"
