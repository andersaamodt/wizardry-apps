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
