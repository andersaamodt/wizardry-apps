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

if [ ! -d "$root/apps/forge" ] || [ ! -x "$root/apps/forge/scripts/forge-backend" ]; then
  printf '%s\n' "launch-forge: invalid wizardry-apps root: $root" >&2
  exit 1
fi

config_root="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps"
config_file="$config_root/forge-root"
mkdir -p "$config_root"
printf '%s\n' "$root" > "$config_file"
export WIZARDRY_APPS_ROOT="$root"

state_dir=${WIZARDRY_APPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/wizardry-apps}
log_file="$state_dir/forge-launch.log"
mkdir -p "$state_dir"

set +e
out=$("$root/apps/forge/scripts/forge-backend" run-desktop "$root" forge 2>&1)
status=$?
set -e

printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] launch root=$root status=$status" >> "$log_file"
printf '%s\n' "$out" >> "$log_file"

if [ "$status" -ne 0 ]; then
  printf '%s\n' "$out" >&2
  exit "$status"
fi

pid=$(printf '%s\n' "$out" | sed -n 's/^pid=//p' | head -n 1)
printf '%s\n' "App Forge launched${pid:+ (pid $pid)}"
printf '%s\n' "Launch log: $log_file"
