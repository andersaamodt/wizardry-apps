#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/apps/forge/index.html"
css="$root/apps/forge/style.css"
host_macos="$root/apps/.host/macos/main.m"

[ -f "$ui" ] || {
  printf '%s\n' "forge ui file missing: $ui" >&2
  exit 1
}
[ -f "$host_macos" ] || {
  printf '%s\n' "forge macOS host file missing: $host_macos" >&2
  exit 1
}
[ -f "$css" ] || {
  printf '%s\n' "forge css file missing: $css" >&2
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
assert_matches "$ui" 'function bridgeAvailable\(\)'
assert_matches "$ui" 'window\.wizardry\.nativeAvailable'
assert_contains "$ui" "'wizardry.forge.cached_workspaces.v2': 'cached_workspaces'"
assert_not_contains "$ui" "'wizardry.forge.cached_workspaces.v1': 'cached_workspaces'"
assert_not_contains "$ui" 'await runInitialBridgeBootstrap();'
assert_matches "$ui" 'function validThemeName\(value\)'
assert_matches "$ui" 'state\.themes\.push\(state\.activeTheme\);'
assert_matches "$ui" 'refreshWorkspaceInFlight:[[:space:]]*null'
assert_matches "$ui" 'if \(state\.refreshWorkspaceInFlight\)'
assert_matches "$ui" 'async function refreshWorkspaceNow\(options\)'
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
assert_matches "$ui" 'function workspaceCatalogKey\(workspace\)'
assert_matches "$ui" "return 'workspace-path:' \\+ normalizedPath;"
assert_matches "$ui" 'key:[[:space:]]*workspaceCatalogKey\(ws\)'
assert_matches "$ui" "state\\.selectedCatalog\\.indexOf\\('workspace:'\\)[[:space:]]*===[[:space:]]*0"
assert_contains "$ui" 'catalog-git-pill'
assert_matches "$ui" 'function setDownloadedAppVisibleState\(appId, exists\)'
assert_matches "$ui" 'setDownloadedAppVisibleState\(item\.id, false\);'
assert_matches "$ui" "backend\('hide-workspace', \[removedPath\]"
assert_matches "$ui" "backend\('unhide-workspace', \[out\.workspace\]"
assert_matches "$ui" "backend\('unhide-workspace', \[out\.registered_path\]"
assert_matches "$ui" "backend\('unhide-workspace', \[out\.created\]"
assert_contains "$ui" "successLabel: item.title + ' removed from Forge.'"
assert_contains "$ui" "state.activeCatalogRowMenuKey = '';"
assert_matches "$ui" '^[[:space:]]*renderCatalogList\(\);$'
assert_matches "$ui" '^[[:space:]]*handler\(\);$'
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
assert_contains "$ui" 'Native Mobile App'
assert_contains "$ui" 'canonical native UI definition'
assert_contains "$ui" 'shared native mobile UI definition'
assert_contains "$ui" 'Canonical UI definition path'
assert_not_contains "$ui" 'canonical native UI IR'
assert_not_contains "$ui" 'shared native mobile IR'
assert_not_contains "$ui" 'Canonical IR path'
assert_contains "$ui" 'value="native-desktop"'
assert_contains "$ui" 'value="native-mobile"'
assert_matches "$ui" 'function nativeMobileProjectTypeKey\(\)'
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

footer_bar_overflow=$(awk '
  /^\.footer-bar[[:space:]]*\{/ { in_rule=1 }
  in_rule && /overflow:[[:space:]]*visible;/ { found=1 }
  in_rule && /^}/ { in_rule=0 }
  END { if (found) print "yes" }
' "$css")
[ "$footer_bar_overflow" = "yes" ] || {
  printf '%s\n' "Forge footer bar must allow the theme menu to escape its bounds" >&2
  exit 1
}

theme_button_fit=$(awk '
  /^\.footer-theme-btn[[:space:]]*\{/ { in_rule=1 }
  in_rule && /width:[[:space:]]*max-content;/ { width=1 }
  in_rule && /min-width:[[:space:]]*max-content;/ { min_width=1 }
  in_rule && /max-width:[[:space:]]*calc\(var\(--left-rail-width/ { max_width=1 }
  in_rule && /flex:[[:space:]]*0 1 auto;/ { flex=1 }
  in_rule && /^}/ { in_rule=0 }
  END { if (width && min_width && max_width && flex) print "yes" }
' "$css")
[ "$theme_button_fit" = "yes" ] || {
  printf '%s\n' "Forge theme selector must fit normal theme labels within the rail" >&2
  exit 1
}

row_menu_clickable=$(awk '
  /^\.catalog-row\.menu-open[[:space:]]*\{/ { in_row=1 }
  in_row && /position:[[:space:]]*relative;/ { row_position=1 }
  in_row && /z-index:[[:space:]]*40;/ { row_z=1 }
  in_row && /^}/ { in_row=0 }
  /^\.catalog-row-menu[[:space:]]*\{/ { in_menu=1 }
  in_menu && /position:[[:space:]]*fixed;/ { menu_fixed=1 }
  in_menu && /display:[[:space:]]*grid;/ { menu_grid=1 }
  in_menu && /-webkit-app-region:[[:space:]]*no-drag;/ { menu_no_drag=1 }
  in_menu && /pointer-events:[[:space:]]*auto;/ { menu_pointer=1 }
  in_menu && /z-index:[[:space:]]*10000[[:space:]]*!important;/ { menu_z=1 }
  in_menu && /^}/ { in_menu=0 }
  /^\.catalog-row-menu\.hidden[[:space:]]*\{/ { in_hidden=1 }
  in_hidden && /display:[[:space:]]*none;/ { menu_hidden=1 }
  in_hidden && /^}/ { in_hidden=0 }
  END { if (row_position && row_z && menu_fixed && menu_grid && menu_no_drag && menu_pointer && menu_z && menu_hidden) print "yes" }
' "$css")
[ "$row_menu_clickable" = "yes" ] || {
  printf '%s\n' "Forge row overflow menus must render as fixed top-layer portals" >&2
  exit 1
}

if rg -q "rowMenu\\.className = 'floating-menu catalog-row-menu" "$ui"; then
  printf '%s\n' "Forge row overflow menus must not use the shared floating-menu hit-test path" >&2
  exit 1
fi

if ! rg -q "!state\\.inlineRenameKey && !state\\.activeCatalogRowMenuKey && !item\\.draft" "$ui"; then
  printf '%s\n' "Forge rows must not stay draggable while an overflow menu is open" >&2
  exit 1
fi

if rg -q "row\\.setAttribute\\('role', 'button'\\)" "$ui"; then
  printf '%s\n' "Forge catalog rows must not use a button role around nested action buttons" >&2
  exit 1
fi

if ! rg -q "button\\.addEventListener\\('pointerdown', runRowMenuAction\\)" "$ui"; then
  printf '%s\n' "Forge row overflow actions must fire on pointerdown before WebKit can retarget the click" >&2
  exit 1
fi

if ! rg -q "button\\.forgeRunRowMenuAction = runRowMenuAction" "$ui" || ! rg -q "button\\.addEventListener\\('mousedown', runRowMenuAction\\)" "$ui"; then
  printf '%s\n' "Forge row overflow actions must expose a direct handler for routed native events" >&2
  exit 1
fi

if ! rg -q "function stopRowMenuEvent" "$ui" || ! rg -q "stopImmediatePropagation" "$ui"; then
  printf '%s\n' "Forge row overflow triggers must stop row and splitter event handling directly" >&2
  exit 1
fi

if ! rg -q "rowMenuBtn\\.addEventListener\\('pointerdown', toggleRowMenu\\)" "$ui" || ! rg -q "rowMenuBtn\\.addEventListener\\('mousedown', toggleRowMenu\\)" "$ui" || ! rg -q "rowMenuBtn\\.addEventListener\\('click', toggleRowMenu\\)" "$ui"; then
  printf '%s\n' "Forge row overflow triggers must fire on pointerdown, mousedown, and click" >&2
  exit 1
fi

if ! rg -q "function routeCatalogRowMenuPointer" "$ui" || ! rg -q "button\\.forgeRunRowMenuAction\\(event\\)" "$ui"; then
  printf '%s\n' "Forge row overflow clicks must be routed from the visible menu rectangle during capture" >&2
  exit 1
fi

if ! rg -q "rowMenuPointerHandledUntil" "$ui"; then
  printf '%s\n' "Forge row overflow trigger routing must suppress repeated native events from one gesture" >&2
  exit 1
fi

if rg -q "function routeCatalogRowOverflowPointer" "$ui"; then
  printf '%s\n' "Forge row overflow triggers should not rely on document-capture hit testing" >&2
  exit 1
fi

if ! rg -q "document\\.addEventListener\\('pointerdown'" "$ui" || ! rg -q "document\\.addEventListener\\('mousedown'" "$ui"; then
  printf '%s\n' "Forge row overflow routing must capture pointerdown and mousedown, not only click" >&2
  exit 1
fi

if rg -q "rowActions\\.appendChild\\(rowMenu\\)" "$ui"; then
  printf '%s\n' "Forge row overflow menus must not be inserted inline into catalog rows" >&2
  exit 1
fi

if ! rg -q "function renderCatalogRowMenuPortal" "$ui" || ! rg -q "document\\.body\\.appendChild\\(menu\\)" "$ui"; then
  printf '%s\n' "Forge row overflow menus must be rendered through a document-level portal" >&2
  exit 1
fi

if ! rg -q "padding: 0 0\\.62rem 0 0\\.4rem" "$css" || ! rg -q "width: 1\\.5rem" "$css"; then
  printf '%s\n' "Forge row overflow triggers must stay inset from the splitter with a stable hit target" >&2
  exit 1
fi

boot_reveal_line=$(awk '/async function boot\(\)/{in_boot=1} in_boot && /revealBootUi\(\);/{print NR; exit}' "$ui")
boot_bridge_line=$(awk '/async function boot\(\)/{in_boot=1} in_boot && /runInitialBridgeBootstrap\(\);/{print NR; exit}' "$ui")
boot_load_themes_before_reveal=$(awk '
  /async function boot\(\)/ { in_boot=1 }
  in_boot && /revealBootUi\(\);/ { exit }
  in_boot && /await loadThemes\(\);/ { found=1 }
  END { if (found) print "yes" }
' "$ui")
[ -n "$boot_reveal_line" ] && [ -n "$boot_bridge_line" ] && [ "$boot_reveal_line" -lt "$boot_bridge_line" ] || {
  printf '%s\n' "Forge startup should reveal cached UI before bridge bootstrap" >&2
  exit 1
}
[ -z "$boot_load_themes_before_reveal" ] || {
  printf '%s\n' "Forge startup should not wait for theme discovery before splash handoff" >&2
  exit 1
}

printf '%s\n' "forge ui regression contracts passed"
