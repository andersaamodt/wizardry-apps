#!/bin/sh

# Emission material notice:
# Repo-internal Wizardry use follows OWL 3.0.
# Generated blank projects may use this file under AGPL-3.0-or-later with the Wizardry Addendum.

case "${1-}" in
  --help|--usage|-h)
    cat <<'USAGE'
Usage: __APP_SLUG__-backend.sh COMMAND [ARGS...]

Commands:
  get-ui-prefs
  set-ui-pref KEY VALUE
  ping
  timestamp
USAGE
    exit 0
    ;;
esac

set -eu

config_root=${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps
prefs_file="$config_root/__APP_SLUG__.conf"

ensure_config_root() {
  mkdir -p "$config_root"
}

key_is_valid() {
  key=${1-}
  case "$key" in
    [a-z0-9]*)
      ;;
    *)
      return 1
      ;;
  esac

  case "$key" in
    *[!a-z0-9._-]*)
      return 1
      ;;
  esac
  return 0
}

sanitize_value() {
  printf '%s' "${1-}" | tr '\r\n' ' '
}

print_prefs() {
  [ -f "$prefs_file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *=*)
        key=${line%%=*}
        value=${line#*=}
        key_is_valid "$key" || continue
        printf '%s=%s\n' "$key" "$(sanitize_value "$value")"
        ;;
    esac
  done <"$prefs_file"
}

set_pref() {
  key=${1-}
  value=${2-}
  [ -n "$key" ] || {
    printf '%s\n' "__APP_SLUG__-backend: KEY required" >&2
    exit 2
  }
  key_is_valid "$key" || {
    printf '%s\n' "__APP_SLUG__-backend: invalid key: $key" >&2
    exit 2
  }
  value=$(sanitize_value "$value")

  ensure_config_root
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/__APP_SLUG__-prefs.XXXXXX")
  if [ -f "$prefs_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        *=*)
          existing_key=${line%%=*}
          existing_value=${line#*=}
          [ "$existing_key" != "$key" ] || continue
          key_is_valid "$existing_key" || continue
          printf '%s=%s\n' "$existing_key" "$(sanitize_value "$existing_value")" >> "$tmp_file"
          ;;
      esac
    done <"$prefs_file"
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
  mv "$tmp_file" "$prefs_file"
}

command_name=${1-}
case "$command_name" in
  get-ui-prefs)
    print_prefs
    ;;
  set-ui-pref)
    set_pref "${2-}" "${3-}"
    ;;
  ping)
    printf 'status=ok\n'
    printf 'message=pong from __APP_NAME__\n'
    ;;
  timestamp)
    printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    ;;
  *)
    printf '%s\n' "__APP_SLUG__-backend: unknown command: ${command_name-}" >&2
    exit 2
    ;;
esac
