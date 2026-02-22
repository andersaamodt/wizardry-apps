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
assert_contains "$api" "resolve_voice_recognition_install_bin()"
assert_contains "$api" "  dictate)"
assert_contains "$api" "  dictation_status)"
assert_contains "$api" "  dictation_uninstall)"
assert_contains "$api" "  dictation_install_info)"
assert_contains "$api" "  dictation_install_start)"
assert_contains "$api" "  dictation_install_status)"
assert_contains "$api" "  dictation_install)"
assert_contains "$api" "run_with_timeout \"\$timeout_sec\" \"\$@\" > \"\$dictate_output_file\" 2> \"\$dictate_error_file\""
assert_contains "$api" "printf '{\"success\":true,\"text\":\"%s\"}\\n' \"\$(json_escape \"\$dictated_text\")\""
assert_contains "$api" "preferred_voice_component_for_host()"
assert_contains "$api" "\"downloaded_bytes\":\"%s\""
assert_contains "$api" "run_with_timeout 1800 \"\$install_bin\" 2>&1"

dictate_block=$(awk '
  /(^|[[:space:]])dictate\)/ { in_block = 1 }
  in_block { print }
  in_block && /^[[:space:]]*;;[[:space:]]*$/ { exit }
' "$api")
printf '%s\n' "$dictate_block" | grep -F 'param "command"' >/dev/null 2>&1 && fail "dictate action must not read command text from request"

assert_contains "$page_html" 'id="dictate-btn"'
assert_contains "$page_md" 'id="dictate-btn"'
assert_contains "$page_html" 'id="install-dictation-btn"'
assert_contains "$page_md" 'id="install-dictation-btn"'
assert_contains "$page_html" 'id="dictation-install-status"'
assert_contains "$page_md" 'id="dictation-install-status"'
assert_contains "$style" ".dictate-btn {"
assert_contains "$style" ".dictate-btn.recording {"
assert_contains "$style" ".modal-actions.modal-actions-compact {"
assert_contains "$style" "#dictation-install-status.error {"

assert_contains "$ui_js" 'dictateBtn: document.getElementById("dictate-btn"),'
assert_contains "$ui_js" 'installDictationBtn: document.getElementById("install-dictation-btn"),'
assert_contains "$ui_js" 'dictationInstallStatus: document.getElementById("dictation-install-status"),'
assert_contains "$ui_js" "function renderDictateButton()"
assert_contains "$ui_js" "safeStep(\"renderDictateButton\", renderDictateButton);"
assert_contains "$ui_js" "safeStep(\"renderDictationInstallSettings\", renderDictationInstallSettings);"
assert_contains "$ui_js" 'dictationInstallReady: false,'
assert_contains "$ui_js" 'dictationInstalled: false,'
assert_contains "$ui_js" 'var DICTATION_INSTALL_SIZE_LABEL = "1.4 GB";'
assert_contains "$ui_js" 'return "Install dictation (" + DICTATION_INSTALL_SIZE_LABEL + ")";'
assert_contains "$ui_js" "function dictationInstallRunningButtonLabel(job)"
assert_contains "$ui_js" "function dictationDownloadAmountLabel(job)"
assert_contains "$ui_js" "label += \" (\" + sizeText + \")\";"
assert_contains "$ui_js" "el.installDictationBtn.disabled = !state.dictationInstallReady || state.dictationInstallInfoLoading || busy;"
assert_contains "$ui_js" "buttonLabel = \"Checking...\";"
assert_contains "$ui_js" "el.installDictationBtn.classList.toggle(\"ui-pending-spinner\", showPending);"
assert_contains "$ui_js" "state.dictationInstallReady = false;"
assert_contains "$ui_js" "state.dictationInstallReady = true;"
assert_contains "$ui_js" "function loadDictationStatus(options)"
assert_contains "$ui_js" "apiGet(\"dictation_status\", {}, { timeoutMs: 12000 })"
assert_contains "$ui_js" "function onDictateClick(event)"
assert_contains "$ui_js" "apiPost(\"dictate\", { duration: \"20\" }, { timeoutMs: 220000 })"
assert_contains "$ui_js" "function installDictationSoftware()"
assert_contains "$ui_js" "function uninstallDictationSoftware()"
assert_contains "$ui_js" "function toggleDictationSoftware()"
assert_contains "$ui_js" "apiPost(\"dictation_install_start\", {}, { timeoutMs: 12000 })"
assert_contains "$ui_js" "apiPost(\"dictation_uninstall\", {}, { timeoutMs: 12000 })"
assert_contains "$ui_js" "apiGet(\"dictation_install_status\", { job_id: id }, { timeoutMs: 12000 })"
assert_contains "$ui_js" "insertTextAtCursor(el.runPrompt, dictatedText);"
assert_contains "$ui_js" "dispatchInputEvent(el.runPrompt);"

assert_contains "$ui_js_source" "function onDictateClick(event)"
assert_contains "$ui_js_source" "apiPost(\"dictate\", { duration: \"20\" }, { timeoutMs: 220000 })"
assert_contains "$ui_js_source" 'dictationInstallStatus: document.getElementById("dictation-install-status"),'
assert_contains "$ui_js_source" 'dictationInstallReady: false,'
assert_contains "$ui_js_source" 'dictationInstalled: false,'
assert_contains "$ui_js_source" 'var DICTATION_INSTALL_SIZE_LABEL = "1.4 GB";'
assert_contains "$ui_js_source" 'return "Install dictation (" + DICTATION_INSTALL_SIZE_LABEL + ")";'
assert_contains "$ui_js_source" "function dictationDownloadAmountLabel(job)"
assert_contains "$ui_js_source" "label += \" (\" + sizeText + \")\";"
assert_contains "$ui_js_source" "el.installDictationBtn.disabled = !state.dictationInstallReady || state.dictationInstallInfoLoading || busy;"
assert_contains "$ui_js_source" "buttonLabel = \"Checking...\";"
assert_contains "$ui_js_source" "el.installDictationBtn.classList.toggle(\"ui-pending-spinner\", showPending);"
assert_contains "$ui_js_source" "function loadDictationStatus(options)"
assert_contains "$ui_js_source" "apiGet(\"dictation_status\", {}, { timeoutMs: 12000 })"
assert_contains "$ui_js_source" "apiPost(\"dictation_install_start\", {}, { timeoutMs: 12000 })"
assert_contains "$ui_js_source" "apiPost(\"dictation_uninstall\", {}, { timeoutMs: 12000 })"
assert_contains "$ui_js_source" "apiGet(\"dictation_install_status\", { job_id: id }, { timeoutMs: 12000 })"

assert_contains "$readme" '- `dictate` (POST)'
assert_contains "$readme" '- `dictation_status` (GET)'
assert_contains "$readme" '- `dictation_uninstall` (POST)'
assert_contains "$readme" '- `dictation_install_info` (GET)'
assert_contains "$readme" '- `dictation_install_start` (POST)'
assert_contains "$readme" '- `dictation_install_status` (GET)'

printf '%s\n' "artificer dictation contract tests passed"
