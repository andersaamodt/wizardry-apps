#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/chatroom/scripts/chatroom-backend.sh"
tmp_home=$(mktemp -d "${TMPDIR:-/tmp}/chatroom-backend-home.XXXXXX")
trap 'rm -rf "$tmp_home"' EXIT HUP INT TERM

[ -f "$backend" ] || {
  printf '%s\n' "chatroom backend missing: $backend" >&2
  exit 1
}

sh -n "$backend"

if HOME="$tmp_home" sh "$backend" set-ui-pref "ab/key" value >/tmp/chatroom-invalid-pref.out 2>/tmp/chatroom-invalid-pref.err; then
  printf '%s\n' "chatroom backend accepted invalid UI pref key" >&2
  exit 1
fi
grep -F "invalid key" /tmp/chatroom-invalid-pref.err >/dev/null 2>&1 || {
  printf '%s\n' "chatroom invalid key error missing" >&2
  exit 1
}

valid_out=$(HOME="$tmp_home" sh "$backend" set-ui-pref "theme.id" "adept")
printf '%s\n' "$valid_out" | grep -F "key=theme.id" >/dev/null
prefs=$(HOME="$tmp_home" sh "$backend" get-ui-prefs)
printf '%s\n' "$prefs" | grep -F "theme.id=adept" >/dev/null

printf '%s\n' "chatroom backend tests passed"
