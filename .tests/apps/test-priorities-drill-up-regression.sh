#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app="$root/.apps/priorities/index.html"

[ -f "$app" ] || {
  printf '%s\n' "priorities app file missing: $app" >&2
  exit 1
}

# Regression guard: Go Up visibility should be based on real parent availability.
grep -F "var nextRoot = parentNavPath(currentRoot);" "$app" >/dev/null
grep -F "up.classList.toggle('hidden', !nextRoot || nextRoot === currentRoot);" "$app" >/dev/null

# Regression guard: drill-in should navigate directly to the clicked path.
grep -F "setRootAndRefresh({ persistRoot: false });" "$app" >/dev/null

# Regression guard: local parent navigation must support dot paths.
grep -F "function parentNavPath(path) {" "$app" >/dev/null
grep -F "if (p === '.') {" "$app" >/dev/null
grep -F "return '..';" "$app" >/dev/null
grep -F "if (p === '..') {" "$app" >/dev/null
grep -F "return '../..';" "$app" >/dev/null

# Regression guard: drill-up should use local nav-parent and avoid no-op.
grep -F "if (!nextRoot || nextRoot === currentRoot) {" "$app" >/dev/null

printf '%s\n' "priorities drill-up regression tests passed"
