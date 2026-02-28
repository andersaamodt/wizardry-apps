#!/bin/sh
set -eu

api_url=${ARTIFICER_TEST_API_URL:-http://localhost:8082/cgi/artificer-api}
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
fixture_file="$root/.tests/apps/fixtures/artificer-decision-surfacing-fixtures.psv"

if [ ! -f "$fixture_file" ]; then
  printf '%s\n' "artificer decision-surfacing fixtures live tests skipped (fixture file missing)"
  exit 0
fi

if ! curl -fsS "$api_url?action=state" >/dev/null 2>&1; then
  printf '%s\n' "artificer decision-surfacing fixtures live tests skipped (api unavailable: $api_url)"
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

assert_case() {
  case_id=$1
  expected_category=$2
  expected_allow=$3
  expected_explicit=$4
  expected_missing=$5
  expected_risk=$6
  expected_external=$7
  expected_destructive=$8
  run_mode=$9
  prompt=${10}
  question=${11}
  commands=${12}

  response=$(post_preview "$prompt" "$question" "$run_mode" "$commands")
  actual_category=$(printf '%s' "$response" | jq -r '.category // ""')
  actual_allow=$(printf '%s' "$response" | jq -r '.allow_decision_request')
  signal_explicit=$(printf '%s' "$response" | jq -r '.signals.explicit_choice')
  signal_missing=$(printf '%s' "$response" | jq -r '.signals.missing_required_inputs')
  signal_risk=$(printf '%s' "$response" | jq -r '.signals.risk_gate_question')
  signal_external=$(printf '%s' "$response" | jq -r '.signals.external_commands')
  signal_destructive=$(printf '%s' "$response" | jq -r '.signals.destructive_commands')

  if [ "$actual_category" != "$expected_category" ]; then
    printf '%s\n' "fixture '$case_id' expected category '$expected_category' but got '$actual_category'" >&2
    exit 1
  fi
  if [ "$actual_allow" != "$expected_allow" ]; then
    printf '%s\n' "fixture '$case_id' expected allow_decision_request=$expected_allow but got '$actual_allow'" >&2
    exit 1
  fi
  if [ "$signal_explicit" != "$expected_explicit" ]; then
    printf '%s\n' "fixture '$case_id' expected explicit_choice=$expected_explicit but got '$signal_explicit'" >&2
    exit 1
  fi
  if [ "$signal_missing" != "$expected_missing" ]; then
    printf '%s\n' "fixture '$case_id' expected missing_required_inputs=$expected_missing but got '$signal_missing'" >&2
    exit 1
  fi
  if [ "$signal_risk" != "$expected_risk" ]; then
    printf '%s\n' "fixture '$case_id' expected risk_gate_question=$expected_risk but got '$signal_risk'" >&2
    exit 1
  fi
  if [ "$signal_external" != "$expected_external" ]; then
    printf '%s\n' "fixture '$case_id' expected external_commands=$expected_external but got '$signal_external'" >&2
    exit 1
  fi
  if [ "$signal_destructive" != "$expected_destructive" ]; then
    printf '%s\n' "fixture '$case_id' expected destructive_commands=$expected_destructive but got '$signal_destructive'" >&2
    exit 1
  fi
}

while IFS='|' read -r case_id expected_category expected_allow expected_explicit expected_missing expected_risk expected_external expected_destructive run_mode prompt question commands || [ -n "$case_id" ]; do
  case_id=$(printf '%s' "$case_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$case_id" ] || continue
  case "$case_id" in
    \#*) continue ;;
  esac
  assert_case \
    "$case_id" \
    "$expected_category" \
    "$expected_allow" \
    "$expected_explicit" \
    "$expected_missing" \
    "$expected_risk" \
    "$expected_external" \
    "$expected_destructive" \
    "$run_mode" \
    "$prompt" \
    "$question" \
    "$commands"
done < "$fixture_file"

printf '%s\n' "artificer decision-surfacing fixture live tests passed"
