#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
bridge="$ROOT_DIR/.apps/.host/shared/wizardry-bridge.js"

[ -f "$bridge" ] || {
  printf '%s\n' "bridge behavior checks failed: missing bridge source" >&2
  exit 1
}

# rpc promise lifecycle
rg -n "return new Promise" "$bridge" >/dev/null
rg -n "window\.__wizardry_callbacks\[id\]" "$bridge" >/dev/null

# success resolution and error rejection branches
rg -n "reject\(new Error\(" "$bridge" >/dev/null
rg -n "resolve\(payload && payload\.result \? payload\.result : payload\)" "$bridge" >/dev/null

# desktop compatibility path
rg -n "method === 'bridge\.exec'" "$bridge" >/dev/null
rg -n "post\(\{ id: id, command: params\.argv \}\)" "$bridge" >/dev/null
rg -n "stderr: 'native bridge unavailable'" "$bridge" >/dev/null

# generic bridge unavailable branch
rg -n "native bridge unavailable or method unsupported" "$bridge" >/dev/null

# subscriptions and dispatch behavior
rg -n "subscribe: function" "$bridge" >/dev/null
rg -n "window\.__wizardry_subscriptions\[token\] =" "$bridge" >/dev/null
rg -n "unsubscribe: function" "$bridge" >/dev/null
rg -n "delete window\.__wizardry_subscriptions\[token\]" "$bridge" >/dev/null
rg -n "window\.__wizardry_emit = function" "$bridge" >/dev/null
rg -n "Object\.keys\(window\.__wizardry_subscriptions\)" "$bridge" >/dev/null
rg -n "sub\.fn\(payload\)" "$bridge" >/dev/null

printf '%s\n' "bridge behavior checks passed"
