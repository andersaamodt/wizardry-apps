#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
index="$root/apps/chatroom/index.html"

[ -f "$index" ] || {
  printf '%s\n' "chatroom index missing" >&2
  exit 1
}

[ ! -f "$root/apps/chatroom/settings.html" ] || {
  printf '%s\n' "chatroom settings must live in the main shell, not settings.html" >&2
  exit 1
}

if grep -E 'settings-frame|settings-iframe|settings[.]html' "$index" >/dev/null 2>&1; then
  printf '%s\n' "chatroom still references split settings shell" >&2
  exit 1
fi

if grep -F "['sh', '-c'" "$index" >/dev/null 2>&1 || grep -F '"sh", "-c"' "$index" >/dev/null 2>&1; then
  printf '%s\n' "chatroom frontend still uses shell-fragment bridge fallback" >&2
  exit 1
fi

if grep -F "/cgi/system-info" "$index" >/dev/null 2>&1; then
  printf '%s\n' "chatroom frontend still scrapes generic CGI machine state" >&2
  exit 1
fi

if awk '
  /async function readEndpoint[(]/ { in_read = 1 }
  in_read && /^    }$/ { in_read = 0 }
  in_read && /setPref|persistChatUrl|set-ui-pref/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$index"; then
  printf '%s\n' "chatroom endpoint read path still writes durable prefs" >&2
  exit 1
fi

if ! grep -F "get-network-info" "$index" >/dev/null 2>&1; then
  printf '%s\n' "chatroom UI does not use backend network info contract" >&2
  exit 1
fi

printf '%s\n' "chatroom UI contract tests passed"
