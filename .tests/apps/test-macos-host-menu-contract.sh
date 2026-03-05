#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
host="$root/apps/.host/macos/main.m"

[ -f "$host" ]

grep -F "setupMainMenuWithAppName" "$host" >/dev/null
grep -F "Hide Others" "$host" >/dev/null
grep -F "Close Window" "$host" >/dev/null
grep -F "setMainMenu" "$host" >/dev/null
grep -F "activateIgnoringOtherApps" "$host" >/dev/null

printf '%s\n' "macOS host menu contract tests passed"
