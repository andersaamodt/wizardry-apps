#!/bin/sh

# Build and run wizardry-core unit tests.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: test_core.sh

Builds and runs runtime/core/tests/test_core.c against runtime/core/src/wizardry_core.c
USAGE
  exit 0
  ;;
esac

set -eu

hash_stdin_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | awk '{ print $NF }'
    return 0
  fi
  printf '%s\n' "test_core.sh: sha256 tool not available (requires shasum, sha256sum, or openssl)" >&2
  exit 1
}

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
CHECKOUT_KEY=$(printf '%s' "$ROOT_DIR" | hash_stdin_sha256)
OUT_DIR="${WIZARDRY_APPS_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/wizardry-apps}/forge/checkouts/$CHECKOUT_KEY/core-tests"
BIN="$OUT_DIR/test_core"

mkdir -p "$OUT_DIR"

cc -std=c99 -Wall -Wextra -Werror \
  -I"$ROOT_DIR/runtime/core/include" \
  "$ROOT_DIR/runtime/core/src/wizardry_core.c" \
  "$ROOT_DIR/runtime/core/tests/test_core.c" \
  -o "$BIN"

"$BIN"
