#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
app="$root/.web/artificer/static/artificer-app.js"

assert_contains() {
  file=$1
  needle=$2
  if ! rg -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "assertion failed: expected to find '$needle' in $file" >&2
    exit 1
  fi
}

# Guardrails for delayed assistant delivery UX:
# - helper exists to verify whether an assistant message has landed after the run anchor
# - run narrative keeps a short grace-period finalizing hint even if pending flags race
# - structured fallback is deferred until after conversation reload check
assert_contains "$app" "function conversationHasAssistantAfterAnchor(workspaceId, conversationId, messageAnchor)"
assert_contains "$app" "recentlyFinishedWithoutAssistant = (Date.now() - finishedAtMs) <= 90000;"
assert_contains "$app" "(pendingAssistantDelivery || recentlyFinishedWithoutAssistant) && !hasAssistantAfterAnchor"
assert_contains "$app" "!assistantText &&"
assert_contains "$app" "!conversationHasAssistantAfterAnchor(workspaceId, conversationId, runAnchor)"
assert_contains "$app" "assistantText = structuredRunFallbackMessage(fallbackAttemptCount);"
assert_contains "$app" "if (assistantText) {"
assert_contains "$app" "appendAssistantMessageOptimistic(workspaceId, conversationId, assistantText);"

printf '%s\n' "artificer run-finalization flow contract tests passed"
