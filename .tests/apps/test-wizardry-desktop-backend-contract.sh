#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh"
tmp_spellbook=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-desktop-spellbook.XXXXXX")
trap 'rm -rf "$tmp_spellbook"' EXIT

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

if ! sh "$backend" list-synonyms "$root" >/dev/null 2>&1; then
  printf '%s\n' "list-synonyms action failed" >&2
  exit 1
fi

printf '%s\n' "arcana=install-menu" >"$tmp_spellbook/.default-synonyms"
SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" add-synonym leap jump-to-marker >/dev/null 2>&1 || {
  printf '%s\n' "add-synonym action failed" >&2
  exit 1
}
tmp_synonyms=$(SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" list-synonyms)
printf '%s\n' "$tmp_synonyms" | grep -F "leap|jump-to-marker|custom" >/dev/null 2>&1 || {
  printf '%s\n' "add-synonym did not create expected custom row" >&2
  exit 1
}
SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" remove-synonym leap >/dev/null 2>&1 || {
  printf '%s\n' "remove-synonym action failed" >&2
  exit 1
}
tmp_synonyms_after=$(SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" list-synonyms)
if printf '%s\n' "$tmp_synonyms_after" | grep -F "leap|" >/dev/null 2>&1; then
  printf '%s\n' "remove-synonym did not remove custom row" >&2
  exit 1
fi

menus=$(sh "$backend" list-menu-spells "$root")
printf '%s\n' "$menus" | grep -F "main-menu|" >/dev/null 2>&1 || {
  printf '%s\n' "list-menu-spells missing main-menu" >&2
  exit 1
}
printf '%s\n' "$menus" | grep -F "cast|" >/dev/null 2>&1 || {
  printf '%s\n' "list-menu-spells missing cast" >&2
  exit 1
}
printf '%s\n' "$menus" | grep -F "spell-menu|0|required|" >/dev/null 2>&1 || {
  printf '%s\n' "list-menu-spells missing required arg metadata for spell-menu" >&2
  exit 1
}
printf '%s\n' "$menus" | grep -F "spellbook|0|optional|" >/dev/null 2>&1 || {
  printf '%s\n' "list-menu-spells missing optional arg metadata for spellbook" >&2
  exit 1
}

main_menu_entries=$(sh "$backend" list-main-menu-entries "$root")
printf '%s\n' "$main_menu_entries" | grep -F "cast|Cast|cast" >/dev/null 2>&1 || {
  printf '%s\n' "list-main-menu-entries missing Cast" >&2
  exit 1
}
printf '%s\n' "$main_menu_entries" | grep -F "spellbook|Spellbook|spellbook" >/dev/null 2>&1 || {
  printf '%s\n' "list-main-menu-entries missing Spellbook" >&2
  exit 1
}
printf '%s\n' "$main_menu_entries" | grep -F "arcana|Arcana|install-menu" >/dev/null 2>&1 || {
  printf '%s\n' "list-main-menu-entries missing Arcana/install-menu" >&2
  exit 1
}
printf '%s\n' "$main_menu_entries" | grep -F "system|Computer|system-menu" >/dev/null 2>&1 || {
  printf '%s\n' "list-main-menu-entries missing Computer/system-menu" >&2
  exit 1
}

system_actions=$(sh "$backend" list-system-menu-actions "$root")
printf '%s\n' "$system_actions" | grep -F "system:restart-menu|Restart...|menu|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing restart-menu row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:services-menu|Manage services|menu|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing services-menu row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:verify-posix|Verify POSIX spells|spell|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing verify-posix row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:update-wizardry|Update wizardry|spell|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing update-wizardry row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:test-magic|Test all wizardry spells|spell|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing test-magic row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:profile-tests|Profile test performance|spell|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing profile-tests row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:update-all|Update all software|spell|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing update-all row" >&2
  exit 1
}
printf '%s\n' "$system_actions" | grep -F "system:uninstall-wizardry|Uninstall wizardry|script|" >/dev/null 2>&1 || {
  printf '%s\n' "list-system-menu-actions missing uninstall row" >&2
  exit 1
}

mud_actions=$(sh "$backend" list-mud-actions "$root")
printf '%s\n' "$mud_actions" | grep -F "mud:menu|Open MUD Menu|menu|" >/dev/null 2>&1 || {
  printf '%s\n' "list-mud-actions missing mud:menu row" >&2
  exit 1
}
printf '%s\n' "$mud_actions" | grep -F "mud:listen|Listen|command|" >/dev/null 2>&1 || {
  printf '%s\n' "list-mud-actions missing mud:listen command row" >&2
  exit 1
}
printf '%s\n' "$mud_actions" | grep -F "mud:say|Say|spell|" >/dev/null 2>&1 || {
  printf '%s\n' "list-mud-actions missing mud:say row" >&2
  exit 1
}

mud_menu_run=$(sh "$backend" run-mud-action mud:menu "" "$root")
printf '%s\n' "$mud_menu_run" | grep -E '^mode=(terminal|manual)$' >/dev/null 2>&1 || {
  printf '%s\n' "run-mud-action mud:menu should return terminal/manual mode" >&2
  exit 1
}

if sh "$backend" run-mud-action mud:say "" "$root" >/tmp/wizardry-desktop-run-mud.out 2>/tmp/wizardry-desktop-run-mud.err; then
  printf '%s\n' "run-mud-action mud:say should fail without required argument" >&2
  exit 1
fi
grep -F "requires an argument" /tmp/wizardry-desktop-run-mud.err >/dev/null 2>&1 || {
  printf '%s\n' "run-mud-action mud:say missing required argument error" >&2
  exit 1
}

if ! sh "$backend" run-mud-action mud:look . "$root" >/tmp/wizardry-desktop-run-mud-look.out 2>/tmp/wizardry-desktop-run-mud-look.err; then
  printf '%s\n' "run-mud-action mud:look should succeed" >&2
  cat /tmp/wizardry-desktop-run-mud-look.err >&2 || true
  exit 1
fi

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

if sh "$backend" run-menu spell-menu "" "$root" >/tmp/wizardry-desktop-run-menu.out 2>/tmp/wizardry-desktop-run-menu.err; then
  printf '%s\n' "run-menu spell-menu should fail without required argument" >&2
  exit 1
fi
grep -F "requires an argument" /tmp/wizardry-desktop-run-menu.err >/dev/null 2>&1 || {
  printf '%s\n' "run-menu spell-menu missing required argument error" >&2
  exit 1
}

menu_help_via_action=$(sh "$backend" run-action menu:help cast "" "$root" 2>&1)
printf '%s\n' "$menu_help_via_action" | grep -E '^Usage: cast' >/dev/null 2>&1 || {
  printf '%s\n' "run-action menu:help cast missing Usage output" >&2
  exit 1
}

arcana=$(sh "$backend" list-arcana-install "$root/spells/.arcana")
printf '%s\n' "$arcana" | grep -F "web-wizardry|" >/dev/null 2>&1 || {
  printf '%s\n' "list-arcana-install missing web-wizardry" >&2
  exit 1
}
printf '%s\n' "$arcana" | grep -E '^wizardry-apps\|(installed|partial install|not installed|coming soon|ready|running)' >/dev/null 2>&1 || {
  printf '%s\n' "list-arcana-install should normalize wizardry-apps status" >&2
  exit 1
}

arcana_items=$(sh "$backend" list-arcana-module-items web-wizardry "$root/spells/.arcana")
printf '%s\n' "$arcana_items" | grep -F "|web-wizardry-menu|" >/dev/null 2>&1 || {
  printf '%s\n' "list-arcana-module-items missing web-wizardry-menu" >&2
  exit 1
}

system_status=$(sh "$backend" run-system status)
printf '%s\n' "$system_status" | grep -F "status=ok" >/dev/null 2>&1 || {
  printf '%s\n' "run-system status did not return status=ok" >&2
  exit 1
}

printf '%s\n' "wizardry-desktop backend contract tests passed"
