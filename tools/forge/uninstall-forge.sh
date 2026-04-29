#!/bin/sh

# Remove launchers for App Forge.

set -eu

home_dir=$HOME
scope=auto
app_dir=''

print_usage() {
  cat <<'USAGE'
Usage: uninstall-forge [--home HOME_DIR] [--system|--user] [--app-dir APP_PATH]

Removes launchers created by install-forge.

Defaults on macOS:
  - Removes /Applications/App Forge.app when possible
  - Also removes ~/Applications/App Forge.app
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|--usage|-h)
      print_usage
      exit 0
      ;;
    --home)
      home_dir=${2-}
      [ -n "$home_dir" ] || {
        printf '%s\n' "uninstall-forge: --home requires HOME_DIR" >&2
        exit 2
      }
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
        printf '%s\n' "uninstall-forge: --app-dir requires APP_PATH" >&2
        exit 2
      }
      shift 2
      ;;
    *)
      printf '%s\n' "uninstall-forge: unknown argument: $1" >&2
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

if has_line_break "$home_dir"; then
  printf '%s\n' "uninstall-forge: unsafe home path" >&2
  exit 2
fi

case "$home_dir" in
  ""|-*)
    printf '%s\n' "uninstall-forge: unsafe home path" >&2
    exit 2
    ;;
esac

if [ -n "$app_dir" ]; then
  app_bundle_path_is_safe "$app_dir" || {
    printf '%s\n' "uninstall-forge: app path must be a safe .app bundle path" >&2
    exit 2
  }
fi

rm -f "$home_dir/.local/bin/app-forge"
rm -f "$home_dir/.local/share/applications/app-forge.desktop"
rm -f "$home_dir/.config/wizardry-apps/forge-root"

remove_path() {
  target=$1
  [ -n "$target" ] || return 0
  [ -e "$target" ] || return 0

  if rm -rf "$target" >/dev/null 2>&1; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo rm -rf "$target" >/dev/null 2>&1 || true
  fi
}

os=$(uname -s 2>/dev/null || printf unknown)
if [ "$os" = "Darwin" ]; then
  if [ -n "$app_dir" ]; then
    remove_path "$app_dir"
  else
    case "$scope" in
      system)
        remove_path "/Applications/App Forge.app"
        ;;
      user)
        remove_path "$home_dir/Applications/App Forge.app"
        ;;
      auto)
        remove_path "/Applications/App Forge.app"
        remove_path "$home_dir/Applications/App Forge.app"
        ;;
    esac
  fi
else
  remove_path "$home_dir/Applications/App Forge.app"
fi

printf '%s\n' "removed_user_launcher_paths_from=$home_dir"
