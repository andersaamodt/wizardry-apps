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

build_icns_from_png() {
  png_source=$1
  out_path=$2
  iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-iconset.XXXXXX")
  iconset="${iconset_tmp}.iconset"
  mv "$iconset_tmp" "$iconset"
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$png_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$png_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_path")"
  iconutil -c icns "$iconset" -o "$out_path" >/dev/null 2>&1
  rm -rf "$iconset"
}

sh "$launch" --help | grep -F "Usage:" >/dev/null
sh "$install" --help | grep -F "Usage:" >/dev/null
sh "$uninstall" --help | grep -F "Usage:" >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-install.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fake_home="$scratch/home"
mkdir -p "$fake_home"

if sh "$root/tools/forge/build-forge-macos-app.sh" --root "$root" --out "$scratch/Bad.app" --bundle-id 'com.example/../../bad' >"$scratch/bad-bundle.out" 2>"$scratch/bad-bundle.err"; then
  printf '%s\n' "build-forge-macos-app accepted invalid bundle id" >&2
  exit 1
fi
grep -F "invalid bundle id" "$scratch/bad-bundle.err" >/dev/null

not_app_bundle="$scratch/not-a-bundle"
mkdir -p "$not_app_bundle"
if sh "$root/tools/forge/build-forge-macos-app.sh" --root "$root" --out "$not_app_bundle" >"$scratch/bad-out-bundle.out" 2>"$scratch/bad-out-bundle.err"; then
  printf '%s\n' "build-forge-macos-app accepted non-app output path" >&2
  exit 1
fi
grep -F "output path must be a .app bundle" "$scratch/bad-out-bundle.err" >/dev/null
[ -d "$not_app_bundle" ]

unsafe_root="$scratch/unsafe\$root"
fake_uname_bin="$scratch/fake-uname-bin"
mkdir -p "$unsafe_root/tools/forge" "$unsafe_root/apps/forge" "$fake_uname_bin"
cat >"$unsafe_root/tools/forge/launch-forge" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$unsafe_root/tools/forge/build-forge-macos-app" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$fake_uname_bin/uname" <<'SH'
#!/bin/sh
printf '%s\n' "Linux"
SH
chmod +x "$unsafe_root/tools/forge/launch-forge" "$unsafe_root/tools/forge/build-forge-macos-app" "$fake_uname_bin/uname"
if PATH="$fake_uname_bin:$PATH" sh "$install" --root "$unsafe_root" --home "$fake_home" >"$scratch/unsafe-root.out" 2>"$scratch/unsafe-root.err"; then
  printf '%s\n' "install-forge accepted shell-unsafe root path" >&2
  exit 1
fi
grep -F "unsafe root path" "$scratch/unsafe-root.err" >/dev/null

not_app_install_target="$scratch/not-an-install-app"
mkdir -p "$not_app_install_target"
if sh "$install" --root "$root" --home "$fake_home" --app-dir "$not_app_install_target" >"$scratch/install-not-app.out" 2>"$scratch/install-not-app.err"; then
  printf '%s\n' "install-forge accepted non-app install path" >&2
  exit 1
fi
grep -F "app path must be a .app bundle" "$scratch/install-not-app.err" >/dev/null
[ -d "$not_app_install_target" ]

install_out=$(sh "$install" --root "$root" --home "$fake_home")
printf '%s\n' "$install_out" | grep -F "installed_command=$fake_home/.local/bin/app-forge" >/dev/null
printf '%s\n' "$install_out" | grep -F "workspace_root_file=$fake_home/.config/wizardry-apps/forge-root" >/dev/null

shim="$fake_home/.local/bin/app-forge"
[ -x "$shim" ]
printf '%s\n' "$(cat "$shim")" | grep -F "$root/tools/forge/launch-forge" >/dev/null
[ -f "$fake_home/.config/wizardry-apps/forge-root" ]
[ "$(head -n 1 "$fake_home/.config/wizardry-apps/forge-root")" = "$root" ]

danger_dir="$scratch/not-an-app"
mkdir -p "$danger_dir"
if sh "$uninstall" --home "$fake_home" --app-dir "$danger_dir" >"$scratch/uninstall-danger.out" 2>"$scratch/uninstall-danger.err"; then
  printf '%s\n' "uninstall-forge accepted non-app removal path" >&2
  exit 1
fi
grep -F "app path must be a .app bundle" "$scratch/uninstall-danger.err" >/dev/null
[ -d "$danger_dir" ]

# Desktop integration files are OS-specific.
os=$(uname -s 2>/dev/null || printf unknown)
case "$os" in
  Darwin)
    icon_out="$scratch/forge-test.icns"
    icon_build_out=$(sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$icon_out")
    printf '%s\n' "$icon_build_out" | grep -F "source_icon=$root/apps/forge/assets/icons/meta/apple-master.png" >/dev/null
    [ -f "$icon_out" ]
    expected_icon_base=$(mktemp "${TMPDIR:-/tmp}/forge-install-expected.XXXXXX")
    expected_icon="$expected_icon_base.icns"
    rm -f "$expected_icon"
    build_icns_from_png "$root/apps/forge/assets/icons/meta/apple-master.png" "$expected_icon"
    cmp -s "$icon_out" "$expected_icon"

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
      cmp -s "$app_icon_path" "$expected_icon"
    fi
    [ -f "$app_bundle/Contents/Resources/.host/shared/wizardry-bridge.js" ]
    [ -f "$app_bundle/Contents/Resources/wizardry-build-input.sha256" ]
    [ -f "$app_bundle/Contents/Resources/wizardry-apps-root.txt" ]
    [ "$(head -n 1 "$app_bundle/Contents/Resources/wizardry-apps-root.txt")" = "$root" ]
    rm -f "$expected_icon"
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
