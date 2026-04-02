#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/apps/wizardry-desktop/index.html"
backend="$root/apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh"

[ -f "$ui" ] || {
  printf '%s\n' "wizardry-desktop ui file missing: $ui" >&2
  exit 1
}
[ -f "$backend" ] || {
  printf '%s\n' "wizardry-desktop backend file missing: $backend" >&2
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

# Backend menu metadata + terminal launch contract.
assert_contains "$backend" "list-menu-spells [ROOT_HINT]"
assert_contains "$backend" "list-main-menu-entries [ROOT_HINT]"
assert_contains "$backend" "list-system-menu-actions [ROOT_HINT]"
assert_contains "$backend" "list-mud-actions [ROOT_HINT]"
assert_contains "$backend" "open-menu-terminal MENU_NAME [MENU_ARG] [ROOT_HINT]"
assert_contains "$backend" "run-mud-action ACTION [ARG] [ROOT_HINT]"
assert_matches "$backend" 'menu_argument_spec\(\)'
assert_matches "$backend" 'cmd_open_menu_terminal\(\)'
assert_matches "$backend" 'cmd_run_mud_action\(\)'
assert_matches "$backend" 'run-action ACTION \[ARG1\] \[ARG2\] \[ROOT_HINT\]'
assert_contains "$backend" "menu:terminal)"
assert_contains "$backend" "open-menu-terminal)"

# UI interactions for menu actions in command composer.
assert_matches "$ui" "function menuRowByName\\(name\\)"
assert_matches "$ui" "function renderComposerArgAssistant\\(plan\\)"
assert_matches "$ui" "function parseComposerText\\(value\\)"
assert_matches "$ui" "function collectComposerAssistEntries\\(plan\\)"
assert_matches "$ui" "function routeMenuActionToGui\\(actionName, params\\)"
assert_matches "$ui" "function runSystemMenuAction\\(actionId, options\\)"
assert_matches "$ui" "function runMudAction\\(actionId, actionArg, options\\)"
assert_contains "$ui" "data-composer-assist-token"
assert_contains "$ui" "data-composer-assist-args"
assert_contains "$ui" "'menu:terminal': { label: 'Open menu in terminal'"
assert_matches "$ui" "tokens: \\['run-action', 'menu:terminal'"
assert_matches "$ui" "tokens: \\['run-system', 'system:restart-menu'"
assert_contains "$ui" "data-system-menu-action="
assert_contains "$ui" "menu:run cast routed to Cast tab"
assert_matches "$ui" "callBackend\\('run-action', actionArgs\\)"

printf '%s\n' "wizardry-desktop menus interaction contracts passed"
