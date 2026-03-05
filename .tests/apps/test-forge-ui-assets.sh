#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

[ -f "$root/apps/forge/index.html" ]
[ -f "$root/apps/forge/style.css" ]
[ -f "$root/apps/forge/README.md" ]
[ -x "$root/apps/forge/scripts/forge-backend.sh" ]
[ -x "$root/tools/forge/launch-forge.sh" ]
[ -x "$root/tools/forge/install-forge.sh" ]
[ -x "$root/tools/forge/uninstall-forge.sh" ]
[ -x "$root/tools/forge/build-forge-icon.sh" ]
[ -x "$root/tools/forge/build-forge-macos-app.sh" ]
[ -f "$root/apps/forge/assets/forge-icon.svg" ]
[ -x "$root/run-forge" ]
[ -x "$root/install-forge" ]
[ -x "$root/uninstall-forge" ]

grep -F "App Forge" "$root/apps/forge/index.html" >/dev/null
grep -F "forge-backend.sh" "$root/apps/forge/index.html" >/dev/null
grep -F "window.wizardry.rpc('bridge.exec'" "$root/apps/forge/index.html" >/dev/null
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
grep -F "is_valid_app_bundle" "$root/tools/forge/launch-forge.sh" >/dev/null

printf '%s\n' "forge UI asset tests passed"
