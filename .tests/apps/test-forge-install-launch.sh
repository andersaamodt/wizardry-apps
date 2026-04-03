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

scratch=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-install.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fake_home="$scratch/home"
mkdir -p "$fake_home"

install_out=$(sh "$install" --root "$root" --home "$fake_home")
printf '%s\n' "$install_out" | grep -F "installed_command=$fake_home/.local/bin/app-forge" >/dev/null
printf '%s\n' "$install_out" | grep -F "workspace_root_file=$fake_home/.config/wizardry-apps/forge-root" >/dev/null

shim="$fake_home/.local/bin/app-forge"
[ -x "$shim" ]
printf '%s\n' "$(cat "$shim")" | grep -F "$root/tools/forge/launch-forge" >/dev/null
[ -f "$fake_home/.config/wizardry-apps/forge-root" ]
[ "$(head -n 1 "$fake_home/.config/wizardry-apps/forge-root")" = "$root" ]

# Desktop integration files are OS-specific.
os=$(uname -s 2>/dev/null || printf unknown)
case "$os" in
  Darwin)
    icon_out="$scratch/forge-test.icns"
    icon_build_out=$(sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$icon_out")
    printf '%s\n' "$icon_build_out" | grep -F "source_icon=$root/apps/forge/assets/icons/macos/forge.icns" >/dev/null
    [ -f "$icon_out" ]
    cmp -s "$icon_out" "$root/apps/forge/assets/icons/macos/forge.icns"

    mac_build_out="$scratch/mac-build/App Forge.app"
    sh "$root/tools/forge/build-forge-macos-app.sh" --root "$root" --out "$mac_build_out" >/tmp/forge-mac-build.log
    [ -x "$mac_build_out/Contents/MacOS/wizardry-host" ]
    [ -x "$mac_build_out/Contents/MacOS/app-forge" ]
    [ -f "$mac_build_out/Contents/Resources/forge/index.html" ]
    [ -f "$mac_build_out/Contents/Resources/forge/.host/shared/wizardry-bridge.js" ]
    [ -f "$mac_build_out/Contents/Resources/.host/shared/wizardry-bridge.js" ]
    [ -f "$mac_build_out/Contents/Resources/wizardry-build-input.sha256" ]
    [ -f "$mac_build_out/Contents/Resources/wizardry-apps-root.txt" ]
    [ "$(head -n 1 "$mac_build_out/Contents/Resources/wizardry-apps-root.txt")" = "$root" ]
    [ -f "$mac_build_out/Contents/Info.plist" ]

    app_bundle="$fake_home/Applications/App Forge.app"
    [ -x "$app_bundle/Contents/MacOS/app-forge" ]
    [ -f "$app_bundle/Contents/Info.plist" ]
    grep -F "<key>CFBundleIconFile</key>" "$app_bundle/Contents/Info.plist" >/dev/null
    app_icon_file=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app_bundle/Contents/Info.plist")
    [ -n "$app_icon_file" ]
    app_icon_path="$app_bundle/Contents/Resources/$app_icon_file"
    if [ ! -f "$app_icon_path" ] && [ -f "$app_icon_path.icns" ]; then
      app_icon_path="$app_icon_path.icns"
    fi
    if [ ! -f "$app_icon_path" ] && [ -f "$app_icon_path.png" ]; then
      app_icon_path="$app_icon_path.png"
    fi
    [ -f "$app_icon_path" ]
    if [ "${app_icon_path##*.}" = "icns" ]; then
      cmp -s "$app_icon_path" "$root/apps/forge/assets/icons/macos/forge.icns"
    fi
    [ -f "$app_bundle/Contents/Resources/.host/shared/wizardry-bridge.js" ]
    [ -f "$app_bundle/Contents/Resources/wizardry-build-input.sha256" ]
    [ -f "$app_bundle/Contents/Resources/wizardry-apps-root.txt" ]
    [ "$(head -n 1 "$app_bundle/Contents/Resources/wizardry-apps-root.txt")" = "$root" ]
    ;;
  Linux)
    [ -f "$fake_home/.local/share/applications/app-forge.desktop" ]
    ;;
esac

# Shim should pass through help without launching host.
sh "$shim" --help | grep -F "Usage:" >/dev/null

sh "$uninstall" --home "$fake_home" >/tmp/forge-uninstall.txt
[ ! -e "$shim" ]
[ ! -e "$fake_home/.local/share/applications/app-forge.desktop" ]
[ ! -e "$fake_home/Applications/App Forge.app" ]
[ ! -e "$fake_home/.config/wizardry-apps/forge-root" ]

printf '%s\n' "forge install/launch tests passed"
