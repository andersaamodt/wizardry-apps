#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: chatroom-backend.sh ACTION [ARGS...]

Actions:
  get-ui-prefs
  set-ui-pref KEY VALUE
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
    [a-z0-9][a-z0-9._-]*)
      ;;
    *)
      printf '%s\n' "chatroom-backend: invalid key: $key" >&2
      exit 2
      ;;
  esac
}

sanitize_value() {
  printf '%s' "${1-}" | tr '\r\n' ' '
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
  *)
    printf '%s\n' "chatroom-backend: unknown action '$action'" >&2
    exit 2
    ;;
esac
