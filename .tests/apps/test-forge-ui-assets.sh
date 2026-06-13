#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-ui-assets.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

[ -f "$root/apps/forge/index.html" ]
[ -f "$root/apps/forge/style.css" ]
[ -f "$root/README.md" ]
[ -f "$root/LICENSE" ]
[ -f "$root/licenses/OWL-3.1.txt" ]
[ -f "$root/licenses/AGPL-3.0-or-later.txt" ]
[ -f "$root/licenses/WIZARDRY_ADDENDUM.md" ]
[ -f "$root/templates/forge/web/sidebar/index.html" ]
[ -f "$root/templates/forge/web/topbar/index.html" ]
[ -f "$root/templates/forge/web/dashboard/index.html" ]
[ -f "$root/templates/forge/web/studio/index.html" ]
[ -f "$root/templates/forge/web/reference-app/index.html" ]
[ -f "$root/templates/forge/web/reference-app/script.js" ]
[ -f "$root/templates/forge/web/reference-app/scripts/__APP_SLUG__-backend.sh" ]
[ -f "$root/templates/forge/web/theurgy-reference-app/index.html" ]
[ -f "$root/templates/forge/web/theurgy-reference-app/script.js" ]
[ -f "$root/templates/forge/web/theurgy-reference-app/scripts/__APP_SLUG__-backend.sh" ]
[ -f "$root/templates/forge/native-desktop/reference-app/scripts/render-native-desktop.sh" ]
[ -f "$root/templates/forge/web/minimal/style.css" ]
[ -f "$root/apps/.host/shared/wizardry-bridge.js" ]
[ -f "$root/apps/.host/macos/main.m" ]
[ -f "$root/apps/.host/linux/main.c" ]
[ -x "$root/apps/forge/scripts/forge-backend.sh" ]
[ -x "$root/tools/forge/launch-forge.sh" ]
[ -x "$root/tools/forge/install-forge.sh" ]
[ -x "$root/tools/forge/uninstall-forge.sh" ]
[ -x "$root/tools/forge/build-forge-icon.sh" ]
[ -x "$root/tools/forge/build-forge-macos-app.sh" ]
[ -x "$root/tools/release/prepare-android-host.sh" ]
[ -x "$root/forge-menu" ]
[ -x "$root/spells/.imps/forge/run-forge" ]
[ -x "$root/spells/.imps/forge/install-forge" ]
[ -x "$root/spells/.imps/forge/uninstall-forge" ]
[ ! -e "$root/run-forge" ]
[ ! -e "$root/install-forge" ]
[ ! -e "$root/uninstall-forge" ]
if [ -e "$root/apps/.host/android/app/src/main/assets/app/index.html" ]; then
  printf '%s\n' "forge UI asset tests: Android host source contains staged app assets" >&2
  exit 1
fi
if [ ! -f "$root/apps/forge/assets/forge-icon.svg" ] && [ ! -f "$root/apps/forge/assets/forge-icon.png" ]; then
  printf '%s\n' "forge icon asset missing (expected forge-icon.svg or forge-icon.png)" >&2
  exit 1
fi
grep -F "App Forge" "$root/apps/forge/index.html" >/dev/null
grep -F "forge-backend.sh" "$root/apps/forge/index.html" >/dev/null
grep -F "window.wizardry.exec" "$root/apps/forge/index.html" >/dev/null
! grep -F "window.wizardry.rpc('bridge.exec'" "$root/apps/forge/index.html" >/dev/null
grep -F "window.wizardry.exec" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "window.wizardry.rpc" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "window.wizardry.nativeAvailable" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "if (method === 'bridge.exec')" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "postRpc(method, payload || {})" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "Emission material notice" "$root/apps/.host/shared/wizardry-bridge.js" >/dev/null
grep -F "version 3 or (at your option) any later version" "$root/licenses/AGPL-3.0-or-later.txt" >/dev/null
grep -F "Remote Network Interaction" "$root/licenses/AGPL-3.0-or-later.txt" >/dev/null
grep -F "Emission material notice" "$root/templates/forge/web/minimal/index.html" >/dev/null
grep -F "Emission material notice" "$root/templates/forge/web/minimal/style.css" >/dev/null
grep -F "Canonical reference note" "$root/templates/forge/web/reference-app/index.html" >/dev/null
grep -F "__wizardry_host_boot_ready" "$root/templates/forge/web/reference-app/script.js" >/dev/null
reference_backend="$root/templates/forge/web/reference-app/scripts/__APP_SLUG__-backend.sh"
theurgy_reference_backend="$root/templates/forge/web/theurgy-reference-app/scripts/__APP_SLUG__-backend.sh"
native_reference_render="$root/templates/forge/native-desktop/reference-app/scripts/render-native-desktop.sh"
grep -F "get-ui-prefs" "$reference_backend" >/dev/null
sh -n "$reference_backend"
grep -F "prepare-theurgy" "$theurgy_reference_backend" >/dev/null
sh -n "$theurgy_reference_backend"
sh -n "$native_reference_render"
grep -F "json-glib-1.0" "$native_reference_render" >/dev/null
grep -F "#include <json-glib/json-glib.h>" "$native_reference_render" >/dev/null
grep -F "apply_reference_snapshot" "$native_reference_render" >/dev/null
grep -F "Loaded native JSON snapshot into GTK list rows." "$native_reference_render" >/dev/null
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
grep -F "assets/forge-icon.png" "$root/templates/forge/web/reference-app/index.html" >/dev/null
grep -F "Reference App" "$root/templates/forge/web/reference-app/index.html" >/dev/null
grep -F "Theurgy" "$root/templates/forge/web/theurgy-reference-app/index.html" >/dev/null
grep -F "prepare-theurgy" "$root/templates/forge/web/theurgy-reference-app/scripts/__APP_SLUG__-backend.sh" >/dev/null
grep -F "desktopBridgeBootstrapSource" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "window.wizardry.exec = execCommand;" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "territory-master.png" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "plain-master.png" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "templates/web/.themes" "$root/apps/.host/macos/main.m" >/dev/null

grep -F "wizardry-apps Licensing" "$root/LICENSE" >/dev/null
grep -F "Generic blank projects emitted by Forge are different." "$root/LICENSE" >/dev/null
grep -F "intended to be sellable and hostable" "$root/LICENSE" >/dev/null
grep -F "Open Wizardry License 3.1" "$root/LICENSE" >/dev/null
grep -F "GNU AGPL-3.0-or-later with Wizardry Addendum 1.0" "$root/LICENSE" >/dev/null
grep -F "OPEN WIZARDRY LICENSE 3.1" "$root/licenses/OWL-3.1.txt" >/dev/null
grep -F "No Enclosure" "$root/licenses/OWL-3.1.txt" >/dev/null
grep -F "root \`LICENSE\` as the public-facing licensing overview" "$root/.github/WIZARDRY_APPS_LICENSING.md" >/dev/null

for emission_file in \
  "$root/apps/.host/shared/wizardry-bridge.js" \
  "$root/runtime/schemas/native-desktop-ir-v1.json" \
  "$root/runtime/schemas/native-mobile-ir-v1.json" \
  "$root/templates/forge/web/minimal/index.html" \
  "$root/templates/forge/web/minimal/style.css" \
  "$root/templates/forge/web/sidebar/index.html" \
  "$root/templates/forge/web/sidebar/style.css" \
  "$root/templates/forge/web/topbar/index.html" \
  "$root/templates/forge/web/topbar/style.css" \
  "$root/templates/forge/web/dashboard/index.html" \
  "$root/templates/forge/web/dashboard/style.css" \
  "$root/templates/forge/web/studio/index.html" \
  "$root/templates/forge/web/studio/style.css" \
  "$root/templates/forge/web/panel/index.html" \
  "$root/templates/forge/web/panel/style.css" \
  "$root/templates/forge/web/reference-app/index.html" \
  "$root/templates/forge/web/reference-app/style.css" \
  "$root/templates/forge/web/reference-app/script.js" \
  "$root/templates/forge/web/reference-app/scripts/__APP_SLUG__-backend.sh" \
  "$root/templates/forge/web/theurgy-reference-app/index.html" \
  "$root/templates/forge/web/theurgy-reference-app/style.css" \
  "$root/templates/forge/web/theurgy-reference-app/script.js" \
  "$root/templates/forge/web/theurgy-reference-app/scripts/__APP_SLUG__-backend.sh" \
  "$root/templates/forge/native-desktop/blank/app-blueprint/app.ir.yaml" \
  "$root/templates/forge/native-desktop/reference-app/app-blueprint/app.ir.yaml" \
  "$root/templates/forge/native-desktop/blank/scripts/render-native-desktop.sh" \
  "$root/templates/forge/native-desktop/reference-app/scripts/render-native-desktop.sh" \
  "$root/templates/forge/native-desktop/blank/scripts/validate-native-desktop-ir.sh" \
  "$root/templates/forge/native-desktop/reference-app/scripts/validate-native-desktop-ir.sh" \
  "$root/templates/forge/native-mobile/blank/app-blueprint/mobile.ir.yaml" \
  "$root/templates/forge/native-mobile/reference-app/app-blueprint/mobile.ir.yaml" \
  "$root/templates/forge/native-mobile/blank/scripts/render-native-mobile.sh" \
  "$root/templates/forge/native-mobile/reference-app/scripts/render-native-mobile.sh" \
  "$root/templates/forge/native-mobile/blank/scripts/validate-native-mobile-ir.sh" \
  "$root/templates/forge/native-mobile/reference-app/scripts/validate-native-mobile-ir.sh"
do
  grep -F "OWL 3.1" "$emission_file" >/dev/null || {
    printf '%s\n' "forge UI asset tests: emission material missing OWL notice: $emission_file" >&2
    exit 1
  }
  grep -F "AGPL-3.0-or-later" "$emission_file" >/dev/null || {
    printf '%s\n' "forge UI asset tests: emission material missing AGPL notice: $emission_file" >&2
    exit 1
  }
done
grep -F -- "--forge-boot-bg: var(--bg, #eceaf4);" "$root/apps/forge/style.css" >/dev/null
grep -F -- "--forge-boot-bg: var(--bg, #eceaf4);" "$root/apps/forge/index.html" >/dev/null
if grep -F "#edf2fa" "$root/apps/forge/style.css" "$root/apps/forge/index.html" "$root/apps/.host/macos/main.m" >/dev/null; then
  printf '%s\n' "forge UI asset tests: Forge splash must not use the old bluish fallback" >&2
  exit 1
fi
grep -F "underPageBackgroundColor = childPageBackingColor" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "underPageBackgroundColor = pageBackingColor" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "DESKTOP_BRIDGE_BOOTSTRAP" "$root/apps/.host/linux/main.c" >/dev/null
grep -F "window.wizardry.rpc = rpcBridge;" "$root/apps/.host/linux/main.c" >/dev/null
grep -F "window.wizardry.nativeAvailable" "$root/apps/forge/index.html" >/dev/null
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
grep -F 'Wizardry Cross-Platform Desktop Reference App' "$root/apps/forge/index.html" >/dev/null
grep -F 'Wizardry Cross-Platform Theurgy Reference App' "$root/apps/forge/index.html" >/dev/null
grep -F 'Wizardry Native Desktop Reference App' "$root/apps/forge/index.html" >/dev/null
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
grep -F "./forge-menu" "$root/README.md" >/dev/null
grep -F 'install-forge" --root "$root" --user' "$root/tools/forge/launch-forge.sh" >/dev/null
grep -F 'opened_app=' "$root/tools/forge/launch-forge.sh" >/dev/null
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
