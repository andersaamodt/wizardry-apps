#!/bin/sh

# Upload IPA artifact to TestFlight.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: upload-testflight.sh IPA_PATH

Uploads IPA using App Store Connect API key env vars.
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -ne 1 ]; then
  printf '%s\n' "upload-testflight: exactly one IPA_PATH required" >&2
  exit 2
fi

ipa=${1-}

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

if [ -z "$ipa" ] || [ ! -f "$ipa" ]; then
  printf '%s\n' "upload-testflight: IPA_PATH required" >&2
  exit 2
fi

if has_line_break "$ipa"; then
  printf '%s\n' "upload-testflight: IPA path must not contain line breaks" >&2
  exit 2
fi

case "$ipa" in
  *.ipa) ;;
  *)
    printf '%s\n' "upload-testflight: IPA path must end with .ipa" >&2
    exit 2
    ;;
esac

if [ -z "${APP_STORE_CONNECT_KEY_ID-}" ] || [ -z "${APP_STORE_CONNECT_ISSUER_ID-}" ] || [ -z "${APP_STORE_CONNECT_PRIVATE_KEY_BASE64-}" ]; then
  printf '%s\n' "upload-testflight: missing App Store Connect credentials" >&2
  exit 1
fi

valid_alnum() {
  case "${1-}" in ""|*[!A-Za-z0-9]*) return 1 ;; esac
}

valid_hex_dash() {
  case "${1-}" in ""|*[!A-Fa-f0-9-]*) return 1 ;; esac
}

valid_alnum "$APP_STORE_CONNECT_KEY_ID" || {
  printf '%s\n' "upload-testflight: invalid App Store Connect key id" >&2
  exit 2
}

valid_hex_dash "$APP_STORE_CONNECT_ISSUER_ID" || {
  printf '%s\n' "upload-testflight: invalid App Store Connect issuer id" >&2
  exit 2
}

if ! command -v xcrun >/dev/null 2>&1; then
  printf '%s\n' "upload-testflight: xcrun is required" >&2
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/asc-upload.XXXXXX")
key_dir="$tmp_dir/private_keys"
mkdir -p "$key_dir"
key_file="$key_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

printf '%s' "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" | openssl base64 -d -A > "$key_file"

if xcrun altool --help >/dev/null 2>&1; then
  API_PRIVATE_KEYS_DIR="$key_dir" \
  xcrun altool --upload-app \
    --file "$ipa" \
    --type ios \
    --apiKey "$APP_STORE_CONNECT_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
else
  xcrun iTMSTransporter \
    -m upload \
    -assetFile "$ipa" \
    -apiKey "$APP_STORE_CONNECT_KEY_ID" \
    -apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
fi

printf '%s\n' "upload-testflight: uploaded $ipa"
