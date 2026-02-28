#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
mode_runtime_lib="$root/.web/artificer/cgi/mode-runtime-lib.sh"

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

valid_id() {
  case "$1" in
    ""|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

param() {
  printf '%s' ""
}

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT
mode_runtime_root="$tmp_root/mode-runtime"

# shellcheck disable=SC1090
. "$mode_runtime_lib"

mkdir -p "$(mr_quality_scorecard_dir)"
entries_file=$(mr_quality_scorecard_entries_file)

cat > "$entries_file" <<'EOF_ROWS'
1	2026-02-28T00:00:01Z	baseline	run-1	programming	done	DONE	0.820	0.000	30	2	0	0
2	2026-02-28T00:00:02Z	baseline	run-2	programming	done	DONE	0.740	-0.080	35	2	0	0
3	2026-02-28T00:00:03Z	baseline	run-3	programming	done	IMPLEMENT	0.500	-0.240	42	3	1	0
4	2026-02-28T00:00:04Z	baseline	run-4	programming	done	DONE	0.580	-0.020	28	2	0	0
5	2026-02-28T00:00:05Z	baseline	run-5	programming	done	IMPLEMENT	0.470	-0.110	51	3	1	0
EOF_ROWS

stats=$(mr_quality_scorecard_recent_regression_stats_for_mode "programming" "5")
old_ifs=$IFS
IFS=$(printf '\t')
set -- $stats
IFS=$old_ifs

if [ "${1:-}" != "5" ]; then
  printf '%s\n' "expected total=5 but got '${1:-}'" >&2
  exit 1
fi
if [ "${2:-}" != "2" ]; then
  printf '%s\n' "expected regressive=2 but got '${2:-}'" >&2
  exit 1
fi
if [ "${3:-}" != "2" ]; then
  printf '%s\n' "expected severe=2 but got '${3:-}'" >&2
  exit 1
fi
if [ "${4:-}" != "-0.090" ]; then
  printf '%s\n' "expected avg_delta=-0.090 but got '${4:-}'" >&2
  exit 1
fi

remaining_initial=$(mr_quality_scorecard_regression_cooldown_remaining_sec "programming" "3600" "10000")
if [ "$remaining_initial" != "0" ]; then
  printf '%s\n' "expected initial cooldown remaining 0 but got '$remaining_initial'" >&2
  exit 1
fi

mr_quality_scorecard_set_regression_cooldown_for_mode "programming" "9700"
remaining_active=$(mr_quality_scorecard_regression_cooldown_remaining_sec "programming" "3600" "10000")
if [ "$remaining_active" != "3300" ]; then
  printf '%s\n' "expected active cooldown remaining 3300 but got '$remaining_active'" >&2
  exit 1
fi

mr_quality_scorecard_set_regression_cooldown_for_mode "programming" "5000"
remaining_expired=$(mr_quality_scorecard_regression_cooldown_remaining_sec "programming" "3600" "10000")
if [ "$remaining_expired" != "0" ]; then
  printf '%s\n' "expected expired cooldown remaining 0 but got '$remaining_expired'" >&2
  exit 1
fi

proposal_marker="$tmp_root/proposal-calls.log"
: > "$proposal_marker"
mr_improvement_proposal_create() {
  call_count=$(wc -l < "$proposal_marker" 2>/dev/null | tr -d '[:space:]')
  case "$call_count" in
    ""|*[!0-9]*) call_count=0 ;;
  esac
  call_count=$((call_count + 1))
  printf '%s\n' "call-$call_count" >> "$proposal_marker"
  printf '%s' "proposal-test-$call_count"
}
mr_improvement_proposal_exists_for_category() {
  return 1
}
mr_failure_taxonomy_latest_category_id() {
  printf '%s' "unknown"
}

mr_quality_scorecard_maybe_raise_regression_proposal "programming" "0.580" "-0.090" "done" "DONE"
proposal_calls=$(wc -l < "$proposal_marker" 2>/dev/null | tr -d '[:space:]')
case "$proposal_calls" in
  ""|*[!0-9]*) proposal_calls=0 ;;
esac
if [ "$proposal_calls" -ne 1 ]; then
  printf '%s\n' "expected one proposal creation call, got $proposal_calls" >&2
  exit 1
fi

mr_quality_scorecard_maybe_raise_regression_proposal "programming" "0.580" "-0.090" "done" "DONE"
proposal_calls=$(wc -l < "$proposal_marker" 2>/dev/null | tr -d '[:space:]')
case "$proposal_calls" in
  ""|*[!0-9]*) proposal_calls=0 ;;
esac
if [ "$proposal_calls" -ne 1 ]; then
  printf '%s\n' "expected cooldown to suppress duplicate proposal calls, got $proposal_calls" >&2
  exit 1
fi

mr_quality_scorecard_maybe_raise_regression_proposal "assistant" "0.450" "-0.200" "done" "IMPLEMENT"
proposal_calls=$(wc -l < "$proposal_marker" 2>/dev/null | tr -d '[:space:]')
case "$proposal_calls" in
  ""|*[!0-9]*) proposal_calls=0 ;;
esac
if [ "$proposal_calls" -ne 2 ]; then
  printf '%s\n' "expected severe regression to create proposal for assistant mode, got $proposal_calls" >&2
  exit 1
fi

printf '%s\n' "artificer quality-scorecard regression logic tests passed"
