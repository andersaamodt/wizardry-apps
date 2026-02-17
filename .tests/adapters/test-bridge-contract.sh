#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
bridge="$ROOT_DIR/.apps/.host/shared/wizardry-bridge.js"
android="$ROOT_DIR/.apps/.host/android/app/src/main/java/com/wizardry/apps/host/MainActivity.kt"
ios="$ROOT_DIR/.apps/.host/ios/Host/WizardryWebView.swift"

[ -f "$bridge" ]
[ -f "$android" ]
[ -f "$ios" ]

# shared JS API contract
rg -n "window\.wizardry" "$bridge" >/dev/null
rg -n "rpc:\s*function" "$bridge" >/dev/null
rg -n "subscribe:\s*function" "$bridge" >/dev/null
rg -n "unsubscribe:\s*function" "$bridge" >/dev/null
rg -n "__wizardry_emit" "$bridge" >/dev/null

# desktop compatibility path
rg -n "bridge\.exec" "$bridge" >/dev/null

# mobile hosts must expose native message handlers
rg -n "@JavascriptInterface|postMessage\(" "$android" >/dev/null
rg -n "WKScriptMessageHandler|userContentController" "$ios" >/dev/null

# both native hosts should wire core v1 method names
for m in core.ping vault.mount vault.info txn.begin txn.commit txn.rollback; do
  rg -n "\"$m\"" "$android" >/dev/null
  rg -n "\"$m\"" "$ios" >/dev/null
done

printf '%s\n' "bridge contract checks passed"
