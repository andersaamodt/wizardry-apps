#!/bin/sh

# Build App Forge macOS app bundle.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: build-forge-macos-app [--root ROOT_DIR] [--out APP_BUNDLE] [--bundle-id BUNDLE_ID]

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

hash_stdin_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | awk '{ print $NF }'
    return 0
  fi
  printf '%s\n' "build-forge-macos-app: sha256 tool not available (requires shasum, sha256sum, or openssl)" >&2
  exit 1
}

hash_file_sha256() {
  file=$1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{ print $1 }'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{ print $1 }'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{ print $NF }'
    return 0
  fi
  printf '%s\n' "build-forge-macos-app: sha256 tool not available (requires shasum, sha256sum, or openssl)" >&2
  exit 1
}

hash_path_sha256() {
  path=$1
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    printf '%s\n' "missing"
    return 0
  fi

  if [ -L "$path" ]; then
    printf 'L %s\n' "$(readlink "$path")" | hash_stdin_sha256
    return 0
  fi

  if [ -f "$path" ]; then
    printf 'F %s\n' "$(hash_file_sha256 "$path")" | hash_stdin_sha256
    return 0
  fi

  listing=$(mktemp "${TMPDIR:-/tmp}/forge-macos-path-hash.XXXXXX")
  (
    cd "$path" || exit 1
    find . -mindepth 1 -print | LC_ALL=C sort
  ) > "$listing"

  {
    while IFS= read -r rel; do
      node=${rel#./}
      abs="$path/$node"
      if [ -L "$abs" ]; then
        printf 'L %s %s\n' "$node" "$(readlink "$abs")"
      elif [ -f "$abs" ]; then
        printf 'F %s %s\n' "$node" "$(hash_file_sha256 "$abs")"
      elif [ -d "$abs" ]; then
        printf 'D %s\n' "$node"
      else
        printf 'X %s\n' "$node"
      fi
    done < "$listing"
  } | hash_stdin_sha256

  rm -f "$listing"
}

macos_bundle_signature_is_usable() {
  bundle_path=$1
  [ -d "$bundle_path" ] || return 1
  command -v codesign >/dev/null 2>&1 || return 0
  codesign --verify --deep --strict "$bundle_path" >/dev/null 2>&1
}

ensure_macos_bundle_signature() {
  bundle_path=$1
  [ -d "$bundle_path" ] || return 1
  command -v codesign >/dev/null 2>&1 || return 0
  if macos_bundle_signature_is_usable "$bundle_path"; then
    return 0
  fi
  codesign --force --deep --sign - "$bundle_path" >/dev/null 2>&1 || return 1
  macos_bundle_signature_is_usable "$bundle_path"
}

forge_bundle_input_hash() {
  {
    printf 'v=2\n'
    printf 'bundle_id=%s\n' "$bundle_id"
    printf 'host_src=%s\n' "$(hash_path_sha256 "$root/apps/.host/macos/main.m")"
    printf 'forge_app=%s\n' "$(hash_path_sha256 "$root/apps/forge")"
    printf 'shared=%s\n' "$(hash_path_sha256 "$root/apps/.host/shared")"
    printf 'core_include=%s\n' "$(hash_path_sha256 "$root/runtime/core/include")"
    printf 'core_src=%s\n' "$(hash_path_sha256 "$root/runtime/core/src")"
    printf 'icon_builder=%s\n' "$(hash_path_sha256 "$root/tools/forge/build-forge-icon.sh")"
    printf 'bundle_builder=%s\n' "$(hash_path_sha256 "$root/tools/forge/build-forge-macos-app.sh")"
  } | hash_stdin_sha256
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)

root=$DEFAULT_ROOT
out_bundle="$root/_tmp/workbench/dist/macos/App Forge.app"
bundle_id="com.wizardry.apps.forge.macos"

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

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

valid_bundle_id() {
  case "${1-}" in *.*) ;; *) return 1 ;; esac
  case "$1" in .|.*|*.|*..*|*[!A-Za-z0-9.-]*) return 1 ;; esac
}

valid_app_bundle_path() {
  case "${1-}" in
    *.app) return 0 ;;
  esac
  return 1
}

safe_app_bundle_path() {
  valid_app_bundle_path "${1-}" || return 1
  case "${1-}" in
    -*|.|..|./*|../*|*/./*|*/../*|*/.|*/..)
      return 1
      ;;
  esac
  return 0
}

if has_line_break "$root"; then
  printf '%s\n' "build-forge-macos-app: root path must not contain line breaks" >&2
  exit 2
fi

if has_line_break "$out_bundle"; then
  printf '%s\n' "build-forge-macos-app: output path must not contain line breaks" >&2
  exit 2
fi

valid_app_bundle_path "$out_bundle" || {
  printf '%s\n' "build-forge-macos-app: output path must be a .app bundle" >&2
  exit 2
}

safe_app_bundle_path "$out_bundle" || {
  printf '%s\n' "build-forge-macos-app: output path must be a safe .app bundle path" >&2
  exit 2
}

valid_bundle_id "$bundle_id" || {
  printf '%s\n' "build-forge-macos-app: invalid bundle id" >&2
  exit 2
}

[ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ] || {
  printf '%s\n' "build-forge-macos-app: macOS required" >&2
  exit 1
}

for req in \
  "$root/apps/.host/macos/main.m" \
  "$root/apps/forge/index.html" \
  "$root/apps/.host/shared/wizardry-bridge.js"; do
  [ -f "$req" ] || {
    printf '%s\n' "build-forge-macos-app: missing required file: $req" >&2
    exit 1
  }
done

[ -d "$root/templates/web/.themes" ] || {
  printf '%s\n' "build-forge-macos-app: missing required directory: $root/templates/web/.themes" >&2
  exit 1
}

command -v clang >/dev/null 2>&1 || {
  printf '%s\n' "build-forge-macos-app: clang required" >&2
  exit 1
}

cache_dir="$root/_tmp/forge-build-cache"
host_src="$root/apps/.host/macos/main.m"
host_bin="$cache_dir/wizardry-host-macos"
module_cache="$cache_dir/clang-module-cache"

mkdir -p "$cache_dir" "$module_cache"

if [ ! -x "$host_bin" ] || [ "$host_src" -nt "$host_bin" ]; then
  CLANG_MODULE_CACHE_PATH="$module_cache" \
    clang -O2 -fobjc-arc -fmodules "$host_src" -o "$host_bin" -framework Cocoa -framework WebKit
fi

expected_hash=$(forge_bundle_input_hash)
hash_file="$out_bundle/Contents/Resources/wizardry-build-input.sha256"
root_file="$out_bundle/Contents/Resources/wizardry-apps-root.txt"
plist_file="$out_bundle/Contents/Info.plist"

if [ -d "$out_bundle" ] &&
   [ -x "$out_bundle/Contents/MacOS/app-forge" ] &&
   [ -x "$out_bundle/Contents/MacOS/wizardry-host" ] &&
   [ -f "$hash_file" ] &&
   [ -f "$root_file" ] &&
   [ -f "$plist_file" ]; then
  cached_hash=$(head -n 1 "$hash_file" 2>/dev/null | tr -d '\r')
  cached_root=$(head -n 1 "$root_file" 2>/dev/null | tr -d '\r')
  if [ "$cached_hash" = "$expected_hash" ] && [ "$cached_root" = "$root" ] && grep -F "<string>$bundle_id</string>" "$plist_file" >/dev/null 2>&1 && ensure_macos_bundle_signature "$out_bundle"; then
    printf '%s\n' "app_bundle=$out_bundle"
    printf '%s\n' "host_binary=$host_bin"
    printf '%s\n' "cache=hit"
    exit 0
  fi
fi

stage_root=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-build.XXXXXX")
stage_bundle="$stage_root/App Forge.app"
macos_dir="$stage_bundle/Contents/MacOS"
resources_dir="$stage_bundle/Contents/Resources"
plist="$stage_bundle/Contents/Info.plist"
final_stage_root=''

cleanup() {
  rm -rf "$stage_root"
  [ -z "$final_stage_root" ] || rm -rf "$final_stage_root"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$macos_dir" "$resources_dir/forge" "$resources_dir/.host" "$resources_dir/wizardry-apps/core"

cp "$host_bin" "$macos_dir/wizardry-host"
for entry in "$root/apps/forge"/* "$root/apps/forge"/.[!.]* "$root/apps/forge"/..?*; do
  [ -e "$entry" ] || continue
  base=$(basename "$entry")
  [ "$base" = "." ] && continue
  [ "$base" = ".." ] && continue
  [ "$base" = "themes" ] && continue
  cp -R "$entry" "$resources_dir/forge/"
done
mkdir -p "$resources_dir/forge/.host"
cp -R "$root/apps/.host/shared" "$resources_dir/forge/.host/"
cp -R "$root/apps/.host/shared" "$resources_dir/.host/"
cp -R "$root/runtime/core/include" "$resources_dir/wizardry-apps/core/"
cp -R "$root/runtime/core/src" "$resources_dir/wizardry-apps/core/"
printf '%s\n' "$root" > "$resources_dir/wizardry-apps-root.txt"
printf '%s\n' "$expected_hash" > "$resources_dir/wizardry-build-input.sha256"

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
if [ -x "$root/tools/forge/build-forge-icon" ]; then
  built_icon_tmp="$stage_root/forge-icon-built.icns"
  if "$root/tools/forge/build-forge-icon" --root "$root" --out "$built_icon_tmp" >/dev/null 2>&1; then
    icon_hash=$(hash_file_sha256 "$built_icon_tmp")
    icon_name="forge-${icon_hash}.icns"
    cp "$built_icon_tmp" "$resources_dir/$icon_name"
    icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
  elif [ -f "$root/apps/forge/assets/icons/meta/apple-master.png" ]; then
    icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/icons/meta/apple-master.png")
    icon_name="forge-icon-${icon_hash}.png"
    cp "$root/apps/forge/assets/icons/meta/apple-master.png" "$resources_dir/$icon_name"
    icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
  elif [ -f "$root/apps/forge/assets/forge-icon.png" ]; then
    icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/forge-icon.png")
    icon_name="forge-icon-${icon_hash}.png"
    cp "$root/apps/forge/assets/forge-icon.png" "$resources_dir/$icon_name"
    icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
  elif [ -f "$root/apps/forge/assets/icons/macos/forge.icns" ]; then
    icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/icons/macos/forge.icns")
    icon_name="forge-${icon_hash}.icns"
    cp "$root/apps/forge/assets/icons/macos/forge.icns" "$resources_dir/$icon_name"
    icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
  elif [ -f "$root/apps/forge/assets/icons/meta/territory-master.png" ]; then
    icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/icons/meta/territory-master.png")
    icon_name="forge-icon-${icon_hash}.png"
    cp "$root/apps/forge/assets/icons/meta/territory-master.png" "$resources_dir/$icon_name"
    icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
  fi
elif [ -f "$root/apps/forge/assets/icons/meta/apple-master.png" ]; then
  icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/icons/meta/apple-master.png")
  icon_name="forge-icon-${icon_hash}.png"
  cp "$root/apps/forge/assets/icons/meta/apple-master.png" "$resources_dir/$icon_name"
  icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
elif [ -f "$root/apps/forge/assets/forge-icon.png" ]; then
  icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/forge-icon.png")
  icon_name="forge-icon-${icon_hash}.png"
  cp "$root/apps/forge/assets/forge-icon.png" "$resources_dir/$icon_name"
  icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
elif [ -f "$root/apps/forge/assets/icons/macos/forge.icns" ]; then
  icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/icons/macos/forge.icns")
  icon_name="forge-${icon_hash}.icns"
  cp "$root/apps/forge/assets/icons/macos/forge.icns" "$resources_dir/$icon_name"
  icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
elif [ -f "$root/apps/forge/assets/icons/meta/territory-master.png" ]; then
  icon_hash=$(hash_file_sha256 "$root/apps/forge/assets/icons/meta/territory-master.png")
  icon_name="forge-icon-${icon_hash}.png"
  cp "$root/apps/forge/assets/icons/meta/territory-master.png" "$resources_dir/$icon_name"
  icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
fi

bundle_version=$(printf '%s' "$expected_hash" | cksum | awk '{ print $1 }')
[ -n "$bundle_version" ] || bundle_version=1

cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>App Forge</string>
<key>CFBundleDisplayName</key><string>App Forge</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>$bundle_version</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>app-forge</string>
$icon_key
</dict></plist>
PLIST

out_parent=$(dirname "$out_bundle")
out_base=$(basename "$out_bundle")
mkdir -p "$out_parent"
final_stage_root=$(mktemp -d "$out_parent/.${out_base}.build.XXXXXX")
final_bundle="$final_stage_root/$out_base"
backup_bundle="$final_stage_root/previous-$out_base"

cp -R "$stage_bundle" "$final_bundle" || {
  printf '%s\n' "build-forge-macos-app: failed to copy macOS app bundle: $out_bundle" >&2
  exit 1
}
ensure_macos_bundle_signature "$final_bundle" || {
  printf '%s\n' "build-forge-macos-app: failed to sign macOS app bundle: $out_bundle" >&2
  exit 1
}

if [ -e "$out_bundle" ] || [ -L "$out_bundle" ]; then
  mv "$out_bundle" "$backup_bundle" || {
    printf '%s\n' "build-forge-macos-app: failed to replace macOS app bundle: $out_bundle" >&2
    exit 1
  }
fi

if ! mv "$final_bundle" "$out_bundle"; then
  if [ -e "$backup_bundle" ] || [ -L "$backup_bundle" ]; then
    mv "$backup_bundle" "$out_bundle" >/dev/null 2>&1 || :
  fi
  printf '%s\n' "build-forge-macos-app: failed to replace macOS app bundle: $out_bundle" >&2
  exit 1
fi
rm -rf "$backup_bundle"

printf '%s\n' "app_bundle=$out_bundle"
printf '%s\n' "host_binary=$host_bin"
printf '%s\n' "cache=miss"
