#!/bin/sh

# Sync selected web/apps surfaces from wizardry into wizardry-apps.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: sync-from-wizardry.sh [SOURCE_DIR]

Synchronizes selected paths from wizardry into this repository.
Default SOURCE_DIR: $HOME/.wizardry

Imported paths:
  spells/web
  spells/.arcana/web-wizardry
  .web
  .apps
  .tests/web
  .tests/.arcana/web-wizardry
USAGE
  exit 0
  ;;
esac

set -eu

src_root=${1:-$HOME/.wizardry}
dst_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)

if [ ! -d "$src_root" ]; then
  printf '%s\n' "sync-from-wizardry: source not found: $src_root" >&2
  exit 1
fi

sync_one() {
  rel=$1
  src="$src_root/$rel"
  dst="$dst_root/$rel"

  if [ ! -e "$src" ]; then
    printf '%s\n' "sync-from-wizardry: skipping missing path: $rel"
    return
  fi

  dst_parent=$(dirname "$dst")
  mkdir -p "$dst_parent"

  if command -v rsync >/dev/null 2>&1; then
    if [ -d "$src" ]; then
      mkdir -p "$dst"
      if [ "$rel" = ".apps" ]; then
        # Keep wizardry-apps native host assets in-repo.
        rsync -a --delete --exclude '.host/' "$src/" "$dst/"
      else
        rm -rf "$dst"
        mkdir -p "$dst"
        rsync -a "$src/" "$dst/"
      fi
    else
      rsync -a "$src" "$dst"
    fi
  else
    if [ -d "$src" ]; then
      mkdir -p "$dst"
      if [ "$rel" = ".apps" ]; then
        for entry in "$src"/* "$src"/.*; do
          [ -e "$entry" ] || continue
          name=$(basename "$entry")
          case "$name" in
            .|..|.host) continue ;;
          esac
          rm -rf "$dst/$name"
          cp -R "$entry" "$dst/$name"
        done
      else
        rm -rf "$dst"
        mkdir -p "$dst"
        cp -R "$src"/. "$dst"/
      fi
    else
      rm -f "$dst"
      cp "$src" "$dst"
    fi
  fi

  printf '%s\n' "sync-from-wizardry: synced $rel"
}

sync_one "spells/web"
sync_one "spells/.arcana/web-wizardry"
sync_one ".web"
sync_one ".apps"
sync_one ".tests/web"
sync_one ".tests/.arcana/web-wizardry"

printf '%s\n' "sync-from-wizardry: complete"
