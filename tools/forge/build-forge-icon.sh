#!/bin/sh

# Resolve/build a macOS .icns file for Wizardry Forge.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: build-forge-icon.sh [--root ROOT_DIR] [--out ICON_FILE]

Ensures a valid .icns icon exists by selecting the first available source.
Priority:
  1) ROOT_DIR/.apps/forge/assets/forge.icns
  2) macOS CoreTypes ToolbarCustomizeIcon.icns
  3) macOS CoreTypes ApplicationsFolderIcon.icns
  4) macOS CoreTypes GenericApplicationIcon.icns
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)

root=$DEFAULT_ROOT
out_file=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root=${2-}
      [ -n "$root" ] || {
        printf '%s\n' "build-forge-icon: --root requires ROOT_DIR" >&2
        exit 2
      }
      shift 2
      ;;
    --out)
      out_file=${2-}
      [ -n "$out_file" ] || {
        printf '%s\n' "build-forge-icon: --out requires ICON_FILE" >&2
        exit 2
      }
      shift 2
      ;;
    *)
      printf '%s\n' "build-forge-icon: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

[ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ] || {
  printf '%s\n' "build-forge-icon: macOS required" >&2
  exit 1
}

if [ -z "$out_file" ]; then
  out_file="$root/.apps/forge/assets/forge.icns"
fi

source_icon=''
for candidate in \
  "$root/.apps/forge/assets/forge.icns" \
  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns" \
  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns" \
  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"; do
  if [ -f "$candidate" ]; then
    source_icon=$candidate
    break
  fi
done

[ -n "$source_icon" ] || {
  printf '%s\n' "build-forge-icon: no .icns source icon found" >&2
  exit 1
}

if [ "$source_icon" = "$out_file" ]; then
  printf '%s\n' "built_icon=$out_file"
  exit 0
fi

mkdir -p "$(dirname "$out_file")"
cp "$source_icon" "$out_file"
printf '%s\n' "built_icon=$out_file"
printf '%s\n' "source_icon=$source_icon"
