#!/bin/sh

# Stage app web assets for embedded desktop/mobile hosts.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: stage-web-assets.sh APP_SLUG DEST_DIR

Copies:
  apps/APP_SLUG/* -> DEST_DIR/app/
  apps/.host/shared/* -> DEST_DIR/app/.host/shared/
  core/include + core/src -> DEST_DIR/core/
USAGE
  exit 0
  ;;
esac

set -eu

slug=${1-}
dest=${2-}

if [ -z "$slug" ] || [ -z "$dest" ]; then
  printf '%s\n' "stage-web-assets: APP_SLUG and DEST_DIR required" >&2
  exit 2
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app_dir="$ROOT_DIR/apps/$slug"
shared_dir="$ROOT_DIR/apps/.host/shared"

[ -d "$app_dir" ] || {
  printf '%s\n' "stage-web-assets: app not found: $slug" >&2
  exit 1
}

[ -d "$shared_dir" ] || {
  printf '%s\n' "stage-web-assets: shared host bridge not found" >&2
  exit 1
}

rm -rf "$dest"
mkdir -p "$dest/app" "$dest/app/.host/shared" "$dest/core"

cp -R "$app_dir"/. "$dest/app/"
cp -R "$shared_dir"/. "$dest/app/.host/shared/"
cp -R "$ROOT_DIR/core/include" "$dest/core/include"
cp -R "$ROOT_DIR/core/src" "$dest/core/src"

if [ ! -f "$dest/app/assets/forge-icon.png" ] && [ -f "$ROOT_DIR/apps/forge/assets/forge-icon.png" ]; then
  mkdir -p "$dest/app/assets"
  cp "$ROOT_DIR/apps/forge/assets/forge-icon.png" "$dest/app/assets/forge-icon.png"
fi

printf '%s\n' "stage-web-assets: staged $slug -> $dest"
