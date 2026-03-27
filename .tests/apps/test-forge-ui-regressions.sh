#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/apps/forge/index.html"
host_macos="$root/apps/.host/macos/main.m"

[ -f "$ui" ] || {
  printf '%s\n' "forge ui file missing: $ui" >&2
  exit 1
}
[ -f "$host_macos" ] || {
  printf '%s\n' "forge macOS host file missing: $host_macos" >&2
  exit 1
}

assert_contains() {
  file=$1
  needle=$2
  if ! grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected contract text in $file: $needle" >&2
    exit 1
  fi
}

assert_matches() {
  file=$1
  pattern=$2
  if ! grep -E "$pattern" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected contract pattern in $file: $pattern" >&2
    exit 1
  fi
}

# UI feedback and action wiring contracts.
assert_contains "$ui" 'id="footer-status"'
assert_contains "$ui" 'id="selected-icon-menu-btn"'
assert_contains "$ui" 'id="selected-icon-regenerate"'
assert_matches "$ui" 'function setFooterStatus\(kind, msg\)'
assert_matches "$ui" 'function shouldShowFooterStatusForAction\(label, opts\)'
assert_matches "$ui" 'function buildActionLabel\(item\)'
assert_matches "$ui" 'function runActionLabel\(item\)'
assert_matches "$ui" 'function ranActionLabel\(item\)'
assert_matches "$ui" 'function regenerateSelectedIconAssets\(\)'
assert_matches "$ui" 'function normalizedCatalogId\(value\)'
assert_matches "$ui" 'workspaceIdSet\[wsId\][[:space:]]*=[[:space:]]*true'
assert_matches "$ui" 'return !workspaceIdSet\[appId\];'

# Backend actions should remain explicit and structured.
assert_matches "$ui" "backend\('run-workspace', \[item\.path, item\.context\]\);"
assert_matches "$ui" "backend\('rebuild-workspace', \[selected\.path, selected\.context\]\);"
assert_matches "$ui" "perform\('Import project folder'"
assert_matches "$ui" "backend\('import-workspace'"
assert_matches "$ui" "backend\('rename-workspace'"

# Native host icon-drop bridge contracts (allow variable renames in callsites).
assert_matches "$ui" "window\.forgeHostFileDrag[[:space:]]*=[[:space:]]*handleForgeHostFileDrag;"
assert_matches "$ui" "window\.forgeHostIconDropResult[[:space:]]*=[[:space:]]*finishNativeHostIconDrop;"
assert_matches "$ui" "argv[[:space:]]*=[[:space:]]*\['__wizardry_host_forge_icon_drop_target'\];"
assert_matches "$ui" 'function scheduleNativeHostIconDropFallback\([^)]*\)'
assert_matches "$ui" 'scheduleNativeHostIconDropFallback\([^,]+,[[:space:]]*file\);'
assert_matches "$ui" 'function markNativeHostIconDropHandled\(\)'
assert_matches "$ui" 'function nativeHostRecentlyHandledIconDrop\(\)'
assert_contains "$ui" 'public.file-url'
assert_contains "$ui" 'text/uri-list'
assert_contains "$ui" 'public.utf8-plain-text'

# Native host callback + drag payload contracts.
assert_contains "$host_macos" 'dispatchForgeHostCallbackNamed:@"forgeHostFileDrag"'
assert_contains "$host_macos" 'forgeHostIconDropResult'
assert_contains "$host_macos" '__wizardry_host_forge_icon_drop_target'
assert_contains "$host_macos" 'runForgeIconDropForPath'
assert_contains "$host_macos" 'NSPasteboardTypeFileURL'
assert_contains "$host_macos" '"public.file-url"'
assert_contains "$host_macos" '"text/uri-list"'
assert_contains "$host_macos" 'NSFilenamesPboardType'

printf '%s\n' "forge ui regression contracts passed"
