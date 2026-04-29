#!/bin/sh

# Promote iOS builds from TestFlight toward App Store production.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: promote-ios-release.sh BUNDLE_ID [BUILD_NUMBER] [VERSION_STRING]

Promotes a TestFlight build by:
  1) resolving app by bundle id
  2) selecting a VALID build (optionally by build number)
  3) attaching build to an App Store version
  4) submitting for review (default)
  5) optionally creating a release when state is PENDING_DEVELOPER_RELEASE

Environment:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_PRIVATE_KEY_BASE64

Optional environment:
  IOS_SUBMIT_FOR_REVIEW=1|0      (default: 1)
  IOS_RELEASE_AFTER_APPROVAL=1|0 (default: 0)
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  printf '%s\n' "promote-ios-release: BUNDLE_ID and optional BUILD_NUMBER VERSION_STRING required" >&2
  exit 2
fi

bundle_id=${1-}
build_number=${2-}
version_string=${3-}

if [ -z "$bundle_id" ]; then
  printf '%s\n' "promote-ios-release: BUNDLE_ID required" >&2
  exit 2
fi

required_vars="APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_PRIVATE_KEY_BASE64"
for v in $required_vars; do
  eval "val=\${$v-}"
  if [ -z "$val" ]; then
    printf '%s\n' "promote-ios-release: missing required env: $v" >&2
    exit 1
  fi
done

valid_alnum() {
  case "${1-}" in ""|*[!A-Za-z0-9]*) return 1 ;; esac
}

valid_hex_dash() {
  case "${1-}" in ""|*[!A-Fa-f0-9-]*) return 1 ;; esac
}

valid_bundle_id() {
  case "${1-}" in *.*) ;; *) return 1 ;; esac
  case "$1" in .|.*|*.|*..*|*[!A-Za-z0-9.-]*) return 1 ;; esac
}

valid_query_token() {
  case "${1-}" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

valid_bool_flag() {
  case "${1-}" in 0|1) return 0 ;; esac
  return 1
}

require_api_token() {
  field=$1
  value=$2
  valid_query_token "$value" || {
    printf '%s\n' "promote-ios-release: invalid $field from API" >&2
    exit 1
  }
}

require_optional_api_token() {
  field=$1
  value=$2
  [ -z "$value" ] || require_api_token "$field" "$value"
}

valid_alnum "$APP_STORE_CONNECT_KEY_ID" || {
  printf '%s\n' "promote-ios-release: invalid App Store Connect key id" >&2
  exit 2
}

valid_hex_dash "$APP_STORE_CONNECT_ISSUER_ID" || {
  printf '%s\n' "promote-ios-release: invalid App Store Connect issuer id" >&2
  exit 2
}

valid_bundle_id "$bundle_id" || {
  printf '%s\n' "promote-ios-release: invalid bundle id" >&2
  exit 2
}

if [ -n "$build_number" ] && ! valid_query_token "$build_number"; then
  printf '%s\n' "promote-ios-release: invalid build number" >&2
  exit 2
fi

if [ -n "$version_string" ] && ! valid_query_token "$version_string"; then
  printf '%s\n' "promote-ios-release: invalid version string" >&2
  exit 2
fi

submit_for_review=${IOS_SUBMIT_FOR_REVIEW:-1}
release_after_approval=${IOS_RELEASE_AFTER_APPROVAL:-0}

valid_bool_flag "$submit_for_review" || {
  printf '%s\n' "promote-ios-release: invalid IOS_SUBMIT_FOR_REVIEW" >&2
  exit 2
}

valid_bool_flag "$release_after_approval" || {
  printf '%s\n' "promote-ios-release: invalid IOS_RELEASE_AFTER_APPROVAL" >&2
  exit 2
}

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "promote-ios-release: curl, jq, and openssl are required" >&2
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/asc-promote.XXXXXX")
key_file="$tmp_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

printf '%s' "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" | openssl base64 -d -A > "$key_file"

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now=$(date +%s)
exp=$((now + 1200))
header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$APP_STORE_CONNECT_KEY_ID")
claim=$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"appstoreconnect-v1"}' "$APP_STORE_CONNECT_ISSUER_ID" "$now" "$exp")
unsigned="$(printf '%s' "$header" | b64url).$(printf '%s' "$claim" | b64url)"
signature=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$key_file" -binary | b64url)
token="$unsigned.$signature"

api_request() {
  method=$1
  path=$2
  body=${3-}
  url="https://api.appstoreconnect.apple.com$path"

  if [ -n "$body" ]; then
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer $token"
  fi
}

api_json() {
  method=$1
  path=$2
  body=${3-}

  response=$(api_request "$method" "$path" "$body")

  if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "promote-ios-release: API returned invalid JSON" >&2
    printf '%s\n' "$response" >&2
    exit 1
  fi

  if printf '%s' "$response" | jq -e '.errors | type == "array" and length > 0' >/dev/null 2>&1; then
    printf '%s\n' "promote-ios-release: API error on $method $path" >&2
    printf '%s\n' "$response" >&2
    exit 1
  fi

  printf '%s' "$response"
}

apps_json=$(api_json GET "/v1/apps?filter[bundleId]=$bundle_id&limit=1")
app_id=$(printf '%s' "$apps_json" | jq -r '.data[0].id // empty')

if [ -z "$app_id" ]; then
  printf '%s\n' "promote-ios-release: app not found for bundle id: $bundle_id" >&2
  exit 1
fi
require_api_token "app id" "$app_id"

if [ -n "$build_number" ]; then
  builds_path="/v1/builds?filter[app]=$app_id&filter[processingState]=VALID&filter[version]=$build_number&sort=-uploadedDate&limit=1&include=preReleaseVersion"
else
  builds_path="/v1/builds?filter[app]=$app_id&filter[processingState]=VALID&sort=-uploadedDate&limit=1&include=preReleaseVersion"
fi

builds_json=$(api_json GET "$builds_path")
build_id=$(printf '%s' "$builds_json" | jq -r '.data[0].id // empty')
resolved_build_number=$(printf '%s' "$builds_json" | jq -r '.data[0].attributes.version // empty')
pre_rel_id=$(printf '%s' "$builds_json" | jq -r '.data[0].relationships.preReleaseVersion.data.id // empty')

if [ -z "$build_id" ]; then
  printf '%s\n' "promote-ios-release: no VALID build found for app" >&2
  exit 1
fi
require_api_token "build id" "$build_id"
require_optional_api_token "build number" "$resolved_build_number"

if [ -z "$version_string" ] && [ -n "$pre_rel_id" ]; then
  version_string=$(printf '%s' "$builds_json" | jq -r --arg id "$pre_rel_id" 'first(.included[]? | select(.type == "preReleaseVersions" and .id == $id) | .attributes.version) // empty')
fi

if [ -z "$version_string" ]; then
  printf '%s\n' "promote-ios-release: VERSION_STRING required (argument 3) when it cannot be inferred" >&2
  exit 1
fi
valid_query_token "$version_string" || {
  printf '%s\n' "promote-ios-release: invalid version string from API" >&2
  exit 1
}

versions_json=$(api_json GET "/v1/appStoreVersions?filter[app]=$app_id&filter[platform]=IOS&filter[versionString]=$version_string&limit=1")
version_id=$(printf '%s' "$versions_json" | jq -r '.data[0].id // empty')

if [ -z "$version_id" ]; then
  create_payload=$(jq -n \
    --arg app_id "$app_id" \
    --arg ver "$version_string" \
    '{data:{type:"appStoreVersions",attributes:{platform:"IOS",versionString:$ver},relationships:{app:{data:{type:"apps",id:$app_id}}}}}')
  create_json=$(api_json POST "/v1/appStoreVersions" "$create_payload")
  version_id=$(printf '%s' "$create_json" | jq -r '.data.id // empty')
fi

if [ -z "$version_id" ]; then
  printf '%s\n' "promote-ios-release: failed to resolve App Store version id" >&2
  exit 1
fi
require_api_token "version id" "$version_id"

assign_payload=$(jq -n --arg build_id "$build_id" '{data:{type:"builds",id:$build_id}}')
api_json PATCH "/v1/appStoreVersions/$version_id/relationships/build" "$assign_payload" >/dev/null

version_json=$(api_json GET "/v1/appStoreVersions/$version_id")
state=$(printf '%s' "$version_json" | jq -r '.data.attributes.appStoreState // ""')
require_optional_api_token "version state" "$state"

if [ "$submit_for_review" = "1" ] && [ "$state" = "PREPARE_FOR_SUBMISSION" ]; then
  submit_payload=$(jq -n --arg version_id "$version_id" '{data:{type:"appStoreVersionSubmissions",relationships:{appStoreVersion:{data:{type:"appStoreVersions",id:$version_id}}}}}')
  api_json POST "/v1/appStoreVersionSubmissions" "$submit_payload" >/dev/null
  state="WAITING_FOR_REVIEW"
fi

if [ "$release_after_approval" = "1" ]; then
  version_json=$(api_json GET "/v1/appStoreVersions/$version_id")
  state=$(printf '%s' "$version_json" | jq -r '.data.attributes.appStoreState // ""')
  require_optional_api_token "version state" "$state"

  if [ "$state" = "PENDING_DEVELOPER_RELEASE" ]; then
    release_payload=$(jq -n --arg version_id "$version_id" '{data:{type:"appStoreVersionReleases",relationships:{appStoreVersion:{data:{type:"appStoreVersions",id:$version_id}}}}}')
    api_json POST "/v1/appStoreVersionReleases" "$release_payload" >/dev/null
    state="READY_FOR_SALE"
  fi
fi

printf '%s\n' "promote-ios-release: bundle=$bundle_id app_id=$app_id build_id=$build_id build_number=$resolved_build_number version=$version_string state=$state"
