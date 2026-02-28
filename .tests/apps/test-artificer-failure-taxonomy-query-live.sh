#!/bin/sh
set -eu

api_url=${ARTIFICER_TEST_API_URL:-http://localhost:8082/cgi/artificer-api}

if ! curl -fsS "$api_url?action=state" >/dev/null 2>&1; then
  printf '%s\n' "artificer failure-taxonomy query live tests skipped (api unavailable: $api_url)"
  exit 0
fi

query_taxonomy() {
  category=$1
  severity=$2
  surface=$3
  mode_value=$4
  since_epoch=$5
  limit_value=$6
  curl -fsS -G "$api_url" \
    --data-urlencode action=failure_taxonomy_query \
    --data-urlencode category="$category" \
    --data-urlencode severity="$severity" \
    --data-urlencode surface="$surface" \
    --data-urlencode mode="$mode_value" \
    --data-urlencode since_epoch="$since_epoch" \
    --data-urlencode limit="$limit_value"
}

assert_eq() {
  name=$1
  actual=$2
  expected=$3
  if [ "$actual" != "$expected" ]; then
    printf '%s\n' "assertion failed: $name expected '$expected' but got '$actual'" >&2
    exit 1
  fi
}

response=$(query_taxonomy "" "" "" "" "0" "2")
base_success=$(printf '%s' "$response" | jq -r '.success')
assert_eq "base.success" "$base_success" "true"
base_limit=$(printf '%s' "$response" | jq -r '.failure_taxonomy_query.filters.limit // ""')
assert_eq "base.limit" "$base_limit" "2"
base_returned=$(printf '%s' "$response" | jq -r '.failure_taxonomy_query.returned // ""')
base_events_len=$(printf '%s' "$response" | jq -r '.failure_taxonomy_query.events | length')
assert_eq "base.returned-length" "$base_returned" "$base_events_len"
if [ "$base_events_len" -gt 2 ]; then
  printf '%s\n' "assertion failed: expected <=2 events but got $base_events_len" >&2
  exit 1
fi

response_high=$(query_taxonomy "" "HIGH" "" "" "0" "999")
high_success=$(printf '%s' "$response_high" | jq -r '.success')
assert_eq "high.success" "$high_success" "true"
high_limit=$(printf '%s' "$response_high" | jq -r '.failure_taxonomy_query.filters.limit // ""')
assert_eq "high.limit-clamped" "$high_limit" "250"
high_mismatch=$(printf '%s' "$response_high" | jq -r '[.failure_taxonomy_query.events[] | select((.severity // "") != "high")] | length')
assert_eq "high.severity-only" "$high_mismatch" "0"

response_invalid=$(query_taxonomy "all" "all" "all" "all" "not-a-number" "abc")
invalid_success=$(printf '%s' "$response_invalid" | jq -r '.success')
assert_eq "invalid.success" "$invalid_success" "true"
invalid_since=$(printf '%s' "$response_invalid" | jq -r '.failure_taxonomy_query.filters.since_epoch // ""')
assert_eq "invalid.since-default" "$invalid_since" "0"
invalid_limit=$(printf '%s' "$response_invalid" | jq -r '.failure_taxonomy_query.filters.limit // ""')
assert_eq "invalid.limit-default" "$invalid_limit" "50"

printf '%s\n' "artificer failure-taxonomy query live tests passed"
