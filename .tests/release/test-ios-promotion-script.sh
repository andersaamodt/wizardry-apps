#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-ios-release.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

out=$(sh "$ROOT_DIR/tools/release/promote-ios-release.sh" --help)
printf '%s' "$out" | grep -q 'Promotes a TestFlight build'
printf '%s' "$out" | grep -q 'IOS_SUBMIT_FOR_REVIEW'

if APP_STORE_CONNECT_KEY_ID='BAD/../../KEY' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   sh "$ROOT_DIR/tools/release/promote-ios-release.sh" com.example.app >"$tmp_dir/ios-promote-invalid-key.err" 2>&1; then
  printf '%s\n' "promote-ios-release accepted invalid key id" >&2
  exit 1
fi
grep -F "invalid App Store Connect key id" "$tmp_dir/ios-promote-invalid-key.err" >/dev/null

if APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   sh "$ROOT_DIR/tools/release/promote-ios-release.sh" 'com.example.app/../../other' >"$tmp_dir/ios-promote-invalid-bundle.err" 2>&1; then
  printf '%s\n' "promote-ios-release accepted invalid bundle id" >&2
  exit 1
fi
grep -F "invalid bundle id" "$tmp_dir/ios-promote-invalid-bundle.err" >/dev/null

ipa_path="$tmp_dir/app.ipa"
: > "$ipa_path"
if APP_STORE_CONNECT_KEY_ID='BAD/../../KEY' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   sh "$ROOT_DIR/tools/release/upload-testflight.sh" "$ipa_path" >"$tmp_dir/upload-testflight-invalid-key.err" 2>&1; then
  printf '%s\n' "upload-testflight accepted invalid key id" >&2
  exit 1
fi
grep -F "invalid App Store Connect key id" "$tmp_dir/upload-testflight-invalid-key.err" >/dev/null

printf '%s\n' "ios promotion script checks passed"
