#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
module_dir="$root/spells/.arcana/native-desktop-compilation"

[ -d "$module_dir" ] || {
  printf '%s\n' "native desktop compilation arcana module missing" >&2
  exit 1
}

find "$module_dir" -maxdepth 1 -type f ! -name '_*' | while IFS= read -r script || [ -n "$script" ]; do
  [ -n "$script" ] || continue
  sh -n "$script"
done
sh -n "$module_dir/_toolchain"

status=$("$module_dir/native-desktop-compilation-status")
printf '%s\n' "$status" | grep -E '^\[[ X]\] C compiler$' >/dev/null 2>&1 || {
  printf '%s\n' "native desktop status missing C compiler row" >&2
  exit 1
}
printf '%s\n' "$status" | grep -E '^\[[ X]\] Meson$' >/dev/null 2>&1 || {
  printf '%s\n' "native desktop status missing Meson row" >&2
  exit 1
}

menu_output=$(PATH=/nonexistent "$module_dir/native-desktop-compilation-menu")
printf '%s\n' "$menu_output" | grep -E '^\[[ X]\] C compiler$' >/dev/null 2>&1 || {
  printf '%s\n' "native desktop menu fallback did not print status rows" >&2
  exit 1
}

"$module_dir/install-appimagetool" --help | grep -F "Usage: install-appimagetool" >/dev/null 2>&1 || {
  printf '%s\n' "install-appimagetool help missing" >&2
  exit 1
}
"$module_dir/install-gtk4" --help | grep -F "Usage: install-gtk4" >/dev/null 2>&1 || {
  printf '%s\n' "install-gtk4 help missing" >&2
  exit 1
}
"$module_dir/install-webkitgtk" --help | grep -F "Usage: install-webkitgtk" >/dev/null 2>&1 || {
  printf '%s\n' "install-webkitgtk help missing" >&2
  exit 1
}

printf '%s\n' "native desktop compilation arcana tests passed"
