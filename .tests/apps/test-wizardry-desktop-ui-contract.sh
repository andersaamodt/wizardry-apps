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
assert_contains "$ui" 'id="command-composer-modal" class="wd-composer-modal wd-hidden"'
assert_contains "$ui" 'startupLock: true'
assert_contains "$ui" 'open: false'
assert_matches "$ui" 'function composerOpenWithTokens\(tokens, options\)'
assert_contains "$ui" 'setComposerOpen(true, { userInitiated: !!options.userInitiated });'
assert_contains "$ui" "setComposerOpen(false, { skipFocus: true });"
assert_contains "$ui" "document.addEventListener('visibilitychange'"

# Navigation and listbox semantics.
assert_contains "$ui" "role=\"listbox\""
assert_contains "$ui" "role=\"option\""
assert_contains "$ui" "aria-selected=\""
assert_contains "$ui" "{ id: 'cast', title: 'Cast'"
assert_not_contains "$ui" "id: 'casting-watch'"

# Centralized theme and backend root contracts.
assert_matches "$ui" "buildThemeStylesheetHref\\(themeName\\)"
assert_contains "$ui" "/web/.themes/"
assert_contains "$ui" "function loadRootHint()"
assert_contains "$ui" "callBackend('root-hint')"
assert_contains "$ui" "workspaceMarker = '/wizardry-desktop/app/index.html'"

# Activity drawer scrollability and layout contracts.
assert_contains "$ui" 'wd-activity-sections'
assert_contains "$ui" 'wd-activity-list wd-scroll-list wd-activity-list-scrolled'
assert_contains "$css" '.wd-scroll-list'
assert_contains "$css" '.wd-activity-list'

printf '%s\n' "wizardry-desktop ui contract tests passed"
