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

printf '%s\n' "release tools smoke passed"
