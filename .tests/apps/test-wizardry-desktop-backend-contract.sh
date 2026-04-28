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
bad_root_hint=$(printf '%s\nforged=1' "$root")
if sh "$backend" root-hint "$bad_root_hint" >/tmp/wizardry-desktop-bad-root.out 2>/tmp/wizardry-desktop-bad-root.err; then
  printf '%s\n' "root-hint accepted newline-bearing root" >&2
  exit 1
fi
grep -F "root hint must not contain line breaks" /tmp/wizardry-desktop-bad-root.err >/dev/null 2>&1 || {
  printf '%s\n' "root-hint newline error missing" >&2
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
if sh "$backend" list-spells "evil:system" "$root" >/tmp/wizardry-desktop-evil-spell-ref.out 2>/tmp/wizardry-desktop-evil-spell-ref.err; then
  printf '%s\n' "list-spells accepted unsupported spell source" >&2
  exit 1
fi
grep -F "invalid spell reference" /tmp/wizardry-desktop-evil-spell-ref.err >/dev/null 2>&1 || {
  printf '%s\n' "list-spells unsupported source error missing" >&2
  exit 1
}
if sh "$backend" list-spells "builtin:system extra" "$root" >/tmp/wizardry-desktop-trailing-spell-ref.out 2>/tmp/wizardry-desktop-trailing-spell-ref.err; then
  printf '%s\n' "list-spells accepted trailing words in spell reference" >&2
  exit 1
fi
grep -F "invalid spell reference" /tmp/wizardry-desktop-trailing-spell-ref.err >/dev/null 2>&1 || {
  printf '%s\n' "list-spells trailing words error missing" >&2
  exit 1
}

if ! sh "$backend" list-synonyms "$root" >/dev/null 2>&1; then
  printf '%s\n' "list-synonyms action failed" >&2
  exit 1
fi

tmp_home=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-desktop-home.XXXXXX")
trap 'rm -rf "$tmp_spellbook" "$tmp_home"' EXIT
if HOME="$tmp_home" sh "$backend" set-ui-pref "ab/key" value >/tmp/wizardry-desktop-invalid-pref.out 2>/tmp/wizardry-desktop-invalid-pref.err; then
  printf '%s\n' "wizardry-desktop backend accepted invalid UI pref key" >&2
  exit 1
fi
grep -F "invalid key" /tmp/wizardry-desktop-invalid-pref.err >/dev/null 2>&1 || {
  printf '%s\n' "wizardry-desktop invalid key error missing" >&2
  exit 1
}
desktop_prefs="$tmp_home/.config/wizardry-apps/wizardry-desktop/config"
mkdir -p "$(dirname "$desktop_prefs")"
{
  printf 'leftRailWidth=280\rforged=1\n'
  printf 'ab/key=value\n'
  printf 'theme=adept\n'
} >"$desktop_prefs"
desktop_prefs_out=$(HOME="$tmp_home" sh "$backend" get-ui-prefs)
if printf '%s\n' "$desktop_prefs_out" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "wizardry-desktop get-ui-prefs emitted forged key-value output" >&2
  exit 1
fi
printf '%s\n' "$desktop_prefs_out" | grep -F "leftRailWidth=280 forged=1" >/dev/null
printf '%s\n' "$desktop_prefs_out" | grep -F "theme=adept" >/dev/null
if printf '%s\n' "$desktop_prefs_out" | grep -F "ab/key=" >/dev/null 2>&1; then
  printf '%s\n' "wizardry-desktop get-ui-prefs emitted invalid key from hand-edited prefs" >&2
  exit 1
fi
watch_log="$tmp_home/.local/share/wizardry/wizardry-desktop/watch.log"
mkdir -p "$(dirname "$watch_log")"
{
  printf '1\tapp\tmenu:demo\twizardry-core\tok\rforged=1\n'
  printf '2\tapp\tbad\twizardry-core\ttoo\tmany\n'
  printf '3\tapp\tmenu:good\twizardry-core\tok\n'
} >"$watch_log"
watch_out=$(HOME="$tmp_home" sh "$backend" list-watch 10)
if printf '%s\n' "$watch_out" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "wizardry-desktop list-watch emitted forged rows from hand-edited log" >&2
  exit 1
fi
if printf '%s\n' "$watch_out" | grep -F "too	many" >/dev/null 2>&1; then
  printf '%s\n' "wizardry-desktop list-watch emitted malformed hand-edited log row" >&2
  exit 1
fi
printf '%s\n' "$watch_out" | grep -F "1	app	menu:demo	wizardry-core	ok forged=1" >/dev/null
printf '%s\n' "$watch_out" | grep -F "3	app	menu:good	wizardry-core	ok" >/dev/null

hostile_spell_dir="$tmp_home/.wizardry/spells/hostilecat"
mkdir -p "$hostile_spell_dir"
: >"$hostile_spell_dir/good-spell"
: >"$hostile_spell_dir/bad|spell"
: >"$hostile_spell_dir/bad spell"
hostile_categories=$(HOME="$tmp_home" sh "$backend" list-spell-categories "$root")
printf '%s\n' "$hostile_categories" | grep -F "custom:hostilecat|custom|hostilecat|1" >/dev/null 2>&1 || {
  printf '%s\n' "list-spell-categories counted unsafe spell filenames" >&2
  exit 1
}
hostile_spells=$(HOME="$tmp_home" sh "$backend" list-spells "custom:hostilecat" "$root")
printf '%s\n' "$hostile_spells" | grep -E '^good-spell$' >/dev/null 2>&1 || {
  printf '%s\n' "list-spells missing safe hostile category spell" >&2
  exit 1
}
if printf '%s\n' "$hostile_spells" | grep -E 'bad[| ]spell' >/dev/null 2>&1; then
  printf '%s\n' "list-spells emitted unsafe spell filenames" >&2
  exit 1
fi

memorized_custom=$(HOME="$tmp_home" SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" memorize-spell quick-look "look ." 2>/dev/null)
printf '%s\n' "$memorized_custom" | grep -F "quick-look	look ." >/dev/null 2>&1 || {
  printf '%s\n' "memorize-spell did not return expected tab-separated row" >&2
  exit 1
}
[ -f "$tmp_spellbook/.memorized" ] || {
  printf '%s\n' "memorize-spell did not create .memorized file" >&2
  exit 1
}
grep -F "quick-look	look ." "$tmp_spellbook/.memorized" >/dev/null 2>&1 || {
  printf '%s\n' "memorize-spell did not persist expected command entry" >&2
  exit 1
}
if HOME="$tmp_home" SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" memorize-spell tabbed "$(printf 'look\tbad')" >/tmp/wizardry-desktop-tabbed-spell.out 2>/tmp/wizardry-desktop-tabbed-spell.err; then
  printf '%s\n' "memorize-spell accepted tab-delimited command text" >&2
  exit 1
fi
grep -F "without tabs" /tmp/wizardry-desktop-tabbed-spell.err >/dev/null 2>&1 || {
  printf '%s\n' "memorize-spell tab-delimited command error missing" >&2
  exit 1
}
if grep -F "tabbed" "$tmp_spellbook/.memorized" >/dev/null 2>&1; then
  printf '%s\n' "memorize-spell persisted rejected tab-delimited command" >&2
  exit 1
fi

memorized_data_home="$tmp_home/xdg"
memorized_rows_dir="$memorized_data_home/wizardry/spellbook"
mkdir -p "$memorized_rows_dir"
printf '%s' "look ." >"$memorized_rows_dir/good-spell"
printf 'look\tbad' >"$memorized_rows_dir/bad-command"
printf 'look\nstatus=forged' >"$memorized_rows_dir/bad-multiline"
printf '%s' "look ." >"$memorized_rows_dir/bad name"
memorized_rows=$(HOME="$tmp_home" XDG_DATA_HOME="$memorized_data_home" PATH="/bin:/usr/bin" sh "$backend" list-memorized-spells)
printf '%s\n' "$memorized_rows" | grep -F "good-spell	look ." >/dev/null 2>&1 || {
  printf '%s\n' "list-memorized-spells missing safe fallback row" >&2
  exit 1
}
row_tab=$(printf '\t')
if printf '%s\n' "$memorized_rows" | awk -F "$row_tab" 'NF != 2 { bad = 1 } END { exit bad ? 0 : 1 }'; then
  printf '%s\n' "list-memorized-spells emitted malformed tab-delimited rows" >&2
  exit 1
fi
if printf '%s\n' "$memorized_rows" | grep -E 'bad-command|bad-multiline|bad name|^status=' >/dev/null 2>&1; then
  printf '%s\n' "list-memorized-spells emitted unsafe fallback rows" >&2
  exit 1
fi
helper_home="$tmp_home/helper-home"
mkdir -p "$helper_home/.wizardry/spells/menu"
cat >"$helper_home/.wizardry/spells/menu/cast" <<'SH'
#!/bin/sh
if [ "${1-}" = "--list" ]; then
  printf 'good-helper\tlook .\n'
  printf 'bad-helper\tlook\rforged=1\n'
  printf 'extra-helper\tlook\tbad\n'
  exit 0
fi
exit 2
SH
chmod +x "$helper_home/.wizardry/spells/menu/cast"
memorized_helper_rows=$(HOME="$helper_home" PATH="/bin:/usr/bin" sh "$backend" list-memorized-spells)
printf '%s\n' "$memorized_helper_rows" | grep -F "good-helper	look ." >/dev/null 2>&1 || {
  printf '%s\n' "list-memorized-spells missing safe helper row" >&2
  exit 1
}
printf '%s\n' "$memorized_helper_rows" | grep -F "bad-helper	look forged=1" >/dev/null 2>&1 || {
  printf '%s\n' "list-memorized-spells did not sanitize CR in helper row" >&2
  exit 1
}
if printf '%s\n' "$memorized_helper_rows" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "list-memorized-spells emitted forged helper rows" >&2
  exit 1
fi
if printf '%s\n' "$memorized_helper_rows" | grep -F "extra-helper" >/dev/null 2>&1; then
  printf '%s\n' "list-memorized-spells emitted malformed helper rows" >&2
  exit 1
fi

{
  printf '%s\n' "arcana=install-menu"
  printf '%s\n' "bad alias=look"
  printf '%s\n' "bad|alias=look"
  printf '%s\n' "badtarget=jump|bad"
  printf 'badtab=jump\tbad\n'
} >"$tmp_spellbook/.default-synonyms"
SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" add-synonym leap jump-to-marker >/dev/null 2>&1 || {
  printf '%s\n' "add-synonym action failed" >&2
  exit 1
}
tmp_synonyms=$(SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" list-synonyms)
printf '%s\n' "$tmp_synonyms" | grep -F "leap|jump-to-marker|custom" >/dev/null 2>&1 || {
  printf '%s\n' "add-synonym did not create expected custom row" >&2
  exit 1
}
printf '%s\n' "$tmp_synonyms" | grep -F "arcana|install-menu|default" >/dev/null 2>&1 || {
  printf '%s\n' "list-synonyms did not include safe default row" >&2
  exit 1
}
if printf '%s\n' "$tmp_synonyms" | awk -F'|' 'NF != 3 { bad = 1 } END { exit bad ? 0 : 1 }'; then
  printf '%s\n' "list-synonyms emitted malformed pipe-delimited rows" >&2
  exit 1
fi
if printf '%s\n' "$tmp_synonyms" | grep -E 'bad alias|bad[|]alias|badtarget|badtab' >/dev/null 2>&1; then
  printf '%s\n' "list-synonyms emitted unsafe imported synonym rows" >&2
  exit 1
fi
if SPELLBOOK_DIR="$tmp_spellbook" sh "$backend" add-synonym badpipe 'jump|bad' >/tmp/wizardry-desktop-pipe-synonym.out 2>/tmp/wizardry-desktop-pipe-synonym.err; then
  printf '%s\n' "add-synonym accepted pipe-delimited target text" >&2
  exit 1
fi
grep -F "without tabs or pipes" /tmp/wizardry-desktop-pipe-synonym.err >/dev/null 2>&1 || {
  printf '%s\n' "add-synonym pipe-delimited target error missing" >&2
  exit 1
}
if grep -F "badpipe=" "$tmp_spellbook/.synonyms" >/dev/null 2>&1; then
  printf '%s\n' "add-synonym persisted rejected pipe-delimited target" >&2
  exit 1
fi
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

hostile_menu_root="$tmp_home/menu-root$(printf '\r')status=forged"
hostile_menu_dir="$hostile_menu_root/spells/menu"
mkdir -p "$hostile_menu_dir"
cat >"$hostile_menu_dir/hostile-menu" <<'SH'
#!/bin/sh
printf '%s\n' 'hostile menu'
SH
chmod +x "$hostile_menu_dir/hostile-menu"
hostile_path="$tmp_home/path"
mkdir -p "$hostile_path"
cat >"$hostile_path/os_id" <<'SH'
#!/bin/sh
printf '%s\n' linux
SH
chmod +x "$hostile_path/os_id"
terminal_output=$(PATH="$hostile_path:$PATH" sh "$backend" open-menu-terminal hostile-menu "" "$hostile_menu_root")
printf '%s\n' "$terminal_output" | grep -F "mode=manual" >/dev/null 2>&1 || {
  printf '%s\n' "open-menu-terminal should use manual mode in platform stub" >&2
  exit 1
}
if printf '%s\n' "$terminal_output" | tr '\r' '\n' | grep -E '^status=' >/dev/null 2>&1; then
  printf '%s\n' "open-menu-terminal emitted forged key-value output from path newline" >&2
  exit 1
fi

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

hostile_arcana_root="$tmp_home/hostile-arcana"
hostile_module_dir="$hostile_arcana_root/evilmod"
mkdir -p "$hostile_module_dir"
: >"$hostile_module_dir/bad|item"
cat >"$hostile_module_dir/evilmod-status" <<'SH'
#!/bin/sh
printf '%s\n' 'ready|forged|extra'
printf '%s\n' '[x] detail|forged|extra'
SH
chmod +x "$hostile_module_dir/evilmod-status"
mkdir -p "$hostile_arcana_root/bad|module"
: >"$hostile_arcana_root/bad|module/bad|module-menu"

hostile_arcana=$(sh "$backend" list-arcana-install "$hostile_arcana_root")
if printf '%s\n' "$hostile_arcana" | awk -F'|' 'NF != 3 { bad = 1 } END { exit bad ? 0 : 1 }'; then
  printf '%s\n' "list-arcana-install emitted malformed pipe-delimited rows" >&2
  exit 1
fi
if printf '%s\n' "$hostile_arcana" | grep -F "bad|module" >/dev/null 2>&1; then
  printf '%s\n' "list-arcana-install emitted unsafe module name" >&2
  exit 1
fi

hostile_arcana_items=$(sh "$backend" list-arcana-module-items evilmod "$hostile_arcana_root")
if printf '%s\n' "$hostile_arcana_items" | awk -F'|' 'NF != 3 { bad = 1 } END { exit bad ? 0 : 1 }'; then
  printf '%s\n' "list-arcana-module-items emitted malformed pipe-delimited rows" >&2
  exit 1
fi
if printf '%s\n' "$hostile_arcana_items" | grep -F "bad|item" >/dev/null 2>&1; then
  printf '%s\n' "list-arcana-module-items emitted unsafe item name" >&2
  exit 1
fi

system_status=$(sh "$backend" run-system status)
printf '%s\n' "$system_status" | grep -F "status=ok" >/dev/null 2>&1 || {
  printf '%s\n' "run-system status did not return status=ok" >&2
  exit 1
}

hostile_environment=$(SHELL="zsh$(printf '\r')status=forged" sh "$backend" run-system environment)
if printf '%s\n' "$hostile_environment" | tr '\r' '\n' | grep -E '^status=' >/dev/null 2>&1; then
  printf '%s\n' "run-system environment emitted forged key-value output" >&2
  exit 1
fi

printf '%s\n' "wizardry-desktop backend contract tests passed"
