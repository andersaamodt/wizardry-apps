#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"
ui="$root/apps/forge/index.html"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable: $backend" >&2
  exit 1
}

[ -f "$ui" ] || {
  printf '%s\n' "forge ui file missing: $ui" >&2
  exit 1
}

assert_contains() {
  file=$1
  needle=$2
  if ! grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected contract text in $file: $needle" >&2
    exit 1
  fi
}

case "$(uname -s 2>/dev/null || printf unknown)" in
  Darwin|Linux)
    list_out=$("$backend" list-apps "$root")
    if printf '%s\n' "$list_out" | awk -F '	' '$1 == "priorities-mobile" { found=1 } END { exit found ? 0 : 1 }'; then
      printf '%s\n' "Forge catalog should not offer mobile-only apps on desktop hosts" >&2
      exit 1
    fi
    ;;
esac

assert_contains "$backend" 'targets_include_host "$targets" || continue'
assert_contains "$ui" 'function appSupportsCurrentHost(app)'
assert_contains "$ui" 'return !!row.id && appSupportsCurrentHost(row);'
assert_contains "$ui" 'return appSupportsCurrentHost(app);'

printf '%s\n' "forge host-target catalog contracts passed"
