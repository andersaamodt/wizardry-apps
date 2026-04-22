#!/bin/sh

# Print production app slugs from config/apps.manifest.json.

set -eu

is_workspace_root() {
  root=${1-}
  [ -n "$root" ] || return 1
  [ -f "$root/config/apps.manifest.json" ] || return 1
  [ -f "$root/config/templates.manifest.json" ] || return 1
  [ -d "$root/apps" ] || return 1
  [ -d "$root/web" ] || return 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
ROOT_DIR=${WIZARDRY_APPS_ROOT-}
if ! is_workspace_root "$ROOT_DIR"; then
  ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)
fi
if ! is_workspace_root "$ROOT_DIR"; then
  printf '%s\n' "list-production-apps: could not resolve wizardry-apps root" >&2
  exit 1
fi

manifest="$ROOT_DIR/config/apps.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "list-production-apps: jq is required" >&2
  exit 1
fi

jq -r '.apps[] | select((.production == true) and ((.distribution // "optional") == "core")) | .slug' "$manifest" | sort
