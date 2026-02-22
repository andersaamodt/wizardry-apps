#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/.apps/forge/index.html"
backend="$root/.apps/forge/scripts/forge-backend.sh"

[ -f "$ui" ] || {
  printf '%s\n' "forge ui file missing: $ui" >&2
  exit 1
}
[ -f "$backend" ] || {
  printf '%s\n' "forge backend file missing: $backend" >&2
  exit 1
}

# Regression guard: main Run action should launch compiled native bundle.
grep -F "var runModeRequest = 'bundle';" "$ui" >/dev/null
grep -F "built and launched from the compiled desktop app bundle." "$ui" >/dev/null

# Regression guard: Hosted Web target should expose runnable play behavior.
grep -F "if (targetId === 'hosted-web') {" "$ui" >/dev/null
grep -F "return true;" "$ui" >/dev/null
grep -F "hosted web entry opened." "$ui" >/dev/null
grep -F "id=\"action-run-menu\"" "$ui" >/dev/null
grep -F "id=\"action-run-webhost\"" "$ui" >/dev/null
grep -F "Serve web host" "$ui" >/dev/null
grep -F "runPipelineAction('serve-web-host')" "$ui" >/dev/null

# Backend hardening: auto should default to host to avoid stale-bundle ambiguity.
grep -F "run_mode=host" "$backend" >/dev/null
grep -F "cmd_run_desktop \"\${2-}\" \"\${3-}\" \"\${4-}\"" "$backend" >/dev/null

printf '%s\n' "forge run mode and hosted-web target tests passed"
