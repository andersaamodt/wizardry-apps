#!/bin/sh

# Export desktop artifacts for Wizardry Godot tools.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: export-godot-desktop.sh [OUTPUT_DIR] [TARGET]

TARGET:
  all   export Linux + macOS presets (default)
  linux export Linux/X11 preset only
  macos export macOS preset only

Requires:
  - godot4 or godot CLI in PATH (or GODOT_BIN)
  - export templates installed for selected presets
USAGE
  exit 0
  ;;
esac

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
out_dir=${1:-$ROOT_DIR/dist/godot}
target=${2-all}
project_dir="$ROOT_DIR/templates/godot/tools/wizardry-lab"
presets_src="$ROOT_DIR/templates/godot/export-presets/export_presets.cfg"

case "$target" in
  all|linux|macos) ;;
  *)
    printf '%s\n' "export-godot-desktop: invalid TARGET: $target" >&2
    exit 2
    ;;
esac

if [ -n "${GODOT_BIN-}" ] && [ -x "$GODOT_BIN" ]; then
  engine="$GODOT_BIN"
elif command -v godot4 >/dev/null 2>&1; then
  engine=$(command -v godot4)
elif command -v godot >/dev/null 2>&1; then
  engine=$(command -v godot)
else
  printf '%s\n' "export-godot-desktop: godot4/godot not found (set GODOT_BIN)" >&2
  exit 1
fi

[ -f "$project_dir/project.godot" ] || {
  printf '%s\n' "export-godot-desktop: missing project.godot at $project_dir" >&2
  exit 1
}

[ -f "$presets_src" ] || {
  printf '%s\n' "export-godot-desktop: missing export presets: $presets_src" >&2
  exit 1
}

mkdir -p "$out_dir/linux" "$out_dir/macos"
cp "$presets_src" "$project_dir/export_presets.cfg"

export_linux() {
  linux_bin="$out_dir/linux/wizardry-lab.x86_64"
  "$engine" --headless --path "$project_dir" --export-release "Linux/X11" "$linux_bin"

  [ -f "$linux_bin" ] || {
    printf '%s\n' "export-godot-desktop: linux export missing binary" >&2
    exit 1
  }

  [ -f "$out_dir/linux/wizardry-lab.pck" ] || {
    printf '%s\n' "export-godot-desktop: linux export missing pck" >&2
    exit 1
  }

  chmod +x "$linux_bin"
  tar -czf "$out_dir/wizardry-godot-linux.tar.gz" -C "$out_dir" linux
}

export_macos() {
  mac_app="$out_dir/macos/WizardryLab.app"
  "$engine" --headless --path "$project_dir" --export-release "macOS" "$mac_app"

  [ -d "$mac_app" ] || {
    printf '%s\n' "export-godot-desktop: macOS export missing .app bundle" >&2
    exit 1
  }

  ls -1 "$mac_app/Contents/MacOS"/* >/dev/null 2>&1 || {
    printf '%s\n' "export-godot-desktop: macOS export missing executable" >&2
    exit 1
  }

  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --sequesterRsrc --keepParent "$mac_app" "$out_dir/wizardry-godot-macos.zip"
  elif command -v zip >/dev/null 2>&1; then
    (cd "$out_dir/macos" && zip -qr "$out_dir/wizardry-godot-macos.zip" "$(basename "$mac_app")")
  else
    printf '%s\n' "export-godot-desktop: need ditto or zip for macOS packaging" >&2
    exit 1
  fi
}

case "$target" in
  linux)
    export_linux
    ;;
  macos)
    export_macos
    ;;
  all)
    export_linux
    export_macos
    ;;
esac

manifest="$out_dir/export-manifest.txt"
{
  printf 'engine=%s\n' "$engine"
  printf 'target=%s\n' "$target"
  printf 'project=%s\n' "$project_dir"
  printf 'artifacts:\n'
  find "$out_dir" -maxdepth 2 -type f | sort
} > "$manifest"

printf '%s\n' "godot desktop export artifacts prepared in $out_dir"
