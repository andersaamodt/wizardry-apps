#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
adapter="$ROOT_DIR/adapters/http-cgi/wizardry-core-api"
state_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-httpcgi-test.XXXXXX")
vault_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-httpcgi-vault.XXXXXX")

cleanup() {
  rm -rf "$state_dir" "$vault_dir"
}
trap cleanup EXIT HUP INT TERM

rpc() {
  body=$1
  CONTENT_LENGTH=$(printf '%s' "$body" | wc -c | tr -d ' ') \
  REQUEST_METHOD=POST \
  WIZARDRY_HTTP_CGI_STATE_DIR="$state_dir" \
  sh -c "printf '%s' '$body' | '$adapter'"
}

# ping
out=$(rpc '{"jsonrpc":"2.0","id":1,"method":"core.ping"}')
printf '%s' "$out" | grep -q 'Content-Type: application/json'
printf '%s' "$out" | grep -q '"ok":true'

# mount vault
mount_body=$(jq -n --arg p "$vault_dir" '{jsonrpc:"2.0",id:2,method:"vault.mount",params:{path:$p}}')
out=$(rpc "$mount_body")
printf '%s' "$out" | grep -q '"mounted":true'

# write/read
write_body='{"jsonrpc":"2.0","id":3,"method":"doc.write","params":{"path":"notes/a.md","content":"hello"}}'
out=$(rpc "$write_body")
printf '%s' "$out" | grep -q '"written":true'

read_body='{"jsonrpc":"2.0","id":4,"method":"doc.read","params":{"path":"notes/a.md"}}'
out=$(rpc "$read_body")
printf '%s' "$out" | grep -q '"path":"notes/a.md"'
printf '%s' "$out" | grep -q '"content":"hello"'

# meta set/get/unset
meta_set='{"jsonrpc":"2.0","id":5,"method":"meta.set","params":{"path":"notes/a.md","key":"user.tag","value":"alpha"}}'
out=$(rpc "$meta_set")
printf '%s' "$out" | grep -q '"set":true'

meta_get='{"jsonrpc":"2.0","id":6,"method":"meta.get","params":{"path":"notes/a.md","key":"user.tag"}}'
out=$(rpc "$meta_get")
printf '%s' "$out" | grep -q '"found":true'
printf '%s' "$out" | grep -q '"value":"alpha"'

meta_unset='{"jsonrpc":"2.0","id":7,"method":"meta.unset","params":{"path":"notes/a.md","key":"user.tag"}}'
out=$(rpc "$meta_unset")
printf '%s' "$out" | grep -q '"unset":true'

# list/delete
list_body='{"jsonrpc":"2.0","id":8,"method":"doc.list","params":{"path":"notes"}}'
out=$(rpc "$list_body")
printf '%s' "$out" | grep -q 'notes/a.md'

del_body='{"jsonrpc":"2.0","id":9,"method":"doc.delete","params":{"path":"notes/a.md"}}'
out=$(rpc "$del_body")
printf '%s' "$out" | grep -q '"deleted":true'

# txn lifecycle
begin='{"jsonrpc":"2.0","id":10,"method":"txn.begin"}'
commit='{"jsonrpc":"2.0","id":11,"method":"txn.commit"}'
out=$(rpc "$begin")
printf '%s' "$out" | grep -q '"opened":true'
out=$(rpc "$commit")
printf '%s' "$out" | grep -q '"committed":true'

# sse endpoint
sse=$(REQUEST_METHOD=GET QUERY_STRING='stream=events' WIZARDRY_HTTP_CGI_STATE_DIR="$state_dir" "$adapter")
printf '%s' "$sse" | grep -q 'Content-Type: text/event-stream'
printf '%s' "$sse" | grep -q 'event: vaultMounted'

printf '%s\n' "http-cgi adapter tests passed"
