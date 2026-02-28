#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
api="$root/.web/artificer/cgi/artificer-api"
mode_runtime_lib="$root/.web/artificer/cgi/mode-runtime-lib.sh"
ui_js="$root/.web/artificer/static/artificer-app.js"
page_md="$root/.web/artificer/pages/index.md"
page_html="$root/.web/artificer/pages/index.html"
style="$root/.web/artificer/static/style.css"
readme="$root/.web/artificer/README.md"
backlog="$root/.web/artificer/INTELLIGENCE_BACKLOG.md"

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
assert_file "$mode_runtime_lib"
assert_file "$ui_js"
assert_file "$page_md"
assert_file "$page_html"
assert_file "$style"
assert_file "$readme"
assert_file "$backlog"

# Backend contracts: failure taxonomy and manual proposal governance exist.
assert_contains "$mode_runtime_lib" "mr_failure_taxonomy_record()"
assert_contains "$mode_runtime_lib" "mr_failure_taxonomy_state_json()"
assert_contains "$mode_runtime_lib" "controller-stagnation"
assert_contains "$mode_runtime_lib" "mr_improvement_proposal_generate_from_taxonomy_json()"
assert_contains "$mode_runtime_lib" "mr_improvement_proposal_set_status()"
assert_contains "$mode_runtime_lib" "manual_confirm=1 is required for apply"
assert_contains "$mode_runtime_lib" "mr_failure_taxonomy_dir()"
assert_contains "$mode_runtime_lib" "mr_improvement_proposals_dir()"
assert_contains "$mode_runtime_lib" "mr_controller_variants_state_json()"
assert_contains "$mode_runtime_lib" "mr_controller_variant_create_from_proposal()"
assert_contains "$mode_runtime_lib" "mr_controller_variant_select_for_run()"
assert_contains "$mode_runtime_lib" "mr_controller_variant_record_run()"
assert_contains "$mode_runtime_lib" "mr_quality_scorecard_record_entry()"
assert_contains "$mode_runtime_lib" "mr_quality_scorecard_state_json()"
assert_contains "$mode_runtime_lib" "mr_quality_scorecard_maybe_raise_regression_proposal()"
assert_contains "$mode_runtime_lib" "mr_failure_taxonomy_recent_summary_text()"
assert_contains "$mode_runtime_lib" "mr_quality_scorecard_recent_summary_text()"
assert_contains "$mode_runtime_lib" "mr_failure_taxonomy_recent_guardrails_text()"
assert_contains "$mode_runtime_lib" "mr_quality_scorecard_guardrail_text()"
assert_contains "$mode_runtime_lib" "mr_runtime_learning_guardrails_text()"
assert_contains "$mode_runtime_lib" "manual_confirm=1 is required for promote"
assert_contains "$mode_runtime_lib" "manual_confirm=1 is required for rollback"
assert_contains "$mode_runtime_lib" "\"controller_variants\":%s"
assert_contains "$mode_runtime_lib" "\"quality_scorecard\":%s"

assert_contains "$api" "failure_taxonomy_state)"
assert_contains "$api" "improvement_proposals_state)"
assert_contains "$api" "improvement_proposal_generate)"
assert_contains "$api" "improvement_proposal_decide)"
assert_contains "$api" "improvement_proposal_create)"
assert_contains "$api" "controller_variants_state)"
assert_contains "$api" "controller_variant_promote)"
assert_contains "$api" "controller_variant_rollback)"
assert_contains "$api" "quality_scorecard_state)"
assert_contains "$api" 'mr_failure_taxonomy_record "$action_text"'
assert_contains "$api" "mr_controller_variant_select_for_run"
assert_contains "$api" "mr_controller_variant_record_run"
assert_contains "$api" "stagnation_repeat_count=0"
assert_contains "$api" "Loop stagnation detected; injecting anti-repeat guardrail."
assert_contains "$api" 'iteration-$iteration:loop-stagnation'
assert_contains "$api" 'runtime_failure_summary=$(mr_failure_taxonomy_recent_summary_text "6")'
assert_contains "$api" 'runtime_quality_summary=$(mr_quality_scorecard_recent_summary_text "8")'
assert_contains "$api" 'runtime_guardrails=$(mr_runtime_learning_guardrails_text)'
assert_contains "$api" "Runtime learning signals:"
assert_contains "$api" '- failure_taxonomy: $runtime_failure_summary'
assert_contains "$api" '- quality_scorecard: $runtime_quality_summary'
assert_contains "$api" "Runtime adaptation guardrails:"
assert_contains "$api" '- $runtime_guardrails'

# Frontend contracts: new state normalization and UI actions exist.
assert_contains "$ui_js" "modeRuntimeFailureTaxonomy: document.getElementById(\"mode-runtime-failure-taxonomy\")"
assert_contains "$ui_js" "modeRuntimeImprovementProposals: document.getElementById(\"mode-runtime-improvement-proposals\")"
assert_contains "$ui_js" "modeRuntimeControllerVariants: document.getElementById(\"mode-runtime-controller-variants\")"
assert_contains "$ui_js" "modeRuntimeQualityScorecard: document.getElementById(\"mode-runtime-quality-scorecard\")"
assert_contains "$ui_js" "function modeRuntimeGenerateImprovementProposals()"
assert_contains "$ui_js" "function modeRuntimeDecideImprovementProposal(proposalId, decision, noteText)"
assert_contains "$ui_js" "function modeRuntimePromoteControllerVariant(variantId)"
assert_contains "$ui_js" "function modeRuntimeRollbackControllerVariant()"
assert_contains "$ui_js" "data-action='mode-runtime-proposal-generate'"
assert_contains "$ui_js" "data-action='mode-runtime-proposal-decision'"
assert_contains "$ui_js" "data-action='mode-runtime-controller-promote'"
assert_contains "$ui_js" "data-action='mode-runtime-controller-rollback'"
assert_contains "$ui_js" "manual_apply_only"
assert_contains "$ui_js" "failure_taxonomy"
assert_contains "$ui_js" "improvement_proposals"
assert_contains "$ui_js" "controller_variants"
assert_contains "$ui_js" "quality_scorecard"

# Settings page contracts: taxonomy/proposal containers are present in source + rendered html.
assert_contains "$page_md" "id=\"mode-runtime-failure-taxonomy\""
assert_contains "$page_md" "id=\"mode-runtime-improvement-proposals\""
assert_contains "$page_md" "id=\"mode-runtime-controller-variants\""
assert_contains "$page_md" "id=\"mode-runtime-quality-scorecard\""
assert_contains "$page_html" "id=\"mode-runtime-failure-taxonomy\""
assert_contains "$page_html" "id=\"mode-runtime-improvement-proposals\""
assert_contains "$page_html" "id=\"mode-runtime-controller-variants\""
assert_contains "$page_html" "id=\"mode-runtime-quality-scorecard\""

# Styling contracts for new settings blocks.
assert_contains "$style" ".mode-runtime-failure-taxonomy"
assert_contains "$style" ".mode-runtime-improvement-proposals"
assert_contains "$style" ".mode-runtime-controller-variants"
assert_contains "$style" ".mode-runtime-quality-scorecard"
assert_contains "$style" ".mode-runtime-proposal-item"

# Documentation contracts.
assert_contains "$readme" "failure_taxonomy_state"
assert_contains "$readme" "improvement_proposal_generate"
assert_contains "$readme" "controller_variants_state"
assert_contains "$readme" "controller_variant_promote"
assert_contains "$readme" "quality_scorecard_state"
assert_contains "$backlog" "INT-001 Failure taxonomy persistence"
assert_contains "$backlog" "INT-003 Contained self-improvement proposals"
assert_contains "$backlog" "INT-008 Multi-run learning loop for controller prompts"
assert_contains "$backlog" "INT-010 Quality scorecard automation"

printf '%s\n' "artificer mode-runtime learning contract tests passed"
