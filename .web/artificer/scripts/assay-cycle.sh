#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
API="$ROOT_DIR/.web/artificer/cgi/artificer-api"
OUT_DIR="$ROOT_DIR/.web/artificer/.assay-reports"

usage() {
  cat <<'EOF'
Usage:
  assay-cycle.sh run [--label NAME] [--timeout-sec N] [--run-budget-sec N]
  assay-cycle.sh compare --before FILE --after FILE

Examples:
  .web/artificer/scripts/assay-cycle.sh run --label baseline
  .web/artificer/scripts/assay-cycle.sh run --label after
  .web/artificer/scripts/assay-cycle.sh compare --before .web/artificer/.assay-reports/baseline.tsv --after .web/artificer/.assay-reports/after.tsv
EOF
}

urlenc() {
  jq -rn --arg v "$1" '$v|@uri'
}

json_only() {
  awk 'BEGIN{p=0} /^\{/ {p=1} p {print}'
}

post_api() {
  body=$1
  REQUEST_METHOD=POST "$API" <<EOF
$body
EOF
}

run_with_timeout() {
  timeout_sec=$1
  shift
  perl -e 'alarm shift @ARGV; exec @ARGV' "$timeout_sec" "$@"
}

task_table() {
  cat <<'EOF'
deterministic-tests	programming	long	Build a deterministic test harness for an existing flaky module. Add repeatable seed control, property tests, and a concise regression report.
concurrency-race	programming	long	Find and fix a likely race-condition class issue in this codebase. Reproduce with a stress test, patch it, and verify with repeated runs.
api-hardening	programming	standard	Introduce strict input validation for one high-risk API path, include backward-compatible error handling, and add focused contract tests.
migration-safe	programming	long	Design and implement an idempotent migration for a realistic schema change. Include rollback notes and a verification checklist.
perf-regression	programming	standard	Profile one slow path, optimize it without behavior drift, and add a benchmark-style guard so regressions are visible.
security-audit	security-audit	long	Audit this project for one concrete security weakness class, implement a fix, and add tests that fail before and pass after.
refactor-boundaries	programming	standard	Refactor one tangled area into clear module boundaries with minimal behavior change, and prove parity with targeted tests.
failure-recovery	programming	long	Add robust failure recovery for an external dependency path. Include retries, fallback behavior, and observable failure diagnostics.
spec-to-code	programming	until-complete	Write a short implementation contract first, then implement and verify a medium-complexity feature end-to-end from that contract.
report-trace	report	standard	Evaluate one recent run for conversation clarity and trace readability. Propose concrete improvements to step framing and summary quality.
teacher-explain	teacher	standard	Teach a difficult subsystem as a mini lesson with misconceptions, checkpoints, and spaced recall prompts.
pentest-simulation	pentest	long	Run a safe internal pentest simulation against likely attack surfaces in this project, propose concrete exploit paths, then implement and verify high-signal mitigations.
EOF
}

score_row_from_event_json() {
  jq -r '
    . as $e |
    ($e.status // "error") as $status |
    ($e.stream_text // "") as $stream |
    ($e.plan // "") as $plan |
    ($e.session_log // "") as $session |
    ($e.assistant // "") as $assistant |
    ([($e.commands // [])[]] | length) as $cmd |
    ([($stream | split("\n"))[] | select(length > 0)] | length) as $steps |
    ([($stream | split("\n"))[] | select(test("^\\[[0-9]{2}:[0-9]{2}:[0-9]{2}\\]"))] | length) as $ts_steps |
    (((($stream + "\n" + $plan + "\n" + $session) | test("MODE_UPDATE:|PLAN_UPDATE:|Next Action:|Completion Criteria:|Transition:"; "i")))) as $control |
    (((($stream + "\n" + $session + "\n" + ($e.state // "")) | test("verified|verification|tests?\\s+(pass|passed)|DONE_CLAIM:\\s*yes"; "i")))) as $verify |
    ((($assistant | test("Outcome:"; "i")) and ($assistant | test("Verification Evidence:"; "i")) and ($assistant | test("Risks:"; "i")) and ($assistant | test("Next Improvement:"; "i")))) as $sections |
    (($stream + "\n" + $assistant) | test("Worked for\\s+[0-9]+m\\s+[0-9]+s|Worked for\\s+[0-9]+s"; "i")) as $runtime_line |
    (
      44
      + (if $status == "done" then 24 elif $status == "error" then -26 elif $status == "cancelled" then -18 elif ($status == "awaiting_approval" or $status == "awaiting_decision") then -8 else 0 end)
      + (if ($plan|length) > 0 then 8 else 0 end)
      + (if $control then 8 else 0 end)
      + (if $verify then 9 else 0 end)
      + (if $sections then 8 elif $status == "done" then -6 else 0 end)
      + (if $steps < 3 then -12 else 0 end)
      + (if $cmd >= 2 then 10 else 0 end)
      + (if $cmd >= 6 then 6 else 0 end)
      + (if $cmd == 0 and $status == "done" then -8 else 0 end)
    ) as $iq_raw |
    (
      40
      + (if $steps >= 10 then 18 elif $steps >= 5 then 10 elif $steps >= 2 then 4 else -12 end)
      + (if $ts_steps >= 3 then 8 else 0 end)
      + (if $control then 9 else 0 end)
      + (if $verify then 6 else 0 end)
      + (if $runtime_line then 4 else 0 end)
      + (if ($stream|length) < 90 then -10 else 0 end)
      + (if $status == "error" and $steps < 4 then -8 else 0 end)
    ) as $flow_raw |
    [
      $status,
      ($cmd|tostring),
      ($steps|tostring),
      (($stream|length)|tostring),
      (($assistant|length)|tostring),
      (if $sections then "1" else "0" end),
      (if $control then "1" else "0" end),
      (if $verify then "1" else "0" end),
      (if $runtime_line then "1" else "0" end),
      ((if $iq_raw < 0 then 0 elif $iq_raw > 100 then 100 else $iq_raw end)|floor|tostring),
      ((if $flow_raw < 0 then 0 elif $flow_raw > 100 then 100 else $flow_raw end)|floor|tostring)
    ] | @tsv
  '
}

run_cycle() {
  label=$1
  task_timeout_sec=$2
  run_budget_sec=$3
  mkdir -p "$OUT_DIR"
  out_file="$OUT_DIR/$label.tsv"
  tmp_tasks=$(mktemp)
  task_table > "$tmp_tasks"

  ws_path=$ROOT_DIR
  ws_json=$(post_api "action=add_workspace&path=$(urlenc "$ws_path")&name=$(urlenc "Assay $label")" | json_only)
  ws_id=$(printf '%s' "$ws_json" | jq -r '.workspace.id')
  if [ -z "$ws_id" ] || [ "$ws_id" = "null" ]; then
    echo "Failed to create/get workspace for assay run." >&2
    exit 1
  fi

  printf 'task\tmode\tbudget\tstatus\tcommands\tsteps\tstream_len\tassistant_len\tsections\tcontrol\tverification\truntime_line\tintelligence\tflow\n' > "$out_file"

  while IFS='	' read -r task mode budget prompt; do
    [ -n "$task" ] || continue
    conv_json=$(post_api "action=new_conversation&workspace_id=$(urlenc "$ws_id")&title=$(urlenc "$task")" | json_only)
    conv_id=$(printf '%s' "$conv_json" | jq -r '.conversation.id')
    if [ -z "$conv_id" ] || [ "$conv_id" = "null" ]; then
      printf '%s\t%s\t%s\terror\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\n' "$task" "$mode" "$budget" >> "$out_file"
      continue
    fi

    max_iterations=6
    case "$budget" in
      long) max_iterations=8 ;;
      until-complete) max_iterations=12 ;;
      quick) max_iterations=3 ;;
      *) max_iterations=6 ;;
    esac

    body="action=run&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")&prompt=$(urlenc "$prompt")&run_mode=$(urlenc "$mode")&compute_budget=$(urlenc "$budget")&advanced_loop=1&max_iterations=$max_iterations&programmer_review=1&programmer_review_rounds=2&assay_task_id=$(urlenc "$task")"
    timed_out=0
    if ! run_with_timeout "$task_timeout_sec" sh -c "ARTIFICER_RUN_TIME_BUDGET_SEC=$run_budget_sec REQUEST_METHOD=POST \"$API\" <<'EOF' >/dev/null
$body
EOF
" 2>/dev/null; then
      timed_out=1
    fi

    if [ "$timed_out" -eq 1 ]; then
      post_api "action=queue_stop&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")" >/dev/null || true
    fi

    settle_try=0
    state_json=""
    while [ "$settle_try" -lt 8 ]; do
      queue_json=$(post_api "action=queue_list&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")" | json_only)
      queue_running=$(printf '%s' "$queue_json" | jq -r '.queue_running // 0')
      if [ "$queue_running" != "1" ]; then
        break
      fi
      sleep 0.4
      settle_try=$((settle_try + 1))
    done
    queue_json=$(post_api "action=queue_list&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")" | json_only)
    queue_last_status=$(printf '%s' "$queue_json" | jq -r '.queue_last_status // "unknown"')
    state_json=$(post_api "action=get_conversation&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")" | json_only)
    event_json=$(printf '%s' "$state_json" | jq -c '.conversation.run_events[-1] // {}')
    row=$(printf '%s' "$event_json" | score_row_from_event_json)
    event_status=$(printf '%s' "$event_json" | jq -r '.status // "unknown"')
    if [ "$event_status" = "running" ] && [ -n "$queue_last_status" ] && [ "$queue_last_status" != "running" ] && [ "$queue_last_status" != "unknown" ]; then
      row=$(printf '%s' "$row" | awk -F '\t' -v s="$queue_last_status" 'BEGIN{OFS=FS}{$1=s; print}')
    elif [ "$event_status" = "running" ] && [ "$timed_out" -eq 1 ]; then
      row=$(printf '%s' "$row" | awk -F '\t' 'BEGIN{OFS=FS}{$1="timeout"; print}')
    fi
    printf '%s\t%s\t%s\t%s\n' "$task" "$mode" "$budget" "$row" >> "$out_file"
    echo "cycle[$label] done: $task"
  done < "$tmp_tasks"

  rm -f "$tmp_tasks"
  echo "$out_file"
}

compare_cycles() {
  before=$1
  after=$2
  report="$OUT_DIR/compare-$(date +%Y%m%d-%H%M%S).md"
  awk -F '\t' 'NR==1{next} {print $1"\t"$13"\t"$14}' "$before" > "$OUT_DIR/.before.$$"
  awk -F '\t' 'NR==1{next} {print $1"\t"$13"\t"$14}' "$after" > "$OUT_DIR/.after.$$"
  join -t "$(printf '\t')" -a 1 -a 2 -e "0" -o 0,1.2,2.2,1.3,2.3 "$OUT_DIR/.before.$$" "$OUT_DIR/.after.$$" > "$OUT_DIR/.joined.$$"
  {
    echo "# Assay Before/After Report"
    echo
    echo "| Task | IQ Before | IQ After | Delta IQ | Flow Before | Flow After | Delta Flow |"
    echo "|---|---:|---:|---:|---:|---:|---:|"
    awk -F '\t' '{
      iqb=$2+0; iqa=$3+0; fb=$4+0; fa=$5+0;
      printf("| %s | %d | %d | %+d | %d | %d | %+d |\n", $1, iqb, iqa, iqa-iqb, fb, fa, fa-fb);
    }' "$OUT_DIR/.joined.$$"
  } > "$report"
  rm -f "$OUT_DIR/.before.$$" "$OUT_DIR/.after.$$" "$OUT_DIR/.joined.$$"
  echo "$report"
}

mode=${1:-}
if [ -z "$mode" ]; then
  usage
  exit 1
fi
shift

case "$mode" in
  run)
    label="cycle-$(date +%Y%m%d-%H%M%S)"
    task_timeout_sec=210
    run_budget_sec=120
    while [ $# -gt 0 ]; do
      case "$1" in
        --label)
          label=$2
          shift 2
          ;;
        --timeout-sec)
          task_timeout_sec=$2
          shift 2
          ;;
        --run-budget-sec)
          run_budget_sec=$2
          shift 2
          ;;
        *)
          echo "Unknown arg: $1" >&2
          usage
          exit 1
          ;;
      esac
    done
    run_cycle "$label" "$task_timeout_sec" "$run_budget_sec"
    ;;
  compare)
    before=""
    after=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --before)
          before=$2
          shift 2
          ;;
        --after)
          after=$2
          shift 2
          ;;
        *)
          echo "Unknown arg: $1" >&2
          usage
          exit 1
          ;;
      esac
    done
    if [ -z "$before" ] || [ -z "$after" ]; then
      usage
      exit 1
    fi
    compare_cycles "$before" "$after"
    ;;
  *)
    usage
    exit 1
    ;;
esac
