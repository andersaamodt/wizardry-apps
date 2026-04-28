#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: chatroom-backend.sh ACTION [ARGS...]

Actions:
  get-ui-prefs
  set-ui-pref KEY VALUE
  get-chat-endpoint
  check-chat [URL]
  start-server
  stop-server
USAGE
  exit 0
  ;;
esac

set -eu

config_file() {
  base="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/chatroom"
  mkdir -p "$base"
  printf '%s\n' "$base/config"
}

validate_key() {
  key=${1-}
  case "$key" in
    [a-z0-9]*)
      ;;
    *)
      printf '%s\n' "chatroom-backend: invalid key: $key" >&2
      exit 2
      ;;
  esac

  case "$key" in
    *[!a-z0-9._-]*)
      printf '%s\n' "chatroom-backend: invalid key: $key" >&2
      exit 2
      ;;
  esac
}

sanitize_value() {
  printf '%s' "${1-}" | tr '\r\n' ' '
}

demo_site_conf() {
  printf '%s\n' "$HOME/sites/demo/site.conf"
}

read_demo_port() {
  cfg=$(demo_site_conf)
  [ -f "$cfg" ] || return 1
  port=$(awk -F= '
    /^port=/ {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "$cfg")
  case "$port" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac
  printf '%s\n' "$port"
}

default_chat_url() {
  port=$(read_demo_port) || return 1
  printf 'http://localhost:%s/pages/chat.html\n' "$port"
}

find_chat_template() {
  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && [ -f "$WIZARDRY_APPS_ROOT/web/demo/pages/chat.md" ]; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT/web/demo/pages/chat.md"
    return 0
  fi
  if [ -n "${WIZARDRY_DIR-}" ] && [ -f "$WIZARDRY_DIR/web/demo/pages/chat.md" ]; then
    printf '%s\n' "$WIZARDRY_DIR/web/demo/pages/chat.md"
    return 0
  fi
  if [ -f "$HOME/git/wizardry-apps/web/demo/pages/chat.md" ]; then
    printf '%s\n' "$HOME/git/wizardry-apps/web/demo/pages/chat.md"
    return 0
  fi
  return 1
}

ensure_demo_site() {
  if [ ! -d "$HOME/sites/demo/site" ]; then
    web-wizardry create demo --template demo >/dev/null
  fi
}

ensure_demo_chat_page() {
  target="$HOME/sites/demo/site/pages/chat.md"
  if [ -f "$target" ]; then
    return 0
  fi
  src=$(find_chat_template) || {
    printf '%s\n' "chatroom-backend: chat template missing (expected web/demo/pages/chat.md in wizardry-apps root)" >&2
    exit 1
  }
  mkdir -p "$(dirname "$target")"
  cp "$src" "$target"
}

ensure_demo_built() {
  web-wizardry build demo >/dev/null
}

serve_demo_site() {
  if web-wizardry serve demo >/dev/null 2>&1; then
    return 0
  fi
  if web-wizardry status demo 2>/dev/null | grep -qi 'serving'; then
    return 0
  fi
  return 1
}

stop_demo_site() {
  if web-wizardry stop demo >/dev/null 2>&1; then
    return 0
  fi
  if web-wizardry status demo 2>/dev/null | grep -qi 'not serving'; then
    return 0
  fi
  return 1
}

is_http_url() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in
    *"$nl_char"*|*"$cr_char"*)
      return 1
      ;;
  esac
  case "$value" in
    http://*|https://*)
      return 0
      ;;
  esac
  return 1
}

probe_url() {
  url=${1-}
  [ -n "$url" ] || return 1

  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 2 "$url" >/dev/null 2>&1 && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q --spider --timeout=2 "$url" >/dev/null 2>&1 && return 0
  fi
  return 1
}

write_key_value_file() {
  file=$1
  key=$2
  value=$3

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/chatroom-kv.XXXXXX")
  found=0
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "$key="*)
          if [ "$found" -eq 0 ]; then
            printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
            found=1
          fi
          ;;
        *)
          printf '%s\n' "$line" >>"$tmp_file"
          ;;
      esac
    done <"$file"
  fi

  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
  fi
  mv "$tmp_file" "$file"
}

action=${1-}
if [ -z "$action" ]; then
  printf '%s\n' "chatroom-backend: action required" >&2
  exit 2
fi
shift || true

case "$action" in
  get-ui-prefs)
    cfg=$(config_file)
    [ -f "$cfg" ] && cat "$cfg"
    ;;
  set-ui-pref)
    key=${1-}
    value=${2-}
    [ -n "$key" ] || {
      printf '%s\n' "chatroom-backend: set-ui-pref requires KEY VALUE" >&2
      exit 2
    }
    validate_key "$key"
    value=$(sanitize_value "$value")
    cfg=$(config_file)
    [ -f "$cfg" ] || : >"$cfg"
    write_key_value_file "$cfg" "$key" "$value"
    printf 'key=%s\n' "$key"
    printf 'value=%s\n' "$value"
    ;;
  get-chat-endpoint)
    port=''
    url=''
    if port=$(read_demo_port 2>/dev/null); then
      url="http://localhost:$port/pages/chat.html"
    fi
    printf 'port=%s\n' "$port"
    printf 'chat_url=%s\n' "$url"
    ;;
  check-chat)
    requested=${1-}
    port=''
    default_url=''
    url=''
    status='stopped'

    if port=$(read_demo_port 2>/dev/null); then
      default_url="http://localhost:$port/pages/chat.html"
    fi

    if [ -n "$requested" ] && is_http_url "$requested"; then
      url=$requested
    else
      url=$default_url
    fi

    if [ -n "$url" ] && probe_url "$url"; then
      status='running'
    fi

    printf 'status=%s\n' "$status"
    printf 'port=%s\n' "$port"
    printf 'chat_url=%s\n' "$url"
    ;;
  start-server)
    ensure_demo_site
    ensure_demo_chat_page
    ensure_demo_built
    serve_demo_site || {
      printf '%s\n' "chatroom-backend: failed to start demo site" >&2
      exit 1
    }
    port=''
    url=''
    if port=$(read_demo_port 2>/dev/null); then
      url="http://localhost:$port/pages/chat.html"
    fi
    printf 'status=running\n'
    printf 'port=%s\n' "$port"
    printf 'chat_url=%s\n' "$url"
    ;;
  stop-server)
    stop_demo_site || {
      printf '%s\n' "chatroom-backend: failed to stop demo site" >&2
      exit 1
    }
    printf 'status=stopped\n'
    ;;
  *)
    printf '%s\n' "chatroom-backend: unknown action '$action'" >&2
    exit 2
    ;;
esac
