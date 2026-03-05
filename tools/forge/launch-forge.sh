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

os=$(uname -s 2>/dev/null || printf unknown)

if [ "$os" = "Darwin" ]; then
  is_valid_app_bundle() {
    bundle=$1
    [ -d "$bundle" ] || return 1
    [ -x "$bundle/Contents/MacOS/app-forge" ] || return 1
    [ -x "$bundle/Contents/MacOS/wizardry-host" ] || return 1
    [ -x "$bundle/Contents/Resources/forge/scripts/forge-backend" ] || return 1
    return 0
  }

  app_path=''
  for candidate in \
    "/Applications/App Forge.app" \
    "$HOME/Applications/App Forge.app"; do
    if is_valid_app_bundle "$candidate"; then
      app_path=$candidate
      break
    fi
  done

  if [ -z "$app_path" ]; then
    dev_app="$root/_tmp/workbench/dist/macos/App Forge.app"
    "$root/tools/forge/build-forge-macos-app" --root "$root" --out "$dev_app" >/dev/null
    app_path=$dev_app
  fi

  root_pointer="$app_path/Contents/Resources/wizardry-apps-root.txt"
  pointer_dir=$(dirname "$root_pointer")
  if [ -d "$pointer_dir" ] && [ -w "$pointer_dir" ]; then
    printf '%s\n' "$root" > "$root_pointer" 2>/dev/null || true
  fi

  if command -v open >/dev/null 2>&1; then
    if open -a "$app_path" >/dev/null 2>&1; then
      printf '%s\n' "App Forge launched: $app_path"
      exit 0
    fi
  fi

  exec "$app_path/Contents/MacOS/app-forge"
fi

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
