#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

[ -f "$root/apps/forge/index.html" ]
[ -f "$root/apps/forge/style.css" ]
[ -f "$root/apps/forge/README.md" ]
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
grep -F "desktopBridgeBootstrapSource" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "window.wizardry.exec = execCommand;" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "territory-master.png" "$root/apps/.host/macos/main.m" >/dev/null
grep -F "plain-master.png" "$root/apps/.host/macos/main.m" >/dev/null
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
grep -F "scaffold-app" "$root/apps/forge/scripts/forge-backend.sh" >/dev/null
grep -F "Install user-local launchers/integration" "$root/apps/forge/README.md" >/dev/null
grep -F 'forge-backend" run-desktop "$root" forge' "$root/tools/forge/launch-forge.sh" >/dev/null
[ -f "$root/apps/forge/assets/icons/meta/territory-master.png" ]
[ -f "$root/apps/wizardry-desktop/assets/icons/meta/territory-master.png" ]
grep -F "territory_master=" "$root/apps/forge/assets/icons/meta/icon-settings.conf" >/dev/null
grep -F "territory_master=" "$root/apps/wizardry-desktop/assets/icons/meta/icon-settings.conf" >/dev/null
grep -F "assets/forge-icon.png" "$root/apps/forge/index.html" >/dev/null
grep -F 'plain_master="$project_dir/assets/icons/meta/plain-master.png"' "$root/apps/forge/scripts/forge-backend.sh" >/dev/null
grep -F "territory-master.png" "$root/apps/wizardry-desktop/index.html" >/dev/null
grep -F "territory-master.png" "$root/tools/forge/build-forge-icon.sh" >/dev/null

printf '%s\n' "forge UI asset tests passed"
