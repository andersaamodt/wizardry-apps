#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
test_file="$root/.tests/apps/test-priorities-frontend-unit.mjs"

if ! command -v node >/dev/null 2>&1; then
  printf '%s\n' "skip: node not installed" >&2
  exit 0
fi

node "$test_file"
