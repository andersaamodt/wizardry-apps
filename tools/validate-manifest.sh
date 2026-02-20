#!/bin/sh

# Validate app/template manifests and enforce required release fields.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: validate-manifest.sh

Validates:
  - config/apps.manifest.json
  - config/templates.manifest.json

Requires jq.
USAGE
  exit 0
  ;;
esac

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
apps_manifest="$ROOT_DIR/config/apps.manifest.json"
templates_manifest="$ROOT_DIR/config/templates.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "validate-manifest: jq is required" >&2
  exit 1
fi

[ -f "$apps_manifest" ] || {
  printf '%s\n' "validate-manifest: missing $apps_manifest" >&2
  exit 1
}

[ -f "$templates_manifest" ] || {
  printf '%s\n' "validate-manifest: missing $templates_manifest" >&2
  exit 1
}

jq -e '.schemaVersion == "1" and (.apps | type == "array" and length > 0)' "$apps_manifest" >/dev/null

jq -e '
  .apps[]
  | (.slug | type == "string" and length > 0)
    and (.name | type == "string" and length > 0)
    and (.production | type == "boolean")
    and (.bundleIds.macos | type == "string" and length > 0)
    and (.bundleIds.ios | type == "string" and length > 0)
    and (.bundleIds.android | type == "string" and length > 0)
' "$apps_manifest" >/dev/null

jq -e '
  ([.apps[].slug] | unique | length) == (.apps | length)
' "$apps_manifest" >/dev/null

jq -e '
  (.apps[] | select(.slug == "artificer") | .production) == true
  and
  (.apps[] | select(.slug == "unix-settings") | .production) == true
' "$apps_manifest" >/dev/null

jq -e '
  ([.apps[].bundleIds.macos] | unique | length) == (.apps | length)
  and
  ([.apps[].bundleIds.ios] | unique | length) == (.apps | length)
  and
  ([.apps[].bundleIds.android] | unique | length) == (.apps | length)
' "$apps_manifest" >/dev/null

jq -e '.schemaVersion == "1" and (.templates | type == "array" and length > 0)' "$templates_manifest" >/dev/null

jq -e '.templates[] | (.slug | type == "string" and length > 0) and (.publish | type == "boolean")' "$templates_manifest" >/dev/null

jq -e '
  (.templates | map(.slug) | index("demo")) != null and
  (.templates | map(.slug) | index("blog")) != null
' "$templates_manifest" >/dev/null

printf '%s\n' "validate-manifest: OK"
