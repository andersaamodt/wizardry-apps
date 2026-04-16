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

assert_not_contains() {
  file=$1
  needle=$2
  if grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "unexpected contract text present in $file: $needle" >&2
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
assert_contains "$ui" 'id="workspace-git-section"'
assert_contains "$ui" 'id="workspace-git-form"'
assert_contains "$ui" 'id="workspace-git-status"'
assert_matches "$ui" 'function setFooterStatus\(kind, msg\)'
assert_matches "$ui" 'function shouldShowFooterStatusForAction\(label, opts\)'
assert_matches "$ui" 'function buildActionLabel\(item\)'
assert_matches "$ui" 'function runActionLabel\(item\)'
assert_matches "$ui" 'function ranActionLabel\(item\)'
assert_matches "$ui" 'function regenerateSelectedIconAssets\(\)'
assert_matches "$ui" 'function parseInstallBeforeRunPrefs\(raw\)'
assert_matches "$ui" 'function installBeforeRunPreferenceForSelected\(selected\)'
assert_matches "$ui" 'return selected\.kind === '"'"'workspace'"'"' && selected\.context !== '"'"'godot'"'"';'
assert_matches "$ui" 'assignmentKeysForItem\(selected\)'
assert_matches "$ui" 'state\.installBeforeRunByItemKey\[keys\[0\]\][[:space:]]*=[[:space:]]*!!enabled;'
assert_not_contains "$ui" 'installBeforeRunHasUserPref'
assert_matches "$ui" 'function hostTargetId\(\)'
assert_matches "$ui" 'function renderWorkspaceGitEditor\(selected\)'
assert_matches "$ui" 'function saveWorkspaceGitRemote\(selected, value\)'
assert_matches "$ui" 'function saveWorkspaceGitBranch\(selected, value\)'
assert_contains "$ui" "runWorkspaceGitCommand(selected, 'Fetch git remote', 'workspace-git-fetch'"
assert_contains "$ui" "runWorkspaceGitCommand(selected, 'Pull and rebuild workspace', 'workspace-git-pull'"
assert_contains "$ui" "runWorkspaceGitCommand(selected, 'Push workspace branch', 'workspace-git-push'"
assert_contains "$ui" "runWorkspaceGitCommand(selected, 'Install latest release', 'workspace-git-install-release'"
assert_matches "$ui" 'parseTSV\(res\.stdout \|\| '"'"''"'"', 13\)'
assert_matches "$ui" 'parseTSV\(res\.stdout \|\| '"'"''"'"', 17\)'
assert_matches "$ui" 'function buildCatalogGitPill\(item\)'
assert_contains "$ui" 'catalog-git-pill'
assert_matches "$ui" 'navigator\.platform'
assert_matches "$ui" 'runtimePlatform\.indexOf\('"'"'mac'"'"'\)[[:space:]]*>=[[:space:]]*0'
assert_matches "$ui" "__wizardry_host_restart_self"

# Backend actions should remain explicit and structured.
assert_matches "$ui" "backend\('run-workspace', \[item\.path, item\.context, runMode\]\);"
assert_matches "$ui" "backend\('install-workspace', \[selected\.path, selected\.context, targetId\]\);"
assert_matches "$ui" "selected\.kind === 'workspace' && canInstallHostTargetForSelected\(selected\)"
assert_matches "$ui" "backend\('rebuild-workspace', \[selected\.path, selected\.context\]\);"
assert_matches "$ui" "perform\('Import project folder'"
assert_matches "$ui" "backend\('import-workspace'"
assert_matches "$ui" "backend\('rename-workspace'"
assert_contains "$ui" 'Cross-Platform App'
assert_contains "$ui" 'Native Desktop App'
assert_contains "$ui" 'value="native-desktop"'
assert_matches "$ui" "function nativeDesktopProjectTypeKey\(\)"
assert_matches "$ui" "function createProjectTypeConfig\(projectType\)"

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
assert_contains "$host_macos" '__wizardry_host_restart_self'
assert_contains "$host_macos" 'if (launchedFromPackagedBundle && resolvedBundleIcon)'
assert_contains "$host_macos" 'else if (resolvedFileIcon)'
assert_contains "$host_macos" '[NSApp setApplicationIconImage:resolvedBundleIcon];'

printf '%s\n' "forge ui regression contracts passed"
