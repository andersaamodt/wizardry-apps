#!/bin/sh
# Validate wizardry app/template manifests and optional-source requirements.

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
MANIFEST_DIR="$ROOT_DIR/config"

for file in "$MANIFEST_DIR"/*.manifest.json; do
  jq . "$file" >/dev/null 2>&1 || {
    printf '%s\n' "Manifest validation failed for $file"
    exit 1
  }
done

jq -e '
  .apps
  | type == "array"
  and all(.[]; (.distribution // "optional") | IN("core", "optional"))
  and all(.[]; if (.distribution // "optional") == "optional" then (.source.repo | type == "string" and length > 0) else true end)
' "$MANIFEST_DIR/apps.manifest.json" >/dev/null || {
  printf '%s\n' "apps.manifest.json validation failed: optional apps require source.repo and distribution must be core|optional"
  exit 1
}

jq -e '
  .templates
  | type == "array"
  and all(.[]; (.distribution // "optional") | IN("core", "optional"))
  and all(.[]; if (.distribution // "optional") == "optional" then (.source.repo | type == "string" and length > 0) else true end)
' "$MANIFEST_DIR/templates.manifest.json" >/dev/null || {
  printf '%s\n' "templates.manifest.json validation failed: optional templates require source.repo and distribution must be core|optional"
  exit 1
}

printf '%s\n' "All manifest files are valid"
