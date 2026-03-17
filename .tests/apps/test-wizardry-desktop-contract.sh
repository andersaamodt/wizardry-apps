#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app_dir="$root/apps/wizardry-desktop"
backend="$app_dir/scripts/wizardry-desktop-backend.sh"
manifest="$root/config/apps.manifest.json"
taxonomy="$root/.github/GUI_TAXONOMY.md"

[ -d "$app_dir" ] || {
  printf '%s\n' "wizardry-desktop app directory missing: $app_dir" >&2
  exit 1
}
[ -f "$app_dir/index.html" ]
[ -f "$app_dir/style.css" ]
[ -f "$app_dir/app.js" ]
[ -f "$app_dir/README.md" ]
[ -x "$backend" ]
[ -f "$app_dir/assets/forge-icon.png" ]
[ -f "$app_dir/assets/settings-gear.svg" ]
[ -d "$app_dir/themes" ]

grep -F '"slug": "wizardry-desktop"' "$manifest" >/dev/null
grep -F '"name": "Wizardry Desktop"' "$manifest" >/dev/null
grep -F '"distribution": "core"' "$manifest" >/dev/null

grep -F 'role="listbox"' "$app_dir/index.html" >/dev/null
grep -F 'id="activity-drawer"' "$app_dir/index.html" >/dev/null
grep -F 'id="theme-picker-menu"' "$app_dir/index.html" >/dev/null
grep -F 'id="settings-modal"' "$app_dir/index.html" >/dev/null
grep -F 'wizardry-bridge.js' "$app_dir/index.html" >/dev/null

grep -F "function renderSpellbook()" "$app_dir/app.js" >/dev/null
grep -F "function renderSpellActivity()" "$app_dir/app.js" >/dev/null
grep -F "function renderComputer()" "$app_dir/app.js" >/dev/null
grep -F "function renderMud()" "$app_dir/app.js" >/dev/null
grep -F "function renderCategory(pageId)" "$app_dir/app.js" >/dev/null
grep -F "requestRender()" "$app_dir/app.js" >/dev/null
if grep -F "localStorage" "$app_dir/app.js" >/dev/null 2>&1; then
  printf '%s\n' "wizardry-desktop must not use localStorage for durable desktop prefs" >&2
  exit 1
fi

grep -F "wizardry-desktop-ui.conf" "$app_dir/README.md" >/dev/null
grep -F "Listbox-style rail navigation" "$taxonomy" >/dev/null
grep -F "Activity drawer log" "$taxonomy" >/dev/null

doctor_out=$("$backend" doctor)
printf '%s\n' "$doctor_out" | grep -F "wizardry_dir=" >/dev/null
printf '%s\n' "$doctor_out" | grep -F "spell_count=" >/dev/null

categories_out=$("$backend" list-categories)
printf '%s\n' "$categories_out" | grep -F "$(printf 'builtin\t')" >/dev/null

activity_out=$("$backend" list-spell-activity)
[ -n "${activity_out-}" ] || true

mud_out=$("$backend" mud-status)
printf '%s\n' "$mud_out" | grep -F "portal_location=" >/dev/null
printf '%s\n' "$mud_out" | grep -F "parse_enabled=" >/dev/null

tmp_home=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-desktop-activity-home.XXXXXX")
cleanup() {
  if [ -n "${spell_pid-}" ]; then
    kill "$spell_pid" >/dev/null 2>&1 || true
    wait "$spell_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_home"
}
trap cleanup EXIT INT TERM

mkdir -p "$tmp_home/spells"
cat > "$tmp_home/spells/slow-activity-spell" <<'EOF'
#!/bin/sh
sleep 3
EOF
chmod +x "$tmp_home/spells/slow-activity-spell"

"$tmp_home/spells/slow-activity-spell" &
spell_pid=$!
sleep 0.3

activity_probe=$(HOME="$tmp_home" WIZARDRY_DIR="$HOME/.wizardry" "$backend" list-spell-activity)
printf '%s\n' "$activity_probe" | grep -F "home-spell" >/dev/null
printf '%s\n' "$activity_probe" | grep -F "slow-activity-spell" >/dev/null

kill "$spell_pid" >/dev/null 2>&1 || true
wait "$spell_pid" >/dev/null 2>&1 || true
spell_pid=

printf '%s\n' "wizardry desktop contract tests passed"
