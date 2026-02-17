#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

[ -f "$root/.apps/forge/index.html" ]
[ -f "$root/.apps/forge/style.css" ]
[ -f "$root/.apps/forge/README.md" ]
[ -x "$root/.apps/forge/scripts/forge-backend.sh" ]
[ -x "$root/tools/forge/launch-forge.sh" ]
[ -x "$root/tools/forge/install-forge.sh" ]
[ -x "$root/tools/forge/uninstall-forge.sh" ]
[ -x "$root/tools/forge/build-forge-icon.sh" ]
[ -x "$root/tools/forge/build-forge-macos-app.sh" ]
[ -f "$root/.apps/forge/assets/forge-icon.svg" ]
[ -x "$root/run-forge" ]
[ -x "$root/install-forge" ]
[ -x "$root/uninstall-forge" ]

grep -F "Wizardry Forge" "$root/.apps/forge/index.html" >/dev/null
grep -F "forge-backend.sh" "$root/.apps/forge/index.html" >/dev/null
grep -F "window.wizardry.rpc('bridge.exec'" "$root/.apps/forge/index.html" >/dev/null
grep -F -- "--accent" "$root/.apps/forge/style.css" >/dev/null
grep -F "scaffold-app" "$root/.apps/forge/scripts/forge-backend.sh" >/dev/null
grep -F "Install user-local launchers/integration" "$root/.apps/forge/README.md" >/dev/null
grep -F "is_valid_app_bundle" "$root/tools/forge/launch-forge.sh" >/dev/null

printf '%s\n' "forge UI asset tests passed"
