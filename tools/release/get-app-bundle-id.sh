#!/bin/sh

# Print platform bundle id for an app slug from config/apps.manifest.json.

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

case "$platform" in
  macos|ios|android) ;;
  *)
    printf '%s\n' "get-app-bundle-id: invalid platform: $platform" >&2
    exit 2
    ;;
esac

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
manifest="$ROOT_DIR/config/apps.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "get-app-bundle-id: jq is required" >&2
  exit 1
fi

bundle_id=$(jq -r --arg slug "$slug" --arg platform "$platform" '
  .apps[] | select(.slug == $slug) | .bundleIds[$platform]
' "$manifest")

if [ -z "$bundle_id" ] || [ "$bundle_id" = "null" ]; then
  printf '%s\n' "get-app-bundle-id: missing bundle id for app=$slug platform=$platform" >&2
  exit 1
fi

printf '%s\n' "$bundle_id"
