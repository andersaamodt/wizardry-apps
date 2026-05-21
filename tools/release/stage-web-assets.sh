#!/bin/sh

# Stage app web assets for embedded desktop/mobile hosts.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: stage-web-assets.sh APP_SLUG DEST_DIR

Copies:
  apps/APP_SLUG/* -> DEST_DIR/app/
  apps/.host/shared/* -> DEST_DIR/app/.host/shared/
  app/themes -> symlink to templates/web/.themes
  runtime/core/include + runtime/core/src -> DEST_DIR/core/
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -ne 2 ]; then
  printf '%s\n' "stage-web-assets: APP_SLUG and DEST_DIR required" >&2
  exit 2
fi

slug=${1-}
dest=${2-}

if [ -z "$slug" ] || [ -z "$dest" ]; then
  printf '%s\n' "stage-web-assets: APP_SLUG and DEST_DIR required" >&2
  exit 2
fi

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

case "$slug" in
  [a-z]*)
    ;;
  *)
    printf '%s\n' "stage-web-assets: invalid app slug: $slug" >&2
    exit 2
    ;;
esac
case "$slug" in
  *[!a-z0-9-]*|*-|*--*)
    printf '%s\n' "stage-web-assets: invalid app slug: $slug" >&2
    exit 2
    ;;
esac

if has_line_break "$dest"; then
  printf '%s\n' "stage-web-assets: destination must not contain line breaks" >&2
  exit 2
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
shared_dir="$ROOT_DIR/apps/.host/shared"
theme_dir="$ROOT_DIR/templates/web/.themes"
manifest="$ROOT_DIR/runtime/config/apps.manifest.json"

dest_abs() {
  path=$1
  parent=$(dirname "$path")
  base=$(basename "$path")
  suffix=$base
  while [ ! -d "$parent" ]; do
    parent_base=$(basename "$parent")
    suffix=$parent_base/$suffix
    next_parent=$(dirname "$parent")
    [ "$next_parent" != "$parent" ] || return 1
    parent=$next_parent
  done
  parent_abs=$(CDPATH= cd -- "$parent" && pwd -P)
  printf '%s/%s\n' "$parent_abs" "$suffix"
}

paths_overlap() {
  first=$1
  second=$2
  case "$first" in
    "$second"|"$second"/*)
      return 0
      ;;
  esac
  case "$second" in
    "$first"|"$first"/*)
      return 0
      ;;
  esac
  return 1
}

resolve_manifest_source_app_dir() {
  app_slug=$1
  [ -f "$manifest" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  repo=$(jq -r --arg slug "$app_slug" '.apps[] | select(.slug == $slug) | (.source.repo // "")' "$manifest")
  subdir=$(jq -r --arg slug "$app_slug" '.apps[] | select(.slug == $slug) | (.source.subdir // ".")' "$manifest")
  [ -n "$repo" ] || return 1
  case "$repo" in
    *"
"*|*"
"*|*"	"*) return 1 ;;
  esac
  case "$subdir" in
    ""|".") subdir=. ;;
    /*|*"
"*|*"
"*|*"	"*|*\\*|*..*|*//*) return 1 ;;
  esac
  case "$repo" in
    /*) repo_path=$repo ;;
    *) repo_path=$ROOT_DIR/$repo ;;
  esac
  [ -d "$repo_path" ] || return 1
  repo_abs=$(CDPATH= cd -- "$repo_path" && pwd -P)
  if [ "$subdir" = "." ]; then
    app_source=$repo_abs
  else
    app_source=$repo_abs/$subdir
  fi
  [ -d "$app_source" ] || return 1
  app_source_abs=$(CDPATH= cd -- "$app_source" && pwd -P)
  case "$app_source_abs" in
    "$repo_abs"|"$repo_abs"/*) ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$app_source_abs"
}

if [ -d "$ROOT_DIR/apps/$slug" ]; then
  app_dir="$ROOT_DIR/apps/$slug"
elif app_dir=$(resolve_manifest_source_app_dir "$slug" 2>/dev/null); then
  :
else
  printf '%s\n' "stage-web-assets: app not found: $slug" >&2
  exit 1
fi

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

dest=$(dest_abs "$dest")
case "$dest" in
  /)
    printf '%s\n' "stage-web-assets: destination overlaps source: $dest" >&2
    exit 2
    ;;
esac
for source_dir in "$app_dir" "$shared_dir" "$theme_dir" "$ROOT_DIR/runtime/core"; do
  if paths_overlap "$dest" "$source_dir"; then
    printf '%s\n' "stage-web-assets: destination overlaps source: $dest" >&2
    exit 2
  fi
done

rm -rf "$dest"
mkdir -p "$dest/app" "$dest/app/.host/shared" "$dest/core"

for entry in "$app_dir"/* "$app_dir"/.[!.]* "$app_dir"/..?*; do
  [ -e "$entry" ] || continue
  base=$(basename "$entry")
  [ "$base" = "." ] && continue
  [ "$base" = ".." ] && continue
  [ "$base" = ".git" ] && continue
  [ "$base" = ".log" ] && continue
  [ "$base" = ".DS_Store" ] && continue
  [ "$base" = ".forge-source.lock" ] && continue
  [ "$base" = "themes" ] && continue
  cp -R "$entry" "$dest/app/"
done

ln -s "$theme_dir" "$dest/app/themes"
cp -R "$shared_dir"/. "$dest/app/.host/shared/"
cp -R "$ROOT_DIR/runtime/core/include" "$dest/core/include"
cp -R "$ROOT_DIR/runtime/core/src" "$dest/core/src"

printf '%s\n' "stage-web-assets: staged $slug -> $dest"
