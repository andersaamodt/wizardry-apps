#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$test_root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

# Forge self-run should return a restart bundle for host-owned relaunch.
grep -F 'printf '\''restart_bundle=%s\n'\'' "$installed_path"' "$backend" >/dev/null
grep -F 'printf '\''restart_bundle=%s\n'\'' "$launch_bundle"' "$backend" >/dev/null
grep -F "elif [ -f \"\$app_dir/assets/forge-icon.png\" ];" "$backend" >/dev/null

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "skip: jq not installed" >&2
  exit 0
fi

out=$(sh "$backend" --help)
printf '%s' "$out" | grep -F "Usage:" >/dev/null
printf '%s\n' "$out" | grep -F "import-workspace [ROOT_HINT] WORKSPACE_PATH [PROJECT_ROOT]" >/dev/null
printf '%s\n' "$out" | grep -F "rename-workspace [ROOT_HINT] WORKSPACE_PATH NEW_TITLE" >/dev/null
grep -F 'self_relaunch=1' "$backend" >/dev/null
grep -F 'open "$launch_bundle"' "$backend" >/dev/null

out=$(sh "$backend" doctor "$test_root")
printf '%s\n' "$out" | grep -F "root=$test_root" >/dev/null
printf '%s\n' "$out" | grep -F "os=" >/dev/null

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
    cmp -s "$forge_icon_path" "$test_root/apps/forge/assets/icons/macos/forge.icns" || {
      printf '%s\n' "forge backend test: desktop bundle icon drifted from generated macOS icon asset" >&2
      exit 1
    }
  fi
fi

apps=$(sh "$backend" list-apps "$test_root")
printf '%s\n' "$apps" | grep -E '^artificer\t' >/dev/null
printf '%s\n' "$apps" | grep -E '^forge\t' >/dev/null

templates=$(sh "$backend" list-templates "$test_root")
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

sh "$backend" scaffold-app "$scratch" sandbox-tool "Sandbox Tool" minimal >/tmp/forge-scaffold-app.log
[ -f "$scratch/apps/sandbox-tool/index.html" ]
[ -f "$scratch/apps/sandbox-tool/style.css" ]

jq -e '.apps[] | select(.slug == "sandbox-tool" and .production == false)' "$scratch/config/apps.manifest.json" >/dev/null

site_out=$(sh "$backend" scaffold-site "$scratch" sandbox-site demo "$scratch/sites")
printf '%s\n' "$site_out" | grep -F "created=$scratch/sites/sandbox-site" >/dev/null
[ -f "$scratch/sites/sandbox-site/site.conf" ]
[ -f "$scratch/sites/sandbox-site/site.allowlist" ]
[ -d "$scratch/sites/sandbox-site/site/pages" ]
[ -d "$scratch/sites/sandbox-site/build" ]

godot_tools=$(sh "$backend" list-godot-tools "$scratch")
printf '%s\n' "$godot_tools" | grep -E '^base-tool$' >/dev/null

workspaces_root="$scratch/workspaces"
workspace_web_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-web "Workspace Web" web panel "hosted-web,macos,linux" "" "$workspaces_root")
printf '%s\n' "$workspace_web_out" | grep -F "created=$workspaces_root/workspace-web" >/dev/null
[ -f "$workspaces_root/workspace-web/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-web/app/index.html" ]
grep -F "development_context=web" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "project_type=application" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null
grep -F "targets=hosted-web,macos,linux" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

workspace_godot_out=$(sh "$backend" scaffold-workspace "$scratch" workspace-godot "Workspace Godot" godot clone "macos,linux,godot-desktop" base-tool "$workspaces_root")
printf '%s\n' "$workspace_godot_out" | grep -F "created=$workspaces_root/workspace-godot" >/dev/null
[ -f "$workspaces_root/workspace-godot/wizardry.workspace.conf" ]
[ -f "$workspaces_root/workspace-godot/README.md" ]
grep -F "development_context=godot" "$workspaces_root/workspace-godot/wizardry.workspace.conf" >/dev/null
grep -F "starter=clone" "$workspaces_root/workspace-godot/wizardry.workspace.conf" >/dev/null

workspaces=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces" | grep -E '^workspace-godot\t' >/dev/null
printf '%s\n' "$workspaces" | grep -E '^workspace-web\t' >/dev/null

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
grep -F "project_type=application" "$external_workspace_abs/wizardry.workspace.conf" >/dev/null
grep -F "development_context=web" "$external_workspace_abs/wizardry.workspace.conf" >/dev/null

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

workspaces_after_import=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces_after_import" | grep -E '^plain-web\t' >/dev/null
printf '%s\n' "$workspaces_after_import" | grep -E '^direct-space\t' >/dev/null
printf '%s\n' "$workspaces_after_import" | grep -E '^generic-repo\t' >/dev/null

if sh "$backend" run-workspace "$scratch" "$generic_workspace_abs" web >/tmp/forge-run-generic.out 2>/tmp/forge-run-generic.err; then
  printf '%s\n' "forge backend test: generic workspace unexpectedly runnable" >&2
  exit 1
fi
grep -F "project app index not found" /tmp/forge-run-generic.err >/dev/null

set_app_targets_out=$(sh "$backend" set-app-targets "$scratch" sandbox-tool "hosted-web,macos,linux,ios,android")
printf '%s\n' "$set_app_targets_out" | grep -F "slug=sandbox-tool" >/dev/null
jq -e '.apps[] | select(.slug == "sandbox-tool" and .targets == "hosted-web,macos,linux,ios,android")' "$scratch/config/apps.manifest.json" >/dev/null
apps_after_set=$(sh "$backend" list-apps "$scratch")
printf '%s\n' "$apps_after_set" | grep -E '^sandbox-tool\t' | grep -F "$(printf '\thosted-web,macos,linux,ios,android')" >/dev/null

set_workspace_targets_out=$(sh "$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web,macos,linux,android")
printf '%s\n' "$set_workspace_targets_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
grep -F "targets=hosted-web,macos,linux,android" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

set_workspace_web_only_out=$(sh "$backend" set-workspace-targets "$scratch" "$workspaces_root/workspace-web" "hosted-web")
printf '%s\n' "$set_workspace_web_only_out" | grep -F "workspace=$workspaces_root/workspace-web" >/dev/null
grep -F "targets=hosted-web" "$workspaces_root/workspace-web/wizardry.workspace.conf" >/dev/null

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

run_workspace_web=$(sh "$backend" run-workspace "$scratch" "$renamed_workspace" web)
printf '%s\n' "$run_workspace_web" | grep -F "mode=python-http" >/dev/null
printf '%s\n' "$run_workspace_web" | grep -F "entry=$renamed_workspace/app" >/dev/null
printf '%s\n' "$run_workspace_web" | grep -E '^url=http://127\.0\.0\.1:[0-9]+$' >/dev/null
printf '%s\n' "$run_workspace_web" | grep -E '^pid=[0-9]+$' >/dev/null
workspace_web_pid=$(printf '%s\n' "$run_workspace_web" | awk -F= '/^pid=/{print $2; exit}')
[ -n "$workspace_web_pid" ] && kill "$workspace_web_pid" >/dev/null 2>&1 || true

run_workspace_open=$(sh "$backend" run-workspace "$scratch" "$workspaces_root/workspace-godot" godot)
printf '%s\n' "$run_workspace_open" | grep -F "launched=1" >/dev/null
printf '%s\n' "$run_workspace_open" | grep -E "mode=(godot|open)" >/dev/null
printf '%s\n' "$run_workspace_open" | grep -F "entry=$workspaces_root/workspace-godot" >/dev/null

run_workspace_infer=$(sh "$backend" run-workspace "$scratch" "$workspaces_root/workspace-godot")
printf '%s\n' "$run_workspace_infer" | grep -E "mode=(godot|open)" >/dev/null

printf '%s\n' "forge backend tests passed"
