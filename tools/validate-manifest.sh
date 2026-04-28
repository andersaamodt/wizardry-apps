#!/bin/sh
# Validate wizardry app/template manifests and release-safe metadata.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: validate-manifest.sh [ROOT_DIR]
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -gt 1 ]; then
  printf '%s\n' "validate-manifest: too many arguments" >&2
  exit 2
fi

ROOT_DIR=${1-}
if [ -z "$ROOT_DIR" ]; then
  ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
else
  ROOT_DIR=$(CDPATH= cd -- "$ROOT_DIR" && pwd -P)
fi
MANIFEST_DIR="$ROOT_DIR/config"

for file in "$MANIFEST_DIR"/*.manifest.json; do
  jq . "$file" >/dev/null 2>&1 || {
    printf '%s\n' "Manifest validation failed for $file"
    exit 1
  }
done

jq -e '
  def one_line_string:
    type == "string" and length > 0 and (test("[\r\n\t]") | not);
  def optional_one_line_string:
    type == "string" and (test("[\r\n\t]") | not);
  def valid_slug:
    one_line_string
    and test("^[a-z][a-z0-9-]*$")
    and (test("--") | not)
    and (test("-$") | not);
  def valid_bundle_id:
    one_line_string
    and test("^[A-Za-z0-9]+(\\.[A-Za-z0-9-]+)+$")
    and (contains("..") | not)
    and (contains("./") | not)
    and (contains("/.") | not);
  def valid_targets:
    type == "string"
    and length > 0
    and (
      split(",")
      | all(.[]; . != "")
      and all(.[]; . as $target | ["hosted-web", "macos", "linux", "ios", "android", "godot-desktop"] | index($target) != null)
      and (length == (unique | length))
    );
  def valid_source_subdir:
    type == "string"
    and (test("[\r\n\t]") | not)
    and (
      . == ""
      or . == "."
      or (
        test("^[A-Za-z0-9._/-]+$")
        and (startswith("/") | not)
        and (endswith("/") | not)
        and (contains("//") | not)
        and (split("/") | all(. != "" and . != "." and . != ".."))
      )
    );
  def valid_source:
    type == "object"
    and (.repo | one_line_string)
    and ((.ref // "") | optional_one_line_string)
    and ((.subdir // "") | valid_source_subdir);

  .apps
  | type == "array"
  and all(.[]; .slug | valid_slug)
  and all(.[]; .name | one_line_string)
  and all(.[]; (.production | type == "boolean"))
  and all(.[]; (.distribution // "optional") | (. == "core" or . == "optional"))
  and all(.[]; .targets | valid_targets)
  and all(.[]; .bundleIds | type == "object")
  and all(.[]; . as $app | all(["macos", "ios", "android"][]; ($app.bundleIds[.] | valid_bundle_id)))
  and all(.[]; if (.distribution // "optional") == "optional" then (.source | valid_source) else true end)
  and all(.[]; if has("hostedWeb") then (.hostedWeb | type == "object" and ((.mode // "") | optional_one_line_string) and ((.path // "") | optional_one_line_string)) else true end)
' "$MANIFEST_DIR/apps.manifest.json" >/dev/null || {
  printf '%s\n' "apps.manifest.json validation failed: app slugs, names, targets, bundle ids, distributions, and optional sources must be release-safe"
  exit 1
}

jq -e '
  def one_line_string:
    type == "string" and length > 0 and (test("[\r\n\t]") | not);
  def optional_one_line_string:
    type == "string" and (test("[\r\n\t]") | not);
  def valid_slug:
    one_line_string
    and test("^[a-z][a-z0-9-]*$")
    and (test("--") | not)
    and (test("-$") | not);
  def valid_source_subdir:
    type == "string"
    and (test("[\r\n\t]") | not)
    and (
      . == ""
      or . == "."
      or (
        test("^[A-Za-z0-9._/-]+$")
        and (startswith("/") | not)
        and (endswith("/") | not)
        and (contains("//") | not)
        and (split("/") | all(. != "" and . != "." and . != ".."))
      )
    );
  def valid_source:
    type == "object"
    and (.repo | one_line_string)
    and ((.ref // "") | optional_one_line_string)
    and ((.subdir // "") | valid_source_subdir);

  .templates
  | type == "array"
  and all(.[]; .slug | valid_slug)
  and all(.[]; (.publish | type == "boolean"))
  and all(.[]; (.distribution // "optional") | (. == "core" or . == "optional"))
  and all(.[]; if (.distribution // "optional") == "optional" then (.source | valid_source) else true end)
' "$MANIFEST_DIR/templates.manifest.json" >/dev/null || {
  printf '%s\n' "templates.manifest.json validation failed: template slugs, publish flags, distributions, and optional sources must be release-safe"
  exit 1
}

printf '%s\n' "All manifest files are valid"
