#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
mode_runtime_lib="$root/web/artificer/cgi/mode-runtime-lib.sh"

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

summary_empty=$(mr_improvement_proposals_recent_summary_text "programming" "12" "3")
if [ "$summary_empty" != "none" ]; then
  printf '%s\n' "expected empty summary to be none, got '$summary_empty'" >&2
  exit 1
fi

proposals_dir=$(mr_improvement_proposals_dir)
mkdir -p "$proposals_dir"

write_meta() {
  proposal_id=$1
  title_text=$2
  scope_text=$3
  risk_text=$4
  source_text=$5
  status_text=$6
  category_text=$7
  source_mode_text=$8
  proposal_dir="$proposals_dir/$proposal_id"
  mkdir -p "$proposal_dir"
  cat > "$proposal_dir/meta.env" <<EOF_META
id=$proposal_id
title=$title_text
scope=$scope_text
risk_level=$risk_text
source=$source_text
status=$status_text
created_at=2026-02-28T00:00:00Z
updated_at=2026-02-28T00:00:00Z
applied_at=
taxonomy_category=$category_text
source_mode=$source_mode_text
rationale=test
proposed_change=test
EOF_META
}

write_meta "proposal-0005" "Investigate quality regression in programming mode" "verification" "high" "quality-scorecard" "applied" "verification-regression" "programming"
write_meta "proposal-0004" "Refine planner checkpoints" "controller-loop" "medium" "manual" "accepted" "plan-drift" "programming"
write_meta "proposal-0003" "Investigate quality regression in assistant mode" "controller-loop" "medium" "quality-scorecard" "applied" "tool-misuse" "assistant"
write_meta "proposal-0002" "Noise proposal" "other" "low" "manual" "rejected" "unknown" "programming"
write_meta "proposal-0001" "Legacy fallback in programming mode" "tooling" "low" "manual" "accepted" "controller-stagnation" ""

summary_programming=$(mr_improvement_proposals_recent_summary_text "programming" "20" "4")
case "$summary_programming" in
  *"accepted=2; applied=1;"*) ;;
  *)
    printf '%s\n' "expected programming summary counts accepted=2 applied=1, got '$summary_programming'" >&2
    exit 1
    ;;
esac
case "$summary_programming" in
  *"verification-regression"*"plan-drift"*"controller-stagnation"*) ;;
  *)
    printf '%s\n' "expected programming summary to include all programming proposal categories, got '$summary_programming'" >&2
    exit 1
    ;;
esac
case "$summary_programming" in
  *"tool-misuse"*)
    printf '%s\n' "assistant-only proposal leaked into programming summary: '$summary_programming'" >&2
    exit 1
    ;;
  *) ;;
esac
case "$summary_programming" in
  *"mode=programming"*) ;;
  *)
    printf '%s\n' "expected programming summary to annotate mode=programming, got '$summary_programming'" >&2
    exit 1
    ;;
esac

summary_assistant=$(mr_improvement_proposals_recent_summary_text "assistant" "20" "4")
case "$summary_assistant" in
  *"accepted=0; applied=1;"*"tool-misuse"*) ;;
  *)
    printf '%s\n' "expected assistant summary to include only applied tool-misuse, got '$summary_assistant'" >&2
    exit 1
    ;;
esac
case "$summary_assistant" in
  *"plan-drift"*|*"verification-regression"*)
    printf '%s\n' "programming proposal leaked into assistant summary: '$summary_assistant'" >&2
    exit 1
    ;;
  *) ;;
esac

summary_limited=$(mr_improvement_proposals_recent_summary_text "programming" "20" "1")
item_count=$(printf '%s' "$summary_limited" | awk -F'\[' '{ print NF-1 }')
case "$item_count" in
  1) ;;
  *)
    printf '%s\n' "expected limited summary to include exactly one item, got '$summary_limited'" >&2
    exit 1
    ;;
esac

summary_reporting=$(mr_improvement_proposals_recent_summary_text "reporting" "20" "3")
if [ "$summary_reporting" != "none" ]; then
  printf '%s\n' "expected unmatched mode summary to be none, got '$summary_reporting'" >&2
  exit 1
fi

printf '%s\n' "artificer improvement-proposals summary logic tests passed"
