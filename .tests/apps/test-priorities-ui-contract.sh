#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app="$root/.apps/priorities/index.html"

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
assert_contains "out.push(pagePath.slice(0, idx) + '/.apps/priorities/scripts/priorities-backend.sh');"
assert_contains "function isMissingBackendScriptError(error)"

# Copy button contract.
assert_contains "id=\"copy-markdown\""
assert_contains "function copyVisiblePrioritiesAsMarkdown()"
assert_contains "lines.push(new Array(depth + 1).join('  ') + '- [' + checked + '] ' + name);"

# Checkbox action contract.
assert_contains "function actToggleChecked(path)"
assert_contains "['check-toggle-fast', path]"
assert_contains "['check-toggle', path]"

# Width auto-grow should not read status text width.
if sed -n '/function computeAutoWindowWidthFromContent()/,/^    }/p' "$app" | grep -F "statusEl" >/dev/null 2>&1; then
  fail "computeAutoWindowWidthFromContent should not include status element width"
fi

printf '%s\n' "priorities ui contract tests passed"
