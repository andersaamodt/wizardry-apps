#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$test_root/apps/forge/scripts/forge-backend.sh"
state_home=${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}
test_scratch_root=${WIZARDRY_APPS_TEST_SCRATCH_ROOT:-"$state_home/wizardry-apps/test-scratch"}

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

build_icns_from_png() {
  png_source=$1
  out_path=$2
  iconset="$test_scratch_root/forge-backend-iconset.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$png_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$png_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_path")"
  iconutil -c icns "$iconset" -o "$out_path" >/dev/null 2>&1
  rm -rf "$iconset"
}

# Forge self-run should return a restart bundle for host-owned relaunch.
grep -F 'printf '\''restart_bundle=%s\n'\'' "$installed_path"' "$backend" >/dev/null
grep -F 'printf '\''restart_bundle=%s\n'\'' "$launch_bundle"' "$backend" >/dev/null
grep -F 'printf '\''restart_stage=%s\n'\'' "$restart_stage"' "$backend" >/dev/null
grep -F "elif [ -f \"\$app_dir/assets/forge-icon.png\" ];" "$backend" >/dev/null

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "skip: jq not installed" >&2
  exit 0
fi

out=$(sh "$backend" --help)
printf '%s' "$out" | grep -F "Usage:" >/dev/null
printf '%s\n' "$out" | grep -F "import-workspace [ROOT_HINT] WORKSPACE_PATH [PROJECT_ROOT]" >/dev/null
printf '%s\n' "$out" | grep -F "hide-workspace [ROOT_HINT] WORKSPACE_PATH" >/dev/null
printf '%s\n' "$out" | grep -F "unhide-workspace [ROOT_HINT] WORKSPACE_PATH" >/dev/null
printf '%s\n' "$out" | grep -F "rename-workspace [ROOT_HINT] WORKSPACE_PATH NEW_TITLE" >/dev/null
printf '%s\n' "$out" | grep -F "workspace-git-init [ROOT_HINT] WORKSPACE_PATH [REMOTE_URL] [BRANCH]" >/dev/null
printf '%s\n' "$out" | grep -F "workspace-git-install-release [ROOT_HINT] WORKSPACE_PATH" >/dev/null
grep -F 'self_relaunch=1' "$backend" >/dev/null
grep -F 'launch_workspace_bundle_macos "$launch_bundle" "$launch_bundle/Contents/MacOS/wizardry-host" "$launch_app_dir"' "$backend" >/dev/null
grep -F 'launch_workspace_bundle_macos "$installed_path" "$installed_path/Contents/MacOS/wizardry-host" "$installed_app_dir"' "$backend" >/dev/null
grep -F 'open -n "$bundle"' "$backend" >/dev/null
grep -F 'launch_bundle="$bundle_artifact"' "$backend" >/dev/null
grep -F 'launch_macos_bundle_async "$artifact"' "$backend" >/dev/null
grep -F 'printf '\''built_artifact=%s\n'\'' "$final_bundle"' "$backend" >/dev/null
grep -F 'install_macos_bundle "$artifact" "$install_path"' "$backend" >/dev/null
grep -F 'forge_with_serialized_macos_desktop_operation() {' "$backend" >/dev/null
grep -F 'scrub_macos_bundle_launch_metadata() {' "$backend" >/dev/null
grep -F 'macos_bundle_launch_policy_usable() {' "$backend" >/dev/null
if grep -F -- '--assess --type exec' "$backend" >/dev/null; then
  printf '%s\n' "forge backend test: install/run path must not preflight app launches with spctl" >&2
  exit 1
fi
grep -F 'cmd_run_desktop_unlocked "$cmd_run_desktop_root" "$cmd_run_desktop_slug" "$cmd_run_desktop_mode"' "$backend" >/dev/null
grep -F 'cmd_run_workspace_unlocked "$cmd_run_workspace_root" "$cmd_run_workspace_path" "$cmd_run_workspace_context" "$cmd_run_workspace_mode"' "$backend" >/dev/null
grep -F 'cmd_install_workspace_unlocked "$cmd_install_workspace_root" "$cmd_install_workspace_path" "$cmd_install_workspace_context" "$cmd_install_workspace_target"' "$backend" >/dev/null
grep -F 'exec /bin/sh "$SCRIPT_DIR/forge-backend.sh" "$@"' "$test_root/apps/forge/scripts/forge-backend" >/dev/null
grep -F 'install_out=$(cmd_install_workspace_unlocked "$root" "$workspace_path" "$context" "$host_target")' "$backend" >/dev/null
grep -F 'resolve_native_macos_package_dir "$root" "$workspace_path" "$workspace_slug"' "$backend" >/dev/null
grep -F '$1 == "macos" {' "$backend" >/dev/null
grep -F '${XDG_STATE_HOME:-$HOME/.local/state}/$resolve_native_macos_package_workspace_slug/generated/macos' "$backend" >/dev/null
mic_usage_count=$(grep -F '<key>NSMicrophoneUsageDescription</key><string>This app uses the microphone for local voice input and voice automation commands.</string>' "$backend" | wc -l | tr -d ' ')
case "$mic_usage_count" in
  ''|0|1|2|3)
    printf '%s\n' "forge backend test: macOS bundle templates are missing microphone usage descriptions" >&2
    exit 1
    ;;
esac
if grep -F 'rm -rf "$install_path"' "$backend" >/dev/null; then
  printf '%s\n' "forge backend test: macOS install path is removed before replacement" >&2
  exit 1
fi
if grep -F 'rm -rf "$dest_bundle"' "$backend" >/dev/null; then
  printf '%s\n' "forge backend test: macOS bundle sync removes existing install before copy" >&2
  exit 1
fi

out=$(sh "$backend" doctor "$test_root")
printf '%s\n' "$out" | grep -F "root=$test_root" >/dev/null
printf '%s\n' "$out" | grep -F "os=" >/dev/null
doctor_injected=$(HOME="${TMPDIR:-/tmp}/forge-home$(printf '\r')forged=1" sh "$backend" doctor "$test_root")
if printf '%s\n' "$doctor_injected" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge doctor emitted forged key-value output from HOME" >&2
  exit 1
fi

os_name=$(uname -s 2>/dev/null || printf unknown)
if [ "$os_name" = "Darwin" ] && [ -x /usr/libexec/PlistBuddy ]; then
  build_out=$(sh "$backend" build-desktop "$test_root" forge)
  forge_artifact=$(printf '%s\n' "$build_out" | awk -F= '/^artifact=/{print $2; exit}')
  [ -n "$forge_artifact" ] || {
    printf '%s\n' "forge backend test: missing build artifact path for forge" >&2
    exit 1
  }
  [ -f "$forge_artifact/Contents/Info.plist" ] || {
    printf '%s\n' "forge backend test: missing Info.plist in forge artifact" >&2
    exit 1
  }
  forge_icon_file=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$forge_artifact/Contents/Info.plist")
  [ -n "$forge_icon_file" ] || {
    printf '%s\n' "forge backend test: missing CFBundleIconFile value" >&2
    exit 1
  }
  forge_icon_path="$forge_artifact/Contents/Resources/$forge_icon_file"
  if [ ! -f "$forge_icon_path" ] && [ -f "$forge_icon_path.icns" ]; then
    forge_icon_path="$forge_icon_path.icns"
  fi
  if [ ! -f "$forge_icon_path" ] && [ -f "$forge_icon_path.png" ]; then
    forge_icon_path="$forge_icon_path.png"
  fi
  [ -f "$forge_icon_path" ] || {
    printf '%s\n' "forge backend test: icon file referenced by CFBundleIconFile is missing" >&2
    exit 1
  }
  if [ "${forge_icon_path##*.}" = "icns" ]; then
    expected_forge_base=$(mktemp "${TMPDIR:-/tmp}/forge-backend-expected.XXXXXX")
    expected_forge_icon="$expected_forge_base.icns"
    rm -f "$expected_forge_icon"
    build_icns_from_png "$test_root/apps/forge/assets/icons/meta/apple-master.png" "$expected_forge_icon"
    cmp -s "$forge_icon_path" "$expected_forge_icon" || {
      printf '%s\n' "forge backend test: desktop bundle icon drifted from Apple-ready macOS icon master" >&2
      exit 1
    }
    rm -f "$expected_forge_icon"
  fi
fi

apps=$(sh "$backend" list-apps "$test_root")
printf '%s\n' "$apps" | awk -F'\t' '$1 == "artificer-web" { if ($2 != "Artificer Web" || $5 != "web" || $7 != "optional") exit 1; found = 1 } END { exit(found ? 0 : 1) }'
printf '%s\n' "$apps" | awk -F'\t' '$1 == "artificer-native" { if ($2 != "Artificer" || $5 != "native-desktop" || $7 != "core") exit 1; found = 1 } END { exit(found ? 0 : 1) }'
printf '%s\n' "$apps" | grep -E '^forge\t' >/dev/null

templates=$(sh "$backend" list-templates "$test_root")
printf '%s\n' "$templates" | grep -E '^demo\t' >/dev/null

scratch="$test_scratch_root/forge-backend"
rm -rf "$scratch"
mkdir -p "$scratch"
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

native_repair_ws="$scratch/native-repair"
mkdir -p "$native_repair_ws/app-blueprint" "$native_repair_ws/scripts"
cat >"$native_repair_ws/app-blueprint/app.ir.yaml" <<'IR'
{
  "schemaVersion": "1.0",
  "app": {
    "id": "native-repair",
    "name": "Native Repair"
  },
  "window": {
    "id": "main-window",
    "type": "Window",
    "title": "Native Repair"
  }
}
IR
cat >"$native_repair_ws/scripts/render-native-desktop.sh" <<'SH'
#!/bin/sh
set -eu
mkdir -p generated/macos
SH
chmod +x "$native_repair_ws/scripts/render-native-desktop.sh"
cat >"$native_repair_ws/wizardry.workspace.conf" <<CONF
# Wizardry Apps project profile
project_id=native-repair
title=Native Repair
project_type=native-desktop
development_context=native-desktop
starter=import-native-desktop
profile_kind=detected
targets=macos,linux
root=$native_repair_ws
native_ir_path=app-blueprint/app.ir.yaml
run_rebuild_command=:
CONF
sh "$backend" import-workspace "$test_root" "$native_repair_ws" "$scratch" >/dev/null
grep -F 'run_rebuild_command=sh scripts/render-native-desktop.sh' "$native_repair_ws/wizardry.workspace.conf" >/dev/null

bundle_install_functions=$(awk '
  /^copy_macos_bundle_contents\(\)/ { printing = 1 }
  /^macos_app_is_running\(\)/ { printing = 0 }
  printing { print }
' "$backend")
bundle_install_probe="$scratch/bundle-install-probe.sh"
cat >"$bundle_install_probe" <<SH
#!/bin/sh
set -eu

validate_macos_app_bundle_name() {
  case "\${1-}" in
    *.app) return 0 ;;
    *) return 1 ;;
  esac
}

hash_file_sha256() {
  cksum "\$1" | awk '{ print \$1 "-" \$2 }'
}

ensure_macos_bundle_signature() {
  return 0
}

macos_bundle_launch_policy_usable() {
  return 0
}

$bundle_install_functions

src="\${1?missing source bundle}"
dest="\${2?missing destination bundle}"
install_macos_bundle "\$src" "\$dest"
SH
chmod +x "$bundle_install_probe"

bundle_install_bin="$scratch/bundle-install-bin"
bundle_install_src="$scratch/Source.app"
bundle_install_dest="$scratch/Installed.app"
mkdir -p "$bundle_install_bin" "$bundle_install_src/Contents/MacOS" "$bundle_install_dest/Contents"
printf '%s\n' "stale" >"$bundle_install_dest/Contents/stale-file"
printf '%s\n' '<plist></plist>' >"$bundle_install_src/Contents/Info.plist"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$bundle_install_src/Contents/MacOS/probe"
chmod +x "$bundle_install_src/Contents/MacOS/probe"
cat >"$bundle_install_bin/ditto" <<'SH'
#!/bin/sh
set -eu
for expected in --norsrc --noextattr --noqtn --noacl; do
  [ "${1-}" = "$expected" ] || {
    printf '%s\n' "ditto missing metadata-clean flag: $expected" >&2
    exit 8
  }
  shift
done
src=${1?missing source}
dest=${2?missing destination}
if [ "$src" = "$dest" ]; then
  printf '%s\n' "ditto received identical source and destination: $src" >&2
  exit 7
fi
printf '%s\t%s\n' "$src" "$dest" >>"${FORGE_DITTO_LOG?missing log path}"
mkdir -p "$dest"
cp -R "$src/." "$dest"
SH
chmod +x "$bundle_install_bin/ditto"
FORGE_DITTO_LOG="$scratch/bundle-install-ditto.log" \
  PATH="$bundle_install_bin:/bin:/usr/bin:/usr/sbin:/sbin" \
  sh "$bundle_install_probe" "$bundle_install_src" "$bundle_install_dest"
[ -x "$bundle_install_dest/Contents/MacOS/probe" ] || {
  printf '%s\n' "forge backend test: macOS bundle install did not populate destination" >&2
  exit 1
}

bundle_unchanged_src="$scratch/UnchangedSource.app"
bundle_unchanged_dest="$scratch/UnchangedInstalled.app"
mkdir -p "$bundle_unchanged_src/Contents/Resources" "$bundle_unchanged_dest/Contents/Resources"
cat >"$bundle_unchanged_src/Contents/Info.plist" <<'PLIST'
<plist><dict>
<key>CFBundleIdentifier</key><string>com.example.unchanged</string>
<key>CFBundleVersion</key><string>42</string>
</dict></plist>
PLIST
cp "$bundle_unchanged_src/Contents/Info.plist" "$bundle_unchanged_dest/Contents/Info.plist"
printf '%s\n' "same-build" >"$bundle_unchanged_src/Contents/Resources/wizardry-build-input.sha256"
printf '%s\n' "same-build" >"$bundle_unchanged_dest/Contents/Resources/wizardry-build-input.sha256"
printf '%s\n' "preserve" >"$bundle_unchanged_dest/Contents/preserved-file"
FORGE_DITTO_LOG="$scratch/bundle-install-unchanged-ditto.log" \
  PATH="$bundle_install_bin:/bin:/usr/bin:/usr/sbin:/sbin" \
  sh "$bundle_install_probe" "$bundle_unchanged_src" "$bundle_unchanged_dest"
[ ! -f "$scratch/bundle-install-unchanged-ditto.log" ] || {
  printf '%s\n' "forge backend test: unchanged macOS bundle install should not recopy destination" >&2
  exit 1
}
grep -Fx "preserve" "$bundle_unchanged_dest/Contents/preserved-file" >/dev/null || {
  printf '%s\n' "forge backend test: unchanged macOS bundle install should preserve destination contents" >&2
  exit 1
}

codesign_identity_functions=$(awk '
  /^macos_codesign_identity\(\)/ { printing = 1 }
  /^ensure_macos_bundle_signature\(\)/ { printing = 0 }
  printing { print }
' "$backend")
codesign_identity_probe="$scratch/codesign-identity-probe.sh"
cat >"$codesign_identity_probe" <<SH
#!/bin/sh
set -eu

$codesign_identity_functions

macos_codesign_identity
SH
chmod +x "$codesign_identity_probe"

codesign_identity_bin="$scratch/codesign-identity-bin"
mkdir -p "$codesign_identity_bin"
cat >"$codesign_identity_bin/security" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' '  1) ABCDEF1234567890 "Wizardry Local Code Signing"'
SH
chmod +x "$codesign_identity_bin/security"

codesign_identity_detected=$(PATH="$codesign_identity_bin:/bin:/usr/bin:/usr/sbin:/sbin" sh "$codesign_identity_probe")
[ "$codesign_identity_detected" = "-" ] || {
  printf '%s\n' "forge backend test: macOS codesign identity probe should ignore detected local identities" >&2
  exit 1
}

codesign_identity_override=$(PATH="$codesign_identity_bin:/bin:/usr/bin:/usr/sbin:/sbin" WIZARDRY_CODESIGN_IDENTITY="Manual Override Identity" sh "$codesign_identity_probe")
[ "$codesign_identity_override" = "Manual Override Identity" ] || {
  printf '%s\n' "forge backend test: macOS codesign identity probe did not honor WIZARDRY_CODESIGN_IDENTITY" >&2
  exit 1
}

cat >"$codesign_identity_bin/security-empty" <<'SH'
#!/bin/sh
set -eu
exit 0
SH
chmod +x "$codesign_identity_bin/security-empty"
ln -sf "$codesign_identity_bin/security-empty" "$codesign_identity_bin/security"
codesign_identity_fallback=$(PATH="$codesign_identity_bin:/bin:/usr/bin:/usr/sbin:/sbin" sh "$codesign_identity_probe")
[ "$codesign_identity_fallback" = "-" ] || {
  printf '%s\n' "forge backend test: macOS codesign identity probe did not fall back to ad hoc signing" >&2
  exit 1
}
[ ! -e "$bundle_install_dest/Contents/stale-file" ] || {
  printf '%s\n' "forge backend test: macOS bundle install left stale destination files" >&2
  exit 1
}
[ ! -e "$bundle_install_dest.previous" ] || {
  printf '%s\n' "forge backend test: macOS bundle install left stale backup bundle" >&2
  exit 1
}
ditto_calls=$(wc -l <"$scratch/bundle-install-ditto.log" | tr -d ' ')
[ "$ditto_calls" = "1" ] || {
  printf '%s\n' "forge backend test: expected one staged bundle ditto call" >&2
  exit 1
}
if awk -F '\t' '$1 == $2 { found = 1 } END { exit found ? 0 : 1 }' "$scratch/bundle-install-ditto.log"; then
  printf '%s\n' "forge backend test: macOS bundle install copied a bundle onto itself" >&2
  exit 1
fi

prefs_home="$scratch/prefs-home"
mkdir -p "$prefs_home"
if XDG_CONFIG_HOME="$prefs_home/.config" sh "$backend" set-ui-pref "$scratch" "ab/key" value >/tmp/forge-invalid-pref.out 2>/tmp/forge-invalid-pref.err; then
  printf '%s\n' "forge backend test: invalid UI pref key accepted" >&2
  exit 1
fi
grep -F "invalid UI pref key" /tmp/forge-invalid-pref.err >/dev/null
prefs_file="$prefs_home/.config/wizardry-apps/forge-ui.conf"
mkdir -p "$(dirname "$prefs_file")"
{
  printf 'sidebar.width=320\rforged=1\n'
  printf 'ab/key=value\n'
  printf 'theme=dark\n'
} >"$prefs_file"
ui_prefs_out=$(XDG_CONFIG_HOME="$prefs_home/.config" sh "$backend" get-ui-prefs "$scratch")
printf '%s\n' "$ui_prefs_out" | grep -F "sidebar.width=320 forged=1" >/dev/null
printf '%s\n' "$ui_prefs_out" | grep -F "theme=dark" >/dev/null
if printf '%s\n' "$ui_prefs_out" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge get-ui-prefs emitted forged key-value output" >&2
  exit 1
fi
if printf '%s\n' "$ui_prefs_out" | grep -F "ab/key=" >/dev/null 2>&1; then
  printf '%s\n' "forge get-ui-prefs emitted invalid key from hand-edited prefs" >&2
  exit 1
fi

bad_prefs_home="$scratch/prefs-home
forged=1"
set_pref_out=$(XDG_CONFIG_HOME="$bad_prefs_home/.config" sh "$backend" set-ui-pref "$scratch" "theme" "dark")
if printf '%s\n' "$set_pref_out" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge set-ui-pref emitted forged key-value output from config path" >&2
  exit 1
fi
printf '%s\n' "$set_pref_out" | grep -F "file=" >/dev/null

macos_prefs_home="$scratch/macos-prefs-home"
macos_prefs_dir="$macos_prefs_home/.config"
macos_apps_dir="$scratch/custom-macos-apps"
macos_pref_out=$(XDG_CONFIG_HOME="$macos_prefs_dir" sh "$backend" set-ui-pref "$scratch" "desktop_apps_install_dir" "$macos_apps_dir")
printf '%s\n' "$macos_pref_out" | grep -F "key=desktop_apps_install_dir" >/dev/null
printf '%s\n' "$macos_pref_out" | grep -F "value=$macos_apps_dir" >/dev/null
grep -F "desktop_apps_install_dir=$macos_apps_dir" "$macos_prefs_dir/wizardry-apps/forge-ui.conf" >/dev/null

if XDG_CONFIG_HOME="$macos_prefs_dir" sh "$backend" set-ui-pref "$scratch" "desktop_apps_install_dir" "relative/path" >"$scratch/forge-invalid-macos-pref.out" 2>"$scratch/forge-invalid-macos-pref.err"; then
  printf '%s\n' "forge backend test: invalid desktop app install folder accepted" >&2
  exit 1
fi
grep -F "invalid desktop app install folder" "$scratch/forge-invalid-macos-pref.err" >/dev/null

bundle_scripts="$scratch/App Forge.app/Contents/Resources/forge/scripts"
bundle_root_file="$scratch/App Forge.app/Contents/Resources/wizardry-apps-root.txt"
mkdir -p "$bundle_scripts"
cp "$backend" "$bundle_scripts/forge-backend.sh"
chmod +x "$bundle_scripts/forge-backend.sh"
printf '%s\n' "$test_root" > "$bundle_root_file"
bundle_doctor=$(sh "$bundle_scripts/forge-backend.sh" doctor)
printf '%s\n' "$bundle_doctor" | grep -F "root=$test_root" >/dev/null

rm -f "$bundle_root_file"
home_dir="$scratch/home"
mkdir -p "$home_dir/.config/wizardry-apps"
printf '%s\n' "$test_root" > "$home_dir/.config/wizardry-apps/forge-root"
config_doctor=$(HOME="$home_dir" sh "$bundle_scripts/forge-backend.sh" doctor)
printf '%s\n' "$config_doctor" | grep -F "root=$test_root" >/dev/null

mkdir -p "$scratch/runtime/config" "$scratch/apps" "$scratch/templates/web" "$scratch/templates/godot/tools/base-tool"
printf '%s\n' "; test scaffold" > "$scratch/templates/godot/tools/base-tool/project.godot"
cp "$test_root/runtime/config/apps.manifest.json" "$scratch/runtime/config/apps.manifest.json"
cp "$test_root/runtime/config/templates.manifest.json" "$scratch/runtime/config/templates.manifest.json"
cp -R "$test_root/licenses" "$scratch/licenses"
cp -R "$test_root/apps/.host" "$scratch/apps/.host"
mkdir -p "$scratch/apps/forge"
cp -R "$test_root/templates/forge" "$scratch/templates/forge"
cp -R "$test_root/runtime/core" "$scratch/runtime/core"
mkdir -p "$scratch/runtime/schemas"
cp "$test_root/runtime/schemas/native-desktop-ir-v1.json" "$scratch/runtime/schemas/native-desktop-ir-v1.json"
cp "$test_root/runtime/schemas/native-mobile-ir-v1.json" "$scratch/runtime/schemas/native-mobile-ir-v1.json"
cp -R "$test_root/tools" "$scratch/tools"
cp -R "$test_root/templates/web/demo" "$scratch/templates/web/demo"
cp -R "$test_root/templates/web/.themes" "$scratch/templates/web/.themes"

bad_root_hint="$scratch/root
forged=1"
mkdir -p "$bad_root_hint/runtime/config" "$bad_root_hint/apps" "$bad_root_hint/templates/web"
cp "$scratch/runtime/config/apps.manifest.json" "$bad_root_hint/runtime/config/apps.manifest.json"
cp "$scratch/runtime/config/templates.manifest.json" "$bad_root_hint/runtime/config/templates.manifest.json"
if sh "$backend" list-apps "$bad_root_hint" >"$scratch/forge-bad-root-hint.out" 2>"$scratch/forge-bad-root-hint.err"; then
  printf '%s\n' "forge list-apps accepted line-break root hint" >&2
  exit 1
fi
grep -F "root path must not contain line breaks" "$scratch/forge-bad-root-hint.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-root-hint.out" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge list-apps emitted forged rows from root hint" >&2
  exit 1
fi
remove_state="$scratch/remove-state"
remove_app_cache="$remove_state/wizardry-apps/forge/catalog/apps/artificer-web"
mkdir -p "$remove_app_cache/deep"
printf '%s\n' "cached" >"$remove_app_cache/deep/file.txt"
remove_app_out=$(XDG_STATE_HOME="$remove_state" sh "$backend" remove-downloaded-app "$scratch" artificer-web)
printf '%s\n' "$remove_app_out" | grep -F "slug=artificer-web" >/dev/null
printf '%s\n' "$remove_app_out" | grep -F "removed=$remove_app_cache" >/dev/null
if [ -e "$remove_app_cache" ] || [ -L "$remove_app_cache" ]; then
  printf '%s\n' "forge remove-downloaded-app left active app cache in place" >&2
  exit 1
fi

remove_template_cache="$remove_state/wizardry-apps/forge/catalog/templates/blog"
mkdir -p "$remove_template_cache/deep"
printf '%s\n' "cached" >"$remove_template_cache/deep/file.txt"
remove_template_out=$(XDG_STATE_HOME="$remove_state" sh "$backend" remove-downloaded-template "$scratch" blog)
printf '%s\n' "$remove_template_out" | grep -F "slug=blog" >/dev/null
printf '%s\n' "$remove_template_out" | grep -F "removed=$remove_template_cache" >/dev/null
if [ -e "$remove_template_cache" ] || [ -L "$remove_template_cache" ]; then
  printf '%s\n' "forge remove-downloaded-template left active template cache in place" >&2
  exit 1
fi

tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq '.apps |= map(if .slug == "artificer-web" then (.source.ref = "main\rforged=1") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"
app_status_injected=$(sh "$backend" app-status "$scratch" artificer-web)
if printf '%s\n' "$app_status_injected" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge app-status emitted forged key-value output from manifest source ref" >&2
  exit 1
fi
printf '%s\n' "$app_status_injected" | grep -F "ref=main forged=1" >/dev/null
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq '.apps |= map(if .slug == "artificer-web" then (.source.ref = "main") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"

tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-template-manifest.XXXXXX")
jq '.templates |= map(if .slug == "blog" then (.source.ref = "main\rforged=1") else . end)' "$scratch/runtime/config/templates.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/templates.manifest.json"
template_status_injected=$(sh "$backend" template-status "$scratch" blog)
if printf '%s\n' "$template_status_injected" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge template-status emitted forged key-value output from manifest source ref" >&2
  exit 1
fi
printf '%s\n' "$template_status_injected" | grep -F "ref=main forged=1" >/dev/null
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-template-manifest.XXXXXX")
jq '.templates |= map(if .slug == "blog" then (.source.ref = "main") else . end)' "$scratch/runtime/config/templates.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/templates.manifest.json"

tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq '.apps |= map(if .slug == "artificer-web" then (.source.subdir = "../escape") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"
if sh "$backend" download-app "$scratch" artificer-web >"$scratch/forge-bad-app-subdir.out" 2>"$scratch/forge-bad-app-subdir.err"; then
  printf '%s\n' "forge download-app accepted escaping source subdir" >&2
  exit 1
fi
grep -F "invalid source subdir" "$scratch/forge-bad-app-subdir.err" >/dev/null
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq '.apps |= map(if .slug == "artificer-web" then (.source.subdir = ".") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"

tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-template-manifest.XXXXXX")
jq '.templates |= map(if .slug == "blog" then (.source.subdir = "../escape") else . end)' "$scratch/runtime/config/templates.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/templates.manifest.json"
if sh "$backend" download-template "$scratch" blog >"$scratch/forge-bad-template-subdir.out" 2>"$scratch/forge-bad-template-subdir.err"; then
  printf '%s\n' "forge download-template accepted escaping source subdir" >&2
  exit 1
fi
grep -F "invalid source subdir" "$scratch/forge-bad-template-subdir.err" >/dev/null
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-template-manifest.XXXXXX")
jq '.templates |= map(if .slug == "blog" then (.source.subdir = ".") else . end)' "$scratch/runtime/config/templates.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/templates.manifest.json"

source_repo_cr="$scratch/source$(printf '\r')forged=1"
mkdir -p "$source_repo_cr"
(
  cd "$source_repo_cr"
  git init -q
  printf '%s\n' "source" > index.html
  git add index.html
  git -c user.name=Forge -c user.email=forge@example.invalid commit -q -m init
)
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq --arg repo "$source_repo_cr" '.apps |= map(if .slug == "artificer-web" then (.source.repo = $repo | .source.ref = "HEAD" | .source.subdir = ".") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"
if XDG_STATE_HOME="$scratch/bad-source-state" sh "$backend" download-app "$scratch" artificer-web >"$scratch/forge-bad-source-repo.out" 2>"$scratch/forge-bad-source-repo.err"; then
  printf '%s\n' "forge download-app accepted line-break source repo" >&2
  exit 1
fi
grep -F "source repo must not contain line breaks" "$scratch/forge-bad-source-repo.err" >/dev/null
if find "$scratch/bad-source-state" -name .forge-source.lock -print 2>/dev/null | grep . >/dev/null 2>&1; then
  printf '%s\n' "forge download-app wrote source lock for rejected source repo" >&2
  exit 1
fi

source_repo_escape="$scratch/source-escape"
source_repo_outside="$scratch/source-outside"
mkdir -p "$source_repo_escape" "$source_repo_outside"
printf '%s\n' "outside" >"$source_repo_outside/leaked.txt"
(
  cd "$source_repo_escape"
  git init -q
  ln -s "$source_repo_outside" payload
  git add payload
  git -c user.name=Forge -c user.email=forge@example.invalid commit -q -m init
)
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq --arg repo "$source_repo_escape" '.apps |= map(if .slug == "artificer-web" then (.source.repo = $repo | .source.ref = "HEAD" | .source.subdir = "payload") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"
if XDG_STATE_HOME="$scratch/escape-source-state" sh "$backend" download-app "$scratch" artificer-web >"$scratch/forge-escape-source-subdir.out" 2>"$scratch/forge-escape-source-subdir.err"; then
  printf '%s\n' "forge download-app accepted source subdir symlink escaping repo" >&2
  exit 1
fi
grep -F "source subdir must stay inside the cloned repo" "$scratch/forge-escape-source-subdir.err" >/dev/null
if [ -e "$scratch/escape-source-state/wizardry-apps/forge/catalog/apps/artificer-web" ] || [ -L "$scratch/escape-source-state/wizardry-apps/forge/catalog/apps/artificer-web" ]; then
  printf '%s\n' "forge download-app left cache path for rejected source subdir" >&2
  exit 1
fi
tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/forge-app-manifest.XXXXXX")
jq '.apps |= map(if .slug == "artificer-web" then (.source.repo = "https://github.com/example/artificer.git" | .source.ref = "main" | .source.subdir = ".") else . end)' "$scratch/runtime/config/apps.manifest.json" >"$tmp_manifest"
mv "$tmp_manifest" "$scratch/runtime/config/apps.manifest.json"

if sh "$backend" run-task "$scratch" "../escape-task" >/tmp/forge-invalid-run-task.out 2>/tmp/forge-invalid-run-task.err; then
  printf '%s\n' "forge backend test: invalid run-task name accepted" >&2
  exit 1
fi
grep -F "unknown task" /tmp/forge-invalid-run-task.err >/dev/null
escaped_task_logs=$(find "$scratch/_tmp/workbench/log" -type f -name 'escape-task-*' -print 2>/dev/null || true)
[ -z "$escaped_task_logs" ]

sh "$backend" scaffold-app "$scratch" sandbox-tool "Sandbox Tool" minimal >/tmp/forge-scaffold-app.log
[ -f "$scratch/apps/sandbox-tool/index.html" ]
[ -f "$scratch/apps/sandbox-tool/style.css" ]

jq -e '.apps[] | select(.slug == "sandbox-tool" and .production == false and .targets == "hosted-web,macos,linux")' "$scratch/runtime/config/apps.manifest.json" >/dev/null
sh "$test_root/tools/validate-manifest.sh" "$scratch" >/tmp/forge-scaffold-manifest-valid.out

for web_starter in panel topbar dashboard studio; do
  starter_slug="sandbox-$web_starter"
  sh "$backend" scaffold-app "$scratch" "$starter_slug" "Sandbox $web_starter" "$web_starter" >/tmp/forge-scaffold-"$web_starter".log
  [ -f "$scratch/apps/$starter_slug/index.html" ]
  [ -f "$scratch/apps/$starter_slug/style.css" ]
  jq -e --arg slug "$starter_slug" '.apps[] | select(.slug == $slug and .targets == "hosted-web,macos,linux")' "$scratch/runtime/config/apps.manifest.json" >/dev/null
done
sh "$test_root/tools/validate-manifest.sh" "$scratch" >/tmp/forge-scaffold-all-web-manifest-valid.out

if sh "$backend" scaffold-app "$scratch" bad-name 'Bad "Name' minimal >/tmp/forge-invalid-app-name.out 2>/tmp/forge-invalid-app-name.err; then
  printf '%s\n' "forge backend test: invalid scaffold app name accepted" >&2
  exit 1
fi
grep -F "unsupported APP_NAME" /tmp/forge-invalid-app-name.err >/dev/null
[ ! -e "$scratch/apps/bad-name" ]

reference_app_slug="forge-reference-app-smoke"
sh "$backend" scaffold-app "$scratch" "$reference_app_slug" "Forge Reference App Smoke" reference-app >/tmp/forge-scaffold-reference-app.log
[ -f "$scratch/apps/$reference_app_slug/index.html" ]
[ -f "$scratch/apps/$reference_app_slug/style.css" ]
[ -f "$scratch/apps/$reference_app_slug/script.js" ]
[ -x "$scratch/apps/$reference_app_slug/scripts/$reference_app_slug-backend.sh" ]
[ -f "$scratch/apps/$reference_app_slug/assets/forge-icon.png" ]
[ ! -d "$scratch/apps/$reference_app_slug/assets/icons/meta" ]
[ ! -d "$scratch/apps/$reference_app_slug/assets/icons/web" ]
grep -F "__wizardry_host_boot_ready" "$scratch/apps/$reference_app_slug/script.js" >/dev/null
grep -F "Reference app" "$scratch/apps/$reference_app_slug/index.html" >/dev/null
grep -F "assets/forge-icon.png" "$scratch/apps/$reference_app_slug/index.html" >/dev/null

if [ "$os_name" = "Darwin" ] && [ -x /usr/libexec/PlistBuddy ] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  sandbox_assets="$scratch/apps/sandbox-tool/assets"
  sandbox_icons="$sandbox_assets/icons"
  mkdir -p "$sandbox_icons/meta" "$sandbox_icons/macos"
  cp "$test_root/apps/forge/assets/forge-icon.png" "$sandbox_assets/forge-icon.png"
  cp "$test_root/apps/forge/assets/icons/meta/apple-master.png" "$sandbox_icons/meta/apple-master.png"
  cp "$test_root/apps/forge/assets/icons/meta/plain-master.png" "$sandbox_icons/meta/plain-master.png"
  build_icns_from_png "$sandbox_icons/meta/plain-master.png" "$sandbox_icons/macos/forge.icns"

  sandbox_expected_base=$(mktemp "${TMPDIR:-/tmp}/sandbox-tool-expected.XXXXXX")
  sandbox_expected_icon="$sandbox_expected_base.icns"
  rm -f "$sandbox_expected_icon"
  build_icns_from_png "$sandbox_icons/meta/apple-master.png" "$sandbox_expected_icon"

  sandbox_build=$(sh "$backend" build-desktop "$scratch" sandbox-tool)
  sandbox_artifact=$(printf '%s\n' "$sandbox_build" | awk -F= '/^artifact=/{print $2; exit}')
  [ -n "$sandbox_artifact" ] || {
    printf '%s\n' "forge backend test: missing build artifact path for sandbox-tool" >&2
    exit 1
  }
  sandbox_icon_file=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$sandbox_artifact/Contents/Info.plist")
  sandbox_icon_path="$sandbox_artifact/Contents/Resources/$sandbox_icon_file"
  if [ ! -f "$sandbox_icon_path" ] && [ -f "$sandbox_icon_path.icns" ]; then
    sandbox_icon_path="$sandbox_icon_path.icns"
  fi
  [ -f "$sandbox_icon_path" ] || {
    printf '%s\n' "forge backend test: sandbox-tool icon file referenced by CFBundleIconFile is missing" >&2
    exit 1
  }
  if [ "${sandbox_icon_path##*.}" = "icns" ]; then
    cmp -s "$sandbox_icon_path" "$sandbox_icons/macos/forge.icns" && {
      printf '%s\n' "forge backend test: stale cached .icns overrode fresher PNG icon masters" >&2
      exit 1
    }
    cmp -s "$sandbox_icon_path" "$sandbox_expected_icon" || {
      printf '%s\n' "forge backend test: sandbox-tool bundle icon did not use the Apple-ready PNG master" >&2
      exit 1
    }
  fi
  rm -f "$sandbox_expected_icon"
fi

site_out=$(sh "$backend" scaffold-site "$scratch" sandbox-site demo "$scratch/sites")
printf '%s\n' "$site_out" | grep -F "created=$scratch/sites/sandbox-site" >/dev/null
[ -f "$scratch/sites/sandbox-site/site.conf" ]
[ -f "$scratch/sites/sandbox-site/site.allowlist" ]
[ -d "$scratch/sites/sandbox-site/site/pages" ]
[ -d "$scratch/sites/sandbox-site/build" ]

for invalid_site in 'ab/../../escape-site' 'ab;semi' 'ab space'; do
  if sh "$backend" scaffold-site "$scratch" "$invalid_site" demo "$scratch/sites" >/tmp/forge-invalid-site.out 2>/tmp/forge-invalid-site.err; then
    printf '%s\n' "forge backend test: invalid site name accepted: $invalid_site" >&2
    exit 1
  fi
  grep -F "invalid site name" /tmp/forge-invalid-site.err >/dev/null
done
[ ! -d "$scratch/escape-site" ]

godot_tools=$(sh "$backend" list-godot-tools "$scratch")
printf '%s\n' "$godot_tools" | grep -E '^base-tool$' >/dev/null

workspaces_root="$scratch/workspaces"
bad_project_root="$scratch/workspaces-bad
run_rebuild_command=bad"
if sh "$backend" scaffold-workspace "$scratch" bad-root "Bad Root" web sidebar "hosted-web" "" "$bad_project_root" >/tmp/forge-invalid-project-root.out 2>/tmp/forge-invalid-project-root.err; then
  printf '%s\n' "forge backend test: line-break project root accepted" >&2
  exit 1
fi
grep -F "project root must not contain line breaks" /tmp/forge-invalid-project-root.err >/dev/null
[ ! -e "$bad_project_root/bad-root" ]

workspace_web_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-web "Workspace Web" web sidebar "hosted-web,macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_web_out" | grep -F "created=$workspaces_root/workspace-web" >/dev/null
workspace_web_abs=$(CDPATH= cd -- "$workspaces_root/workspace-web" && pwd -P)
[ -f "$workspaces_root/workspace-web/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-web/app/index.html" ]
[ -f "$workspaces_root/workspace-web/LICENSE" ]
[ -f "$workspaces_root/workspace-web/WIZARDRY_ADDENDUM.md" ]
[ -f "$workspaces_root/workspace-web/README.md" ]
grep -F "development_context=web" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "project_type=application" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "targets=hosted-web,macos,linux" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "GNU AGPL-3.0-or-later" "$workspaces_root/workspace-web/README.md" >/dev/null
grep -F "Generated by: App Forge" "$workspaces_root/workspace-web/README.md" >/dev/null
grep -F "You may sell or host this app" "$workspaces_root/workspace-web/README.md" >/dev/null
grep -F "Wizardry Addendum 1.0" "$workspaces_root/workspace-web/WIZARDRY_ADDENDUM.md" >/dev/null
grep -F "Starter: Sidebar" "$workspaces_root/workspace-web/app/index.html" >/dev/null
grep -F "Emission material notice" "$workspaces_root/workspace-web/app/index.html" >/dev/null

native_renamed="$workspaces_root/owl"
web_renamed="$workspaces_root/owl-nonnative"
mkdir -p "$native_renamed/app-blueprint" "$web_renamed/app"
native_renamed_abs=$(CDPATH= cd -- "$native_renamed" && pwd -P)
web_renamed_abs=$(CDPATH= cd -- "$web_renamed" && pwd -P)
printf '%s\n' 'app:' >"$native_renamed/app-blueprint/app.ir.yaml"
printf '%s\n' '<!doctype html><title>Owl</title>' >"$web_renamed/app/index.html"
cat >"$native_renamed/wizardry.workspace.conf" <<CONF
project_id=owl
title=Owl
project_type=native-desktop
development_context=native-desktop
targets=macos,linux
root=.
native_ir_path=app-blueprint/app.ir.yaml
run_rebuild_command=:
CONF
cat >"$web_renamed/wizardry.workspace.conf" <<CONF
project_id=owl
title=Owl
project_type=application
development_context=web
targets=hosted-web,macos,linux
root=$native_renamed_abs
app_subpath=app
run_rebuild_command=:
CONF
renamed_workspaces=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$renamed_workspaces" | grep -F "owl	"
printf '%s\n' "$renamed_workspaces" | grep -F "owl-nonnative	"
grep -Fx "project_id=owl-nonnative" "$web_renamed/wizardry.workspace.conf" >/dev/null
grep -Fx "root=$web_renamed_abs" "$web_renamed/wizardry.workspace.conf" >/dev/null

source_inject_workspace_out=$(sh "$backend" scaffold-workspace "$scratch" source-inject "Source Inject" web sidebar "hosted-web" "unused
run_rebuild_command=bad" "$workspaces_root")
printf '%s\n' "$source_inject_workspace_out" | grep -F "created=$workspaces_root/source-inject" >/dev/null
grep -Fx "source=" "$workspaces_root/source-inject/wizardry.workspace.conf" >/dev/null
! grep -F "run_rebuild_command=bad" "$workspaces_root/source-inject/wizardry.workspace.conf" >/dev/null

workspace_home_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-home "Workspace Home" web reference-app "hosted-web,macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_home_out" | grep -F "created=$workspaces_root/workspace-home" >/dev/null
[ -f "$workspaces_root/workspace-home/app/script.js" ]
[ -x "$workspaces_root/workspace-home/app/scripts/workspace-home-backend.sh" ]
[ -f "$workspaces_root/workspace-home/app/assets/forge-icon.png" ]
[ ! -d "$workspaces_root/workspace-home/app/assets/icons/meta" ]
[ ! -d "$workspaces_root/workspace-home/app/assets/icons/web" ]
grep -F "Wizardry Reference App" "$workspaces_root/workspace-home/app/index.html" >/dev/null

workspace_theurgy_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-theurgy "Workspace Theurgy" web theurgy-reference-app "hosted-web,macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_theurgy_out" | grep -F "created=$workspaces_root/workspace-theurgy" >/dev/null
[ -f "$workspaces_root/workspace-theurgy/app/script.js" ]
[ -x "$workspaces_root/workspace-theurgy/app/scripts/workspace-theurgy-backend.sh" ]
[ -x "$workspaces_root/workspace-theurgy/scripts/prepare-theurgy-runtime.sh" ]
grep -F "starter=theurgy-reference-app" "$workspaces_root/workspace-theurgy/wizardry.workspace.conf" >/dev/null
grep -F "run_rebuild_command=sh scripts/prepare-theurgy-runtime.sh" "$workspaces_root/workspace-theurgy/wizardry.workspace.conf" >/dev/null
grep -F "Theurgy App" "$workspaces_root/workspace-theurgy/app/index.html" >/dev/null
grep -F "prepare-theurgy" "$workspaces_root/workspace-theurgy/app/scripts/workspace-theurgy-backend.sh" >/dev/null
grep -F "check-theurgy-web-runtime" "$workspaces_root/workspace-theurgy/scripts/prepare-theurgy-runtime.sh" >/dev/null

if sh "$backend" set-workspace-field "$scratch" "$workspaces_root/workspace-home" hosted_web_serve_action "ab/action" >/tmp/forge-invalid-action.out 2>/tmp/forge-invalid-action.err; then
  printf '%s\n' "forge backend test: invalid hosted_web_serve_action accepted" >&2
  exit 1
fi
grep -F "invalid hosted_web_serve_action" /tmp/forge-invalid-action.err >/dev/null

bad_set_field_workspace="$scratch/set-field/bad
value=forged"
mkdir -p "$bad_set_field_workspace"
cat >"$bad_set_field_workspace/wizardry.workspace.conf" <<'CONF'
project_id=bad-set-field
title=Bad Set Field
project_type=application
development_context=web
targets=hosted-web
CONF
if sh "$backend" set-workspace-field "$scratch" "$bad_set_field_workspace" starter blank >"$scratch/forge-bad-set-field.out" 2>"$scratch/forge-bad-set-field.err"; then
  printf '%s\n' "forge set-workspace-field accepted line-break project path" >&2
  exit 1
fi
grep -F "project path must not contain line breaks" "$scratch/forge-bad-set-field.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-set-field.out" | grep -E '^value=' >/dev/null 2>&1; then
  printf '%s\n' "forge set-workspace-field emitted forged rows from project path" >&2
  exit 1
fi
if sh "$backend" set-workspace-targets "$scratch" "$bad_set_field_workspace" hosted-web >"$scratch/forge-bad-set-targets.out" 2>"$scratch/forge-bad-set-targets.err"; then
  printf '%s\n' "forge set-workspace-targets accepted line-break project path" >&2
  exit 1
fi
grep -F "project path must not contain line breaks" "$scratch/forge-bad-set-targets.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-set-targets.out" | grep -E '^(workspace|profile)=' >/dev/null 2>&1; then
  printf '%s\n' "forge set-workspace-targets emitted forged rows from project path" >&2
  exit 1
fi
if sh "$backend" rebuild-workspace "$scratch" "$bad_set_field_workspace" web >"$scratch/forge-bad-rebuild-path.out" 2>"$scratch/forge-bad-rebuild-path.err"; then
  printf '%s\n' "forge rebuild-workspace accepted line-break project path" >&2
  exit 1
fi
grep -F "project path must not contain line breaks" "$scratch/forge-bad-rebuild-path.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-rebuild-path.out" | grep -E '^(workspace|app_entry)=' >/dev/null 2>&1; then
  printf '%s\n' "forge rebuild-workspace emitted forged rows from project path" >&2
  exit 1
fi

bad_rename_workspace="$scratch/rename-field/bad
old_workspace=forged"
mkdir -p "$bad_rename_workspace"
cat >"$bad_rename_workspace/wizardry.workspace.conf" <<'CONF'
project_id=bad-rename
title=Bad Rename
project_type=application
development_context=web
targets=hosted-web
CONF
if sh "$backend" rename-workspace "$scratch" "$bad_rename_workspace" "Better Name" >"$scratch/forge-bad-rename.out" 2>"$scratch/forge-bad-rename.err"; then
  printf '%s\n' "forge rename-workspace accepted line-break project path" >&2
  exit 1
fi
grep -F "project path must not contain line breaks" "$scratch/forge-bad-rename.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-rename.out" | grep -E '^old_workspace=' >/dev/null 2>&1; then
  printf '%s\n' "forge rename-workspace emitted forged rows from project path" >&2
  exit 1
fi

escape_workspace="$workspaces_root/escape-workspace"
escape_outside="$workspaces_root/escape-outside"
mkdir -p "$escape_workspace" "$escape_outside"
printf '%s\n' '<!doctype html><title>outside</title>' >"$escape_outside/index.html"
cat > "$escape_workspace/wizardry.workspace.conf" <<CONF
project_id=escape-workspace
title=Escape Workspace
project_type=application
development_context=web
targets=hosted-web,macos,linux
app_subpath=../escape-outside
run_rebuild_command=:
CONF
if sh "$backend" run-workspace "$scratch" "$escape_workspace" web >/tmp/forge-escape-subpath.out 2>/tmp/forge-escape-subpath.err; then
  printf '%s\n' "forge backend test: escaping app_subpath was runnable" >&2
  exit 1
fi
grep -F "project app index not found" /tmp/forge-escape-subpath.err >/dev/null

cr_subpath_workspace="$workspaces_root/cr-subpath-workspace"
cr_subpath=$(printf 'app\rforged=1')
mkdir -p "$cr_subpath_workspace/$cr_subpath"
printf '%s\n' '<!doctype html><title>cr app</title>' >"$cr_subpath_workspace/$cr_subpath/index.html"
{
  printf '%s\n' "project_id=cr-subpath-workspace"
  printf '%s\n' "title=CR Subpath Workspace"
  printf '%s\n' "project_type=application"
  printf '%s\n' "development_context=web"
  printf '%s\n' "targets=hosted-web"
  printf 'app_subpath=%s\n' "$cr_subpath"
  printf '%s\n' "run_rebuild_command=:"
} >"$cr_subpath_workspace/wizardry.workspace.conf"
if sh "$backend" run-workspace "$scratch" "$cr_subpath_workspace" web >"$scratch/forge-cr-subpath.out" 2>"$scratch/forge-cr-subpath.err"; then
  cr_subpath_pid=$(awk -F= '/^pid=/{print $2; exit}' "$scratch/forge-cr-subpath.out")
  [ -n "$cr_subpath_pid" ] && kill "$cr_subpath_pid" >/dev/null 2>&1 || true
  printf '%s\n' "forge backend test: CR-injected app_subpath was runnable" >&2
  exit 1
fi
grep -F "project app index not found" "$scratch/forge-cr-subpath.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-cr-subpath.out" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge run-workspace emitted forged rows from app_subpath" >&2
  exit 1
fi

cr_detect_workspace="$workspaces_root/cr-detect-workspace"
cr_detect_subdir=$(printf 'crapp\rforged=1')
mkdir -p "$cr_detect_workspace/apps/$cr_detect_subdir"
printf '%s\n' '<!doctype html><title>cr detected app</title>' >"$cr_detect_workspace/apps/$cr_detect_subdir/index.html"
cat >"$cr_detect_workspace/wizardry.workspace.conf" <<'CONF'
project_id=cr-detect-workspace
title=CR Detect Workspace
project_type=application
development_context=web
targets=hosted-web
run_rebuild_command=:
CONF
if sh "$backend" run-workspace "$scratch" "$cr_detect_workspace" web >"$scratch/forge-cr-detect-subpath.out" 2>"$scratch/forge-cr-detect-subpath.err"; then
  cr_detect_pid=$(awk -F= '/^pid=/{print $2; exit}' "$scratch/forge-cr-detect-subpath.out")
  [ -n "$cr_detect_pid" ] && kill "$cr_detect_pid" >/dev/null 2>&1 || true
  printf '%s\n' "forge backend test: CR-bearing detected app subpath was runnable" >&2
  exit 1
fi
grep -F "project app index not found" "$scratch/forge-cr-detect-subpath.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-cr-detect-subpath.out" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge run-workspace emitted forged rows from detected app subpath" >&2
  exit 1
fi

if sh "$backend" scaffold-workspace "$scratch" bad-native 'Bad "Name' native-desktop blank "macos,linux" "" "$workspaces_root" >/tmp/forge-invalid-workspace-name.out 2>/tmp/forge-invalid-workspace-name.err; then
  printf '%s\n' "forge backend test: invalid scaffold workspace name accepted" >&2
  exit 1
fi
grep -F "unsupported APP_NAME" /tmp/forge-invalid-workspace-name.err >/dev/null
[ ! -e "$workspaces_root/bad-native" ]

if sh "$backend" scaffold-workspace "$scratch" bad-targets "Bad Targets" web minimal "hosted-web,,linux" "" "$workspaces_root" >/tmp/forge-invalid-scaffold-targets.out 2>/tmp/forge-invalid-scaffold-targets.err; then
  printf '%s\n' "forge backend test: invalid scaffold workspace targets accepted" >&2
  exit 1
fi
grep -F "invalid targets" /tmp/forge-invalid-scaffold-targets.err >/dev/null
[ ! -e "$workspaces_root/bad-targets" ]

workspace_native_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-native "Workspace Native" native-desktop blank "macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_native_out" | grep -F "created=$workspaces_root/workspace-native" >/dev/null
workspace_native_abs=$(CDPATH= cd -- "$workspaces_root/workspace-native" && pwd -P)
[ -f "$workspaces_root/workspace-native/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-native/app-blueprint/app.ir.yaml" ]
[ -f "$workspaces_root/workspace-native/scripts/render-native-desktop.sh" ]
[ -f "$workspaces_root/workspace-native/generated/macos/Package.swift" ]
[ -f "$workspaces_root/workspace-native/generated/linux/meson.build" ]
[ -f "$workspaces_root/workspace-native/README.md" ]
[ -f "$workspaces_root/workspace-native/LICENSE" ]
[ -f "$workspaces_root/workspace-native/WIZARDRY_ADDENDUM.md" ]
grep -F "project_type=native-desktop" "$workspaces_root/workspace-native/wizardry.workspace.conf" >/dev/null
grep -F "development_context=native-desktop" "$workspaces_root/workspace-native/wizardry.workspace.conf" >/dev/null
grep -F "targets=macos,linux" "$workspaces_root/workspace-native/wizardry.workspace.conf" >/dev/null
grep -F "run_rebuild_command=sh scripts/render-native-desktop.sh" "$workspaces_root/workspace-native/wizardry.workspace.conf" >/dev/null
grep -F '"type": "Window"' "$workspaces_root/workspace-native/app-blueprint/app.ir.yaml" >/dev/null
grep -F "Native desktop app scaffolded by App Forge." "$workspaces_root/workspace-native/README.md" >/dev/null
grep -F "You may sell or host this app" "$workspaces_root/workspace-native/README.md" >/dev/null
grep -F "AGPL-3.0-or-later" "$workspaces_root/workspace-native/scripts/render-native-desktop.sh" >/dev/null
grep -F "AGPL-3.0-or-later" "$workspaces_root/workspace-native/app-blueprint/app.ir.yaml" >/dev/null
grep -F "AGPL-3.0-or-later" "$workspaces_root/workspace-native/schemas/native-desktop-ir-v1.json" >/dev/null
grep -F "// swift-tools-version:" "$workspaces_root/workspace-native/generated/macos/Package.swift" >/dev/null

workspace_native_reference_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-native-reference "Workspace Native Reference" native-desktop reference-app "macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_native_reference_out" | grep -F "created=$workspaces_root/workspace-native-reference" >/dev/null
[ -f "$workspaces_root/workspace-native-reference/app-blueprint/app.ir.yaml" ]
[ -f "$workspaces_root/workspace-native-reference/generated/macos/Sources/App/App.swift" ]
[ -f "$workspaces_root/workspace-native-reference/generated/linux/src/main.c" ]
grep -F "Native desktop app scaffolded by App Forge." "$workspaces_root/workspace-native-reference/README.md" >/dev/null
grep -F "NSOutlineView" "$workspaces_root/workspace-native-reference/generated/macos/Sources/App/App.swift" >/dev/null
grep -F "gtk_header_bar_new" "$workspaces_root/workspace-native-reference/generated/linux/src/main.c" >/dev/null
grep -F "json-glib-1.0" "$workspaces_root/workspace-native-reference/generated/linux/meson.build" >/dev/null
grep -F "#include <json-glib/json-glib.h>" "$workspaces_root/workspace-native-reference/generated/linux/src/main.c" >/dev/null
grep -F "apply_reference_snapshot" "$workspaces_root/workspace-native-reference/generated/linux/src/main.c" >/dev/null
grep -F "starter=reference-app" "$workspaces_root/workspace-native-reference/wizardry.workspace.conf" >/dev/null

bad_native_ir=$(mktemp "${TMPDIR:-/tmp}/forge-bad-native-ir.XXXXXX")
jq '.app.name = "Bad \"Name" | .app.window.title = "Bad \"Title"' "$workspaces_root/workspace-native/app-blueprint/app.ir.yaml" >"$bad_native_ir"
if sh "$workspaces_root/workspace-native/scripts/validate-native-desktop-ir.sh" "$bad_native_ir" "$workspaces_root/workspace-native/schemas/native-desktop-ir-v1.json" >/tmp/forge-bad-native-ir.out 2>/tmp/forge-bad-native-ir.err; then
  printf '%s\n' "forge backend test: native desktop IR accepted render-breaking strings" >&2
  exit 1
fi
grep -F "render-safe" /tmp/forge-bad-native-ir.err >/dev/null
rm -f "$bad_native_ir"

bad_native_ir_path="$scratch/native-ir
status=forged.json"
cp "$workspaces_root/workspace-native/app-blueprint/app.ir.yaml" "$bad_native_ir_path"
if sh "$workspaces_root/workspace-native/scripts/validate-native-desktop-ir.sh" "$bad_native_ir_path" "$workspaces_root/workspace-native/schemas/native-desktop-ir-v1.json" >"$scratch/forge-native-ir-path.out" 2>"$scratch/forge-native-ir-path.err"; then
  printf '%s\n' "forge backend test: native desktop IR accepted line-break IR path" >&2
  exit 1
fi
grep -F "IR path must not contain line breaks" "$scratch/forge-native-ir-path.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-native-ir-path.out" | grep -E '^status=' >/dev/null 2>&1; then
  printf '%s\n' "forge native desktop IR emitted forged status from IR path" >&2
  exit 1
fi

rebuild_workspace_native_out=$(sh "$backend" rebuild-workspace "$scratch" "$workspaces_root/workspace-native" native-desktop)
printf '%s\n' "$rebuild_workspace_native_out" | grep -F "workspace=$workspace_native_abs" >/dev/null
printf '%s\n' "$rebuild_workspace_native_out" | grep -F "context=native-desktop" >/dev/null
grep -F "WindowGroup" "$workspaces_root/workspace-native/generated/macos/Sources/App/App.swift" >/dev/null
grep -F "GtkApplication" "$workspaces_root/workspace-native/generated/linux/src/main.c" >/dev/null

printf '%s\n' "custom readme" > "$workspaces_root/workspace-web/README.md"
rm -f "$workspaces_root/workspace-web/LICENSE" "$workspaces_root/workspace-web/WIZARDRY_ADDENDUM.md"
rebuild_workspace_web_out=$(sh "$backend" rebuild-workspace "$scratch" "$workspaces_root/workspace-web" web)
printf '%s\n' "$rebuild_workspace_web_out" | grep -F "workspace=$workspace_web_abs" >/dev/null
[ -f "$workspaces_root/workspace-web/LICENSE" ]
[ -f "$workspaces_root/workspace-web/WIZARDRY_ADDENDUM.md" ]
grep -Fx "custom readme" "$workspaces_root/workspace-web/README.md" >/dev/null

workspace_godot_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-godot "Workspace Godot" godot clone "macos,linux,godot-desktop" base-tool "$workspaces_root")
printf '%s\n' "$workspace_godot_out" | grep -F "created=$workspaces_root/workspace-godot" >/dev/null
[ -f "$workspaces_root/workspace-godot/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-godot/README.md" ]
grep -F "development_context=godot" "$workspaces_root/workspace-godot/wizardry.workspace.conf" >/dev/null
grep -F "starter=clone" "$workspaces_root/workspace-godot/wizardry.workspace.conf" >/dev/null

apps_list=$(sh "$backend" list-apps "$scratch")
printf '%s\n' "$apps_list" | awk -F'\t' 'NF != 18 { exit 1 } END { exit(NR > 0 ? 0 : 1) }'

workspaces=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces" | grep -E '^workspace-godot\t' >/dev/null
printf '%s\n' "$workspaces" | grep -E '^workspace-web\t' >/dev/null
printf '%s\n' "$workspaces" | awk -F'\t' '$1 == "workspace-native" { if (NF != 14 || $8 != "1" || $9 != "no" || $13 != "") exit 1; found = 1 } END { exit(found ? 0 : 1) }'
printf '%s\n' "$workspaces" | awk -F'\t' '$1 == "workspace-web" { if (NF != 14 || $9 != "no" || $10 != "" || $13 != "") exit 1; found = 1 } END { exit(found ? 0 : 1) }'

hidden_workspace_home="$scratch/hidden-workspace-home"
hide_workspace_out=$(XDG_CONFIG_HOME="$hidden_workspace_home/.config" sh "$backend" hide-workspace "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$hide_workspace_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
hidden_workspaces=$(XDG_CONFIG_HOME="$hidden_workspace_home/.config" sh "$backend" list-workspaces "$scratch" "$workspaces_root")
if printf '%s\n' "$hidden_workspaces" | grep -E '^workspace-web\t' >/dev/null 2>&1; then
  printf '%s\n' "forge list-workspaces included hidden workspace" >&2
  exit 1
fi
printf '%s\n' "$hidden_workspaces" | grep -E '^workspace-native\t' >/dev/null
unhide_workspace_out=$(XDG_CONFIG_HOME="$hidden_workspace_home/.config" sh "$backend" unhide-workspace "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$unhide_workspace_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
unhidden_workspaces=$(XDG_CONFIG_HOME="$hidden_workspace_home/.config" sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$unhidden_workspaces" | grep -E '^workspace-web\t' >/dev/null
bad_hide_workspace=$(printf '%s\nforged=1' "$workspaces_root/workspace-web")
if XDG_CONFIG_HOME="$hidden_workspace_home/.config" sh "$backend" hide-workspace "$scratch" "$bad_hide_workspace" >"$scratch/forge-bad-hide-workspace.out" 2>"$scratch/forge-bad-hide-workspace.err"; then
  printf '%s\n' "forge hide-workspace accepted line-break workspace path" >&2
  exit 1
fi
grep -F "workspace path must not contain line breaks" "$scratch/forge-bad-hide-workspace.err" >/dev/null

workspace_web_profile=$(sh "$backend" get-workspace-profile "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_profile" | grep -F "git_repo_present=no" >/dev/null
printf '%s\n' "$workspace_web_profile" | grep -F "git_default_branch=main" >/dev/null

workspace_native_git_init=$(sh "$backend" workspace-git-init "$scratch" "$workspaces_root/workspace-native" "" "main")
printf '%s\n' "$workspace_native_git_init" | grep -F "git_repo_present=yes" >/dev/null
printf '%s\n' "$workspace_native_git_init" | grep -F "git_status_label=No Remote" >/dev/null

git_remote_dir="$scratch/git-remotes"
mkdir -p "$git_remote_dir"
workspace_web_remote="$git_remote_dir/workspace-web-origin.git"
git init --bare "$workspace_web_remote" >/dev/null 2>&1

workspace_web_git_init=$(sh "$backend" workspace-git-init "$scratch" "$workspaces_root/workspace-web" "$workspace_web_remote" "main")
printf '%s\n' "$workspace_web_git_init" | grep -F "git_repo_present=yes" >/dev/null
printf '%s\n' "$workspace_web_git_init" | grep -F "git_status_label=Push" >/dev/null

bad_remote_url=$(printf 'https://github.com/example/workspace-web.git\ngit_status_label=Owned')
if sh "$backend" workspace-git-set-remote "$scratch" "$workspaces_root/workspace-web" "$bad_remote_url" >"$scratch/forge-bad-remote.out" 2>"$scratch/forge-bad-remote.err"; then
  printf '%s\n' "forge workspace-git-set-remote accepted line-break remote URL" >&2
  exit 1
fi
grep -F "remote URL must not contain line breaks" "$scratch/forge-bad-remote.err" >/dev/null

git -C "$workspaces_root/workspace-web" config user.name "Forge Test"
git -C "$workspaces_root/workspace-web" config user.email "forge@example.com"
git -C "$workspaces_root/workspace-web" add . >/dev/null
git -C "$workspaces_root/workspace-web" commit -m "Initial workspace commit" >/dev/null

workspace_web_push=$(sh "$backend" workspace-git-push "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_push" | grep -F "git_status_label=Current" >/dev/null
printf '%s\n' "$workspace_web_push" | grep -F "git_upstream_present=yes" >/dev/null

printf '%s\n' 'repo=test' 'ref=main' 'subdir=.' 'commit=test' > "$workspaces_root/workspace-web/.forge-source.lock"
workspace_web_lock_only=$(sh "$backend" workspace-git-status "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_lock_only" | grep -F "git_dirty=no" >/dev/null
printf '%s\n' "$workspace_web_lock_only" | grep -F "git_status_label=Current" >/dev/null
workspace_web_lock_push=$(sh "$backend" workspace-git-push "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_lock_push" | grep -F "git_status_label=Current" >/dev/null
rm -f "$workspaces_root/workspace-web/.forge-source.lock"

workspace_web_remote_clone="$scratch/workspace-web-remote-clone"
git clone "$workspace_web_remote" "$workspace_web_remote_clone" >/dev/null 2>&1
git -C "$workspace_web_remote_clone" config user.name "Forge Test"
git -C "$workspace_web_remote_clone" config user.email "forge@example.com"
printf '%s\n' "<!-- remote update -->" >> "$workspace_web_remote_clone/README.md"
git -C "$workspace_web_remote_clone" add README.md >/dev/null
git -C "$workspace_web_remote_clone" commit -m "Remote update" >/dev/null
git -C "$workspace_web_remote_clone" push origin main >/dev/null 2>&1

workspace_web_fetch=$(sh "$backend" workspace-git-fetch "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_fetch" | grep -F "git_status_label=Update" >/dev/null
printf '%s\n' "$workspace_web_fetch" | grep -F "git_behind=1" >/dev/null

workspace_web_pull=$(sh "$backend" workspace-git-pull "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_pull" | grep -F "git_status_label=Current" >/dev/null
printf '%s\n' "$workspace_web_pull" | grep -F "git_behind=0" >/dev/null

git -C "$workspaces_root/workspace-web" remote set-url origin "$git_remote_dir/missing-origin.git"
workspace_web_broken=$(sh "$backend" workspace-git-status "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_broken" | grep -F "git_status_label=No Remote" >/dev/null
printf '%s\n' "$workspace_web_broken" | grep -F "git_last_fetch_error=Fetch from origin failed." >/dev/null
git -C "$workspaces_root/workspace-web" remote set-url origin "$workspace_web_remote"

git -C "$workspaces_root/workspace-web" remote set-url origin "$(printf 'https://github.com/example/workspace-web.git\ngit_status_label=Owned')"
workspace_web_injected_remote=$(sh "$backend" workspace-git-status "$scratch" "$workspaces_root/workspace-web")
injected_status_count=$(printf '%s\n' "$workspace_web_injected_remote" | grep -c '^git_status_label=' | tr -d ' ')
[ "$injected_status_count" = "1" ] || {
  printf '%s\n' "forge backend emitted injected git_status_label rows from remote URL" >&2
  exit 1
}
if printf '%s\n' "$workspace_web_injected_remote" | grep -Fx "git_status_label=Owned" >/dev/null 2>&1; then
  printf '%s\n' "forge backend preserved forged git_status_label from remote URL" >&2
  exit 1
fi
printf '%s\n' "$workspace_web_injected_remote" | grep -Fx "git_remote_browser_url=" >/dev/null
printf '%s\n' "$workspace_web_injected_remote" | grep -Fx "git_github_slug=" >/dev/null

git -C "$workspaces_root/workspace-web" remote set-url origin 'https://github.com/example/workspace-web/../../other.git'
workspace_web_path_remote=$(sh "$backend" workspace-git-status "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_path_remote" | grep -Fx "git_remote_browser_url=" >/dev/null
printf '%s\n' "$workspace_web_path_remote" | grep -Fx "git_github_slug=" >/dev/null
git -C "$workspaces_root/workspace-web" remote set-url origin "$workspace_web_remote"

git -C "$workspaces_root/workspace-web" remote set-url origin 'git@github.com:example/workspace-web.git'
git -C "$workspaces_root/workspace-web" config core.sshCommand false
privacy_bin="$scratch/privacy-bin"
mkdir -p "$privacy_bin"
cat >"$privacy_bin/gh" <<'SH'
#!/bin/sh
set -eu
[ "$1" = "api" ] || exit 2
[ "$2" = "repos/example/workspace-web" ] || exit 3
printf '%s\n' '{"private":true}'
SH
chmod +x "$privacy_bin/gh"
workspace_web_private=$(PATH="$privacy_bin:$PATH" sh "$backend" workspace-git-status "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_private" | grep -Fx "git_repo_private=yes" >/dev/null
workspaces_private_cache=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces_private_cache" | awk -F'\t' '$1 == "workspace-web" { if ($13 != "yes") exit 1; found = 1 } END { exit(found ? 0 : 1) }'
git -C "$workspaces_root/workspace-web" config --unset core.sshCommand
git -C "$workspaces_root/workspace-web" remote set-url origin "$workspace_web_remote"

git -C "$workspaces_root/workspace-web" checkout -b 'feat#fragment' >/dev/null 2>&1
git -C "$workspaces_root/workspace-web" remote set-url origin 'https://github.com/example/workspace-web.git'
if sh "$backend" workspace-git-pr-url "$scratch" "$workspaces_root/workspace-web" >"$scratch/forge-bad-pr-ref.out" 2>"$scratch/forge-bad-pr-ref.err"; then
  printf '%s\n' "forge workspace-git-pr-url accepted URL-fragment branch name" >&2
  exit 1
fi
grep -F "branch name is not safe for a GitHub compare URL" "$scratch/forge-bad-pr-ref.err" >/dev/null
if grep -F "pr_url=" "$scratch/forge-bad-pr-ref.out" >/dev/null 2>&1; then
  printf '%s\n' "forge workspace-git-pr-url emitted PR URL for URL-fragment branch" >&2
  exit 1
fi
git -C "$workspaces_root/workspace-web" checkout main >/dev/null 2>&1
git -C "$workspaces_root/workspace-web" branch -D 'feat#fragment' >/dev/null 2>&1
git -C "$workspaces_root/workspace-web" remote set-url origin "$workspace_web_remote"

bad_git_status_workspace="$scratch/git-status/bad
forged=1"
mkdir -p "$bad_git_status_workspace"
if sh "$backend" workspace-git-status "$scratch" "$bad_git_status_workspace" >"$scratch/forge-bad-git-status.out" 2>"$scratch/forge-bad-git-status.err"; then
  printf '%s\n' "forge workspace-git-status accepted line-break project path" >&2
  exit 1
fi
grep -F "project path must not contain line breaks" "$scratch/forge-bad-git-status.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-git-status.out" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge workspace-git-status emitted forged rows from project path" >&2
  exit 1
fi

bad_import_workspace="$scratch/external/bad
run_rebuild_command=bad"
mkdir -p "$bad_import_workspace/app"
cat > "$bad_import_workspace/app/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Bad Import</title>
HTML
if sh "$backend" import-workspace "$scratch" "$bad_import_workspace" "$workspaces_root" >/tmp/forge-invalid-import-path.out 2>/tmp/forge-invalid-import-path.err; then
  printf '%s\n' "forge backend test: line-break import path accepted" >&2
  exit 1
fi
grep -F "project path must not contain line breaks" /tmp/forge-invalid-import-path.err >/dev/null
[ ! -f "$bad_import_workspace/wizardry.workspace.conf" ]

external_workspace="$scratch/external/plain-web"
mkdir -p "$external_workspace/app"
cat > "$external_workspace/app/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Plain Web</title>
HTML
external_workspace_abs=$(CDPATH= cd -- "$external_workspace" && pwd -P)
workspaces_root_abs=$(CDPATH= cd -- "$workspaces_root" && pwd -P)
import_workspace_out=$(sh "$backend" import-workspace "$scratch" "$external_workspace" "$workspaces_root")
printf '%s\n' "$import_workspace_out" | grep -F "workspace=$external_workspace_abs" >/dev/null
printf '%s\n' "$import_workspace_out" | grep -F "registered_path=$workspaces_root_abs/plain-web" >/dev/null
printf '%s\n' "$import_workspace_out" | grep -F "mode=linked" >/dev/null
printf '%s\n' "$import_workspace_out" | grep -F "profile_created=1" >/dev/null
[ -L "$workspaces_root_abs/plain-web" ]
[ ! -e "$workspaces_root_abs/plain-web-2" ]
[ -f "$external_workspace_abs/wizardry.workspace.conf" ]
[ -f "$external_workspace_abs/README.md" ]
grep -F "project_type=application" "$external_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -F "development_context=web" "$external_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -F "Imported into App Forge as a managed workspace." "$external_workspace_abs/README.md" >/dev/null

import_workspace_dup_out=$(sh "$backend" import-workspace "$scratch" "$external_workspace_abs" "$workspaces_root")
printf '%s\n' "$import_workspace_dup_out" | grep -F "workspace=$external_workspace_abs" >/dev/null
printf '%s\n' "$import_workspace_dup_out" | grep -F "registered_path=$workspaces_root_abs/plain-web" >/dev/null
printf '%s\n' "$import_workspace_dup_out" | grep -F "mode=linked" >/dev/null
[ ! -e "$workspaces_root_abs/plain-web-2" ]

direct_workspace="$workspaces_root/direct-space"
mkdir -p "$direct_workspace/app"
cat > "$direct_workspace/app/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Direct Space</title>
HTML
direct_workspace_abs=$(CDPATH= cd -- "$direct_workspace" && pwd -P)
import_direct_out=$(sh "$backend" import-workspace "$scratch" "$direct_workspace" "$workspaces_root")
printf '%s\n' "$import_direct_out" | grep -F "workspace=$direct_workspace_abs" >/dev/null
printf '%s\n' "$import_direct_out" | grep -F "registered_path=$direct_workspace_abs" >/dev/null
printf '%s\n' "$import_direct_out" | grep -F "mode=direct" >/dev/null
printf '%s\n' "$import_direct_out" | grep -F "profile_created=1" >/dev/null
[ -f "$direct_workspace_abs/wizardry.workspace.conf" ]

generic_workspace="$scratch/external/generic-repo"
mkdir -p "$generic_workspace/docs"
printf '%s\n' "hello" > "$generic_workspace/README.md"
generic_workspace_abs=$(CDPATH= cd -- "$generic_workspace" && pwd -P)
import_generic_out=$(sh "$backend" import-workspace "$scratch" "$generic_workspace" "$workspaces_root")
printf '%s\n' "$import_generic_out" | grep -F "workspace=$generic_workspace_abs" >/dev/null
printf '%s\n' "$import_generic_out" | grep -F "mode=linked" >/dev/null
printf '%s\n' "$import_generic_out" | grep -F "profile_created=1" >/dev/null
[ -f "$generic_workspace_abs/wizardry.workspace.conf" ]
grep -F "project_type=application" "$generic_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -F "development_context=web" "$generic_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -F "starter=import-generic" "$generic_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -F "profile_kind=generic" "$generic_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -E '^targets=$' "$generic_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -Fx "hello" "$generic_workspace_abs/README.md" >/dev/null

tmp_profile=$(mktemp "${TMPDIR:-/tmp}/forge-profile.XXXXXX")
awk '
  BEGIN { replaced = 0 }
  /^project_id=/ {
    print "project_id=ab/../../escape"
    replaced = 1
    next
  }
  { print }
  END {
    if (replaced == 0) {
      print "project_id=ab/../../escape"
    }
  }
' "$generic_workspace_abs/wizardry.workspace.conf" >"$tmp_profile"
mv "$tmp_profile" "$generic_workspace_abs/wizardry.workspace.conf"
generic_profile_out=$(sh "$backend" get-workspace-profile "$scratch" "$generic_workspace_abs")
printf '%s\n' "$generic_profile_out" | grep -F "project_id=generic-repo" >/dev/null
tmp_profile=$(mktemp "${TMPDIR:-/tmp}/forge-profile.XXXXXX")
awk -v injected="$(printf 'title=Generic\tImported\rforged=1')" '
  BEGIN { replaced = 0 }
  /^title=/ {
    print injected
    replaced = 1
    next
  }
  { print }
  END {
    if (replaced == 0) {
      print injected
    }
  }
' "$generic_workspace_abs/wizardry.workspace.conf" >"$tmp_profile"
mv "$tmp_profile" "$generic_workspace_abs/wizardry.workspace.conf"
generic_profile_injected=$(sh "$backend" get-workspace-profile "$scratch" "$generic_workspace_abs")
if printf '%s\n' "$generic_profile_injected" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge get-workspace-profile emitted forged key-value output from title" >&2
  exit 1
fi

workspaces_after_import=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces_after_import" | grep -E '^plain-web\t' >/dev/null
printf '%s\n' "$workspaces_after_import" | grep -E '^direct-space\t' >/dev/null
printf '%s\n' "$workspaces_after_import" | grep -E '^generic-repo\t' >/dev/null
row_tab=$(printf '\t')
if printf '%s\n' "$workspaces_after_import" | awk -F "$row_tab" 'NF != 14 { bad = 1 } END { exit bad ? 0 : 1 }'; then
  printf '%s\n' "forge list-workspaces emitted malformed tab-delimited rows" >&2
  exit 1
fi
if printf '%s\n' "$workspaces_after_import" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge list-workspaces emitted forged key-value-shaped row from profile title" >&2
  exit 1
fi

if sh "$backend" run-workspace "$scratch" "$generic_workspace_abs" web >/tmp/forge-run-generic.out 2>/tmp/forge-run-generic.err; then
  printf '%s\n' "forge backend test: generic workspace unexpectedly runnable" >&2
  exit 1
fi
grep -F "project app index not found" /tmp/forge-run-generic.err >/dev/null

set_app_targets_out=$(sh "$backend" set-app-targets "$scratch" sandbox-tool "hosted-web,macos,linux,ios,android")
printf '%s\n' "$set_app_targets_out" | grep -F "slug=sandbox-tool" >/dev/null
jq -e '.apps[] | select(.slug == "sandbox-tool" and .targets == "hosted-web,macos,linux,ios,android")' "$scratch/runtime/config/apps.manifest.json" >/dev/null
apps_after_set=$(sh "$backend" list-apps "$scratch")
printf '%s\n' "$apps_after_set" | grep -E '^sandbox-tool\t' | grep -F "$(printf '\thosted-web,macos,linux,ios,android')" >/dev/null

for invalid_targets in 'not-a-target' 'hosted-web,not-a-target' 'hosted-web,hosted-web' ''; do
  if sh "$backend" set-app-targets "$scratch" sandbox-tool "$invalid_targets" >/tmp/forge-invalid-app-targets.out 2>/tmp/forge-invalid-app-targets.err; then
    printf '%s\n' "forge backend test: invalid app targets accepted: $invalid_targets" >&2
    exit 1
  fi
  grep -F "invalid targets" /tmp/forge-invalid-app-targets.err >/dev/null
done

for invalid_slug in 'ab/../../escape-app' 'ab;semi' 'ab space'; do
  if sh "$backend" set-app-targets "$scratch" "$invalid_slug" hosted-web >/tmp/forge-invalid-slug.out 2>/tmp/forge-invalid-slug.err; then
    printf '%s\n' "forge backend test: invalid slug accepted: $invalid_slug" >&2
    exit 1
  fi
  grep -F "invalid slug" /tmp/forge-invalid-slug.err >/dev/null
done

set_workspace_targets_out=$(sh "$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web,macos,linux,android")
printf '%s\n' "$set_workspace_targets_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
grep -F "targets=hosted-web,macos,linux,android" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

set_workspace_web_only_out=$(sh "$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web")
printf '%s\n' "$set_workspace_web_only_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
grep -F "targets=hosted-web" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

if sh "$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web
run_rebuild_command=bad" >/tmp/forge-invalid-targets.out 2>/tmp/forge-invalid-targets.err; then
  printf '%s\n' "forge backend test: newline-injected workspace targets accepted" >&2
  exit 1
fi
grep -F "invalid targets" /tmp/forge-invalid-targets.err >/dev/null
! grep -F "run_rebuild_command=bad" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

for invalid_targets in 'not-a-target' 'hosted-web,not-a-target' 'hosted-web,hosted-web'; do
  if sh "$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "$invalid_targets" >/tmp/forge-invalid-workspace-targets.out 2>/tmp/forge-invalid-workspace-targets.err; then
    printf '%s\n' "forge backend test: invalid workspace targets accepted: $invalid_targets" >&2
    exit 1
  fi
  grep -F "invalid targets" /tmp/forge-invalid-workspace-targets.err >/dev/null
done

if sh "$backend" rename-workspace "$scratch" "$workspaces_root/workspace-web" 'Bad "Name' >/tmp/forge-invalid-rename-title.out 2>/tmp/forge-invalid-rename-title.err; then
  printf '%s\n' "forge backend test: invalid rename title accepted" >&2
  exit 1
fi
grep -F "unsupported NEW_TITLE" /tmp/forge-invalid-rename-title.err >/dev/null
[ -d "$workspaces_root/workspace-web" ]
[ ! -e "$workspaces_root/bad-name" ]

rename_workspace_out=$(sh "$backend" rename-workspace "$scratch" "$workspaces_root/workspace-web" "Workspace Web Renamed")
renamed_workspace="$workspaces_root_abs/workspace-web-renamed"
printf '%s\n' "$rename_workspace_out" | grep -F "workspace=$renamed_workspace" >/dev/null
printf '%s\n' "$rename_workspace_out" | grep -F "old_workspace=$workspaces_root_abs/workspace-web" >/dev/null
printf '%s\n' "$rename_workspace_out" | grep -F "title=Workspace Web Renamed" >/dev/null
printf '%s\n' "$rename_workspace_out" | grep -F "project_id=workspace-web-renamed" >/dev/null
printf '%s\n' "$rename_workspace_out" | grep -F "moved=1" >/dev/null
[ -d "$renamed_workspace" ]
[ ! -e "$workspaces_root/workspace-web" ]
grep -F "title=Workspace Web Renamed" "$renamed_workspace/wizardry.workspace.conf" >/dev/null
grep -F "project_id=workspace-web-renamed" "$renamed_workspace/wizardry.workspace.conf" >/dev/null
grep -F "root=$renamed_workspace" "$renamed_workspace/wizardry.workspace.conf" >/dev/null

icon_seed="$test_root/apps/forge/assets/icons/web/icon-32.png"
[ -f "$icon_seed" ]
if command -v openssl >/dev/null 2>&1; then
  icon_b64=$(openssl base64 -A < "$icon_seed")
else
  icon_b64=$(base64 < "$icon_seed" | tr -d '\r\n')
fi
icon_payload="data:image/png;base64,$icon_b64"
set_workspace_icon_out=$(sh "$backend" set-workspace-icon "$scratch" "$renamed_workspace" "$icon_payload")
printf '%s\n' "$set_workspace_icon_out" | grep -F "workspace=$renamed_workspace" >/dev/null
[ -s "$renamed_workspace/assets/forge-icon.png" ]
[ -s "$renamed_workspace/app/assets/forge-icon.png" ]
if command -v sips >/dev/null 2>&1; then
  root_icon_width=$(sips -g pixelWidth "$renamed_workspace/assets/forge-icon.png" 2>/dev/null | awk '/pixelWidth:/{print $2; exit}')
  app_icon_width=$(sips -g pixelWidth "$renamed_workspace/app/assets/forge-icon.png" 2>/dev/null | awk '/pixelWidth:/{print $2; exit}')
  [ -n "$root_icon_width" ]
  [ "$root_icon_width" = "$app_icon_width" ]
fi

clear_workspace_icon_out=$(sh "$backend" set-workspace-icon "$scratch" "$renamed_workspace" "")
printf '%s\n' "$clear_workspace_icon_out" | grep -F "workspace=$renamed_workspace" >/dev/null
[ ! -f "$renamed_workspace/assets/forge-icon.png" ]
[ ! -f "$renamed_workspace/app/assets/forge-icon.png" ]

icon_stub_workspace="$scratch/workspaces/dictator"
mkdir -p "$icon_stub_workspace/app"
printf '%s\n' '<!doctype html><title>Dictator</title>' > "$icon_stub_workspace/app/index.html"
icon_stub_bin="$scratch/icon-stub-bin"
mkdir -p "$icon_stub_bin"
icon_stub_log="$scratch/icon-sips.log"
: > "$icon_stub_log"
cat > "$icon_stub_bin/sips" <<'SH'
#!/bin/sh
set -eu
if [ "\${1-}" = "-s" ] && [ "\${2-}" = "format" ] && [ "\${3-}" = "png" ] && [ "\${4-}" = "-z" ] && [ "\${5-}" = "1024" ] && [ "\${6-}" = "1024" ]; then
  printf '%s\\n' "\$*" >>"\${ICON_STUB_LOG?missing ICON_STUB_LOG}"
fi
exec /usr/bin/sips "\$@"
SH
chmod +x "$icon_stub_bin/sips"
ICON_STUB_LOG="$icon_stub_log" PATH="$icon_stub_bin:/bin:/usr/bin:/usr/sbin:/sbin" \
  /bin/sh "$backend" set-workspace-icon-file "$test_root" "$icon_stub_workspace" "$icon_seed" plain >/tmp/forge-workspace-icon-file.out
icon_stub_calls=$(wc -l <"$icon_stub_log" | tr -d ' ')
[ "$icon_stub_calls" -le 1 ] || {
  printf '%s\n' "forge backend test: workspace icon file update resized the dropped icon more than once" >&2
  exit 1
}
[ -f "$icon_stub_workspace/assets/forge-icon.png" ]
[ -f "$icon_stub_workspace/app/assets/forge-icon.png" ]

icon_escape_workspace="$scratch/icon-escape"
mkdir -p "$icon_escape_workspace/assets/icons/meta"
printf '%s\n' "not an icon" > "$scratch/outside-original.png"
cat > "$icon_escape_workspace/assets/icons/meta/icon-settings.conf" <<CONF
generator=wizardry-forge-icon-pipeline
original_source=$scratch/outside-original.png
CONF
if sh "$backend" regenerate-workspace-icon-assets "$scratch" "$icon_escape_workspace" >/tmp/forge-icon-outside-source.out 2>/tmp/forge-icon-outside-source.err; then
  printf '%s\n' "forge backend test: outside-project icon original source accepted" >&2
  exit 1
fi
grep -F "no saved original icon source" /tmp/forge-icon-outside-source.err >/dev/null

managed_site_workspace="$workspaces_root/workspace-managed-site"
managed_site_workspace_abs=$(CDPATH= cd -- "$workspaces_root" && mkdir -p "workspace-managed-site/scripts" && cd -- "workspace-managed-site" && pwd -P)
wizardry_home="$scratch/home/.wizardry"
mkdir -p "$wizardry_home/spells/web" "$wizardry_home/spells/.imps/sys"
cat > "$wizardry_home/spells/.imps/sys/env-clear" <<'SH'
#!/bin/sh
return 0 2>/dev/null || exit 0
SH
chmod +x "$wizardry_home/spells/.imps/sys/env-clear"
cat > "$wizardry_home/spells/web/web-wizardry" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "stub web-wizardry"
exit 0
SH
chmod +x "$wizardry_home/spells/web/web-wizardry"
cat > "$wizardry_home/spells/web/write-managed-site-conf" <<'SH'
#!/bin/sh
set -eu

site_name=${1-}
web_root=${2-}
[ -n "$site_name" ] || exit 2
[ -n "$web_root" ] || exit 2

site_dir="$web_root/$site_name"
mkdir -p "$site_dir"
cat > "$site_dir/site.conf" <<CONF
domain=localhost
port=43123
https=false
CONF
SH
chmod +x "$wizardry_home/spells/web/write-managed-site-conf"
cat > "$managed_site_workspace/wizardry.workspace.conf" <<CONF
project_id=workspace-managed-site
title=Workspace Managed Site
project_type=application
development_context=web
targets=hosted-web
root=$managed_site_workspace_abs
hosted_web_mode=web-wizardry-site
hosted_web_site_name=workspace-managed-site
hosted_web_serve_script=scripts/serve-site.sh
CONF
cat > "$managed_site_workspace/scripts/serve-site.sh" <<'SH'
#!/bin/sh
set -eu

action=${1-}
site_name=${2-}
[ "$action" = "serve" ] || exit 2
[ -n "$site_name" ] || exit 2

web_root=${WEB_WIZARDRY_ROOT:-$HOME/sites}
write-managed-site-conf "$site_name" "$web_root"
SH
chmod +x "$managed_site_workspace/scripts/serve-site.sh"

mkdir -p "$scratch/invalid-wizardry/spells/web"
cat > "$scratch/invalid-wizardry/spells/web/web-wizardry" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "invalid runtime"
exit 1
SH
chmod +x "$scratch/invalid-wizardry/spells/web/web-wizardry"

serve_workspace_managed_site=$(env -i HOME="$scratch/home" PATH='/usr/bin:/bin:/usr/sbin:/sbin' WIZARDRY_DIR="$scratch/invalid-wizardry" WEB_WIZARDRY_ROOT="$scratch/web-root" sh "$backend" serve-hosted-web "$scratch" workspace "$managed_site_workspace")
printf '%s\n' "$serve_workspace_managed_site" | grep -F "mode=web-wizardry" >/dev/null
printf '%s\n' "$serve_workspace_managed_site" | grep -F "site=workspace-managed-site" >/dev/null
printf '%s\n' "$serve_workspace_managed_site" | grep -F "entry=$scratch/web-root/workspace-managed-site" >/dev/null
printf '%s\n' "$serve_workspace_managed_site" | grep -F "url=http://localhost:43123" >/dev/null

cat > "$wizardry_home/spells/web/write-managed-site-conf" <<'SH'
#!/bin/sh
set -eu

site_name=${1-}
web_root=${2-}
[ -n "$site_name" ] || exit 2
[ -n "$web_root" ] || exit 2

site_dir="$web_root/$site_name"
mkdir -p "$site_dir"
{
  printf 'domain=localhost\rforged=1\n'
  printf 'port=43123\n'
  printf 'https=false\n'
} > "$site_dir/site.conf"
SH
chmod +x "$wizardry_home/spells/web/write-managed-site-conf"
if env -i HOME="$scratch/home" PATH='/usr/bin:/bin:/usr/sbin:/sbin' WIZARDRY_DIR="$scratch/invalid-wizardry" WEB_WIZARDRY_ROOT="$scratch/web-root" sh "$backend" serve-hosted-web "$scratch" workspace "$managed_site_workspace" >"$scratch/forge-bad-hosted-web.out" 2>"$scratch/forge-bad-hosted-web.err"; then
  printf '%s\n' "forge serve-hosted-web accepted CR-injected site.conf domain" >&2
  exit 1
fi
grep -F "invalid domain" "$scratch/forge-bad-hosted-web.err" >/dev/null
if tr '\r' '\n' <"$scratch/forge-bad-hosted-web.out" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "forge serve-hosted-web emitted forged rows from site.conf domain" >&2
  exit 1
fi

run_workspace_web=$(sh "$backend" run-workspace "$scratch" "$renamed_workspace" web)
printf '%s\n' "$run_workspace_web" | grep -F "mode=python-http" >/dev/null
printf '%s\n' "$run_workspace_web" | grep -F "entry=$renamed_workspace/app" >/dev/null
printf '%s\n' "$run_workspace_web" | grep -E '^url=http://127\.0\.0\.1:[0-9]+$' >/dev/null
printf '%s\n' "$run_workspace_web" | grep -E '^pid=[0-9]+$' >/dev/null
workspace_web_pid=$(printf '%s\n' "$run_workspace_web" | awk -F= '/^pid=/{print $2; exit}')
[ -n "$workspace_web_pid" ] && kill "$workspace_web_pid" >/dev/null 2>&1 || true

fake_godot_bin="$scratch/fake-godot-bin"
cat > "$fake_godot_bin" <<'SH'
#!/bin/sh
sleep 30
SH
chmod +x "$fake_godot_bin"

run_workspace_open=$(GODOT_BIN="$fake_godot_bin" sh "$backend" run-workspace "$scratch" "$workspaces_root/workspace-godot" godot)
printf '%s\n' "$run_workspace_open" | grep -F "launched=1" >/dev/null
printf '%s\n' "$run_workspace_open" | grep -E "mode=(godot|open)" >/dev/null
printf '%s\n' "$run_workspace_open" | grep -F "entry=$workspaces_root/workspace-godot" >/dev/null
workspace_godot_pid=$(printf '%s\n' "$run_workspace_open" | awk -F= '/^pid=/{print $2; exit}')
[ -n "$workspace_godot_pid" ] && kill "$workspace_godot_pid" >/dev/null 2>&1 || true

run_workspace_infer=$(GODOT_BIN="$fake_godot_bin" sh "$backend" run-workspace "$scratch" "$workspaces_root/workspace-godot")
printf '%s\n' "$run_workspace_infer" | grep -E "mode=(godot|open)" >/dev/null
workspace_godot_infer_pid=$(printf '%s\n' "$run_workspace_infer" | awk -F= '/^pid=/{print $2; exit}')
[ -n "$workspace_godot_infer_pid" ] && kill "$workspace_godot_infer_pid" >/dev/null 2>&1 || true


native_mobile_root="$scratch/native-mobile-root"
native_mobile_out=$(sh "$backend" scaffold-workspace "$scratch" "pocket-owl" "Pocket Owl" native-mobile reference-app android,ios "" "$native_mobile_root")
native_mobile_created=$(printf '%s\n' "$native_mobile_out" | awk -F= '/^created=/{print $2; exit}')
[ -f "$native_mobile_created/app-blueprint/mobile.ir.yaml" ] || {
  printf '%s\n' "forge backend test: native mobile IR was not scaffolded" >&2
  exit 1
}
[ -f "$native_mobile_created/generated/mobile/android/settings.gradle" ] || {
  printf '%s\n' "forge backend test: native Android project was not generated" >&2
  exit 1
}
[ -f "$native_mobile_created/generated/mobile/ios/project.yml" ] || {
  printf '%s\n' "forge backend test: native iOS project was not generated" >&2
  exit 1
}
grep -F "project_type=native-mobile" "$native_mobile_created/wizardry.workspace.conf" >/dev/null
grep -F "mobile_ir_path=app-blueprint/mobile.ir.yaml" "$native_mobile_created/wizardry.workspace.conf" >/dev/null
grep -F "You may sell or host this app" "$native_mobile_created/README.md" >/dev/null
grep -F "AGPL-3.0-or-later" "$native_mobile_created/scripts/render-native-mobile.sh" >/dev/null
grep -F "AGPL-3.0-or-later" "$native_mobile_created/app-blueprint/mobile.ir.yaml" >/dev/null
grep -F "AGPL-3.0-or-later" "$native_mobile_created/schemas/native-mobile-ir-v1.json" >/dev/null
if grep -R "com.google.android.gms" "$native_mobile_created/generated/mobile/android" >/dev/null 2>&1; then
  printf '%s\n' "forge backend test: native mobile starter introduced Play Services dependency" >&2
  exit 1
fi
printf '%s\n' "forge backend tests passed"
