#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-manifest-validation.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fixture_root="$tmp_dir/root"
mkdir -p "$fixture_root/config" "$fixture_root/apps" "$fixture_root/web"
cp "$ROOT_DIR/config/apps.manifest.json" "$fixture_root/config/apps.manifest.json"
cp "$ROOT_DIR/config/templates.manifest.json" "$fixture_root/config/templates.manifest.json"

sh "$ROOT_DIR/tools/validate-manifest.sh" "$fixture_root"

bad_root="$tmp_dir/bad-root"
mkdir -p "$bad_root/config" "$bad_root/apps" "$bad_root/web"
cp "$fixture_root/config/apps.manifest.json" "$bad_root/config/apps.manifest.json"
cp "$fixture_root/config/templates.manifest.json" "$bad_root/config/templates.manifest.json"

jq '.apps += [{
  "slug":"bad/../../slug",
  "name":"Bad App",
  "production":true,
  "distribution":"core",
  "bundleIds":{"macos":"com.example.bad","ios":"com.example.bad","android":"com.example.bad"},
  "targets":"macos"
}]' "$fixture_root/config/apps.manifest.json" > "$bad_root/config/apps.manifest.json"
if sh "$ROOT_DIR/tools/validate-manifest.sh" "$bad_root" >"$tmp_dir/bad-slug.out" 2>&1; then
  printf '%s\n' "validate-manifest accepted path-shaped app slug" >&2
  exit 1
fi
grep -F "apps.manifest.json validation failed" "$tmp_dir/bad-slug.out" >/dev/null

jq '.apps[0].name = "Injected\nbundleIds={}"' "$fixture_root/config/apps.manifest.json" > "$bad_root/config/apps.manifest.json"
if sh "$ROOT_DIR/tools/validate-manifest.sh" "$bad_root" >"$tmp_dir/bad-name.out" 2>&1; then
  printf '%s\n' "validate-manifest accepted newline app name" >&2
  exit 1
fi
grep -F "apps.manifest.json validation failed" "$tmp_dir/bad-name.out" >/dev/null

jq '.apps[0].name = "Injected\tbundleIds={}"' "$fixture_root/config/apps.manifest.json" > "$bad_root/config/apps.manifest.json"
if sh "$ROOT_DIR/tools/validate-manifest.sh" "$bad_root" >"$tmp_dir/bad-tab-name.out" 2>&1; then
  printf '%s\n' "validate-manifest accepted tab-delimited app name" >&2
  exit 1
fi
grep -F "apps.manifest.json validation failed" "$tmp_dir/bad-tab-name.out" >/dev/null

jq '.apps[0].bundleIds.ios = "com.example/../../bad"' "$fixture_root/config/apps.manifest.json" > "$bad_root/config/apps.manifest.json"
if sh "$ROOT_DIR/tools/validate-manifest.sh" "$bad_root" >"$tmp_dir/bad-bundle.out" 2>&1; then
  printf '%s\n' "validate-manifest accepted path-shaped bundle id" >&2
  exit 1
fi
grep -F "apps.manifest.json validation failed" "$tmp_dir/bad-bundle.out" >/dev/null

cp "$fixture_root/config/apps.manifest.json" "$bad_root/config/apps.manifest.json"
jq '.templates += [{
  "slug":"bad/../../template",
  "publish":true,
  "distribution":"core"
}]' "$fixture_root/config/templates.manifest.json" > "$bad_root/config/templates.manifest.json"
if sh "$ROOT_DIR/tools/validate-manifest.sh" "$bad_root" >"$tmp_dir/bad-template.out" 2>&1; then
  printf '%s\n' "validate-manifest accepted path-shaped template slug" >&2
  exit 1
fi
grep -F "templates.manifest.json validation failed" "$tmp_dir/bad-template.out" >/dev/null

printf '%s\n' "manifest validation tests passed"
