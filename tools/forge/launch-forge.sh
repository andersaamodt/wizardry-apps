#!/bin/sh

# Launch App Forge from a wizardry-apps checkout.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)

root=$DEFAULT_ROOT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|--usage|-h)
      cat <<'USAGE'
Usage: launch-forge [--root ROOT_DIR]

Launches the App Forge desktop app from this repository.
USAGE
      exit 0
      ;;
    --root)
      root=${2-}
      if [ -z "$root" ]; then
        printf '%s\n' "launch-forge: --root requires ROOT_DIR" >&2
        exit 2
      fi
      shift 2
      ;;
    *)
      printf '%s\n' "launch-forge: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

if has_line_break "$root"; then
  printf '%s\n' "launch-forge: root path must not contain line breaks" >&2
  exit 2
fi

if [ ! -d "$root/apps/forge" ] || [ ! -x "$root/apps/forge/scripts/forge-backend" ]; then
  printf '%s\n' "launch-forge: invalid wizardry-apps root: $root" >&2
  exit 1
fi

stop_running_macos_forge() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -f "/App Forge.app/Contents/MacOS/wizardry-host" >/dev/null 2>&1 || true
    pkill -f "/App Forge.app/Contents/MacOS/app-forge" >/dev/null 2>&1 || true
  fi
}

config_root="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps"
config_file="$config_root/forge-root"
mkdir -p "$config_root"
printf '%s\n' "$root" > "$config_file"
export WIZARDRY_APPS_ROOT="$root"

state_dir=${WIZARDRY_APPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/wizardry-apps}
log_file="$state_dir/forge-launch.log"
mkdir -p "$state_dir"

set +e
if [ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ]; then
  out=$("$root/tools/forge/install-forge" --root "$root" --user 2>&1)
  status=$?
  if [ "$status" -eq 0 ]; then
    installed_app=$(printf '%s\n' "$out" | sed -n 's/^installed_app=//p' | head -n 1)
    if [ -n "$installed_app" ] && [ -d "$installed_app" ] && command -v open >/dev/null 2>&1; then
      stop_running_macos_forge
      open -n "$installed_app" >/dev/null 2>&1
      open_status=$?
      if [ "$open_status" -eq 0 ]; then
        out=$(printf '%s\n%s\n' "$out" "opened_app=$installed_app")
      else
        status=$open_status
        out=$(printf '%s\n%s\n' "$out" "launch-forge: failed to open installed app: $installed_app")
      fi
    else
      status=1
      out=$(printf '%s\n%s\n' "$out" "launch-forge: installed app missing after install")
    fi
  fi
else
  out=$("$root/apps/forge/scripts/forge-backend" run-desktop "$root" forge 2>&1)
  status=$?
fi
set -e

printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] launch root=$root status=$status" >> "$log_file"
printf '%s\n' "$out" >> "$log_file"

if [ "$status" -ne 0 ]; then
  printf '%s\n' "$out" >&2
  exit "$status"
fi

pid=$(printf '%s\n' "$out" | sed -n 's/^pid=//p' | head -n 1)
opened_app=$(printf '%s\n' "$out" | sed -n 's/^opened_app=//p' | head -n 1)
if [ -n "$opened_app" ]; then
  printf '%s\n' "App Forge launched ($opened_app)"
else
  printf '%s\n' "App Forge launched${pid:+ (pid $pid)}"
fi
printf '%s\n' "Launch log: $log_file"
