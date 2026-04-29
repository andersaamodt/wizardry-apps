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

if [ "$#" -ne 1 ]; then
  printf '%s\n' "sign-and-notarize-macos: exactly one APP_BUNDLE required" >&2
  exit 2
fi

app_bundle=${1-}

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

if [ -z "$app_bundle" ] || [ ! -d "$app_bundle" ]; then
  printf '%s\n' "sign-and-notarize-macos: app bundle required" >&2
  exit 2
fi

if has_line_break "$app_bundle"; then
  printf '%s\n' "sign-and-notarize-macos: app bundle path must not contain line breaks" >&2
  exit 2
fi

case "$app_bundle" in
  -*)
    printf '%s\n' "sign-and-notarize-macos: app bundle path must be a safe .app bundle path" >&2
    exit 2
    ;;
  *.app) ;;
  *)
    printf '%s\n' "sign-and-notarize-macos: app bundle path must be a .app bundle" >&2
    exit 2
    ;;
esac

required_vars="APPLE_P12_BASE64 APPLE_P12_PASSWORD APPLE_DEVELOPER_ID_APP APPLE_TEAM_ID APPLE_NOTARY_KEY_ID APPLE_NOTARY_ISSUER_ID APPLE_NOTARY_PRIVATE_KEY_BASE64"
for v in $required_vars; do
  eval "val=\${$v-}"
  if [ -z "$val" ]; then
    printf '%s\n' "sign-and-notarize-macos: missing required env: $v" >&2
    exit 1
  fi
done

valid_alnum() {
  case "${1-}" in ""|*[!A-Za-z0-9]*) return 1 ;; esac
}

valid_hex_dash() {
  case "${1-}" in ""|*[!A-Fa-f0-9-]*) return 1 ;; esac
}

valid_alnum "$APPLE_TEAM_ID" || {
  printf '%s\n' "sign-and-notarize-macos: invalid Apple team id" >&2
  exit 2
}

valid_alnum "$APPLE_NOTARY_KEY_ID" || {
  printf '%s\n' "sign-and-notarize-macos: invalid Apple notary key id" >&2
  exit 2
}

valid_hex_dash "$APPLE_NOTARY_ISSUER_ID" || {
  printf '%s\n' "sign-and-notarize-macos: invalid Apple notary issuer id" >&2
  exit 2
}

if has_line_break "$APPLE_DEVELOPER_ID_APP"; then
  printf '%s\n' "sign-and-notarize-macos: invalid Developer ID application identity" >&2
  exit 2
fi

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
