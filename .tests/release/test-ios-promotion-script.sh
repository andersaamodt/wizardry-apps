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

if APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   IOS_SUBMIT_FOR_REVIEW='maybe' \
   sh "$ROOT_DIR/tools/release/promote-ios-release.sh" com.example.app >"$tmp_dir/ios-promote-invalid-submit-flag.err" 2>&1; then
  printf '%s\n' "promote-ios-release accepted invalid submit flag" >&2
  exit 1
fi
grep -F "invalid IOS_SUBMIT_FOR_REVIEW" "$tmp_dir/ios-promote-invalid-submit-flag.err" >/dev/null

if APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   IOS_RELEASE_AFTER_APPROVAL='maybe' \
   sh "$ROOT_DIR/tools/release/promote-ios-release.sh" com.example.app >"$tmp_dir/ios-promote-invalid-release-flag.err" 2>&1; then
  printf '%s\n' "promote-ios-release accepted invalid release flag" >&2
  exit 1
fi
grep -F "invalid IOS_RELEASE_AFTER_APPROVAL" "$tmp_dir/ios-promote-invalid-release-flag.err" >/dev/null

if sh "$ROOT_DIR/tools/release/promote-ios-release.sh" com.example.app 42 1.2.3 ignored >"$tmp_dir/ios-promote-extra.err" 2>&1; then
  printf '%s\n' "promote-ios-release accepted an extra operand" >&2
  exit 1
fi
grep -F "BUNDLE_ID and optional BUILD_NUMBER VERSION_STRING required" "$tmp_dir/ios-promote-extra.err" >/dev/null

fake_promote_bin="$tmp_dir/fake-promote-bin"
mkdir -p "$fake_promote_bin"
cat >"$fake_promote_bin/openssl" <<'SH'
#!/bin/sh
cat
SH
cat >"$fake_promote_bin/curl" <<'SH'
#!/bin/sh
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    https://api.appstoreconnect.apple.com*) url=$1 ;;
  esac
  shift
done
case "$url" in
  *'/v1/apps?'*)
    printf '%s\n' '{"data":[{"id":"app123"}]}'
    ;;
  *'/v1/builds?'*)
    printf '%s\n' '{"data":[{"id":"build123","attributes":{"version":"42"},"relationships":{"preReleaseVersion":{"data":{"id":"pre123"}}}}],"included":[{"type":"preReleaseVersions","id":"pre123","attributes":{"version":"1.2.3\nforged=1"}}]}'
    ;;
  *'/v1/appStoreVersions/version123/relationships/build')
    printf '%s\n' '{}'
    ;;
  *'/v1/appStoreVersions/version123')
    printf '%s\n' '{"data":{"attributes":{"appStoreState":"PREPARE_FOR_SUBMISSION"}}}'
    ;;
  *'/v1/appStoreVersionSubmissions')
    printf '%s\n' '{}'
    ;;
  *'/v1/appStoreVersions?'*)
    printf '%s\n' '{"data":[{"id":"version123"}]}'
    ;;
  *)
    printf '%s\n' '{"data":[]}'
    ;;
esac
SH
chmod +x "$fake_promote_bin/openssl" "$fake_promote_bin/curl"
if APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   PATH="$fake_promote_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/promote-ios-release.sh" com.example.app >"$tmp_dir/ios-promote-api-version.out" 2>"$tmp_dir/ios-promote-api-version.err"; then
  printf '%s\n' "promote-ios-release accepted invalid API version string" >&2
  exit 1
fi
grep -F "invalid version string from API" "$tmp_dir/ios-promote-api-version.err" >/dev/null

ipa_path="$tmp_dir/app.ipa"
: > "$ipa_path"
bad_ipa_path="$tmp_dir/app
forged=1.ipa"
: > "$bad_ipa_path"
if APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   sh "$ROOT_DIR/tools/release/upload-testflight.sh" "$bad_ipa_path" >"$tmp_dir/upload-testflight-bad-path.out" 2>"$tmp_dir/upload-testflight-bad-path.err"; then
  printf '%s\n' "upload-testflight accepted newline IPA path" >&2
  exit 1
fi
grep -F "IPA path must not contain line breaks" "$tmp_dir/upload-testflight-bad-path.err" >/dev/null

bad_ipa_suffix="$tmp_dir/app.txt"
: > "$bad_ipa_suffix"
if sh "$ROOT_DIR/tools/release/upload-testflight.sh" "$bad_ipa_suffix" >"$tmp_dir/upload-testflight-bad-suffix.err" 2>&1; then
  printf '%s\n' "upload-testflight accepted a non-IPA artifact path" >&2
  exit 1
fi
grep -F "IPA path must end with .ipa" "$tmp_dir/upload-testflight-bad-suffix.err" >/dev/null

if sh "$ROOT_DIR/tools/release/upload-testflight.sh" "$ipa_path" ignored >"$tmp_dir/upload-testflight-extra.err" 2>&1; then
  printf '%s\n' "upload-testflight accepted an extra operand" >&2
  exit 1
fi
grep -F "exactly one IPA_PATH required" "$tmp_dir/upload-testflight-extra.err" >/dev/null

if APP_STORE_CONNECT_KEY_ID='BAD/../../KEY' \
   APP_STORE_CONNECT_ISSUER_ID='11111111-1111-1111-1111-111111111111' \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   sh "$ROOT_DIR/tools/release/upload-testflight.sh" "$ipa_path" >"$tmp_dir/upload-testflight-invalid-key.err" 2>&1; then
  printf '%s\n' "upload-testflight accepted invalid key id" >&2
  exit 1
fi
grep -F "invalid App Store Connect key id" "$tmp_dir/upload-testflight-invalid-key.err" >/dev/null

fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/openssl" <<'SH'
#!/bin/sh
cat
SH
cat >"$fake_bin/xcrun" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$fake_bin/openssl" "$fake_bin/xcrun"
bad_issuer=$(printf '11111111-1111-1111-1111-111111111111\nforged=1')
if APP_STORE_CONNECT_KEY_ID='ABC123DEF4' \
   APP_STORE_CONNECT_ISSUER_ID="$bad_issuer" \
   APP_STORE_CONNECT_PRIVATE_KEY_BASE64='bad' \
   PATH="$fake_bin:$PATH" \
   sh "$ROOT_DIR/tools/release/upload-testflight.sh" "$ipa_path" >"$tmp_dir/upload-testflight-invalid-issuer.err" 2>&1; then
  printf '%s\n' "upload-testflight accepted invalid issuer id" >&2
  exit 1
fi
grep -F "invalid App Store Connect issuer id" "$tmp_dir/upload-testflight-invalid-issuer.err" >/dev/null

printf '%s\n' "ios promotion script checks passed"
