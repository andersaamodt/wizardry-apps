#!/bin/sh

# Promote an existing Play release between tracks.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: promote-play-track.sh PACKAGE_NAME [FROM_TRACK] [TO_TRACK] [VERSION_CODES]

FROM_TRACK defaults to internal.
TO_TRACK defaults to production.
VERSION_CODES is optional comma-separated list.
Requires PLAY_SERVICE_ACCOUNT_JSON_BASE64.
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 4 ]; then
  printf '%s\n' "promote-play-track: PACKAGE_NAME and optional FROM_TRACK TO_TRACK VERSION_CODES required" >&2
  exit 2
fi

package_name=${1-}
from_track=${2-internal}
to_track=${3-production}
version_codes_csv=${4-}

if [ -z "$package_name" ]; then
  printf '%s\n' "promote-play-track: PACKAGE_NAME required" >&2
  exit 2
fi

valid_package_name() {
  case "${1-}" in *.*) ;; *) return 1 ;; esac
  case "$1" in .|.*|*.|*..*|*[!A-Za-z0-9._]*) return 1 ;; esac
}

valid_track_name() {
  case "${1-}" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

valid_version_codes() {
  case "${1-}" in ""|*[!0-9,]*|*,|,*|*,,*) return 1 ;; esac
}

valid_query_token() {
  case "${1-}" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

valid_bearer_token() {
  case "${1-}" in ""|*[!A-Za-z0-9._~+/=-]*) return 1 ;; esac
}

valid_service_account_email() {
  case "${1-}" in ""|*[!A-Za-z0-9._%+@-]*|*@*@*|@*|*@|*.|*@.*) return 1 ;; esac
  case "$1" in *@*.*) return 0 ;; *) return 1 ;; esac
}

valid_package_name "$package_name" || {
  printf '%s\n' "promote-play-track: invalid package name" >&2
  exit 2
}

valid_track_name "$from_track" && valid_track_name "$to_track" || {
  printf '%s\n' "promote-play-track: invalid track" >&2
  exit 2
}

if [ -n "$version_codes_csv" ] && ! valid_version_codes "$version_codes_csv"; then
  printf '%s\n' "promote-play-track: invalid version codes" >&2
  exit 2
fi

if [ -z "${PLAY_SERVICE_ACCOUNT_JSON_BASE64-}" ]; then
  printf '%s\n' "promote-play-track: missing PLAY_SERVICE_ACCOUNT_JSON_BASE64" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "promote-play-track: jq curl openssl are required" >&2
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/play-promote.XXXXXX")
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
  printf '%s\n' "promote-play-track: invalid service account json (client_email)" >&2
  exit 1
fi

valid_service_account_email "$client_email" || {
  printf '%s\n' "promote-play-track: invalid service account json (client_email)" >&2
  exit 1
}

if [ -z "$private_key" ] || [ "$private_key" = "null" ]; then
  printf '%s\n' "promote-play-track: invalid service account json (private_key)" >&2
  exit 1
fi

printf '%s' "$private_key" > "$svc_key"

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now=$(date +%s)
exp=$((now + 3600))
header='{"alg":"RS256","typ":"JWT"}'
claim=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","iat":%s,"exp":%s}' "$client_email" "$now" "$exp")
unsigned="$(printf '%s' "$header" | b64url).$(printf '%s' "$claim" | b64url)"
signature=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$svc_key" -binary | b64url)
assertion="$unsigned.$signature"

token_json=$(curl -sS -X POST "https://oauth2.googleapis.com/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  --data-urlencode "assertion=$assertion")
access_token=$(printf '%s' "$token_json" | jq -r '.access_token')

if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
  printf '%s\n' "promote-play-track: token request failed" >&2
  printf '%s\n' "$token_json" >&2
  exit 1
fi
valid_bearer_token "$access_token" || {
  printf '%s\n' "promote-play-track: invalid access token from API" >&2
  exit 1
}

api_base="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package_name/edits"

edit_json=$(curl -sS -X POST "$api_base" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  -d '{}')
edit_id=$(printf '%s' "$edit_json" | jq -r '.id')

if [ -z "$edit_id" ] || [ "$edit_id" = "null" ]; then
  printf '%s\n' "promote-play-track: create edit failed" >&2
  printf '%s\n' "$edit_json" >&2
  exit 1
fi
valid_query_token "$edit_id" || {
  printf '%s\n' "promote-play-track: invalid edit id from API" >&2
  exit 1
}

if [ -z "$version_codes_csv" ]; then
  source_track_json=$(curl -sS -X GET "$api_base/$edit_id/tracks/$from_track" \
    -H "Authorization: Bearer $access_token")

  if ! printf '%s' "$source_track_json" | jq -e '.releases | type == "array" and length > 0' >/dev/null 2>&1; then
    printf '%s\n' "promote-play-track: source track has no releases: $from_track" >&2
    printf '%s\n' "$source_track_json" >&2
    exit 1
  fi

  version_codes_csv=$(printf '%s' "$source_track_json" | jq -r '[.releases[0].versionCodes[]] | join(",")')
  valid_version_codes "$version_codes_csv" || {
    printf '%s\n' "promote-play-track: invalid version codes from API" >&2
    exit 1
  }
fi

if [ -z "$version_codes_csv" ]; then
  printf '%s\n' "promote-play-track: no version codes to promote" >&2
  exit 1
fi

track_payload=$(jq -n \
  --arg status "completed" \
  --arg codes "$version_codes_csv" \
  '{releases:[{status:$status,versionCodes:($codes | split(","))}]}' )

promote_json=$(curl -sS -X PUT "$api_base/$edit_id/tracks/$to_track" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  -d "$track_payload")

if ! printf '%s' "$promote_json" | jq -e '.releases | type == "array" and length > 0' >/dev/null 2>&1; then
  printf '%s\n' "promote-play-track: failed to write destination track: $to_track" >&2
  printf '%s\n' "$promote_json" >&2
  exit 1
fi

commit_json=$(curl -sS -X POST "$api_base/$edit_id:commit" \
  -H "Authorization: Bearer $access_token")

if ! printf '%s' "$commit_json" | jq -e --arg id "$edit_id" '.id == $id' >/dev/null 2>&1; then
  printf '%s\n' "promote-play-track: failed to commit edit" >&2
  printf '%s\n' "$commit_json" >&2
  exit 1
fi

printf '%s\n' "promote-play-track: promoted $package_name $from_track -> $to_track versions=$version_codes_csv"
