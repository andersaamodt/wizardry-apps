#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
api="$root/.web/artificer/cgi/artificer-api"

assert_contains() {
  file=$1
  needle=$2
  if ! rg -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "assertion failed: expected to find '$needle' in $file" >&2
    exit 1
  fi
}

# Contract coverage: category helpers and preview action are present.
assert_contains "$api" "decision_prompt_requests_explicit_choice()"
assert_contains "$api" "decision_prompt_has_missing_required_inputs()"
assert_contains "$api" "decision_question_looks_required_input()"
assert_contains "$api" "decision_question_looks_risk_gate()"
assert_contains "$api" "decision_commands_trigger_external_gate()"
assert_contains "$api" "decision_request_category_for_prompt()"
assert_contains "$api" "should_allow_model_decision_request()"
assert_contains "$api" "decision_surface_preview)"
assert_contains "$api" "\"allow_decision_request\":%s"
assert_contains "$api" "\"signals\":{\"explicit_choice\":%s,\"missing_required_inputs\":%s,\"risk_gate_question\":%s,\"external_commands\":%s}"
assert_contains "$api" "\"explicit-choice\""
assert_contains "$api" "\"required-input-missing\""
assert_contains "$api" "\"external-action-gate\""
assert_contains "$api" "\"risk-acknowledgement\""

# Contract coverage: loop integrates category-aware handling and fallback surfacing.
assert_contains "$api" "decision_surface_category=\"none\""
assert_contains "$api" 'decision_surface_category=$(decision_request_category_for_prompt "$augmented_user_prompt" "$decision_question" "$run_mode" "$commands_text")'
assert_contains "$api" 'if ! should_allow_model_decision_request "$augmented_user_prompt" "$decision_question" "$run_mode" "$commands_text"; then'
assert_contains "$api" "decision_surface_category=\"external-action-gate\""
assert_contains "$api" "decision_surface_category=\"required-input-missing\""
assert_contains "$api" 'state_set "$state_file" "blocking" "decision required (${decision_surface_category})"'

printf '%s\n' "artificer decision-surfacing contract tests passed"
