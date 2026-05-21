#!/bin/sh

# Prepare a disposable Android host project with staged app assets.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: prepare-android-host.sh APP_SLUG DEST_DIR

Copies apps/.host/android to DEST_DIR, then stages web assets and launcher icons
inside that disposable Android project.
USAGE
  exit 0
  ;;
esac

set -eu

slug=${1-}
dest=${2-}

if [ -z "$slug" ] || [ -z "$dest" ]; then
  printf '%s\n' "prepare-android-host: APP_SLUG and DEST_DIR are required" >&2
  exit 2
fi

case "$slug" in
  [a-z]*)
    ;;
  *)
    printf '%s\n' "prepare-android-host: invalid app slug: $slug" >&2
    exit 2
    ;;
esac
case "$slug" in
  *[!a-z0-9-]*|*-|*--*)
    printf '%s\n' "prepare-android-host: invalid app slug: $slug" >&2
    exit 2
    ;;
esac

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
host_source="$ROOT_DIR/apps/.host/android"
manifest="$ROOT_DIR/runtime/config/apps.manifest.json"

resolve_manifest_source_app_dir() {
  app_slug=$1
  [ -f "$manifest" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  repo=$(jq -r --arg slug "$app_slug" '.apps[] | select(.slug == $slug) | (.source.repo // "")' "$manifest")
  subdir=$(jq -r --arg slug "$app_slug" '.apps[] | select(.slug == $slug) | (.source.subdir // ".")' "$manifest")
  [ -n "$repo" ] || return 1
  case "$repo" in *"
"*|*"
"*|*"	"*) return 1 ;; esac
  case "$subdir" in ""|".") subdir=. ;; /*|*"
"*|*"
"*|*"	"*|*\\*|*..*|*//*) return 1 ;; esac
  case "$repo" in /*) repo_path=$repo ;; *) repo_path=$ROOT_DIR/$repo ;; esac
  [ -d "$repo_path" ] || return 1
  repo_abs=$(CDPATH= cd -- "$repo_path" && pwd -P)
  if [ "$subdir" = "." ]; then app_source=$repo_abs; else app_source=$repo_abs/$subdir; fi
  [ -d "$app_source" ] || return 1
  app_source_abs=$(CDPATH= cd -- "$app_source" && pwd -P)
  case "$app_source_abs" in "$repo_abs"|"$repo_abs"/*) ;; *) return 1 ;; esac
  printf '%s\n' "$app_source_abs"
}

if [ -d "$ROOT_DIR/apps/$slug" ]; then
  app_dir="$ROOT_DIR/apps/$slug"
elif app_dir=$(resolve_manifest_source_app_dir "$slug" 2>/dev/null); then
  :
else
  app_dir="$ROOT_DIR/apps/$slug"
fi

[ -d "$host_source" ] || {
  printf '%s\n' "prepare-android-host: Android host source not found" >&2
  exit 1
}
[ -d "$app_dir" ] || {
  printf '%s\n' "prepare-android-host: app not found: $slug" >&2
  exit 1
}

dest_parent=$(dirname "$dest")
dest_base=$(basename "$dest")
mkdir -p "$dest_parent"
dest_parent_abs=$(CDPATH= cd -- "$dest_parent" && pwd -P)
dest_abs="$dest_parent_abs/$dest_base"

case "$dest_abs" in
  "$ROOT_DIR/apps/.host/android"|"$ROOT_DIR/apps/.host/android"/*)
    printf '%s\n' "prepare-android-host: destination must be outside apps/.host/android" >&2
    exit 2
    ;;
esac

rm -rf "$dest_abs"
mkdir -p "$dest_abs"
cp -R "$host_source"/. "$dest_abs/"

rm -rf "$dest_abs/app/src/main/assets" "$dest_abs/app/src/main/res"/mipmap-*
sh "$ROOT_DIR/tools/release/stage-web-assets.sh" "$slug" "$dest_abs/app/src/main/assets"
sh "$ROOT_DIR/tools/icons/stage-android-launcher-icons.sh" "$app_dir" "$dest_abs/app/src/main/res"

printf 'android_project=%s\n' "$dest_abs"
