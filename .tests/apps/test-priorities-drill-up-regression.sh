#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app="$root/.apps/priorities/index.html"

[ -f "$app" ] || {
  printf '%s\n' "priorities app file missing: $app" >&2
  exit 1
}

# Regression guard: Go Up must stay visible when a real parent exists.
grep -F "up.classList.toggle('hidden', state.drillStack.length === 0 && !hasParent);" "$app" >/dev/null

# Regression guard: drill-in should record the active root, not only raw input text.
grep -F "state.drillStack.push(currentRoot);" "$app" >/dev/null

# Regression guard: drill-up must have a parent-directory fallback when stack is empty.
grep -F "var parent = parentDirOfPath(currentRoot);" "$app" >/dev/null
grep -F "if (!parent || parent === currentRoot) {" "$app" >/dev/null
grep -F "previous = parent;" "$app" >/dev/null

# Regression guard: stale stack entries matching current root should be skipped.
grep -F "if (!candidate || candidate === currentRoot) {" "$app" >/dev/null

# Regression guard: drill-up should ask backend for canonical parent first.
grep -F "await runBackend(['parent', currentRoot]);" "$app" >/dev/null

printf '%s\n' "priorities drill-up regression tests passed"
