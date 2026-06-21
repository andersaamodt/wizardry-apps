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
assert_contains "$ui" "Install xcodegen through Wizardry, then retry."
assert_contains "$ui" "/.wizardry/spells/.arcana/wizardry-apps/install-xcodegen"
assert_not_contains "$ui" "brew', 'install', 'xcodegen'"
assert_not_contains "$ui" "Install xcodegen (requires Homebrew)"
assert_matches "$ui" 'function hasEnabledMobileRunTarget\(selected\)'
assert_matches "$ui" 'function defaultMobileRunTargetForSelected\(selected\)'
assert_contains "$ui" 'hasEnabledHostRunTarget(selected) || hasEnabledHostedWebTarget(selected) || hasEnabledMobileRunTarget(selected)'
assert_contains "$ui" "await runTargetAction(selected, mobileTarget);"
assert_contains "$ui" "Build ' + (mobileRunTarget === 'ios' ? 'iOS' : 'Android') + ' app"
assert_contains "$ui" "project sources were generated. Build or run them from the platform toolchain, simulator, emulator, or device."
assert_contains "$ui" "mobileOut.message"
assert_contains "$ui" "setPanel('settings', false);"
assert_matches "$ui" 'function regenerateSelectedIconAssets\(\)'
assert_matches "$ui" 'function parseInstallBeforeRunPrefs\(raw\)'
assert_matches "$ui" 'function installBeforeRunPreferenceForSelected\(selected\)'
assert_matches "$ui" 'function isWorkspaceBackedBuiltIn\(item\)'
assert_matches "$ui" 'function usesWorkspacePipeline\(item\)'
assert_contains "$ui" 'renderSelectedTargetsEditor(selected);'
assert_contains "$ui" 'artificer: true'
assert_matches "$ui" 'return usesWorkspacePipeline\(selected\) && selected\.context !== '"'"'godot'"'"';'
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
assert_not_contains "$ui" "if (a === 'psionic')"
assert_not_contains "$ui" "if (b === 'psionic')"
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
assert_matches "$ui" 'parseTSV\(res\.stdout \|\| '"'"''"'"', 14\)'
assert_matches "$ui" 'parseTSV\(res\.stdout \|\| '"'"''"'"', 18\)'
assert_matches "$ui" 'function buildCatalogGitPill\(item\)'
assert_matches "$ui" 'function buildCatalogGitPrivacyIcon\(item\)'
assert_contains "$ui" 'catalog-git-privacy-icon'
assert_contains "$ui" 'Private repository'
assert_matches "$ui" 'function workspaceCatalogKey\(workspace\)'
assert_matches "$ui" 'function builtInCatalogPathSet\(\)'
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
assert_contains "$ui" "setActiveCatalogRowMenuKey('');"
assert_matches "$ui" '^[[:space:]]*renderCatalogList\(\);$'
assert_matches "$ui" '^[[:space:]]*closeCatalogRowMenu\(\);$'
assert_matches "$ui" '^[[:space:]]*handler\(\);$'
assert_matches "$ui" 'navigator\.platform'
assert_matches "$ui" 'runtimePlatform\.indexOf\('"'"'mac'"'"'\)[[:space:]]*>=[[:space:]]*0'
assert_matches "$ui" "__wizardry_host_restart_self"
assert_matches "$ui" 'function forgeCanBackgroundRefresh\(\)'
assert_matches "$ui" "document\.hidden"
assert_matches "$ui" "document\.hasFocus\(\)"
assert_matches "$ui" "suppressTransientRefresh\(90000\);"
assert_not_contains "$ui" 'state.autoRefreshTimer = setInterval(function () {'
assert_contains "$css" '.target-install-before-run:has(input:disabled) {'
assert_contains "$css" 'cursor: not-allowed;'

# Backend actions should remain explicit and structured.
assert_matches "$ui" "backend\('run-workspace', \[item\.path, item\.context, runMode\]\);"
assert_matches "$ui" "backend\('install-workspace', \[selected\.path, selected\.context, targetId\]\);"
assert_matches "$ui" "usesWorkspacePipeline\\(selected\\) \\|\\| \\(selected\\.kind !== 'builtin' && !!selected\\.path\\)"
assert_matches "$ui" "backend\('rebuild-workspace', \[selected\.path, selected\.context\]\);"
assert_not_contains "$ui" "if (selected.kind === 'builtin') {\n          return true;\n        }"
assert_not_contains "$ui" "if (state.os === 'darwin' && selected.context === 'native-desktop') {\n          return true;\n        }"
assert_matches "$ui" "perform\('Import project folder'"
assert_matches "$ui" "backend\('import-workspace'"
assert_matches "$ui" "backend\('rename-workspace'"
assert_contains "$ui" 'Cross-Platform App'
assert_contains "$ui" 'Native Desktop App'
assert_contains "$ui" 'Native Mobile App'
assert_contains "$ui" 'Wizardry Cross-Platform Theurgy Reference App'
assert_contains "$ui" 'stronger runtime boundaries and professional-scale behavior'
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
assert_contains "$ui" "return 'Prepared ' + itemStatusName(item);"
assert_contains "$ui" "mobilePrepared ? 'ready' : 'built'"
assert_contains "$ui" 'Open Generated Project'
assert_contains "$ui" 'project sources were generated. Build or run them from the platform toolchain, simulator, emulator, or device.'

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

footer_status_single_divider=$(awk '
  /^\.footer-status[[:space:]]*\{/ { in_rule=1 }
  in_rule && /border-left:[[:space:]]*0;/ { no_left_border=1 }
  in_rule && /^}/ { in_rule=0 }
  END { if (no_left_border) print "yes" }
' "$css")
[ "$footer_status_single_divider" = "yes" ] || {
  printf '%s\n' "Forge footer status must not draw a second divider next to the theme selector" >&2
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

if ! rg -q "function prepareCatalogRowDrag" "$ui" || ! rg -q "isCatalogRowControlTarget\\(event\\.target\\)" "$ui" || ! rg -q "row\\.setAttribute\\('draggable', 'true'\\)" "$ui"; then
  printf '%s\n' "Forge rows must only become draggable from non-control row presses" >&2
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

if rg -q "rowMenuBtn\\.disabled = state\\.busy" "$ui"; then
  printf '%s\n' "Forge row overflow triggers must open even while background work is busy" >&2
  exit 1
fi

if ! rg -q "rowMenuBtn\\.addEventListener\\('click', toggleRowMenuFromClick\\)" "$ui"; then
  printf '%s\n' "Forge row overflow triggers must open on the browser-native click event" >&2
  exit 1
fi

if ! rg -q "function setActiveCatalogRowMenuKey" "$ui" || ! rg -q "function renderActiveCatalogRowMenuPortal" "$ui" || ! rg -q "function closeCatalogRowMenu" "$ui"; then
  printf '%s\n' "Forge row overflow menu state must update through direct lightweight helpers" >&2
  exit 1
fi

if ! awk '
  /function toggleRowMenu\(event\)/ { in_toggle=1; depth=0 }
  in_toggle {
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (/renderActiveCatalogRowMenuPortal\(\);/) { direct=1 }
    if (/renderCatalogList\(\);/) { full_render=1 }
    if (in_toggle && depth == 0) { in_toggle=0 }
  }
  END { exit (direct && !full_render) ? 0 : 1 }
' "$ui"; then
  printf '%s\n' "Forge row overflow triggers must open the portal directly without a full catalog render" >&2
  exit 1
fi

if rg -q "activeCatalogRowMenuKey === item\\.key \\? 'menu' : 'closed'" "$ui"; then
  printf '%s\n' "Forge row overflow open state must not force catalog row rebuilds" >&2
  exit 1
fi

if ! rg -q "rowActions\\.setAttribute\\('draggable', 'false'\\)" "$ui" || ! rg -q "rowMenuBtn\\.setAttribute\\('draggable', 'false'\\)" "$ui" || ! rg -q "play\\.setAttribute\\('draggable', 'false'\\)" "$ui"; then
  printf '%s\n' "Forge row action buttons must opt out of draggable row behavior" >&2
  exit 1
fi

if ! rg -q "width: 1\\.5rem" "$css" || ! rg -q "height: 1\\.5rem" "$css"; then
  printf '%s\n' "Forge row overflow must keep the compact visible button size" >&2
  exit 1
fi

if ! awk '
  /^\.left-rail[[:space:]]*\{/ { in_left=1 }
  in_left && /-webkit-app-region:[[:space:]]*no-drag;/ { left_no_drag=1 }
  in_left && /^}/ { in_left=0 }
  /^\.apps-list-card[[:space:]]*\{/ { in_card=1 }
  in_card && /-webkit-app-region:[[:space:]]*no-drag;/ { card_no_drag=1 }
  in_card && /^}/ { in_card=0 }
  /^\.catalog-list[[:space:]]*\{/ { in_list=1 }
  in_list && /-webkit-app-region:[[:space:]]*no-drag;/ { list_no_drag=1 }
  in_list && /^}/ { in_list=0 }
  /^\.catalog-row-actions[[:space:]]*\{/ { in_actions=1 }
  in_actions && /-webkit-app-region:[[:space:]]*no-drag;/ { actions_no_drag=1 }
  in_actions && /^}/ { in_actions=0 }
  /^\.row-overflow[[:space:]]*\{/ { in_overflow=1 }
  in_overflow && /-webkit-app-region:[[:space:]]*no-drag;/ { overflow_no_drag=1 }
  in_overflow && /^}/ { in_overflow=0 }
  END { exit (left_no_drag && card_no_drag && list_no_drag && actions_no_drag && overflow_no_drag) ? 0 : 1 }
' "$css"; then
  printf '%s\n' "Forge left catalog and row controls must not be native drag regions" >&2
  exit 1
fi

if rg -q "button:active[[:space:]]*\\{" "$css" || rg -q "transform:[[:space:]]*translateY\\(1px\\)" "$css"; then
  printf '%s\n' "Forge buttons must not move on press" >&2
  exit 1
fi

if rg -q "function isCatalogRowMenuGutterClick" "$ui" || rg -q "trigger\\.click\\(\\)" "$ui"; then
  printf '%s\n' "Forge row overflow must not use coordinate-based row fallback clicks" >&2
  exit 1
fi

if awk '
  /function setBusy\(flag\)/ { in_busy=1; depth=0 }
  in_busy {
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (/querySelectorAll\(/ && /\.row-overflow/) { disables_overflow=1 }
    if (in_busy && depth == 0) { in_busy=0 }
  }
  END { exit disables_overflow ? 0 : 1 }
' "$ui"; then
  printf '%s\n' "Forge row overflow triggers must stay enabled while Forge is busy so the menu never becomes inert" >&2
  exit 1
fi

if ! rg -q "function eventHitsRowMenuButton" "$ui" || ! rg -q "hitSlop = 8" "$ui" || ! rg -q "playRect\\.right \\+ 2" "$ui" || ! rg -q "rowActions\\.addEventListener\\('pointerdown', toggleRowMenuFromActions\\)" "$ui"; then
  printf '%s\n' "Forge row overflow must have a tight invisible hit zone around the compact button without stealing Run clicks" >&2
  exit 1
fi

if ! rg -q "function isCatalogRowControlTarget" "$ui" || ! rg -q "isCatalogRowControlTarget\\(event\\.target\\)" "$ui"; then
  printf '%s\n' "Forge row selection must ignore clicks from row action controls" >&2
  exit 1
fi

if rg -q "function routeCatalogRowOverflowClick" "$ui" || rg -q "function eventHitsCatalogRowOverflowZone" "$ui" || rg -q "toggleRowMenuFromRowHit" "$ui" || rg -q "rowRect\\.right - 44" "$ui" || rg -q "rowRect\\.right - 220" "$ui"; then
  printf '%s\n' "Forge row overflow triggers must not use broad document or row-edge hit-test fallbacks" >&2
  exit 1
fi

if ! rg -q "rowMenuBtn\\.addEventListener\\('pointerdown', toggleRowMenuFromPress\\)" "$ui" || ! rg -q "rowMenuBtn\\.addEventListener\\('mousedown', toggleRowMenuFromPress\\)" "$ui"; then
  printf '%s\n' "Forge row overflow triggers must open on early press events because WebKit can lose the completed click" >&2
  exit 1
fi

if ! rg -q "function consumeSuppressedCatalogDocumentEvent" "$ui" || ! rg -q "state\\.suppressNextCatalogDocumentClick = true" "$ui" || ! rg -q "event\\.type !== 'pointerdown'" "$ui" || ! rg -q "consumeSuppressedCatalogDocumentEvent\\(event\\)" "$ui"; then
  printf '%s\n' "Forge row overflow press-open must suppress follow-up pointerdown/mousedown/click events after rerender" >&2
  exit 1
fi

if ! rg -q "function routeCatalogRowMenuPointer" "$ui" || ! rg -q "button\\.forgeRunRowMenuAction\\(event\\)" "$ui"; then
  printf '%s\n' "Forge row overflow actions must be routed from the visible menu rectangle when native hit testing retargets the event" >&2
  exit 1
fi

if ! rg -q "function routeCatalogRowOverflowPointer" "$ui" || ! rg -q "document\\.querySelectorAll\\('\\.row-overflow'\\)" "$ui" || ! rg -q "button\\.forgeToggleRowMenuFromPointer\\(event\\)" "$ui"; then
  printf '%s\n' "Forge row overflow trigger routing must use exact visible button rectangles when native hit testing retargets the event" >&2
  exit 1
fi

if ! rg -q "event\\.type !== 'pointerup'" "$ui" && ! rg -q "event\\.type !== 'mouseup'" "$ui"; then
  if ! awk '
    /function routeCatalogRowOverflowPointer\(event\)/ { in_route=1; depth=0 }
    in_route {
      depth += gsub(/\{/, "{")
      depth -= gsub(/\}/, "}")
      if (/event\.type !== '\''pointerdown'\'' && event\.type !== '\''mousedown'\'' && event\.type !== '\''click'\''/) { guarded=1 }
      if (in_route && depth == 0) { in_route=0 }
    }
    END { exit guarded ? 0 : 1 }
  ' "$ui"; then
    printf '%s\n' "Forge row overflow trigger routing must ignore release events so one click cannot immediately close the menu" >&2
    exit 1
  fi
fi

if ! rg -q "appendAction\\('Rename', function \\(\\)" "$ui" || ! rg -q "setTimeout\\(function \\(\\)" "$ui" || ! rg -q "state\\.inlineRenameKey = item\\.key" "$ui"; then
  printf '%s\n' "Forge row menu Rename must defer inline edit until after the physical click finishes" >&2
  exit 1
fi

if ! rg -q "\\['pointerdown', 'pointerup', 'mousedown', 'mouseup', 'click'\\]\\.forEach" "$ui" || ! rg -q "document\\.addEventListener\\(eventName" "$ui"; then
  printf '%s\n' "Forge row overflow menu routing must catch down/up/click retargeting" >&2
  exit 1
fi

if ! rg -q "button\\.addEventListener\\('pointerup', runRowMenuAction\\)" "$ui" || ! rg -q "button\\.addEventListener\\('mouseup', runRowMenuAction\\)" "$ui"; then
  printf '%s\n' "Forge row menu actions must also fire on release events in the native host" >&2
  exit 1
fi

if ! awk '
  /document\.addEventListener\(eventName/ { in_listener=1; route_line=0; suppress_line=0 }
  in_listener && /routeCatalogRowMenuPointer\(event\)/ && !route_line { route_line=NR }
  in_listener && /consumeSuppressedCatalogDocumentEvent\(event\)/ && !suppress_line { suppress_line=NR }
  in_listener && /}, true\);/ {
    if (route_line && suppress_line && route_line < suppress_line) found=1
    in_listener=0
  }
  END { exit found ? 0 : 1 }
' "$ui"; then
  printf '%s\n' "Forge row menu actions must route before press-open suppression can swallow them" >&2
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

if ! rg -q "function activeCatalogRowMenuPortal" "$ui" || ! rg -q "state\\.activeCatalogRowMenuKey === item\\.key && activeCatalogRowMenuPortal\\(\\)" "$ui"; then
  printf '%s\n' "Forge row overflow toggles must treat a missing menu portal as closed" >&2
  exit 1
fi

if ! awk '
  /function renderCatalogRowMenuPortal\(visibleItems\)/ { in_render=1; depth=0 }
  in_render {
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (/if \(!trigger\)/) { in_no_trigger=1 }
    if (in_no_trigger && /setActiveCatalogRowMenuKey\('\'''\''\);/) { clears_missing_trigger=1; in_no_trigger=0 }
    if (/if \(!menu\)/) { in_no_menu=1 }
    if (in_no_menu && /setActiveCatalogRowMenuKey\('\'''\''\);/) { clears_missing_menu=1; in_no_menu=0 }
    if (in_render && depth == 0) { in_render=0 }
  }
  END { exit (clears_missing_trigger && clears_missing_menu) ? 0 : 1 }
' "$ui"; then
  printf '%s\n' "Forge row overflow portal rendering must clear stale open state when the trigger or menu disappears" >&2
  exit 1
fi

if ! awk '
  /function refreshIsSuppressed\(\)/ { in_refresh=1; depth=0 }
  in_refresh {
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (/activeCatalogRowMenuPortal\(\)/) { pauses_for_menu=1 }
    if (in_refresh && depth == 0) { in_refresh=0 }
  }
  END { exit pauses_for_menu ? 0 : 1 }
' "$ui"; then
  printf '%s\n' "Forge background refresh must pause while a row overflow menu is visibly open" >&2
  exit 1
fi

if ! rg -q "padding: 0 0\\.62rem 0 0\\.4rem" "$css" || ! rg -q "padding: 0;" "$css"; then
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

if ! rg -q "bridgePrefsHydrated: false" "$ui" || ! rg -q "state\\.bridgePrefsHydrated = true" "$ui"; then
  printf '%s\n' "Forge startup must track when bridge prefs are already hydrated" >&2
  exit 1
fi

if ! awk '
  /async function runInitialBridgeBootstrap\(\)/ { in_bootstrap=1 }
  in_bootstrap && /if \(!state\.bridgePrefsHydrated\)/ { guarded=1 }
  in_bootstrap && /await hydratePrefsFromBackend\(\);/ && guarded { hydrate_after_guard=1 }
  in_bootstrap && /loadCatalogCachesFromStorage\(\);/ && guarded { cache_after_guard=1 }
  in_bootstrap && /await refreshWorkspace\(\{ quiet: true \}\);/ { exit }
  END { exit !(guarded && hydrate_after_guard && cache_after_guard) }
' "$ui"; then
  printf '%s\n' "Forge bridge bootstrap must not replay cached prefs over already-clickable startup minitabs" >&2
  exit 1
fi

printf '%s\n' "forge ui regression contracts passed"
