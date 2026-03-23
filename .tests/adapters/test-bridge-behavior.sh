#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
bridge="$ROOT_DIR/apps/.host/shared/wizardry-bridge.js"

[ -f "$bridge" ] || {
  printf '%s\n' "bridge behavior checks failed: missing bridge source" >&2
  exit 1
}

assert_contains() {
  file=$1
  needle=$2
  if ! grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected bridge behavior text in $file: $needle" >&2
    exit 1
  fi
}

assert_matches() {
  file=$1
  pattern=$2
  if ! grep -E "$pattern" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected bridge behavior pattern in $file: $pattern" >&2
    exit 1
  fi
}

# Promise lifecycle + callback dispatch.
assert_matches "$bridge" 'return new Promise\(function \(resolve\)'
assert_contains "$bridge" 'window.__wizardry_callbacks[id] = function (payload) {'
assert_contains "$bridge" 'resolve(payload || {'

# Fallback behavior when native bridge is unavailable.
assert_contains "$bridge" "stderr: 'native bridge unavailable'"
assert_contains "$bridge" 'exit_code: 1'
assert_contains "$bridge" 'setTimeout(function () {'

# RPC wrapper behavior should only allow bridge.exec and normalize argv payload.
assert_contains "$bridge" "if (method !== 'bridge.exec')"
assert_contains "$bridge" "unsupported rpc method"
assert_contains "$bridge" 'Array.isArray(payload.argv)'
assert_contains "$bridge" 'argv = payload.argv;'

# Transport behavior must post command + callback id through native bridge.
assert_contains "$bridge" 'post({ id: id, command: argv })'
assert_contains "$bridge" 'window.webkit.messageHandlers.wizardry.postMessage(message);'
assert_contains "$bridge" 'window.WizardryBridge.postMessage(JSON.stringify(message));'

printf '%s\n' "bridge behavior checks passed"
