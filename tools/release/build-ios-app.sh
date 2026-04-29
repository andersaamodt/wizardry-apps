#!/bin/sh

# Build wizardry iOS host app for a specific app slug.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: build-ios-app.sh APP_SLUG OUT_DIR [smoke|release]

Modes:
  smoke   Build unsigned iOS simulator app for CI validation.
  release Build signed App Store IPA (requires secrets).
USAGE
  exit 0
  ;;
esac

set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  printf '%s\n' "build-ios-app: APP_SLUG OUT_DIR and optional mode required" >&2
  exit 2
fi

slug=${1-}
out_dir=${2-}
mode=${3-smoke}

if [ -z "$slug" ] || [ -z "$out_dir" ]; then
  printf '%s\n' "build-ios-app: APP_SLUG and OUT_DIR required" >&2
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

if has_line_break "$out_dir"; then
  printf '%s\n' "build-ios-app: output directory must not contain line breaks" >&2
  exit 2
fi

case "$out_dir" in
  -*)
    printf '%s\n' "build-ios-app: output directory must be a safe path" >&2
    exit 2
    ;;
esac

valid_app_slug() {
  case "${1-}" in
    [a-z]*)
      ;;
    *)
      return 1
      ;;
  esac
  case "$1" in
    *[!a-z0-9-]*|*-|*--*)
      return 1
      ;;
  esac
  return 0
}

valid_app_slug "$slug" || {
  printf '%s\n' "build-ios-app: invalid app slug" >&2
  exit 2
}

case "$mode" in
  smoke|release) ;;
  *)
    printf '%s\n' "build-ios-app: invalid mode: $mode" >&2
    exit 2
    ;;
esac

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
IOS_ROOT="$ROOT_DIR/apps/.host/ios"
APP_NAME=$(sh "$ROOT_DIR/tools/release/get-app-name.sh" "$slug")
BUNDLE_ID=$(sh "$ROOT_DIR/tools/release/get-app-bundle-id.sh" ios "$slug")
VERSION_NAME=${RELEASE_VERSION:-0.1.0}
case "$VERSION_NAME" in
  v*) VERSION_NAME=${VERSION_NAME#v} ;;
esac

valid_alnum() {
  case "${1-}" in ""|*[!A-Za-z0-9]*) return 1 ;; esac
}

valid_hex_dash() {
  case "${1-}" in ""|*[!A-Fa-f0-9-]*) return 1 ;; esac
}

valid_ios_version() {
  case "${1-}" in ""|*[!0-9.]*|.*|*.|*..*) return 1 ;; esac
  printf '%s\n' "$1" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$'
}

valid_ios_version "$VERSION_NAME" || {
  printf '%s\n' "build-ios-app: invalid release version" >&2
  exit 2
}

if [ "$mode" = "release" ]; then
  required_vars="APPLE_P12_BASE64 APPLE_P12_PASSWORD APPLE_TEAM_ID APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_PRIVATE_KEY_BASE64"
  for v in $required_vars; do
    eval "val=\${$v-}"
    if [ -z "$val" ]; then
      printf '%s\n' "build-ios-app: missing required env: $v" >&2
      exit 1
    fi
  done

  valid_alnum "$APPLE_TEAM_ID" || {
    printf '%s\n' "build-ios-app: invalid Apple team id" >&2
    exit 2
  }

  valid_alnum "$APP_STORE_CONNECT_KEY_ID" || {
    printf '%s\n' "build-ios-app: invalid App Store Connect key id" >&2
    exit 2
  }

  valid_hex_dash "$APP_STORE_CONNECT_ISSUER_ID" || {
    printf '%s\n' "build-ios-app: invalid App Store Connect issuer id" >&2
    exit 2
  }
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' "build-ios-app: xcodebuild is required" >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  printf '%s\n' "build-ios-app: xcodegen is required" >&2
  exit 1
fi

build_root="$ROOT_DIR/_tmp/ios-build-$slug"
project_dir="$build_root/project"
derived_data="$build_root/DerivedData"
archive_path="$build_root/$slug.xcarchive"

rm -rf "$build_root"
mkdir -p "$project_dir" "$out_dir"

cp -R "$IOS_ROOT/Host" "$project_dir/Host"
mkdir -p "$project_dir/Resources"
sh "$ROOT_DIR/tools/release/stage-web-assets.sh" "$slug" "$project_dir/Resources"
mkdir -p "$project_dir/Host/Assets.xcassets"
cat > "$project_dir/Host/Assets.xcassets/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "wizardry",
    "version" : 1
  }
}
JSON
sh "$ROOT_DIR/tools/icons/stage-ios-appiconset.sh" "$ROOT_DIR/apps/$slug" "$project_dir/Host/Assets.xcassets"

project_yml="$project_dir/project.yml"
cp "$IOS_ROOT/project-template.yml" "$project_yml"

esc() {
  printf '%s' "$1" | sed -e 's/[\\&/]/\\&/g'
}

sed -i '' "s/__APP_NAME__/$(esc "$APP_NAME")/g" "$project_yml"
sed -i '' "s/__BUNDLE_ID__/$(esc "$BUNDLE_ID")/g" "$project_yml"
sed -i '' "s/__APP_VERSION__/$(esc "$VERSION_NAME")/g" "$project_yml"

(
  cd "$project_dir"
  xcodegen generate --spec "$project_yml"
)

if [ "$mode" = "smoke" ]; then
  xcodebuild \
    -project "$project_dir/WizardryHost.xcodeproj" \
    -scheme WizardryHost \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build >/tmp/wizardry-ios-smoke-$slug.log

  app_path="$derived_data/Build/Products/Debug-iphonesimulator/WizardryHost.app"
  [ -d "$app_path" ] || {
    printf '%s\n' "build-ios-app: smoke app bundle not found: $app_path" >&2
    exit 1
  }

  zip_path="$out_dir/wizardry-$slug-ios-simulator.app.zip"
  rm -f "$zip_path"
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
  printf '%s\n' "build-ios-app: smoke artifact -> $zip_path"
  exit 0
fi

# release mode requires signing credentials.
keychain="$build_root/wizardry-signing.keychain-db"
keychain_password="wizardry-ci-$(date +%s)"
cert_file="$build_root/apple-cert.p12"
api_key_file="$build_root/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
export_options="$build_root/ExportOptions.plist"

cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

printf '%s' "$APPLE_P12_BASE64" | openssl base64 -d -A > "$cert_file"
printf '%s' "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" | openssl base64 -d -A > "$api_key_file"

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain"
security import "$cert_file" -k "$keychain" -P "$APPLE_P12_PASSWORD" -A
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain"

cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

xcodebuild \
  -project "$project_dir/WizardryHost.xcodeproj" \
  -scheme WizardryHost \
  -configuration Release \
  -archivePath "$archive_path" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$api_key_file" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" \
  archive >/tmp/wizardry-ios-release-$slug.log

export_path="$build_root/export"
mkdir -p "$export_path"

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$api_key_file" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" >/tmp/wizardry-ios-export-$slug.log

ipa=$(find "$export_path" -maxdepth 1 -type f -name '*.ipa' | head -n 1 || true)
if [ -z "$ipa" ]; then
  printf '%s\n' "build-ios-app: export did not produce an ipa" >&2
  exit 1
fi

out_ipa="$out_dir/wizardry-$slug-ios.ipa"
cp "$ipa" "$out_ipa"
printf '%s\n' "build-ios-app: release artifact -> $out_ipa"
