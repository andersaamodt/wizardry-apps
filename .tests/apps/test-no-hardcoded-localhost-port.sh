#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

fail=0
for f in \
  "$root/apps/artificer/index.html" \
  "$root/apps/unix-settings/index.html" \
  "$root/apps/chatroom/index.html" \
  "$root/apps/chatroom/settings.html"; do
  if rg -n "localhost:8080" "$f" >/dev/null 2>&1; then
    printf '%s\n' "hardcoded localhost:8080 detected in $f" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ]
printf '%s\n' "desktop app port-hardcode guard tests passed"
