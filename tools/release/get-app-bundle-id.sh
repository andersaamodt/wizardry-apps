#!/bin/sh

# Print platform bundle id for an app slug from runtime/config/apps.manifest.json.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: get-app-bundle-id.sh PLATFORM APP_SLUG

PLATFORM: macos | ios | android
USAGE
  exit 0
  ;;
esac

set -eu

platform=${1-}
slug=${2-}

if [ -z "$platform" ] || [ -z "$slug" ]; then
  printf '%s\n' "get-app-bundle-id: PLATFORM and APP_SLUG required" >&2
  exit 2
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

case "$platform" in
  macos|ios|android) ;;
  *)
    printf '%s\n' "get-app-bundle-id: invalid platform: $platform" >&2
    exit 2
    ;;
  esac

is_safe_slug "$slug" || {
  printf '%s\n' "get-app-bundle-id: invalid app slug" >&2
  exit 2
}

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
  printf '%s\n' "get-app-bundle-id: could not resolve wizardry-apps root" >&2
  exit 1
fi

manifest="$ROOT_DIR/runtime/config/apps.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "get-app-bundle-id: jq is required" >&2
  exit 1
fi

is_safe_bundle_id() {
  value=${1-}
  [ -n "$value" ] || return 1
  case "$value" in
    *..*|*./*|*/.*|*/*|*\\*|*[!A-Za-z0-9.-]*)
      return 1
      ;;
  esac
  printf '%s\n' "$value" | grep -Eq '^[A-Za-z0-9]+(\.[A-Za-z0-9-]+)+$'
}

bundle_id=$(jq -r --arg slug "$slug" --arg platform "$platform" '
  .apps[] | select(.slug == $slug) | .bundleIds[$platform]
' "$manifest")

if [ -z "$bundle_id" ] || [ "$bundle_id" = "null" ]; then
  printf '%s\n' "get-app-bundle-id: missing bundle id for app=$slug platform=$platform" >&2
  exit 1
fi
if ! is_safe_bundle_id "$bundle_id"; then
  printf '%s\n' "get-app-bundle-id: unsafe bundle id in manifest for app=$slug platform=$platform" >&2
  exit 1
fi

printf '%s\n' "$bundle_id"
