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
  app-status [ROOT_HINT] APP_SLUG
  template-status [ROOT_HINT] TEMPLATE_SLUG
  list-themes [ROOT_HINT]
  list-godot-tools [ROOT_HINT]
  list-workspaces [ROOT_HINT] [PROJECT_ROOT]
  import-workspace [ROOT_HINT] WORKSPACE_PATH [PROJECT_ROOT]
  get-ui-prefs [ROOT_HINT]
  set-ui-pref [ROOT_HINT] KEY VALUE
  set-app-targets [ROOT_HINT] APP_SLUG TARGETS
  set-workspace-targets [ROOT_HINT] WORKSPACE_PATH TARGETS
  rename-workspace [ROOT_HINT] WORKSPACE_PATH NEW_TITLE
  set-app-icon [ROOT_HINT] APP_SLUG DATA_URL
  set-workspace-icon [ROOT_HINT] WORKSPACE_PATH DATA_URL
  download-app [ROOT_HINT] APP_SLUG
  remove-downloaded-app [ROOT_HINT] APP_SLUG
  download-template [ROOT_HINT] TEMPLATE_SLUG
  remove-downloaded-template [ROOT_HINT] TEMPLATE_SLUG
  build-desktop [ROOT_HINT] APP_SLUG
  install-desktop [ROOT_HINT] APP_SLUG [TARGET_ID]
  run-desktop [ROOT_HINT] APP_SLUG
  run-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT]
  serve-hosted-web [ROOT_HINT] MODE REF
  stage-mobile [ROOT_HINT] APP_SLUG
  build-ios-smoke [ROOT_HINT] APP_SLUG
  build-android-debug [ROOT_HINT] APP_SLUG
  scaffold-app [ROOT_HINT] APP_SLUG APP_NAME TEMPLATE [SOURCE_APP]
  scaffold-workspace [ROOT_HINT] APP_SLUG APP_NAME CONTEXT STARTER TARGETS [SOURCE] [PROJECT_ROOT]
  scaffold-site [ROOT_HINT] SITE_NAME TEMPLATE [DEST_ROOT]
  run-task [ROOT_HINT] TASK

TASK values:
  validate-manifest | test-core | test-adapters | test-release-tools

TEMPLATE values for scaffold-app:
  minimal | panel | clone

CONTEXT values for scaffold-workspace:
  web | godot
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
  [ -d "$root/apps" ] || return 1
  [ -d "$root/web" ] || return 1
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

path_mtime_epoch() {
  path=${1-}
  [ -n "$path" ] || {
    printf '%s\n' "0"
    return 0
  }
  [ -e "$path" ] || {
    printf '%s\n' "0"
    return 0
  }

  if ts=$(stat -f %m "$path" 2>/dev/null); then
    printf '%s\n' "$ts"
    return 0
  fi

  if ts=$(stat -c %Y "$path" 2>/dev/null); then
    printf '%s\n' "$ts"
    return 0
  fi

  printf '%s\n' "0"
}

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
  printf '%s\n' "forge-backend: sha256 tool not available (requires shasum, sha256sum, or openssl)" >&2
  exit 1
}

hash_file_sha256() {
  file=${1-}
  [ -n "$file" ] || {
    printf '%s\n' "forge-backend: hash_file_sha256 requires FILE" >&2
    exit 2
  }
  [ -f "$file" ] || {
    printf '%s\n' "forge-backend: cannot hash missing file: $file" >&2
    exit 1
  }

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
  printf '%s\n' "forge-backend: sha256 tool not available (requires shasum, sha256sum, or openssl)" >&2
  exit 1
}

hash_path_sha256() {
  path=${1-}
  [ -n "$path" ] || {
    printf '%s\n' "forge-backend: hash_path_sha256 requires PATH" >&2
    exit 2
  }

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

  if [ -d "$path" ]; then
    listing=$(mktemp "${TMPDIR:-/tmp}/forge-path-hash.XXXXXX")
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
    return 0
  fi

  printf 'X %s\n' "$path" | hash_stdin_sha256
}

desktop_build_input_hash() {
  root=${1-}
  slug=${2-}
  app_dir=${3-}
  target=${4-}

  [ -n "$root" ] || return 1
  [ -n "$slug" ] || return 1
  [ -n "$app_dir" ] || return 1
  [ -n "$target" ] || return 1

  host_src=''
  bundle_target=''
  case "$target" in
    darwin)
      host_src="$root/apps/.host/macos/main.m"
      bundle_target='macos'
      ;;
    linux)
      host_src="$root/apps/.host/linux/main.c"
      bundle_target='linux'
      ;;
    *)
      return 1
      ;;
  esac

  bundle_id=$(bundle_id_from_manifest "$root" "$bundle_target" "$slug")

  {
    printf 'v=2\n'
    printf 'slug=%s\n' "$slug"
    printf 'target=%s\n' "$target"
    printf 'bundle_id=%s\n' "$bundle_id"
    printf 'manifest=%s\n' "$(hash_path_sha256 "$root/config/apps.manifest.json")"
    printf 'host=%s\n' "$(hash_path_sha256 "$host_src")"
    printf 'app=%s\n' "$(hash_path_sha256 "$app_dir")"
    printf 'app_icon_override=%s\n' "$(hash_path_sha256 "$(app_icon_override_path "$slug")")"
    printf 'shared=%s\n' "$(hash_path_sha256 "$root/apps/.host/shared")"
    printf 'core_include=%s\n' "$(hash_path_sha256 "$root/core/include")"
    printf 'core_src=%s\n' "$(hash_path_sha256 "$root/core/src")"
    printf 'backend=%s\n' "$(hash_path_sha256 "$SCRIPT_DIR/forge-backend.sh")"
  } | hash_stdin_sha256
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
  resolve_app_dir "$root" "$slug" >/dev/null 2>&1
}

forge_catalog_root() {
  base="${XDG_STATE_HOME:-$HOME/.local/state}/wizardry-apps/forge/catalog"
  mkdir -p "$base/apps" "$base/templates"
  printf '%s\n' "$base"
}

forge_catalog_apps_dir() {
  printf '%s\n' "$(forge_catalog_root)/apps"
}

forge_catalog_templates_dir() {
  printf '%s\n' "$(forge_catalog_root)/templates"
}

forge_catalog_icon_overrides_dir() {
  printf '%s\n' "$(forge_catalog_root)/icon-overrides/apps"
}

app_icon_override_path() {
  slug=$1
  printf '%s\n' "$(forge_catalog_icon_overrides_dir)/$slug/forge-icon.png"
}

apply_optional_app_icon_override_if_present() {
  slug=$1
  dest_dir=$2
  override_icon=$(app_icon_override_path "$slug")
  if [ -f "$override_icon" ]; then
    mkdir -p "$dest_dir/assets"
    cp "$override_icon" "$dest_dir/assets/forge-icon.png"
    rm -f "$dest_dir/assets/forge.icns"
  fi
}

manifest_app_exists() {
  root=$1
  slug=$2
  jq -e --arg slug "$slug" '.apps[] | select(.slug == $slug)' "$root/config/apps.manifest.json" >/dev/null 2>&1
}

manifest_template_exists() {
  root=$1
  slug=$2
  jq -e --arg slug "$slug" '.templates[] | select(.slug == $slug)' "$root/config/templates.manifest.json" >/dev/null 2>&1
}

app_distribution() {
  root=$1
  slug=$2
  jq -r --arg slug "$slug" '.apps[] | select(.slug == $slug) | (.distribution // "optional")' "$root/config/apps.manifest.json"
}

template_distribution() {
  root=$1
  slug=$2
  jq -r --arg slug "$slug" '.templates[] | select(.slug == $slug) | (.distribution // "optional")' "$root/config/templates.manifest.json"
}

app_source_field() {
  root=$1
  slug=$2
  key=$3
  jq -r --arg slug "$slug" --arg key "$key" '.apps[] | select(.slug == $slug) | (.source[$key] // "")' "$root/config/apps.manifest.json"
}

template_source_field() {
  root=$1
  slug=$2
  key=$3
  jq -r --arg slug "$slug" --arg key "$key" '.templates[] | select(.slug == $slug) | (.source[$key] // "")' "$root/config/templates.manifest.json"
}

app_hosted_web_mode() {
  root=$1
  slug=$2
  jq -r --arg slug "$slug" '.apps[] | select(.slug == $slug) | (.hostedWeb.mode // "local")' "$root/config/apps.manifest.json"
}

app_hosted_web_path() {
  root=$1
  slug=$2
  jq -r --arg slug "$slug" '.apps[] | select(.slug == $slug) | (.hostedWeb.path // "")' "$root/config/apps.manifest.json"
}

app_cache_dir() {
  slug=$1
  printf '%s\n' "$(forge_catalog_apps_dir)/$slug"
}

template_cache_dir() {
  slug=$1
  printf '%s\n' "$(forge_catalog_templates_dir)/$slug"
}

resolve_app_dir() {
  root=$1
  slug=$2
  distribution=$(app_distribution "$root" "$slug")
  case "$distribution" in
    core)
      dir="$root/apps/$slug"
      [ -d "$dir" ] || return 1
      printf '%s\n' "$dir"
      return 0
      ;;
    optional)
      dir=$(app_cache_dir "$slug")
      [ -d "$dir" ] || return 1
      printf '%s\n' "$dir"
      return 0
      ;;
  esac
  return 1
}

app_status() {
  root=$1
  slug=$2
  distribution=$(app_distribution "$root" "$slug")
  case "$distribution" in
    core)
      path="$root/apps/$slug"
      if [ -d "$path" ]; then
        printf '%s\t%s\n' "core_present" "$path"
      else
        printf '%s\t%s\n' "core_missing" "$path"
      fi
      ;;
    optional)
      path=$(app_cache_dir "$slug")
      if [ -d "$path" ]; then
        printf '%s\t%s\n' "optional_downloaded" "$path"
      else
        printf '%s\t%s\n' "not_downloaded" ""
      fi
      ;;
    *)
      printf '%s\t%s\n' "unknown" ""
      ;;
  esac
}

resolve_template_dir() {
  root=$1
  slug=$2
  distribution=$(template_distribution "$root" "$slug")
  case "$distribution" in
    core)
      dir="$root/web/$slug"
      [ -d "$dir" ] || return 1
      printf '%s\n' "$dir"
      return 0
      ;;
    optional)
      dir=$(template_cache_dir "$slug")
      [ -d "$dir" ] || return 1
      printf '%s\n' "$dir"
      return 0
      ;;
  esac
  return 1
}

template_status() {
  root=$1
  slug=$2
  distribution=$(template_distribution "$root" "$slug")
  case "$distribution" in
    core)
      path="$root/web/$slug"
      if [ -d "$path" ]; then
        printf '%s\t%s\n' "core_present" "$path"
      else
        printf '%s\t%s\n' "core_missing" "$path"
      fi
      ;;
    optional)
      path=$(template_cache_dir "$slug")
      if [ -d "$path" ]; then
        printf '%s\t%s\n' "optional_downloaded" "$path"
      else
        printf '%s\t%s\n' "not_downloaded" ""
      fi
      ;;
    *)
      printf '%s\t%s\n' "unknown" ""
      ;;
  esac
}

resolve_app_dir_or_error() {
  root=$1
  slug=$2
  if path=$(resolve_app_dir "$root" "$slug" 2>/dev/null); then
    printf '%s\n' "$path"
    return 0
  fi
  status_line=$(app_status "$root" "$slug")
  status=$(printf '%s\n' "$status_line" | cut -f1)
  case "$status" in
    not_downloaded)
      printf '%s\n' "forge-backend: app not downloaded: $slug (run download-app)" >&2
      ;;
    core_missing)
      printf '%s\n' "forge-backend: core app directory missing: $root/apps/$slug" >&2
      ;;
    *)
      printf '%s\n' "forge-backend: app not found: $slug" >&2
      ;;
  esac
  exit 1
}

resolve_template_dir_or_error() {
  root=$1
  slug=$2
  if path=$(resolve_template_dir "$root" "$slug" 2>/dev/null); then
    printf '%s\n' "$path"
    return 0
  fi
  status_line=$(template_status "$root" "$slug")
  status=$(printf '%s\n' "$status_line" | cut -f1)
  case "$status" in
    not_downloaded)
      printf '%s\n' "forge-backend: template not downloaded: $slug (run download-template)" >&2
      ;;
    core_missing)
      printf '%s\n' "forge-backend: core template directory missing: $root/web/$slug" >&2
      ;;
    *)
      printf '%s\n' "forge-backend: template not found: $slug" >&2
      ;;
  esac
  exit 1
}

write_source_lock() {
  lock_file=$1
  repo=$2
  ref=$3
  subdir=$4
  commit=$5
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$lock_file" <<EOF
repo=$repo
ref=$ref
subdir=$subdir
commit=$commit
fetched_at=$now
EOF
}

download_into_cache() {
  repo=$1
  ref=$2
  subdir=$3
  dest_dir=$4
  lock_file=$5
  slug=${6-}

  require_tool git
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/forge-catalog.XXXXXX")
  trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

  if ! git clone --depth=1 --branch "$ref" "$repo" "$tmp_dir/repo" >/dev/null 2>&1; then
    rm -rf "$tmp_dir/repo"
    git clone "$repo" "$tmp_dir/repo" >/dev/null 2>&1
    (cd "$tmp_dir/repo" && git checkout "$ref" >/dev/null 2>&1)
  fi

  commit=$(cd "$tmp_dir/repo" && git rev-parse HEAD)
  [ -n "$subdir" ] || subdir=.
  src_dir="$tmp_dir/repo/$subdir"
  [ -d "$src_dir" ] || {
    printf '%s\n' "forge-backend: source subdir not found in repo: $subdir" >&2
    rm -rf "$tmp_dir"
    trap - EXIT HUP INT TERM
    exit 1
  }

  rm -rf "$dest_dir"
  mkdir -p "$(dirname "$dest_dir")"
  cp -R "$src_dir" "$dest_dir"
  if [ -n "$slug" ]; then
    apply_optional_app_icon_override_if_present "$slug" "$dest_dir"
  fi
  write_source_lock "$lock_file" "$repo" "$ref" "$subdir" "$commit"

  rm -rf "$tmp_dir"
  trap - EXIT HUP INT TERM
}

resolve_source_repo() {
  root=$1
  repo=$2
  case "$repo" in
    '' )
      printf '%s\n' ""
      return 0
      ;;
    *://*)
      printf '%s\n' "$repo"
      return 0
      ;;
    /*)
      printf '%s\n' "$repo"
      return 0
      ;;
    *)
      parent=$(dirname "$root/$repo")
      base=$(basename "$root/$repo")
      if abs_parent=$(CDPATH= cd -- "$parent" 2>/dev/null && pwd -P); then
        printf '%s\n' "$abs_parent/$base"
      else
        printf '%s\n' "$root/$repo"
      fi
      return 0
      ;;
  esac
}

lock_field() {
  file=$1
  key=$2
  [ -f "$file" ] || return 1
  awk -F= -v k="$key" '
    $1 == k {
      sub(/^[^=]*=/, "", $0)
      print
      exit
    }
  ' "$file"
}

resolve_source_ref_commit() {
  repo=$1
  ref=$2
  [ -n "$repo" ] || return 1
  [ -n "$ref" ] || ref=HEAD
  require_tool git

  if [ -d "$repo/.git" ] || git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$repo" rev-parse "$ref" 2>/dev/null
    return $?
  fi

  git ls-remote "$repo" "$ref" 2>/dev/null | awk 'NR == 1 { print $1 }'
}

maybe_refresh_optional_app_cache() {
  root=$1
  slug=$2

  distribution=$(app_distribution "$root" "$slug")
  [ "$distribution" = "optional" ] || return 0

  repo=$(app_source_field "$root" "$slug" repo)
  ref=$(app_source_field "$root" "$slug" ref)
  subdir=$(app_source_field "$root" "$slug" subdir)
  [ -n "$repo" ] || return 0
  [ -n "$ref" ] || ref=main
  [ -n "$subdir" ] || subdir=.

  repo=$(resolve_source_repo "$root" "$repo")
  dest_dir=$(app_cache_dir "$slug")
  [ -d "$dest_dir" ] || return 0

  lock_file="$dest_dir/.forge-source.lock"
  if [ ! -f "$lock_file" ]; then
    download_into_cache "$repo" "$ref" "$subdir" "$dest_dir" "$lock_file" "$slug"
    return 0
  fi

  locked_repo=$(lock_field "$lock_file" repo || true)
  locked_ref=$(lock_field "$lock_file" ref || true)
  locked_subdir=$(lock_field "$lock_file" subdir || true)
  locked_commit=$(lock_field "$lock_file" commit || true)
  current_commit=$(resolve_source_ref_commit "$repo" "$ref" 2>/dev/null || true)

  if [ -z "$current_commit" ]; then
    return 0
  fi

  if [ "$locked_repo" != "$repo" ] || [ "$locked_ref" != "$ref" ] || [ "$locked_subdir" != "$subdir" ] || [ "$locked_commit" != "$current_commit" ]; then
    download_into_cache "$repo" "$ref" "$subdir" "$dest_dir" "$lock_file" "$slug"
  fi
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
  host_src="$root/apps/.host/macos/main.m"
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
  host_src="$root/apps/.host/linux/main.c"

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

resolve_workspace_relative_path() {
  workspace_path=$1
  rel_path=$2

  [ -n "$workspace_path" ] || return 1
  [ -n "$rel_path" ] || return 1

  case "$rel_path" in
    /*)
      return 1
      ;;
  esac

  workspace_abs=$(CDPATH= cd -- "$workspace_path" && pwd -P) || return 1
  rel_dir=$(dirname "$rel_path")
  rel_base=$(basename "$rel_path")
  abs_dir=$(CDPATH= cd -- "$workspace_abs/$rel_dir" 2>/dev/null && pwd -P) || return 1
  abs_path="$abs_dir/$rel_base"

  case "$abs_path" in
    "$workspace_abs" | "$workspace_abs"/*)
      printf '%s\n' "$abs_path"
      return 0
      ;;
  esac

  return 1
}

is_valid_wizardry_runtime_dir() {
  wizardry_dir=${1-}
  [ -n "$wizardry_dir" ] || return 1
  [ -x "$wizardry_dir/spells/.imps/sys/env-clear" ] || return 1
  [ -x "$wizardry_dir/spells/web/web-wizardry" ] || return 1
  return 0
}

resolve_runtime_wizardry_dir() {
  inherited=${1-}

  if is_valid_wizardry_runtime_dir "$inherited"; then
    printf '%s\n' "$inherited"
    return 0
  fi

  if is_valid_wizardry_runtime_dir "$HOME/.wizardry"; then
    printf '%s\n' "$HOME/.wizardry"
    return 0
  fi

  if [ -n "$inherited" ]; then
    printf '%s\n' "$inherited"
    return 0
  fi

  printf '%s\n' "$HOME/.wizardry"
  return 0
}

wizardry_spell_path() {
  wizardry_dir=${1-}
  current_path=${2-}

  [ -n "$wizardry_dir" ] || wizardry_dir="$HOME/.wizardry"
  spell_path=$current_path

  for dir in \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    /opt/local/bin \
    /opt/local/sbin \
    /opt/pkg/bin \
    /opt/pkg/sbin \
    /usr/local/bin \
    /usr/local/sbin \
    "$HOME/.local/bin" \
    "$HOME/bin"; do
    [ -d "$dir" ] || continue
    case ":$spell_path:" in
      *":$dir:"*)
        ;;
      *)
        spell_path="$dir:$spell_path"
        ;;
    esac
  done

  if [ -d "$wizardry_dir/spells" ]; then
    for dir in \
      "$wizardry_dir/spells"/* \
      "$wizardry_dir/spells"/.* \
      "$wizardry_dir/spells"/*/* \
      "$wizardry_dir/spells"/.*/*; do
      [ -d "$dir" ] || continue
      case "$dir" in
        */.|*/..|*/.DS_Store)
          continue
          ;;
      esac
      case ":$spell_path:" in
        *":$dir:"*)
          ;;
        *)
          spell_path="$dir:$spell_path"
          ;;
      esac
    done
  fi

  printf '%s\n' "$spell_path"
}

serve_workspace_managed_hosted_web() {
  root=$1
  workspace_path=$2
  workspace_conf=$3
  workspace_slug=$4

  site_name=$(workspace_field "$workspace_conf" hosted_web_site_name "")
  [ -n "$site_name" ] || site_name=$(workspace_field "$workspace_conf" project_id "$workspace_slug")
  validate_site_name "$site_name"

  serve_script_rel=$(workspace_field "$workspace_conf" hosted_web_serve_script "")
  [ -n "$serve_script_rel" ] || {
    printf '%s\n' "forge-backend: hosted_web_serve_script is required for hosted_web_mode=web-wizardry-site" >&2
    return 1
  }

  serve_action=$(workspace_field "$workspace_conf" hosted_web_serve_action "serve")
  serve_script=$(resolve_workspace_relative_path "$workspace_path" "$serve_script_rel") || {
    printf '%s\n' "forge-backend: hosted_web_serve_script must resolve inside the workspace: $serve_script_rel" >&2
    return 1
  }
  [ -f "$serve_script" ] || {
    printf '%s\n' "forge-backend: hosted web serve script not found: $serve_script" >&2
    return 1
  }

  web_root=${WEB_WIZARDRY_ROOT:-$HOME/sites}
  site_dir="$web_root/$site_name"
  web_log="$root/_tmp/workbench/log/hosted-web/$site_name-workspace-web-wizardry.log"
  mkdir -p "$(dirname "$web_log")"

  if ! (
    cd "$workspace_path"
    wizardry_dir=$(resolve_runtime_wizardry_dir "${WIZARDRY_DIR-}")
    PATH=$(wizardry_spell_path "$wizardry_dir" "${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}")
    export PATH
    export WIZARDRY_DIR="$wizardry_dir"
    if [ -x "$serve_script" ]; then
      "$serve_script" "$serve_action" "$site_name"
    else
      sh "$serve_script" "$serve_action" "$site_name"
    fi
  ) >"$web_log" 2>&1; then
    printf '%s\n' "forge-backend: workspace hosted web serve failed (see log: $web_log)" >&2
    return 1
  fi

  site_conf="$site_dir/site.conf"
  [ -f "$site_conf" ] || {
    printf '%s\n' "forge-backend: workspace hosted web site config not found after serve: $site_conf" >&2
    return 1
  }

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
  return 0
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
  printf '%s\n' "local-share"
}

sanitize_bundle_component() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//; s/--*/-/g')
  if [ -z "$cleaned" ]; then
    cleaned=workspace
  fi
  printf '%s\n' "$cleaned"
}

copy_tree_for_bundle() {
  src=${1-}
  dest=${2-}
  [ -d "$src" ] || return 1
  mkdir -p "$dest"
  (
    cd "$src" || exit 1
    tar \
      --exclude '.git' \
      --exclude '*/.git' \
      --exclude '.assay-runs' \
      --exclude '*/.assay-runs' \
      --exclude '.assay-reports' \
      --exclude '*/.assay-reports' \
      --exclude '.DS_Store' \
      --exclude 'target' \
      --exclude '*/target' \
      --exclude 'node_modules' \
      --exclude '*/node_modules' \
      -cf - .
  ) | (
    cd "$dest" || exit 1
    tar -xf -
  )
}

copy_macos_bundle() {
  src_bundle=${1-}
  dest_bundle=${2-}
  [ -d "$src_bundle" ] || return 1
  [ -n "$dest_bundle" ] || return 1
  rm -rf "$dest_bundle"
  if command -v ditto >/dev/null 2>&1; then
    ditto "$src_bundle" "$dest_bundle" || return 1
  else
    cp -R "$src_bundle" "$dest_bundle" || return 1
  fi
  touch "$dest_bundle" >/dev/null 2>&1 || :
  touch "$dest_bundle/Contents/Info.plist" >/dev/null 2>&1 || :
  return 0
}

sync_existing_macos_installs_from_bundle() {
  bundle_path=${1-}
  app_name=${2-}
  [ -d "$bundle_path" ] || return 1
  [ -n "$app_name" ] || return 1

  synced_path=''
  for candidate in "/Applications/$app_name.app" "$HOME/Applications/$app_name.app"; do
    [ -d "$candidate" ] || continue
    if copy_macos_bundle "$bundle_path" "$candidate"; then
      [ -n "$synced_path" ] || synced_path="$candidate"
    fi
  done

  [ -n "$synced_path" ] || return 1
  printf '%s\n' "$synced_path"
}

sync_macos_install_for_slug() {
  root=${1-}
  slug=${2-}
  [ -n "$root" ] || return 1
  [ -n "$slug" ] || return 1
  [ "$(os_id)" = "darwin" ] || return 1

  app_name=$(app_name_from_manifest "$root" "$slug")
  has_install=0
  for candidate in "/Applications/$app_name.app" "$HOME/Applications/$app_name.app"; do
    if [ -d "$candidate" ]; then
      has_install=1
      break
    fi
  done
  [ "$has_install" -eq 1 ] || return 1

  build_out=$(cmd_build_desktop "$root" "$slug" 2>/dev/null || true)
  bundle_path=$(printf '%s\n' "$build_out" | kv_read artifact)
  [ -n "$bundle_path" ] || return 1
  sync_existing_macos_installs_from_bundle "$bundle_path" "$app_name"
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
      | awk -v app="$app_dir" '
          index($0, app) > 0 && index($0, "wizardry-host") > 0 { print $1 }
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
      | awk -v app="$app_dir" '
          index($0, app) > 0 && index($0, "wizardry-host") > 0 { print $1 }
        ' \
      | tr '\n' ' ' \
      | sed 's/[[:space:]]*$//'
  )
  if [ -n "$still" ]; then
    # shellcheck disable=SC2086
    kill -9 $still >/dev/null 2>&1 || true
  fi
}

workspace_host_running_for_app_dir() {
  app_dir=${1-}
  [ -n "$app_dir" ] || return 1
  command -v ps >/dev/null 2>&1 || return 1
  ps -axo command= 2>/dev/null \
    | awk -v app="$app_dir" '
        index($0, app) > 0 && index($0, "wizardry-host") > 0 { found=1; exit }
        END { if (found) exit 0; exit 1 }
      '
}

wait_for_workspace_host_start() {
  app_dir=${1-}
  attempts=${2-}
  [ -n "$app_dir" ] || return 1
  [ -n "$attempts" ] || attempts=20
  i=0
  while [ "$i" -lt "$attempts" ]; do
    if workspace_host_running_for_app_dir "$app_dir"; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.2
  done
  return 1
}

launch_workspace_bundle_macos() {
  bundle=${1-}
  launcher_exec=${2-}
  app_dir=${3-}
  [ -d "$bundle" ] || return 1
  [ -n "$app_dir" ] || return 1

  if command -v open >/dev/null 2>&1; then
    if open -na "$bundle" >/dev/null 2>&1; then
      if wait_for_workspace_host_start "$app_dir" 25; then
        return 0
      fi
    fi
  fi

  [ -x "$launcher_exec" ] || return 1
  if command -v nohup >/dev/null 2>&1; then
    nohup "$launcher_exec" >/dev/null 2>&1 &
  else
    "$launcher_exec" >/dev/null 2>&1 &
  fi
  wait_for_workspace_host_start "$app_dir" 25
}

stop_desktop_instances_for_slug() {
  root=${1-}
  slug=${2-}
  app_name=${3-}
  os_name=${4-}

  [ -n "$slug" ] || return 0

  if [ "$os_name" = "darwin" ] && [ -n "$app_name" ] && command -v osascript >/dev/null 2>&1; then
    osascript \
      -e "if application \"$app_name\" is running then" \
      -e "tell application \"$app_name\" to quit" \
      -e "end if" >/dev/null 2>&1 || true
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
  jq -r '.apps[] | [.slug, .name, (if .production then "true" else "false" end), ((.bundleIds // {}) | keys | join(",")), (if has("targets") then (.targets // "") else "__FORGE_TARGETS_MISSING__" end), (.distribution // "optional")] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r slug name production bundle_targets manifest_targets distribution; do
    status_line=$(app_status "$root" "$slug")
    resolved_status=$(printf '%s\n' "$status_line" | cut -f1)
    resolved_path=$(printf '%s\n' "$status_line" | cut -f2)
    exists=0
    case "$resolved_status" in
      core_present|optional_downloaded)
        exists=1
        ;;
    esac
    development_context=web
    if [ "$distribution" = "core" ] && [ -d "$root/godot/tools/$slug" ]; then
      development_context=godot
    fi

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
      if [ -d "$root/web/$slug" ]; then
        targets="hosted-web,$targets"
      fi
    fi

    mtime_epoch=$(path_mtime_epoch "$resolved_path")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slug" "$name" "$production" "$exists" "$development_context" "$targets" "$distribution" "$resolved_status" "$resolved_path" "$mtime_epoch"
  done
}

cmd_list_templates() {
  root=$(require_root "${1-}")
  require_jq

  manifest="$root/config/templates.manifest.json"
  jq -r '.templates[] | [.slug, (if .publish then "true" else "false" end), (.distribution // "optional")] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r slug publish distribution; do
    status_line=$(template_status "$root" "$slug")
    resolved_status=$(printf '%s\n' "$status_line" | cut -f1)
    resolved_path=$(printf '%s\n' "$status_line" | cut -f2)
    exists=0
    case "$resolved_status" in
      core_present|optional_downloaded)
        exists=1
        ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$slug" "$publish" "$exists" "$distribution" "$resolved_status" "$resolved_path"
  done
}

cmd_app_status() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: app-status requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }

  distribution=$(app_distribution "$root" "$slug")
  status_line=$(app_status "$root" "$slug")
  resolved_status=$(printf '%s\n' "$status_line" | cut -f1)
  resolved_path=$(printf '%s\n' "$status_line" | cut -f2)
  repo=$(app_source_field "$root" "$slug" repo)
  ref=$(app_source_field "$root" "$slug" ref)
  [ -n "$ref" ] || ref=main
  subdir=$(app_source_field "$root" "$slug" subdir)
  [ -n "$subdir" ] || subdir=.

  printf 'slug=%s\n' "$slug"
  printf 'distribution=%s\n' "$distribution"
  printf 'status=%s\n' "$resolved_status"
  [ -n "$resolved_path" ] && printf 'path=%s\n' "$resolved_path"
  [ -n "$repo" ] && printf 'repo=%s\n' "$repo"
  printf 'ref=%s\n' "$ref"
  printf 'subdir=%s\n' "$subdir"
}

cmd_template_status() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: template-status requires TEMPLATE_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq
  manifest_template_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: template not found in manifest: $slug" >&2
    exit 1
  }

  distribution=$(template_distribution "$root" "$slug")
  status_line=$(template_status "$root" "$slug")
  resolved_status=$(printf '%s\n' "$status_line" | cut -f1)
  resolved_path=$(printf '%s\n' "$status_line" | cut -f2)
  repo=$(template_source_field "$root" "$slug" repo)
  ref=$(template_source_field "$root" "$slug" ref)
  [ -n "$ref" ] || ref=main
  subdir=$(template_source_field "$root" "$slug" subdir)
  [ -n "$subdir" ] || subdir=.

  printf 'slug=%s\n' "$slug"
  printf 'distribution=%s\n' "$distribution"
  printf 'status=%s\n' "$resolved_status"
  [ -n "$resolved_path" ] && printf 'path=%s\n' "$resolved_path"
  [ -n "$repo" ] && printf 'repo=%s\n' "$repo"
  printf 'ref=%s\n' "$ref"
  printf 'subdir=%s\n' "$subdir"
}

cmd_download_app() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: download-app requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }

  distribution=$(app_distribution "$root" "$slug")
  [ "$distribution" = "optional" ] || {
    printf '%s\n' "forge-backend: app is core; download-app only applies to optional apps: $slug" >&2
    exit 1
  }
  repo=$(app_source_field "$root" "$slug" repo)
  ref=$(app_source_field "$root" "$slug" ref)
  subdir=$(app_source_field "$root" "$slug" subdir)
  [ -n "$repo" ] || {
    printf '%s\n' "forge-backend: optional app missing source.repo: $slug" >&2
    exit 1
  }
  [ -n "$ref" ] || ref=main
  [ -n "$subdir" ] || subdir=.
  repo=$(resolve_source_repo "$root" "$repo")

  dest_dir=$(app_cache_dir "$slug")
  lock_file="$dest_dir/.forge-source.lock"
  download_into_cache "$repo" "$ref" "$subdir" "$dest_dir" "$lock_file" "$slug"
  printf 'slug=%s\n' "$slug"
  printf 'downloaded=%s\n' "$dest_dir"
  printf 'lock=%s\n' "$lock_file"
}

cmd_remove_downloaded_app() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: remove-downloaded-app requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }

  distribution=$(app_distribution "$root" "$slug")
  [ "$distribution" = "optional" ] || {
    printf '%s\n' "forge-backend: app is core; remove-downloaded-app only applies to optional apps: $slug" >&2
    exit 1
  }
  dest_dir=$(app_cache_dir "$slug")
  rm -rf "$dest_dir"
  printf 'slug=%s\n' "$slug"
  printf 'removed=%s\n' "$dest_dir"
}

cmd_download_template() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: download-template requires TEMPLATE_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq
  manifest_template_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: template not found in manifest: $slug" >&2
    exit 1
  }

  distribution=$(template_distribution "$root" "$slug")
  [ "$distribution" = "optional" ] || {
    printf '%s\n' "forge-backend: template is core; download-template only applies to optional templates: $slug" >&2
    exit 1
  }
  repo=$(template_source_field "$root" "$slug" repo)
  ref=$(template_source_field "$root" "$slug" ref)
  subdir=$(template_source_field "$root" "$slug" subdir)
  [ -n "$repo" ] || {
    printf '%s\n' "forge-backend: optional template missing source.repo: $slug" >&2
    exit 1
  }
  [ -n "$ref" ] || ref=main
  [ -n "$subdir" ] || subdir=.
  repo=$(resolve_source_repo "$root" "$repo")

  dest_dir=$(template_cache_dir "$slug")
  lock_file="$dest_dir/.forge-source.lock"
  download_into_cache "$repo" "$ref" "$subdir" "$dest_dir" "$lock_file"
  printf 'slug=%s\n' "$slug"
  printf 'downloaded=%s\n' "$dest_dir"
  printf 'lock=%s\n' "$lock_file"
}

cmd_remove_downloaded_template() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: remove-downloaded-template requires TEMPLATE_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  require_jq
  manifest_template_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: template not found in manifest: $slug" >&2
    exit 1
  }

  distribution=$(template_distribution "$root" "$slug")
  [ "$distribution" = "optional" ] || {
    printf '%s\n' "forge-backend: template is core; remove-downloaded-template only applies to optional templates: $slug" >&2
    exit 1
  }
  dest_dir=$(template_cache_dir "$slug")
  rm -rf "$dest_dir"
  printf 'slug=%s\n' "$slug"
  printf 'removed=%s\n' "$dest_dir"
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
  theme_root="$root/web/.themes"
  app_theme_dir="$root/apps/forge/themes"

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

expand_user_path() {
  path=${1-}
  case "$path" in
    "~")
      path=$HOME
      ;;
    "~/"*)
      path=$HOME/${path#~/}
      ;;
  esac
  printf '%s\n' "$path"
}

resolve_existing_dir_path() {
  path=$(expand_user_path "${1-}")
  [ -d "$path" ] || return 1
  (CDPATH= cd -- "$path" && pwd -P)
}

ensure_dir_path() {
  path=$(expand_user_path "${1-}")
  mkdir -p "$path"
  (CDPATH= cd -- "$path" && pwd -P)
}

derive_workspace_slug() {
  name=${1-}
  slug=$(printf '%s' "$name" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '-' \
    | sed 's/^-*//; s/-*$//; s/-\{2,\}/-/g')
  [ -n "$slug" ] || slug=workspace
  case "$slug" in
    [a-z]*)
      ;;
    *)
      slug="w-$slug"
      ;;
  esac
  printf '%s\n' "$slug"
}

resolve_workspace_slug() {
  conf_path=${1-}
  workspace_path=${2-}
  project_id=$(workspace_field "$conf_path" project_id "")
  if [ -n "$project_id" ]; then
    case "$project_id" in
      [a-z][a-z0-9-]*)
        case "$project_id" in
          *-|*--*)
            project_id=""
            ;;
        esac
        ;;
      *)
        project_id=""
        ;;
    esac
  fi
  [ -n "$project_id" ] || project_id=$(derive_workspace_slug "$(basename "$workspace_path")")
  printf '%s\n' "$project_id"
}

ensure_importable_workspace_profile() {
  workspace_path=${1-}
  conf_path="$workspace_path/wizardry.workspace.conf"
  if [ -f "$conf_path" ]; then
    printf '%s\t%s\n' "$conf_path" "0"
    return 0
  fi

  if [ ! -w "$workspace_path" ]; then
    printf '%s\n' "forge-backend: workspace profile missing and workspace is not writable: $workspace_path" >&2
    exit 1
  fi

  context=""
  project_type=""
  targets=""
  starter="import"
  profile_kind="detected"
  if [ -f "$workspace_path/project.godot" ] || [ -f "$workspace_path/game/project.godot" ] || [ -f "$workspace_path/tool_main.gd" ]; then
    context="godot"
    project_type="game"
    targets="macos,linux,godot-desktop"
    starter="import-godot"
  elif [ -f "$workspace_path/app/index.html" ] || [ -f "$workspace_path/index.html" ]; then
    context="web"
    project_type="application"
    targets="hosted-web,macos,linux"
    starter="import-web"
  else
    # Allow importing arbitrary repositories/folders so they appear in Forge.
    # Keep targets empty until the user enables the ones they want.
    context="web"
    project_type="application"
    targets=""
    starter="import-generic"
    profile_kind="generic"
  fi

  project_id=$(derive_workspace_slug "$(basename "$workspace_path")")
  project_title=$(basename "$workspace_path")
  cat > "$conf_path" <<CONF
# Wizardry Apps workspace profile
project_id=$project_id
title=$project_title
project_type=$project_type
development_context=$context
starter=$starter
profile_kind=$profile_kind
targets=$targets
root=$workspace_path
CONF

  printf '%s\t%s\n' "$conf_path" "1"
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

    project_type=$(workspace_field "$conf" project_type "application")

    development_context=$(workspace_field "$conf" development_context "web")

    targets=$(workspace_field "$conf" targets "")
    runnable=0
    case "$development_context" in
      godot)
        if [ -f "$path/project.godot" ] || [ -f "$path/game/project.godot" ] || [ -f "$path/tool_main.gd" ]; then
          runnable=1
        fi
        ;;
      *)
        if [ -f "$path/app/index.html" ] || [ -f "$path/index.html" ]; then
          runnable=1
        fi
        ;;
    esac
    mtime_epoch=$(path_mtime_epoch "$path")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$project_id" "$title" "$project_type" "$development_context" "$targets" "$path" "$mtime_epoch" "$runnable"
  done | sort
}

cmd_import_workspace() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  project_root=${3-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: import-workspace requires WORKSPACE_PATH" >&2
    exit 2
  }

  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
    exit 1
  }

  [ -n "$project_root" ] || project_root=$(workspace_default_root)
  project_root_abs=$(ensure_dir_path "$project_root")

  profile_meta=$(ensure_importable_workspace_profile "$workspace_abs")
  profile_path=$(printf '%s\n' "$profile_meta" | cut -f1)
  profile_created=$(printf '%s\n' "$profile_meta" | cut -f2)
  workspace_id=$(resolve_workspace_slug "$profile_path" "$workspace_abs")
  registration_mode="linked"
  registered_path=""

  workspace_parent=$(dirname "$workspace_abs")
  if [ "$workspace_parent" = "$project_root_abs" ]; then
    registration_mode="direct"
    registered_path="$workspace_abs"
  else
    candidate_base="$project_root_abs/$workspace_id"
    candidate_path="$candidate_base"
    suffix=2
    while :; do
      if [ -e "$candidate_path" ] || [ -L "$candidate_path" ]; then
        if [ -d "$candidate_path" ]; then
          existing_target=$(resolve_existing_dir_path "$candidate_path" 2>/dev/null || true)
          if [ -n "$existing_target" ] && [ "$existing_target" = "$workspace_abs" ]; then
            registered_path="$candidate_path"
            break
          fi
        fi
        candidate_path="$candidate_base-$suffix"
        suffix=$((suffix + 1))
        continue
      fi
      ln -s "$workspace_abs" "$candidate_path"
      registered_path="$candidate_path"
      break
    done
  fi

  [ -n "$registered_path" ] || {
    printf '%s\n' "forge-backend: failed to register workspace: $workspace_abs" >&2
    exit 1
  }

  [ -f "$registered_path/wizardry.workspace.conf" ] || {
    printf '%s\n' "forge-backend: registered workspace is missing wizardry.workspace.conf: $registered_path" >&2
    exit 1
  }

  printf 'workspace=%s\n' "$workspace_abs"
  printf 'registered_path=%s\n' "$registered_path"
  printf 'project_root=%s\n' "$project_root_abs"
  printf 'project_id=%s\n' "$workspace_id"
  printf 'mode=%s\n' "$registration_mode"
  printf 'profile=%s\n' "$profile_path"
  printf 'profile_created=%s\n' "$profile_created"
  printf 'root=%s\n' "$root"
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

cmd_rename_workspace() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  title=${3-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: rename-workspace requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
    exit 1
  }
  [ -n "$title" ] || {
    printf '%s\n' "forge-backend: rename-workspace requires NEW_TITLE" >&2
    exit 2
  }

  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
    exit 1
  }

  conf="$workspace_abs/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: workspace profile missing: $workspace_abs" >&2
    exit 1
  }

  cleaned_title=$(printf '%s' "$title" | tr '\r\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$cleaned_title" ] || {
    printf '%s\n' "forge-backend: rename-workspace requires a non-empty NEW_TITLE" >&2
    exit 2
  }

  old_path="$workspace_abs"
  parent_dir=$(dirname "$workspace_abs")
  new_slug=$(derive_workspace_slug "$cleaned_title")
  target_path="$parent_dir/$new_slug"
  moved=0

  if [ "$workspace_abs" != "$target_path" ]; then
    [ ! -e "$target_path" ] || {
      printf '%s\n' "forge-backend: workspace path already exists: $target_path" >&2
      exit 1
    }
    mv "$workspace_abs" "$target_path"
    moved=1
  fi

  conf="$target_path/wizardry.workspace.conf"
  write_key_value_file "$conf" title "$cleaned_title"
  write_key_value_file "$conf" project_id "$new_slug"
  write_key_value_file "$conf" root "$target_path"

  printf 'root=%s\n' "$root"
  printf 'workspace=%s\n' "$target_path"
  printf 'old_workspace=%s\n' "$old_path"
  printf 'title=%s\n' "$cleaned_title"
  printf 'project_id=%s\n' "$new_slug"
  printf 'moved=%s\n' "$moved"
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
  legacy_icns_path="$project_dir/assets/forge.icns"
  mkdir -p "$(dirname "$icon_path")"

  if [ -z "$data_url" ]; then
    rm -f "$icon_path"
    rm -f "$legacy_icns_path"
    printf 'icon=%s\n' "$icon_path"
    printf 'status=cleared\n'
    return 0
  fi

  case "$data_url" in
    data:image/png\;base64,*)
      payload=${data_url#data:image/png;base64,}
      image_ext=png
      ;;
    data:image/*\;base64,*)
      image_type=${data_url#data:image/}
      image_type=${image_type%%;base64,*}
      payload=${data_url#data:image/}
      payload=${payload#*;base64,}
      case "$image_type" in
        png) image_ext=png ;;
        jpeg|jpg) image_ext=jpg ;;
        webp) image_ext=webp ;;
        gif) image_ext=gif ;;
        bmp) image_ext=bmp ;;
        tiff) image_ext=tiff ;;
        svg+xml) image_ext=svg ;;
        *) image_ext=img ;;
      esac
      ;;
    *)
      printf '%s\n' "forge-backend: icon payload must be a base64 image data URL" >&2
      exit 2
      ;;
  esac

  tmp_icon_base=$(mktemp "${TMPDIR:-/tmp}/app-forge-icon.XXXXXX")
  tmp_icon="$tmp_icon_base.$image_ext"
  mv "$tmp_icon_base" "$tmp_icon"
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

  normalized_icon=$tmp_icon
  if command -v sips >/dev/null 2>&1; then
    resized_icon_base=$(mktemp "${TMPDIR:-/tmp}/app-forge-icon-resized.XXXXXX")
    resized_icon="$resized_icon_base.png"
    rm -f "$resized_icon"
    if sips -z 1024 1024 "$tmp_icon" --out "$resized_icon" >/dev/null 2>&1; then
      normalized_icon=$resized_icon
    else
      rm -f "$resized_icon"
    fi
  fi

  mv "$normalized_icon" "$icon_path"
  [ "$normalized_icon" = "$tmp_icon" ] || rm -f "$tmp_icon"
  # A user-selected icon should always win. Remove stale handcrafted ICNS files
  # that would otherwise mask the new PNG in desktop bundle generation.
  rm -f "$legacy_icns_path"
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
  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }
  app_dir=$(resolve_app_dir_or_error "$root" "$slug")
  distribution=$(app_distribution "$root" "$slug")
  override_icon=''
  if [ "$distribution" = "optional" ]; then
    override_icon=$(app_icon_override_path "$slug")
  fi

  if [ "$distribution" = "optional" ] && [ -z "${data_url-}" ]; then
    rm -f "$override_icon"
    cmd_download_app "$root" "$slug" >/dev/null
    synced_install=$(sync_macos_install_for_slug "$root" "$slug" 2>/dev/null || true)
    printf 'icon=%s\n' "$override_icon"
    printf 'status=cleared\n'
    [ -n "$synced_install" ] && printf 'installed_synced=%s\n' "$synced_install"
    printf 'slug=%s\n' "$slug"
    return 0
  fi

  write_project_icon_from_data_url "$app_dir" "$data_url"
  if [ "$distribution" = "optional" ] && [ -n "$override_icon" ] && [ -f "$app_dir/assets/forge-icon.png" ]; then
    mkdir -p "$(dirname "$override_icon")"
    cp "$app_dir/assets/forge-icon.png" "$override_icon"
  fi
  synced_install=$(sync_macos_install_for_slug "$root" "$slug" 2>/dev/null || true)
  [ -n "$synced_install" ] && printf 'installed_synced=%s\n' "$synced_install"
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
  workspace_app_dir="$workspace_path/app"
  if [ -f "$workspace_app_dir/index.html" ]; then
    # Keep workspace root and nested app icon assets synchronized so runtime,
    # splash, and bundle icon resolution cannot diverge.
    write_project_icon_from_data_url "$workspace_app_dir" "$data_url" >/dev/null
  fi
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

  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }
  maybe_refresh_optional_app_cache "$root" "$slug"
  app_dir=$(resolve_app_dir_or_error "$root" "$slug")

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
      hash_path="$bundle/Contents/Resources/wizardry-build-input.sha256"
      expected_hash=$(desktop_build_input_hash "$root" "$slug" "$app_dir" darwin)
      cache_hit=false

      if [ -d "$bundle" ] &&
         [ -x "$bundle/Contents/MacOS/wizardry-host" ] &&
         [ -x "$bundle/Contents/MacOS/$slug" ] &&
         [ -f "$bundle/Contents/Resources/wizardry-apps-root.txt" ] &&
         [ -f "$hash_path" ]; then
        cached_hash=$(head -n 1 "$hash_path" 2>/dev/null | tr -d '\r')
        cached_root=$(head -n 1 "$bundle/Contents/Resources/wizardry-apps-root.txt" 2>/dev/null | tr -d '\r')
        if [ "$cached_hash" = "$expected_hash" ] && [ "$cached_root" = "$root" ]; then
          cache_hit=true
        fi
      fi

      if [ "$cache_hit" = false ]; then
        rm -rf "$bundle"
        mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/$slug" "$bundle/Contents/Resources/.host" "$bundle/Contents/Resources/wizardry-apps/core"

        copy_tree_for_bundle "$app_dir" "$bundle/Contents/Resources/$slug/"
        mkdir -p "$bundle/Contents/Resources/$slug/.host"
        cp -R "$root/apps/.host/shared" "$bundle/Contents/Resources/$slug/.host/"
        cp -R "$root/apps/.host/shared" "$bundle/Contents/Resources/.host/"
        printf '%s\n' "$root" > "$bundle/Contents/Resources/wizardry-apps-root.txt"
        printf '%s\n' "$expected_hash" > "$hash_path"
        cp -R "$root/core/include" "$bundle/Contents/Resources/wizardry-apps/core/"
        cp -R "$root/core/src" "$bundle/Contents/Resources/wizardry-apps/core/"
        cp "$host_bin" "$bundle/Contents/MacOS/wizardry-host"

        cat > "$bundle/Contents/MacOS/$slug" <<APP
#!/bin/sh
set -eu
APPDIR=\$(CDPATH= cd -- "\$(dirname "\$0")/.." && pwd -P)
exec env WIZARDRY_DIR="$root" WIZARDRY_APPS_ROOT="$root" "\$APPDIR/MacOS/wizardry-host" "\$APPDIR/Resources/$slug"
APP
        chmod +x "$bundle/Contents/MacOS/$slug"

        icon_source=''
        icon_source_format=''
        icon_override=$(app_icon_override_path "$slug")
        if [ -f "$icon_override" ]; then
          icon_source="$icon_override"
          icon_source_format='png'
        elif [ -f "$app_dir/assets/forge-icon.png" ]; then
          icon_source="$app_dir/assets/forge-icon.png"
          icon_source_format='png'
        elif [ -f "$app_dir/assets/forge.icns" ]; then
          icon_source="$app_dir/assets/forge.icns"
          icon_source_format='icns'
        fi

        icon_key=''
        icon_hash=''
        if [ -n "$icon_source" ]; then
          icon_hash=$(hash_path_sha256 "$icon_source")
        fi
        if [ "$icon_source_format" = 'png' ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
          iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-iconset.XXXXXX")
          iconset="${iconset_tmp}.iconset"
          mv "$iconset_tmp" "$iconset"
          for size in 16 32 128 256 512; do
            sips -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
            sips -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
          done
          icon_name="forge-${icon_hash}.icns"
          if iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/$icon_name" >/dev/null 2>&1; then
            icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
          else
            icon_name="forge-icon-${icon_hash}.png"
            cp "$icon_source" "$bundle/Contents/Resources/$icon_name"
            icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
          fi
          rm -rf "$iconset"
        elif [ "$icon_source_format" = 'png' ]; then
          icon_name="forge-icon-${icon_hash}.png"
          cp "$icon_source" "$bundle/Contents/Resources/$icon_name"
          icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
        elif [ "$icon_source_format" = 'icns' ]; then
          icon_name="forge-${icon_hash}.icns"
          cp "$icon_source" "$bundle/Contents/Resources/$icon_name"
          icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
        fi
        if [ -n "${icon_name-}" ] && [ "${icon_name##*.}" = "icns" ]; then
          icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
        fi

        bundle_version=$(printf '%s' "$expected_hash" | cksum | awk '{ print $1 }')
        [ -n "$bundle_version" ] || bundle_version=1

        cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$app_name</string>
<key>CFBundleDisplayName</key><string>$app_name</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>$bundle_version</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>$slug</string>
$icon_key
</dict></plist>
PLIST
      fi

      if command -v ditto >/dev/null 2>&1; then
        if [ "$cache_hit" = false ] || [ ! -f "$zip_path" ]; then
          rm -f "$zip_path"
        fi
        if [ ! -f "$zip_path" ] && ! ditto -c -k --sequesterRsrc --keepParent "$bundle" "$zip_path"; then
          zip_path=''
        fi
      else
        zip_path=''
      fi

      printf 'app_name=%s\n' "$app_name"
      printf 'host=%s\n' "$host_bin"
      printf 'artifact=%s\n' "$bundle"
      printf 'cache=%s\n' "$([ "$cache_hit" = true ] && printf hit || printf miss)"
      [ -n "$zip_path" ] && printf 'zip=%s\n' "$zip_path"
      ;;

    linux)
      host_bin=$(ensure_linux_host "$root")
      dist_dir="$root/_tmp/workbench/dist/linux"
      appdir="$dist_dir/AppDir-$slug"
      artifact=''
      hash_path="$appdir/usr/share/wizardry-build-input.sha256"
      expected_hash=$(desktop_build_input_hash "$root" "$slug" "$app_dir" linux)
      cache_hit=false

      if [ -d "$appdir" ] &&
         [ -x "$appdir/usr/bin/wizardry-host" ] &&
         [ -x "$appdir/AppRun" ] &&
         [ -f "$appdir/usr/share/wizardry-apps-root.txt" ] &&
         [ -f "$hash_path" ]; then
        cached_hash=$(head -n 1 "$hash_path" 2>/dev/null | tr -d '\r')
        cached_root=$(head -n 1 "$appdir/usr/share/wizardry-apps-root.txt" 2>/dev/null | tr -d '\r')
        if [ "$cached_hash" = "$expected_hash" ] && [ "$cached_root" = "$root" ]; then
          cache_hit=true
        fi
      fi

      if [ "$cache_hit" = false ]; then
        rm -rf "$appdir"
        mkdir -p "$appdir/usr/bin" "$appdir/usr/share/$slug" "$appdir/usr/share/.host" "$appdir/usr/share/wizardry-apps/core"

        copy_tree_for_bundle "$app_dir" "$appdir/usr/share/$slug/"
        icon_override=$(app_icon_override_path "$slug")
        linux_icon_source=''
        if [ -f "$icon_override" ]; then
          linux_icon_source="$icon_override"
        elif [ -f "$app_dir/assets/forge-icon.png" ]; then
          linux_icon_source="$app_dir/assets/forge-icon.png"
        fi
        if [ -n "$linux_icon_source" ]; then
          mkdir -p "$appdir/usr/share/$slug/assets"
          cp "$linux_icon_source" "$appdir/usr/share/$slug/assets/forge-icon.png"
        fi
        mkdir -p "$appdir/usr/share/$slug/.host"
        cp -R "$root/apps/.host/shared" "$appdir/usr/share/$slug/.host/"
        cp -R "$root/apps/.host/shared" "$appdir/usr/share/.host/"
        printf '%s\n' "$root" > "$appdir/usr/share/wizardry-apps-root.txt"
        printf '%s\n' "$expected_hash" > "$hash_path"
        cp -R "$root/core/include" "$appdir/usr/share/wizardry-apps/core/"
        cp -R "$root/core/src" "$appdir/usr/share/wizardry-apps/core/"
        cp "$host_bin" "$appdir/usr/bin/wizardry-host"

        cat > "$appdir/AppRun" <<APP
#!/bin/sh
set -eu
HERE=\$(CDPATH= cd -- "\$(dirname "\$0")" && pwd -P)
exec env WIZARDRY_DIR="$root" WIZARDRY_APPS_ROOT="$root" "\$HERE/usr/bin/wizardry-host" "\$HERE/usr/share/$slug"
APP
        chmod +x "$appdir/AppRun"
      fi

      if command -v appimagetool >/dev/null 2>&1; then
        mkdir -p "$dist_dir"
        if [ "$cache_hit" = false ] || [ ! -f "$dist_dir/wizardry-$slug-x86_64.AppImage" ]; then
          ARCH=x86_64 appimagetool "$appdir" "$dist_dir/wizardry-$slug-x86_64.AppImage" >/dev/null 2>&1
        fi
        artifact="$dist_dir/wizardry-$slug-x86_64.AppImage"
      else
        mkdir -p "$dist_dir"
        tar_path="$dist_dir/wizardry-$slug-linux.tar.gz"
        if [ "$cache_hit" = false ] || [ ! -f "$tar_path" ]; then
          rm -f "$tar_path"
          (cd "$dist_dir" && tar -czf "$tar_path" "AppDir-$slug")
        fi
        artifact="$tar_path"
      fi

      printf 'app_name=%s\n' "$slug"
      printf 'host=%s\n' "$host_bin"
      printf 'appdir=%s\n' "$appdir"
      printf 'artifact=%s\n' "$artifact"
      printf 'cache=%s\n' "$([ "$cache_hit" = true ] && printf hit || printf miss)"
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

      printf 'status=ok\n'
      printf 'target=linux\n'
      printf 'install_mode=%s\n' "$(normalize_linux_install_mode)"
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
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: run-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"

  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }
  build_out=$(cmd_build_desktop "$root" "$slug")
  bundle_artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
  appdir=$(printf '%s\n' "$build_out" | kv_read appdir)
  [ -n "$bundle_artifact" ] || {
    printf '%s\n' "forge-backend: build-desktop did not return an artifact" >&2
    exit 1
  }

  os=$(os_id)
  case "$os" in
    darwin)
      app_name=$(app_name_from_manifest "$root" "$slug")
      stop_desktop_instances_for_slug "$root" "$slug" "$app_name" "$os"
      [ -d "$bundle_artifact" ] || {
        printf '%s\n' "forge-backend: built bundle artifact missing: $bundle_artifact" >&2
        exit 1
      }
      launch_bundle="$bundle_artifact"
      synced_install=$(sync_existing_macos_installs_from_bundle "$bundle_artifact" "$app_name" 2>/dev/null || true)
      if [ -n "$synced_install" ] && [ -d "$synced_install" ]; then
        launch_bundle="$synced_install"
      fi
      command -v open >/dev/null 2>&1 || {
        printf '%s\n' "forge-backend: open command not available on this system" >&2
        exit 1
      }
      open -na "$launch_bundle"
      printf 'launched=1\n'
      printf 'mode=desktop-executable\n'
      printf 'artifact=%s\n' "$launch_bundle"
      printf 'built_artifact=%s\n' "$bundle_artifact"
      [ -n "$synced_install" ] && printf 'installed_synced=%s\n' "$synced_install"
      exit 0
      ;;
    linux)
      stop_desktop_instances_for_slug "$root" "$slug" "" "$os"
      [ -n "$appdir" ] || {
        printf '%s\n' "forge-backend: build-desktop did not return AppDir for Linux run" >&2
        exit 1
      }
      [ -d "$appdir" ] || {
        printf '%s\n' "forge-backend: Linux AppDir not found: $appdir" >&2
        exit 1
      }
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac

  log_dir="$root/_tmp/workbench/log"
  mkdir -p "$log_dir"
  log_path="$log_dir/$slug-run.log"

  if command -v nohup >/dev/null 2>&1; then
    case "$bundle_artifact" in
      *.AppImage)
        nohup "$bundle_artifact" >"$log_path" 2>&1 &
        ;;
      *)
        nohup "$appdir/AppRun" >"$log_path" 2>&1 &
        ;;
    esac
  else
    case "$bundle_artifact" in
      *.AppImage)
        "$bundle_artifact" >"$log_path" 2>&1 &
        ;;
      *)
        "$appdir/AppRun" >"$log_path" 2>&1 &
        ;;
    esac
  fi
  pid=$!

  printf 'launched=1\n'
  printf 'mode=desktop-executable\n'
  printf 'entry=%s\n' "$appdir"
  printf 'artifact=%s\n' "$bundle_artifact"
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
  fi
  [ -n "$context" ] || context=web

  case "$context" in
    godot)
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
    web)
      ;;
    *)
      printf '%s\n' "forge-backend: workspace context must be web or godot" >&2
      exit 2
      ;;
  esac

  app_dir="$workspace_path/app"
  if [ ! -f "$app_dir/index.html" ] && [ -f "$workspace_path/index.html" ]; then
    app_dir="$workspace_path"
  fi
  if [ ! -f "$app_dir/index.html" ]; then
    printf '%s\n' "forge-backend: workspace app index not found: $workspace_path" >&2
    exit 1
  fi
  app_entry_suffix=''
  if [ "$app_dir" != "$workspace_path" ]; then
    app_entry_suffix='/app'
  fi

  workspace_conf="$workspace_path/wizardry.workspace.conf"
  targets_csv=''
  if [ -f "$workspace_conf" ]; then
    targets_csv=$(workspace_field "$workspace_conf" targets "")
  fi

  host_target=''
  case "$(os_id)" in
    darwin) host_target='macos' ;;
    linux) host_target='linux' ;;
  esac

  has_host_target=false
  has_hosted_web=false
  case ",$targets_csv," in
    *,"$host_target",*) has_host_target=true ;;
  esac
  case ",$targets_csv," in
    *,hosted-web,*) has_hosted_web=true ;;
  esac

  if [ "$has_host_target" = false ] && [ "$has_hosted_web" = true ]; then
    cmd_serve_hosted_web "$root" workspace "$workspace_path"
    return 0
  fi
  if [ "$has_host_target" = false ]; then
    printf '%s\n' "forge-backend: workspace has no runnable target for this host (enable $host_target or hosted-web)" >&2
    exit 1
  fi

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
  log_path="$log_dir/workspace-$workspace_id-run.log"

  if [ "$os" = "darwin" ] && command -v open >/dev/null 2>&1; then
    workspace_title=$(workspace_field "$workspace_conf" title "")
    [ -n "$workspace_title" ] || workspace_title=$(workspace_field "$workspace_conf" name "")
    [ -n "$workspace_title" ] || workspace_title=$(basename "$workspace_path")

    workspace_slug=$(workspace_field "$workspace_conf" project_id "")
    [ -n "$workspace_slug" ] || workspace_slug=$(basename "$workspace_path")
    workspace_slug=$(sanitize_bundle_component "$workspace_slug")

    bundle_root="$root/_tmp/workbench/dist/macos-workspaces/$workspace_slug"
    bundle="$bundle_root/$workspace_title.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/$workspace_slug" "$bundle/Contents/Resources/.host"

    copy_tree_for_bundle "$workspace_path" "$bundle/Contents/Resources/$workspace_slug/"
    mkdir -p "$bundle/Contents/Resources/$workspace_slug/.host"
    cp -R "$root/apps/.host/shared" "$bundle/Contents/Resources/$workspace_slug/.host/"
    cp -R "$root/apps/.host/shared" "$bundle/Contents/Resources/.host/"
    printf '%s\n' "$root" > "$bundle/Contents/Resources/wizardry-apps-root.txt"
    cp "$host_bin" "$bundle/Contents/MacOS/wizardry-host"

    cat > "$bundle/Contents/MacOS/$workspace_slug" <<APP
#!/bin/sh
set -eu
APPDIR=\$(CDPATH= cd -- "\$(dirname "\$0")/.." && pwd -P)
exec env WIZARDRY_DIR="$root" WIZARDRY_APPS_ROOT="$root" "\$APPDIR/MacOS/wizardry-host" "\$APPDIR/Resources/$workspace_slug$app_entry_suffix"
APP
    chmod +x "$bundle/Contents/MacOS/$workspace_slug"

    icon_source=''
    icon_source_format=''
    if [ -f "$workspace_path/assets/forge-icon.png" ]; then
      icon_source="$workspace_path/assets/forge-icon.png"
      icon_source_format='png'
    elif [ -f "$app_dir/assets/forge-icon.png" ]; then
      icon_source="$app_dir/assets/forge-icon.png"
      icon_source_format='png'
    elif [ -f "$workspace_path/assets/forge.icns" ]; then
      icon_source="$workspace_path/assets/forge.icns"
      icon_source_format='icns'
    elif [ -f "$app_dir/assets/forge.icns" ]; then
      icon_source="$app_dir/assets/forge.icns"
      icon_source_format='icns'
    fi

    icon_key=''
    icon_hash=''
    if [ -n "$icon_source" ]; then
      icon_hash=$(hash_path_sha256 "$icon_source")
    fi
    if [ "$icon_source_format" = 'png' ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
      iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-ws-iconset.XXXXXX")
      iconset="${iconset_tmp}.iconset"
      mv "$iconset_tmp" "$iconset"
      for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
      done
      icon_name="forge-${icon_hash}.icns"
      if iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/$icon_name" >/dev/null 2>&1; then
        icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
      else
        icon_name="forge-icon-${icon_hash}.png"
        cp "$icon_source" "$bundle/Contents/Resources/$icon_name"
        icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
      fi
      rm -rf "$iconset"
    elif [ "$icon_source_format" = 'png' ]; then
      icon_name="forge-icon-${icon_hash}.png"
      cp "$icon_source" "$bundle/Contents/Resources/$icon_name"
      icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
    elif [ "$icon_source_format" = 'icns' ]; then
      icon_name="forge-${icon_hash}.icns"
      cp "$icon_source" "$bundle/Contents/Resources/$icon_name"
      icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
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

    stop_desktop_instances_for_slug "$root" "$workspace_slug" "$workspace_title" "$os"
    if ! launch_workspace_bundle_macos "$bundle" "$bundle/Contents/MacOS/$workspace_slug" "$bundle/Contents/Resources/$workspace_slug$app_entry_suffix"; then
      printf '%s\n' "forge-backend: failed to launch workspace bundle: $bundle" >&2
      exit 1
    fi
    printf 'launched=1\n'
    printf 'mode=desktop-executable\n'
    printf 'artifact=%s\n' "$bundle"
    printf 'entry=%s\n' "$bundle/Contents/Resources/$workspace_slug$app_entry_suffix"
    printf 'log=%s\n' "$log_path"
    return 0
  fi

  if [ "$os" = "linux" ]; then
    bundle_slug=$(sanitize_bundle_component "$(basename "$workspace_path")")
    bundle_root="$root/_tmp/workbench/dist/linux-workspaces/$bundle_slug"
    appdir="$bundle_root/AppDir"
    rm -rf "$appdir"
    mkdir -p "$appdir/usr/bin" "$appdir/usr/share/$bundle_slug" "$appdir/usr/share/.host" "$appdir/usr/share/wizardry-apps/core"

    copy_tree_for_bundle "$workspace_path" "$appdir/usr/share/$bundle_slug/"
    linux_ws_icon_source=''
    if [ -f "$workspace_path/assets/forge-icon.png" ]; then
      linux_ws_icon_source="$workspace_path/assets/forge-icon.png"
    elif [ -f "$app_dir/assets/forge-icon.png" ]; then
      linux_ws_icon_source="$app_dir/assets/forge-icon.png"
    fi
    if [ -n "$linux_ws_icon_source" ]; then
      mkdir -p "$appdir/usr/share/$bundle_slug/assets"
      cp "$linux_ws_icon_source" "$appdir/usr/share/$bundle_slug/assets/forge-icon.png"
    fi
    mkdir -p "$appdir/usr/share/$bundle_slug/.host"
    cp -R "$root/apps/.host/shared" "$appdir/usr/share/$bundle_slug/.host/"
    cp -R "$root/apps/.host/shared" "$appdir/usr/share/.host/"
    cp -R "$root/core/include" "$appdir/usr/share/wizardry-apps/core/"
    cp -R "$root/core/src" "$appdir/usr/share/wizardry-apps/core/"
    cp "$host_bin" "$appdir/usr/bin/wizardry-host"

    cat > "$appdir/AppRun" <<APP
#!/bin/sh
set -eu
HERE=\$(CDPATH= cd -- "\$(dirname "\$0")" && pwd -P)
exec env WIZARDRY_DIR="$root" WIZARDRY_APPS_ROOT="$root" "\$HERE/usr/bin/wizardry-host" "\$HERE/usr/share/$bundle_slug$app_entry_suffix"
APP
    chmod +x "$appdir/AppRun"

    if command -v nohup >/dev/null 2>&1; then
      nohup "$appdir/AppRun" >"$log_path" 2>&1 &
    else
      "$appdir/AppRun" >"$log_path" 2>&1 &
    fi
    pid=$!
    printf 'launched=1\n'
    printf 'mode=desktop-executable\n'
    printf 'artifact=%s\n' "$appdir"
    printf 'entry=%s\n' "$appdir/usr/share/$bundle_slug$app_entry_suffix"
    printf 'pid=%s\n' "$pid"
    printf 'log=%s\n' "$log_path"
    return 0
  fi
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
      require_jq
      manifest_app_exists "$root" "$slug" || {
        printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
        exit 1
      }
      hosted_mode=$(app_hosted_web_mode "$root" "$slug")
      case "$hosted_mode" in
        local)
          template_dir="$root/web/$slug"
          [ -d "$template_dir" ] || {
            printf '%s\n' "forge-backend: hosted web template not found for app: $slug" >&2
            exit 1
          }
          ;;
        external)
          printf '%s\n' "forge-backend: hosted web serve for external hostedWeb apps is not yet available in this repository clone" >&2
          exit 1
          ;;
        *)
          printf '%s\n' "forge-backend: unknown hostedWeb mode for app: $slug" >&2
          exit 1
          ;;
      esac

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
      workspace_path=$ref
      [ -d "$workspace_path" ] || {
        printf '%s\n' "forge-backend: workspace not found: $workspace_path" >&2
        exit 1
      }
      workspace_path=$(CDPATH= cd -- "$workspace_path" && pwd -P)
      workspace_slug=$(sanitize_bundle_component "$(basename "$workspace_path")")
      workspace_conf="$workspace_path/wizardry.workspace.conf"
      workspace_hosted_web_mode=$(workspace_field "$workspace_conf" hosted_web_mode "")
      case "$workspace_hosted_web_mode" in
        "")
          ;;
        web-wizardry-site)
          serve_workspace_managed_hosted_web "$root" "$workspace_path" "$workspace_conf" "$workspace_slug" || exit 1
          return 0
          ;;
        *)
          printf '%s\n' "forge-backend: unknown workspace hosted_web_mode: $workspace_hosted_web_mode" >&2
          exit 1
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
      command -v python3 >/dev/null 2>&1 || {
        printf '%s\n' "forge-backend: python3 is required to serve workspace hosted web targets" >&2
        exit 1
      }
      port=$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)
      web_log="$root/_tmp/workbench/log/hosted-web/workspace-$workspace_slug-python.log"
      mkdir -p "$(dirname "$web_log")"
      if command -v nohup >/dev/null 2>&1; then
        nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$app_dir" >"$web_log" 2>&1 &
      else
        python3 -m http.server "$port" --bind 127.0.0.1 --directory "$app_dir" >"$web_log" 2>&1 &
      fi
      pid=$!
      printf 'mode=python-http\n'
      printf 'site=workspace-%s\n' "$workspace_slug"
      printf 'entry=%s\n' "$app_dir"
      printf 'url=%s\n' "http://127.0.0.1:$port"
      printf 'pid=%s\n' "$pid"
      printf 'log=%s\n' "$web_log"
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
  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }
  distribution=$(app_distribution "$root" "$slug")
  [ "$distribution" = "core" ] || {
    printf '%s\n' "forge-backend: stage-mobile currently supports core apps only: $slug" >&2
    exit 1
  }
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
  require_jq
  distribution=$(app_distribution "$root" "$slug")
  [ "$distribution" = "core" ] || {
    printf '%s\n' "forge-backend: build-ios-smoke currently supports core apps only: $slug" >&2
    exit 1
  }
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
  require_jq
  distribution=$(app_distribution "$root" "$slug")
  [ "$distribution" = "core" ] || {
    printf '%s\n' "forge-backend: build-android-debug currently supports core apps only: $slug" >&2
    exit 1
  }
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  require_tool gradle
  require_tool java

  app_name=$(app_name_from_manifest "$root" "$slug")
  app_id=$(bundle_id_from_manifest "$root" android "$slug")

  sh "$root/tools/release/stage-web-assets.sh" "$slug" "$root/apps/.host/android/app/src/main/assets"

  version_name="0.0.0-local"
  version_code=$(date +%s)

  gradle -p "$root/apps/.host/android" :app:assembleDebug \
    -PwizardryApplicationId="$app_id" \
    -PwizardryAppName="$app_name" \
    -PwizardryVersionName="$version_name" \
    -PwizardryVersionCode="$version_code"

  apk=$(find "$root/apps/.host/android/app/build/outputs/apk/debug" -type f -name '*.apk' | head -n 1)
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

  <script src="./.host/shared/wizardry-bridge.js"></script>
  <script>
    document.getElementById('ping').addEventListener('click', async function () {
      var out = document.getElementById('out');
      if (!window.wizardry || !window.wizardry.exec) {
        out.textContent = 'wizardry bridge unavailable';
        return;
      }
      try {
        var res = await window.wizardry.exec(['sh', '-c', 'printf ping']);
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

  <script src="./.host/shared/wizardry-bridge.js"></script>
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
        if (!window.wizardry || !window.wizardry.exec) {
          out.textContent = 'wizardry bridge unavailable';
          return;
        }
        out.textContent = 'running: ' + argv.join(' ');
        try {
          var res = await window.wizardry.exec(argv);
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
      "distribution": "core",
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

  app_dir="$root/apps/$slug"
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
      require_jq
      manifest_app_exists "$root" "$source_app" || {
        printf '%s\n' "forge-backend: source app not found in manifest: $source_app" >&2
        exit 1
      }
      source_dir=$(resolve_app_dir_or_error "$root" "$source_app")
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
    web)
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
          require_jq
          manifest_app_exists "$root" "$source" || {
            printf '%s\n' "forge-backend: source app not found in manifest: $source" >&2
            exit 1
          }
          source_dir=$(resolve_app_dir_or_error "$root" "$source")
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

    godot)
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
      printf '%s\n' "forge-backend: scaffold-workspace context must be web or godot" >&2
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

  require_jq
  manifest_template_exists "$root" "$template" || {
    printf '%s\n' "forge-backend: template not found in manifest: $template" >&2
    exit 1
  }
  template_dir=$(resolve_template_dir_or_error "$root" "$template")

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

  if [ -d "$root/web/.themes" ]; then
    mkdir -p "$site_dir/site/static/themes"
    cp -f "$root/web/.themes"/*.css "$site_dir/site/static/themes/" 2>/dev/null || true
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
  app-status)
    cmd_app_status "${2-}" "${3-}"
    ;;
  template-status)
    cmd_template_status "${2-}" "${3-}"
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
  import-workspace)
    cmd_import_workspace "${2-}" "${3-}" "${4-}"
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
  rename-workspace)
    cmd_rename_workspace "${2-}" "${3-}" "${4-}"
    ;;
  set-app-icon)
    cmd_set_app_icon "${2-}" "${3-}" "${4-}"
    ;;
  set-workspace-icon)
    cmd_set_workspace_icon "${2-}" "${3-}" "${4-}"
    ;;
  download-app)
    cmd_download_app "${2-}" "${3-}"
    ;;
  remove-downloaded-app)
    cmd_remove_downloaded_app "${2-}" "${3-}"
    ;;
  download-template)
    cmd_download_template "${2-}" "${3-}"
    ;;
  remove-downloaded-template)
    cmd_remove_downloaded_template "${2-}" "${3-}"
    ;;
  build-desktop)
    cmd_build_desktop "${2-}" "${3-}"
    ;;
  run-desktop)
    cmd_run_desktop "${2-}" "${3-}"
    ;;
  install-desktop)
    cmd_install_desktop "${2-}" "${3-}" "${4-}"
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
