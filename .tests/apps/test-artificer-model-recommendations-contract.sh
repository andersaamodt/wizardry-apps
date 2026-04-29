#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
artificer_dir="$root/web/artificer"
[ -d "$artificer_dir" ] || {
  printf '%s\n' "skip: optional artificer app is not checked out"
  exit 0
}
api="$root/web/artificer/cgi/artificer-api"

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

assert_file() {
  file=$1
  [ -f "$file" ] || fail "missing file: $file"
}

assert_contains() {
  file=$1
  needle=$2
  if ! rg -F -- "$needle" "$file" >/dev/null 2>&1; then
    fail "missing expected text in $(basename "$file"): $needle"
  fi
}

assert_file "$api"

assert_contains "$api" "model_preference_score_for_mode()"
assert_contains "$api" "ranked_models_json_for_mode()"
assert_contains "$api" "emit_model_recommendations()"
assert_contains "$api" '"recommendations":{"chat":%s,"programming":%s}'
assert_contains "$api" "model_recommendations)"

printf '%s\n' "artificer model recommendations contract tests passed"
