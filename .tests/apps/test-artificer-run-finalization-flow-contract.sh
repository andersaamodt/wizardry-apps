#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
app="$root/.web/artificer/static/artificer-app.js"
style="$root/.web/artificer/static/style.css"

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
assert_contains "$app" "function startAssistantDeliveryWatch(workspaceId, conversationId, messageAnchor, runEventId, fallbackAttemptHint)"
assert_contains "$app" "stopAssistantDeliveryWatchesForConversation(workspaceId, conversationId);"
assert_contains "$app" "recentlyFinishedWithoutAssistant = (Date.now() - finishedAtMs) <= 90000;"
assert_contains "$app" "var latestRunEvent = findLatestRunEventByStatus(conversationId, [\"running\", \"done\", \"awaiting_decision\", \"awaiting_approval\", \"error\", \"cancelled\"]);"
assert_contains "$app" "var shouldShowFinalizingLine = false;"
assert_contains "$app" "var eventAwaitingAssistant = Number(event.awaiting_assistant || 0) > 0;"
assert_contains "$app" "if (eventAwaitingAssistant || pendingAssistantDelivery || recentlyFinishedWithoutAssistant) {"
assert_contains "$app" "else if (isLatestRunEvent && !queueRunning && queuePending < 1 && !queueAwaitingApproval && !queueAwaitingDecision) {"
assert_contains "$app" "} else if (shouldShowFinalizingLine) {"
assert_contains "$app" "!assistantText &&"
assert_contains "$app" "!conversationHasAssistantAfterAnchor(workspaceId, conversationId, runAnchor)"
assert_contains "$app" "assistantText = structuredRunFallbackMessage(fallbackAttemptCount);"
assert_contains "$app" "needsAssistantDeliveryWatch = ("
assert_contains "$app" "pendingEvent.awaiting_assistant = (!assistantText && !awaitingApproval && !awaitingDecision) ? 1 : 0;"
assert_contains "$app" "startAssistantDeliveryWatch("
assert_contains "$app" "pendingEvent.awaiting_assistant = 1;"
assert_contains "$app" "if (assistantText) {"
assert_contains "$app" "appendAssistantMessageOptimistic(workspaceId, conversationId, assistantText);"
assert_contains "$app" "function prettifyRunStepText(rawText)"
assert_contains "$app" "text = text.replace(/^MODE_UPDATE:\\s*/i, \"Mode update: \");"
assert_contains "$app" "if (status !== \"running\" && status !== \"awaiting_approval\" && status !== \"awaiting_decision\") {"
assert_contains "$style" ".run-thinking {"
assert_contains "$style" "border-top: 0;"
assert_contains "$style" ".run-details > summary::before {"
assert_contains "$style" "content: none;"
assert_contains "$style" ".run-rollup > summary {"
assert_contains "$style" "justify-content: flex-start;"

printf '%s\n' "artificer run-finalization flow contract tests passed"
