#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
API="$ROOT_DIR/.web/artificer/cgi/artificer-api"
OUT_DIR="$ROOT_DIR/.web/artificer/.assay-reports"

usage() {
  cat <<'EOF'
Usage:
  assay-cycle.sh run [--label NAME] [--timeout-sec N] [--run-budget-sec N] [--attempts N] [--mentor-from FILE] [--max-tasks N]
  assay-cycle.sh compare --before FILE --after FILE
  assay-cycle.sh decisions [--label NAME]

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

status_rank() {
  case "$1" in
    done) printf '%s' "6" ;;
    awaiting_approval|awaiting_decision) printf '%s' "5" ;;
    error) printf '%s' "4" ;;
    cancelled) printf '%s' "3" ;;
    timeout) printf '%s' "2" ;;
    running) printf '%s' "1" ;;
    *) printf '%s' "0" ;;
  esac
}

mentor_suffix_for_task() {
  task_id=$1
  mentor_file=$2
  if [ -z "$mentor_file" ] || [ ! -f "$mentor_file" ]; then
    return 0
  fi
  line=$(awk -F '\t' -v t="$task_id" 'NR>1 && $1==t {print; exit}' "$mentor_file")
  [ -n "$line" ] || return 0
  iq=$(printf '%s' "$line" | awk -F '\t' '{print $13+0}')
  flow=$(printf '%s' "$line" | awk -F '\t' '{print $14+0}')
  sections=$(printf '%s' "$line" | awk -F '\t' '{print $9+0}')
  control=$(printf '%s' "$line" | awk -F '\t' '{print $10+0}')
  verify=$(printf '%s' "$line" | awk -F '\t' '{print $11+0}')
  runtime_line=$(printf '%s' "$line" | awk -F '\t' '{print $12+0}')

  printf '\n\nAssay mentor guidance from prior cycle:\n'
  if [ "$iq" -lt 60 ]; then
    printf -- '- Raise intelligence score by increasing concrete execution depth and explicit verification.\n'
  fi
  if [ "$flow" -lt 60 ]; then
    printf -- '- Raise flow score with concise timestamp-style step updates and a cleaner final structure.\n'
  fi
  if [ "$sections" -lt 1 ]; then
    printf -- '- Mandatory final sections: Outcome, Verification Evidence, Risks, Next Improvement.\n'
  fi
  if [ "$control" -lt 1 ]; then
    printf -- '- Include explicit planning scaffold updates while running.\n'
  fi
  if [ "$verify" -lt 1 ]; then
    printf -- '- Include concrete verification evidence before DONE.\n'
  fi
  if [ "$runtime_line" -lt 1 ]; then
    printf -- '- Include explicit runtime line: Worked for Xm Ys.\n'
  fi
}

task_table() {
  cat <<'EOF'
deterministic-tests	report	standard	Design a deterministic test harness strategy for a flaky subsystem, including seed policy, repeatability checks, and a concise regression report template.
concurrency-race	assistant	standard	Diagnose a likely race-condition class failure path, propose a concrete mitigation design, and specify verification steps for concurrent stress conditions.
api-hardening	programming	standard	Introduce strict input validation for one high-risk API path, include backward-compatible error handling, and add focused contract tests.
migration-safe	assistant	standard	Design an idempotent migration plan for a realistic schema change, including rollback, observability, and release sequencing safeguards.
perf-regression	report	standard	Analyze a probable performance regression path and propose measurable optimization and benchmark guardrails without behavior drift.
security-audit	security-audit	standard	Audit this project for one concrete security weakness class, implement a fix, and add tests that fail before and pass after.
refactor-boundaries	assistant	standard	Refactor strategy: split one tangled area into clear module boundaries with minimal behavior change and parity validation checkpoints.
failure-recovery	programming	standard	Add robust failure recovery for one external dependency path with retries, fallback behavior, and observable failure diagnostics.
spec-to-code	assistant	standard	Write a short implementation contract first, then produce a high-confidence implementation and verification plan for end-to-end delivery.
report-trace	report	standard	Evaluate one recent run for conversation clarity and trace readability. Propose concrete improvements to step framing and summary quality.
teacher-explain	teacher	standard	Teach a difficult subsystem as a mini lesson with misconceptions, checkpoints, and spaced recall prompts.
pentest-simulation	pentest	standard	Run a safe internal pentest simulation against likely attack surfaces, propose concrete exploit paths, then implement and verify high-signal mitigations.
EOF
}

score_row_from_event_json() {
  jq -r '
    . as $e |
    ($e.status // "error") as $status |
    ($e.stream_text // "") as $stream |
    ($e.plan // "") as $plan |
    ($e.session_log // "") as $session |
    ($e.failures // "") as $failures |
    (if (($e.assistant // "") | length) > 0 then ($e.assistant // "") else ($e.error // "") end) as $assistant |
    ([($e.commands // [])[]] | length) as $cmd |
    ([((($stream + "\n" + $failures) | split("\n")))[] | select(length > 0)] | length) as $steps |
    ([($stream | split("\n"))[] | select(test("^\\[[0-9]{2}:[0-9]{2}:[0-9]{2}\\]"))] | length) as $ts_steps |
    (((($stream + "\n" + $plan + "\n" + $session + "\n" + $failures + "\n" + $assistant) | test("MODE_UPDATE:|PLAN_UPDATE:|Next Action:|Completion Criteria:|Transition:"; "i")))) as $control |
    (((($stream + "\n" + $session + "\n" + ($e.state // "") + "\n" + $failures + "\n" + $assistant) | test("verified|verification|tests?\\s+(pass|passed)|DONE_CLAIM:\\s*yes"; "i")))) as $verify |
    ((($assistant | test("Outcome:"; "i")) and ($assistant | test("Verification Evidence:"; "i")) and ($assistant | test("Risks:"; "i")) and ($assistant | test("Next Improvement:"; "i")))) as $sections |
    (($stream + "\n" + $assistant + "\n" + $failures) | test("Worked for\\s+[0-9]+m\\s+[0-9]+s|Worked for\\s+[0-9]+s"; "i")) as $runtime_line |
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
  attempts=$4
  mentor_from=$5
  max_tasks=$6
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

  processed_count=0
  while IFS='	' read -r task mode budget prompt; do
    [ -n "$task" ] || continue
    if [ "$max_tasks" -gt 0 ] && [ "$processed_count" -ge "$max_tasks" ]; then
      break
    fi
    max_iterations=6
    case "$budget" in
      long) max_iterations=4 ;;
      until-complete) max_iterations=5 ;;
      quick) max_iterations=2 ;;
      *) max_iterations=3 ;;
    esac
    case "$mode" in
      programming|security-audit|pentest)
        if [ "$max_iterations" -lt 4 ]; then
          max_iterations=4
        fi
        ;;
      assistant|report|teacher)
        if [ "$max_iterations" -lt 3 ]; then
          max_iterations=3
        fi
        ;;
    esac

    best_row=""
    best_rank=-1
    attempt=1
    while [ "$attempt" -le "$attempts" ]; do
      conv_json=$(post_api "action=new_conversation&workspace_id=$(urlenc "$ws_id")&title=$(urlenc "$task")" | json_only)
      conv_id=$(printf '%s' "$conv_json" | jq -r '.conversation.id')
      if [ -z "$conv_id" ] || [ "$conv_id" = "null" ]; then
        row="error\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0"
        current_rank=$(status_rank "error")
        if [ "$current_rank" -gt "$best_rank" ]; then
          best_rank=$current_rank
          best_row=$row
        fi
        break
      fi

      budget_this=$run_budget_sec
      case "$budget" in
        long)
          budget_this=$((budget_this + 10))
          ;;
        until-complete)
          budget_this=$((budget_this + 15))
          ;;
      esac
      timeout_this=$((budget_this + 240))
      if [ "$timeout_this" -lt "$task_timeout_sec" ]; then
        timeout_this=$task_timeout_sec
      fi
      if [ "$timeout_this" -gt 540 ]; then
        timeout_this=540
      fi
      if [ "$attempt" -gt 1 ]; then
        timeout_this=$((timeout_this + (attempt - 1) * 15))
        budget_this=$((budget_this + (attempt - 1) * 10))
      fi

      mentor_suffix=$(mentor_suffix_for_task "$task" "$mentor_from" || true)
      prompt_for_run=$prompt
      if [ -n "$mentor_suffix" ]; then
        prompt_for_run=$(printf '%s\n%s' "$prompt" "$mentor_suffix")
      fi
      body="action=run&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")&prompt=$(urlenc "$prompt_for_run")&run_mode=$(urlenc "$mode")&compute_budget=$(urlenc "$budget")&advanced_loop=1&max_iterations=$max_iterations&programmer_review=1&programmer_review_rounds=2&assay_task_id=$(urlenc "$task")"
      timed_out=0
      if ! run_with_timeout "$timeout_this" sh -c "ARTIFICER_RUN_TIME_BUDGET_SEC=$budget_this REQUEST_METHOD=POST \"$API\" <<'EOF' >/dev/null
$body
EOF
" 2>/dev/null; then
        timed_out=1
      fi

      if [ "$timed_out" -eq 1 ]; then
        post_api "action=queue_stop&workspace_id=$(urlenc "$ws_id")&conversation_id=$(urlenc "$conv_id")" >/dev/null || true
      fi

      settle_try=0
      settle_limit=20
      if [ "$timed_out" -eq 1 ]; then
        settle_limit=45
      fi
      state_json=""
      while [ "$settle_try" -lt "$settle_limit" ]; do
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
      assistant_from_messages=$(printf '%s' "$state_json" | jq -r '.conversation.messages | map(select(.role=="assistant")) | last | .content // ""')
      if [ -n "$assistant_from_messages" ]; then
        event_json=$(printf '%s' "$event_json" | jq -c --arg a "$assistant_from_messages" '.assistant = (if ((.assistant // "") | length) > 0 then .assistant else $a end)')
      fi
      row=$(printf '%s' "$event_json" | score_row_from_event_json)
      event_status=$(printf '%s' "$event_json" | jq -r '.status // "unknown"')
      if [ "$event_status" = "running" ] && [ -n "$queue_last_status" ] && [ "$queue_last_status" != "running" ] && [ "$queue_last_status" != "unknown" ]; then
        row=$(printf '%s' "$row" | awk -F '\t' -v s="$queue_last_status" 'BEGIN{OFS=FS}{$1=s; print}')
      elif [ "$event_status" = "running" ] && [ "$timed_out" -eq 1 ]; then
        row=$(printf '%s' "$row" | awk -F '\t' 'BEGIN{OFS=FS}{$1="timeout"; print}')
      fi

      this_status=$(printf '%s' "$row" | awk -F '\t' '{print $1}')
      if [ "$timed_out" -eq 1 ] && [ "$this_status" != "done" ]; then
        row=$(printf '%s' "$row" | awk -F '\t' 'BEGIN{OFS=FS}{$1="timeout"; print}')
        this_status="timeout"
      fi
      this_rank=$(status_rank "$this_status")
      if [ "$this_rank" -gt "$best_rank" ]; then
        best_rank=$this_rank
        best_row=$row
      fi
      if [ "$this_status" = "done" ]; then
        break
      fi
      attempt=$((attempt + 1))
    done

    [ -n "$best_row" ] || best_row="error\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0"
    printf '%s\t%s\t%s\t%s\n' "$task" "$mode" "$budget" "$best_row" >> "$out_file"
    echo "cycle[$label] done: $task"
    processed_count=$((processed_count + 1))
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

decision_matrix() {
  label=$1
  mkdir -p "$OUT_DIR"
  out_file="$OUT_DIR/$label.tsv"
  printf 'case\tkind\texpected_category\tactual_category\tallow\tpass\n' > "$out_file"

  run_case() {
    case_id=$1
    kind=$2
    expected=$3
    prompt=$4
    question=$5
    commands=$6
    run_mode=${7:-assistant}
    raw=$(post_api "action=decision_surface_preview&prompt=$(urlenc "$prompt")&question=$(urlenc "$question")&commands=$(urlenc "$commands")&run_mode=$(urlenc "$run_mode")" | json_only)
    actual=$(printf '%s' "$raw" | jq -r '.category // "none"')
    allow=$(printf '%s' "$raw" | jq -r '.allow_decision_request // false')
    pass=0
    if [ "$actual" = "$expected" ]; then
      pass=1
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$case_id" "$kind" "$expected" "$actual" "$allow" "$pass" >> "$out_file"
  }

  run_case "explicit-choice-trigger" "trigger" "explicit-choice" \
    "Choose one approach: ship now or delay for reliability?" "" ""
  run_case "explicit-choice-near" "near-miss" "none" \
    "Please proceed with your best approach." "" ""

  run_case "required-input-trigger" "trigger" "required-input-missing" \
    "Write a migration for my database." "" ""
  run_case "required-input-near" "near-miss" "none" \
    "Write a migration for PostgreSQL table users add column last_login TIMESTAMP default now()." "" ""

  run_case "external-action-trigger" "trigger" "external-action-gate" \
    "" "" "curl -X POST https://api.mailgun.net/send"
  run_case "external-action-near" "near-miss" "none" \
    "" "" "grep -R \"TODO\" ."

  run_case "risk-ack-trigger" "trigger" "risk-acknowledgement" \
    "" "This action can delete production data. Continue anyway?" ""
  run_case "risk-ack-near" "near-miss" "none" \
    "" "Ready to continue with the next implementation step?" ""

  echo "$out_file"
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
    task_timeout_sec=320
    run_budget_sec=120
    attempts=1
    mentor_from=""
    max_tasks=0
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
        --attempts)
          attempts=$2
          shift 2
          ;;
        --mentor-from)
          mentor_from=$2
          shift 2
          ;;
        --max-tasks)
          max_tasks=$2
          shift 2
          ;;
        *)
          echo "Unknown arg: $1" >&2
          usage
          exit 1
          ;;
      esac
    done
    case "$max_tasks" in
      ""|*[!0-9]*)
        max_tasks=0
        ;;
    esac
    run_cycle "$label" "$task_timeout_sec" "$run_budget_sec" "$attempts" "$mentor_from" "$max_tasks"
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
  decisions)
    label="decisions-$(date +%Y%m%d-%H%M%S)"
    while [ $# -gt 0 ]; do
      case "$1" in
        --label)
          label=$2
          shift 2
          ;;
        *)
          echo "Unknown arg: $1" >&2
          usage
          exit 1
          ;;
      esac
    done
    decision_matrix "$label"
    ;;
  *)
    usage
    exit 1
    ;;
esac
