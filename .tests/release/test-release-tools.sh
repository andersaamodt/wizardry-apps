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

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-release-tools.XXXXXX")
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

jq '.apps[0].bundleIds.android = "com.example/../../bad"' "$ROOT_DIR/runtime/config/apps.manifest.json" >"$bad_manifest_root/runtime/config/apps.manifest.json"
if WIZARDRY_APPS_ROOT="$bad_manifest_root" sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" android artificer-web >"$tmp_dir/bad-bundle-id.out" 2>"$tmp_dir/bad-bundle-id.err"; then
  printf '%s\n' "get-app-bundle-id accepted unsafe manifest bundle id" >&2
  exit 1
fi
grep -F "unsafe bundle id" "$tmp_dir/bad-bundle-id.err" >/dev/null

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

partial_icon_app="$tmp_dir/partial-icon-app"
partial_icon_res="$tmp_dir/partial-icon-res"
mkdir -p "$partial_icon_app/assets/icons/android/mipmap-mdpi" "$partial_icon_app/assets/icons/android/mipmap-hdpi" "$partial_icon_app/assets"
printf '%s\n' "fallback icon" > "$partial_icon_app/assets/forge-icon.png"
printf '%s\n' "generated icon" > "$partial_icon_app/assets/icons/android/mipmap-hdpi/ic_launcher.png"
sh "$ROOT_DIR/tools/icons/stage-android-launcher-icons.sh" "$partial_icon_app" "$partial_icon_res"
grep -Fx "fallback icon" "$partial_icon_res/mipmap-mdpi/ic_launcher.png" >/dev/null
grep -Fx "fallback icon" "$partial_icon_res/mipmap-mdpi/ic_launcher_round.png" >/dev/null
grep -Fx "generated icon" "$partial_icon_res/mipmap-hdpi/ic_launcher.png" >/dev/null

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
printf '%s\n' "arcana spell" > "$sync_source/spells/.arcana/web-wizardry/install"
printf '%s\n' "web page" > "$sync_source/web/index.html"
printf '%s\n' "source host should not sync" > "$sync_source/apps/.host/source-host.txt"
printf '%s\n' "forge app" > "$sync_source/apps/forge/app.txt"
printf '%s\n' "web test" > "$sync_source/.tests/web/test-web"
printf '%s\n' "arcana test" > "$sync_source/.tests/.arcana/web-wizardry/test-arcana"
printf '%s\n' "local host stays local" > "$sync_target/apps/.host/local-host.txt"

sh "$ROOT_DIR/tools/sync-from-wizardry.sh" "$sync_source" "$sync_target" > "$tmp_dir/sync.out"
[ -f "$sync_target/spells/web/site-spell" ]
[ -f "$sync_target/spells/.arcana/web-wizardry/install" ]
[ -f "$sync_target/templates/web/index.html" ]
[ -f "$sync_target/apps/forge/app.txt" ]
[ -f "$sync_target/.tests/web/test-web" ]
[ -f "$sync_target/.tests/.arcana/web-wizardry/test-arcana" ]
[ -f "$sync_target/apps/.host/local-host.txt" ]
[ ! -e "$sync_target/apps/.host/source-host.txt" ]

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

printf '%s\n' "wizardry release tools smoke passed"
