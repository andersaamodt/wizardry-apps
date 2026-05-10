#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
artificer_dir="$root/templates/web/artificer"
[ -d "$artificer_dir" ] || {
  printf '%s\n' "skip: optional artificer app is not checked out"
  exit 0
}
api="$root/templates/web/artificer/cgi/artificer-api"
backlog="$root/templates/web/artificer/INTELLIGENCE_BACKLOG.md"

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
  if ! rg -F "$needle" "$file" >/dev/null 2>&1; then
    fail "missing expected text in $(basename "$file"): $needle"
  fi
}

assert_file "$api"
assert_file "$backlog"

# Mode policies for security specialist modes.
assert_contains "$api" "run_mode_policy_instructions()"
assert_contains "$api" "prioritize adversarial testing depth: enumerate exploit paths, abuse cases, and boundary failures."
assert_contains "$api" "report findings with impact level, evidence, and remediation status."
assert_contains "$api" "produce auditable findings with severity, evidence, and mitigation guidance."

# Structured findings enforcement helpers.
assert_contains "$api" "is_security_specialist_mode()"
assert_contains "$api" "security_report_has_structured_findings()"
assert_contains "$api" "security_mode_normalize_assistant_output()"
assert_contains "$api" 'Security Findings Report ($run_mode_value):'
assert_contains "$api" 'Severity: $severity_line'
assert_contains "$api" 'Evidence: $evidence_line'
assert_contains "$api" 'Remediation: $remediation_line'

# Synthesis and final response path enforcement for pentest/security-audit.
assert_contains "$api" "Write a structured security findings report that includes:"
assert_contains "$api" "each finding must include Severity, Evidence, Remediation, and Status"
assert_contains "$api" 'assistant_output=$(security_mode_normalize_assistant_output'
assert_contains "$api" 'if [ "$run_mode" = "pentest" ] || [ "$run_mode" = "security-audit" ]; then'

# Documentation/backlog references for this upgrade area.
assert_contains "$backlog" "INT-009 Security specialist modes"
assert_contains "$backlog" 'Run-mode picker includes a `More modes` expander'

printf '%s\n' "artificer security modes contract tests passed"
