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

newline_root="$scratch/root
status=forged"
mkdir -p "$newline_root/apps/forge/scripts"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" pid=1234' > "$newline_root/apps/forge/scripts/forge-backend"
chmod +x "$newline_root/apps/forge/scripts/forge-backend"
if XDG_CONFIG_HOME="$scratch/launch-config" XDG_STATE_HOME="$scratch/launch-state" sh "$launch" --root "$newline_root" >"$scratch/launch-newline.out" 2>"$scratch/launch-newline.err"; then
  printf '%s\n' "launch-forge accepted newline root path" >&2
  exit 1
fi
grep -F "root path must not contain line breaks" "$scratch/launch-newline.err" >/dev/null
[ ! -e "$scratch/launch-config/wizardry-apps/forge-root" ]

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

traversal_build_parent="$scratch/build-parent"
traversal_build_target="$traversal_build_parent/safe.app/../victim.app"
mkdir -p "$traversal_build_parent/victim.app"
printf '%s\n' "preserve" >"$traversal_build_parent/victim.app/marker"
if sh "$root/tools/forge/build-forge-macos-app.sh" --root "$root" --out "$traversal_build_target" >"$scratch/build-traversal.out" 2>"$scratch/build-traversal.err"; then
  printf '%s\n' "build-forge-macos-app accepted traversal app output path" >&2
  exit 1
fi
grep -F "output path must be a safe .app bundle path" "$scratch/build-traversal.err" >/dev/null
grep -Fx "preserve" "$traversal_build_parent/victim.app/marker" >/dev/null

preserve_build_root="$scratch/preserve-build-root"
preserve_build_bin="$scratch/preserve-build-bin"
preserve_build_target="$scratch/preserve-build/App Forge.app"
mkdir -p \
  "$preserve_build_root/tools/forge" \
  "$preserve_build_root/apps/.host/macos" \
  "$preserve_build_root/apps/.host/shared" \
  "$preserve_build_root/apps/forge" \
  "$preserve_build_root/web/.themes" \
  "$preserve_build_root/core/include" \
  "$preserve_build_root/core/src" \
  "$preserve_build_bin" \
  "$preserve_build_target/Contents"
cp "$root/tools/forge/build-forge-macos-app.sh" "$preserve_build_root/tools/forge/build-forge-macos-app.sh"
printf '%s\n' "int main(void){return 0;}" >"$preserve_build_root/apps/.host/macos/main.m"
printf '%s\n' "<main></main>" >"$preserve_build_root/apps/forge/index.html"
printf '%s\n' "bridge" >"$preserve_build_root/apps/.host/shared/wizardry-bridge.js"
printf '%s\n' "header" >"$preserve_build_root/core/include/wizardry.h"
printf '%s\n' "source" >"$preserve_build_root/core/src/wizardry.c"
printf '%s\n' "preserve" >"$preserve_build_target/marker"
cat >"$preserve_build_bin/uname" <<'SH'
#!/bin/sh
printf '%s\n' Darwin
SH
cat >"$preserve_build_bin/clang" <<'SH'
#!/bin/sh
out=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      shift
      out=${1-}
      ;;
  esac
  shift
done
[ -n "$out" ] || exit 2
mkdir -p "$(dirname "$out")"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$out"
chmod +x "$out"
SH
cat >"$preserve_build_bin/codesign" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$preserve_build_bin/cp" <<'SH'
#!/bin/sh
last=''
for arg in "$@"; do
  last=$arg
done
if [ "${1-}" = "-R" ]; then
  case "${2-}:$last" in
    *"/App Forge.app:"*"/App Forge.app")
      exit 1
      ;;
  esac
fi
exec /bin/cp "$@"
SH
chmod +x "$preserve_build_bin/uname" "$preserve_build_bin/clang" \
  "$preserve_build_bin/codesign" "$preserve_build_bin/cp"
if PATH="$preserve_build_bin:/bin:/usr/bin:/usr/sbin:/sbin" \
    sh "$root/tools/forge/build-forge-macos-app.sh" \
      --root "$preserve_build_root" \
      --out "$preserve_build_target" >"$scratch/build-preserve.out" 2>"$scratch/build-preserve.err"; then
  printf '%s\n' "build-forge-macos-app succeeded with failing final bundle copy" >&2
  exit 1
fi
grep -F "failed to copy macOS app bundle" "$scratch/build-preserve.err" >/dev/null
grep -Fx "preserve" "$preserve_build_target/marker" >/dev/null

bad_icon_out="$scratch/forge-icon.png"
if sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$bad_icon_out" >"$scratch/bad-icon-out.out" 2>"$scratch/bad-icon-out.err"; then
  printf '%s\n' "build-forge-icon accepted non-icns output path" >&2
  exit 1
fi
grep -F "output path must be an .icns file" "$scratch/bad-icon-out.err" >/dev/null

icon_newline_out="$scratch/forge-icon
status=forged.icns"
if sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$icon_newline_out" >"$scratch/icon-newline.out" 2>"$scratch/icon-newline.err"; then
  printf '%s\n' "build-forge-icon accepted newline output path" >&2
  exit 1
fi
grep -F "output path must not contain line breaks" "$scratch/icon-newline.err" >/dev/null

traversal_icon_parent="$scratch/icon-parent"
traversal_icon_target="$traversal_icon_parent/safe.icns/../victim.icns"
mkdir -p "$traversal_icon_parent"
printf '%s\n' "preserve" >"$traversal_icon_parent/victim.icns"
if sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$traversal_icon_target" >"$scratch/icon-traversal.out" 2>"$scratch/icon-traversal.err"; then
  printf '%s\n' "build-forge-icon accepted traversal icon output path" >&2
  exit 1
fi
grep -F "output path must be a safe .icns file path" "$scratch/icon-traversal.err" >/dev/null
grep -Fx "preserve" "$traversal_icon_parent/victim.icns" >/dev/null

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
grep -F "app path must be a safe .app bundle path" "$scratch/install-not-app.err" >/dev/null
[ -d "$not_app_install_target" ]

traversal_install_parent="$scratch/install-parent"
traversal_install_target="$traversal_install_parent/safe.app/../victim.app"
mkdir -p "$traversal_install_parent/victim.app"
printf '%s\n' "preserve" >"$traversal_install_parent/victim.app/marker"
if sh "$install" --root "$root" --home "$fake_home" --app-dir "$traversal_install_target" >"$scratch/install-traversal.out" 2>"$scratch/install-traversal.err"; then
  printf '%s\n' "install-forge accepted traversal app install path" >&2
  exit 1
fi
grep -F "app path must be a safe .app bundle path" "$scratch/install-traversal.err" >/dev/null
grep -Fx "preserve" "$traversal_install_parent/victim.app/marker" >/dev/null

preserve_install_root="$scratch/preserve-install-root"
preserve_install_bin="$scratch/preserve-install-bin"
preserve_install_target="$scratch/preserve-install/App Forge.app"
mkdir -p "$preserve_install_root/tools/forge" "$preserve_install_root/apps/forge" \
  "$preserve_install_bin" "$preserve_install_target/Contents"
printf '%s\n' "preserve" >"$preserve_install_target/marker"
cat >"$preserve_install_root/tools/forge/launch-forge" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$preserve_install_root/tools/forge/build-forge-macos-app" <<'SH'
#!/bin/sh
out=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      shift
      out=${1-}
      ;;
  esac
  shift
done
[ -n "$out" ] || exit 2
mkdir -p "$out/Contents/MacOS" "$out/Contents/Resources"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$out/Contents/MacOS/app-forge"
chmod +x "$out/Contents/MacOS/app-forge"
printf '%s\n' '<plist></plist>' >"$out/Contents/Info.plist"
SH
cat >"$preserve_install_bin/uname" <<'SH'
#!/bin/sh
printf '%s\n' Darwin
SH
cat >"$preserve_install_bin/cp" <<'SH'
#!/bin/sh
exit 1
SH
cat >"$preserve_install_bin/ditto" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$preserve_install_root/tools/forge/launch-forge" \
  "$preserve_install_root/tools/forge/build-forge-macos-app" \
  "$preserve_install_bin/uname" "$preserve_install_bin/cp" "$preserve_install_bin/ditto"
if PATH="$preserve_install_bin:/bin:/usr/bin:/usr/sbin:/sbin" \
    sh "$install" --root "$preserve_install_root" --home "$fake_home" \
    --app-dir "$preserve_install_target" >"$scratch/install-preserve.out" 2>"$scratch/install-preserve.err"; then
  printf '%s\n' "install-forge succeeded with failing bundle copy" >&2
  exit 1
fi
grep -Fx "preserve" "$preserve_install_target/marker" >/dev/null

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
grep -F "app path must be a safe .app bundle path" "$scratch/uninstall-danger.err" >/dev/null
[ -d "$danger_dir" ]

traversal_remove_parent="$scratch/remove-parent"
traversal_remove_target="$traversal_remove_parent/safe.app/../victim.app"
mkdir -p "$traversal_remove_parent/victim.app"
printf '%s\n' "preserve" >"$traversal_remove_parent/victim.app/marker"
if sh "$uninstall" --home "$fake_home" --app-dir "$traversal_remove_target" >"$scratch/uninstall-traversal.out" 2>"$scratch/uninstall-traversal.err"; then
  printf '%s\n' "uninstall-forge accepted traversal app removal path" >&2
  exit 1
fi
grep -F "app path must be a safe .app bundle path" "$scratch/uninstall-traversal.err" >/dev/null
grep -Fx "preserve" "$traversal_remove_parent/victim.app/marker" >/dev/null

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
