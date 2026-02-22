#!/bin/sh

# App Forge backend: shell-first control plane for wizardry-apps.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: forge-backend.sh COMMAND [ARGS...]

Commands:
  doctor [ROOT_HINT]
  list-apps [ROOT_HINT]
  list-templates [ROOT_HINT]
  list-themes [ROOT_HINT]
  list-godot-tools [ROOT_HINT]
  list-workspaces [ROOT_HINT] [PROJECT_ROOT]
  get-ui-prefs [ROOT_HINT]
  set-ui-pref [ROOT_HINT] KEY VALUE
  set-app-targets [ROOT_HINT] APP_SLUG TARGETS
  set-workspace-targets [ROOT_HINT] WORKSPACE_PATH TARGETS
  set-app-icon [ROOT_HINT] APP_SLUG DATA_URL
  set-workspace-icon [ROOT_HINT] WORKSPACE_PATH DATA_URL
  build-desktop [ROOT_HINT] APP_SLUG
  install-desktop [ROOT_HINT] APP_SLUG [TARGET_ID] [LINUX_INSTALL_MODE]
  run-desktop [ROOT_HINT] APP_SLUG [RUN_MODE]
  run-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT]
  serve-hosted-web [ROOT_HINT] MODE REF
  stage-mobile [ROOT_HINT] APP_SLUG
  build-ios-smoke [ROOT_HINT] APP_SLUG
  build-android-debug [ROOT_HINT] APP_SLUG
  scaffold-app [ROOT_HINT] APP_SLUG APP_NAME TEMPLATE [SOURCE_APP]   # legacy
  scaffold-workspace [ROOT_HINT] APP_SLUG APP_NAME CONTEXT STARTER TARGETS [SOURCE] [PROJECT_ROOT]
  scaffold-site [ROOT_HINT] SITE_NAME TEMPLATE [DEST_ROOT]
  run-task [ROOT_HINT] TASK

TASK values:
  validate-manifest | test-core | test-adapters | test-release-tools

TEMPLATE values for scaffold-app:
  minimal | panel | clone

CONTEXT values for scaffold-workspace:
  web | godot | application | game
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

is_workspace_root() {
  root=${1-}
  [ -n "$root" ] || return 1
  [ -f "$root/config/apps.manifest.json" ] || return 1
  [ -f "$root/config/templates.manifest.json" ] || return 1
  [ -d "$root/.apps" ] || return 1
  [ -d "$root/.web" ] || return 1
}

find_root_from() {
  start=${1-}
  [ -n "$start" ] || return 1
  dir=$start
  while :; do
    if is_workspace_root "$dir"; then
      printf '%s\n' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done
  return 1
}

root_from_file() {
  file=${1-}
  [ -n "$file" ] || return 1
  [ -f "$file" ] || return 1

  root=$(head -n 1 "$file" 2>/dev/null | tr -d '\r')
  [ -n "$root" ] || return 1

  if is_workspace_root "$root"; then
    printf '%s\n' "$root"
    return 0
  fi

  return 1
}

resolve_root() {
  hint=${1-}
  user_root_file="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/forge-root"

  if [ -n "$hint" ] && is_workspace_root "$hint"; then
    printf '%s\n' "$hint"
    return 0
  fi

  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && is_workspace_root "$WIZARDRY_APPS_ROOT"; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT"
    return 0
  fi

  if root=$(root_from_file "$SCRIPT_DIR/../../wizardry-apps-root.txt" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if root=$(root_from_file "$SCRIPT_DIR/../wizardry-apps-root.txt" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if root=$(root_from_file "$user_root_file" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if root=$(find_root_from "$SCRIPT_DIR" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if pwd_now=$(pwd -P 2>/dev/null); then
    if root=$(find_root_from "$pwd_now" 2>/dev/null); then
      printf '%s\n' "$root"
      return 0
    fi
  fi

  return 1
}

require_root() {
  hint=${1-}
  if root=$(resolve_root "$hint" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  printf '%s\n' "forge-backend: unable to resolve wizardry-apps root (set WIZARDRY_APPS_ROOT or provide ROOT_HINT)" >&2
  exit 1
}

require_tool() {
  tool=$1
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s\n' "forge-backend: required tool not found: $tool" >&2
    exit 1
  fi
}

os_id() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' "darwin" ;;
    Linux) printf '%s\n' "linux" ;;
    *) printf '%s\n' "unknown" ;;
  esac
}

resolve_godot_engine() {
  if [ -n "${GODOT_BIN-}" ] && [ -x "$GODOT_BIN" ]; then
    printf '%s\n' "$GODOT_BIN"
    return 0
  fi
  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return 0
  fi
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi
  if [ "$(os_id)" = "darwin" ] && command -v open >/dev/null 2>&1; then
    printf '%s\n' "__GODOT_APP__"
    return 0
  fi
  return 1
}

ensure_godot_project() {
  workspace_path=$1
  project_title=${2-}

  if [ -f "$workspace_path/project.godot" ]; then
    printf '%s\n' "$workspace_path"
    return 0
  fi
  if [ -f "$workspace_path/game/project.godot" ]; then
    printf '%s\n' "$workspace_path/game"
    return 0
  fi

  [ -f "$workspace_path/tool_main.gd" ] || return 1

  [ -w "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace is not writable for Godot bootstrap: $workspace_path" >&2
    return 1
  }

  [ -n "$project_title" ] || project_title=$(basename "$workspace_path")

  cat > "$workspace_path/Main.tscn" <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tool_main.gd" id="1_tool"]

[node name="Main" type="Node"]
script = ExtResource("1_tool")
TSCN

  cat > "$workspace_path/project.godot" <<PROJECT
; Engine configuration file.
config_version=5

[application]
config/name="$project_title"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("4.2")
PROJECT

  printf '%s\n' "$workspace_path"
  return 0
}

validate_slug() {
  candidate=${1-}
  case "$candidate" in
    [a-z][a-z0-9-]*) ;;
    *)
      printf '%s\n' "forge-backend: invalid slug '$candidate' (expected [a-z][a-z0-9-]*)" >&2
      exit 2
      ;;
  esac

  case "$candidate" in
    *-|*--*)
      printf '%s\n' "forge-backend: invalid slug '$candidate' (no trailing or consecutive hyphens)" >&2
      exit 2
      ;;
  esac
}

validate_site_name() {
  site=${1-}
  case "$site" in
    [A-Za-z0-9][A-Za-z0-9._-]*) ;;
    *)
      printf '%s\n' "forge-backend: invalid site name '$site'" >&2
      exit 2
      ;;
  esac
}

app_exists() {
  root=$1
  slug=$2
  [ -d "$root/.apps/$slug" ]
}

require_jq() {
  require_tool jq
}

app_name_from_manifest() {
  root=$1
  slug=$2
  sh "$root/tools/release/get-app-name.sh" "$slug"
}

bundle_id_from_manifest() {
  root=$1
  platform=$2
  slug=$3
  sh "$root/tools/release/get-app-bundle-id.sh" "$platform" "$slug"
}

ensure_macos_host() {
  root=$1
  require_tool clang

  host_bin="$root/_tmp/workbench/bin/wizardry-host-macos"
  host_src="$root/.apps/.host/macos/main.m"
  module_cache="$root/_tmp/workbench/clang-module-cache"

  mkdir -p "$(dirname "$host_bin")"
  needs_rebuild=0
  if [ ! -x "$host_bin" ] || [ "$host_src" -nt "$host_bin" ]; then
    needs_rebuild=1
  elif command -v lipo >/dev/null 2>&1; then
    archs=$(lipo -archs "$host_bin" 2>/dev/null || true)
    if ! printf '%s\n' "$archs" | grep -qw 'arm64'; then
      needs_rebuild=1
    fi
    if ! printf '%s\n' "$archs" | grep -qw 'x86_64'; then
      needs_rebuild=1
    fi
  fi

  if [ "$needs_rebuild" -eq 1 ]; then
    mkdir -p "$module_cache"
    CLANG_MODULE_CACHE_PATH="$module_cache" \
      clang -O2 -fobjc-arc -fmodules -arch arm64 -arch x86_64 "$host_src" -o "$host_bin" -framework Cocoa -framework WebKit
    if command -v lipo >/dev/null 2>&1; then
      archs=$(lipo -archs "$host_bin" 2>/dev/null || true)
      if ! printf '%s\n' "$archs" | grep -qw 'arm64' || ! printf '%s\n' "$archs" | grep -qw 'x86_64'; then
        printf '%s\n' "forge-backend: failed to produce universal macOS host binary (got: ${archs:-unknown})" >&2
        exit 1
      fi
    fi
  fi
  printf '%s\n' "$host_bin"
}

ensure_linux_host() {
  root=$1
  require_tool cc
  require_tool pkg-config

  host_bin="$root/_tmp/workbench/bin/wizardry-host-linux"
  host_src="$root/.apps/.host/linux/main.c"

  mkdir -p "$(dirname "$host_bin")"
  cc -O2 "$host_src" -o "$host_bin" $(pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.1)
  printf '%s\n' "$host_bin"
}

workspace_field() {
  conf=$1
  key=$2
  fallback=${3-}
  if [ ! -f "$conf" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi
  value=$(awk -F= -v k="$key" '
    $1 ~ /^[[:space:]]*#/ { next }
    $1 ~ /^[[:space:]]*$/ { next }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
      if ($1 == k) {
        v=$0
        sub(/^[^=]*=/, "", v)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$conf")
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

config_field() {
  file=$1
  key=$2
  fallback=${3-}
  if [ ! -f "$file" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi
  value=$(awk -F= -v k="$key" '
    $1 ~ /^[[:space:]]*#/ { next }
    $1 ~ /^[[:space:]]*$/ { next }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
      if ($1 == k) {
        v=$0
        sub(/^[^=]*=/, "", v)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$file")
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

kv_read() {
  key=$1
  awk -F= -v k="$key" '
    $1 == k {
      sub(/^[^=]*=/, "", $0)
      print
      exit
    }
  '
}

normalize_linux_install_mode() {
  value=${1-}
  case "$value" in
    appimage-local-bin|appdir-local-share)
      printf '%s\n' "$value"
      ;;
    *)
      printf '%s\n' "appdir-local-share"
      ;;
  esac
}

sanitize_bundle_component() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//; s/--*/-/g')
  if [ -z "$cleaned" ]; then
    cleaned=workspace
  fi
  printf '%s\n' "$cleaned"
}

stop_host_instances_for_app() {
  host_bin=${1-}
  app_dir=${2-}

  [ -n "$app_dir" ] || return 0
  command -v ps >/dev/null 2>&1 || return 0

  # Prevent stale hidden windows/processes from making desktop runs appear as no-op.
  # Match by app_dir path + wizardry host command so we also catch launcher/bundle variants.
  pids=$(
    ps -axo pid=,command= 2>/dev/null \
      | awk -v app="$app_dir" -v host="$host_bin" '
          index($0, app) > 0 && (
            index($0, "wizardry-host") > 0 ||
            (length(host) > 0 && index($0, host) > 0)
          ) { print $1 }
        ' \
      | tr '\n' ' ' \
      | sed 's/[[:space:]]*$//'
  )
  [ -n "$pids" ] || return 0

  # shellcheck disable=SC2086
  kill $pids >/dev/null 2>&1 || true
  sleep 0.2
  still=$(
    ps -axo pid=,command= 2>/dev/null \
      | awk -v app="$app_dir" -v host="$host_bin" '
          index($0, app) > 0 && (
            index($0, "wizardry-host") > 0 ||
            (length(host) > 0 && index($0, host) > 0)
          ) { print $1 }
        ' \
      | tr '\n' ' ' \
      | sed 's/[[:space:]]*$//'
  )
  if [ -n "$still" ]; then
    # shellcheck disable=SC2086
    kill -9 $still >/dev/null 2>&1 || true
  fi
}

stop_desktop_instances_for_slug() {
  root=${1-}
  slug=${2-}
  app_name=${3-}
  os_name=${4-}

  [ -n "$slug" ] || return 0

  if [ "$os_name" = "darwin" ] && [ -n "$app_name" ] && command -v osascript >/dev/null 2>&1; then
    osascript -e "tell application \"$app_name\" to quit" >/dev/null 2>&1 || true
  fi

  if command -v pkill >/dev/null 2>&1; then
    pkill -f "wizardry-host.*[/.]apps/$slug" >/dev/null 2>&1 || true
    pkill -f "wizardry-host.*/Resources/$slug" >/dev/null 2>&1 || true
    if [ -n "$root" ]; then
      pkill -f "wizardry-host.*$root/_tmp/workbench/dist/.*/$slug" >/dev/null 2>&1 || true
    fi
  fi
}

cmd_doctor() {
  root_hint=${1-}
  root=''

  if resolved=$(resolve_root "$root_hint" 2>/dev/null); then
    root=$resolved
  fi

  printf 'root=%s\n' "$root"
  printf 'os=%s\n' "$(os_id)"
  printf 'home=%s\n' "$HOME"

  for t in jq clang cc gcc xcodebuild xcodegen pkg-config gradle java brew open xdg-open appimagetool; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '%s=%s\n' "$t" "1"
    else
      printf '%s=%s\n' "$t" "0"
    fi
  done

  for p in x-terminal-emulator gnome-terminal konsole; do
    key=$(printf '%s' "$p" | tr '-' '_')
    if command -v "$p" >/dev/null 2>&1; then
      printf '%s=%s\n' "$key" "1"
    else
      printf '%s=%s\n' "$key" "0"
    fi
  done

  if [ -n "$root" ] && command -v jq >/dev/null 2>&1; then
    printf 'apps_manifest=%s\n' "$root/config/apps.manifest.json"
    printf 'templates_manifest=%s\n' "$root/config/templates.manifest.json"
    printf 'apps_total=%s\n' "$(jq -r '.apps | length' "$root/config/apps.manifest.json")"
    printf 'apps_production=%s\n' "$(jq -r '[.apps[] | select(.production == true)] | length' "$root/config/apps.manifest.json")"
    printf 'templates_total=%s\n' "$(jq -r '.templates | length' "$root/config/templates.manifest.json")"
  fi
}

cmd_list_apps() {
  root=$(require_root "${1-}")
  require_jq

  manifest="$root/config/apps.manifest.json"
  jq -r '.apps[] | [.slug, .name, (if .production then "true" else "false" end), ((.bundleIds // {}) | keys | join(",")), (if has("targets") then (.targets // "") else "__FORGE_TARGETS_MISSING__" end)] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r slug name production bundle_targets manifest_targets; do
    exists=0
    app_exists "$root" "$slug" && exists=1
    development_context=web
    [ -d "$root/godot/tools/$slug" ] && development_context=godot

    if [ "$manifest_targets" != "__FORGE_TARGETS_MISSING__" ]; then
      targets=$manifest_targets
    else
      targets="macos,linux"
      case ",$bundle_targets," in
        *,ios,*)
          targets="$targets,ios"
          ;;
      esac
      case ",$bundle_targets," in
        *,android,*)
          targets="$targets,android"
          ;;
      esac
      if [ -d "$root/.web/$slug" ]; then
        targets="hosted-web,$targets"
      fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$slug" "$name" "$production" "$exists" "$development_context" "$targets"
  done
}

cmd_list_templates() {
  root=$(require_root "${1-}")
  require_jq

  manifest="$root/config/templates.manifest.json"
  jq -r '.templates[] | [.slug, (if .publish then "true" else "false" end)] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r slug publish; do
    exists=0
    [ -d "$root/.web/$slug" ] && exists=1
    printf '%s\t%s\t%s\n' "$slug" "$publish" "$exists"
  done
}

theme_names_from_dir() {
  dir=${1-}
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.css' 2>/dev/null \
    | awk -F/ '{ print $NF }' \
    | sed 's/\.css$//' \
    | awk '/^[a-z0-9_-]+$/' \
    | sort -u
}

cmd_list_themes() {
  root=$(require_root "${1-}")
  theme_root="$root/.web/.themes"
  app_theme_dir="$root/.apps/forge/themes"

  if [ -d "$theme_root" ]; then
    mkdir -p "$app_theme_dir"
    cp -f "$theme_root"/*.css "$app_theme_dir/" 2>/dev/null || true
  fi

  themes=$(theme_names_from_dir "$theme_root" || true)
  if [ -z "$themes" ]; then
    themes=$(theme_names_from_dir "$app_theme_dir" || true)
  fi

  if [ -n "$themes" ]; then
    printf '%s\n' "$themes"
  fi
}

cmd_list_godot_tools() {
  root=$(require_root "${1-}")
  tools_dir="$root/godot/tools"
  [ -d "$tools_dir" ] || return 0

  for path in "$tools_dir"/*; do
    [ -d "$path" ] || continue
    tool=$(basename "$path")
    case "$tool" in
      .* ) continue ;;
    esac
    printf '%s\n' "$tool"
  done | sort
}

workspace_default_root() {
  if [ -n "${APP_FORGE_PROJECTS_ROOT-}" ]; then
    printf '%s\n' "$APP_FORGE_PROJECTS_ROOT"
    return 0
  fi
  printf '%s\n' "$HOME/git"
}

forge_ui_prefs_file() {
  base="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps"
  mkdir -p "$base"
  printf '%s\n' "$base/forge-ui.conf"
}

validate_ui_pref_key() {
  key=${1-}
  case "$key" in
    [a-z0-9][a-z0-9._-]*)
      ;;
    *)
      printf '%s\n' "forge-backend: invalid UI pref key: $key" >&2
      exit 2
      ;;
  esac
}

sanitize_ui_pref_value() {
  value=${1-}
  printf '%s' "$value" | tr '\r\n' ' '
}

cmd_get_ui_prefs() {
  prefs_file=$(forge_ui_prefs_file)
  [ -f "$prefs_file" ] || exit 0
  cat "$prefs_file"
}

cmd_set_ui_pref() {
  key=${2-}
  value=${3-}
  [ -n "$key" ] || {
    printf '%s\n' "forge-backend: set-ui-pref requires KEY" >&2
    exit 2
  }
  validate_ui_pref_key "$key"
  prefs_file=$(forge_ui_prefs_file)
  [ -f "$prefs_file" ] || : > "$prefs_file"
  value=$(sanitize_ui_pref_value "$value")
  write_key_value_file "$prefs_file" "$key" "$value"
  printf 'key=%s\n' "$key"
  printf 'value=%s\n' "$value"
  printf 'file=%s\n' "$prefs_file"
}

cmd_list_workspaces() {
  root=$(require_root "${1-}")
  project_root=${2-}
  [ -n "$project_root" ] || project_root=$(workspace_default_root)
  [ -d "$project_root" ] || return 0

  for path in "$project_root"/*; do
    [ -d "$path" ] || continue
    conf="$path/wizardry.workspace.conf"
    [ -f "$conf" ] || continue

    project_id=$(workspace_field "$conf" project_id "")
    [ -n "$project_id" ] || project_id=$(workspace_field "$conf" slug "$(basename "$path")")

    title=$(workspace_field "$conf" title "")
    [ -n "$title" ] || title=$(workspace_field "$conf" name "$project_id")

    project_type=$(workspace_field "$conf" project_type "")
    [ -n "$project_type" ] || project_type=$(workspace_field "$conf" context "application")

    development_context=$(workspace_field "$conf" development_context "")
    [ -n "$development_context" ] || development_context=$(workspace_field "$conf" context "web")

    targets=$(workspace_field "$conf" targets "")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$project_id" "$title" "$project_type" "$development_context" "$targets" "$path"
  done | sort
}

write_key_value_file() {
  file=$1
  key=$2
  value=$3

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/app-forge-kv.XXXXXX")
  found=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$key="*)
        if [ "$found" -eq 0 ]; then
          printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
          found=1
        fi
        ;;
      *)
        printf '%s\n' "$line" >>"$tmp_file"
        ;;
    esac
  done <"$file"

  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
  fi
  mv "$tmp_file" "$file"
}

cmd_set_app_targets() {
  root=$(require_root "${1-}")
  slug=${2-}
  targets=${3-}

  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: set-app-targets requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq

  manifest="$root/config/apps.manifest.json"
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/app-forge-manifest.XXXXXX")
  jq --arg slug "$slug" --arg targets "$targets" '
    if any(.apps[]; .slug == $slug) then
      .apps |= map(if .slug == $slug then (.targets = $targets) else . end)
    else
      error("app-not-found")
    end
  ' "$manifest" >"$tmp_file" || {
    rm -f "$tmp_file"
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }
  mv "$tmp_file" "$manifest"

  printf 'slug=%s\n' "$slug"
  printf 'targets=%s\n' "$targets"
  printf 'manifest=%s\n' "$manifest"
}

cmd_set_workspace_targets() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  targets=${3-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: set-workspace-targets requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
    exit 1
  }

  conf="$workspace_path/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: workspace profile missing: $workspace_path" >&2
    exit 1
  }

  write_key_value_file "$conf" targets "$targets"
  printf 'workspace=%s\n' "$workspace_path"
  printf 'targets=%s\n' "$targets"
  printf 'profile=%s\n' "$conf"
}

decode_base64_to_file() {
  payload=$1
  out_file=$2

  if command -v base64 >/dev/null 2>&1; then
    if printf '%s' "$payload" | base64 --decode >"$out_file" 2>/dev/null; then
      return 0
    fi
    if printf '%s' "$payload" | base64 -D >"$out_file" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

write_project_icon_from_data_url() {
  project_dir=$1
  data_url=$2

  [ -d "$project_dir" ] || {
    printf '%s\n' "forge-backend: project path not found: $project_dir" >&2
    exit 1
  }

  icon_path="$project_dir/assets/forge-icon.png"
  mkdir -p "$(dirname "$icon_path")"

  if [ -z "$data_url" ]; then
    rm -f "$icon_path"
    printf 'icon=%s\n' "$icon_path"
    printf 'status=cleared\n'
    return 0
  fi

  case "$data_url" in
    data:image/png\;base64,*)
      payload=${data_url#data:image/png;base64,}
      ;;
    data:image/*\;base64,*)
      payload=${data_url#data:image/}
      payload=${payload#*;base64,}
      ;;
    *)
      printf '%s\n' "forge-backend: icon payload must be a base64 image data URL" >&2
      exit 2
      ;;
  esac

  tmp_icon=$(mktemp "${TMPDIR:-/tmp}/app-forge-icon.XXXXXX")
  if ! decode_base64_to_file "$payload" "$tmp_icon"; then
    rm -f "$tmp_icon"
    printf '%s\n' "forge-backend: failed to decode icon payload (base64 tool missing or invalid payload)" >&2
    exit 1
  fi

  if [ ! -s "$tmp_icon" ]; then
    rm -f "$tmp_icon"
    printf '%s\n' "forge-backend: decoded icon was empty" >&2
    exit 1
  fi

  mv "$tmp_icon" "$icon_path"
  printf 'icon=%s\n' "$icon_path"
  printf 'status=updated\n'
}

cmd_set_app_icon() {
  root=$(require_root "${1-}")
  slug=${2-}
  data_url=${3-}

  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: set-app-icon requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_dir="$root/.apps/$slug"
  [ -d "$app_dir" ] || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  write_project_icon_from_data_url "$app_dir" "$data_url"
  printf 'slug=%s\n' "$slug"
}

cmd_set_workspace_icon() {
  require_root "${1-}" >/dev/null
  workspace_path=${2-}
  data_url=${3-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: set-workspace-icon requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
    exit 1
  }

  write_project_icon_from_data_url "$workspace_path" "$data_url"
  printf 'workspace=%s\n' "$workspace_path"
}

cmd_build_desktop() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: build-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"

  app_dir="$root/.apps/$slug"
  [ -d "$app_dir" ] || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  require_jq
  os=$(os_id)

  case "$os" in
    darwin)
      host_bin=$(ensure_macos_host "$root")
      app_name=$(app_name_from_manifest "$root" "$slug")
      bundle_id=$(bundle_id_from_manifest "$root" macos "$slug")
      dist_dir="$root/_tmp/workbench/dist/macos"
      bundle="$dist_dir/$app_name.app"
      zip_path="$dist_dir/$app_name.zip"

      rm -rf "$bundle"
      mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/$slug" "$bundle/Contents/Resources/wizardry-apps/core"

      cp -R "$app_dir"/. "$bundle/Contents/Resources/$slug/"
      mkdir -p "$bundle/Contents/Resources/$slug/.host"
      cp -R "$root/.apps/.host/shared" "$bundle/Contents/Resources/$slug/.host/"
      cp -R "$root/core/include" "$bundle/Contents/Resources/wizardry-apps/core/"
      cp -R "$root/core/src" "$bundle/Contents/Resources/wizardry-apps/core/"
      cp "$host_bin" "$bundle/Contents/MacOS/wizardry-host"

      cat > "$bundle/Contents/MacOS/$slug" <<APP
#!/bin/sh
set -eu
APPDIR=\$(CDPATH= cd -- "\$(dirname "\$0")/.." && pwd -P)
exec "\$APPDIR/MacOS/wizardry-host" "\$APPDIR/Resources/$slug"
APP
      chmod +x "$bundle/Contents/MacOS/$slug"

      icon_key=''
      if [ -f "$app_dir/assets/forge.icns" ]; then
        cp "$app_dir/assets/forge.icns" "$bundle/Contents/Resources/forge.icns"
        icon_key='<key>CFBundleIconFile</key><string>forge.icns</string>'
      elif [ -f "$app_dir/assets/forge-icon.png" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
        iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-iconset.XXXXXX")
        iconset="${iconset_tmp}.iconset"
        mv "$iconset_tmp" "$iconset"
        for size in 16 32 128 256 512; do
          sips -z "$size" "$size" "$app_dir/assets/forge-icon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
          sips -z $((size * 2)) $((size * 2)) "$app_dir/assets/forge-icon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
        done
        if iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/forge.icns" >/dev/null 2>&1; then
          icon_key='<key>CFBundleIconFile</key><string>forge.icns</string>'
        fi
        rm -rf "$iconset"
      elif [ -f "$app_dir/assets/forge-icon.png" ]; then
        cp "$app_dir/assets/forge-icon.png" "$bundle/Contents/Resources/forge-icon.png"
        icon_key='<key>CFBundleIconFile</key><string>forge-icon.png</string>'
      fi

      cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$app_name</string>
<key>CFBundleDisplayName</key><string>$app_name</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>$slug</string>
$icon_key
</dict></plist>
PLIST

      if command -v ditto >/dev/null 2>&1; then
        rm -f "$zip_path"
        ditto -c -k --sequesterRsrc --keepParent "$bundle" "$zip_path"
      else
        zip_path=''
      fi

      printf 'app_name=%s\n' "$app_name"
      printf 'host=%s\n' "$host_bin"
      printf 'artifact=%s\n' "$bundle"
      [ -n "$zip_path" ] && printf 'zip=%s\n' "$zip_path"
      ;;

    linux)
      host_bin=$(ensure_linux_host "$root")
      dist_dir="$root/_tmp/workbench/dist/linux"
      appdir="$dist_dir/AppDir-$slug"
      artifact=''

      rm -rf "$appdir"
      mkdir -p "$appdir/usr/bin" "$appdir/usr/share/$slug" "$appdir/usr/share/wizardry-apps/core"

      cp -R "$app_dir"/. "$appdir/usr/share/$slug/"
      mkdir -p "$appdir/usr/share/$slug/.host"
      cp -R "$root/.apps/.host/shared" "$appdir/usr/share/$slug/.host/"
      cp -R "$root/core/include" "$appdir/usr/share/wizardry-apps/core/"
      cp -R "$root/core/src" "$appdir/usr/share/wizardry-apps/core/"
      cp "$host_bin" "$appdir/usr/bin/wizardry-host"

      cat > "$appdir/AppRun" <<APP
#!/bin/sh
set -eu
HERE=\$(CDPATH= cd -- "\$(dirname "\$0")" && pwd -P)
exec "\$HERE/usr/bin/wizardry-host" "\$HERE/usr/share/$slug"
APP
      chmod +x "$appdir/AppRun"

      if command -v appimagetool >/dev/null 2>&1; then
        mkdir -p "$dist_dir"
        ARCH=x86_64 appimagetool "$appdir" "$dist_dir/wizardry-$slug-x86_64.AppImage" >/dev/null 2>&1
        artifact="$dist_dir/wizardry-$slug-x86_64.AppImage"
      else
        mkdir -p "$dist_dir"
        tar_path="$dist_dir/wizardry-$slug-linux.tar.gz"
        rm -f "$tar_path"
        (cd "$dist_dir" && tar -czf "$tar_path" "AppDir-$slug")
        artifact="$tar_path"
      fi

      printf 'app_name=%s\n' "$slug"
      printf 'host=%s\n' "$host_bin"
      printf 'appdir=%s\n' "$appdir"
      printf 'artifact=%s\n' "$artifact"
      ;;

    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac
}

cmd_install_desktop() {
  root=$(require_root "${1-}")
  slug=${2-}
  target_id=${3-}
  linux_install_mode=$(normalize_linux_install_mode "${4-}")
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: install-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"

  os=$(os_id)
  case "$os" in
    darwin)
      expected_target=macos
      ;;
    linux)
      expected_target=linux
      ;;
    *)
      printf '%s\n' "forge-backend: install-desktop is only supported on macOS and Linux hosts" >&2
      exit 1
      ;;
  esac

  if [ -n "$target_id" ] && [ "$target_id" != "$expected_target" ]; then
    printf '%s\n' "forge-backend: install-desktop target '$target_id' does not match current host '$expected_target'" >&2
    exit 2
  fi

  build_out=$(cmd_build_desktop "$root" "$slug")
  artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
  app_name=$(printf '%s\n' "$build_out" | kv_read app_name)
  appdir=$(printf '%s\n' "$build_out" | kv_read appdir)
  [ -n "$artifact" ] || {
    printf '%s\n' "forge-backend: build-desktop did not return an artifact path" >&2
    exit 1
  }

  case "$os" in
    darwin)
      [ -d "$artifact" ] || {
        printf '%s\n' "forge-backend: expected macOS app bundle artifact, got: $artifact" >&2
        exit 1
      }
      bundle_name=$(basename "$artifact")
      install_path="/Applications/$bundle_name"
      rm -rf "$install_path"
      if command -v ditto >/dev/null 2>&1; then
        ditto "$artifact" "$install_path"
      else
        cp -R "$artifact" "$install_path"
      fi

      printf 'status=ok\n'
      printf 'target=macos\n'
      printf 'install_mode=system-applications\n'
      printf 'artifact=%s\n' "$artifact"
      printf 'installed=%s\n' "$install_path"
      printf 'app_name=%s\n' "$app_name"
      ;;

    linux)
      launcher_dir="$HOME/.local/bin"
      launcher_path="$launcher_dir/wizardry-$slug"
      mkdir -p "$launcher_dir"

      case "$linux_install_mode" in
        appimage-local-bin)
          case "$artifact" in
            *.AppImage) ;;
            *)
              printf '%s\n' "forge-backend: Linux install mode appimage-local-bin requires appimagetool (artifact was: $artifact)" >&2
              exit 1
              ;;
          esac
          cp "$artifact" "$launcher_path"
          chmod +x "$launcher_path"
          install_path="$launcher_path"
          ;;

        appdir-local-share)
          [ -n "$appdir" ] || {
            printf '%s\n' "forge-backend: build-desktop did not return an AppDir path for Linux install" >&2
            exit 1
          }
          [ -d "$appdir" ] || {
            printf '%s\n' "forge-backend: Linux AppDir not found: $appdir" >&2
            exit 1
          }
          install_root="$HOME/.local/share/wizardry-apps/$slug"
          rm -rf "$install_root"
          mkdir -p "$(dirname "$install_root")"
          cp -R "$appdir" "$install_root"
          cat > "$launcher_path" <<LAUNCHER
#!/bin/sh
set -eu
exec "$install_root/AppRun" "\$@"
LAUNCHER
          chmod +x "$launcher_path"
          install_path="$install_root"

          desktop_dir="$HOME/.local/share/applications"
          desktop_file="$desktop_dir/wizardry-$slug.desktop"
          mkdir -p "$desktop_dir"
          icon_path="$install_root/usr/share/$slug/assets/forge-icon.png"
          cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$app_name
Exec=$launcher_path
Terminal=false
Categories=Development;
Icon=$icon_path
DESKTOP
          ;;
      esac

      printf 'status=ok\n'
      printf 'target=linux\n'
      printf 'install_mode=%s\n' "$linux_install_mode"
      printf 'artifact=%s\n' "$artifact"
      printf 'launcher=%s\n' "$launcher_path"
      printf 'installed=%s\n' "$install_path"
      [ -n "${install_root-}" ] && printf 'install_root=%s\n' "$install_root"
      [ -n "${desktop_file-}" ] && printf 'desktop_entry=%s\n' "$desktop_file"
      ;;
  esac
}

cmd_run_desktop() {
  root=$(require_root "${1-}")
  slug=${2-}
  run_mode=${3-auto}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: run-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  case "$run_mode" in
    ''|auto)
      # Run should favor live source to avoid stale bundle confusion.
      run_mode=host
      ;;
    host|bundle)
      ;;
    *)
      printf '%s\n' "forge-backend: run-desktop RUN_MODE must be host|bundle|auto" >&2
      exit 2
      ;;
  esac

  # Memetrader is currently iterated rapidly from source and should always run
  # the live host entry instead of a previously compiled bundle snapshot.
  if [ "$slug" = "memetrader" ] && [ "$run_mode" != "bundle" ]; then
    run_mode=host
    # Ensure stale host windows do not linger on old in-memory assets.
    if command -v pkill >/dev/null 2>&1; then
      pkill -f "wizardry-host.*[/.]apps/memetrader" >/dev/null 2>&1 || true
    fi
  fi
  # Priorities is actively iterated and should run from the live source folder.
  if [ "$slug" = "priorities" ] && [ "$run_mode" != "bundle" ]; then
    run_mode=host
  fi

  app_dir="$root/.apps/$slug"
  [ -d "$app_dir" ] || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  os=$(os_id)
  host_bin=''
  case "$os" in
    darwin)
      app_name=$(app_name_from_manifest "$root" "$slug")
      stop_desktop_instances_for_slug "$root" "$slug" "$app_name" "$os"
      bundle="$root/_tmp/workbench/dist/macos/$app_name.app"
      if [ "$run_mode" = "bundle" ]; then
        [ -d "$bundle" ] || {
          printf '%s\n' "forge-backend: desktop bundle not found, run Compile Desktop first" >&2
          exit 1
        }
        command -v open >/dev/null 2>&1 || {
          printf '%s\n' "forge-backend: open command not available on this system" >&2
          exit 1
        }
        open -na "$bundle"
        printf 'launched=1\n'
        printf 'mode=bundle\n'
        printf 'artifact=%s\n' "$bundle"
        exit 0
      fi
      host_bin=$(ensure_macos_host "$root")
      ;;
    linux)
      stop_desktop_instances_for_slug "$root" "$slug" "" "$os"
      host_bin=$(ensure_linux_host "$root")
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac

  log_dir="$root/_tmp/workbench/log"
  mkdir -p "$log_dir"
  log_path="$log_dir/$slug-host.log"

  host_zoom=''
  if [ "$slug" = "artificer" ]; then
    host_zoom=${WIZARDRY_ARTIFICER_PAGE_ZOOM:-0.92}
  fi

  stop_host_instances_for_app "$host_bin" "$app_dir"

  if command -v nohup >/dev/null 2>&1; then
    if [ -n "$host_zoom" ]; then
      nohup env WIZARDRY_PAGE_ZOOM="$host_zoom" "$host_bin" "$app_dir" >"$log_path" 2>&1 &
    else
      nohup "$host_bin" "$app_dir" >"$log_path" 2>&1 &
    fi
  else
    if [ -n "$host_zoom" ]; then
      env WIZARDRY_PAGE_ZOOM="$host_zoom" "$host_bin" "$app_dir" >"$log_path" 2>&1 &
    else
      "$host_bin" "$app_dir" >"$log_path" 2>&1 &
    fi
  fi
  pid=$!

  printf 'launched=1\n'
  printf 'mode=host\n'
  printf 'entry=%s\n' "$app_dir"
  printf 'pid=%s\n' "$pid"
  printf 'log=%s\n' "$log_path"
}

cmd_run_workspace() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  context_hint=${3-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: run-workspace requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
    exit 1
  }

  context=$context_hint
  if [ -z "$context" ] && [ -f "$workspace_path/wizardry.workspace.conf" ]; then
    context=$(workspace_field "$workspace_path/wizardry.workspace.conf" development_context "")
    [ -n "$context" ] || context=$(workspace_field "$workspace_path/wizardry.workspace.conf" context "")
  fi
  [ -n "$context" ] || context=web

  case "$context" in
    godot|game)
      project_title=''
      if [ -f "$workspace_path/wizardry.workspace.conf" ]; then
        project_title=$(workspace_field "$workspace_path/wizardry.workspace.conf" title "")
      fi
      if ! project_path=$(ensure_godot_project "$workspace_path" "$project_title"); then
        printf '%s\n' "forge-backend: Godot project not found in workspace (missing project.godot): $workspace_path" >&2
        exit 1
      fi

      engine=$(resolve_godot_engine) || {
        printf '%s\n' "forge-backend: godot4/godot not found (set GODOT_BIN or install Godot)" >&2
        exit 1
      }

      workspace_id=$(basename "$workspace_path")
      log_dir="$root/_tmp/workbench/log"
      mkdir -p "$log_dir"
      log_path="$log_dir/workspace-$workspace_id-godot.log"

      if [ "$engine" = "__GODOT_APP__" ]; then
        open -na "Godot" --args --path "$project_path" >/dev/null 2>&1 || {
          printf '%s\n' "forge-backend: failed to launch Godot.app" >&2
          exit 1
        }
        printf 'launched=1\n'
        printf 'mode=godot-app\n'
        printf 'entry=%s\n' "$project_path"
        printf 'log=%s\n' "$log_path"
        return 0
      fi

      if command -v nohup >/dev/null 2>&1; then
        nohup "$engine" --path "$project_path" >"$log_path" 2>&1 &
      else
        "$engine" --path "$project_path" >"$log_path" 2>&1 &
      fi
      pid=$!
      printf 'launched=1\n'
      printf 'mode=godot\n'
      printf 'entry=%s\n' "$project_path"
      printf 'pid=%s\n' "$pid"
      printf 'log=%s\n' "$log_path"
      return 0
      ;;
  esac

  app_dir="$workspace_path/app"
  if [ ! -f "$app_dir/index.html" ] && [ -f "$workspace_path/index.html" ]; then
    app_dir="$workspace_path"
  fi
  [ -f "$app_dir/index.html" ] || {
    printf '%s\n' "forge-backend: workspace app index not found: $workspace_path" >&2
    exit 1
  }

  os=$(os_id)
  host_bin=''
  case "$os" in
    darwin)
      host_bin=$(ensure_macos_host "$root")
      ;;
    linux)
      host_bin=$(ensure_linux_host "$root")
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac

  workspace_id=$(basename "$workspace_path")
  log_dir="$root/_tmp/workbench/log"
  mkdir -p "$log_dir"
  log_path="$log_dir/workspace-$workspace_id-host.log"

  workspace_conf="$workspace_path/wizardry.workspace.conf"
  stop_host_instances_for_app "$host_bin" "$app_dir"

  if [ "$os" = "darwin" ] && command -v open >/dev/null 2>&1; then
    workspace_title=$(workspace_field "$workspace_conf" title "")
    [ -n "$workspace_title" ] || workspace_title=$(workspace_field "$workspace_conf" name "")
    [ -n "$workspace_title" ] || workspace_title=$(basename "$workspace_path")

    workspace_slug=$(workspace_field "$workspace_conf" project_id "")
    [ -n "$workspace_slug" ] || workspace_slug=$(workspace_field "$workspace_conf" slug "")
    [ -n "$workspace_slug" ] || workspace_slug=$(basename "$workspace_path")
    workspace_slug=$(sanitize_bundle_component "$workspace_slug")

    bundle_root="$root/_tmp/workbench/dist/macos-workspaces/$workspace_slug"
    bundle="$bundle_root/$workspace_title.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"

    cat > "$bundle/Contents/MacOS/$workspace_slug" <<APP
#!/bin/sh
set -eu
exec "$host_bin" "$app_dir"
APP
    chmod +x "$bundle/Contents/MacOS/$workspace_slug"

    icon_source=''
    if [ -f "$workspace_path/assets/forge-icon.png" ]; then
      icon_source="$workspace_path/assets/forge-icon.png"
    elif [ -f "$app_dir/assets/forge-icon.png" ]; then
      icon_source="$app_dir/assets/forge-icon.png"
    fi

    icon_key=''
    if [ -n "$icon_source" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
      iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-ws-iconset.XXXXXX")
      iconset="${iconset_tmp}.iconset"
      mv "$iconset_tmp" "$iconset"
      for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
      done
      if iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/forge.icns" >/dev/null 2>&1; then
        icon_key='<key>CFBundleIconFile</key><string>forge.icns</string>'
      fi
      rm -rf "$iconset"
    fi

    bundle_id="com.wizardry.workspace.$workspace_slug"
    cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$workspace_title</string>
<key>CFBundleDisplayName</key><string>$workspace_title</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>$workspace_slug</string>
$icon_key
</dict></plist>
PLIST

    open -na "$bundle"
    printf 'launched=1\n'
    printf 'mode=bundle\n'
    printf 'artifact=%s\n' "$bundle"
    printf 'entry=%s\n' "$app_dir"
    printf 'log=%s\n' "$log_path"
    return 0
  fi

  if command -v nohup >/dev/null 2>&1; then
    nohup "$host_bin" "$app_dir" >"$log_path" 2>&1 &
  else
    "$host_bin" "$app_dir" >"$log_path" 2>&1 &
  fi
  pid=$!

  printf 'launched=1\n'
  printf 'mode=host\n'
  printf 'entry=%s\n' "$app_dir"
  printf 'pid=%s\n' "$pid"
  printf 'log=%s\n' "$log_path"
}

cmd_serve_hosted_web() {
  root=$(require_root "${1-}")
  mode=${2-}
  ref=${3-}

  [ -n "$mode" ] || {
    printf '%s\n' "forge-backend: serve-hosted-web requires MODE (builtin|workspace)" >&2
    exit 2
  }
  [ -n "$ref" ] || {
    printf '%s\n' "forge-backend: serve-hosted-web requires REF (APP_SLUG or WORKSPACE_PATH)" >&2
    exit 2
  }

  case "$mode" in
    builtin)
      slug=$ref
      validate_slug "$slug"
      template_dir="$root/.web/$slug"
      [ -d "$template_dir" ] || {
        printf '%s\n' "forge-backend: hosted web template not found for app: $slug" >&2
        exit 1
      }

      web_root=${WEB_WIZARDRY_ROOT:-$HOME/sites}
      site_name="forge-$slug"
      site_dir="$web_root/$site_name"
      web_log="$root/_tmp/workbench/log/hosted-web/$site_name-web-wizardry.log"
      mkdir -p "$(dirname "$web_log")"

      command -v web-wizardry >/dev/null 2>&1 || {
        printf '%s\n' "forge-backend: web-wizardry is required to serve hosted web targets" >&2
        exit 1
      }
      command -v create-from-template >/dev/null 2>&1 || {
        printf '%s\n' "forge-backend: create-from-template is required to serve hosted web targets" >&2
        exit 1
      }

      if ! (
        if [ ! -d "$site_dir" ]; then
          WIZARDRY_DIR="$root" create-from-template "$site_name" "$slug"
        fi
        WIZARDRY_DIR="$root" web-wizardry build "$site_name"
        WIZARDRY_DIR="$root" web-wizardry serve "$site_name"
      ) >"$web_log" 2>&1; then
        printf '%s\n' "forge-backend: hosted web serve failed (see log: $web_log)" >&2
        exit 1
      fi

      site_conf="$site_dir/site.conf"
      domain=$(config_field "$site_conf" domain "localhost")
      port=$(config_field "$site_conf" port "8080")
      https=$(config_field "$site_conf" https "false")
      scheme=http
      if [ "$https" = "true" ]; then
        scheme=https
      fi

      printf 'mode=web-wizardry\n'
      printf 'site=%s\n' "$site_name"
      printf 'entry=%s\n' "$site_dir"
      printf 'url=%s\n' "$scheme://$domain:$port"
      printf 'log=%s\n' "$web_log"
      ;;

    workspace)
      printf '%s\n' "forge-backend: hosted web serve currently supports built-in app templates only" >&2
      exit 1
      ;;

    *)
      printf '%s\n' "forge-backend: serve-hosted-web MODE must be builtin|workspace" >&2
      exit 2
      ;;
  esac
}

cmd_stage_mobile() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: stage-mobile requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  dest="$root/_tmp/workbench/stage/mobile-$slug"
  sh "$root/tools/release/stage-web-assets.sh" "$slug" "$dest"
  printf 'staged=%s\n' "$dest"
}

cmd_build_ios_smoke() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: build-ios-smoke requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  [ "$(os_id)" = "darwin" ] || {
    printf '%s\n' "forge-backend: build-ios-smoke is supported on macOS only" >&2
    exit 1
  }
  require_tool xcodegen
  require_tool xcodebuild

  out_dir="$root/_tmp/workbench/dist/ios"
  mkdir -p "$out_dir"
  sh "$root/tools/release/build-ios-app.sh" "$slug" "$out_dir" smoke
  printf 'out=%s\n' "$out_dir"
}

cmd_build_android_debug() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: build-android-debug requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  require_tool gradle
  require_tool java

  app_name=$(app_name_from_manifest "$root" "$slug")
  app_id=$(bundle_id_from_manifest "$root" android "$slug")

  sh "$root/tools/release/stage-web-assets.sh" "$slug" "$root/.apps/.host/android/app/src/main/assets"

  version_name="0.0.0-local"
  version_code=$(date +%s)

  gradle -p "$root/.apps/.host/android" :app:assembleDebug \
    -PwizardryApplicationId="$app_id" \
    -PwizardryAppName="$app_name" \
    -PwizardryVersionName="$version_name" \
    -PwizardryVersionCode="$version_code"

  apk=$(find "$root/.apps/.host/android/app/build/outputs/apk/debug" -type f -name '*.apk' | head -n 1)
  [ -n "$apk" ] || {
    printf '%s\n' "forge-backend: debug APK not found" >&2
    exit 1
  }

  out_dir="$root/_tmp/workbench/dist/android"
  mkdir -p "$out_dir"
  out_apk="$out_dir/wizardry-$slug-debug.apk"
  cp "$apk" "$out_apk"

  printf 'artifact=%s\n' "$out_apk"
}

run_logged_step() {
  log=$1
  label=$2
  script_path=$3

  printf 'step=%s\n' "$label" >>"$log"
  printf '$ sh %s\n' "$script_path" >>"$log"
  if sh "$script_path" >>"$log" 2>&1; then
    printf 'step_status=%s:ok\n' "$label" >>"$log"
    return 0
  fi

  printf 'step_status=%s:failed\n' "$label" >>"$log"
  return 1
}

write_minimal_template() {
  app_dir=$1
  app_name=$2

  cat > "$app_dir/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$app_name</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main class="shell">
    <h1>$app_name</h1>
    <p>This app is scaffolded from App Forge.</p>
    <button id="ping">Ping bridge</button>
    <pre id="out">ready</pre>
  </main>

  <script>
    (function loadBridge() {
      var candidates = ['./.host/shared/wizardry-bridge.js', '../.host/shared/wizardry-bridge.js'];
      var i = 0;
      function tryNext() {
        if (i >= candidates.length) {
          return;
        }
        var s = document.createElement('script');
        s.src = candidates[i++];
        s.onerror = tryNext;
        document.head.appendChild(s);
      }
      tryNext();
    })();
  </script>
  <script>
    document.getElementById('ping').addEventListener('click', async function () {
      var out = document.getElementById('out');
      if (!window.wizardry || !window.wizardry.rpc) {
        out.textContent = 'wizardry bridge unavailable';
        return;
      }
      try {
        var res = await window.wizardry.rpc('core.ping', {});
        out.textContent = JSON.stringify(res, null, 2);
      } catch (err) {
        out.textContent = String(err && err.message ? err.message : err);
      }
    });
  </script>
</body>
</html>
HTML

  cat > "$app_dir/style.css" <<'CSS'
:root {
  --bg: #141821;
  --panel: #1b2230;
  --line: #2c3648;
  --fg: #eff6ff;
  --muted: #a6b7cc;
  --accent: #5dc2a6;
}

body {
  margin: 0;
  min-height: 100vh;
  background: radial-gradient(circle at 20% 0%, #253146 0%, #141821 55%);
  color: var(--fg);
  font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.shell {
  max-width: 760px;
  margin: 5rem auto;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 1.2rem;
}

h1 {
  margin: 0 0 0.7rem;
}

p {
  margin: 0 0 1rem;
  color: var(--muted);
}

button {
  border: 1px solid transparent;
  background: var(--accent);
  color: #0b1715;
  border-radius: 10px;
  padding: 0.45rem 0.8rem;
  cursor: pointer;
  font-weight: 600;
}

pre {
  background: #0f141d;
  border: 1px solid #232f40;
  border-radius: 10px;
  margin: 1rem 0 0;
  padding: 0.75rem;
  min-height: 7rem;
  overflow: auto;
}
CSS
}

write_panel_template() {
  app_dir=$1
  app_name=$2

  cat > "$app_dir/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$app_name</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <h1>$app_name</h1>
    <p>Control panel starter generated by App Forge.</p>
  </header>

  <section class="buttons">
    <button data-cmd="status">Status</button>
    <button data-cmd="build">Build Site</button>
    <button data-cmd="serve">Serve Site</button>
    <button data-cmd="stop">Stop Site</button>
  </section>

  <pre id="out">ready</pre>

  <script>
    (function loadBridge() {
      var candidates = ['./.host/shared/wizardry-bridge.js', '../.host/shared/wizardry-bridge.js'];
      var i = 0;
      function tryNext() {
        if (i >= candidates.length) {
          return;
        }
        var s = document.createElement('script');
        s.src = candidates[i++];
        s.onerror = tryNext;
        document.head.appendChild(s);
      }
      tryNext();
    })();
  </script>
  <script>
    var out = document.getElementById('out');
    var site = 'demo';
    var commands = {
      status: ['web-wizardry', 'status', site],
      build: ['web-wizardry', 'build', site],
      serve: ['web-wizardry', 'serve', site],
      stop: ['web-wizardry', 'stop', site]
    };

    document.querySelectorAll('button[data-cmd]').forEach(function (btn) {
      btn.addEventListener('click', async function () {
        var key = btn.getAttribute('data-cmd');
        var argv = commands[key];
        if (!window.wizardry || !window.wizardry.rpc) {
          out.textContent = 'wizardry bridge unavailable';
          return;
        }
        out.textContent = 'running: ' + argv.join(' ');
        try {
          var res = await window.wizardry.rpc('bridge.exec', { argv: argv });
          out.textContent = ['exit=' + res.exit_code, res.stdout || '', res.stderr || ''].filter(Boolean).join('\n');
        } catch (err) {
          out.textContent = String(err && err.message ? err.message : err);
        }
      });
    });
  </script>
</body>
</html>
HTML

  cat > "$app_dir/style.css" <<'CSS'
:root {
  --bg: #faf5ee;
  --line: #d7c7b2;
  --ink: #2f2314;
  --panel: #fff8f0;
  --action: #b16900;
}

body {
  margin: 0;
  min-height: 100vh;
  background: linear-gradient(160deg, #f2e7d9 0%, #f9f3ea 62%);
  color: var(--ink);
  font-family: "Avenir Next", "Segoe UI", sans-serif;
}

header {
  padding: 1rem 1.2rem;
  border-bottom: 1px solid var(--line);
}

header h1 {
  margin: 0;
  font-size: 1.25rem;
}

header p {
  margin: 0.35rem 0 0;
  color: #71553a;
}

.buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  padding: 1rem 1.2rem;
}

button {
  border: 1px solid transparent;
  background: var(--action);
  color: #fff;
  border-radius: 8px;
  padding: 0.45rem 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

pre {
  margin: 0 1.2rem 1.2rem;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 10px;
  min-height: 12rem;
  padding: 0.8rem;
  overflow: auto;
  white-space: pre-wrap;
}
CSS
}

append_manifest_app() {
  root=$1
  slug=$2
  name=$3

  manifest="$root/config/apps.manifest.json"
  tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/wizardry-apps-manifest.XXXXXX")

  if jq -e --arg slug "$slug" '.apps[] | select(.slug == $slug)' "$manifest" >/dev/null 2>&1; then
    rm -f "$tmp_manifest"
    printf '%s\n' "forge-backend: app slug already exists in manifest: $slug" >&2
    exit 1
  fi

  jq --arg slug "$slug" --arg name "$name" '
    .apps += [{
      "slug": $slug,
      "name": $name,
      "production": false,
      "bundleIds": {
        "macos": ("com.wizardry.apps." + $slug + ".macos"),
        "ios": ("com.wizardry.apps." + $slug + ".ios"),
        "android": ("com.wizardry.apps." + $slug + ".android")
      }
    }]
  ' "$manifest" > "$tmp_manifest"

  mv "$tmp_manifest" "$manifest"
}

cmd_scaffold_app() {
  root=$(require_root "${1-}")
  slug=${2-}
  app_name=${3-}
  template=${4-}
  source_app=${5-}

  [ -n "$slug" ] || { printf '%s\n' "forge-backend: scaffold-app requires APP_SLUG" >&2; exit 2; }
  [ -n "$app_name" ] || { printf '%s\n' "forge-backend: scaffold-app requires APP_NAME" >&2; exit 2; }
  [ -n "$template" ] || { printf '%s\n' "forge-backend: scaffold-app requires TEMPLATE" >&2; exit 2; }

  validate_slug "$slug"
  require_jq

  app_dir="$root/.apps/$slug"
  [ ! -e "$app_dir" ] || {
    printf '%s\n' "forge-backend: app path already exists: $app_dir" >&2
    exit 1
  }

  case "$template" in
    minimal|panel) ;;
    clone)
      [ -n "$source_app" ] || {
        printf '%s\n' "forge-backend: scaffold-app clone requires SOURCE_APP" >&2
        exit 2
      }
      validate_slug "$source_app"
      source_dir="$root/.apps/$source_app"
      [ -d "$source_dir" ] || {
        printf '%s\n' "forge-backend: source app not found: $source_app" >&2
        exit 1
      }
      ;;
    *)
      printf '%s\n' "forge-backend: unknown app template: $template" >&2
      exit 2
      ;;
  esac

  mkdir -p "$app_dir"

  case "$template" in
    minimal)
      write_minimal_template "$app_dir" "$app_name"
      ;;
    panel)
      write_panel_template "$app_dir" "$app_name"
      ;;
    clone)
      rm -rf "$app_dir"
      mkdir -p "$app_dir"
      cp -R "$source_dir"/. "$app_dir/"
      ;;
  esac

  append_manifest_app "$root" "$slug" "$app_name"

  printf 'created=%s\n' "$app_dir"
  printf 'manifest=%s\n' "$root/config/apps.manifest.json"
}

cmd_scaffold_workspace() {
  root=$(require_root "${1-}")
  slug=${2-}
  app_name=${3-}
  context=${4-}
  starter=${5-}
  targets=${6-}
  source=${7-}
  project_root=${8-}

  [ -n "$slug" ] || { printf '%s\n' "forge-backend: scaffold-workspace requires APP_SLUG" >&2; exit 2; }
  [ -n "$app_name" ] || { printf '%s\n' "forge-backend: scaffold-workspace requires APP_NAME" >&2; exit 2; }
  [ -n "$context" ] || { printf '%s\n' "forge-backend: scaffold-workspace requires CONTEXT" >&2; exit 2; }
  [ -n "$starter" ] || { printf '%s\n' "forge-backend: scaffold-workspace requires STARTER" >&2; exit 2; }
  [ -n "$targets" ] || { printf '%s\n' "forge-backend: scaffold-workspace requires TARGETS" >&2; exit 2; }

  validate_slug "$slug"

  case "$targets" in
    *[!a-zA-Z0-9,._-]*)
      printf '%s\n' "forge-backend: scaffold-workspace targets contain invalid characters" >&2
      exit 2
      ;;
  esac

  [ -n "$project_root" ] || project_root=$(workspace_default_root)
  case "$project_root" in
    /*) ;;
    *)
      project_root="$(pwd -P)/$project_root"
      ;;
  esac
  mkdir -p "$project_root"

  workspace_dir="$project_root/$slug"
  [ ! -e "$workspace_dir" ] || {
    printf '%s\n' "forge-backend: workspace path already exists: $workspace_dir" >&2
    exit 1
  }

  case "$context" in
    web|application)
      project_type=application
      development_context=web

      case "$starter" in
        minimal|panel|clone) ;;
        *)
          printf '%s\n' "forge-backend: scaffold-workspace unknown web starter: $starter" >&2
          exit 2
          ;;
      esac

      app_dir="$workspace_dir/app"
      mkdir -p "$app_dir"

      case "$starter" in
        minimal)
          write_minimal_template "$app_dir" "$app_name"
          ;;
        panel)
          write_panel_template "$app_dir" "$app_name"
          ;;
        clone)
          [ -n "$source" ] || {
            printf '%s\n' "forge-backend: scaffold-workspace web clone requires SOURCE" >&2
            exit 2
          }
          validate_slug "$source"
          source_dir="$root/.apps/$source"
          [ -d "$source_dir" ] || {
            printf '%s\n' "forge-backend: source app not found: $source" >&2
            exit 1
          }
          rm -rf "$app_dir"
          mkdir -p "$app_dir"
          cp -R "$source_dir"/. "$app_dir/"
          ;;
      esac

      cat > "$workspace_dir/README.md" <<README
# $app_name

Application workspace scaffolded by App Forge.

- Development context: web
- App files: app/
README
      ;;

    godot|game)
      project_type=game
      development_context=godot

      case "$starter" in
        blank)
          mkdir -p "$workspace_dir"
          cat > "$workspace_dir/project.godot" <<PROJECT
; Engine configuration file.
config_version=5

[application]
config/name="$app_name"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("4.2")
PROJECT
          cat > "$workspace_dir/Main.tscn" <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tool_main.gd" id="1_tool"]

[node name="Main" type="Node"]
script = ExtResource("1_tool")
TSCN
          cat > "$workspace_dir/README.md" <<README
# $app_name

Godot workspace scaffold generated by App Forge.
README
          cat > "$workspace_dir/tool_main.gd" <<'GDSCRIPT'
extends Node

func _ready():
    print("Wizardry Godot tool workspace ready.")
GDSCRIPT
          ;;
        clone)
          [ -n "$source" ] || {
            printf '%s\n' "forge-backend: scaffold-workspace godot clone requires SOURCE" >&2
            exit 2
          }
          validate_slug "$source"

          source_dir=''
          for candidate in \
            "$root/godot/tools/$source" \
            "$project_root/$source"; do
            if [ -d "$candidate" ]; then
              source_dir=$candidate
              break
            fi
          done

          [ -d "$source_dir" ] || {
            printf '%s\n' "forge-backend: source godot tool not found: $source" >&2
            exit 1
          }
          cp -R "$source_dir" "$workspace_dir"
          if [ ! -f "$workspace_dir/README.md" ]; then
            cat > "$workspace_dir/README.md" <<README
# $app_name

Godot workspace cloned by App Forge.
README
          fi
          ;;
        *)
          printf '%s\n' "forge-backend: scaffold-workspace unknown godot starter: $starter" >&2
          exit 2
          ;;
      esac

      ;;

    *)
      printf '%s\n' "forge-backend: scaffold-workspace context must be web/application or godot/game" >&2
      exit 2
      ;;
  esac

  profile="$workspace_dir/wizardry.workspace.conf"
  cat > "$profile" <<CONF
# Wizardry Apps workspace profile
project_id=$slug
title=$app_name
project_type=$project_type
development_context=$development_context
starter=$starter
targets=$targets
source=${source-}
root=$workspace_dir

# Legacy keys preserved for compatibility.
slug=$slug
name=$app_name
context=$development_context
CONF

  printf 'created=%s\n' "$workspace_dir"
  printf 'workspace_profile=%s\n' "$profile"
  printf 'project_root=%s\n' "$project_root"
  printf 'project_type=%s\n' "$project_type"
  printf 'development_context=%s\n' "$development_context"
  printf 'targets=%s\n' "$targets"
}

cmd_scaffold_site() {
  root=$(require_root "${1-}")
  site_name=${2-}
  template=${3-}
  dest_root=${4-}

  [ -n "$site_name" ] || { printf '%s\n' "forge-backend: scaffold-site requires SITE_NAME" >&2; exit 2; }
  [ -n "$template" ] || { printf '%s\n' "forge-backend: scaffold-site requires TEMPLATE" >&2; exit 2; }

  validate_site_name "$site_name"

  if [ -z "$dest_root" ]; then
    dest_root="$HOME/sites"
  fi

  template_dir="$root/.web/$template"
  [ -d "$template_dir" ] || {
    printf '%s\n' "forge-backend: template not found: $template" >&2
    exit 1
  }

  site_dir="$dest_root/$site_name"
  [ ! -e "$site_dir" ] || {
    printf '%s\n' "forge-backend: destination already exists: $site_dir" >&2
    exit 1
  }

  mkdir -p "$site_dir"
  cp -R "$template_dir"/. "$site_dir/"

  if [ -d "$site_dir/pages" ]; then
    mkdir -p "$site_dir/site"
    mv "$site_dir/pages" "$site_dir/site/"
  fi

  if [ -d "$site_dir/static" ]; then
    mkdir -p "$site_dir/site"
    mv "$site_dir/static" "$site_dir/site/"
  fi

  if [ -d "$site_dir/includes" ]; then
    mkdir -p "$site_dir/site"
    mv "$site_dir/includes" "$site_dir/site/"
  fi

  if [ -d "$root/.web/.themes" ]; then
    mkdir -p "$site_dir/site/static/themes"
    cp -f "$root/.web/.themes"/*.css "$site_dir/site/static/themes/" 2>/dev/null || true
  fi

  mkdir -p "$site_dir/site/uploads" "$site_dir/build"

  cat > "$site_dir/site.conf" <<CONF
# Site configuration for $site_name
site-name=$site_name
site-user=
template=$template
port=8080
domain=localhost
https=false
CONF

  cat > "$site_dir/site.allowlist" <<'ALLOW'
# List additional absolute paths this site may access.
# One path per line. Lines starting with # are ignored.
ALLOW

  printf 'created=%s\n' "$site_dir"
}

cmd_run_task() {
  root=$(require_root "${1-}")
  task=${2-}
  [ -n "$task" ] || {
    printf '%s\n' "forge-backend: run-task requires TASK" >&2
    exit 2
  }

  task_log_dir="$root/_tmp/workbench/log/tasks"
  mkdir -p "$task_log_dir"
  task_log="$task_log_dir/$task-$(date +%Y%m%d-%H%M%S).log"
  {
    printf 'task=%s\n' "$task"
    printf 'root=%s\n' "$root"
    printf 'started_at=%s\n' "$(date)"
  } >"$task_log"

  status=0
  case "$task" in
    validate-manifest)
      run_logged_step "$task_log" "validate-manifest" "$root/tools/validate-manifest.sh" || status=$?
      ;;
    test-core)
      run_logged_step "$task_log" "core-tests" "$root/core/tests/test_core.sh" || status=$?
      [ "$status" -eq 0 ] && run_logged_step "$task_log" "core-rpc-tests" "$root/.tests/core/test-core-rpc.sh" || status=$?
      ;;
    test-adapters)
      run_logged_step "$task_log" "adapter-http-cgi" "$root/.tests/adapters/test-http-cgi.sh" || status=$?
      [ "$status" -eq 0 ] && run_logged_step "$task_log" "adapter-shell-parity" "$root/.tests/adapters/test-shell-parity.sh" || status=$?
      [ "$status" -eq 0 ] && run_logged_step "$task_log" "adapter-core-shell-parity" "$root/.tests/adapters/test-core-shell-parity.sh" || status=$?
      [ "$status" -eq 0 ] && run_logged_step "$task_log" "adapter-bridge-contract" "$root/.tests/adapters/test-bridge-contract.sh" || status=$?
      [ "$status" -eq 0 ] && run_logged_step "$task_log" "adapter-bridge-behavior" "$root/.tests/adapters/test-bridge-behavior.sh" || status=$?
      ;;
    test-release-tools)
      run_logged_step "$task_log" "release-tools" "$root/.tests/release/test-release-tools.sh" || status=$?
      ;;
    *)
      printf '%s\n' "forge-backend: unknown task: $task" >&2
      exit 2
      ;;
  esac

  printf 'finished_at=%s\n' "$(date)" >>"$task_log"

  if [ "$status" -ne 0 ]; then
    printf '%s\n' "forge-backend: task $task failed (see log: $task_log)" >&2
    exit "$status"
  fi

  printf 'task=%s\n' "$task"
  printf 'status=ok\n'
  printf 'log=%s\n' "$task_log"
}

cmd=${1-}
case "$cmd" in
  doctor)
    cmd_doctor "${2-}"
    ;;
  list-apps)
    cmd_list_apps "${2-}"
    ;;
  list-templates)
    cmd_list_templates "${2-}"
    ;;
  list-themes)
    cmd_list_themes "${2-}"
    ;;
  list-godot-tools)
    cmd_list_godot_tools "${2-}"
    ;;
  list-workspaces)
    cmd_list_workspaces "${2-}" "${3-}"
    ;;
  get-ui-prefs)
    cmd_get_ui_prefs "${2-}"
    ;;
  set-ui-pref)
    cmd_set_ui_pref "${2-}" "${3-}" "${4-}"
    ;;
  set-app-targets)
    cmd_set_app_targets "${2-}" "${3-}" "${4-}"
    ;;
  set-workspace-targets)
    cmd_set_workspace_targets "${2-}" "${3-}" "${4-}"
    ;;
  set-app-icon)
    cmd_set_app_icon "${2-}" "${3-}" "${4-}"
    ;;
  set-workspace-icon)
    cmd_set_workspace_icon "${2-}" "${3-}" "${4-}"
    ;;
  build-desktop)
    cmd_build_desktop "${2-}" "${3-}"
    ;;
  run-desktop)
    cmd_run_desktop "${2-}" "${3-}" "${4-}"
    ;;
  install-desktop)
    cmd_install_desktop "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  run-workspace)
    cmd_run_workspace "${2-}" "${3-}" "${4-}"
    ;;
  serve-hosted-web)
    cmd_serve_hosted_web "${2-}" "${3-}" "${4-}"
    ;;
  stage-mobile)
    cmd_stage_mobile "${2-}" "${3-}"
    ;;
  build-ios-smoke)
    cmd_build_ios_smoke "${2-}" "${3-}"
    ;;
  build-android-debug)
    cmd_build_android_debug "${2-}" "${3-}"
    ;;
  scaffold-app)
    cmd_scaffold_app "${2-}" "${3-}" "${4-}" "${5-}" "${6-}"
    ;;
  scaffold-workspace)
    cmd_scaffold_workspace "${2-}" "${3-}" "${4-}" "${5-}" "${6-}" "${7-}" "${8-}" "${9-}"
    ;;
  scaffold-site)
    cmd_scaffold_site "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  run-task)
    cmd_run_task "${2-}" "${3-}"
    ;;
  *)
    printf '%s\n' "forge-backend: unknown command '$cmd' (use --help)" >&2
    exit 2
    ;;
esac
