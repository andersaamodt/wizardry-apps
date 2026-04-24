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

print_prefs() {
  [ -f "$prefs_file" ] || return 0
  cat "$prefs_file"
}

set_pref() {
  key=${1-}
  value=${2-}
  [ -n "$key" ] || {
    printf '%s\n' "__APP_SLUG__-backend: KEY required" >&2
    exit 2
  }

  ensure_config_root
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/__APP_SLUG__-prefs.XXXXXX")
  if [ -f "$prefs_file" ]; then
    awk -F= -v key="$key" '$1 != key { print $0 }' "$prefs_file" > "$tmp_file"
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
