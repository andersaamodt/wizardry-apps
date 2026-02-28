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

failure_events_file=$(mr_failure_taxonomy_events_file)
mkdir -p "$(dirname "$failure_events_file")"
cat > "$failure_events_file" <<'EOF_FAILURES'
100	2026-02-28T00:01:00Z	verification-regression	finalizer	high	programming	action	error	hyp	next
101	2026-02-28T00:01:01Z	verification-regression	verifier	high	programming	action	error	hyp	next
102	2026-02-28T00:01:02Z	tool-misuse	planner	high	assistant	action	error	hyp	next
103	2026-02-28T00:01:03Z	tool-misuse	planner	medium	assistant	action	error	hyp	next
104	2026-02-28T00:01:04Z	tool-misuse	planner	high	assistant	action	error	hyp	next
105	2026-02-28T00:01:05Z	plan-drift	controller	medium	programming	action	error	hyp	next
106	2026-02-28T00:01:06Z	sandbox-permission	executor	high	assistant	action	error	hyp	next
107	2026-02-28T00:01:07Z	sandbox-permission	executor	high	assistant	action	error	hyp	next
108	2026-02-28T00:01:08Z	unknown	finalizer	low	assistant	action	error	hyp	next
EOF_FAILURES

top_programming=$(mr_failure_taxonomy_top_category_for_mode "programming" "2")
if [ "$top_programming" != "verification-regression" ]; then
  printf '%s\n' "expected programming top category verification-regression, got '$top_programming'" >&2
  exit 1
fi

top_assistant=$(mr_failure_taxonomy_top_category_for_mode "assistant" "2")
if [ "$top_assistant" != "sandbox-permission" ]; then
  printf '%s\n' "expected assistant top category sandbox-permission, got '$top_assistant'" >&2
  exit 1
fi

top_reporting=$(mr_failure_taxonomy_top_category_for_mode "reporting" "2")
if [ "$top_reporting" != "unknown" ]; then
  printf '%s\n' "expected missing mode top category unknown, got '$top_reporting'" >&2
  exit 1
fi

proposal_marker="$tmp_root/proposal-calls.tsv"
: > "$proposal_marker"
proposal_lookup_marker="$tmp_root/proposal-lookups.tsv"
: > "$proposal_lookup_marker"
mr_improvement_proposal_create() {
  call_count=$(wc -l < "$proposal_marker" 2>/dev/null | tr -d '[:space:]')
  case "$call_count" in
    ""|*[!0-9]*) call_count=0 ;;
  esac
  call_count=$((call_count + 1))
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$4" "$5" "$6" "$7" "${8:-}" >> "$proposal_marker"
  printf '%s' "proposal-test-$call_count"
}
mr_improvement_proposal_exists_for_category_and_mode() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$proposal_lookup_marker"
  return 1
}
mr_failure_taxonomy_top_category_for_mode() {
  printf '%s' "verification-regression"
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

lookup_calls=$(wc -l < "$proposal_lookup_marker" 2>/dev/null | tr -d '[:space:]')
case "$lookup_calls" in
  ""|*[!0-9]*) lookup_calls=0 ;;
esac
if [ "$lookup_calls" -ne 2 ]; then
  printf '%s\n' "expected two category/mode dedupe checks, got $lookup_calls" >&2
  exit 1
fi
if ! grep -Fq "$(printf 'verification-regression\tprogramming\tquality-scorecard')" "$proposal_lookup_marker"; then
  printf '%s\n' "expected programming dedupe lookup to include mode+source filters" >&2
  exit 1
fi
if ! grep -Fq "$(printf 'verification-regression\tassistant\tquality-scorecard')" "$proposal_lookup_marker"; then
  printf '%s\n' "expected assistant dedupe lookup to include mode+source filters" >&2
  exit 1
fi

tab_char=$(printf '\t')
first_row=$(awk 'NR == 1 { print; exit }' "$proposal_marker")
old_ifs=$IFS
IFS="$tab_char"
set -- $first_row
IFS=$old_ifs
first_title=${1:-}
first_scope=${2:-}
first_risk=${3:-}
first_source=${4:-}
first_category=${5:-}
first_source_mode=${6:-}
case "$first_title" in
  *"programming mode"*) ;;
  *)
    printf '%s\n' "expected first proposal title to target programming mode, got '$first_title'" >&2
    exit 1
    ;;
esac
if [ "$first_scope" != "verification" ]; then
  printf '%s\n' "expected first proposal scope verification, got '$first_scope'" >&2
  exit 1
fi
if [ "$first_risk" != "medium" ]; then
  printf '%s\n' "expected first proposal risk medium, got '$first_risk'" >&2
  exit 1
fi
if [ "$first_source" != "quality-scorecard" ]; then
  printf '%s\n' "expected first proposal source quality-scorecard, got '$first_source'" >&2
  exit 1
fi
if [ "$first_category" != "verification-regression" ]; then
  printf '%s\n' "expected first proposal category verification-regression, got '$first_category'" >&2
  exit 1
fi
if [ "$first_source_mode" != "programming" ]; then
  printf '%s\n' "expected first proposal source_mode programming, got '$first_source_mode'" >&2
  exit 1
fi

second_row=$(awk 'NR == 2 { print; exit }' "$proposal_marker")
old_ifs=$IFS
IFS="$tab_char"
set -- $second_row
IFS=$old_ifs
second_title=${1:-}
second_scope=${2:-}
second_risk=${3:-}
second_source_mode=${6:-}
case "$second_title" in
  *"assistant mode"*) ;;
  *)
    printf '%s\n' "expected second proposal title to target assistant mode, got '$second_title'" >&2
    exit 1
    ;;
esac
if [ "$second_scope" != "verification" ]; then
  printf '%s\n' "expected second proposal scope verification, got '$second_scope'" >&2
  exit 1
fi
if [ "$second_risk" != "high" ]; then
  printf '%s\n' "expected severe regression proposal risk high, got '$second_risk'" >&2
  exit 1
fi
if [ "$second_source_mode" != "assistant" ]; then
  printf '%s\n' "expected second proposal source_mode assistant, got '$second_source_mode'" >&2
  exit 1
fi

printf '%s\n' "artificer quality-scorecard regression logic tests passed"
