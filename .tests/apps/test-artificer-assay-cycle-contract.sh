#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
artificer_dir="$root/web/artificer"
[ -d "$artificer_dir" ] || {
  printf '%s\n' "skip: optional artificer app is not checked out"
  exit 0
}
script="$root/web/artificer/scripts/assay-cycle.sh"
fixtures="$root/.tests/apps/fixtures/artificer-decision-surfacing-fixtures.psv"

assert_contains() {
  file=$1
  needle=$2
  if ! rg -F -- "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "assertion failed: expected to find '$needle' in $file" >&2
    exit 1
  fi
}

if [ ! -f "$script" ]; then
  printf '%s\n' "assay-cycle script missing: $script" >&2
  exit 1
fi
if [ ! -f "$fixtures" ]; then
  printf '%s\n' "decision fixtures missing: $fixtures" >&2
  exit 1
fi

assert_contains "$script" "assay-cycle.sh mentor"
assert_contains "$script" "mentor_series()"
assert_contains "$script" "action=decision_surface_preview"
assert_contains "$script" "DECISION_FIXTURE_FILE="
assert_contains "$script" "--fixtures"
assert_contains "$script" "cycle_metrics_for_file()"
assert_contains "$script" "decision_metrics_for_file()"
assert_contains "$script" "Assay execution scope:"
assert_contains "$script" 'case "$mode" in'
assert_contains "$script" "mentor)"

# Ensure the default task panel remains a substantial challenge set.
task_count=$(awk -F '\t' '
  /^task_table\(\)/ { in_table=1; next }
  in_table && /^EOF$/ { in_table=0 }
  in_table && NF >= 4 { count += 1 }
  END { print count + 0 }
' "$script")
if [ "$task_count" -lt 12 ]; then
  printf '%s\n' "expected at least 12 assay tasks, found $task_count" >&2
  exit 1
fi

printf '%s\n' "artificer assay-cycle contract tests passed"
