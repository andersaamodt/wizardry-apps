#!/bin/sh

# Sign and notarize a macOS app bundle.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: sign-and-notarize-macos.sh APP_BUNDLE

Requires Apple signing and notary environment variables.
USAGE
  exit 0
  ;;
esac

set -eu

app_bundle=${1-}
if [ -z "$app_bundle" ] || [ ! -d "$app_bundle" ]; then
  printf '%s\n' "sign-and-notarize-macos: app bundle required" >&2
  exit 2
fi

required_vars="APPLE_P12_BASE64 APPLE_P12_PASSWORD APPLE_DEVELOPER_ID_APP APPLE_TEAM_ID APPLE_NOTARY_KEY_ID APPLE_NOTARY_ISSUER_ID APPLE_NOTARY_PRIVATE_KEY_BASE64"
for v in $required_vars; do
  eval "val=\${$v-}"
  if [ -z "$val" ]; then
    printf '%s\n' "sign-and-notarize-macos: missing required env: $v" >&2
    exit 1
  fi
done

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-macos-sign.XXXXXX")
keychain="$tmp_dir/signing.keychain-db"
keychain_password="wizardry-sign-$(date +%s)"
p12_file="$tmp_dir/cert.p12"
tmp_key="$tmp_dir/notary-key.p8"

cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

printf '%s' "$APPLE_P12_BASE64" | openssl base64 -d -A > "$p12_file"
printf '%s' "$APPLE_NOTARY_PRIVATE_KEY_BASE64" | openssl base64 -d -A > "$tmp_key"

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain"
security import "$p12_file" -k "$keychain" -P "$APPLE_P12_PASSWORD" -A
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain"

codesign --force --deep --options runtime --timestamp --sign "$APPLE_DEVELOPER_ID_APP" "$app_bundle"

xcrun notarytool submit "$app_bundle" \
  --key "$tmp_key" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  --wait

xcrun stapler staple "$app_bundle"

printf '%s\n' "sign-and-notarize-macos: notarized $app_bundle"
