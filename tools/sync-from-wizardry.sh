#!/bin/sh

set -eu

usage() {
  printf '%s\n' "usage: sync-from-wizardry.sh SOURCE_DIR [TARGET_DIR]" >&2
}

fail() {
  printf '%s\n' "sync-from-wizardry: $*" >&2
  exit 1
}

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in
    *"$nl_char"*|*"$cr_char"*) return 0 ;;
  esac
  return 1
}

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

source_arg=${1-}
[ -n "$source_arg" ] || {
  usage
  exit 2
}

target_arg=${2-$repo_root}

has_line_break "$source_arg" && fail "source directory must not contain line breaks"
has_line_break "$target_arg" && fail "target directory must not contain line breaks"

[ -d "$source_arg" ] || fail "source directory not found: $source_arg"
[ -d "$target_arg" ] || fail "target directory not found: $target_arg"

source_dir=$(CDPATH= cd -- "$source_arg" && pwd -P)
target_dir=$(CDPATH= cd -- "$target_arg" && pwd -P)

[ "$source_dir" != "$target_dir" ] || fail "source and target must be different directories"

case "$target_dir" in
  "$source_dir"/*)
    fail "target directory must not be inside source directory"
    ;;
esac

case "$source_dir" in
  "$target_dir"/*)
    fail "source directory must not be inside target directory"
    ;;
esac

copy_dir_contents() {
  src_dir=$1
  dest_dir=$2
  archive=$(mktemp "${TMPDIR:-/tmp}/wizardry-sync.XXXXXX")

  mkdir -p "$dest_dir"
  if ! (cd "$src_dir" && tar -cf "$archive" .); then
    rm -f "$archive"
    return 1
  fi
  if ! (cd "$dest_dir" && tar -xf "$archive"); then
    rm -f "$archive"
    return 1
  fi
  rm -f "$archive"
}

copy_path() {
  rel_path=$1
  src_path="$source_dir/$rel_path"
  dest_path="$target_dir/$rel_path"

  [ -e "$src_path" ] || {
    printf 'skipped=%s\n' "$rel_path"
    return 0
  }

  if [ -d "$src_path" ] && [ ! -L "$src_path" ]; then
    copy_dir_contents "$src_path" "$dest_path" || fail "failed to copy $rel_path"
  else
    mkdir -p "$(dirname "$dest_path")"
    cp -p "$src_path" "$dest_path" || fail "failed to copy $rel_path"
  fi

  SYNCED_ANY=1
  printf 'synced=%s\n' "$rel_path"
}

sync_apps() {
  src_apps="$source_dir/apps"
  [ -d "$src_apps" ] || {
    printf '%s\n' "skipped=apps"
    return 0
  }

  copied=0
  for src_entry in "$src_apps"/* "$src_apps"/.[!.]* "$src_apps"/..?*; do
    [ -e "$src_entry" ] || continue
    base_name=${src_entry##*/}
    [ "$base_name" = ".host" ] && continue
    copy_path "apps/$base_name"
    copied=1
  done

  [ "$copied" = 1 ] || printf '%s\n' "skipped=apps"
}

SYNCED_ANY=0

copy_path "spells/web"
copy_path "spells/.arcana/web-wizardry"
copy_path "web"
sync_apps
copy_path ".tests/web"
copy_path ".tests/.arcana/web-wizardry"

[ "$SYNCED_ANY" = 1 ] || fail "source did not contain any importable wizardry app paths"

printf 'source=%s\n' "$source_dir"
printf 'target=%s\n' "$target_dir"
