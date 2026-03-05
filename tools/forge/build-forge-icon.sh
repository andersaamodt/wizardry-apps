#!/bin/sh

# Resolve/build a macOS .icns file for App Forge.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: build-forge-icon.sh [--root ROOT_DIR] [--out ICON_FILE]

Ensures a valid .icns icon exists by selecting the first available source.
Priority:
  1) ROOT_DIR/apps/forge/assets/forge-icon.png (converted to .icns)
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
  out_file="$root/_tmp/forge-build-cache/forge.icns"
fi

png_icon="$root/apps/forge/assets/forge-icon.png"
if [ -f "$png_icon" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  iconset=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-iconset.XXXXXX")
  trap 'rm -rf "$iconset"' EXIT INT TERM
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$png_icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$png_icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_file")"
  iconutil -c icns "$iconset" -o "$out_file"
  printf '%s\n' "built_icon=$out_file"
  printf '%s\n' "source_icon=$png_icon"
  exit 0
fi

source_icon=''
for candidate in \
  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns" \
  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns" \
  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"; do
  if [ -f "$candidate" ]; then
    source_icon=$candidate
    break
  fi
done

[ -n "$source_icon" ] || {
  printf '%s\n' "build-forge-icon: no icon source found (missing forge-icon.png and system fallback icons)" >&2
  exit 1
}

mkdir -p "$(dirname "$out_file")"
cp "$source_icon" "$out_file"
printf '%s\n' "built_icon=$out_file"
printf '%s\n' "source_icon=$source_icon"
