#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
script_path="$ROOT_DIR/apps/forge/scripts/forge-backend.sh"

grep -F "resolve_firewalled_adb_exec" "$script_path" >/dev/null
grep -F "run_firewalled_adb_command" "$script_path" >/dev/null
grep -F "firewalled-adb is required to run Android device commands safely" "$script_path" >/dev/null

printf '%s\n' "forge firewalled adb checks passed"
