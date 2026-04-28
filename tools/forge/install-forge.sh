#!/bin/sh

# Install launchers for App Forge.

set -eu

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
  - macOS: installs app bundle to /Applications (first-class desktop app)
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
  case "${1-}" in *'"'*|*'$'*|*'`'*|*'\'*) return 1 ;; esac
  has_line_break "$1" && return 1
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

if [ -n "$app_dir" ] && has_line_break "$app_dir"; then
  printf '%s\n' "install-forge: unsafe app path" >&2
  exit 2
fi
if [ -n "$app_dir" ]; then
  case "$app_dir" in
    *.app) ;;
    *)
      printf '%s\n' "install-forge: app path must be a .app bundle" >&2
      exit 2
      ;;
  esac
fi

if [ ! -x "$root/tools/forge/launch-forge" ] || [ ! -d "$root/apps/forge" ]; then
  printf '%s\n' "install-forge: invalid wizardry-apps root: $root" >&2
  exit 1
fi

[ -x "$root/tools/forge/build-forge-macos-app" ] || {
  printf '%s\n' "install-forge: missing build-forge-macos-app" >&2
  exit 1
}

mkdir -p "$home_dir/.local/bin"
shim="$home_dir/.local/bin/app-forge"
config_root="$home_dir/.config/wizardry-apps"
config_file="$config_root/forge-root"

cat > "$shim" <<SHIM
#!/bin/sh
set -eu
exec "$root/tools/forge/launch-forge" --root "$root" "\$@"
SHIM
chmod +x "$shim"

mkdir -p "$config_root"
printf '%s\n' "$root" > "$config_file"

os=$(uname -s 2>/dev/null || printf unknown)

install_macos_bundle() {
  target=$1
  stage_root=$(mktemp -d "${TMPDIR:-/tmp}/app-forge-app.XXXXXX")
  stage_bundle="$stage_root/App Forge.app"
  if ! "$root/tools/forge/build-forge-macos-app" --root "$root" --out "$stage_bundle" >/dev/null 2>&1; then
    rm -rf "$stage_root"
    return 1
  fi

  parent_dir=$(dirname "$target")

  if [ -w "$parent_dir" ] || [ ! -e "$parent_dir" ]; then
    mkdir -p "$parent_dir"
    rm -rf "$target"
    cp -R "$stage_bundle" "$target"
    rm -rf "$stage_root"
    printf '%s\n' "$target"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    set +e
    sudo mkdir -p "$parent_dir" && \
      sudo rm -rf "$target" && \
      sudo cp -R "$stage_bundle" "$target"
    sudo_rc=$?
    set -e
    if [ "$sudo_rc" -eq 0 ]; then
      rm -rf "$stage_root"
      printf '%s\n' "$target"
      return 0
    fi
  fi

  rm -rf "$stage_root"
  return 1
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
          if [ "$home_explicit" -eq 1 ]; then
            target_app="$home_dir/Applications/App Forge.app"
          else
            target_app="/Applications/App Forge.app"
          fi
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
