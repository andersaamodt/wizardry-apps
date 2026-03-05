#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
api="$root/web/artificer/cgi/artificer-api"

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
assert_contains "$api" "decision_commands_trigger_destructive_gate()"
assert_contains "$api" "decision_request_category_for_prompt()"
assert_contains "$api" "should_allow_model_decision_request()"
assert_contains "$api" "decision_surface_preview)"
assert_contains "$api" "\"allow_decision_request\":%s"
assert_contains "$api" "\"signals\":{\"explicit_choice\":%s,\"missing_required_inputs\":%s,\"risk_gate_question\":%s,\"external_commands\":%s,\"destructive_commands\":%s}"
assert_contains "$api" "\"explicit-choice\""
assert_contains "$api" "\"required-input-missing\""
assert_contains "$api" "\"external-action-gate\""
assert_contains "$api" "\"destructive-action-gate\""
assert_contains "$api" "\"risk-acknowledgement\""
assert_contains "$api" "incident response|security incident|breach response|forensics|containment|compromise"
assert_contains "$api" "performance test|load test|benchmark|perf regression|latency optimization"
assert_contains "$api" "\\b(deploy|rollout|hotfix|rollback)\\b"
assert_contains "$api" "\\brelease\\b"
assert_contains "$api" "\\b(deploy|ship|publish|promote|launch|go[- ]live)\\b"
assert_contains "$api" "legal|compliance|privacy|pii|gdpr|hipaa|waiver|policy exception"
assert_contains "$api" "<<[^>]{2,}>>"
assert_contains "$api" "\$\{[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD|CRED|ID|URL|HOST|REGION|TENANT)[A-Z0-9_]*\}"
assert_contains "$api" "git[[:space:]]+push"
assert_contains "$api" "kubectl[[:space:]]+(apply|delete|patch|rollout|scale|replace)"
assert_contains "$api" "ansible-playbook"
assert_contains "$api" "helm[[:space:]]+(install|upgrade|uninstall|delete)"
assert_contains "$api" "aws[[:space:]]+(s3|ecs|eks|lambda|rds|cloudformation)"
assert_contains "$api" "kubectl[[:space:]]+replace[[:space:]]+--force"
assert_contains "$api" "aws[[:space:]]+rds[[:space:]]+delete-db-instance"
assert_contains "$api" "latency|throughput|slo|sla|target|baseline"

# Contract coverage: loop integrates category-aware handling and fallback surfacing.
assert_contains "$api" "decision_surface_category=\"none\""
assert_contains "$api" 'decision_surface_category=$(decision_request_category_for_prompt "$augmented_user_prompt" "$decision_question" "$run_mode" "$commands_text")'
assert_contains "$api" 'if ! should_allow_model_decision_request "$augmented_user_prompt" "$decision_question" "$run_mode" "$commands_text"; then'
assert_contains "$api" "decision_surface_category=\"external-action-gate\""
assert_contains "$api" "decision_surface_category=\"destructive-action-gate\""
assert_contains "$api" "decision_surface_category=\"required-input-missing\""
assert_contains "$api" 'state_set "$state_file" "blocking" "decision required (${decision_surface_category})"'

printf '%s\n' "artificer decision-surfacing contract tests passed"
