#!/bin/sh

# Emission material notice:
# Repo-internal Wizardry use follows OWL 3.1.
# Generated blank projects may use this file under AGPL-3.0-or-later with the Wizardry Addendum.

case "${1-}" in
  --help|--usage|-h)
    cat <<'USAGE'
Usage: __APP_SLUG__-backend.sh COMMAND [ARGS...]

Commands:
  get-ui-prefs
  set-ui-pref KEY VALUE
  prepare-theurgy
  theurgy-status
USAGE
    exit 0
    ;;
esac

set -eu

config_root=${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps
prefs_file="$config_root/__APP_SLUG__.conf"
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
app_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
workspace_root=$(CDPATH= cd -- "$app_root/.." && pwd -P)

ensure_config_root() {
  mkdir -p "$config_root"
}

key_is_valid() {
  key=${1-}
  case "$key" in
    [a-z0-9]*) ;;
    *) return 1 ;;
  esac
  case "$key" in
    *[!a-z0-9._-]*) return 1 ;;
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
          printf '%s=%s\n' "$existing_key" "$(sanitize_value "$existing_value")" >>"$tmp_file"
          ;;
      esac
    done <"$prefs_file"
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
  mv "$tmp_file" "$prefs_file"
}

run_prepare_script() {
  script="$workspace_root/scripts/prepare-theurgy-runtime.sh"
  [ -x "$script" ] || {
    printf '%s\n' "__APP_SLUG__-backend: missing workspace prepare script: $script" >&2
    exit 1
  }
  (
    cd "$workspace_root"
    sh "$script"
  )
}

command_name=${1-}
case "$command_name" in
  get-ui-prefs)
    print_prefs
    ;;
  set-ui-pref)
    set_pref "${2-}" "${3-}"
    ;;
  prepare-theurgy)
    run_prepare_script
    ;;
  theurgy-status)
    out=$(run_prepare_script)
    status_file=$(printf '%s\n' "$out" | awk -F= '$1=="status_file"{print $2; exit}')
    if [ -n "$status_file" ] && [ -f "$status_file" ]; then
      cat "$status_file"
    else
      printf '%s\n' "$out"
    fi
    ;;
  *)
    printf '%s\n' "__APP_SLUG__-backend: unknown command: ${command_name-}" >&2
    exit 2
    ;;
esac
