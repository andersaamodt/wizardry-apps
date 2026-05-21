#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-native-mobile-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

mkdir -p "$tmp_dir/runtime/config" "$tmp_dir/runtime/schemas" "$tmp_dir/apps" "$tmp_dir/templates" "$tmp_dir/licenses"
cp "$root/runtime/config/apps.manifest.json" "$tmp_dir/runtime/config/apps.manifest.json"
cp "$root/runtime/config/templates.manifest.json" "$tmp_dir/runtime/config/templates.manifest.json"
cp "$root/runtime/schemas/native-mobile-ir-v1.json" "$tmp_dir/runtime/schemas/native-mobile-ir-v1.json"
cp -R "$root/templates/forge" "$tmp_dir/templates/forge"
cp -R "$root/licenses" "$tmp_dir/licenses"

backend="$root/apps/forge/scripts/forge-backend.sh"
projects="$tmp_dir/projects"
out=$(sh "$backend" scaffold-workspace "$tmp_dir" pocket-chat "Pocket Chat" native-mobile blank android,ios "" "$projects")
created=$(printf '%s\n' "$out" | awk -F= '/^created=/{print $2; exit}')

[ -f "$created/app-blueprint/mobile.ir.yaml" ]
[ -f "$created/schemas/native-mobile-ir-v1.json" ]
[ -f "$created/generated/mobile/android/app/src/main/AndroidManifest.xml" ]
[ -f "$created/generated/mobile/android/app/src/main/java/app/wizardry/generated/pocket_chat/MainActivity.java" ]
[ -f "$created/generated/mobile/ios/project.yml" ]
[ -f "$created/generated/mobile/ios/Host/ContentView.swift" ]

sh "$created/scripts/validate-native-mobile-ir.sh" "$created/app-blueprint/mobile.ir.yaml" "$created/schemas/native-mobile-ir-v1.json" >/dev/null
sh "$created/scripts/render-native-mobile.sh" >/dev/null

if grep -R "com.google.android.gms\|play-services" "$created/generated/mobile/android" >/dev/null 2>&1; then
  printf '%s\n' "native mobile renderer introduced Google Play Services dependency" >&2
  exit 1
fi

printf '%s\n' "native mobile renderer tests passed"
