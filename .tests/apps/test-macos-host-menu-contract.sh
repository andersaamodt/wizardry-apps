#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
host="$root/apps/.host/macos/main.m"

[ -f "$host" ] || {
  printf '%s\n' "missing host source: $host" >&2
  exit 1
}

assert_contains() {
  file=$1
  needle=$2
  if ! grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected macOS host contract text: $needle" >&2
    exit 1
  fi
}

# Edit menu should expose native text editing shortcuts through Cocoa selectors.
assert_contains "$host" "setupMainMenuWithAppName"
assert_contains "$host" 'initWithTitle:@"Edit"'
assert_contains "$host" '@selector(copy:)'
assert_contains "$host" '@selector(cut:)'
assert_contains "$host" '@selector(paste:)'
assert_contains "$host" '@selector(selectAll:)'
assert_contains "$host" '@selector(undo:)'
assert_contains "$host" '@selector(redo:)'
assert_contains "$host" 'makeFirstResponder:self.webView'
assert_contains "$host" "Hide Others"
assert_contains "$host" "Close Window"
assert_contains "$host" "setMainMenu"
assert_contains "$host" "activateIgnoringOtherApps"

# Nested workspace app launches should include workspace icon candidates.
assert_contains "$host" "isNestedWorkspaceApp"
assert_contains "$host" '[self.appPath stringByAppendingPathComponent:@"assets/forge-icon.png"]'
assert_contains "$host" '[parentPath stringByAppendingPathComponent:@"assets/forge-icon.png"]'
assert_contains "$host" "self.appIconImage = resolvedFileIcon ?: resolvedBundleIcon;"

printf '%s\n' "macOS host menu contract tests passed"
