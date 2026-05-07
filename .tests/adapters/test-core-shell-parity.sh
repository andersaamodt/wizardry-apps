#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
shell_adapter="$ROOT_DIR/runtime/adapters/shell-reference/rpc-shell-reference"
out_dir="$ROOT_DIR/_tmp/core-parity"
core_bin="$out_dir/rpc_session"

state_shell=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-shell-parity.XXXXXX")
vault_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-vault-parity.XXXXXX")

cleanup() {
  rm -rf "$state_shell" "$vault_dir"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$out_dir"
cc -std=c99 -Wall -Wextra -Werror \
  -I"$ROOT_DIR/runtime/core/include" \
  "$ROOT_DIR/runtime/core/src/wizardry_core.c" \
  "$ROOT_DIR/runtime/core/tests/rpc_session.c" \
  -o "$core_bin"

core_req() {
  id=$1
  method=$2
  params=${3-}

  if [ -n "$params" ]; then
    jq -cn --argjson id "$id" --arg m "$method" --argjson p "$params" '{jsonrpc:"2.0",id:$id,method:$m,params:$p}'
  else
    jq -cn --argjson id "$id" --arg m "$method" '{jsonrpc:"2.0",id:$id,method:$m}'
  fi
}

assert_eq() {
  got=$1
  want=$2
  label=$3
  [ "$got" = "$want" ] || {
    printf '%s\n' "parity mismatch [$label]: got=$got want=$want" >&2
    exit 1
  }
}

# shell adapter state
WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" \
WIZARDRY_SHELL_REF_VAULT="$vault_dir" \
"$shell_adapter" vault.mount "$vault_dir" >/dev/null

shell_ping=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" core.ping)
shell_write=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" doc.write notes/p.md hello)
shell_read=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" doc.read notes/p.md)
shell_list=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" doc.list notes)
shell_mset=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" meta.set notes/p.md user.tag alpha)
shell_mget=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" meta.get notes/p.md user.tag)
shell_munset=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" meta.unset notes/p.md user.tag)
shell_mget2=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" meta.get notes/p.md user.tag)
shell_begin=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" txn.begin)
shell_commit=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" txn.commit)
shell_del=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" doc.delete notes/p.md)

set +e
shell_rollback=$(WIZARDRY_SHELL_REF_STATE_DIR="$state_shell" "$shell_adapter" txn.rollback 2>/dev/null)
shell_rollback_status=$?
set -e

# core rpc session on same method matrix
req1=$(core_req 1 vault.mount "$(jq -cn --arg p "$vault_dir" '{path:$p}')")
req2=$(core_req 2 core.ping)
req3=$(core_req 3 doc.write '{"path":"notes/p.md","content":"hello"}')
req4=$(core_req 4 doc.read '{"path":"notes/p.md"}')
req5=$(core_req 5 doc.list '{"path":"notes"}')
req6=$(core_req 6 meta.set '{"path":"notes/p.md","key":"user.tag","value":"alpha"}')
req7=$(core_req 7 meta.get '{"path":"notes/p.md","key":"user.tag"}')
req8=$(core_req 8 meta.unset '{"path":"notes/p.md","key":"user.tag"}')
req9=$(core_req 9 meta.get '{"path":"notes/p.md","key":"user.tag"}')
req10=$(core_req 10 txn.begin)
req11=$(core_req 11 txn.commit)
req12=$(core_req 12 txn.rollback)
req13=$(core_req 13 doc.delete '{"path":"notes/p.md"}')

core_out=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
  "$req1" "$req2" "$req3" "$req4" "$req5" "$req6" "$req7" "$req8" "$req9" "$req10" "$req11" "$req12" "$req13" | "$core_bin")

core_ping=$(printf '%s\n' "$core_out" | sed -n '2p')
core_write=$(printf '%s\n' "$core_out" | sed -n '3p')
core_read=$(printf '%s\n' "$core_out" | sed -n '4p')
core_list=$(printf '%s\n' "$core_out" | sed -n '5p')
core_mset=$(printf '%s\n' "$core_out" | sed -n '6p')
core_mget=$(printf '%s\n' "$core_out" | sed -n '7p')
core_munset=$(printf '%s\n' "$core_out" | sed -n '8p')
core_mget2=$(printf '%s\n' "$core_out" | sed -n '9p')
core_begin=$(printf '%s\n' "$core_out" | sed -n '10p')
core_commit=$(printf '%s\n' "$core_out" | sed -n '11p')
core_rollback=$(printf '%s\n' "$core_out" | sed -n '12p')
core_del=$(printf '%s\n' "$core_out" | sed -n '13p')

assert_eq "$(printf '%s' "$core_ping" | jq -r '.result.ok')" "$(printf '%s' "$shell_ping" | jq -r '.ok')" "ping.ok"
assert_eq "$(printf '%s' "$core_write" | jq -r '.result.written')" "$(printf '%s' "$shell_write" | jq -r '.written')" "doc.write"
assert_eq "$(printf '%s' "$core_read" | jq -r '.result.content')" "$(printf '%s' "$shell_read" | jq -r '.content')" "doc.read.content"
assert_eq "$(printf '%s' "$core_read" | jq -r '.result.path')" "$(printf '%s' "$shell_read" | jq -r '.path')" "doc.read.path"
assert_eq "$(printf '%s' "$core_list" | jq -r '.result.docs[0]')" "$(printf '%s' "$shell_list" | jq -r '.docs[0]')" "doc.list.first"
assert_eq "$(printf '%s' "$core_mset" | jq -r '.result.set')" "$(printf '%s' "$shell_mset" | jq -r '.set')" "meta.set"
assert_eq "$(printf '%s' "$core_mget" | jq -r '.result.value')" "$(printf '%s' "$shell_mget" | jq -r '.value')" "meta.get.value"
assert_eq "$(printf '%s' "$core_munset" | jq -r '.result.unset')" "$(printf '%s' "$shell_munset" | jq -r '.unset')" "meta.unset"
assert_eq "$(printf '%s' "$core_mget2" | jq -r '.result.found')" "$(printf '%s' "$shell_mget2" | jq -r '.found')" "meta.get.found.after_unset"
assert_eq "$(printf '%s' "$core_begin" | jq -r '.result.opened')" "$(printf '%s' "$shell_begin" | jq -r '.opened')" "txn.begin"
assert_eq "$(printf '%s' "$core_commit" | jq -r '.result.committed')" "$(printf '%s' "$shell_commit" | jq -r '.committed')" "txn.commit"
assert_eq "$(printf '%s' "$core_del" | jq -r '.result.deleted')" "$(printf '%s' "$shell_del" | jq -r '.deleted')" "doc.delete"

# rollback after commit should error in both implementations
[ "$shell_rollback_status" -ne 0 ] || {
  printf '%s\n' "expected shell rollback failure after commit" >&2
  exit 1
}
printf '%s' "$core_rollback" | jq -e '.error.code == -32600' >/dev/null

printf '%s\n' "core/shell parity matrix passed"
