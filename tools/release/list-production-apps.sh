#!/bin/sh

# Print production app slugs from config/apps.manifest.json.

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
manifest="$ROOT_DIR/config/apps.manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "list-production-apps: jq is required" >&2
  exit 1
fi

jq -r '.apps[] | select((.production == true) and ((.distribution // "optional") == "core")) | .slug' "$manifest" | sort
