#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
api="$root/.web/artificer/cgi/artificer-api"

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

assert_contains "$api" "run_mode_policy_instructions()"
assert_contains "$api" "- prioritize continuity across turns: keep the active thread and user framing corrections intact."
assert_contains "$api" "- prefer insight and concrete distinctions over generic platitudes."
assert_contains "$api" "chat_history_text=\$(conversation_history \"\$conv_dir\" | sed -n '1,220p')"
assert_contains "$api" "Primary objective: answer the latest user message while preserving continuity with recent turns."
assert_contains "$api" "- treat the latest message as a refinement of the same thread, not a topic reset."
assert_contains "$api" "- if the user corrects framing, acknowledge the correction briefly and continue with the corrected framing."
assert_contains "$api" "- avoid procedural onboarding/setup assumptions unless the user explicitly asks for implementation steps."
assert_contains "$api" "Recent conversation (most recent last):"
assert_contains "$api" "chat_followup_hint=\"- user signaled the prior framing was off; restate the corrected framing before answering.\""
assert_contains "$api" "if { [ \"\$simple_direct_prompt\" != \"1\" ] || [ \"\$run_mode\" = \"chat\" ]; } && [ -n \"\$(trim \"\$attachment_context\")\" ]; then"
assert_contains "$api" "if { [ \"\$simple_direct_prompt\" != \"1\" ] || [ \"\$run_mode\" = \"chat\" ]; } && [ -n \"\$(trim \"\$web_context\")\" ]; then"

printf '%s\n' "artificer chat conversation intelligence contract tests passed"
