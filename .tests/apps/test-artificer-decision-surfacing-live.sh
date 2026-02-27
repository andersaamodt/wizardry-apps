#!/bin/sh
set -eu

api_url=${ARTIFICER_TEST_API_URL:-http://localhost:8082/cgi/artificer-api}

if ! curl -fsS "$api_url?action=state" >/dev/null 2>&1; then
  printf '%s\n' "artificer decision-surfacing live tests skipped (api unavailable: $api_url)"
  exit 0
fi

post_preview() {
  prompt=$1
  question=$2
  run_mode=$3
  commands=$4
  curl -fsS -X POST "$api_url" \
    --data-urlencode action=decision_surface_preview \
    --data-urlencode prompt="$prompt" \
    --data-urlencode question="$question" \
    --data-urlencode run_mode="$run_mode" \
    --data-urlencode commands="$commands"
}

assert_preview_case() {
  case_name=$1
  expected_category=$2
  prompt=$3
  question=$4
  run_mode=$5
  commands=$6
  response=$(post_preview "$prompt" "$question" "$run_mode" "$commands")
  actual_category=$(printf '%s' "$response" | jq -r '.category // ""')
  allow=$(printf '%s' "$response" | jq -r '.allow_decision_request')
  if [ "$actual_category" != "$expected_category" ]; then
    printf '%s\n' "preview case '$case_name' expected category '$expected_category' but got '$actual_category'" >&2
    exit 1
  fi
  if [ "$expected_category" = "none" ]; then
    if [ "$allow" != "false" ]; then
      printf '%s\n' "preview case '$case_name' expected allow_decision_request=false" >&2
      exit 1
    fi
  else
    if [ "$allow" != "true" ]; then
      printf '%s\n' "preview case '$case_name' expected allow_decision_request=true" >&2
      exit 1
    fi
  fi
}

assert_preview_case \
  "explicit-choice" \
  "explicit-choice" \
  "We have two migration plans. Which one should I use?" \
  "Which migration strategy should I apply now?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "required-input-missing" \
  "required-input-missing" \
  "Deploy this using <PROD_API_KEY> and <PROD_HOST>; values are not provided yet." \
  "Which production host and API key should I use?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "external-action-gate" \
  "external-action-gate" \
  "Create a launch plan and run outreach checks." \
  "Do you approve external network actions now?" \
  "assistant" \
  "curl https://example.com/health"

assert_preview_case \
  "risk-acknowledgement" \
  "risk-acknowledgement" \
  "Proceed with irreversible data deletion if needed." \
  "Do you approve deleting production rows now?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none" \
  "none" \
  "Refactor this module and continue autonomously." \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-optional-near-miss" \
  "none" \
  "Enable optional caching for this endpoint and continue autonomously." \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-choice-words-without-choice-question" \
  "none" \
  "Preserve optional behavior and keep preferred defaults stable while refactoring." \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-risk-phrase-without-risk-question" \
  "none" \
  "Proceed with this refactor now and keep changes minimal." \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-should-i-without-options" \
  "none" \
  "Should I continue with this refactor now?" \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-missing-input-without-input-question" \
  "none" \
  "Deploy with <API_KEY> and <HOST>, values are missing." \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-lowercase-token-near-miss" \
  "none" \
  "Deploy with prod_api_key and prod_host from config and continue autonomously." \
  "Need anything else?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "none-external-in-programming" \
  "none" \
  "Collect diagnostics and continue autonomously." \
  "Need anything else?" \
  "programming" \
  "curl https://example.com/health"

assert_preview_case \
  "none-assistant-without-external-commands" \
  "none" \
  "Create a launch memo but do not run external actions yet." \
  "Need anything else?" \
  "assistant" \
  "git status --short"

assert_preview_case \
  "precedence-explicit-over-missing" \
  "explicit-choice" \
  "Which deployment path should I choose for <PROD_HOST>, blue-green or canary?" \
  "Which deployment path should I use?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "precedence-external-over-risk" \
  "external-action-gate" \
  "Launch this workflow and run outreach checks." \
  "Do you approve this now?" \
  "assistant" \
  "curl https://example.com/health"

assert_preview_case \
  "precedence-explicit-over-external" \
  "explicit-choice" \
  "Which outreach path should I use, email or forum?" \
  "Which outreach path should I choose?" \
  "assistant" \
  "curl https://example.com/health"

assert_preview_case \
  "precedence-missing-over-risk" \
  "required-input-missing" \
  "Use <PROD_API_KEY> before deleting production rows." \
  "Which API key should I use before continuing?" \
  "programming" \
  "git status --short"

assert_preview_case \
  "precedence-missing-over-external" \
  "required-input-missing" \
  "Run outreach checks after setting <PROD_API_KEY>." \
  "Which API key should I use before network actions?" \
  "assistant" \
  "curl https://example.com/health"

assert_preview_case \
  "precedence-explicit-over-risk" \
  "explicit-choice" \
  "For the production deletion workflow, should I continue now or stop and prepare a backup first?" \
  "Should I continue now or stop and prepare backup first?" \
  "programming" \
  "git status --short"

printf '%s\n' "artificer decision-surfacing live tests passed"
