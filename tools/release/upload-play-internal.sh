#!/bin/sh

# Upload Android AAB to Google Play using Android Publisher API.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: upload-play-internal.sh AAB_PATH PACKAGE_NAME [TRACK]

TRACK defaults to "internal".
Requires PLAY_SERVICE_ACCOUNT_JSON_BASE64 env var.
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  printf '%s\n' "upload-play-internal: AAB_PATH PACKAGE_NAME and optional TRACK required" >&2
  exit 2
fi

aab=${1-}
package_name=${2-}
track=${3-internal}

if [ -z "$aab" ] || [ ! -f "$aab" ]; then
  printf '%s\n' "upload-play-internal: AAB_PATH required" >&2
  exit 2
fi

if [ -z "$package_name" ]; then
  printf '%s\n' "upload-play-internal: PACKAGE_NAME required" >&2
  exit 2
fi

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

valid_package_name() {
  case "${1-}" in *.*) ;; *) return 1 ;; esac
  case "$1" in .|.*|*.|*..*|*[!A-Za-z0-9._]*) return 1 ;; esac
}

valid_track_name() {
  case "${1-}" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

valid_release_status() {
  case "${1-}" in completed|draft|halted|inProgress) return 0 ;; esac
  return 1
}

valid_query_token() {
  case "${1-}" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

valid_version_code() {
  case "${1-}" in ""|*[!0-9]*) return 1 ;; esac
}

valid_bearer_token() {
  case "${1-}" in ""|*[!A-Za-z0-9._~+/=-]*) return 1 ;; esac
}

valid_service_account_email() {
  case "${1-}" in ""|*[!A-Za-z0-9._%+@-]*|*@*@*|@*|*@|*.|*@.*) return 1 ;; esac
  case "$1" in *@*.*) return 0 ;; *) return 1 ;; esac
}

if has_line_break "$aab"; then
  printf '%s\n' "upload-play-internal: AAB path must not contain line breaks" >&2
  exit 2
fi

case "$aab" in
  *.aab) ;;
  *)
    printf '%s\n' "upload-play-internal: AAB path must end with .aab" >&2
    exit 2
    ;;
esac

valid_package_name "$package_name" || {
  printf '%s\n' "upload-play-internal: invalid package name" >&2
  exit 2
}

valid_track_name "$track" || {
  printf '%s\n' "upload-play-internal: invalid track" >&2
  exit 2
}

release_status=${PLAY_RELEASE_STATUS:-completed}
valid_release_status "$release_status" || {
  printf '%s\n' "upload-play-internal: invalid release status" >&2
  exit 2
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "upload-play-internal: jq is required" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "upload-play-internal: openssl is required" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' "upload-play-internal: curl is required" >&2
  exit 1
fi

if [ -z "${PLAY_SERVICE_ACCOUNT_JSON_BASE64-}" ]; then
  printf '%s\n' "upload-play-internal: missing service account secret" >&2
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/play-upload.XXXXXX")
svc_json="$tmp_dir/service-account.json"
svc_key="$tmp_dir/service-account.pem"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

printf '%s' "$PLAY_SERVICE_ACCOUNT_JSON_BASE64" | openssl base64 -d -A > "$svc_json"

client_email=$(jq -r '.client_email' "$svc_json")
private_key=$(jq -r '.private_key' "$svc_json")

if [ -z "$client_email" ] || [ "$client_email" = "null" ]; then
  printf '%s\n' "upload-play-internal: invalid service account json (client_email)" >&2
  exit 1
fi

valid_service_account_email "$client_email" || {
  printf '%s\n' "upload-play-internal: invalid service account json (client_email)" >&2
  exit 1
}

if [ -z "$private_key" ] || [ "$private_key" = "null" ]; then
  printf '%s\n' "upload-play-internal: invalid service account json (private_key)" >&2
  exit 1
fi

printf '%s' "$private_key" > "$svc_key"

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

jwt_header='{"alg":"RS256","typ":"JWT"}'
now=$(date +%s)
exp=$((now + 3600))
jwt_claim=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","iat":%s,"exp":%s}' "$client_email" "$now" "$exp")

unsigned_token="$(printf '%s' "$jwt_header" | b64url).$(printf '%s' "$jwt_claim" | b64url)"
signature=$(printf '%s' "$unsigned_token" | openssl dgst -sha256 -sign "$svc_key" -binary | b64url)
assertion="$unsigned_token.$signature"

token_json=$(curl -sS -X POST "https://oauth2.googleapis.com/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  --data-urlencode "assertion=$assertion")

access_token=$(printf '%s' "$token_json" | jq -r '.access_token')
if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
  printf '%s\n' "upload-play-internal: failed to acquire oauth token" >&2
  printf '%s\n' "$token_json" >&2
  exit 1
fi
valid_bearer_token "$access_token" || {
  printf '%s\n' "upload-play-internal: invalid access token from API" >&2
  exit 1
}

api_base="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package_name/edits"

edit_json=$(curl -sS -X POST "$api_base" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  -d '{}')

edit_id=$(printf '%s' "$edit_json" | jq -r '.id')
if [ -z "$edit_id" ] || [ "$edit_id" = "null" ]; then
  printf '%s\n' "upload-play-internal: failed to create edit" >&2
  printf '%s\n' "$edit_json" >&2
  exit 1
fi
valid_query_token "$edit_id" || {
  printf '%s\n' "upload-play-internal: invalid edit id from API" >&2
  exit 1
}

bundle_json=$(curl -sS -X POST \
  "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package_name/edits/$edit_id/bundles?uploadType=media" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$aab")

version_code=$(printf '%s' "$bundle_json" | jq -r '.versionCode')
if [ -z "$version_code" ] || [ "$version_code" = "null" ]; then
  printf '%s\n' "upload-play-internal: bundle upload failed" >&2
  printf '%s\n' "$bundle_json" >&2
  exit 1
fi
valid_version_code "$version_code" || {
  printf '%s\n' "upload-play-internal: invalid version code from API" >&2
  exit 1
}

release_name=${PLAY_RELEASE_NAME:-wizardry-apps-$package_name-$version_code}

track_payload=$(jq -n \
  --arg vc "$version_code" \
  --arg name "$release_name" \
  --arg status "$release_status" \
  '{releases:[{name:$name,status:$status,versionCodes:[$vc]}]}')

track_json=$(curl -sS -X PUT "$api_base/$edit_id/tracks/$track" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  -d "$track_payload")

if ! printf '%s' "$track_json" | jq -e '.releases | type == "array"' >/dev/null 2>&1; then
  printf '%s\n' "upload-play-internal: failed to assign release track" >&2
  printf '%s\n' "$track_json" >&2
  exit 1
fi

commit_json=$(curl -sS -X POST "$api_base/$edit_id:commit" \
  -H "Authorization: Bearer $access_token")

if ! printf '%s' "$commit_json" | jq -e --arg id "$edit_id" '.id == $id' >/dev/null 2>&1; then
  printf '%s\n' "upload-play-internal: failed to commit edit" >&2
  printf '%s\n' "$commit_json" >&2
  exit 1
fi

printf '%s\n' "upload-play-internal: uploaded $aab to $package_name track=$track versionCode=$version_code"
