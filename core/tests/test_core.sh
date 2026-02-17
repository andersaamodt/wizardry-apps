#!/bin/sh

# Build and run wizardry-core unit tests.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: test_core.sh

Builds and runs core/tests/test_core.c against core/src/wizardry_core.c
USAGE
  exit 0
  ;;
esac

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
OUT_DIR="$ROOT_DIR/_tmp/core-tests"
BIN="$OUT_DIR/test_core"

mkdir -p "$OUT_DIR"

cc -std=c99 -Wall -Wextra -Werror \
  -I"$ROOT_DIR/core/include" \
  "$ROOT_DIR/core/src/wizardry_core.c" \
  "$ROOT_DIR/core/tests/test_core.c" \
  -o "$BIN"

"$BIN"
