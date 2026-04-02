#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/apps/wizardry-desktop/index.html"
css="$root/apps/wizardry-desktop/style.css"

[ -f "$ui" ] || {
  printf '%s\n' "wizardry-desktop ui file missing: $ui" >&2
  exit 1
}
[ -f "$css" ] || {
  printf '%s\n' "wizardry-desktop css file missing: $css" >&2
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

assert_not_contains() {
  file=$1
  needle=$2
  if grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "unexpected contract text in $file: $needle" >&2
    exit 1
  fi
}

# Startup + composer stability contracts.
assert_contains "$ui" 'id="command-composer-toggle"'
assert_not_contains "$ui" 'id="action-refresh"'
assert_contains "$ui" 'id="command-composer-modal" class="wd-composer-modal wd-hidden"'
assert_contains "$ui" 'startupLock: true'
assert_contains "$ui" 'open: false'
assert_matches "$ui" 'function composerOpenWithTokens\(tokens, options\)'
assert_contains "$ui" 'setComposerOpen(true, { userInitiated: !!options.userInitiated });'
assert_contains "$ui" "composerOpenWithTokens([], { userInitiated: true, allowEmpty: true, seededDefaults: false });"
assert_contains "$ui" "setComposerOpen(false, { skipFocus: true });"
assert_contains "$ui" "document.addEventListener('visibilitychange'"
assert_not_contains "$ui" "Build validated wizardry commands from action blocks."
assert_not_contains "$ui" "Press <kbd>Enter</kbd> to add token or run"
assert_contains "$ui" "els.splash.hidden = true;"
assert_contains "$css" ".wd-splash-fade {"
assert_contains "$css" "pointer-events: none;"
assert_contains "$css" "var(--text-muted, var(--light-text, #334155))"
assert_contains "$css" "background: var(--wd-panel);"
assert_not_contains "$css" "background: #ffffff;"

# Navigation and listbox semantics.
assert_contains "$ui" "role=\"listbox\""
assert_contains "$ui" "role=\"option\""
assert_contains "$ui" "aria-selected=\""
assert_not_contains "$ui" "id: 'menus'"
assert_contains "$ui" "{ id: 'cast', title: 'Cast'"
assert_contains "$ui" "activePage: 'cast'"
assert_not_contains "$ui" "id: 'casting-watch'"
assert_contains "$ui" "DEFAULT_MAIN_MENU_ORDER"
assert_matches "$ui" "function loadMainMenuEntries\\(\\)"
assert_contains "$ui" "callBackend('list-main-menu-entries')"
assert_contains "$ui" "id=\"composer-arg-assistant\""
assert_matches "$ui" "function renderComposerArgAssistant\\(plan\\)"
assert_matches "$ui" "function parseComposerText\\(value\\)"
assert_matches "$ui" "function decodeComposerAssistArgs\\(value\\)"
assert_contains "$ui" "data-composer-assist-args"
assert_contains "$ui" "title=\"Wrap values in quotes to keep spaces in one token.\""
assert_contains "$ui" "title=\"Press Enter to add token, Shift+Enter to run current command.\""
assert_matches "$ui" "function loadSpellbookAliases\\(\\)"
assert_contains "$ui" "callBackend('list-synonyms')"
assert_not_contains "$ui" "<h3>Synonyms</h3>"
assert_not_contains "$ui" "Wizardry aliases"
assert_not_contains "$ui" "Desktop aliases"
assert_contains "$ui" "aria-label=\"Spellbook aliases\""
assert_contains "$ui" "callBackend('list-spells', [catId])"
assert_not_contains "$ui" "callBackend('list-spells', [kind, id])"
assert_matches "$ui" "function loadArcanaModuleItems\\(moduleName\\)"
assert_contains "$ui" "callBackend('list-arcana-module-items', [name])"
assert_contains "$ui" "data-arcana-module="
assert_matches "$ui" "function loadSystemMenuActions\\(\\)"
assert_contains "$ui" "callBackend('list-system-menu-actions')"
assert_contains "$ui" "data-system-menu-action="
assert_contains "$ui" "Mirrors the wizardry <code>system-menu</code> structure."
assert_matches "$ui" "function loadMudActions\\(\\)"
assert_contains "$ui" "callBackend('list-mud-actions')"
assert_contains "$ui" "callBackend('run-mud-action', [id, argValue])"
assert_contains "$ui" "data-mud-run-action="
assert_contains "$ui" "Play the MUD with the currently installed wizardry capabilities."

# Centralized theme and backend root contracts.
assert_matches "$ui" "buildThemeStylesheetHref\\(themeName\\)"
assert_contains "$ui" "/web/.themes/"
assert_contains "$ui" "function loadRootHint()"
assert_contains "$ui" "callBackend('root-hint')"
assert_contains "$ui" "workspaceMarker = '/wizardry-desktop/app/index.html'"
assert_not_contains "$ui" 'id="bridge-status"'
assert_not_contains "$ui" "card('Bridge'"
assert_contains "$css" "max-height: min(16rem, calc(100vh - var(--wd-host-top-inset) - 1.6rem));"
assert_contains "$css" "overflow: auto;"
assert_contains "$css" "#theme-list {"
assert_contains "$ui" "wd-theme-check"

# Activity drawer scrollability and layout contracts.
assert_contains "$ui" 'wd-activity-sections'
assert_contains "$ui" 'wd-activity-list wd-scroll-list wd-activity-list-scrolled'
assert_contains "$ui" "Command Output"
assert_contains "$css" '.wd-scroll-list'
assert_contains "$css" '.wd-activity-list'
assert_contains "$css" '.wd-rail-divider::before'
assert_contains "$css" 'cursor: col-resize;'
assert_not_contains "$css" '.wd-rail-divider:hover'

printf '%s\n' "wizardry-desktop ui contract tests passed"
