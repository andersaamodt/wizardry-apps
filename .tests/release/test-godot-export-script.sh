#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
out=$(sh "$ROOT_DIR/godot/scripts/export-godot-desktop.sh" --help)
printf '%s' "$out" | grep -q 'Linux + macOS'
printf '%s' "$out" | grep -q 'TARGET'

printf '%s\n' "godot export script help checks passed"
