#!/bin/sh

# Stage app web assets for embedded desktop/mobile hosts.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: stage-web-assets.sh APP_SLUG DEST_DIR

Copies:
  apps/APP_SLUG/* -> DEST_DIR/app/
  apps/.host/shared/* -> DEST_DIR/app/.host/shared/
  web/.themes/* -> DEST_DIR/app/themes/
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
theme_dir="$ROOT_DIR/web/.themes"

[ -d "$app_dir" ] || {
  printf '%s\n' "stage-web-assets: app not found: $slug" >&2
  exit 1
}

[ -d "$shared_dir" ] || {
  printf '%s\n' "stage-web-assets: shared host bridge not found" >&2
  exit 1
}

[ -d "$theme_dir" ] || {
  printf '%s\n' "stage-web-assets: theme directory not found: $theme_dir" >&2
  exit 1
}

rm -rf "$dest"
mkdir -p "$dest/app" "$dest/app/.host/shared" "$dest/core"

for entry in "$app_dir"/* "$app_dir"/.[!.]* "$app_dir"/..?*; do
  [ -e "$entry" ] || continue
  base=$(basename "$entry")
  [ "$base" = "." ] && continue
  [ "$base" = ".." ] && continue
  [ "$base" = "themes" ] && continue
  cp -R "$entry" "$dest/app/"
done

mkdir -p "$dest/app/themes"
cp -R "$shared_dir"/. "$dest/app/.host/shared/"
cp -R "$theme_dir"/. "$dest/app/themes/"
cp -R "$ROOT_DIR/core/include" "$dest/core/include"
cp -R "$ROOT_DIR/core/src" "$dest/core/src"

printf '%s\n' "stage-web-assets: staged $slug -> $dest"
