#!/bin/sh

# Install launchers for App Forge.

set -eu
export COPYFILE_DISABLE=1

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DEFAULT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)

root=$DEFAULT_ROOT
home_dir=$HOME
scope=auto
app_dir=''
home_explicit=0

print_usage() {
  cat <<'USAGE'
Usage: install-forge [--root ROOT_DIR] [--home HOME_DIR] [--system|--user] [--app-dir APP_PATH]

Installs launchers for App Forge.

Defaults:
  - macOS: installs app bundle to ~/Applications (first-class desktop app)
  - Linux: installs desktop entry to ~/.local/share/applications
  - all platforms: installs command shim at ~/.local/bin/app-forge

Options:
  --system   Prefer system-wide app location on macOS (/Applications)
  --user     Force user app location on macOS (~/Applications)
  --app-dir  Explicit app bundle path on macOS (overrides --system/--user)

If the repository is moved, rerun this installer.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|--usage|-h)
      print_usage
      exit 0
      ;;
    --root)
      root=${2-}
      [ -n "$root" ] || {
        printf '%s\n' "install-forge: --root requires ROOT_DIR" >&2
        exit 2
      }
      shift 2
      ;;
    --home)
      home_dir=${2-}
      [ -n "$home_dir" ] || {
        printf '%s\n' "install-forge: --home requires HOME_DIR" >&2
        exit 2
      }
      home_explicit=1
      shift 2
      ;;
    --system)
      scope=system
      shift
      ;;
    --user)
      scope=user
      shift
      ;;
    --app-dir)
      app_dir=${2-}
      [ -n "$app_dir" ] || {
        printf '%s\n' "install-forge: --app-dir requires APP_PATH" >&2
        exit 2
      }
      shift 2
      ;;
    *)
      printf '%s\n' "install-forge: unknown argument: $1" >&2
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

shell_generated_path_is_safe() {
  case "${1-}" in ""|-*|*'"'*|*'$'*|*'`'*|*'\'*) return 1 ;; esac
  has_line_break "$1" && return 1
  return 0
}

desktop_generated_path_is_safe() {
  shell_generated_path_is_safe "${1-}" || return 1
  case "${1-}" in *'%'*) return 1 ;; esac
  return 0
}

hash_file_sha256() {
  hash_target=${1-}
  [ -f "$hash_target" ] || return 1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$hash_target" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$hash_target" | awk '{ print $1 }'
  else
    cksum "$hash_target" | awk '{ print $1 "-" $2 }'
  fi
}

normalize_desktop_apps_install_dir() {
  dir_path=${1-}
  [ -n "$dir_path" ] || return 1
  has_line_break "$dir_path" && return 1
  case "$dir_path" in
    /*)
      printf '%s\n' "$(printf '%s' "$dir_path" | sed 's#/*$##')"
      return 0
      ;;
  esac
  return 1
}

forge_ui_prefs_file() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$home_dir/.config}/wizardry-apps/forge-ui.conf"
}

forge_ui_pref_value() {
  pref_key=${1-}
  prefs_file=$(forge_ui_prefs_file)
  [ -n "$pref_key" ] || return 1
  [ -f "$prefs_file" ] || return 0
  while IFS= read -r pref_line || [ -n "$pref_line" ]; do
    case "$pref_line" in
      "$pref_key"=*)
        printf '%s\n' "${pref_line#*=}"
        return 0
        ;;
    esac
  done < "$prefs_file"
  return 0
}

preferred_macos_apps_install_dir() {
  pref_value=$(forge_ui_pref_value desktop_apps_install_dir 2>/dev/null || true)
  if [ -z "$pref_value" ]; then
    pref_value=$(forge_ui_pref_value macos_apps_install_dir 2>/dev/null || true)
  fi
  if normalized_pref=$(normalize_desktop_apps_install_dir "$pref_value" 2>/dev/null); then
    printf '%s\n' "$normalized_pref"
    return 0
  fi

  printf '%s/Applications\n' "$home_dir"
}

app_bundle_path_is_safe() {
  path_value=${1-}
  has_line_break "$path_value" && return 1
  case "$path_value" in
    *.app) ;;
    *) return 1 ;;
  esac
  case "$path_value" in
    -*|.|..|./*|../*|*/./*|*/../*|*/.|*/..)
      return 1
      ;;
  esac
  return 0
}

shell_generated_path_is_safe "$root" || {
  printf '%s\n' "install-forge: unsafe root path" >&2
  exit 2
}

shell_generated_path_is_safe "$home_dir" || {
  printf '%s\n' "install-forge: unsafe home path" >&2
  exit 2
}

if [ -n "$app_dir" ]; then
  app_bundle_path_is_safe "$app_dir" || {
    printf '%s\n' "install-forge: app path must be a safe .app bundle path" >&2
    exit 2
  }
fi

if [ ! -f "$root/tools/forge/launch-forge.sh" ] || [ ! -d "$root/apps/forge" ]; then
  printf '%s\n' "install-forge: invalid wizardry-apps root: $root" >&2
  exit 1
fi

[ -f "$root/tools/forge/build-forge-macos-app.sh" ] || {
  printf '%s\n' "install-forge: missing build-forge-macos-app" >&2
  exit 1
}

os=$(uname -s 2>/dev/null || printf unknown)
case "$os" in
  Linux)
    desktop_generated_path_is_safe "$home_dir" || {
      printf '%s\n' "install-forge: unsafe home path" >&2
      exit 2
    }
    ;;
esac

mkdir -p "$home_dir/.local/bin"
shim="$home_dir/.local/bin/app-forge"
config_root="$home_dir/.config/wizardry-apps"
config_file="$config_root/forge-root"

cat > "$shim" <<SHIM
#!/bin/sh
set -eu
exec sh "$root/tools/forge/launch-forge.sh" --root "$root" "\$@"
SHIM
chmod +x "$shim"

mkdir -p "$config_root"
printf '%s\n' "$root" > "$config_file"

scrub_macos_bundle_launch_metadata() {
  scrub_macos_bundle_launch_metadata_bundle=${1-}
  [ -d "$scrub_macos_bundle_launch_metadata_bundle" ] || return 1
  command -v xattr >/dev/null 2>&1 || return 0
  for scrub_macos_bundle_launch_metadata_attr in \
    com.apple.quarantine \
    com.apple.provenance \
    com.apple.macl \
    com.apple.FinderInfo \
    com.apple.ResourceFork
  do
    xattr -r -d "$scrub_macos_bundle_launch_metadata_attr" "$scrub_macos_bundle_launch_metadata_bundle" >/dev/null 2>&1 || true
  done
}

macos_bundle_signature_is_usable() {
  bundle_path=${1-}
  [ -d "$bundle_path" ] || return 1
  command -v codesign >/dev/null 2>&1 || return 0
  codesign --verify --deep --strict "$bundle_path" >/dev/null 2>&1
}

macos_codesign_identity() {
  if [ -n "${WIZARDRY_CODESIGN_IDENTITY-}" ]; then
    printf '%s\n' "$WIZARDRY_CODESIGN_IDENTITY"
    return 0
  fi
  printf '%s\n' "-"
}

ensure_macos_bundle_signature() {
  bundle_path=${1-}
  [ -d "$bundle_path" ] || return 1
  command -v codesign >/dev/null 2>&1 || return 0
  scrub_macos_bundle_launch_metadata "$bundle_path"
  signing_identity=$(macos_codesign_identity)
  [ -n "$signing_identity" ] || signing_identity=-
  codesign --force --deep --sign "$signing_identity" "$bundle_path" >/dev/null 2>&1 || return 1
  macos_bundle_signature_is_usable "$bundle_path"
}

macos_bundle_launch_policy_usable() {
  bundle_path=${1-}
  [ -d "$bundle_path" ] || return 1
  # Let the normal open/launch path perform macOS assessment once. Explicit
  # spctl probes add avoidable syspolicyd work during install and relaunch.
  return 0
}

copy_macos_bundle_contents() {
  src_bundle=${1-}
  dest_bundle=${2-}
  [ -d "$src_bundle" ] || return 1
  [ -n "$dest_bundle" ] || return 1
  if command -v ditto >/dev/null 2>&1; then
    ditto --norsrc --noextattr --noqtn --noacl "$src_bundle" "$dest_bundle" || return 1
  else
    export COPYFILE_DISABLE=1
    cp -R "$src_bundle" "$dest_bundle" || return 1
  fi
}

macos_plist_value() {
  bundle_path=${1-}
  key=${2-}
  [ -n "$bundle_path" ] || return 1
  [ -n "$key" ] || return 1
  plist_path="$bundle_path/Contents/Info.plist"
  [ -f "$plist_path" ] || return 1

  if command -v plutil >/dev/null 2>&1; then
    plist_value=$(plutil -extract "$key" raw -o - "$plist_path" 2>/dev/null || true)
    if [ -n "$plist_value" ]; then
      printf '%s\n' "$plist_value"
      return 0
    fi
  fi

  tr '\n' ' ' <"$plist_path" |
    sed -n "s/.*<key>$key<\\/key>[[:space:]]*<string>\\([^<]*\\)<\\/string>.*/\\1/p" |
    head -n 1
}

macos_bundle_build_marker() {
  bundle_path=${1-}
  [ -d "$bundle_path" ] || return 1
  marker_path="$bundle_path/Contents/Resources/wizardry-build-input.sha256"
  [ -f "$marker_path" ] || return 1
  hash_file_sha256 "$marker_path" 2>/dev/null
}

macos_bundle_same_install_identity() {
  src_bundle=${1-}
  dest_bundle=${2-}
  [ -d "$src_bundle" ] || return 1
  [ -d "$dest_bundle" ] || return 1

  src_id=$(macos_plist_value "$src_bundle" CFBundleIdentifier 2>/dev/null || true)
  dest_id=$(macos_plist_value "$dest_bundle" CFBundleIdentifier 2>/dev/null || true)
  [ -n "$src_id" ] && [ "$src_id" = "$dest_id" ] || return 1

  src_version=$(macos_plist_value "$src_bundle" CFBundleVersion 2>/dev/null || true)
  dest_version=$(macos_plist_value "$dest_bundle" CFBundleVersion 2>/dev/null || true)
  [ -n "$src_version" ] && [ "$src_version" = "$dest_version" ] || return 1

  src_marker=$(macos_bundle_build_marker "$src_bundle" 2>/dev/null || true)
  dest_marker=$(macos_bundle_build_marker "$dest_bundle" 2>/dev/null || true)
  [ -z "$src_marker" ] || [ "$src_marker" = "$dest_marker" ] || return 1

  ensure_macos_bundle_signature "$dest_bundle" >/dev/null 2>&1
}

install_macos_bundle() {
  target=$1
  stage_root=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-app.XXXXXX")
  stage_bundle="$stage_root/App Forge.app"
  target_parent=$(dirname "$target")
  target_base=${target##*/}
  target_stage="$target_parent/.$target_base.install.$$"

  if ! sh "$root/tools/forge/build-forge-macos-app.sh" --root "$root" --out "$stage_bundle" >/dev/null 2>&1; then
    rm -rf "$stage_root"
    return 1
  fi
  scrub_macos_bundle_launch_metadata "$stage_bundle" || {
    rm -rf "$stage_root"
    return 1
  }
  ensure_macos_bundle_signature "$stage_bundle" || {
    rm -rf "$stage_root"
    return 1
  }
  macos_bundle_launch_policy_usable "$stage_bundle" || {
    rm -rf "$stage_root"
    return 1
  }

  if macos_bundle_same_install_identity "$stage_bundle" "$target"; then
    scrub_macos_bundle_launch_metadata "$target" >/dev/null 2>&1 || true
    rm -rf "$stage_root"
    printf '%s\n' "$target"
    return 0
  fi

  if [ -w "$target_parent" ] || [ ! -e "$target_parent" ]; then
    mkdir -p "$target_parent"
    rm -rf "$target_stage"
    copy_macos_bundle_contents "$stage_bundle" "$target_stage" || {
      rm -rf "$target_stage"
      rm -rf "$stage_root"
      return 1
    }
    backup_target="$target.previous"
    rm -rf "$backup_target"
    if [ -e "$target" ]; then
      mv "$target" "$backup_target" || {
        rm -rf "$target_stage"
        rm -rf "$stage_root"
        return 1
      }
    fi
    mv "$target_stage" "$target" || {
      [ ! -e "$backup_target" ] || mv "$backup_target" "$target" >/dev/null 2>&1 || true
      rm -rf "$target_stage"
      rm -rf "$stage_root"
      return 1
    }
    if ! ensure_macos_bundle_signature "$target" || ! macos_bundle_launch_policy_usable "$target"; then
      rm -rf "$target" >/dev/null 2>&1 || true
      [ ! -e "$backup_target" ] || mv "$backup_target" "$target" >/dev/null 2>&1 || true
      rm -rf "$stage_root"
      return 1
    fi
    rm -rf "$backup_target"
    rm -rf "$stage_root"
    printf '%s\n' "$target"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    set +e
    if command -v ditto >/dev/null 2>&1; then
      sudo mkdir -p "$target_parent" && sudo rm -rf "$target_stage" && sudo ditto --norsrc --noextattr --noqtn --noacl "$stage_bundle" "$target_stage"
    else
      sudo mkdir -p "$target_parent" && sudo rm -rf "$target_stage" && sudo COPYFILE_DISABLE=1 cp -R "$stage_bundle" "$target_stage"
    fi
    sudo_rc=$?
    set -e
    if [ "$sudo_rc" -eq 0 ]; then
      backup_target="$target.previous"
      if ! sudo rm -rf "$backup_target" >/dev/null 2>&1; then
        sudo rm -rf "$target_stage" >/dev/null 2>&1 || true
        rm -rf "$stage_root"
        return 1
      fi
      if sudo test -e "$target"; then
        if ! sudo mv "$target" "$backup_target"; then
          sudo rm -rf "$target_stage" >/dev/null 2>&1 || true
          rm -rf "$stage_root"
          return 1
        fi
      fi
      if ! sudo mv "$target_stage" "$target"; then
        sudo test ! -e "$backup_target" || sudo mv "$backup_target" "$target" >/dev/null 2>&1 || true
        sudo rm -rf "$target_stage" >/dev/null 2>&1 || true
        rm -rf "$stage_root"
        return 1
      fi
      if ! ensure_macos_bundle_signature "$target" || ! macos_bundle_launch_policy_usable "$target"; then
        sudo rm -rf "$target" >/dev/null 2>&1 || true
        sudo test ! -e "$backup_target" || sudo mv "$backup_target" "$target" >/dev/null 2>&1 || true
        rm -rf "$stage_root"
        return 1
      fi
      sudo rm -rf "$backup_target" >/dev/null 2>&1 || true
      rm -rf "$stage_root"
      printf '%s\n' "$target"
      return 0
    fi
    sudo rm -rf "$target_stage" >/dev/null 2>&1 || true
  fi

  rm -rf "$stage_root"
  return 1
}

cleanup_alternate_macos_bundle() {
  target_bundle=${1-}
  home_root=${2-}
  [ -n "$target_bundle" ] || return 1
  [ -n "$home_root" ] || return 1

  system_bundle="/Applications/App Forge.app"
  user_bundle="$home_root/Applications/App Forge.app"
  for alternate_bundle in "$system_bundle" "$user_bundle"; do
    [ "$alternate_bundle" = "$target_bundle" ] && continue
    [ -e "$alternate_bundle" ] || continue
    rm -rf "$alternate_bundle" >/dev/null 2>&1 || true
  done
}

case "$os" in
  Darwin)
    target_app=''
    fallback_used=0

    if [ -n "$app_dir" ]; then
      target_app=$app_dir
    else
      case "$scope" in
        system)
          target_app="/Applications/App Forge.app"
          ;;
        user)
          target_app="$home_dir/Applications/App Forge.app"
          ;;
        auto)
          target_app="$(preferred_macos_apps_install_dir)/App Forge.app"
          ;;
      esac
    fi

    if ! installed_app=$(install_macos_bundle "$target_app"); then
      fallback_target="$home_dir/Applications/App Forge.app"
      installed_app=$(install_macos_bundle "$fallback_target") || {
        printf '%s\n' "install-forge: failed to install macOS app bundle" >&2
        exit 1
      }
      fallback_used=1
    fi

    printf '%s\n' "installed_command=$shim"
    printf '%s\n' "workspace_root_file=$config_file"
    printf '%s\n' "installed_app=$installed_app"
    cleanup_alternate_macos_bundle "$installed_app" "$home_dir"
    if [ "$fallback_used" -eq 1 ]; then
      printf '%s\n' "note=insufficient permissions for /Applications, installed to $installed_app" >&2
    fi
    ;;

  Linux)
    apps_dir="$home_dir/.local/share/applications"
    desktop_file="$apps_dir/app-forge.desktop"

    mkdir -p "$apps_dir"

    cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=App Forge
Comment=Desktop control plane for wizardry-apps
Exec=/bin/sh "$shim"
Terminal=false
Categories=Development;Utility;
StartupNotify=true
DESKTOP

    printf '%s\n' "installed_command=$shim"
    printf '%s\n' "workspace_root_file=$config_file"
    printf '%s\n' "installed_desktop=$desktop_file"
    ;;

  *)
    printf '%s\n' "installed_command=$shim"
    printf '%s\n' "workspace_root_file=$config_file"
    printf '%s\n' "install-forge: unsupported OS '$os' for desktop integration; command shim installed only" >&2
    ;;
esac

printf '%s\n' "note=if repo root moves, rerun install-forge"
