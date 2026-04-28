#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

name=$(sh "$ROOT_DIR/tools/release/get-app-name.sh" artificer)
[ "$name" = "Artificer" ]

forge_name=$(sh "$ROOT_DIR/tools/release/get-app-name.sh" forge)
[ "$forge_name" = "App Forge" ]

bundle_id=$(sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" android artificer)
printf '%s' "$bundle_id" | grep -Eq '^[A-Za-z0-9]+(\.[A-Za-z0-9-]+)+$'

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-stage-assets.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

sh "$ROOT_DIR/tools/release/stage-web-assets.sh" forge "$tmp_dir/forge-assets"
[ -f "$tmp_dir/forge-assets/app/index.html" ]
[ -f "$tmp_dir/forge-assets/app/.host/shared/wizardry-bridge.js" ]
[ -d "$tmp_dir/forge-assets/core/include" ]
[ -d "$tmp_dir/forge-assets/core/src" ]

sh "$ROOT_DIR/tools/release/stage-web-assets.sh" chatroom "$tmp_dir/chatroom-assets"
[ -f "$tmp_dir/chatroom-assets/app/index.html" ]
[ -f "$tmp_dir/chatroom-assets/app/.host/shared/wizardry-bridge.js" ]

if sh "$ROOT_DIR/tools/release/stage-web-assets.sh" ../web/demo "$tmp_dir/traversed-assets" >/dev/null 2>&1; then
  printf '%s\n' "stage-web-assets accepted slug path traversal" >&2
  exit 1
fi
[ ! -e "$tmp_dir/traversed-assets" ]

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
[ -f "$sync_target/web/index.html" ]
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

aab_path="$tmp_dir/app.aab"
: > "$aab_path"
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

printf '%s\n' "release tools smoke passed"
