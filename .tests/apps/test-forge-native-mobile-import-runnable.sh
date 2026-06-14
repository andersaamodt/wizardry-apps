#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-native-mobile-import.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

workspace="$scratch/mobile-repair"
mkdir -p "$workspace/app-blueprint" "$workspace/scripts"

cat >"$workspace/app-blueprint/mobile.ir.yaml" <<'IR'
{
  "schemaVersion": "1.0",
  "app": {
    "id": "mobile-repair",
    "name": "Mobile Repair"
  },
  "navigation": {
    "kind": "tabs",
    "items": [
      {
        "id": "home",
        "title": "Home",
        "screen": {
          "id": "home-screen",
          "title": "Home",
          "body": {
            "type": "Text",
            "text": "Hello"
          }
        }
      }
    ]
  }
}
IR

cat >"$workspace/scripts/render-mobile.sh" <<'SH'
#!/bin/sh
set -eu
project_id=$(awk -F= '$1 == "project_id" { print $2; exit }' wizardry.workspace.conf)
[ -n "$project_id" ] || project_id=$(basename "$(pwd)")
generated_root="${XDG_STATE_HOME:-$HOME/.local/state}/$project_id/generated/mobile"
mkdir -p "$generated_root/android/app"
cat > "$generated_root/android/settings.gradle" <<'GRADLE'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "mobile-repair"
include ':app'
GRADLE
cat > "$generated_root/android/build.gradle" <<'GRADLE'
plugins {
    id 'com.android.application' version '8.5.2' apply false
}
GRADLE
cat > "$generated_root/android/app/build.gradle" <<'GRADLE'
plugins { id 'com.android.application' }

android { namespace 'app.mobile_repair'; compileSdk 35 }
GRADLE
printf 'rendered_android=%s\n' "$generated_root/android"
SH
chmod +x "$workspace/scripts/render-mobile.sh"

cat >"$workspace/wizardry.workspace.conf" <<CONF
# Wizardry Apps project profile
project_id=mobile-repair
title=Mobile Repair
project_type=native-mobile
development_context=native-mobile
starter=import-native-mobile
profile_kind=detected
targets=android,ios
root=$workspace
mobile_ir_path=app-blueprint/mobile.ir.yaml
run_rebuild_command=:
CONF

sh "$backend" import-workspace "$root" "$workspace" "$scratch" >/dev/null

grep -F 'run_rebuild_command=sh scripts/render-mobile.sh' "$workspace/wizardry.workspace.conf" >/dev/null || {
  printf '%s\n' "forge native-mobile import test: expected render-mobile rebuild command repair" >&2
  exit 1
}

workspace_rows=$(sh "$backend" list-workspaces "$root" "$scratch")
printf '%s\n' "$workspace_rows" | awk -F '\t' '
  $1 == "mobile-repair" {
    if ($2 != "Mobile Repair" || $4 != "native-mobile" || $8 != "1") exit 1
    found = 1
  }
  END { exit(found ? 0 : 1) }
' || {
  printf '%s\n' "forge native-mobile import test: workspace did not list as runnable" >&2
  printf '%s\n' "$workspace_rows" >&2
  exit 1
}

mkdir -p "$scratch/home"
build_out=$(env HOME="$scratch/home" XDG_STATE_HOME="$scratch/state" PATH="/usr/bin:/bin" sh "$backend" build-native-mobile-workspace "$root" "$workspace" android release)
printf '%s\n' "$build_out" | grep -F 'status=prepared' >/dev/null || {
  printf '%s\n' "forge native-mobile import test: missing Gradle should prepare mobile project instead of failing" >&2
  printf '%s\n' "$build_out" >&2
  exit 1
}
printf '%s\n' "$build_out" | grep -F "project=$scratch/state/mobile-repair/generated/mobile/android" >/dev/null || {
  printf '%s\n' "forge native-mobile import test: prepared Android result should report external generated project path" >&2
  printf '%s\n' "$build_out" >&2
  exit 1
}
printf '%s\n' "$build_out" | grep -F 'missing_tool=android-build-toolchain' >/dev/null || {
  printf '%s\n' "forge native-mobile import test: prepared Android result should report build toolchain gap" >&2
  printf '%s\n' "$build_out" >&2
  exit 1
}
grep -F "rendered_android=$scratch/state/mobile-repair/generated/mobile/android" "$(env XDG_STATE_HOME="$scratch/state" sh "$backend" rebuild-workspace "$root" "$workspace" native-mobile | awk -F= '$1 == "log" { print $2; exit }')" >/dev/null || {
  printf '%s\n' "forge native-mobile import test: rebuild log should preserve external generated Android path" >&2
  exit 1
}

printf '%s\n' "forge native-mobile import runnable test passed"
