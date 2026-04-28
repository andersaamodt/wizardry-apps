#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-ui-assets.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

[ -f "$root/apps/forge/index.html" ]
[ -f "$root/apps/forge/style.css" ]
[ -f "$root/apps/forge/README.md" ]
[ -f "$root/licenses/AGPL-3.0-or-later.txt" ]
[ -f "$root/licenses/WIZARDRY_ADDENDUM.md" ]
[ -f "$root/apps/forge/starter-templates/web/sidebar/index.html" ]
[ -f "$root/apps/forge/starter-templates/web/topbar/index.html" ]
[ -f "$root/apps/forge/starter-templates/web/dashboard/index.html" ]
[ -f "$root/apps/forge/starter-templates/web/studio/index.html" ]
[ -f "$root/apps/forge/starter-templates/web/reference-app/index.html" ]
[ -f "$root/apps/forge/starter-templates/web/reference-app/script.js" ]
[ -f "$root/apps/forge/starter-templates/web/reference-app/scripts/__APP_SLUG__-backend.sh" ]
[ -f "$root/apps/forge/starter-templates/web/minimal/style.css" ]
[ -f "$root/apps/.host/shared/wizardry-bridge.js" ]
[ -f "$root/apps/.host/macos/main.m" ]
[ -f "$root/apps/.host/linux/main.c" ]
[ -x "$root/apps/forge/scripts/forge-backend.sh" ]
[ -x "$root/tools/forge/launch-forge.sh" ]
[ -x "$root/tools/forge/install-forge.sh" ]
[ -x "$root/tools/forge/uninstall-forge.sh" ]
[ -x "$root/tools/forge/build-forge-icon.sh" ]
[ -x "$root/tools/forge/build-forge-macos-app.sh" ]
if [ ! -f "$root/apps/forge/assets/forge-icon.svg" ] && [ ! -f "$root/apps/forge/assets/forge-icon.png" ]; then
  printf '%s\n' "forge icon asset missing (expected forge-icon.svg or forge-icon.png)" >&2
  exit 1
fi
[ -x "$root/run-forge" ]
[ -x "$root/install-forge" ]
[ -x "$root/uninstall-forge" ]

grep -F "App Forge" "$root/apps/forge/index.html" >/dev/null
grep -F "forge-backend.sh" "$root/apps/forge/index.html" >/dev/null
grep -F "window.wizardry.exec" "$root/apps/forge/index.html" >/dev/null
! grep -F "window.wizardry.rpc('bridge.exec'" "$root/apps/forge/index.html" >/dev/null
grep -F "window.wizardry.exec" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "window.wizardry.rpc" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "method !== 'bridge.exec'" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "Emission material notice" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "version 3 or (at your option) any later version" "$root/licenses/AGPL-3.0-or-later.txt" >/dev/null
grep -F "Remote Network Interaction" "$root/licenses/AGPL-3.0-or-later.txt" >/dev/null
grep -F "Emission material notice" "$root/apps/forge/starter-templates/web/minimal/index.html" >/dev/null
grep -F "Emission material notice" "$root/apps/forge/starter-templates/web/minimal/style.css" >/dev/null
grep -F "Canonical reference note" "$root/apps/forge/starter-templates/web/reference-app/index.html" >/dev/null
grep -F "__wizardry_host_boot_ready" "$root/apps/forge/starter-templates/web/reference-app/script.js" >/dev/null
reference_backend="$root/apps/forge/starter-templates/web/reference-app/scripts/__APP_SLUG__-backend.sh"
grep -F "get-ui-prefs" "$reference_backend" >/dev/null
sh -n "$reference_backend"
if XDG_CONFIG_HOME="$scratch/.config" sh "$reference_backend" set-ui-pref "ab/key" value >/tmp/forge-reference-invalid-pref.out 2>/tmp/forge-reference-invalid-pref.err; then
  printf '%s\n' "reference app backend accepted invalid UI pref key" >&2
  exit 1
fi
grep -F "invalid key" /tmp/forge-reference-invalid-pref.err >/dev/null
reference_prefs="$scratch/.config/wizardry-apps/__APP_SLUG__.conf"
mkdir -p "$(dirname "$reference_prefs")"
{
  printf 'selected_view=home\rforged=1\n'
  printf 'ab/key=value\n'
} >"$reference_prefs"
reference_pref_out=$(XDG_CONFIG_HOME="$scratch/.config" sh "$reference_backend" get-ui-prefs)
printf '%s\n' "$reference_pref_out" | grep -F "selected_view=home forged=1" >/dev/null
if printf '%s\n' "$reference_pref_out" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "reference app backend emitted forged UI pref output" >&2
  exit 1
fi
if printf '%s\n' "$reference_pref_out" | grep -F "ab/key=" >/dev/null 2>&1; then
  printf '%s\n' "reference app backend emitted invalid hand-edited UI pref key" >&2
  exit 1
fi
grep -F "assets/forge-icon.png" "$root/apps/forge/starter-templates/web/reference-app/index.html" >/dev/null
grep -F "Reference App" "$root/apps/forge/starter-templates/web/reference-app/index.html" >/dev/null
grep -F "desktopBridgeBootstrapSource" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "window.wizardry.exec = execCommand;" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "territory-master.png" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "plain-master.png" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "underPageBackgroundColor = childPageBackingColor" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "underPageBackgroundColor = pageBackingColor" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "DESKTOP_BRIDGE_BOOTSTRAP" "$root/apps/.host/linux/main.c" >/dev/null
grep -F "window.wizardry.rpc = rpcBridge;" "$root/apps/.host/linux/main.c" >/dev/null
grep -F 'id="toggle-settings-panel"' "$root/apps/forge/index.html" >/dev/null
grep -F 'id="organize-menu"' "$root/apps/forge/index.html" >/dev/null
grep -F 'id="open-create-workflow"' "$root/apps/forge/index.html" >/dev/null
grep -F 'data-organize-show="builtin"' "$root/apps/forge/index.html" >/dev/null
grep -F 'data-organize-show="workspace"' "$root/apps/forge/index.html" >/dev/null
grep -F 'id="theme-picker-menu"' "$root/apps/forge/index.html" >/dev/null
grep -F 'id="selected-targets-editor"' "$root/apps/forge/index.html" >/dev/null
grep -F ">Log<" "$root/apps/forge/index.html" >/dev/null
grep -F 'id="target-active-list"' "$root/apps/forge/index.html" >/dev/null
grep -F 'id="target-inactive-list"' "$root/apps/forge/index.html" >/dev/null
grep -F 'Starter: Left sidebar' "$root/apps/forge/index.html" >/dev/null
grep -F 'Wizardry Reference Desktop App' "$root/apps/forge/index.html" >/dev/null
grep -F 'Starter: Top bar + graph' "$root/apps/forge/index.html" >/dev/null
grep -F 'Starter: Dashboard' "$root/apps/forge/index.html" >/dev/null
grep -F 'Starter: Studio' "$root/apps/forge/index.html" >/dev/null
grep -F "row-play" "$root/apps/forge/index.html" >/dev/null
grep -F "function buildCatalogRowMenu(item)" "$root/apps/forge/index.html" >/dev/null
grep -F "rowMenuBtn.className = 'row-overflow'" "$root/apps/forge/index.html" >/dev/null
grep -F "appendAction('Open folder'" "$root/apps/forge/index.html" >/dev/null
grep -F "placeholder=\"Filter\"" "$root/apps/forge/index.html" >/dev/null
! grep -F "Refresh" "$root/apps/forge/index.html" >/dev/null
! grep -F 'id="artifact-list"' "$root/apps/forge/index.html" >/dev/null
! grep -F 'id="result-status"' "$root/apps/forge/index.html" >/dev/null
! grep -F ">Reveal<" "$root/apps/forge/index.html" >/dev/null
! grep -F "class=\"stage-tab\" data-route=\"quality\"" "$root/apps/forge/index.html" >/dev/null
! grep -F "stage-nav" "$root/apps/forge/index.html" >/dev/null
! grep -F "stage-tab" "$root/apps/forge/index.html" >/dev/null
grep -F -- "--accent" "$root/apps/forge/style.css" >/dev/null
grep -F -- "--catalog-thumb-image" "$root/apps/forge/style.css" >/dev/null
grep -F -- "-webkit-mask-image: var(--catalog-thumb-image, none);" "$root/apps/forge/style.css" >/dev/null
grep -F -- "-webkit-mask-image: linear-gradient(white, white);" "$root/apps/forge/style.css" >/dev/null
grep -F -- "background-size: contain;" "$root/apps/forge/style.css" >/dev/null
grep -F "scaffold-app" "$root/apps/forge/scripts/forge-backend.sh" >/dev/null
grep -F "Install user-local launchers/integration" "$root/apps/forge/README.md" >/dev/null
grep -F 'forge-backend" run-desktop "$root" forge' "$root/tools/forge/launch-forge.sh" >/dev/null
[ -f "$root/apps/forge/assets/icons/meta/territory-master.png" ]
[ -f "$root/apps/wizardry-desktop/assets/icons/meta/territory-master.png" ]
grep -F "territory_master=" "$root/apps/forge/assets/icons/meta/icon-settings.conf" >/dev/null
grep -F "territory_master=" "$root/apps/wizardry-desktop/assets/icons/meta/icon-settings.conf" >/dev/null
grep -F "original_source=assets/icons/meta/original-source.png" "$root/apps/forge/assets/icons/meta/icon-settings.conf" >/dev/null
grep -F "original_source=assets/icons/meta/original-source.png" "$root/apps/wizardry-desktop/assets/icons/meta/icon-settings.conf" >/dev/null
if grep -F "/Users/" "$root/apps/forge/assets/icons/meta/icon-settings.conf" "$root/apps/wizardry-desktop/assets/icons/meta/icon-settings.conf" >/dev/null; then
  printf '%s\n' "forge UI asset tests: icon settings contain machine-local absolute paths" >&2
  exit 1
fi
grep -F "assets/forge-icon.png" "$root/apps/forge/index.html" >/dev/null
grep -F "thumb.style.setProperty('--catalog-thumb-image'" "$root/apps/forge/index.html" >/dev/null
grep -F 'plain_master="$project_dir/assets/icons/meta/plain-master.png"' "$root/apps/forge/scripts/forge-backend.sh" >/dev/null
grep -F "territory-master.png" "$root/apps/wizardry-desktop/index.html" >/dev/null
grep -F "territory-master.png" "$root/tools/forge/build-forge-icon.sh" >/dev/null

printf '%s\n' "forge UI asset tests passed"
