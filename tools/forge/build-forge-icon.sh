#!/bin/sh

# Resolve/build a macOS .icns file for App Forge.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: build-forge-icon.sh [--root ROOT_DIR] [--out ICON_FILE]

Ensures a valid .icns icon exists by selecting the first available source.
Priority:
  1) ROOT_DIR/apps/forge/assets/icons/meta/apple-master.png (converted to .icns)
  2) ROOT_DIR/apps/forge/assets/forge-icon.png (converted to .icns)
  3) ROOT_DIR/apps/forge/assets/icons/macos/forge.icns
  4) ROOT_DIR/apps/forge/assets/icons/meta/territory-master.png (converted to .icns)
  5) ROOT_DIR/apps/forge/assets/icons/meta/original-source.* (converted to .icns)
  6) macOS CoreTypes ToolbarCustomizeIcon.icns
  7) macOS CoreTypes ApplicationsFolderIcon.icns
  8) macOS CoreTypes GenericApplicationIcon.icns
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

forge_project_dir="$root/apps/forge"
icon_meta_dir="$forge_project_dir/assets/icons/meta"
config_path="$icon_meta_dir/icon-settings.conf"
apple_source="$root/apps/forge/assets/icons/meta/apple-master.png"

resolve_project_config_file() {
  project_dir=$1
  configured_path=${2-}

  [ -n "$configured_path" ] || return 1
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$configured_path" in
    *"$nl_char"*|*"$cr_char"*) return 1 ;;
  esac

  project_abs=$(CDPATH= cd -- "$project_dir" && pwd -P) || return 1

  case "$configured_path" in
    /*)
      candidate=$configured_path
      ;;
    *)
      rel_dir=$(dirname "$configured_path")
      rel_base=$(basename "$configured_path")
      rel_abs_dir=$(CDPATH= cd -- "$project_abs/$rel_dir" 2>/dev/null && pwd -P) || return 1
      candidate="$rel_abs_dir/$rel_base"
      ;;
  esac

  [ -f "$candidate" ] || return 1
  candidate_dir=$(dirname "$candidate")
  candidate_base=$(basename "$candidate")
  candidate_abs_dir=$(CDPATH= cd -- "$candidate_dir" 2>/dev/null && pwd -P) || return 1
  candidate_abs="$candidate_abs_dir/$candidate_base"

  case "$candidate_abs" in
    "$project_abs"/*)
      printf '%s\n' "$candidate_abs"
      return 0
      ;;
  esac

  return 1
}

if [ -f "$config_path" ]; then
  configured_apple=$(awk -F= '/^apple_master=/{print substr($0, index($0, "=") + 1); exit}' "$config_path" 2>/dev/null | tr -d '\r')
  resolved_apple=$(resolve_project_config_file "$forge_project_dir" "$configured_apple" 2>/dev/null || true)
  if [ -n "$resolved_apple" ]; then
    apple_source=$resolved_apple
  fi
fi

if [ -f "$apple_source" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-iconset.XXXXXX")
  iconset="${iconset_tmp}.iconset"
  mv "$iconset_tmp" "$iconset"
  trap 'rm -rf "$iconset"' EXIT INT TERM
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$apple_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$apple_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_file")"
  iconutil -c icns "$iconset" -o "$out_file"
  printf '%s\n' "built_icon=$out_file"
  printf '%s\n' "source_icon=$apple_source"
  exit 0
fi

png_icon="$root/apps/forge/assets/forge-icon.png"
if [ -f "$png_icon" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-iconset.XXXXXX")
  iconset="${iconset_tmp}.iconset"
  mv "$iconset_tmp" "$iconset"
  trap 'rm -rf "$iconset"' EXIT INT TERM
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$png_icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$png_icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_file")"
  iconutil -c icns "$iconset" -o "$out_file"
  printf '%s\n' "built_icon=$out_file"
  printf '%s\n' "source_icon=$png_icon"
  exit 0
fi

generated_icns="$root/apps/forge/assets/icons/macos/forge.icns"
if [ -f "$generated_icns" ]; then
  mkdir -p "$(dirname "$out_file")"
  cp "$generated_icns" "$out_file"
  printf '%s\n' "built_icon=$out_file"
  printf '%s\n' "source_icon=$generated_icns"
  exit 0
fi

territory_source="$icon_meta_dir/territory-master.png"
if [ -f "$config_path" ]; then
  configured_territory=$(awk -F= '/^territory_master=/{print substr($0, index($0, "=") + 1); exit}' "$config_path" 2>/dev/null | tr -d '\r')
  resolved_territory=$(resolve_project_config_file "$forge_project_dir" "$configured_territory" 2>/dev/null || true)
  if [ -n "$resolved_territory" ]; then
    territory_source=$resolved_territory
  fi
fi
if [ -f "$territory_source" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-iconset.XXXXXX")
  iconset="${iconset_tmp}.iconset"
  mv "$iconset_tmp" "$iconset"
  trap 'rm -rf "$iconset"' EXIT INT TERM
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$territory_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$territory_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_file")"
  iconutil -c icns "$iconset" -o "$out_file"
  printf '%s\n' "built_icon=$out_file"
  printf '%s\n' "source_icon=$territory_source"
  exit 0
fi

icon_source=''
if [ -f "$config_path" ]; then
  configured_icon=$(awk -F= '/^original_source=/{print substr($0, index($0, "=") + 1); exit}' "$config_path" 2>/dev/null | tr -d '\r')
  resolved_icon=$(resolve_project_config_file "$forge_project_dir" "$configured_icon" 2>/dev/null || true)
  if [ -n "$resolved_icon" ]; then
    icon_source=$resolved_icon
  fi
fi

if [ -z "$icon_source" ]; then
  for candidate in "$icon_meta_dir"/original-source.*; do
    [ -f "$candidate" ] || continue
    icon_source=$candidate
    break
  done
fi

if [ -n "$icon_source" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-iconset.XXXXXX")
  iconset="${iconset_tmp}.iconset"
  mv "$iconset_tmp" "$iconset"
  trap 'rm -rf "$iconset"' EXIT INT TERM
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  mkdir -p "$(dirname "$out_file")"
  iconutil -c icns "$iconset" -o "$out_file"
  printf '%s\n' "built_icon=$out_file"
  printf '%s\n' "source_icon=$icon_source"
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
  printf '%s\n' "build-forge-icon: no icon source found (missing territory/original/forge icon assets and system fallback icons)" >&2
  exit 1
}

mkdir -p "$(dirname "$out_file")"
cp "$source_icon" "$out_file"
printf '%s\n' "built_icon=$out_file"
printf '%s\n' "source_icon=$source_icon"
