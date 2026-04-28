#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$test_root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

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
printf '%s\n' "$out" | grep -F "workspace-git-init [ROOT_HINT] WORKSPACE_PATH [REMOTE_URL] [BRANCH]" >/dev/null
printf '%s\n' "$out" | grep -F "workspace-git-install-release [ROOT_HINT] WORKSPACE_PATH" >/dev/null
grep -F 'self_relaunch=1' "$backend" >/dev/null
grep -F 'open "$launch_bundle"' "$backend" >/dev/null

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
printf '%s\n' "$apps" | grep -E '^artificer\t' >/dev/null
printf '%s\n' "$apps" | grep -E '^forge\t' >/dev/null

templates=$(sh "$backend" list-templates "$test_root")
printf '%s\n' "$templates" | grep -E '^demo\t' >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-backend.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

prefs_home="$scratch/prefs-home"
mkdir -p "$prefs_home"
if XDG_CONFIG_HOME="$prefs_home/.config" sh "$backend" set-ui-pref "$scratch" "ab/key" value >/tmp/forge-invalid-pref.out 2>/tmp/forge-invalid-pref.err; then
  printf '%s\n' "forge backend test: invalid UI pref key accepted" >&2
  exit 1
fi
grep -F "invalid UI pref key" /tmp/forge-invalid-pref.err >/dev/null

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
cp -R "$test_root/licenses" "$scratch/licenses"
cp -R "$test_root/apps/.host" "$scratch/apps/.host"
mkdir -p "$scratch/apps/forge"
cp -R "$test_root/apps/forge/starter-templates" "$scratch/apps/forge/starter-templates"
cp -R "$test_root/core" "$scratch/core"
mkdir -p "$scratch/schemas"
cp "$test_root/schemas/native-desktop-ir-v1.json" "$scratch/schemas/native-desktop-ir-v1.json"
cp -R "$test_root/tools" "$scratch/tools"
cp -R "$test_root/web/demo" "$scratch/web/demo"
cp -R "$test_root/web/.themes" "$scratch/web/.themes"

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

jq -e '.apps[] | select(.slug == "sandbox-tool" and .production == false)' "$scratch/config/apps.manifest.json" >/dev/null

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
grep -F "Wizardry Addendum 1.0" "$workspaces_root/workspace-web/WIZARDRY_ADDENDUM.md" >/dev/null
grep -F "Starter: Sidebar" "$workspaces_root/workspace-web/app/index.html" >/dev/null
grep -F "Emission material notice" "$workspaces_root/workspace-web/app/index.html" >/dev/null

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

if sh "$backend" set-workspace-field "$scratch" "$workspaces_root/workspace-home" hosted_web_serve_action "ab/action" >/tmp/forge-invalid-action.out 2>/tmp/forge-invalid-action.err; then
  printf '%s\n' "forge backend test: invalid hosted_web_serve_action accepted" >&2
  exit 1
fi
grep -F "invalid hosted_web_serve_action" /tmp/forge-invalid-action.err >/dev/null

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
[ -f "$workspaces_root/workspace-native/ir/app.ir.yaml" ]
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
grep -F '"type": "Window"' "$workspaces_root/workspace-native/ir/app.ir.yaml" >/dev/null
grep -F "Native desktop app scaffolded by App Forge." "$workspaces_root/workspace-native/README.md" >/dev/null
grep -F "// swift-tools-version:" "$workspaces_root/workspace-native/generated/macos/Package.swift" >/dev/null

bad_native_ir=$(mktemp "${TMPDIR:-/tmp}/forge-bad-native-ir.XXXXXX")
jq '.app.name = "Bad \"Name" | .app.window.title = "Bad \"Title"' "$workspaces_root/workspace-native/ir/app.ir.yaml" >"$bad_native_ir"
if sh "$workspaces_root/workspace-native/scripts/validate-native-desktop-ir.sh" "$bad_native_ir" "$workspaces_root/workspace-native/schemas/native-desktop-ir-v1.json" >/tmp/forge-bad-native-ir.out 2>/tmp/forge-bad-native-ir.err; then
  printf '%s\n' "forge backend test: native desktop IR accepted render-breaking strings" >&2
  exit 1
fi
grep -F "render-safe" /tmp/forge-bad-native-ir.err >/dev/null
rm -f "$bad_native_ir"

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
printf '%s\n' "$apps_list" | awk -F'\t' 'NF != 17 { exit 1 } END { exit(NR > 0 ? 0 : 1) }'

workspaces=$(sh "$backend" list-workspaces "$scratch" "$workspaces_root")
printf '%s\n' "$workspaces" | grep -E '^workspace-godot\t' >/dev/null
printf '%s\n' "$workspaces" | grep -E '^workspace-web\t' >/dev/null
printf '%s\n' "$workspaces" | awk -F'\t' '$1 == "workspace-native" { if (NF != 13 || $8 != "1" || $9 != "no") exit 1; found = 1 } END { exit(found ? 0 : 1) }'
printf '%s\n' "$workspaces" | awk -F'\t' '$1 == "workspace-web" { if (NF != 13 || $9 != "no" || $10 != "") exit 1; found = 1 } END { exit(found ? 0 : 1) }'

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

git -C "$workspaces_root/workspace-web" config user.name "Forge Test"
git -C "$workspaces_root/workspace-web" config user.email "forge@example.com"
git -C "$workspaces_root/workspace-web" add . >/dev/null
git -C "$workspaces_root/workspace-web" commit -m "Initial workspace commit" >/dev/null

workspace_web_push=$(sh "$backend" workspace-git-push "$scratch" "$workspaces_root/workspace-web")
printf '%s\n' "$workspace_web_push" | grep -F "git_status_label=Current" >/dev/null
printf '%s\n' "$workspace_web_push" | grep -F "git_upstream_present=yes" >/dev/null

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
