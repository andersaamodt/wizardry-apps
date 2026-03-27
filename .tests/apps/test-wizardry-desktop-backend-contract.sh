#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh"

[ -f "$backend" ] || {
  printf '%s\n' "wizardry-desktop backend missing: $backend" >&2
  exit 1
}

sh -n "$backend"

root_hint=$(sh "$backend" root-hint "$root" | head -n 1 | tr -d '\r')
[ "$root_hint" = "$root" ] || {
  printf '%s\n' "root-hint mismatch: expected $root got $root_hint" >&2
  exit 1
}

themes=$(sh "$backend" list-themes "$root")
printf '%s\n' "$themes" | grep -F "adept" >/dev/null 2>&1 || {
  printf '%s\n' "list-themes missing adept" >&2
  exit 1
}

categories=$(sh "$backend" list-spell-categories "$root")
printf '%s\n' "$categories" | grep -F "builtin:cantrips|" >/dev/null 2>&1 || {
  printf '%s\n' "list-spell-categories missing builtin:cantrips" >&2
  exit 1
}
printf '%s\n' "$categories" | grep -F "builtin:web|" >/dev/null 2>&1 || {
  printf '%s\n' "list-spell-categories missing builtin:web" >&2
  exit 1
}

spells=$(sh "$backend" list-spells "builtin:system" "$root")
printf '%s\n' "$spells" | grep -F "status" >/dev/null 2>&1 || {
  printf '%s\n' "list-spells builtin:system missing status" >&2
  exit 1
}

menus=$(sh "$backend" list-menu-spells "$root")
printf '%s\n' "$menus" | grep -F "main-menu|" >/dev/null 2>&1 || {
  printf '%s\n' "list-menu-spells missing main-menu" >&2
  exit 1
}
printf '%s\n' "$menus" | grep -F "cast|" >/dev/null 2>&1 || {
  printf '%s\n' "list-menu-spells missing cast" >&2
  exit 1
}

menu_help=$(sh "$backend" menu-help cast "$root" 2>&1)
printf '%s\n' "$menu_help" | grep -E '^Usage: cast' >/dev/null 2>&1 || {
  printf '%s\n' "menu-help cast missing Usage output" >&2
  exit 1
}

menu_run_main=$(sh "$backend" run-menu main-menu "" "$root")
printf '%s\n' "$menu_run_main" | grep -F "mode=sourced-only" >/dev/null 2>&1 || {
  printf '%s\n' "run-menu main-menu should report sourced-only mode" >&2
  exit 1
}

arcana=$(sh "$backend" list-arcana-install "$root/spells/.arcana")
printf '%s\n' "$arcana" | grep -F "web-wizardry|" >/dev/null 2>&1 || {
  printf '%s\n' "list-arcana-install missing web-wizardry" >&2
  exit 1
}

system_status=$(sh "$backend" run-system status)
printf '%s\n' "$system_status" | grep -F "status=ok" >/dev/null 2>&1 || {
  printf '%s\n' "run-system status did not return status=ok" >&2
  exit 1
}

printf '%s\n' "wizardry-desktop backend contract tests passed"
