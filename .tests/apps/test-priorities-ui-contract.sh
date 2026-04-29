#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app_dir="$root/apps/priorities"
app="$app_dir/index.html"

[ -d "$app_dir" ] || {
  printf '%s\n' "skip: optional priorities app is not checked out"
  exit 0
}

[ -f "$app" ] || {
  printf '%s\n' "priorities app file missing: $app" >&2
  exit 1
}

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  needle=$1
  if ! grep -F "$needle" "$app" >/dev/null 2>&1; then
    fail "missing expected contract text: $needle"
  fi
}

# Backend resolution must support bundled app path and workspace path.
assert_contains "function detectBackendScriptCandidates()"
assert_contains "var appMarker = '/priorities/index.html';"
assert_contains "out.push(pagePath.slice(0, appIdx) + '/priorities/scripts/priorities-backend.sh');"
assert_contains "out.push(pagePath.slice(0, idx) + '/apps/priorities/scripts/priorities-backend.sh');"
assert_contains "function isMissingBackendScriptError(error)"

# Copy button contract.
assert_contains "id=\"copy-markdown\""
assert_contains "function copyVisiblePrioritiesAsMarkdown()"
assert_contains "lines.push(new Array(depth + 1).join('  ') + '- [' + checked + '] ' + name);"

# Checkbox action contract.
assert_contains "function actToggleChecked(path)"
assert_contains "['check-toggle-fast', path]"
assert_contains "['check-toggle', path]"
assert_contains "var hadOptimisticTouch = optimisticTouches.length > 0;"
assert_contains "if (!hadOptimisticTouch) {"
assert_contains "Avoid a second full rerender when optimistic UI already matches"

# Add queue contract (no spinner lockstep with save).
assert_contains "addQueue: []"
assert_contains "addQueueActive: false"
assert_contains "function processAddQueue()"
assert_contains "state.addQueue.push({"
assert_contains "addBtn.textContent = '+';"
assert_contains "var hasName = String(input.value || '').trim().length > 0;"
assert_contains "addBtn.disabled = !hasName;"

# Next action startup cache contract.
assert_contains "var NEXT_ACTION_CACHE_KEY = 'wizardry.priorities.nextActionCache';"
assert_contains "function loadNextActionLabelCacheFromPrefs()"
assert_contains "function schedulePersistNextActionLabelCache()"
assert_contains "function setCachedNextActionLabel(path, label, checked)"
assert_contains "loadNextActionLabelCacheFromPrefs();"
assert_contains "return String((cachedEntry && cachedEntry.label) || '');"

# Make Project reveal behavior contract.
assert_contains "state.revealedMakeProjectPath = (state.revealedMakeProjectPath === item.path) ? '' : item.path;"
assert_contains "render({ suppressLoadingOverlay: true, animateReorder: true });"
assert_contains "var inMakeProject = event.target.closest('.make-project-inline');"
assert_contains "if (!inMakeProject && state.revealedMakeProjectPath && !state.pendingMakeProjectPath) {"

# Cached expand-open should background revalidate and patch if changed.
assert_contains "function revalidateDirInBackground(path)"
assert_contains "if (willOpen) {"
assert_contains "revalidateDirInBackground(path);"
assert_contains "if (listFingerprint(cachedItems) === listFingerprint(freshItems)) {"
assert_contains "upsertNextActionForPath(key);"

# Prioritize should be optimistic/direct (no queue push dependency).
assert_contains "function applyOptimisticPrioritize(dir, path)"
assert_contains "var previousItems = applyOptimisticPrioritize(parentDir, path);"
if grep -F "state.prioritizeQueue.push" "$app" >/dev/null 2>&1; then
  fail "actPrioritize should not enqueue prioritize actions"
fi

# Title double-click hidden open-folder action contract.
assert_contains "function openCurrentRootInFileBrowser()"
assert_contains "await runBackend(['open-dir', currentRoot]);"
assert_contains "titleFolder.addEventListener('dblclick', openTitleFolderIfDouble);"
assert_contains "titleFolder.addEventListener('mouseup', function (event) {"

# Width auto-grow should not read status text width.
if sed -n '/function computeAutoWindowWidthFromContent()/,/^    }/p' "$app" | grep -F "statusEl" >/dev/null 2>&1; then
  fail "computeAutoWindowWidthFromContent should not include status element width"
fi

printf '%s\n' "priorities ui contract tests passed"
