#!/bin/sh

# Build App Forge macOS app bundle.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: build-forge-macos-app.sh [--root ROOT_DIR] [--out APP_BUNDLE] [--bundle-id BUNDLE_ID]

Builds a self-contained App Forge .app bundle with:
- native WebKit host binary
- Forge app assets
- shared bridge assets
- core source/include payload
- icon resource (.icns)
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)

root=$DEFAULT_ROOT
out_bundle="$root/_tmp/workbench/dist/macos/App Forge.app"
bundle_id="com.wizardry.apps.forge.local"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root=${2-}
      [ -n "$root" ] || {
        printf '%s\n' "build-forge-macos-app: --root requires ROOT_DIR" >&2
        exit 2
      }
      shift 2
      ;;
    --out)
      out_bundle=${2-}
      [ -n "$out_bundle" ] || {
        printf '%s\n' "build-forge-macos-app: --out requires APP_BUNDLE" >&2
        exit 2
      }
      shift 2
      ;;
    --bundle-id)
      bundle_id=${2-}
      [ -n "$bundle_id" ] || {
        printf '%s\n' "build-forge-macos-app: --bundle-id requires BUNDLE_ID" >&2
        exit 2
      }
      shift 2
      ;;
    *)
      printf '%s\n' "build-forge-macos-app: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

[ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ] || {
  printf '%s\n' "build-forge-macos-app: macOS required" >&2
  exit 1
}

for req in \
  "$root/.apps/.host/macos/main.m" \
  "$root/.apps/forge/index.html" \
  "$root/.apps/.host/shared/wizardry-bridge.js"; do
  [ -f "$req" ] || {
    printf '%s\n' "build-forge-macos-app: missing required file: $req" >&2
    exit 1
  }
done

command -v clang >/dev/null 2>&1 || {
  printf '%s\n' "build-forge-macos-app: clang required" >&2
  exit 1
}

cache_dir="$root/_tmp/forge-build-cache"
host_src="$root/.apps/.host/macos/main.m"
host_bin="$cache_dir/wizardry-host-macos"
module_cache="$cache_dir/clang-module-cache"

mkdir -p "$cache_dir" "$module_cache"

if [ ! -x "$host_bin" ] || [ "$host_src" -nt "$host_bin" ]; then
  CLANG_MODULE_CACHE_PATH="$module_cache" \
    clang -O2 -fobjc-arc -fmodules "$host_src" -o "$host_bin" -framework Cocoa -framework WebKit
fi

stage_root=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-build.XXXXXX")
stage_bundle="$stage_root/App Forge.app"
macos_dir="$stage_bundle/Contents/MacOS"
resources_dir="$stage_bundle/Contents/Resources"
plist="$stage_bundle/Contents/Info.plist"

cleanup() {
  rm -rf "$stage_root"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$macos_dir" "$resources_dir/forge" "$resources_dir/wizardry-apps/core"

cp "$host_bin" "$macos_dir/wizardry-host"
cp -R "$root/.apps/forge"/. "$resources_dir/forge/"
mkdir -p "$resources_dir/forge/.host"
cp -R "$root/.apps/.host/shared" "$resources_dir/forge/.host/"
cp -R "$root/core/include" "$resources_dir/wizardry-apps/core/"
cp -R "$root/core/src" "$resources_dir/wizardry-apps/core/"
printf '%s\n' "$root" > "$resources_dir/wizardry-apps-root.txt"

cat > "$macos_dir/app-forge" <<'APP'
#!/bin/sh
set -eu
APPDIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
ROOT_FILE="$APPDIR/Resources/wizardry-apps-root.txt"
USER_ROOT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/forge-root"
APP_ENTRY="$APPDIR/Resources/forge"

if [ -z "${WIZARDRY_APPS_ROOT-}" ]; then
  if [ -f "$ROOT_FILE" ]; then
    WIZARDRY_APPS_ROOT=$(head -n 1 "$ROOT_FILE" 2>/dev/null | tr -d '\r')
  elif [ -f "$USER_ROOT_FILE" ]; then
    WIZARDRY_APPS_ROOT=$(head -n 1 "$USER_ROOT_FILE" 2>/dev/null | tr -d '\r')
  fi
  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && [ -d "$WIZARDRY_APPS_ROOT" ]; then
    export WIZARDRY_APPS_ROOT
  fi
fi

if [ -n "${WIZARDRY_APPS_ROOT-}" ] && [ -d "$WIZARDRY_APPS_ROOT" ]; then
  cd "$WIZARDRY_APPS_ROOT"
fi

exec "$APPDIR/MacOS/wizardry-host" "$APP_ENTRY"
APP
chmod +x "$macos_dir/app-forge"

icon_key=''
if [ -x "$root/tools/forge/build-forge-icon.sh" ]; then
  if sh "$root/tools/forge/build-forge-icon.sh" --root "$root" --out "$resources_dir/forge.icns" >/dev/null 2>&1; then
    icon_key='<key>CFBundleIconFile</key><string>forge.icns</string>'
  fi
fi

cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>App Forge</string>
<key>CFBundleDisplayName</key><string>App Forge</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>app-forge</string>
$icon_key
</dict></plist>
PLIST

mkdir -p "$(dirname "$out_bundle")"
rm -rf "$out_bundle"
cp -R "$stage_bundle" "$out_bundle"

printf '%s\n' "app_bundle=$out_bundle"
printf '%s\n' "host_binary=$host_bin"
