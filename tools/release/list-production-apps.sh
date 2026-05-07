#!/bin/sh

# Print production app slugs from runtime/config/apps.manifest.json.

set -eu

is_workspace_root() {
  root=${1-}
  [ -n "$root" ] || return 1
  [ -f "$root/runtime/config/apps.manifest.json" ] || return 1
  [ -f "$root/runtime/config/templates.manifest.json" ] || return 1
  [ -d "$root/apps" ] || return 1
  [ -d "$root/templates/web" ] || return 1
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

manifest="$ROOT_DIR/runtime/config/apps.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "list-production-apps: jq is required" >&2
  exit 1
fi

is_safe_slug() {
  value=${1-}
  case "$value" in
    [a-z]*)
      ;;
    *)
      return 1
      ;;
  esac
  case "$value" in
    *[!a-z0-9-]*|*-|*--*)
      return 1
      ;;
  esac
  return 0
}

tmp_slugs=$(mktemp "${TMPDIR:-/tmp}/wizardry-production-apps.XXXXXX")
jq -r '.apps[] | select((.production == true) and ((.distribution // "optional") == "core")) | .slug' "$manifest" |
while IFS= read -r app_slug || [ -n "$app_slug" ]; do
  if ! is_safe_slug "$app_slug"; then
    rm -f "$tmp_slugs"
    printf '%s\n' "list-production-apps: unsafe app slug in manifest: $app_slug" >&2
    exit 1
  fi
  printf '%s\n' "$app_slug" >>"$tmp_slugs"
done
sort "$tmp_slugs"
rm -f "$tmp_slugs"
