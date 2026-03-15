#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
host="$root/apps/.host/macos/main.m"

[ -f "$host" ]

grep -F "setupMainMenuWithAppName" "$host" >/dev/null
grep -F 'initWithTitle:@"Edit"' "$host" >/dev/null
grep -F '@selector(copy:)' "$host" >/dev/null
grep -F '@selector(cut:)' "$host" >/dev/null
grep -F '@selector(paste:)' "$host" >/dev/null
grep -F '@selector(selectAll:)' "$host" >/dev/null
grep -F '@selector(undo:)' "$host" >/dev/null
grep -F '@selector(redo:)' "$host" >/dev/null
grep -F 'makeFirstResponder:self.webView' "$host" >/dev/null
grep -F "Hide Others" "$host" >/dev/null
grep -F "Close Window" "$host" >/dev/null
grep -F "setMainMenu" "$host" >/dev/null
grep -F "activateIgnoringOtherApps" "$host" >/dev/null
grep -F "isNestedWorkspaceApp" "$host" >/dev/null
grep -F "prefer the workspace-level icon" "$host" >/dev/null

printf '%s\n' "macOS host menu contract tests passed"
