#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
api="$root/.web/artificer/cgi/artificer-api"
page_html="$root/.web/artificer/pages/index.html"
page_md="$root/.web/artificer/pages/index.md"
ui_js="$root/.web/artificer/static/artificer-app.js"
ui_js_source="$root/.web/artificer/static/app.js"
style="$root/.web/artificer/static/style.css"
readme="$root/.web/artificer/README.md"

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

assert_file "$api"
assert_file "$page_html"
assert_file "$page_md"
assert_file "$ui_js"
assert_file "$ui_js_source"
assert_file "$style"
assert_file "$readme"

assert_contains "$api" 'DICTATE_BIN=${DICTATE_BIN:-$WIZARDRY_DIR/spells/psi/dictate}'
assert_contains "$api" "resolve_dictate_bin()"
assert_contains "$api" "  dictate)"
assert_contains "$api" "run_with_timeout \"\$timeout_sec\" \"\$@\" > \"\$dictate_output_file\" 2> \"\$dictate_error_file\""
assert_contains "$api" "printf '{\"success\":true,\"text\":\"%s\"}\\n' \"\$(json_escape \"\$dictated_text\")\""

dictate_block=$(awk '
  /(^|[[:space:]])dictate\)/ { in_block = 1 }
  in_block { print }
  in_block && /^[[:space:]]*;;[[:space:]]*$/ { exit }
' "$api")
printf '%s\n' "$dictate_block" | grep -F 'param "command"' >/dev/null 2>&1 && fail "dictate action must not read command text from request"

assert_contains "$page_html" 'id="dictate-btn"'
assert_contains "$page_md" 'id="dictate-btn"'
assert_contains "$style" ".dictate-btn {"
assert_contains "$style" ".dictate-btn.recording {"

assert_contains "$ui_js" 'dictateBtn: document.getElementById("dictate-btn"),'
assert_contains "$ui_js" "function renderDictateButton()"
assert_contains "$ui_js" "safeStep(\"renderDictateButton\", renderDictateButton);"
assert_contains "$ui_js" "function onDictateClick(event)"
assert_contains "$ui_js" "apiPost(\"dictate\", { duration: \"20\" }, { timeoutMs: 220000 })"
assert_contains "$ui_js" "insertTextAtCursor(el.runPrompt, dictatedText);"
assert_contains "$ui_js" "dispatchInputEvent(el.runPrompt);"

assert_contains "$ui_js_source" "function onDictateClick(event)"
assert_contains "$ui_js_source" "apiPost(\"dictate\", { duration: \"20\" }, { timeoutMs: 220000 })"

assert_contains "$readme" '- `dictate` (POST)'

printf '%s\n' "artificer dictation contract tests passed"
