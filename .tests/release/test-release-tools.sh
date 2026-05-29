#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

name=$(sh "$ROOT_DIR/tools/release/get-app-name.sh" artificer-web)
[ "$name" = "Artificer Web" ]

native_name=$(sh "$ROOT_DIR/tools/release/get-app-name.sh" artificer-native)
[ "$native_name" = "Artificer" ]

forge_name=$(sh "$ROOT_DIR/tools/release/get-app-name.sh" forge)
[ "$forge_name" = "App Forge" ]

bundle_id=$(sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" android artificer-web)
printf '%s' "$bundle_id" | grep -Eq '^[A-Za-z0-9]+(\.[A-Za-z0-9-]+)+$'

native_bundle_id=$(sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" macos artificer-native)
[ "$native_bundle_id" = "com.artificer.app" ]

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-stage-assets.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

bad_lookup_slug=$(printf 'forge\nforged=1')
if sh "$ROOT_DIR/tools/release/get-app-name.sh" "$bad_lookup_slug" >"$tmp_dir/get-name-bad-slug.out" 2>"$tmp_dir/get-name-bad-slug.err"; then
  printf '%s\n' "get-app-name accepted newline app slug" >&2
  exit 1
fi
grep -F "invalid app slug" "$tmp_dir/get-name-bad-slug.err" >/dev/null
if tr '\r' '\n' <"$tmp_dir/get-name-bad-slug.err" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "get-app-name emitted forged rows from invalid app slug" >&2
  exit 1
fi

if sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" ios "$bad_lookup_slug" >"$tmp_dir/get-bundle-bad-slug.out" 2>"$tmp_dir/get-bundle-bad-slug.err"; then
  printf '%s\n' "get-app-bundle-id accepted newline app slug" >&2
  exit 1
fi
grep -F "invalid app slug" "$tmp_dir/get-bundle-bad-slug.err" >/dev/null
if tr '\r' '\n' <"$tmp_dir/get-bundle-bad-slug.err" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "get-app-bundle-id emitted forged rows from invalid app slug" >&2
  exit 1
fi

bad_manifest_root="$tmp_dir/bad-manifest-root"
mkdir -p "$bad_manifest_root/runtime/config" "$bad_manifest_root/apps" "$bad_manifest_root/templates/web"
cp "$ROOT_DIR/runtime/config/templates.manifest.json" "$bad_manifest_root/runtime/config/templates.manifest.json"
cp "$ROOT_DIR/runtime/config/apps.manifest.json" "$bad_manifest_root/runtime/config/apps.manifest.json"
jq '.apps[0].name = "Bad\nName"' "$ROOT_DIR/runtime/config/apps.manifest.json" >"$bad_manifest_root/runtime/config/apps.manifest.json"
if WIZARDRY_APPS_ROOT="$bad_manifest_root" sh "$ROOT_DIR/tools/release/get-app-name.sh" artificer-web >"$tmp_dir/bad-app-name.out" 2>"$tmp_dir/bad-app-name.err"; then
  printf '%s\n' "get-app-name accepted unsafe manifest app name" >&2
  exit 1
fi
grep -F "unsafe app name" "$tmp_dir/bad-app-name.err" >/dev/null

jq '.apps[0].name = "Bad/../../Name"' "$ROOT_DIR/runtime/config/apps.manifest.json" >"$bad_manifest_root/runtime/config/apps.manifest.json"
if WIZARDRY_APPS_ROOT="$bad_manifest_root" sh "$ROOT_DIR/tools/release/get-app-name.sh" artificer-web >"$tmp_dir/bad-app-path-name.out" 2>"$tmp_dir/bad-app-path-name.err"; then
  printf '%s\n' "get-app-name accepted path-shaped manifest app name" >&2
  exit 1
fi
grep -F "unsafe app name" "$tmp_dir/bad-app-path-name.err" >/dev/null

jq '.apps[0].bundleIds.android = "com.example/../../bad"' "$ROOT_DIR/runtime/config/apps.manifest.json" >"$bad_manifest_root/runtime/config/apps.manifest.json"
if WIZARDRY_APPS_ROOT="$bad_manifest_root" sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" android artificer-web >"$tmp_dir/bad-bundle-id.out" 2>"$tmp_dir/bad-bundle-id.err"; then
  printf '%s\n' "get-app-bundle-id accepted unsafe manifest bundle id" >&2
  exit 1
fi
grep -F "unsafe bundle id" "$tmp_dir/bad-bundle-id.err" >/dev/null

jq '.apps += [{
  "slug":"bad/../../slug",
  "name":"Bad",
  "production":true,
  "distribution":"core",
  "bundleIds":{"macos":"com.example.bad","ios":"com.example.bad","android":"com.example.bad"},
  "targets":"macos"
}]' "$ROOT_DIR/runtime/config/apps.manifest.json" >"$bad_manifest_root/runtime/config/apps.manifest.json"
if WIZARDRY_APPS_ROOT="$bad_manifest_root" sh "$ROOT_DIR/tools/release/list-production-apps.sh" >"$tmp_dir/bad-production-slug.out" 2>"$tmp_dir/bad-production-slug.err"; then
  printf '%s\n' "list-production-apps accepted unsafe production app slug" >&2
  exit 1
fi
grep -F "unsafe app slug" "$tmp_dir/bad-production-slug.err" >/dev/null

fake_stage_root="$tmp_dir/fake-stage-root"
mkdir -p \
  "$fake_stage_root/tools/release" \
  "$fake_stage_root/apps/forge" \
  "$fake_stage_root/apps/.host/shared" \
  "$fake_stage_root/templates/web/.themes" \
  "$fake_stage_root/runtime/core/include" \
  "$fake_stage_root/runtime/core/src"
cp "$ROOT_DIR/tools/release/stage-web-assets.sh" "$fake_stage_root/tools/release/stage-web-assets.sh"
printf '%s\n' "source marker" >"$fake_stage_root/apps/forge/index.html"
printf '%s\n' "bridge" >"$fake_stage_root/apps/.host/shared/wizardry-bridge.js"
printf '%s\n' "header" >"$fake_stage_root/runtime/core/include/wizardry.h"
printf '%s\n' "source" >"$fake_stage_root/runtime/core/src/wizardry.c"
if sh "$fake_stage_root/tools/release/stage-web-assets.sh" forge "$fake_stage_root/apps/forge" >"$tmp_dir/stage-into-source.out" 2>"$tmp_dir/stage-into-source.err"; then
  printf '%s\n' "stage-web-assets accepted destination inside app source" >&2
  exit 1
fi
grep -F "destination overlaps source" "$tmp_dir/stage-into-source.err" >/dev/null
grep -Fx "source marker" "$fake_stage_root/apps/forge/index.html" >/dev/null
if sh "$fake_stage_root/tools/release/stage-web-assets.sh" forge "$fake_stage_root/apps/forge/generated-parent/out" >"$tmp_dir/stage-nested-source.out" 2>"$tmp_dir/stage-nested-source.err"; then
  printf '%s\n' "stage-web-assets accepted nested destination inside app source" >&2
  exit 1
fi
grep -F "destination overlaps source" "$tmp_dir/stage-nested-source.err" >/dev/null
[ ! -e "$fake_stage_root/apps/forge/generated-parent" ]
bad_stage_dest="$tmp_dir/forge-assets
forged=1"
if sh "$ROOT_DIR/tools/release/stage-web-assets.sh" forge "$bad_stage_dest" >"$tmp_dir/stage-newline-dest.out" 2>"$tmp_dir/stage-newline-dest.err"; then
  printf '%s\n' "stage-web-assets accepted newline destination path" >&2
  exit 1
fi
grep -F "destination must not contain line breaks" "$tmp_dir/stage-newline-dest.err" >/dev/null
[ ! -e "$bad_stage_dest" ]

sh "$ROOT_DIR/tools/release/stage-web-assets.sh" forge "$tmp_dir/forge-assets"
[ -f "$tmp_dir/forge-assets/app/index.html" ]
[ -f "$tmp_dir/forge-assets/app/.host/shared/wizardry-bridge.js" ]
[ -d "$tmp_dir/forge-assets/core/include" ]
[ -d "$tmp_dir/forge-assets/core/src" ]

sh "$ROOT_DIR/tools/release/stage-web-assets.sh" chatroom "$tmp_dir/chatroom-assets"
[ -f "$tmp_dir/chatroom-assets/app/index.html" ]
[ -f "$tmp_dir/chatroom-assets/app/.host/shared/wizardry-bridge.js" ]

optional_source_root="$tmp_dir/optional-source-root"
optional_stage_root="$tmp_dir/optional-stage-root"
mkdir -p \
  "$optional_source_root" \
  "$optional_stage_root/tools/release" \
  "$optional_stage_root/apps/.host/shared" \
  "$optional_stage_root/templates/web/.themes" \
  "$optional_stage_root/runtime/config" \
  "$optional_stage_root/runtime/core/include" \
  "$optional_stage_root/runtime/core/src"
cp "$ROOT_DIR/tools/release/stage-web-assets.sh" "$optional_stage_root/tools/release/stage-web-assets.sh"
cp "$ROOT_DIR/runtime/config/templates.manifest.json" "$optional_stage_root/runtime/config/templates.manifest.json"
printf '%s\n' "optional app" >"$optional_source_root/index.html"
mkdir -p "$optional_source_root/.git"
: >"$optional_source_root/.log"
printf '%s\n' "bridge" >"$optional_stage_root/apps/.host/shared/wizardry-bridge.js"
printf '%s\n' "theme" >"$optional_stage_root/templates/web/.themes/psionic.css"
printf '%s\n' "core header" >"$optional_stage_root/runtime/core/include/wizardry.h"
printf '%s\n' "core source" >"$optional_stage_root/runtime/core/src/wizardry.c"
jq -n --arg repo "$optional_source_root" '{
  schemaVersion:"1",
  apps:[{
    slug:"optional-mobile",
    name:"Optional Mobile",
    production:false,
    distribution:"optional",
    source:{repo:$repo, ref:"main", subdir:"."},
    bundleIds:{macos:"com.example.optional.macos", ios:"com.example.optional.ios", android:"com.example.optional.android"},
    targets:"ios,android"
  }]
}' >"$optional_stage_root/runtime/config/apps.manifest.json"
sh "$optional_stage_root/tools/release/stage-web-assets.sh" optional-mobile "$tmp_dir/optional-mobile-assets"
grep -Fx "optional app" "$tmp_dir/optional-mobile-assets/app/index.html" >/dev/null
[ ! -e "$tmp_dir/optional-mobile-assets/app/.git" ]
[ ! -e "$tmp_dir/optional-mobile-assets/app/.log" ]

partial_icon_app="$tmp_dir/partial-icon-app"
partial_icon_res="$tmp_dir/partial-icon-res"
mkdir -p "$partial_icon_app/assets/icons/android/mipmap-mdpi" "$partial_icon_app/assets/icons/android/mipmap-hdpi" "$partial_icon_app/assets"
printf '%s\n' "fallback icon" > "$partial_icon_app/assets/forge-icon.png"
printf '%s\n' "generated icon" > "$partial_icon_app/assets/icons/android/mipmap-hdpi/ic_launcher.png"
sh "$ROOT_DIR/tools/icons/stage-android-launcher-icons.sh" "$partial_icon_app" "$partial_icon_res"
grep -Fx "fallback icon" "$partial_icon_res/mipmap-mdpi/ic_launcher.png" >/dev/null
grep -Fx "fallback icon" "$partial_icon_res/mipmap-mdpi/ic_launcher_round.png" >/dev/null
grep -Fx "generated icon" "$partial_icon_res/mipmap-hdpi/ic_launcher.png" >/dev/null
grep -Fx "fallback icon" "$partial_icon_res/mipmap-hdpi/ic_launcher_round.png" >/dev/null

missing_icon_app="$tmp_dir/missing-icon-app"
missing_icon_res="$tmp_dir/missing-icon-res"
mkdir -p "$missing_icon_app/assets" "$missing_icon_res/mipmap-mdpi"
printf '%s\n' "stale icon" >"$missing_icon_res/mipmap-mdpi/ic_launcher.png"
if sh "$ROOT_DIR/tools/icons/stage-android-launcher-icons.sh" "$missing_icon_app" "$missing_icon_res" >"$tmp_dir/android-missing-icon.out" 2>"$tmp_dir/android-missing-icon.err"; then
  printf '%s\n' "stage-android-launcher-icons accepted missing icon source" >&2
  exit 1
fi
grep -F "missing icon source" "$tmp_dir/android-missing-icon.err" >/dev/null
grep -Fx "stale icon" "$missing_icon_res/mipmap-mdpi/ic_launcher.png" >/dev/null

missing_ios_app="$tmp_dir/missing-ios-app"
missing_ios_assets="$tmp_dir/missing-ios-xcassets"
mkdir -p "$missing_ios_app/assets/icons/ios/AppIcon.appiconset" "$missing_ios_assets"
printf '%s\n' "partial generated icon" >"$missing_ios_app/assets/icons/ios/AppIcon.appiconset/icon-20@2x.png"
if sh "$ROOT_DIR/tools/icons/stage-ios-appiconset.sh" "$missing_ios_app" "$missing_ios_assets" >"$tmp_dir/ios-missing-icon.out" 2>"$tmp_dir/ios-missing-icon.err"; then
  printf '%s\n' "stage-ios-appiconset accepted incomplete icon set without fallback" >&2
  exit 1
fi
grep -F "generated icon set is incomplete and fallback source icon is missing" "$tmp_dir/ios-missing-icon.err" >/dev/null
[ ! -e "$missing_ios_assets/AppIcon.appiconset" ] || {
  printf '%s\n' "stage-ios-appiconset left an empty AppIcon.appiconset on failure" >&2
  exit 1
}

absent_ios_app="$tmp_dir/absent-ios-app"
absent_ios_assets="$tmp_dir/absent-ios-xcassets"
mkdir -p "$absent_ios_app" "$absent_ios_assets"
sh "$ROOT_DIR/tools/icons/stage-ios-appiconset.sh" "$absent_ios_app" "$absent_ios_assets"
[ ! -e "$absent_ios_assets/AppIcon.appiconset" ] || {
  printf '%s\n' "stage-ios-appiconset created AppIcon.appiconset when no icon inputs existed" >&2
  exit 1
}

partial_ios_app="$tmp_dir/partial-ios-app"
partial_ios_assets="$tmp_dir/partial-ios-xcassets"
fake_icon_bin="$tmp_dir/fake-icon-bin"
mkdir -p "$partial_ios_app/assets/icons/ios/AppIcon.appiconset" "$partial_ios_app/assets" "$fake_icon_bin"
printf '%s\n' "partial generated icon" >"$partial_ios_app/assets/icons/ios/AppIcon.appiconset/icon-20@2x.png"
printf '%s\n' "fallback icon" >"$partial_ios_app/assets/forge-icon.png"
cat >"$fake_icon_bin/sips" <<'SH'
#!/bin/sh
out=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--out" ]; then
    shift
    out=${1-}
    break
  fi
  shift
done
[ -n "$out" ] || exit 2
mkdir -p "$(dirname "$out")"
printf '%s\n' "rendered icon" >"$out"
SH
chmod +x "$fake_icon_bin/sips"
PATH="$fake_icon_bin:$PATH" sh "$ROOT_DIR/tools/icons/stage-ios-appiconset.sh" "$partial_ios_app" "$partial_ios_assets"
grep -Fx "rendered icon" "$partial_ios_assets/AppIcon.appiconset/icon-1024.png" >/dev/null
[ -f "$partial_ios_assets/AppIcon.appiconset/Contents.json" ]
grep -F "GENERATE_INFOPLIST_FILE: YES" "$ROOT_DIR/apps/.host/ios/project-template.yml" >/dev/null || {
  printf '%s\n' "iOS project template must generate Info.plist from INFOPLIST_KEY settings" >&2
  exit 1
}
grep -F 'app_path="$derived_data/Build/Products/Debug-iphonesimulator/$APP_NAME.app"' "$ROOT_DIR/tools/release/build-ios-app.sh" >/dev/null || {
  printf '%s\n' "build-ios-app must package the generated product app name, not the template target name" >&2
  exit 1
}

fake_ios_bin="$tmp_dir/fake-ios-bin"
mkdir -p "$fake_ios_bin"
cat >"$fake_ios_bin/xcodegen" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$fake_ios_bin/xcodebuild" <<'SH'
#!/bin/sh
derived=''
export_path=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -derivedDataPath)
      shift
      derived=${1-}
      ;;
    -exportPath)
      shift
      export_path=${1-}
      ;;
  esac
  shift
done
if [ -n "$derived" ]; then
  mkdir -p "$derived/Build/Products/Debug-iphonesimulator/WizardryHost.app"
  mkdir -p "$derived/Build/Products/Debug-iphonesimulator/App Forge.app"
fi
if [ -n "$export_path" ]; then
  mkdir -p "$export_path"
  : >"$export_path/WizardryHost.ipa"
fi
exit 0
SH
cat >"$fake_ios_bin/openssl" <<'SH'
#!/bin/sh
cat
SH
cat >"$fake_ios_bin/security" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$fake_ios_bin/xcodegen" "$fake_ios_bin/xcodebuild" "$fake_ios_bin/openssl" "$fake_ios_bin/security"

bad_ios_slug=$(printf 'forge\nforged=1')
if PATH="$fake_ios_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/build-ios-app.sh" "$bad_ios_slug" "$tmp_dir/ios-bad-slug-out" smoke >"$tmp_dir/ios-bad-slug.out" 2>"$tmp_dir/ios-bad-slug.err"; then
  printf '%s\n' "build-ios-app accepted newline app slug" >&2
  exit 1
fi
grep -F "invalid app slug" "$tmp_dir/ios-bad-slug.err" >/dev/null
[ ! -e "$tmp_dir/ios-bad-slug-out" ]
if tr '\r' '\n' <"$tmp_dir/ios-bad-slug.err" | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "build-ios-app emitted forged rows from invalid app slug" >&2
  exit 1
fi

bad_ios_out="$tmp_dir/ios-out
forged=1"
if PATH="$fake_ios_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/build-ios-app.sh" forge "$bad_ios_out" smoke >"$tmp_dir/ios-bad-out.out" 2>"$tmp_dir/ios-bad-out.err"; then
  rm -rf "$ROOT_DIR/_tmp/ios-build-forge"
  printf '%s\n' "build-ios-app accepted newline output directory" >&2
  exit 1
fi
grep -F "output directory must not contain line breaks" "$tmp_dir/ios-bad-out.err" >/dev/null
[ ! -e "$bad_ios_out" ]

if (
  cd "$tmp_dir" &&
  PATH="$fake_ios_bin:$PATH" sh "$ROOT_DIR/tools/release/build-ios-app.sh" forge "-ios-out" smoke >"$tmp_dir/ios-leading-dash-out.out" 2>"$tmp_dir/ios-leading-dash-out.err"
); then
  rm -rf "$ROOT_DIR/_tmp/ios-build-forge"
  printf '%s\n' "build-ios-app accepted leading-dash output directory" >&2
  exit 1
fi
grep -F "output directory must be a safe path" "$tmp_dir/ios-leading-dash-out.err" >/dev/null
[ ! -e "$tmp_dir/-ios-out" ]

if PATH="$fake_ios_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/build-ios-app.sh" forge "$tmp_dir/ios-extra-out" smoke ignored >"$tmp_dir/ios-extra.out" 2>"$tmp_dir/ios-extra.err"; then
  rm -rf "$ROOT_DIR/_tmp/ios-build-forge"
  printf '%s\n' "build-ios-app accepted an extra operand" >&2
  exit 1
fi
grep -F "APP_SLUG OUT_DIR and optional mode required" "$tmp_dir/ios-extra.err" >/dev/null
[ ! -e "$tmp_dir/ios-extra-out" ]

if RELEASE_VERSION='v1.2.3/../../bad' \
   PATH="$fake_ios_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/build-ios-app.sh" forge "$tmp_dir/ios-version-out" smoke >"$tmp_dir/ios-invalid-version.out" 2>"$tmp_dir/ios-invalid-version.err"; then
  rm -rf "$ROOT_DIR/_tmp/ios-build-forge"
  printf '%s\n' "build-ios-app accepted invalid release version" >&2
  exit 1
fi
grep -F "invalid release version" "$tmp_dir/ios-invalid-version.err" >/dev/null

bad_build_issuer=$(printf '11111111-1111-1111-1111-111111111111\nforged=1')
if APPLE_P12_BASE64='bad' \
   APPLE_P12_PASSWORD='password' \
   APPLE_TEAM_ID='TEAM123456' \
   APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID="$bad_build_issuer" \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   PATH="$fake_ios_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/build-ios-app.sh" forge "$tmp_dir/ios-issuer-out" release >"$tmp_dir/ios-invalid-issuer.out" 2>"$tmp_dir/ios-invalid-issuer.err"; then
  rm -rf "$ROOT_DIR/_tmp/ios-build-forge"
  printf '%s\n' "build-ios-app accepted invalid issuer id" >&2
  exit 1
fi
grep -F "invalid App Store Connect issuer id" "$tmp_dir/ios-invalid-issuer.err" >/dev/null

if APPLE_P12_BASE64='bad' \
   APPLE_P12_PASSWORD='password' \
   APPLE_TEAM_ID='TEAM/../../BAD' \
   APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   PATH="$fake_ios_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/build-ios-app.sh" forge "$tmp_dir/ios-team-out" release >"$tmp_dir/ios-invalid-team.out" 2>"$tmp_dir/ios-invalid-team.err"; then
  rm -rf "$ROOT_DIR/_tmp/ios-build-forge"
  printf '%s\n' "build-ios-app accepted invalid Apple team id" >&2
  exit 1
fi
grep -F "invalid Apple team id" "$tmp_dir/ios-invalid-team.err" >/dev/null

if sh "$ROOT_DIR/tools/release/stage-web-assets.sh" ../web/demo "$tmp_dir/traversed-assets" >/dev/null 2>&1; then
  printf '%s\n' "stage-web-assets accepted slug path traversal" >&2
  exit 1
fi
[ ! -e "$tmp_dir/traversed-assets" ]

if sh "$ROOT_DIR/tools/release/stage-web-assets.sh" forge "$tmp_dir/extra-assets" ignored >"$tmp_dir/stage-extra.out" 2>"$tmp_dir/stage-extra.err"; then
  printf '%s\n' "stage-web-assets accepted an extra operand before replacing the destination" >&2
  exit 1
fi
grep -F "APP_SLUG and DEST_DIR required" "$tmp_dir/stage-extra.err" >/dev/null
[ ! -e "$tmp_dir/extra-assets" ]

sync_source="$tmp_dir/sync-source"
sync_target="$tmp_dir/sync-target"
mkdir -p \
  "$sync_source/spells/web" \
  "$sync_source/spells/.arcana/web-wizardry" \
  "$sync_source/web" \
  "$sync_source/apps/.host" \
  "$sync_source/apps/forge" \
  "$sync_source/.tests/web" \
  "$sync_source/.tests/.arcana/web-wizardry" \
  "$sync_target/apps/.host"
printf '%s\n' "site spell" > "$sync_source/spells/web/site-spell"
printf '%s\n' "hidden site metadata" > "$sync_source/spells/web/.site-hidden"
printf '%s\n' "arcana spell" > "$sync_source/spells/.arcana/web-wizardry/install"
printf '%s\n' "web page" > "$sync_source/web/index.html"
printf '%s\n' "source host should not sync" > "$sync_source/apps/.host/source-host.txt"
printf '%s\n' "forge app" > "$sync_source/apps/forge/app.txt"
printf '%s\n' "web test" > "$sync_source/.tests/web/test-web"
printf '%s\n' "arcana test" > "$sync_source/.tests/.arcana/web-wizardry/test-arcana"
printf '%s\n' "local host stays local" > "$sync_target/apps/.host/local-host.txt"

sh "$ROOT_DIR/tools/sync-from-wizardry.sh" "$sync_source" "$sync_target" > "$tmp_dir/sync.out"
[ -f "$sync_target/spells/web/site-spell" ]
[ -f "$sync_target/spells/web/.site-hidden" ]
[ -f "$sync_target/spells/.arcana/web-wizardry/install" ]
[ -f "$sync_target/templates/web/index.html" ]
[ -f "$sync_target/apps/forge/app.txt" ]
[ -f "$sync_target/.tests/web/test-web" ]
[ -f "$sync_target/.tests/.arcana/web-wizardry/test-arcana" ]
[ -f "$sync_target/apps/.host/local-host.txt" ]
[ ! -e "$sync_target/apps/.host/source-host.txt" ]

if sh "$ROOT_DIR/tools/sync-from-wizardry.sh" "$sync_source" "$sync_source" >"$tmp_dir/sync-same.out" 2>&1; then
  printf '%s\n' "sync-from-wizardry accepted identical source and target" >&2
  exit 1
fi
grep -F "source and target must be different" "$tmp_dir/sync-same.out" >/dev/null

if sh "$ROOT_DIR/tools/sync-from-wizardry.sh" "$tmp_dir/missing-source" "$sync_target" >"$tmp_dir/sync-missing.out" 2>&1; then
  printf '%s\n' "sync-from-wizardry accepted missing source" >&2
  exit 1
fi
grep -F "source directory not found" "$tmp_dir/sync-missing.out" >/dev/null

sync_newline_source="$tmp_dir/sync-newline
source"
mkdir -p "$sync_newline_source/spells/web"
if sh "$ROOT_DIR/tools/sync-from-wizardry.sh" "$sync_newline_source" "$sync_target" >"$tmp_dir/sync-newline.out" 2>&1; then
  printf '%s\n' "sync-from-wizardry accepted newline source path" >&2
  exit 1
fi
grep -F "source directory must not contain line breaks" "$tmp_dir/sync-newline.out" >/dev/null

aab_path="$tmp_dir/app.aab"
: > "$aab_path"
bad_aab_path="$tmp_dir/app
forged=1.aab"
: > "$bad_aab_path"
if sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$bad_aab_path" "com.example.app" internal >"$tmp_dir/play-upload-bad-aab-path.err" 2>&1; then
  printf '%s\n' "upload-play-internal accepted newline AAB path" >&2
  exit 1
fi
grep -F "AAB path must not contain line breaks" "$tmp_dir/play-upload-bad-aab-path.err" >/dev/null

bad_aab_suffix="$tmp_dir/app.txt"
: > "$bad_aab_suffix"
if sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$bad_aab_suffix" "com.example.app" internal >"$tmp_dir/play-upload-bad-aab-suffix.err" 2>&1; then
  printf '%s\n' "upload-play-internal accepted a non-AAB artifact path" >&2
  exit 1
fi
grep -F "AAB path must end with .aab" "$tmp_dir/play-upload-bad-aab-suffix.err" >/dev/null

if sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" "com.example.app" internal ignored >"$tmp_dir/play-upload-extra.err" 2>&1; then
  printf '%s\n' "upload-play-internal accepted an extra operand" >&2
  exit 1
fi
grep -F "AAB_PATH PACKAGE_NAME and optional TRACK required" "$tmp_dir/play-upload-extra.err" >/dev/null

if sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" "com.example/../../other" internal >"$tmp_dir/play-upload-invalid-package.err" 2>&1; then
  printf '%s\n' "upload-play-internal accepted invalid package name" >&2
  exit 1
fi
grep -F "invalid package name" "$tmp_dir/play-upload-invalid-package.err" >/dev/null

if sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" "com.example.app" "internal/../../production" >"$tmp_dir/play-upload-invalid-track.err" 2>&1; then
  printf '%s\n' "upload-play-internal accepted invalid track" >&2
  exit 1
fi
grep -F "invalid track" "$tmp_dir/play-upload-invalid-track.err" >/dev/null

if PLAY_RELEASE_STATUS='maybe' \
   sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" "com.example.app" internal >"$tmp_dir/play-upload-invalid-status.err" 2>&1; then
  printf '%s\n' "upload-play-internal accepted invalid release status" >&2
  exit 1
fi
grep -F "invalid release status" "$tmp_dir/play-upload-invalid-status.err" >/dev/null

if sh "$ROOT_DIR/tools/release/promote-play-track.sh" "com.example/../../other" internal production >"$tmp_dir/play-promote-invalid-package.err" 2>&1; then
  printf '%s\n' "promote-play-track accepted invalid package name" >&2
  exit 1
fi
grep -F "invalid package name" "$tmp_dir/play-promote-invalid-package.err" >/dev/null

if sh "$ROOT_DIR/tools/release/promote-play-track.sh" "com.example.app" "internal/../../prod" production >"$tmp_dir/play-promote-invalid-track.err" 2>&1; then
  printf '%s\n' "promote-play-track accepted invalid track" >&2
  exit 1
fi
grep -F "invalid track" "$tmp_dir/play-promote-invalid-track.err" >/dev/null

if sh "$ROOT_DIR/tools/release/promote-play-track.sh" "com.example.app" internal production 123 ignored >"$tmp_dir/play-promote-extra.err" 2>&1; then
  printf '%s\n' "promote-play-track accepted an extra operand" >&2
  exit 1
fi
grep -F "PACKAGE_NAME and optional FROM_TRACK TO_TRACK VERSION_CODES required" "$tmp_dir/play-promote-extra.err" >/dev/null

fake_play_bin="$tmp_dir/fake-play-bin"
mkdir -p "$fake_play_bin"
cat >"$fake_play_bin/openssl" <<'SH'
#!/bin/sh
cat
SH
cat >"$fake_play_bin/curl" <<'SH'
#!/bin/sh
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    https://*) url=$1 ;;
  esac
  shift
done
case "$url" in
  https://oauth2.googleapis.com/token)
    if [ "${PLAY_FAKE_BAD_ACCESS_TOKEN-}" = "1" ]; then
      printf '%s\n' '{"access_token":"token123\nInjected: bad"}'
    else
      printf '%s\n' '{"access_token":"token123"}'
    fi
    ;;
  *'/edits/edit123/bundles?uploadType=media')
    if [ "${PLAY_FAKE_BAD_VERSION_CODE-}" = "1" ]; then
      printf '%s\n' '{"versionCode":"123\nforged=1"}'
    else
      printf '%s\n' '{"versionCode":"123"}'
    fi
    ;;
  *'/edits/edit123/tracks/internal')
    if [ "${PLAY_FAKE_BAD_SOURCE_CODES-}" = "1" ]; then
      printf '%s\n' '{"releases":[{"versionCodes":["123\nforged=1"]}]}'
    else
      printf '%s\n' '{"releases":[{"versionCodes":["123"]}]}'
    fi
    ;;
  *'/edits/edit123/tracks/'*)
    printf '%s\n' '{"releases":[{}]}'
    ;;
  *'/edits/edit123:commit')
    printf '%s\n' '{"id":"edit123"}'
    ;;
  *'/edits')
    printf '%s\n' '{"id":"edit123"}'
    ;;
  *)
    printf '%s\n' '{}'
    ;;
esac
SH
chmod +x "$fake_play_bin/openssl" "$fake_play_bin/curl"
bad_service_json='{"client_email":"bad\nemail@example.com","private_key":"key"}'
if PLAY_SERVICE_ACCOUNT_JSON_BASE64="$bad_service_json" \
   PATH="$fake_play_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" com.example.app internal >"$tmp_dir/play-upload-bad-email.out" 2>"$tmp_dir/play-upload-bad-email.err"; then
  printf '%s\n' "upload-play-internal accepted invalid service account email" >&2
  exit 1
fi
grep -F "invalid service account json (client_email)" "$tmp_dir/play-upload-bad-email.err" >/dev/null

good_service_json='{"client_email":"svc@example.iam.gserviceaccount.com","private_key":"key"}'
if PLAY_SERVICE_ACCOUNT_JSON_BASE64="$good_service_json" \
   PLAY_FAKE_BAD_ACCESS_TOKEN=1 \
   PATH="$fake_play_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" com.example.app internal >"$tmp_dir/play-upload-bad-token.out" 2>"$tmp_dir/play-upload-bad-token.err"; then
  printf '%s\n' "upload-play-internal accepted invalid API access token" >&2
  exit 1
fi
grep -F "invalid access token from API" "$tmp_dir/play-upload-bad-token.err" >/dev/null

if PLAY_SERVICE_ACCOUNT_JSON_BASE64="$good_service_json" \
   PLAY_FAKE_BAD_VERSION_CODE=1 \
   PATH="$fake_play_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/upload-play-internal.sh" "$aab_path" com.example.app internal >"$tmp_dir/play-upload-bad-version.out" 2>"$tmp_dir/play-upload-bad-version.err"; then
  printf '%s\n' "upload-play-internal accepted invalid API version code" >&2
  exit 1
fi
grep -F "invalid version code from API" "$tmp_dir/play-upload-bad-version.err" >/dev/null

if PLAY_SERVICE_ACCOUNT_JSON_BASE64="$good_service_json" \
   PLAY_FAKE_BAD_ACCESS_TOKEN=1 \
   PATH="$fake_play_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/promote-play-track.sh" com.example.app internal production >"$tmp_dir/play-promote-bad-token.out" 2>"$tmp_dir/play-promote-bad-token.err"; then
  printf '%s\n' "promote-play-track accepted invalid API access token" >&2
  exit 1
fi
grep -F "invalid access token from API" "$tmp_dir/play-promote-bad-token.err" >/dev/null

if PLAY_SERVICE_ACCOUNT_JSON_BASE64="$good_service_json" \
   PLAY_FAKE_BAD_SOURCE_CODES=1 \
   PATH="$fake_play_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/promote-play-track.sh" com.example.app internal production >"$tmp_dir/play-promote-bad-codes.out" 2>"$tmp_dir/play-promote-bad-codes.err"; then
  printf '%s\n' "promote-play-track accepted invalid API version codes" >&2
  exit 1
fi
grep -F "invalid version codes from API" "$tmp_dir/play-promote-bad-codes.err" >/dev/null

deploy_bundle="$tmp_dir/deploy-bundle"
mkdir -p "$deploy_bundle"
fake_deploy_bin="$tmp_dir/fake-deploy-bin"
mkdir -p "$fake_deploy_bin"
cat >"$fake_deploy_bin/openssl" <<'SH'
#!/bin/sh
cat
SH
cat >"$fake_deploy_bin/ssh" <<'SH'
#!/bin/sh
[ -n "${FAKE_SSH_LOG-}" ] || exit 0
: >"$FAKE_SSH_LOG"
for arg in "$@"; do
  printf '%s\n' "$arg" >>"$FAKE_SSH_LOG"
done
exit 0
SH
cat >"$fake_deploy_bin/rsync" <<'SH'
#!/bin/sh
ssh_cmd=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-e" ]; then
    shift
    ssh_cmd=${1-}
    break
  fi
  shift
done
if [ -n "$ssh_cmd" ] && [ -n "${FAKE_SSH_LOG-}" ]; then
  sh -c "$ssh_cmd --fake-probe"
fi
exit 0
SH
chmod +x "$fake_deploy_bin/openssl" "$fake_deploy_bin/ssh" "$fake_deploy_bin/rsync"
bad_deploy_host=$(printf 'example.com\nforged=1')
if WEB_DEPLOY_HOST="$bad_deploy_host" \
   WEB_DEPLOY_USER='deploy' \
   WEB_DEPLOY_PATH='/var/www/wizardry' \
   WEB_DEPLOY_SSH_KEY_BASE64='bad' \
   PATH="$fake_deploy_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/deploy-hosted-web.sh" "$deploy_bundle" >"$tmp_dir/deploy-bad-host.out" 2>"$tmp_dir/deploy-bad-host.err"; then
  printf '%s\n' "deploy-hosted-web accepted invalid host" >&2
  exit 1
fi
grep -F "invalid deploy host" "$tmp_dir/deploy-bad-host.err" >/dev/null

if WEB_DEPLOY_HOST='example.com' \
   WEB_DEPLOY_USER='deploy' \
   WEB_DEPLOY_PATH='/var/www/../../other' \
   WEB_DEPLOY_SSH_KEY_BASE64='bad' \
   PATH="$fake_deploy_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/deploy-hosted-web.sh" "$deploy_bundle" >"$tmp_dir/deploy-bad-path.out" 2>"$tmp_dir/deploy-bad-path.err"; then
  printf '%s\n' "deploy-hosted-web accepted invalid path" >&2
  exit 1
fi
grep -F "invalid deploy path" "$tmp_dir/deploy-bad-path.err" >/dev/null

deploy_tmpdir="$tmp_dir/deploy tmp 'quote"
deploy_ssh_log="$tmp_dir/deploy-ssh-args.log"
mkdir -p "$deploy_tmpdir"
if ! WEB_DEPLOY_HOST='example.com' \
     WEB_DEPLOY_USER='deploy' \
     WEB_DEPLOY_PATH='/var/www/wizardry' \
     WEB_DEPLOY_SSH_KEY_BASE64='bad' \
     FAKE_SSH_LOG="$deploy_ssh_log" \
     TMPDIR="$deploy_tmpdir" \
     PATH="$fake_deploy_bin:$PATH" \
     sh "$ROOT_DIR/tools/release/deploy-hosted-web.sh" "$deploy_bundle" >"$tmp_dir/deploy-quoted-key.out" 2>"$tmp_dir/deploy-quoted-key.err"; then
  printf '%s\n' "deploy-hosted-web failed with a quote-bearing TMPDIR" >&2
  cat "$tmp_dir/deploy-quoted-key.err" >&2
  exit 1
fi
deploy_key_arg=$(awk 'previous == "-i" { print; exit } { previous = $0 }' "$deploy_ssh_log")
case "$deploy_key_arg" in
  "$deploy_tmpdir"/web-deploy.*.key)
    ;;
  *)
    printf '%s\n' "deploy-hosted-web did not preserve quoted ssh key path as one argument" >&2
    exit 1
    ;;
esac

if sh "$ROOT_DIR/tools/release/deploy-hosted-web.sh" "$deploy_bundle" ignored >"$tmp_dir/deploy-extra.out" 2>"$tmp_dir/deploy-extra.err"; then
  printf '%s\n' "deploy-hosted-web accepted an extra operand" >&2
  exit 1
fi
grep -F "exactly one BUNDLE_DIR required" "$tmp_dir/deploy-extra.err" >/dev/null

sign_app="$tmp_dir/Test.app"
mkdir -p "$sign_app"
fake_sign_bin="$tmp_dir/fake-sign-bin"
mkdir -p "$fake_sign_bin"
cat >"$fake_sign_bin/openssl" <<'SH'
#!/bin/sh
cat
SH
cat >"$fake_sign_bin/security" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$fake_sign_bin/codesign" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$fake_sign_bin/xcrun" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$fake_sign_bin/openssl" "$fake_sign_bin/security" "$fake_sign_bin/codesign" "$fake_sign_bin/xcrun"
bad_sign_app="$tmp_dir/Bad
forged=1.app"
mkdir -p "$bad_sign_app"
if sh "$ROOT_DIR/tools/release/sign-and-notarize-macos.sh" "$bad_sign_app" >"$tmp_dir/sign-bad-app-path.out" 2>"$tmp_dir/sign-bad-app-path.err"; then
  printf '%s\n' "sign-and-notarize-macos accepted newline app bundle path" >&2
  exit 1
fi
grep -F "app bundle path must not contain line breaks" "$tmp_dir/sign-bad-app-path.err" >/dev/null

sign_not_app="$tmp_dir/NotApp"
mkdir -p "$sign_not_app"
if sh "$ROOT_DIR/tools/release/sign-and-notarize-macos.sh" "$sign_not_app" >"$tmp_dir/sign-not-app.out" 2>"$tmp_dir/sign-not-app.err"; then
  printf '%s\n' "sign-and-notarize-macos accepted a non-.app directory" >&2
  exit 1
fi
grep -F "app bundle path must be a .app bundle" "$tmp_dir/sign-not-app.err" >/dev/null

mkdir -p "$tmp_dir/-Bad.app"
if (
  cd "$tmp_dir" &&
  sh "$ROOT_DIR/tools/release/sign-and-notarize-macos.sh" "-Bad.app" >"$tmp_dir/sign-leading-dash.out" 2>"$tmp_dir/sign-leading-dash.err"
); then
  printf '%s\n' "sign-and-notarize-macos accepted a leading-dash app bundle path" >&2
  exit 1
fi
grep -F "app bundle path must be a safe .app bundle path" "$tmp_dir/sign-leading-dash.err" >/dev/null

if sh "$ROOT_DIR/tools/release/sign-and-notarize-macos.sh" "$sign_app" ignored >"$tmp_dir/sign-extra.out" 2>"$tmp_dir/sign-extra.err"; then
  printf '%s\n' "sign-and-notarize-macos accepted an extra operand" >&2
  exit 1
fi
grep -F "exactly one APP_BUNDLE required" "$tmp_dir/sign-extra.err" >/dev/null

bad_notary_issuer=$(printf '11111111-1111-1111-1111-111111111111\nforged=1')
if APPLE_P12_BASE64='bad' \
   APPLE_P12_PASSWORD='password' \
   APPLE_DEVELOPER_ID_APP='Developer ID Application: Example (TEAM123456)' \
   APPLE_TEAM_ID='TEAM123456' \
   APPLE_NOTARY_KEY_ID='ABC123DEF4' \
   APPLE_NOTARY_ISSUER_ID="$bad_notary_issuer" \
   APPLE_NOTARY_PRIVATE_KEY_BASE64='bad' \
   PATH="$fake_sign_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/sign-and-notarize-macos.sh" "$sign_app" >"$tmp_dir/sign-bad-issuer.out" 2>"$tmp_dir/sign-bad-issuer.err"; then
  printf '%s\n' "sign-and-notarize-macos accepted invalid notary issuer id" >&2
  exit 1
fi
grep -F "invalid Apple notary issuer id" "$tmp_dir/sign-bad-issuer.err" >/dev/null

fake_magick_bin="$tmp_dir/fake-magick-bin"
mkdir -p "$fake_magick_bin"
cat >"$fake_magick_bin/magick" <<'SH'
#!/bin/sh
if [ "${1-}" = "identify" ]; then
  case "${3-}" in
    *'%[opaque]'*) printf '%s\n' "100 100 true" ;;
    *) printf '%s\n' "100 100" ;;
  esac
  exit 0
fi
out=''
for arg in "$@"; do
  out=$arg
done
[ -n "$out" ] || exit 0
mkdir -p "$(dirname "$out")"
printf '%s\n' "image" >"$out"
SH
chmod +x "$fake_magick_bin/magick"
icon_input="$tmp_dir/icon.png"
icon_project="$tmp_dir/icon-project"
bad_icon_project="$tmp_dir/icon-project
forged=1"
: >"$icon_input"
mkdir -p "$icon_project" "$bad_icon_project"
if PATH="$fake_magick_bin:$PATH" \
   sh "$ROOT_DIR/tools/icons/generate-platform-icons.sh" "$icon_input" "$bad_icon_project" >"$tmp_dir/icons-bad-project.out" 2>"$tmp_dir/icons-bad-project.err"; then
  printf '%s\n' "generate-platform-icons accepted newline project path" >&2
  exit 1
fi
grep -F "project directory must not contain line breaks" "$tmp_dir/icons-bad-project.err" >/dev/null

bad_ext_icon="$tmp_dir/icon.bad-ext"
bad_ext_project="$tmp_dir/icon-bad-ext-project"
: >"$bad_ext_icon"
mkdir -p "$bad_ext_project"
if PATH="$fake_magick_bin:$PATH" \
   sh "$ROOT_DIR/tools/icons/generate-platform-icons.sh" "$bad_ext_icon" "$bad_ext_project" >"$tmp_dir/icons-bad-ext.out" 2>"$tmp_dir/icons-bad-ext.err"; then
  printf '%s\n' "generate-platform-icons accepted invalid input image extension" >&2
  exit 1
fi
grep -F "invalid input image extension" "$tmp_dir/icons-bad-ext.err" >/dev/null
[ ! -e "$bad_ext_project/assets" ]

printf '%s\n' "release tools smoke passed"
