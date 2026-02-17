#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
shell_adapter="$ROOT_DIR/adapters/shell-reference/rpc-shell-reference"
http_adapter="$ROOT_DIR/adapters/http-cgi/wizardry-core-api"

state_shell=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-shell-parity.XXXXXX")
state_http=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-http-parity.XXXXXX")
vault_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-vault-parity.XXXXXX")

cleanup() {
  rm -rf "$state_shell" "$state_http" "$vault_dir"
}
trap cleanup EXIT HUP INT TERM

http_rpc() {
  body=$1
  CONTENT_LENGTH=$(printf '%s' "$body" | wc -c | tr -d ' ') \
  REQUEST_METHOD=POST \
  WIZARDRY_HTTP_CGI_STATE_DIR="$state_http" \
  sh -c "printf '%s' '$body' | '$http_adapter'"
}

http_result() {
  body=$1
  http_rpc "$body" | sed -n '/^\r$/,$p' | sed '1d'
}

# mount both adapters to same vault
WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" vault.mount "$vault_dir" >/dev/null
mount_body=$(jq -n --arg p "$vault_dir" '{jsonrpc:"2.0",id:1,method:"vault.mount",params:{path:$p}}')
http_result "$mount_body" >/dev/null

shell_write=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" doc.write notes/p.md hello)
http_write=$(http_result '{"jsonrpc":"2.0","id":2,"method":"doc.write","params":{"path":"notes/p.md","content":"hello"}}')
printf '%s' "$shell_write" | grep -q '"written":true'
printf '%s' "$http_write" | grep -q '"written":true'

shell_read=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" doc.read notes/p.md)
http_read=$(http_result '{"jsonrpc":"2.0","id":3,"method":"doc.read","params":{"path":"notes/p.md"}}')
printf '%s' "$shell_read" | grep -q '"content":"hello"'
printf '%s' "$http_read" | grep -q '"content":"hello"'

WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" meta.set notes/p.md user.tag alpha >/dev/null
http_result '{"jsonrpc":"2.0","id":4,"method":"meta.set","params":{"path":"notes/p.md","key":"user.tag","value":"alpha"}}' >/dev/null

shell_meta=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" meta.get notes/p.md user.tag)
http_meta=$(http_result '{"jsonrpc":"2.0","id":5,"method":"meta.get","params":{"path":"notes/p.md","key":"user.tag"}}')
printf '%s' "$shell_meta" | grep -q '"value":"alpha"'
printf '%s' "$http_meta" | grep -q '"value":"alpha"'

shell_begin=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" txn.begin)
http_begin=$(http_result '{"jsonrpc":"2.0","id":6,"method":"txn.begin"}')
printf '%s' "$shell_begin" | grep -q '"opened":true'
printf '%s' "$http_begin" | grep -q '"opened":true'

shell_commit=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" txn.commit)
http_commit=$(http_result '{"jsonrpc":"2.0","id":7,"method":"txn.commit"}')
printf '%s' "$shell_commit" | grep -q '"committed":true'
printf '%s' "$http_commit" | grep -q '"committed":true'

printf '%s\n' "shell/http parity checks passed"
