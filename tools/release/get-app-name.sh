#!/bin/sh

# Print app display name for a slug from config/apps.manifest.json.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: get-app-name.sh APP_SLUG
USAGE
  exit 0
  ;;
esac

set -eu

slug=${1-}
if [ -z "$slug" ]; then
  printf '%s\n' "get-app-name: APP_SLUG required" >&2
  exit 2
fi

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
  printf '%s\n' "get-app-name: could not resolve wizardry-apps root" >&2
  exit 1
fi

manifest="$ROOT_DIR/config/apps.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "get-app-name: jq is required" >&2
  exit 1
fi

has_control_delimiter() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  tab_char=$(printf '\t')
  case "$value" in
    *"$nl_char"*|*"$cr_char"*|*"$tab_char"*) return 0 ;;
  esac
  return 1
}

name=$(jq -r --arg slug "$slug" '.apps[] | select(.slug == $slug) | .name' "$manifest")
if [ -z "$name" ] || [ "$name" = "null" ]; then
  printf '%s\n' "get-app-name: unknown slug: $slug" >&2
  exit 1
fi
if has_control_delimiter "$name"; then
  printf '%s\n' "get-app-name: unsafe app name in manifest for slug: $slug" >&2
  exit 1
fi

printf '%s\n' "$name"
