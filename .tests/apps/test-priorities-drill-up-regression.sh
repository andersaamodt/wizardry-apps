#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app="$root/.apps/priorities/index.html"

[ -f "$app" ] || {
  printf '%s\n' "priorities app file missing: $app" >&2
  exit 1
}

# Regression guard: Go Up visibility should be based on real parent availability.
grep -F "if (currentRoot === '.') {" "$app" >/dev/null
grep -F "up.classList.toggle('hidden', !hasParent);" "$app" >/dev/null

# Regression guard: drill-in should navigate directly to the clicked path.
grep -F "setRootAndRefresh({ persistRoot: false });" "$app" >/dev/null

# Regression guard: drill-up must have a parent-directory fallback.
grep -F "var parent = parentDirOfPath(currentRoot);" "$app" >/dev/null
grep -F "if (!parent || parent === currentRoot) {" "$app" >/dev/null
grep -F "nextRoot = parent;" "$app" >/dev/null

# Regression guard: drill-up should ask backend for canonical parent first.
grep -F "await runBackend(['parent', currentRoot]);" "$app" >/dev/null

printf '%s\n' "priorities drill-up regression tests passed"
