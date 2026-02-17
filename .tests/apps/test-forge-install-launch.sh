#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

launch="$root/tools/forge/launch-forge.sh"
install="$root/tools/forge/install-forge.sh"
uninstall="$root/tools/forge/uninstall-forge.sh"

[ -x "$launch" ]
[ -x "$install" ]
[ -x "$uninstall" ]
[ -x "$root/tools/forge/build-forge-macos-app.sh" ]
[ -x "$root/run-forge" ]
[ -x "$root/install-forge" ]
[ -x "$root/uninstall-forge" ]

sh "$launch" --help | grep -F "Usage:" >/dev/null
sh "$install" --help | grep -F "Usage:" >/dev/null
sh "$uninstall" --help | grep -F "Usage:" >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-forge-install.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fake_home="$scratch/home"
mkdir -p "$fake_home"

install_out=$(sh "$install" --root "$root" --home "$fake_home")
printf '%s\n' "$install_out" | grep -F "installed_command=$fake_home/.local/bin/wizardry-forge" >/dev/null
printf '%s\n' "$install_out" | grep -F "workspace_root_file=$fake_home/.config/wizardry-apps/forge-root" >/dev/null

shim="$fake_home/.local/bin/wizardry-forge"
[ -x "$shim" ]
printf '%s\n' "$(cat "$shim")" | grep -F "$root/tools/forge/launch-forge.sh" >/dev/null
[ -f "$fake_home/.config/wizardry-apps/forge-root" ]
[ "$(head -n 1 "$fake_home/.config/wizardry-apps/forge-root")" = "$root" ]

# Desktop integration files are OS-specific.
os=$(uname -s 2>/dev/null || printf unknown)
case "$os" in
  Darwin)
    icon_out="$scratch/forge-test.icns"
    sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$icon_out" >/tmp/forge-icon-build.log
    [ -f "$icon_out" ]

    mac_build_out="$scratch/mac-build/Wizardry Forge.app"
    sh "$root/tools/forge/build-forge-macos-app.sh" --root "$root" --out "$mac_build_out" >/tmp/forge-mac-build.log
    [ -x "$mac_build_out/Contents/MacOS/wizardry-host" ]
    [ -x "$mac_build_out/Contents/MacOS/wizardry-forge" ]
    [ -f "$mac_build_out/Contents/Resources/forge/index.html" ]
    [ -f "$mac_build_out/Contents/Resources/forge/.host/shared/wizardry-bridge.js" ]
    [ -f "$mac_build_out/Contents/Resources/wizardry-apps-root.txt" ]
    [ "$(head -n 1 "$mac_build_out/Contents/Resources/wizardry-apps-root.txt")" = "$root" ]
    [ -f "$mac_build_out/Contents/Info.plist" ]

    app_bundle="$fake_home/Applications/Wizardry Forge.app"
    [ -x "$app_bundle/Contents/MacOS/wizardry-forge" ]
    [ -f "$app_bundle/Contents/Info.plist" ]
    grep -F "<key>CFBundleIconFile</key>" "$app_bundle/Contents/Info.plist" >/dev/null
    [ -f "$app_bundle/Contents/Resources/forge.icns" ]
    [ -f "$app_bundle/Contents/Resources/wizardry-apps-root.txt" ]
    [ "$(head -n 1 "$app_bundle/Contents/Resources/wizardry-apps-root.txt")" = "$root" ]
    ;;
  Linux)
    [ -f "$fake_home/.local/share/applications/wizardry-forge.desktop" ]
    ;;
esac

# Shim should pass through help without launching host.
sh "$shim" --help | grep -F "Usage:" >/dev/null

sh "$uninstall" --home "$fake_home" >/tmp/forge-uninstall.txt
[ ! -e "$shim" ]
[ ! -e "$fake_home/.local/share/applications/wizardry-forge.desktop" ]
[ ! -e "$fake_home/Applications/Wizardry Forge.app" ]
[ ! -e "$fake_home/.config/wizardry-apps/forge-root" ]

printf '%s\n' "forge install/launch tests passed"
