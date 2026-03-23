#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
bridge="$ROOT_DIR/apps/.host/shared/wizardry-bridge.js"
android="$ROOT_DIR/apps/.host/android/app/src/main/java/com/wizardry/apps/host/MainActivity.kt"
ios="$ROOT_DIR/apps/.host/ios/Host/WizardryWebView.swift"

[ -f "$bridge" ]
[ -f "$android" ]
[ -f "$ios" ]

assert_contains() {
  file=$1
  needle=$2
  if ! grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected bridge contract text in $file: $needle" >&2
    exit 1
  fi
}

assert_matches() {
  file=$1
  pattern=$2
  if ! grep -E "$pattern" "$file" >/dev/null 2>&1; then
    printf '%s\n' "missing expected bridge contract pattern in $file: $pattern" >&2
    exit 1
  fi
}

# Shared JS bridge API contract.
assert_contains "$bridge" 'window.__wizardry_callbacks'
assert_matches "$bridge" 'function execCommand\(argv\)'
assert_matches "$bridge" 'window\.wizardry\.exec = execCommand;'
assert_matches "$bridge" 'window\.wizardry\.rpc = rpcBridge;'
assert_contains "$bridge" "method !== 'bridge.exec'"
assert_contains "$bridge" "unsupported rpc method"

# Shared bridge transport should support both iOS and Android message paths.
assert_contains "$bridge" 'window.webkit.messageHandlers.wizardry'
assert_contains "$bridge" 'window.WizardryBridge.postMessage'

# Mobile hosts must expose native message handlers.
assert_contains "$android" '@JavascriptInterface'
assert_contains "$android" 'fun postMessage(payload: String)'
assert_contains "$ios" 'WKScriptMessageHandler'
assert_contains "$ios" 'userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)'

# Both native hosts should wire core v1 method names.
for m in core.ping vault.mount vault.info txn.begin txn.commit txn.rollback; do
  assert_contains "$android" "\"$m\""
  assert_contains "$ios" "\"$m\""
done

printf '%s\n' "bridge contract checks passed"
