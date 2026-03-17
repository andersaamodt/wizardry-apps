#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app_dir="$root/apps/chatroom"
backend="$app_dir/scripts/chatroom-backend.sh"
demo_chat="$root/web/demo/pages/chat.md"
app_chat="$app_dir/chat.md"
app_style="$app_dir/chatroom.css"

[ -d "$app_dir" ]
[ -f "$app_dir/index.html" ]
[ -f "$app_dir/settings.html" ]
[ -f "$app_chat" ]
[ -f "$app_style" ]
[ -f "$backend" ]
[ -f "$demo_chat" ]

grep -F '<link rel="stylesheet" href="/static/chatroom.css" />' "$app_chat" >/dev/null
grep -F 'pages/chatroom-app.html' "$backend" >/dev/null
grep -F 'sync_chatroom_app_assets' "$backend" >/dev/null
grep -F "const CHAT_PATH = '/pages/chatroom-app.html';" "$app_dir/index.html" >/dev/null
grep -F "const CLIENT_CHAT_URL_KEY = 'client_chat_url';" "$app_dir/index.html" >/dev/null
grep -F 'Chatroom Controls' "$app_dir/index.html" >/dev/null
grep -F "window.location.replace('index.html#settings');" "$app_dir/settings.html" >/dev/null
if rg -F 'chat-tab' "$app_dir/index.html" >/dev/null 2>&1; then
  printf '%s\n' "legacy tab shell still present in $app_dir/index.html" >&2
  exit 1
fi

printf '%s\n' "chatroom contract tests passed"
