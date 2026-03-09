#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$test_root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "skip: jq not installed" >&2
  exit 0
fi

out=$("$backend" --help)
printf '%s' "$out" | grep -F "Usage:" >/dev/null

out=$("$backend" doctor "$test_root")
printf '%s\n' "$out" | grep -F "root=$test_root" >/dev/null
printf '%s\n' "$out" | grep -F "os=" >/dev/null

os_name=$(uname -s 2>/dev/null || printf unknown)
if [ "$os_name" = "Darwin" ] && [ -x /usr/libexec/PlistBuddy ]; then
  build_out=$("$backend" build-desktop "$test_root" forge)
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
  [ -f "$forge_artifact/Contents/Resources/$forge_icon_file" ] || {
    printf '%s\n' "forge backend test: icon file referenced by CFBundleIconFile is missing" >&2
    exit 1
  }
fi

apps=$("$backend" list-apps "$test_root")
printf '%s\n' "$apps" | grep -E '^artificer\t' >/dev/null
printf '%s\n' "$apps" | grep -E '^forge\t' >/dev/null

templates=$("$backend" list-templates "$test_root")
printf '%s\n' "$templates" | grep -E '^demo\t' >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-backend.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

bundle_scripts="$scratch/App Forge.app/Contents/Resources/forge/scripts"
bundle_root_file="$scratch/App Forge.app/Contents/Resources/wizardry-apps-root.txt"
mkdir -p "$bundle_scripts"
cp "$backend" "$bundle_scripts/forge-backend.sh"
chmod +x "$bundle_scripts/forge-backend.sh"
printf '%s\n' "$test_root" > "$bundle_root_file"
bundle_doctor=$("$bundle_scripts/forge-backend.sh" doctor)
printf '%s\n' "$bundle_doctor" | grep -F "root=$test_root" >/dev/null

rm -f "$bundle_root_file"
home_dir="$scratch/home"
mkdir -p "$home_dir/.config/wizardry-apps"
printf '%s\n' "$test_root" > "$home_dir/.config/wizardry-apps/forge-root"
config_doctor=$(HOME="$home_dir" "$bundle_scripts/forge-backend.sh" doctor)
printf '%s\n' "$config_doctor" | grep -F "root=$test_root" >/dev/null

mkdir -p "$scratch/config" "$scratch/apps" "$scratch/web" "$scratch/godot/tools/base-tool"
printf '%s\n' "; test scaffold" > "$scratch/godot/tools/base-tool/project.godot"
cp "$test_root/config/apps.manifest.json" "$scratch/config/apps.manifest.json"
cp "$test_root/config/templates.manifest.json" "$scratch/config/templates.manifest.json"
cp -R "$test_root/web/demo" "$scratch/web/demo"
cp -R "$test_root/web/.themes" "$scratch/web/.themes"
mkdir -p "$scratch/apps/forge/assets"
cp "$test_root/apps/forge/assets/forge-icon.png" "$scratch/apps/forge/assets/forge-icon.png"

"$backend" scaffold-app "$scratch" sandbox-tool "Sandbox Tool" minimal >/tmp/forge-scaffold-app.log
[ -f "$scratch/apps/sandbox-tool/index.html" ]
[ -f "$scratch/apps/sandbox-tool/style.css" ]
[ -f "$scratch/apps/sandbox-tool/assets/forge-icon.png" ]

jq -e '.apps[] | select(.slug == "sandbox-tool" and .production == false)' "$scratch/config/apps.manifest.json" >/dev/null

site_out=$("$backend" scaffold-site "$scratch" sandbox-site demo "$scratch/sites")
printf '%s\n' "$site_out" | grep -F "created=$scratch/sites/sandbox-site" >/dev/null
[ -f "$scratch/sites/sandbox-site/site.conf" ]
[ -f "$scratch/sites/sandbox-site/site.allowlist" ]
[ -d "$scratch/sites/sandbox-site/site/pages" ]
[ -d "$scratch/sites/sandbox-site/build" ]

godot_tools=$("$backend" list-godot-tools "$scratch")
printf '%s\n' "$godot_tools" | grep -E '^base-tool$' >/dev/null

workspaces_root="$scratch/workspaces"
workspace_web_out=$("$backend" scaffold-workspace "$scratch" workspace-web "Workspace Web" web panel "hosted-web,macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_web_out" | grep -F "created=$workspaces_root/workspace-web" >/dev/null
[ -f "$workspaces_root/workspace-web/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-web/app/index.html" ]
[ -f "$workspaces_root/workspace-web/assets/forge-icon.png" ]
[ -f "$workspaces_root/workspace-web/app/assets/forge-icon.png" ]
grep -F "development_context=web" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "project_type=application" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "targets=hosted-web,macos,linux" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

workspace_godot_out=$("$backend" scaffold-workspace "$scratch" workspace-godot "Workspace Godot" godot clone "macos,linux,godot-desktop" base-tool "$workspaces_root")
printf '%s\n' "$workspace_godot_out" | grep -F "created=$workspaces_root/workspace-godot" >/dev/null
[ -f "$workspaces_root/workspace-godot/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-godot/README.md" ]
grep -F "development_context=godot" "$workspaces_root/workspace-godot/wizardry.workspace.conf" >/dev/null
grep -F "starter=clone" "$workspaces_root/workspace-godot/wizardry.workspace.conf" >/dev/null

workspaces=$("$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces" | grep -E '^workspace-godot\t' >/dev/null
printf '%s\n' "$workspaces" | grep -E '^workspace-web\t' >/dev/null

set_app_targets_out=$("$backend" set-app-targets "$scratch" sandbox-tool "hosted-web,macos,linux,ios,android")
printf '%s\n' "$set_app_targets_out" | grep -F "slug=sandbox-tool" >/dev/null
jq -e '.apps[] | select(.slug == "sandbox-tool" and .targets == "hosted-web,macos,linux,ios,android")' "$scratch/config/apps.manifest.json" >/dev/null
apps_after_set=$("$backend" list-apps "$scratch")
printf '%s\n' "$apps_after_set" | grep -E '^sandbox-tool\t' | grep -F "$(printf '\thosted-web,macos,linux,ios,android')" >/dev/null

set_workspace_targets_out=$("$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web,macos,linux,android")
printf '%s\n' "$set_workspace_targets_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
grep -F "targets=hosted-web,macos,linux,android" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

set_workspace_web_only_out=$("$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web")
printf '%s\n' "$set_workspace_web_only_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
grep -F "targets=hosted-web" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

icon_payload='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+8X8AAAAASUVORK5CYII='
set_workspace_icon_out=$("$backend" set-workspace-icon "$scratch" "$workspaces_root/workspace-web" "$icon_payload")
printf '%s\n' "$set_workspace_icon_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
[ -s "$workspaces_root/workspace-web/assets/forge-icon.png" ]
[ -s "$workspaces_root/workspace-web/app/assets/forge-icon.png" ]
cmp "$workspaces_root/workspace-web/assets/forge-icon.png" "$workspaces_root/workspace-web/app/assets/forge-icon.png" >/dev/null

clear_workspace_icon_out=$("$backend" set-workspace-icon "$scratch" "$workspaces_root/workspace-web" "")
printf '%s\n' "$clear_workspace_icon_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
[ ! -f "$workspaces_root/workspace-web/assets/forge-icon.png" ]
[ ! -f "$workspaces_root/workspace-web/app/assets/forge-icon.png" ]

run_workspace_web=$("$backend" run-workspace "$scratch" "$workspaces_root/workspace-web" web)
printf '%s\n' "$run_workspace_web" | grep -F "mode=python-http" >/dev/null
printf '%s\n' "$run_workspace_web" | grep -F "entry=$workspaces_root/workspace-web/app" >/dev/null
printf '%s\n' "$run_workspace_web" | grep -E '^url=http://127\.0\.0\.1:[0-9]+$' >/dev/null
printf '%s\n' "$run_workspace_web" | grep -E '^pid=[0-9]+$' >/dev/null
workspace_web_pid=$(printf '%s\n' "$run_workspace_web" | awk -F= '/^pid=/{print $2; exit}')
[ -n "$workspace_web_pid" ] && kill "$workspace_web_pid" >/dev/null 2>&1 || true

run_workspace_open=$("$backend" run-workspace "$scratch" "$workspaces_root/workspace-godot" godot)
printf '%s\n' "$run_workspace_open" | grep -F "launched=1" >/dev/null
printf '%s\n' "$run_workspace_open" | grep -E "mode=(godot|open)" >/dev/null
printf '%s\n' "$run_workspace_open" | grep -F "entry=$workspaces_root/workspace-godot" >/dev/null

run_workspace_infer=$("$backend" run-workspace "$scratch" "$workspaces_root/workspace-godot")
printf '%s\n' "$run_workspace_infer" | grep -E "mode=(godot|open)" >/dev/null

printf '%s\n' "forge backend tests passed"
