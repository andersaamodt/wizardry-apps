#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
api="$root/.web/artificer/cgi/artificer-api"
page_html="$root/.web/artificer/pages/index.html"
page_md="$root/.web/artificer/pages/index.md"
ui_js="$root/.web/artificer/static/artificer-app.js"
style="$root/.web/artificer/static/style.css"

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

assert_file() {
  target=$1
  [ -f "$target" ] || fail "missing file: $target"
}

assert_contains() {
  file=$1
  needle=$2
  if ! grep -F -- "$needle" "$file" >/dev/null 2>&1; then
    fail "missing expected text in $(basename "$file"): $needle"
  fi
}

assert_not_contains() {
  file=$1
  needle=$2
  if grep -F -- "$needle" "$file" >/dev/null 2>&1; then
    fail "unexpected text in $(basename "$file"): $needle"
  fi
}

assert_file "$api"
assert_file "$page_html"
assert_file "$page_md"
assert_file "$ui_js"
assert_file "$style"

# Backend contract: programmer review metadata and run-loop integration.
assert_contains "$api" "normalize_programmer_review_enabled_value()"
assert_contains "$api" "normalize_programmer_review_rounds_value()"
assert_contains "$api" "printf 'programmer_review=%s\\n' \"\$normalized_programmer_review_enabled\""
assert_contains "$api" "printf 'programmer_review_rounds=%s\\n' \"\$normalized_programmer_review_rounds\""
assert_contains "$api" "queue_meta_programmer_review_from_file()"
assert_contains "$api" "queue_meta_programmer_review_rounds_from_file()"
assert_contains "$api" "\"programmer_review\":\"%s\""
assert_contains "$api" "\"programmer_review_rounds\":\"%s\""
assert_contains "$api" "programmer_review_raw=\$(trim \"\$(param \"programmer_review\")\")"
assert_contains "$api" "programmer_review_rounds_raw=\$(trim \"\$(param \"programmer_review_rounds\")\")"
assert_contains "$api" "programmer_review_last_feedback=\"\""
assert_contains "$api" "Code review round \$review_round/\$programmer_review_max_rounds started."
assert_contains "$api" "code_review=\${programmer_review_enabled}, review_rounds=\${programmer_review_max_rounds}"
assert_contains "$api" "\"until-complete\" uses 0 as an unlimited-iteration sentinel."
assert_contains "$api" "max_iterations_label=\"unbounded\""
assert_contains "$api" 'if [ "$max_iterations" -gt 0 ] && [ "$iteration" -gt "$max_iterations" ]; then'

# Frontend contract: programmer-review settings and run payload wiring.
assert_contains "$ui_js" "programmerReviewEnabled: storageGet(\"artificer.programmerReviewEnabled\", \"1\") !== \"0\","
assert_contains "$ui_js" "programmerReviewRounds: Number(storageGet(\"artificer.programmerReviewRounds\", \"2\")),"
assert_contains "$ui_js" "function renderProgrammingSettings()"
assert_contains "$ui_js" "programmer_review: programmerReviewEnabledForRun ? \"1\" : \"0\","
assert_contains "$ui_js" "programmer_review_rounds: String(programmerReviewRoundsForRun),"
assert_contains "$ui_js" "programmer_review: normalizedProgrammerReview ? \"1\" : \"0\","
assert_contains "$ui_js" "programmer_review_rounds: String(normalizedProgrammerReviewRounds),"
assert_contains "$ui_js" "selectedIterations = 0;"
assert_contains "$ui_js" "safeStep(\"renderProgrammingSettings\", renderProgrammingSettings);"
assert_contains "$ui_js" "function synthesizeRunTimelineEntries(event)"
assert_contains "$ui_js" "function runTimelineEntries(event)"
assert_contains "$ui_js" "var streamEntries = runTimelineEntries(event);"

# Assay-specific payload plumbing must not be active in Artificer runtime.
assert_not_contains "$ui_js" "assay_task_id: explicitAssayTaskId,"
assert_not_contains "$ui_js" "assay_task_id: normalizedAssayTaskId,"

# Page contract: programmer-review controls exist in source and rendered html.
assert_contains "$page_md" "id=\"programmer-review-toggle\""
assert_contains "$page_md" "id=\"programmer-review-rounds\""
assert_contains "$page_html" "id=\"programmer-review-toggle\""
assert_contains "$page_html" "id=\"programmer-review-rounds\""

# Assay controls should not exist in the app UI pages.
assert_not_contains "$page_md" "id=\"assay-cycle-count\""
assert_not_contains "$page_md" "id=\"assay-queue-next-btn\""
assert_not_contains "$page_md" "id=\"assay-queue-cycle-btn\""
assert_not_contains "$page_md" "id=\"assay-reset-btn\""
assert_not_contains "$page_md" "id=\"assay-task-list\""
assert_not_contains "$page_html" "id=\"assay-cycle-count\""
assert_not_contains "$page_html" "id=\"assay-queue-next-btn\""
assert_not_contains "$page_html" "id=\"assay-queue-cycle-btn\""
assert_not_contains "$page_html" "id=\"assay-reset-btn\""
assert_not_contains "$page_html" "id=\"assay-task-list\""

# Styling contract for settings controls.
assert_contains "$style" ".settings-inline-field {"

printf '%s\n' "artificer programmer-review contract tests passed"
