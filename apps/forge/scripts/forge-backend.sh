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
  get-workspace-profile [ROOT_HINT] WORKSPACE_PATH
  workspace-git-status [ROOT_HINT] WORKSPACE_PATH
  workspace-git-init [ROOT_HINT] WORKSPACE_PATH [REMOTE_URL] [BRANCH]
  workspace-git-set-remote [ROOT_HINT] WORKSPACE_PATH REMOTE_URL
  workspace-git-set-branch [ROOT_HINT] WORKSPACE_PATH BRANCH
  workspace-git-fetch [ROOT_HINT] WORKSPACE_PATH
  workspace-git-pull [ROOT_HINT] WORKSPACE_PATH
  workspace-git-push [ROOT_HINT] WORKSPACE_PATH
  workspace-git-repo-url [ROOT_HINT] WORKSPACE_PATH
  workspace-git-pr-url [ROOT_HINT] WORKSPACE_PATH
  workspace-git-release [ROOT_HINT] WORKSPACE_PATH
  workspace-git-install-release [ROOT_HINT] WORKSPACE_PATH
  pick-workspace-subpath [ROOT_HINT] WORKSPACE_PATH
  get-ui-prefs [ROOT_HINT]
  set-ui-pref [ROOT_HINT] KEY VALUE
  set-workspace-field [ROOT_HINT] WORKSPACE_PATH KEY VALUE
  set-app-targets [ROOT_HINT] APP_SLUG TARGETS
  set-workspace-targets [ROOT_HINT] WORKSPACE_PATH TARGETS
  rename-workspace [ROOT_HINT] WORKSPACE_PATH NEW_TITLE
  set-app-icon [ROOT_HINT] APP_SLUG DATA_URL [squircle|plain]
  set-workspace-icon [ROOT_HINT] WORKSPACE_PATH DATA_URL [squircle|plain]
  set-app-icon-file [ROOT_HINT] APP_SLUG IMAGE_PATH [squircle|plain]
  set-workspace-icon-file [ROOT_HINT] WORKSPACE_PATH IMAGE_PATH [squircle|plain]
  regenerate-app-icon-assets [ROOT_HINT] APP_SLUG [squircle|plain]
  regenerate-workspace-icon-assets [ROOT_HINT] WORKSPACE_PATH [squircle|plain]
  icon-tool-status [ROOT_HINT]
  install-icon-tool [ROOT_HINT] TOOL
  uninstall-icon-tool [ROOT_HINT] TOOL
  download-app [ROOT_HINT] APP_SLUG
  remove-downloaded-app [ROOT_HINT] APP_SLUG
  download-template [ROOT_HINT] TEMPLATE_SLUG
  remove-downloaded-template [ROOT_HINT] TEMPLATE_SLUG
  build-desktop [ROOT_HINT] APP_SLUG
  install-desktop [ROOT_HINT] APP_SLUG [TARGET_ID]
  install-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT] [TARGET_ID]
  run-desktop [ROOT_HINT] APP_SLUG [normal|install-first|bundle]
  rebuild-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT]
  run-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT] [normal|install-first|bundle]
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
  minimal | reference-app | panel | sidebar | topbar | dashboard | studio | clone

CONTEXT values for scaffold-workspace:
  web | native-desktop | godot
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

icon_creation_dir() {
  root=${1-}
  [ -n "$root" ] || return 1
  printf '%s\n' "$root/spells/.arcana/icon-creation"
}

run_icon_creation_script() {
  root=${1-}
  script_name=${2-}
  shift 2

  [ -n "$root" ] || {
    printf '%s\n' "forge-backend: icon script requires ROOT" >&2
    exit 2
  }
  [ -n "$script_name" ] || {
    printf '%s\n' "forge-backend: icon script name is required" >&2
    exit 2
  }

  script_path="$(icon_creation_dir "$root")/$script_name"
  [ -f "$script_path" ] || {
    printf '%s\n' "forge-backend: icon script not found: $script_path" >&2
    exit 1
  }

  sh "$script_path" "$@"
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
  bundle_id=''
  case "$target" in
    darwin)
      host_src="$root/apps/.host/macos/main.m"
      bundle_id=$(bundle_id_from_manifest "$root" macos "$slug")
      ;;
    linux)
      host_src="$root/apps/.host/linux/main.c"
      bundle_id="linux.$slug"
      ;;
    *)
      return 1
      ;;
  esac

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

resolve_godot_app_bundle() {
  if [ "$(os_id)" != "darwin" ]; then
    return 1
  fi
  if [ -n "${GODOT_APP-}" ] && [ -x "$GODOT_APP/Contents/MacOS/Godot" ]; then
    printf '%s\n' "$GODOT_APP"
    return 0
  fi
  for candidate in \
    "/Applications/Godot.app" \
    "$HOME/Applications/Godot.app"; do
    if [ -x "$candidate/Contents/MacOS/Godot" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

godot_project_icon_res_path() {
  project_dir=${1-}
  [ -n "$project_dir" ] || return 1
  for rel in \
    "assets/forge-icon.png" \
    "icon.svg" \
    "icon.png"; do
    if [ -f "$project_dir/$rel" ]; then
      printf 'res://%s\n' "$rel"
      return 0
    fi
  done
  return 1
}

sync_godot_project_icon_config() {
  project_dir=${1-}
  [ -n "$project_dir" ] || return 1
  project_file="$project_dir/project.godot"
  [ -f "$project_file" ] || return 0
  icon_res=$(godot_project_icon_res_path "$project_dir" 2>/dev/null || true)
  [ -n "$icon_res" ] || return 0
  icon_line="config/icon=\"$icon_res\""
  if grep -Fqx "$icon_line" "$project_file" 2>/dev/null; then
    return 0
  fi

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/forge-godot-project.XXXXXX")
  awk -v icon_line="$icon_line" '
    BEGIN {
      in_application = 0
      saw_application = 0
      inserted = 0
    }
    /^\[application\]$/ {
      if (in_application && inserted == 0) {
        print icon_line
        inserted = 1
      }
      in_application = 1
      saw_application = 1
      print
      next
    }
    /^\[/ {
      if (in_application && inserted == 0) {
        print icon_line
        inserted = 1
      }
      in_application = 0
      print
      next
    }
    {
      if (in_application && $0 ~ /^config\/icon=/) {
        if (inserted == 0) {
          print icon_line
          inserted = 1
        }
        next
      }
      print
    }
    END {
      if (in_application && inserted == 0) {
        print icon_line
        inserted = 1
      }
      if (saw_application == 0) {
        if (NR > 0) {
          print ""
        }
        print "[application]"
        print icon_line
      }
    }
  ' "$project_file" > "$tmp_file"
  mv "$tmp_file" "$project_file"
}

sync_workspace_godot_icon_config_if_needed() {
  workspace_path=${1-}
  [ -n "$workspace_path" ] || return 1
  conf_path="$workspace_path/wizardry.workspace.conf"
  if godot_subpath=$(resolve_workspace_godot_subpath "$workspace_path" "$conf_path" 2>/dev/null || true) && [ -n "$godot_subpath" ]; then
    case "$godot_subpath" in
      ".")
        project_path="$workspace_path"
        ;;
      *)
        project_path="$workspace_path/$godot_subpath"
        ;;
    esac
    sync_godot_project_icon_config "$project_path"
  fi
}

ensure_godot_project() {
  workspace_path=$1
  project_title=${2-}

  if godot_subpath=$(resolve_workspace_godot_subpath "$workspace_path" "$workspace_path/wizardry.workspace.conf" 2>/dev/null || true) && [ -n "$godot_subpath" ]; then
    case "$godot_subpath" in
      ".")
        printf '%s\n' "$workspace_path"
        ;;
      *)
        printf '%s\n' "$workspace_path/$godot_subpath"
        ;;
    esac
    return 0
  fi

  [ -f "$workspace_path/tool_main.gd" ] || return 1

  [ -w "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project is not writable for Godot bootstrap: $workspace_path" >&2
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

  sync_godot_project_icon_config "$workspace_path"
  printf '%s\n' "$workspace_path"
  return 0
}

is_valid_slug_value() {
  candidate=${1-}
  case "$candidate" in
    [a-z]*) ;;
    *)
      return 1
      ;;
  esac

  case "$candidate" in
    *[!a-z0-9-]*|*-|*--*)
      return 1
      ;;
  esac

  return 0
}

validate_slug() {
  candidate=${1-}
  if ! is_valid_slug_value "$candidate"; then
    printf '%s\n' "forge-backend: invalid slug '$candidate' (expected [a-z][a-z0-9-]* with no trailing or consecutive hyphens)" >&2
    exit 2
  fi
}

validate_site_name() {
  site=${1-}
  case "$site" in
    [A-Za-z0-9]*) ;;
    *)
      printf '%s\n' "forge-backend: invalid site name '$site'" >&2
      exit 2
      ;;
  esac

  case "$site" in
    *[!A-Za-z0-9._-]*)
      printf '%s\n' "forge-backend: invalid site name '$site'" >&2
      exit 2
      ;;
  esac
}

normalize_targets_value() {
  value=${1-}
  value=$(printf '%s' "$value" | tr '\r\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  case "$value" in
    *[!A-Za-z0-9,-]*|*,|,*|*,,*)
      printf '%s\n' "forge-backend: invalid targets '$value'" >&2
      exit 2
      ;;
  esac

  printf '%s\n' "$value"
}

normalize_generated_display_name() {
  printf '%s' "${1-}" | tr '\r\n\t' '   ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

validate_generated_display_name() {
  value=${1-}
  label=${2-APP_NAME}

  [ -n "$value" ] || {
    printf '%s\n' "forge-backend: $label requires a non-empty value" >&2
    exit 2
  }

  if ! printf '%s\n' "$value" | LC_ALL=C grep -Eq '^[A-Za-z0-9 .,_()-]+$'; then
    printf '%s\n' "forge-backend: unsupported $label '$value' (use letters, numbers, spaces, '.', ',', '_', '-', or parentheses)" >&2
    exit 2
  fi
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
    shape_mode=$(project_icon_shape_mode "$dest_dir")
    write_project_icon_from_file "$dest_dir" "$override_icon" "$shape_mode"
  fi
}

project_preferred_bundle_icon_path() {
  project_dir=$1
  territory_master="$project_dir/assets/icons/meta/territory-master.png"
  apple_master="$project_dir/assets/icons/meta/apple-master.png"
  plain_master="$project_dir/assets/icons/meta/plain-master.png"
  original_source=$(project_original_icon_source "$project_dir" 2>/dev/null || true)

  # Prefer current PNG masters so stale cached .icns files from older icon
  # pipeline revisions cannot override the latest Apple-safe composition.
  for candidate in \
    "$apple_master" \
    "$project_dir/assets/forge-icon.png" \
    "$project_dir/assets/icons/macos/forge.icns" \
    "$plain_master" \
    "$project_dir/assets/forge.icns"
  do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [ -f "$territory_master" ]; then
    printf '%s\n' "$territory_master"
    return 0
  fi

  if [ -n "$original_source" ] && [ -f "$original_source" ]; then
    printf '%s\n' "$original_source"
    return 0
  fi

  return 1
}

icon_source_format_for_path() {
  path=$1

  case "$path" in
    *.icns) printf '%s\n' icns ;;
    *) printf '%s\n' png ;;
  esac
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

host_install_status_for_app() {
  root=$1
  slug=$2
  app_name_hint=${3-}
  os=$(os_id)

  case "$os" in
    darwin)
      app_name=$app_name_hint
      [ -n "$app_name" ] || app_name=$slug
      for candidate in "/Applications/$app_name.app" "$HOME/Applications/$app_name.app"; do
        if [ -d "$candidate" ]; then
          printf '%s\t%s\n' "1" "$candidate"
          return 0
        fi
      done
      ;;
    linux)
      for candidate in \
        "$HOME/.local/bin/wizardry-$slug" \
        "/usr/local/bin/wizardry-$slug" \
        "/usr/bin/wizardry-$slug"; do
        if [ -x "$candidate" ]; then
          printf '%s\t%s\n' "1" "$candidate"
          return 0
        fi
      done
      for candidate in \
        "$HOME/.local/share/applications/wizardry-$slug.desktop" \
        "/usr/local/share/applications/wizardry-$slug.desktop" \
        "/usr/share/applications/wizardry-$slug.desktop"; do
        if [ -f "$candidate" ]; then
          printf '%s\t%s\n' "1" "$candidate"
          return 0
        fi
      done
      ;;
  esac

  printf '%s\t%s\n' "0" ""
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

validate_source_subdir() {
  subdir=${1-}
  label=${2-source subdir}

  [ -n "$subdir" ] || return 0
  [ "$subdir" = "." ] && return 0

  if has_line_break "$subdir"; then
    printf '%s\n' "forge-backend: invalid $label" >&2
    exit 2
  fi

  tab_char=$(printf '\t')
  case "$subdir" in
    *"$tab_char"*|/*|*\\*|*//*|*/|./*|*/./*|*/.|..|../*|*/../*|*/..|*[!A-Za-z0-9._/-]*)
      safe_subdir=$(printf '%s' "$subdir" | tr '\t' ' ')
      printf '%s\n' "forge-backend: invalid $label '$safe_subdir'" >&2
      exit 2
      ;;
  esac
}

download_into_cache() {
  repo=$1
  ref=$2
  subdir=$3
  dest_dir=$4
  lock_file=$5
  slug=${6-}

  require_tool git
  validate_source_subdir "$subdir" "source subdir"
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
  env WIZARDRY_APPS_ROOT="$root" sh "$root/tools/release/get-app-name.sh" "$slug"
}

bundle_id_from_manifest() {
  root=$1
  platform=$2
  slug=$3
  env WIZARDRY_APPS_ROOT="$root" sh "$root/tools/release/get-app-bundle-id.sh" "$platform" "$slug"
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

macos_bundle_signature_is_usable() {
  bundle_path=${1-}
  [ -d "$bundle_path" ] || return 1
  command -v codesign >/dev/null 2>&1 || return 0
  codesign --verify --deep --strict "$bundle_path" >/dev/null 2>&1
}

ensure_macos_bundle_signature() {
  bundle_path=${1-}
  [ -d "$bundle_path" ] || return 1
  command -v codesign >/dev/null 2>&1 || return 0
  if macos_bundle_signature_is_usable "$bundle_path"; then
    return 0
  fi
  codesign --force --deep --sign - "$bundle_path" >/dev/null 2>&1 || return 1
  macos_bundle_signature_is_usable "$bundle_path"
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

workspace_rebuild_command() {
  conf=${1-}
  if workspace_field_exists "$conf" run_rebuild_command; then
    command=$(workspace_field "$conf" run_rebuild_command "")
  else
    command=""
  fi
  if [ -n "$command" ]; then
    printf '%s\n' "$command"
    return 0
  fi
  if workspace_field_exists "$conf" run_rebuild_command; then
    printf '%s\n' ""
    return 0
  fi
  printf '%s\n' "$(workspace_field "$conf" rebuild_command "")"
}

run_workspace_rebuild() {
  root=$1
  workspace_path=$2
  workspace_conf=$3

  rebuild_command=$(workspace_rebuild_command "$workspace_conf")
  if [ -z "$rebuild_command" ]; then
    printf 'status=noop\n'
    printf 'mode=none\n'
    return 0
  fi

  case "$rebuild_command" in
    :|true)
      printf 'status=noop\n'
      printf 'mode=command-noop\n'
      printf 'command=%s\n' "$(kv_output_value "$rebuild_command")"
      return 0
      ;;
  esac

  workspace_slug=$(sanitize_bundle_component "$(basename "$workspace_path")")
  log_dir="$root/_tmp/workbench/log"
  mkdir -p "$log_dir"
  log_path="$log_dir/workspace-$workspace_slug-rebuild.log"

  if (
    cd "$workspace_path"
    env WIZARDRY_DIR="$root" WIZARDRY_APPS_ROOT="$root" sh -lc "$rebuild_command"
  ) >"$log_path" 2>&1; then
    printf 'status=ok\n'
    printf 'mode=command\n'
    printf 'command=%s\n' "$(kv_output_value "$rebuild_command")"
    printf 'log=%s\n' "$(kv_output_value "$log_path")"
    return 0
  fi

  printf '%s\n' "forge-backend: project rebuild failed (see log: $log_path)" >&2
  exit 1
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

workspace_field_exists() {
  conf=$1
  key=$2
  [ -f "$conf" ] || return 1
  awk -F= -v k="$key" '
    $1 ~ /^[[:space:]]*#/ { next }
    $1 ~ /^[[:space:]]*$/ { next }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
      if ($1 == k) {
        found = 1
        exit
      }
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$conf"
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
    printf '%s\n' "forge-backend: hosted_web_serve_script must resolve inside the project: $serve_script_rel" >&2
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
    printf '%s\n' "forge-backend: project hosted web serve failed (see log: $web_log)" >&2
    return 1
  fi

  site_conf="$site_dir/site.conf"
  [ -f "$site_conf" ] || {
    printf '%s\n' "forge-backend: project hosted web site config not found after serve: $site_conf" >&2
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

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in
    *"$nl_char"*|*"$cr_char"*) return 0 ;;
  esac
  return 1
}

kv_output_value() {
  printf '%s' "${1-}" | tr '\r\n' '  '
}

tsv_output_value() {
  printf '%s' "${1-}" | tr '\r\n\t' '   '
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
  ensure_macos_bundle_signature "$dest_bundle" || return 1
  return 0
}

macos_app_is_running() {
  app_name=${1-}
  [ -n "$app_name" ] || return 1
  command -v osascript >/dev/null 2>&1 || return 1

  running=$(
    osascript \
      -e "if application \"$app_name\" is running then" \
      -e 'return "yes"' \
      -e 'else' \
      -e 'return "no"' \
      -e 'end if' 2>/dev/null || printf 'no'
  )
  [ "$running" = "yes" ]
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

  # Do not try to hot-swap an installed macOS app bundle while it is running.
  # That can hang or fail when the user edits the icon of the currently running app,
  # especially Forge updating itself from inside Forge.
  macos_app_is_running "$app_name" && return 1

  build_out=$(cmd_build_desktop "$root" "$slug" 2>/dev/null || true)
  bundle_path=$(printf '%s\n' "$build_out" | kv_read artifact)
  [ -n "$bundle_path" ] || return 1
  sync_existing_macos_installs_from_bundle "$bundle_path" "$app_name"
}

stop_host_instances_for_app() {
  host_bin=${1-}
  app_dir=${2-}
  bundle_path=${3-}

  [ -n "$app_dir$bundle_path" ] || return 0
  command -v ps >/dev/null 2>&1 || return 0

  # Prevent stale hidden windows/processes from making desktop runs appear as no-op.
  # Match by app_dir path + wizardry host command so we also catch launcher/bundle variants.
  pids=$(
    ps -axo pid=,command= 2>/dev/null \
      | awk -v app="$app_dir" -v bundle="$bundle_path" '
          {
            matched = 0
            if (app != "" && index($0, app) > 0) matched = 1
            if (bundle != "" && index($0, bundle "/Contents/MacOS/wizardry-host") > 0) matched = 1
            if (index($0, "wizardry-host") > 0 && matched) print $1
          }
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
      | awk -v app="$app_dir" -v bundle="$bundle_path" '
          {
            matched = 0
            if (app != "" && index($0, app) > 0) matched = 1
            if (bundle != "" && index($0, bundle "/Contents/MacOS/wizardry-host") > 0) matched = 1
            if (index($0, "wizardry-host") > 0 && matched) print $1
          }
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
  bundle_path=${2-}
  [ -n "$app_dir$bundle_path" ] || return 1
  command -v ps >/dev/null 2>&1 || return 1
  ps -axo command= 2>/dev/null \
    | awk -v app="$app_dir" -v bundle="$bundle_path" '
        {
          matched = 0
          if (app != "" && index($0, app) > 0) matched = 1
          if (bundle != "" && index($0, bundle "/Contents/MacOS/wizardry-host") > 0) matched = 1
          if (index($0, "wizardry-host") > 0 && matched) {
            found = 1
            exit
          }
        }
        END { if (found) exit 0; exit 1 }
      '
}

wait_for_workspace_host_start() {
  app_dir=${1-}
  attempts=${2-}
  bundle_path=${3-}
  [ -n "$app_dir$bundle_path" ] || return 1
  [ -n "$attempts" ] || attempts=20
  i=0
  stable=0
  while [ "$i" -lt "$attempts" ]; do
    if workspace_host_running_for_app_dir "$app_dir" "$bundle_path"; then
      stable=$((stable + 1))
      if [ "$stable" -ge 2 ]; then
        return 0
      fi
    else
      stable=0
    fi
    i=$((i + 1))
    sleep 0.2
  done
  return 1
}

launch_desktop_host_linux() {
  app_run=${1-}
  app_dir=${2-}
  log_path=${3-}

  [ -n "$app_run" ] || return 1
  [ -x "$app_run" ] || return 1
  [ -n "$app_dir" ] || return 1
  [ -n "$log_path" ] || return 1

  stop_host_instances_for_app "" "$app_dir"

  if command -v nohup >/dev/null 2>&1; then
    nohup "$app_run" >"$log_path" 2>&1 &
  else
    "$app_run" >"$log_path" 2>&1 &
  fi
  pid=$!

  if wait_for_workspace_host_start "$app_dir" 50; then
    printf '%s\n' "$pid"
    return 0
  fi

  stop_host_instances_for_app "" "$app_dir"
  wait "$pid" >/dev/null 2>&1 || true
  return 1
}

launch_workspace_bundle_macos() {
  bundle=${1-}
  launcher_exec=${2-}
  app_dir=${3-}
  [ -d "$bundle" ] || return 1
  [ -n "$app_dir" ] || return 1

  stop_host_instances_for_app "" "$app_dir" "$bundle"

  if command -v open >/dev/null 2>&1; then
    if open "$bundle" >/dev/null 2>&1; then
      # A successful open request should not be followed by a second explicit
      # launch attempt; doing both can create duplicate app instances/tray icons
      # on slower startups.
      if wait_for_workspace_host_start "$app_dir" 100 "$bundle"; then
        return 0
      fi
      return 1
    fi
  fi

  [ -x "$launcher_exec" ] || return 1
  stop_host_instances_for_app "" "$app_dir" "$bundle"
  if command -v nohup >/dev/null 2>&1; then
    nohup "$launcher_exec" >/dev/null 2>&1 &
  else
    "$launcher_exec" >/dev/null 2>&1 &
  fi
  wait_for_workspace_host_start "$app_dir" 50 "$bundle"
}

stop_desktop_instances_for_slug() {
  root=${1-}
  slug=${2-}
  app_name=${3-}
  os_name=${4-}
  skip_gui_quit=${5-}

  [ -n "$slug" ] || return 0

  if [ "$os_name" = "darwin" ] && [ -n "$app_name" ] && [ "$skip_gui_quit" != "1" ] && command -v osascript >/dev/null 2>&1; then
    osascript \
      -e "if application \"$app_name\" is running then" \
      -e "tell application \"$app_name\" to quit" \
      -e "end if" >/dev/null 2>&1 || true
  fi

  if command -v pkill >/dev/null 2>&1; then
    pkill -f "wizardry-host.*[/.]apps/$slug" >/dev/null 2>&1 || true
    pkill -f "wizardry-host.*/Resources/$slug" >/dev/null 2>&1 || true
    if [ -n "$app_name" ]; then
      pkill -f "/$app_name.app/Contents/MacOS/wizardry-host" >/dev/null 2>&1 || true
    fi
    if [ -n "$root" ]; then
      pkill -f "wizardry-host.*$root/_tmp/workbench/dist/.*/$slug" >/dev/null 2>&1 || true
    fi
  fi

  if command -v ps >/dev/null 2>&1; then
    i=0
    still_running=1
    while [ "$i" -lt 20 ]; do
      still_running=$(
        ps -axo command= 2>/dev/null \
          | awk -v slug="$slug" -v root="$root" -v app_name="$app_name" '
              index($0, "wizardry-host") > 0 && (index($0, "/apps/" slug) > 0 || index($0, "/Resources/" slug) > 0 || (app_name != "" && index($0, "/" app_name ".app/Contents/MacOS/wizardry-host") > 0) || (root != "" && index($0, root "/_tmp/workbench/dist/") > 0 && index($0, "/" slug) > 0)) { found=1; exit }
              END { if (found) print "1"; else print "0" }
            '
      )
      [ "$still_running" = "0" ] && break
      sleep 0.1
      i=$((i + 1))
    done

    if [ "$still_running" = "1" ]; then
      stubborn_pids=$(
        ps -axo pid=,command= 2>/dev/null \
          | awk -v slug="$slug" -v root="$root" -v app_name="$app_name" '
              index($0, "wizardry-host") > 0 && (index($0, "/apps/" slug) > 0 || index($0, "/Resources/" slug) > 0 || (app_name != "" && index($0, "/" app_name ".app/Contents/MacOS/wizardry-host") > 0) || (root != "" && index($0, root "/_tmp/workbench/dist/") > 0 && index($0, "/" slug) > 0)) { print $1 }
            ' \
          | tr '\n' ' ' \
          | sed 's/[[:space:]]*$//'
      )
      if [ -n "$stubborn_pids" ]; then
        # shellcheck disable=SC2086
        kill -9 $stubborn_pids >/dev/null 2>&1 || true
      fi
    fi
  fi
}

cmd_doctor() {
  root_hint=${1-}
  root=''

  if resolved=$(resolve_root "$root_hint" 2>/dev/null); then
    root=$resolved
  fi

  printf 'root=%s\n' "$(kv_output_value "$root")"
  printf 'os=%s\n' "$(os_id)"
  printf 'home=%s\n' "$(kv_output_value "${HOME-}")"

  for t in jq clang cc gcc xcodebuild xcodegen pkg-config gradle java brew open xdg-open appimagetool magick; do
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
    printf 'apps_manifest=%s\n' "$(kv_output_value "$root/config/apps.manifest.json")"
    printf 'templates_manifest=%s\n' "$(kv_output_value "$root/config/templates.manifest.json")"
    printf 'apps_total=%s\n' "$(jq -r '.apps | length' "$root/config/apps.manifest.json")"
    printf 'apps_production=%s\n' "$(jq -r '[.apps[] | select(.production == true)] | length' "$root/config/apps.manifest.json")"
    printf 'templates_total=%s\n' "$(jq -r '.templates | length' "$root/config/templates.manifest.json")"
  fi
}

cmd_list_apps() {
  root=$(require_root "${1-}")
  require_jq

  manifest="$root/config/apps.manifest.json"
  list_apps_tmp=$(mktemp "${TMPDIR:-/tmp}/forge-list-apps.XXXXXX")
  jq -r '.apps[] | [.slug, .name, (if .production then "true" else "false" end), ((.bundleIds // {}) | keys | join(",")), (if has("targets") then (.targets // "") else "__FORGE_TARGETS_MISSING__" end), (.distribution // "optional")] | @tsv' "$manifest" > "$list_apps_tmp"
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

    install_line=$(host_install_status_for_app "$root" "$slug" "$name")
    host_installed=$(printf '%s\n' "$install_line" | cut -f1)
    host_install_path=$(printf '%s\n' "$install_line" | cut -f2)
    git_repo_present='no'
    git_status_label=''
    git_status_tone='muted'
    git_status_reason=''
    git_release_available='no'
    if [ -n "$resolved_path" ] && [ -d "$resolved_path" ]; then
      git_info=$(workspace_git_collect_status "$resolved_path" "0" "0")
      git_repo_present=$(printf '%s\n' "$git_info" | kv_read git_repo_present)
      git_status_label=$(printf '%s\n' "$git_info" | kv_read git_status_label)
      git_status_tone=$(printf '%s\n' "$git_info" | kv_read git_status_tone)
      git_status_reason=$(printf '%s\n' "$git_info" | kv_read git_status_reason)
      git_release_available=$(printf '%s\n' "$git_info" | kv_read git_release_available)
    fi

    mtime_epoch=$(path_mtime_epoch "$resolved_path")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slug" "$name" "$production" "$exists" "$development_context" "$targets" "$distribution" "$resolved_status" "$resolved_path" "$mtime_epoch" "$host_installed" "$host_install_path" "$git_repo_present" "$git_status_label" "$git_status_tone" "$git_status_reason" "$git_release_available"
  done < "$list_apps_tmp"
  rm -f "$list_apps_tmp"
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

  printf 'slug=%s\n' "$(kv_output_value "$slug")"
  printf 'distribution=%s\n' "$(kv_output_value "$distribution")"
  printf 'status=%s\n' "$(kv_output_value "$resolved_status")"
  [ -n "$resolved_path" ] && printf 'path=%s\n' "$(kv_output_value "$resolved_path")"
  [ -n "$repo" ] && printf 'repo=%s\n' "$(kv_output_value "$repo")"
  printf 'ref=%s\n' "$(kv_output_value "$ref")"
  printf 'subdir=%s\n' "$(kv_output_value "$subdir")"
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

  printf 'slug=%s\n' "$(kv_output_value "$slug")"
  printf 'distribution=%s\n' "$(kv_output_value "$distribution")"
  printf 'status=%s\n' "$(kv_output_value "$resolved_status")"
  [ -n "$resolved_path" ] && printf 'path=%s\n' "$(kv_output_value "$resolved_path")"
  [ -n "$repo" ] && printf 'repo=%s\n' "$(kv_output_value "$repo")"
  printf 'ref=%s\n' "$(kv_output_value "$ref")"
  printf 'subdir=%s\n' "$(kv_output_value "$subdir")"
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

reject_line_breaks() {
  value=${1-}
  label=${2-value}
  single_line=$(printf '%s' "$value" | tr '\r\n' '  ')
  [ "$single_line" = "$value" ] || {
    printf '%s\n' "forge-backend: $label must not contain line breaks" >&2
    exit 2
  }
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

detect_workspace_app_subpath() {
  workspace_path=${1-}
  if [ -f "$workspace_path/app/index.html" ]; then
    printf '%s\n' "app"
    return 0
  fi
  if [ -f "$workspace_path/index.html" ]; then
    printf '%s\n' "."
    return 0
  fi

  apps_dir="$workspace_path/apps"
  if [ -d "$apps_dir" ]; then
    found_subpath=""
    found_count=0
    for candidate in "$apps_dir"/*; do
      [ -d "$candidate" ] || continue
      if [ -f "$candidate/index.html" ]; then
        found_subpath="apps/$(basename "$candidate")"
        found_count=$((found_count + 1))
      fi
    done
    if [ "$found_count" -eq 1 ] && [ -n "$found_subpath" ]; then
      printf '%s\n' "$found_subpath"
      return 0
    fi
  fi

  return 1
}

detect_workspace_godot_subpath() {
  workspace_path=${1-}
  if [ -f "$workspace_path/project.godot" ] || [ -f "$workspace_path/tool_main.gd" ]; then
    printf '%s\n' "."
    return 0
  fi
  if [ -f "$workspace_path/game/project.godot" ]; then
    printf '%s\n' "game"
    return 0
  fi
  if [ -f "$workspace_path/godot/project.godot" ]; then
    printf '%s\n' "godot"
    return 0
  fi

  found_subpath=""
  found_count=0
  for level_one in "$workspace_path"/*; do
    [ -d "$level_one" ] || continue
    case "$(basename "$level_one")" in
      .* ) continue ;;
    esac
    if [ -f "$level_one/project.godot" ]; then
      found_subpath="$(basename "$level_one")"
      found_count=$((found_count + 1))
    fi
    for level_two in "$level_one"/*; do
      [ -d "$level_two" ] || continue
      case "$(basename "$level_two")" in
        .* ) continue ;;
      esac
      if [ -f "$level_two/project.godot" ]; then
        found_subpath="$(basename "$level_one")/$(basename "$level_two")"
        found_count=$((found_count + 1))
      fi
    done
  done

  if [ "$found_count" -eq 1 ] && [ -n "$found_subpath" ]; then
    printf '%s\n' "$found_subpath"
    return 0
  fi

  return 1
}

detect_workspace_native_ir_path() {
  workspace_path=${1-}
  for candidate in \
    "$workspace_path/ir/app.ir.yaml" \
    "$workspace_path/ir/app.ir.yml" \
    "$workspace_path/app.ir.yaml" \
    "$workspace_path/app.ir.yml"
  do
    [ -f "$candidate" ] || continue
    printf '%s\n' "${candidate#"$workspace_path"/}"
    return 0
  done
  return 1
}

resolve_workspace_godot_subpath() {
  workspace_path=${1-}
  conf_path=${2-}

  godot_subpath=""
  if [ -n "$conf_path" ] && [ -f "$conf_path" ]; then
    godot_subpath=$(workspace_field "$conf_path" godot_subpath "")
  fi

  if [ -n "$godot_subpath" ]; then
    case "$godot_subpath" in
      ".")
        if [ -f "$workspace_path/project.godot" ] || [ -f "$workspace_path/tool_main.gd" ]; then
          printf '%s\n' "."
          return 0
        fi
        ;;
      *)
        godot_project_file=$(resolve_workspace_relative_path "$workspace_path" "$godot_subpath/project.godot" 2>/dev/null || true)
        if [ -n "$godot_project_file" ] && [ -f "$godot_project_file" ]; then
          printf '%s\n' "$godot_subpath"
          return 0
        fi
        ;;
    esac
  fi

  detect_workspace_godot_subpath "$workspace_path"
}

resolve_workspace_native_ir_path() {
  workspace_path=${1-}
  conf_path=${2-}

  native_ir_path=""
  if [ -n "$conf_path" ] && [ -f "$conf_path" ]; then
    native_ir_path=$(workspace_field "$conf_path" native_ir_path "")
  fi

  if [ -n "$native_ir_path" ]; then
    native_ir_abs=$(resolve_workspace_relative_path "$workspace_path" "$native_ir_path" 2>/dev/null || true)
    if [ -n "$native_ir_abs" ] && [ -f "$native_ir_abs" ]; then
      printf '%s\n' "$native_ir_path"
      return 0
    fi
  fi

  detect_workspace_native_ir_path "$workspace_path"
}

resolve_workspace_app_dir() {
  workspace_path=${1-}
  conf_path=${2-}
  app_subpath=""
  if [ -n "$conf_path" ] && [ -f "$conf_path" ]; then
    app_subpath=$(workspace_field "$conf_path" app_subpath "")
  fi
  if [ -z "$app_subpath" ]; then
    app_subpath=$(detect_workspace_app_subpath "$workspace_path" 2>/dev/null || true)
  fi

  case "$app_subpath" in
    "")
      return 1
      ;;
    ".")
      printf '%s\n' "$workspace_path"
      return 0
      ;;
    *)
      app_index_abs=$(resolve_workspace_relative_path "$workspace_path" "$app_subpath/index.html" 2>/dev/null || true)
      if [ -n "$app_index_abs" ] && [ -f "$app_index_abs" ]; then
        dirname "$app_index_abs"
        return 0
      fi
      ;;
  esac

  return 1
}

resolve_workspace_slug() {
  conf_path=${1-}
  workspace_path=${2-}
  project_id=$(workspace_field "$conf_path" project_id "")
  if [ -n "$project_id" ]; then
    if ! is_valid_slug_value "$project_id"; then
      project_id=""
    fi
  fi
  [ -n "$project_id" ] || project_id=$(derive_workspace_slug "$(basename "$workspace_path")")
  printf '%s\n' "$project_id"
}

ensure_importable_workspace_profile() {
  workspace_path=${1-}
  reject_line_breaks "$workspace_path" "project path"
  conf_path="$workspace_path/wizardry.workspace.conf"
  if [ -f "$conf_path" ]; then
    existing_profile_kind=$(workspace_field "$conf_path" profile_kind "")
    existing_context=$(workspace_field "$conf_path" development_context "")
    existing_targets=$(workspace_field "$conf_path" targets "")
    existing_app_subpath=$(workspace_field "$conf_path" app_subpath "")
    existing_godot_subpath=$(workspace_field "$conf_path" godot_subpath "")
    existing_native_ir_path=$(workspace_field "$conf_path" native_ir_path "")
    needs_detection=0
    if [ "$existing_profile_kind" = "generic" ] || [ -z "$existing_targets" ]; then
      needs_detection=1
    elif [ "$existing_context" = "godot" ]; then
      needs_detection=0
    elif [ "$existing_context" = "native-desktop" ] && [ -n "$existing_native_ir_path" ]; then
      needs_detection=0
    elif [ "$existing_context" = "web" ] && [ -n "$existing_app_subpath" ]; then
      needs_detection=0
    elif [ "$existing_context" = "web" ] && [ -f "$workspace_path/index.html" ]; then
      needs_detection=0
    else
      needs_detection=1
    fi

    if [ "$needs_detection" -eq 1 ]; then
      detected_godot_subpath=$(detect_workspace_godot_subpath "$workspace_path" 2>/dev/null || true)
      detected_native_ir_path=$(detect_workspace_native_ir_path "$workspace_path" 2>/dev/null || true)
      detected_app_subpath=$(detect_workspace_app_subpath "$workspace_path" 2>/dev/null || true)
      if [ -n "$detected_godot_subpath" ]; then
        if [ "$existing_profile_kind" = "generic" ] || [ -z "$existing_targets" ] || [ "$existing_context" != "godot" ]; then
          write_key_value_file "$conf_path" project_type "game"
          write_key_value_file "$conf_path" development_context "godot"
          write_key_value_file "$conf_path" starter "import-godot"
          write_key_value_file "$conf_path" profile_kind "detected"
          write_key_value_file "$conf_path" targets "macos,linux,godot-desktop"
        fi
        if [ "$detected_godot_subpath" = "." ]; then
          if [ "$existing_godot_subpath" != "." ]; then
            write_key_value_file "$conf_path" godot_subpath "."
          fi
        elif [ "$existing_godot_subpath" != "$detected_godot_subpath" ]; then
          write_key_value_file "$conf_path" godot_subpath "$detected_godot_subpath"
        fi
      elif [ -n "$detected_native_ir_path" ] && [ "$existing_context" != "godot" ]; then
        if [ "$existing_profile_kind" = "generic" ] || [ -z "$existing_targets" ] || [ "$existing_context" != "native-desktop" ]; then
          write_key_value_file "$conf_path" project_type "native-desktop"
          write_key_value_file "$conf_path" development_context "native-desktop"
          write_key_value_file "$conf_path" starter "import-native-desktop"
          write_key_value_file "$conf_path" profile_kind "detected"
          write_key_value_file "$conf_path" targets "macos,linux"
        fi
        if [ "$existing_native_ir_path" != "$detected_native_ir_path" ]; then
          write_key_value_file "$conf_path" native_ir_path "$detected_native_ir_path"
        fi
      elif [ -n "$detected_app_subpath" ] && [ "$existing_context" != "godot" ]; then
        if [ "$existing_profile_kind" = "generic" ] || [ -z "$existing_targets" ] || [ -z "$existing_app_subpath" ]; then
          write_key_value_file "$conf_path" project_type "application"
          write_key_value_file "$conf_path" development_context "web"
          write_key_value_file "$conf_path" starter "import-web"
          write_key_value_file "$conf_path" profile_kind "detected"
          write_key_value_file "$conf_path" targets "hosted-web,macos,linux"
          if [ "$detected_app_subpath" != "." ]; then
            write_key_value_file "$conf_path" app_subpath "$detected_app_subpath"
          fi
        fi
      fi
    fi
    if [ -z "$(workspace_rebuild_command "$conf_path")" ]; then
      write_key_value_file "$conf_path" run_rebuild_command ":"
    fi
    printf '%s\t%s\n' "$conf_path" "0"
    return 0
  fi

  if [ ! -w "$workspace_path" ]; then
    printf '%s\n' "forge-backend: project profile missing and project is not writable: $workspace_path" >&2
    exit 1
  fi

  context=""
  project_type=""
  targets=""
  starter="import"
  profile_kind="detected"
  app_subpath=""
  native_ir_path=""
  if godot_subpath=$(detect_workspace_godot_subpath "$workspace_path" 2>/dev/null || true) && [ -n "$godot_subpath" ]; then
    context="godot"
    project_type="game"
    targets="macos,linux,godot-desktop"
    starter="import-godot"
  elif native_ir_path=$(detect_workspace_native_ir_path "$workspace_path" 2>/dev/null || true) && [ -n "$native_ir_path" ]; then
    context="native-desktop"
    project_type="native-desktop"
    targets="macos,linux"
    starter="import-native-desktop"
  elif app_subpath=$(detect_workspace_app_subpath "$workspace_path" 2>/dev/null || true) && [ -n "$app_subpath" ]; then
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
# Wizardry Apps project profile
project_id=$project_id
title=$project_title
project_type=$project_type
development_context=$context
starter=$starter
profile_kind=$profile_kind
targets=$targets
root=$workspace_path
CONF
  if [ -n "$app_subpath" ] && [ "$app_subpath" != "." ]; then
    printf 'app_subpath=%s\n' "$app_subpath" >>"$conf_path"
  fi
  if [ -n "$godot_subpath" ]; then
    printf 'godot_subpath=%s\n' "$godot_subpath" >>"$conf_path"
  fi
  if [ -n "$native_ir_path" ]; then
    printf 'native_ir_path=%s\n' "$native_ir_path" >>"$conf_path"
  fi
  printf 'run_rebuild_command=%s\n' ":" >>"$conf_path"

  printf '%s\t%s\n' "$conf_path" "1"
}

forge_ui_prefs_file() {
  base="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps"
  mkdir -p "$base"
  printf '%s\n' "$base/forge-ui.conf"
}

forge_workspace_git_state_dir() {
  base="${XDG_STATE_HOME:-$HOME/.local/state}/wizardry-apps/forge/git"
  mkdir -p "$base/cache" "$base/releases"
  printf '%s\n' "$base"
}

workspace_git_state_key() {
  workspace_path=${1-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace_git_state_key requires WORKSPACE_PATH" >&2
    exit 2
  }
  printf '%s' "$workspace_path" | hash_stdin_sha256
}

workspace_git_state_file() {
  workspace_path=${1-}
  printf '%s/%s.conf\n' "$(forge_workspace_git_state_dir)/cache" "$(workspace_git_state_key "$workspace_path")"
}

workspace_git_release_dir() {
  workspace_path=${1-}
  dir="$(forge_workspace_git_state_dir)/releases/$(workspace_git_state_key "$workspace_path")"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

validate_release_asset_name() {
  asset_name=${1-}
  clean_name=$(printf '%s' "$asset_name" | tr -d '\r\n')

  [ -n "$asset_name" ] || {
    printf '%s\n' "forge-backend: release asset name missing" >&2
    exit 1
  }

  [ "$clean_name" = "$asset_name" ] || {
    printf '%s\n' "forge-backend: invalid release asset name: $asset_name" >&2
    exit 1
  }

  case "$asset_name" in
    .|..|/*|*/*|*\\*)
      printf '%s\n' "forge-backend: invalid release asset name: $asset_name" >&2
      exit 1
      ;;
  esac
}

workspace_git_cached_value() {
  workspace_path=${1-}
  key=${2-}
  state_file=$(workspace_git_state_file "$workspace_path")
  if [ -f "$state_file" ]; then
    workspace_field "$state_file" "$key" ""
    return 0
  fi
  printf '%s\n' ""
}

workspace_git_cached_value_file() {
  state_file=${1-}
  key=${2-}
  if [ -f "$state_file" ]; then
    workspace_field "$state_file" "$key" ""
    return 0
  fi
  printf '%s\n' ""
}

workspace_git_state_write() {
  workspace_path=${1-}
  key=${2-}
  value=${3-}
  state_file=$(workspace_git_state_file "$workspace_path")
  [ -f "$state_file" ] || : > "$state_file"
  write_key_value_file "$state_file" "$key" "$(printf '%s' "${value-}" | tr '\r\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
}

workspace_git_browser_url_from_remote() {
  remote_url=${1-}
  has_line_break "$remote_url" && {
    printf '%s\n' ""
    return 0
  }
  case "$remote_url" in
    https://github.com/*|http://github.com/*)
      repo_path=${remote_url#https://github.com/}
      repo_path=${repo_path#http://github.com/}
      repo_path=$(printf '%s' "$repo_path" | sed 's#\.git$##')
      if valid_github_slug "$repo_path"; then
        printf 'https://github.com/%s\n' "$repo_path"
      else
        printf '%s\n' ""
      fi
      return 0
      ;;
    git@github.com:*)
      repo_path=${remote_url#git@github.com:}
      repo_path=$(printf '%s' "$repo_path" | sed 's#\.git$##')
      if valid_github_slug "$repo_path"; then
        printf 'https://github.com/%s\n' "$repo_path"
      else
        printf '%s\n' ""
      fi
      return 0
      ;;
    ssh://git@github.com/*)
      repo_path=${remote_url#ssh://git@github.com/}
      repo_path=$(printf '%s' "$repo_path" | sed 's#\.git$##')
      if valid_github_slug "$repo_path"; then
        printf 'https://github.com/%s\n' "$repo_path"
      else
        printf '%s\n' ""
      fi
      return 0
      ;;
    https://*|http://*)
      printf '%s\n' "$(printf '%s' "$remote_url" | sed 's#\.git$##')"
      return 0
      ;;
  esac
  printf '%s\n' ""
}

valid_github_slug() {
  slug=${1-}
  case "$slug" in
    */*) ;;
    *) return 1 ;;
  esac
  owner=${slug%%/*}
  repo=${slug#*/}
  case "$repo" in
    */*) return 1 ;;
  esac
  case "$owner" in
    ""|.|..|*..*|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  case "$repo" in
    ""|.|..|*..*|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  return 0
}

workspace_git_github_slug_from_remote() {
  remote_url=${1-}
  has_line_break "$remote_url" && {
    printf '%s\n' ""
    return 0
  }
  case "$remote_url" in
    https://github.com/*|http://github.com/*)
      repo_path=${remote_url#https://github.com/}
      repo_path=${repo_path#http://github.com/}
      repo_path=$(printf '%s' "$repo_path" | sed 's#\.git$##')
      valid_github_slug "$repo_path" && printf '%s\n' "$repo_path" || printf '%s\n' ""
      return 0
      ;;
    git@github.com:*)
      repo_path=${remote_url#git@github.com:}
      repo_path=$(printf '%s' "$repo_path" | sed 's#\.git$##')
      valid_github_slug "$repo_path" && printf '%s\n' "$repo_path" || printf '%s\n' ""
      return 0
      ;;
    ssh://git@github.com/*)
      repo_path=${remote_url#ssh://git@github.com/}
      repo_path=$(printf '%s' "$repo_path" | sed 's#\.git$##')
      valid_github_slug "$repo_path" && printf '%s\n' "$repo_path" || printf '%s\n' ""
      return 0
      ;;
  esac
  printf '%s\n' ""
}

workspace_git_repo_exists() {
  workspace_path=${1-}
  command -v git >/dev/null 2>&1 || return 1
  git -C "$workspace_path" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

workspace_git_repo_root() {
  workspace_path=${1-}
  git -C "$workspace_path" rev-parse --show-toplevel 2>/dev/null || true
}

workspace_git_current_branch() {
  workspace_path=${1-}
  branch=$(git -C "$workspace_path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -n "$branch" ]; then
    printf '%s\n' "$branch"
    return 0
  fi
  branch=$(git -C "$workspace_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  case "$branch" in
    ""|HEAD)
      printf '%s\n' ""
      ;;
    *)
      printf '%s\n' "$branch"
      ;;
  esac
}

workspace_git_head_commit() {
  workspace_path=${1-}
  git -C "$workspace_path" rev-parse HEAD 2>/dev/null || true
}

workspace_git_head_short() {
  workspace_path=${1-}
  git -C "$workspace_path" rev-parse --short HEAD 2>/dev/null || true
}

workspace_git_default_base_branch() {
  workspace_path=${1-}
  remote_head=$(git -C "$workspace_path" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  case "$remote_head" in
    origin/*)
      printf '%s\n' "${remote_head#origin/}"
      return 0
      ;;
  esac
  if git -C "$workspace_path" show-ref --verify --quiet refs/heads/main; then
    printf '%s\n' "main"
    return 0
  fi
  if git -C "$workspace_path" show-ref --verify --quiet refs/heads/master; then
    printf '%s\n' "master"
    return 0
  fi
  printf '%s\n' "main"
}

workspace_git_fetch_origin() {
  workspace_path=${1-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace_git_fetch_origin requires WORKSPACE_PATH" >&2
    exit 2
  }
  command -v git >/dev/null 2>&1 || {
    printf '%s\n' "forge-backend: git not available on PATH" >&2
    exit 1
  }
  git -C "$workspace_path" remote get-url origin >/dev/null 2>&1 || {
    printf '%s\n' "forge-backend: origin remote is not configured" >&2
    exit 1
  }
  GIT_TERMINAL_PROMPT=0 git -C "$workspace_path" fetch --quiet --prune origin
}

workspace_git_sync_label() {
  pill_state=${1-}
  case "$pill_state" in
    check_git) printf '%s\n' "No Remote" ;;
    sync) printf '%s\n' "Sync" ;;
    push) printf '%s\n' "Push" ;;
    update) printf '%s\n' "Update" ;;
    current) printf '%s\n' "Current" ;;
    *) printf '%s\n' "" ;;
  esac
}

workspace_git_collect_release_info() {
  workspace_path=${1-}
  github_slug=${2-}
  refresh_release=${3-0}
  state_file=$(workspace_git_state_file "$workspace_path")
  now_epoch=$(date +%s 2>/dev/null || printf '0')
  if [ -z "$github_slug" ]; then
    printf 'git_release_check_epoch=%s\n' ""
    printf 'git_release_name=%s\n' ""
    printf 'git_release_tag=%s\n' ""
    printf 'git_release_url=%s\n' ""
    printf 'git_release_published_at=%s\n' ""
    printf 'git_release_asset_name=%s\n' ""
    printf 'git_release_asset_url=%s\n' ""
    printf 'git_release_install_supported=%s\n' "no"
    printf 'git_release_install_reason=%s\n' ""
    printf 'git_release_available=%s\n' "no"
    printf 'git_release_error=%s\n' ""
    return 0
  fi

  release_check_epoch=$(workspace_git_cached_value_file "$state_file" release_check_epoch)
  release_name=$(workspace_git_cached_value_file "$state_file" release_name)
  release_tag=$(workspace_git_cached_value_file "$state_file" release_tag)
  release_html_url=$(workspace_git_cached_value_file "$state_file" release_html_url)
  release_published_at=$(workspace_git_cached_value_file "$state_file" release_published_at)
  release_asset_name=$(workspace_git_cached_value_file "$state_file" release_asset_name)
  release_asset_url=$(workspace_git_cached_value_file "$state_file" release_asset_url)
  release_install_supported=$(workspace_git_cached_value_file "$state_file" release_install_supported)
  release_install_reason=$(workspace_git_cached_value_file "$state_file" release_install_reason)
  release_available=$(workspace_git_cached_value_file "$state_file" release_available)
  release_error=$(workspace_git_cached_value_file "$state_file" release_error)

  if [ "$refresh_release" = "1" ] &&
     command -v curl >/dev/null 2>&1 &&
     command -v jq >/dev/null 2>&1; then
    api_url="https://api.github.com/repos/$github_slug/releases/latest"
    release_json=$(curl -fsSL -H "Accept: application/vnd.github+json" "$api_url" 2>/dev/null || true)
    if [ -n "$release_json" ]; then
      release_name=$(printf '%s' "$release_json" | jq -r '.name // ""' 2>/dev/null || true)
      release_tag=$(printf '%s' "$release_json" | jq -r '.tag_name // ""' 2>/dev/null || true)
      release_html_url=$(printf '%s' "$release_json" | jq -r '.html_url // ""' 2>/dev/null || true)
      release_published_at=$(printf '%s' "$release_json" | jq -r '.published_at // ""' 2>/dev/null || true)
      release_asset_name=''
      release_asset_url=''
      release_install_supported='no'
      release_install_reason='No supported release asset was found for this host.'
      release_error=''
      os_name=$(os_id)
      candidate_summary=$(printf '%s' "$release_json" | jq -r --arg os "$os_name" '
        [
          .assets[]?
          | { name: (.name // ""), url: (.browser_download_url // ""), lower: ((.name // "") | ascii_downcase) }
          | select(
              ($os == "darwin"
                and (.lower | test("(macos|darwin|osx|mac|universal)"))
                and ((.lower | endswith(".zip")) or (.lower | endswith(".tar.gz")) or (.lower | endswith(".tgz"))))
              or
              ($os == "linux"
                and (.lower | endswith(".appimage")))
            )
        ] as $matches
        | [($matches | length), ($matches[0].name // ""), ($matches[0].url // "")]
        | @tsv
      ' 2>/dev/null || true)
      candidate_count=$(printf '%s' "$candidate_summary" | awk -F'\t' 'NF { print $1; exit }')
      selected_name=$(printf '%s' "$candidate_summary" | awk -F'\t' 'NF { print $2; exit }')
      selected_url=$(printf '%s' "$candidate_summary" | awk -F'\t' 'NF { print $3; exit }')
      candidate_count=${candidate_count:-0}

      if [ "$candidate_count" -eq 1 ] && [ -n "$selected_name" ] && [ -n "$selected_url" ]; then
        release_asset_name=$selected_name
        release_asset_url=$selected_url
        release_install_supported='yes'
        release_install_reason=''
      elif [ "$candidate_count" -gt 1 ]; then
        release_asset_name=''
        release_asset_url=''
        release_install_supported='no'
        release_install_reason='Multiple release assets matched this host. Pick one manually on GitHub.'
      fi

      release_available='no'
      if [ "$release_install_supported" = "yes" ] && [ -n "$release_tag" ]; then
        current_tag=$(git -C "$workspace_path" describe --tags --exact-match HEAD 2>/dev/null || true)
        if [ "$current_tag" != "$release_tag" ]; then
          release_available='yes'
        fi
      fi

      workspace_git_state_write "$workspace_path" release_check_epoch "$now_epoch"
      workspace_git_state_write "$workspace_path" release_name "$release_name"
      workspace_git_state_write "$workspace_path" release_tag "$release_tag"
      workspace_git_state_write "$workspace_path" release_html_url "$release_html_url"
      workspace_git_state_write "$workspace_path" release_published_at "$release_published_at"
      workspace_git_state_write "$workspace_path" release_asset_name "$release_asset_name"
      workspace_git_state_write "$workspace_path" release_asset_url "$release_asset_url"
      workspace_git_state_write "$workspace_path" release_install_supported "$release_install_supported"
      workspace_git_state_write "$workspace_path" release_install_reason "$release_install_reason"
      workspace_git_state_write "$workspace_path" release_available "$release_available"
      workspace_git_state_write "$workspace_path" release_error "$release_error"

      release_check_epoch=$(workspace_git_cached_value_file "$state_file" release_check_epoch)
      release_name=$(workspace_git_cached_value_file "$state_file" release_name)
      release_tag=$(workspace_git_cached_value_file "$state_file" release_tag)
      release_html_url=$(workspace_git_cached_value_file "$state_file" release_html_url)
      release_published_at=$(workspace_git_cached_value_file "$state_file" release_published_at)
      release_asset_name=$(workspace_git_cached_value_file "$state_file" release_asset_name)
      release_asset_url=$(workspace_git_cached_value_file "$state_file" release_asset_url)
      release_install_supported=$(workspace_git_cached_value_file "$state_file" release_install_supported)
      release_install_reason=$(workspace_git_cached_value_file "$state_file" release_install_reason)
      release_available=$(workspace_git_cached_value_file "$state_file" release_available)
      release_error=$(workspace_git_cached_value_file "$state_file" release_error)
    else
      workspace_git_state_write "$workspace_path" release_check_epoch "$now_epoch"
      workspace_git_state_write "$workspace_path" release_error "GitHub latest release could not be loaded."
      release_check_epoch=$now_epoch
      release_error='GitHub latest release could not be loaded.'
    fi
  fi

  printf 'git_release_check_epoch=%s\n' "$release_check_epoch"
  printf 'git_release_name=%s\n' "$(kv_output_value "$release_name")"
  printf 'git_release_tag=%s\n' "$(kv_output_value "$release_tag")"
  printf 'git_release_url=%s\n' "$(kv_output_value "$release_html_url")"
  printf 'git_release_published_at=%s\n' "$(kv_output_value "$release_published_at")"
  printf 'git_release_asset_name=%s\n' "$(kv_output_value "$release_asset_name")"
  printf 'git_release_asset_url=%s\n' "$(kv_output_value "$release_asset_url")"
  printf 'git_release_install_supported=%s\n' "${release_install_supported:-no}"
  printf 'git_release_install_reason=%s\n' "$(kv_output_value "$release_install_reason")"
  printf 'git_release_available=%s\n' "${release_available:-no}"
  printf 'git_release_error=%s\n' "$(kv_output_value "$release_error")"
}

workspace_git_collect_status() {
  workspace_path=${1-}
  refresh_remote=${2-0}
  refresh_release=${3-0}

  git_available='no'
  git_repo_present='no'
  git_repo_root=''
  git_remote_origin=''
  git_remote_browser_url=''
  git_github_slug=''
  git_branch=''
  git_head=''
  git_head_short=''
  git_dirty='no'
  git_upstream=''
  git_upstream_present='no'
  git_ahead='0'
  git_behind='0'
  git_diverged='no'
  git_status_label=''
  git_status_tone='muted'
  git_status_reason=''
  git_last_checked_epoch=$(date +%s 2>/dev/null || printf '0')
  git_last_fetch_epoch=''
  git_last_fetch_error=''
  git_has_release='no'

  if command -v git >/dev/null 2>&1; then
    git_available='yes'
  fi

  state_file=$(workspace_git_state_file "$workspace_path")
  git_last_fetch_epoch=$(workspace_git_cached_value_file "$state_file" remote_check_epoch)
  git_last_fetch_error=$(workspace_git_cached_value_file "$state_file" remote_check_error)

  if [ "$git_available" != 'yes' ]; then
    printf 'git_available=%s\n' "$git_available"
    printf 'git_repo_present=%s\n' "$git_repo_present"
    printf 'git_status_label=%s\n' ""
    printf 'git_status_tone=%s\n' "$git_status_tone"
    printf 'git_status_reason=%s\n' "git is not available on this machine."
    printf 'git_last_checked_epoch=%s\n' "$git_last_checked_epoch"
    workspace_git_collect_release_info "$workspace_path" "" "0"
    return 0
  fi

  if ! workspace_git_repo_exists "$workspace_path"; then
    printf 'git_available=%s\n' "$git_available"
    printf 'git_repo_present=%s\n' "$git_repo_present"
    printf 'git_status_label=%s\n' ""
    printf 'git_status_tone=%s\n' "$git_status_tone"
    printf 'git_status_reason=%s\n' ""
    printf 'git_last_checked_epoch=%s\n' "$git_last_checked_epoch"
    workspace_git_collect_release_info "$workspace_path" "" "0"
    return 0
  fi

  git_repo_present='yes'
  git_repo_root=$(workspace_git_repo_root "$workspace_path")
  git_remote_origin=$(git -C "$workspace_path" remote get-url origin 2>/dev/null || true)
  git_remote_browser_url=$(workspace_git_browser_url_from_remote "$git_remote_origin")
  git_github_slug=$(workspace_git_github_slug_from_remote "$git_remote_origin")
  git_branch=$(workspace_git_current_branch "$workspace_path")
  git_head=$(workspace_git_head_commit "$workspace_path")
  git_head_short=$(workspace_git_head_short "$workspace_path")
  if [ -n "$(git -C "$workspace_path" status --porcelain 2>/dev/null || true)" ]; then
    git_dirty='yes'
  fi

  if [ "$refresh_remote" = "1" ] && [ -n "$git_remote_origin" ]; then
    if workspace_git_fetch_origin "$workspace_path" >/dev/null 2>&1; then
      git_last_fetch_epoch=$(date +%s 2>/dev/null || printf '0')
      git_last_fetch_error=''
      workspace_git_state_write "$workspace_path" remote_check_epoch "$git_last_fetch_epoch"
      workspace_git_state_write "$workspace_path" remote_check_error ""
    else
      git_last_fetch_epoch=$(date +%s 2>/dev/null || printf '0')
      git_last_fetch_error='Fetch from origin failed.'
      workspace_git_state_write "$workspace_path" remote_check_epoch "$git_last_fetch_epoch"
      workspace_git_state_write "$workspace_path" remote_check_error "$git_last_fetch_error"
    fi
  fi

  git_upstream=$(git -C "$workspace_path" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
  if [ -n "$git_upstream" ]; then
    git_upstream_present='yes'
  elif [ -n "$git_branch" ] && git -C "$workspace_path" show-ref --verify --quiet "refs/remotes/origin/$git_branch"; then
    git_upstream="origin/$git_branch"
    git_upstream_present='yes'
  fi

  if [ -n "$git_head" ] && [ "$git_upstream_present" = 'yes' ]; then
    ahead_behind=$(git -C "$workspace_path" rev-list --left-right --count "HEAD...$git_upstream" 2>/dev/null || printf '0 0')
    git_ahead=$(printf '%s' "$ahead_behind" | awk '{print $1}')
    git_behind=$(printf '%s' "$ahead_behind" | awk '{print $2}')
  else
    git_ahead='0'
    git_behind='0'
  fi

  case "${git_ahead:-0}:${git_behind:-0}" in
    [1-9]*:[1-9]*|[1-9][0-9]*:[1-9][0-9]*)
      git_diverged='yes'
      ;;
  esac

  release_info=$(workspace_git_collect_release_info "$workspace_path" "$git_github_slug" "$refresh_release")
  git_release_available=$(printf '%s\n' "$release_info" | kv_read git_release_available)
  if [ "$git_release_available" = 'yes' ]; then
    git_has_release='yes'
  fi

  if [ -n "$git_last_fetch_error" ] || { [ -z "$git_remote_origin" ] && [ -n "$git_repo_root" ]; }; then
    git_status_label='No Remote'
    git_status_tone='bad'
    if [ -n "$git_last_fetch_error" ]; then
      git_status_reason=$git_last_fetch_error
    else
      git_status_reason='origin is not configured for this repo yet.'
    fi
  elif [ "$git_diverged" = 'yes' ] || { [ "${git_behind:-0}" -gt 0 ] && { [ "${git_ahead:-0}" -gt 0 ] || [ "$git_dirty" = 'yes' ]; }; }; then
    git_status_label='Conflict'
    git_status_tone='bad'
    git_status_reason='Local and remote changes both need reconciliation before the repo is current.'
  elif [ "$git_dirty" = 'yes' ] || [ "${git_ahead:-0}" -gt 0 ] || { [ -n "$git_remote_origin" ] && [ "$git_upstream_present" != 'yes' ]; }; then
    git_status_label='Push'
    git_status_tone='ok'
    if [ "$git_dirty" = 'yes' ]; then
      git_status_reason='Local code changes are ready to review and push.'
    elif [ "${git_ahead:-0}" -gt 0 ]; then
      git_status_reason='Local commits are ahead of origin.'
    else
      git_status_reason='The current branch is not tracking origin yet.'
    fi
  elif [ "${git_behind:-0}" -gt 0 ] || [ "$git_has_release" = 'yes' ]; then
    git_status_label='Update'
    git_status_tone='working'
    if [ "${git_behind:-0}" -gt 0 ]; then
      git_status_reason='Upstream code changes are available to pull.'
    else
      git_status_reason='A newer GitHub release is available for this host.'
    fi
  else
    git_status_label='Current'
    git_status_tone='ok'
    git_status_reason='The repo is clean and up to date.'
  fi

  printf 'git_available=%s\n' "$git_available"
  printf 'git_repo_present=%s\n' "$git_repo_present"
  printf 'git_repo_root=%s\n' "$(kv_output_value "$git_repo_root")"
  printf 'git_remote_origin=%s\n' "$(kv_output_value "$git_remote_origin")"
  printf 'git_remote_browser_url=%s\n' "$(kv_output_value "$git_remote_browser_url")"
  printf 'git_github_slug=%s\n' "$(kv_output_value "$git_github_slug")"
  printf 'git_branch=%s\n' "$(kv_output_value "$git_branch")"
  printf 'git_head=%s\n' "$git_head"
  printf 'git_head_short=%s\n' "$git_head_short"
  printf 'git_dirty=%s\n' "$git_dirty"
  printf 'git_upstream=%s\n' "$(kv_output_value "$git_upstream")"
  printf 'git_upstream_present=%s\n' "$git_upstream_present"
  printf 'git_ahead=%s\n' "$git_ahead"
  printf 'git_behind=%s\n' "$git_behind"
  printf 'git_diverged=%s\n' "$git_diverged"
  printf 'git_status_label=%s\n' "$(kv_output_value "$git_status_label")"
  printf 'git_status_tone=%s\n' "$git_status_tone"
  printf 'git_status_reason=%s\n' "$(kv_output_value "$git_status_reason")"
  printf 'git_last_checked_epoch=%s\n' "$git_last_checked_epoch"
  printf 'git_last_fetch_epoch=%s\n' "$git_last_fetch_epoch"
  printf 'git_last_fetch_error=%s\n' "$(kv_output_value "$git_last_fetch_error")"
  printf '%s\n' "$release_info"
}

ui_pref_key_is_valid() {
  key=${1-}
  case "$key" in
    [a-z0-9]*)
      ;;
    *)
      return 1
      ;;
  esac

  case "$key" in
    *[!a-z0-9._-]*)
      return 1
      ;;
  esac
  return 0
}

validate_ui_pref_key() {
  key=${1-}
  if ! ui_pref_key_is_valid "$key"; then
    printf '%s\n' "forge-backend: invalid UI pref key: $key" >&2
    exit 2
  fi
}

sanitize_ui_pref_value() {
  value=${1-}
  printf '%s' "$value" | tr '\r\n' ' '
}

cmd_get_ui_prefs() {
  prefs_file=$(forge_ui_prefs_file)
  [ -f "$prefs_file" ] || exit 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *=*)
        key=${line%%=*}
        value=${line#*=}
        ui_pref_key_is_valid "$key" || continue
        printf '%s=%s\n' "$key" "$(sanitize_ui_pref_value "$value")"
        ;;
    esac
  done <"$prefs_file"
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
  printf 'file=%s\n' "$(kv_output_value "$prefs_file")"
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

    profile_kind=$(workspace_field "$conf" profile_kind "")
    profile_targets=$(workspace_field "$conf" targets "")
    profile_context=$(workspace_field "$conf" development_context "")
    profile_rebuild=$(workspace_rebuild_command "$conf")
    profile_app_subpath=$(workspace_field "$conf" app_subpath "")
    profile_godot_subpath=$(workspace_field "$conf" godot_subpath "")
    needs_profile_repair=0
    if [ "$profile_kind" = "generic" ] || [ -z "$profile_targets" ] || [ -z "$profile_rebuild" ]; then
      needs_profile_repair=1
    elif [ "$profile_context" = "web" ] && [ -z "$profile_app_subpath" ] && [ ! -f "$path/index.html" ]; then
      needs_profile_repair=1
    elif [ "$profile_context" = "godot" ] && [ -z "$profile_godot_subpath" ] && [ ! -f "$path/project.godot" ] && [ ! -f "$path/tool_main.gd" ]; then
      needs_profile_repair=1
    elif [ "$profile_context" = "native-desktop" ] && ! resolve_workspace_native_ir_path "$path" "$conf" >/dev/null 2>&1; then
      needs_profile_repair=1
    fi
    if [ "$needs_profile_repair" -eq 1 ]; then
      ensure_importable_workspace_profile "$path" >/dev/null 2>&1 || true
    fi

    project_id=$(workspace_field "$conf" project_id "")
    [ -n "$project_id" ] || project_id=$(workspace_field "$conf" slug "")
    if ! is_valid_slug_value "$project_id"; then
      project_id=$(derive_workspace_slug "$(basename "$path")")
    fi

    title=$(workspace_field "$conf" title "")
    [ -n "$title" ] || title=$(workspace_field "$conf" name "$project_id")

    project_type=$(workspace_field "$conf" project_type "application")

    development_context=$(workspace_field "$conf" development_context "web")

    targets=$(workspace_field "$conf" targets "")
    runnable=0
    case "$development_context" in
      godot)
        if resolve_workspace_godot_subpath "$path" "$conf" >/dev/null 2>&1; then
          runnable=1
        fi
        ;;
      native-desktop)
        if resolve_workspace_native_ir_path "$path" "$conf" >/dev/null 2>&1; then
          runnable=1
        fi
        ;;
      *)
        if resolve_workspace_app_dir "$path" "$conf" >/dev/null 2>&1; then
          runnable=1
        fi
        ;;
    esac
    git_info=$(workspace_git_collect_status "$path" "0" "0")
    git_repo_present=$(printf '%s\n' "$git_info" | kv_read git_repo_present)
    git_status_label=$(printf '%s\n' "$git_info" | kv_read git_status_label)
    git_status_tone=$(printf '%s\n' "$git_info" | kv_read git_status_tone)
    git_status_reason=$(printf '%s\n' "$git_info" | kv_read git_status_reason)
    git_release_available=$(printf '%s\n' "$git_info" | kv_read git_release_available)
    mtime_epoch=$(path_mtime_epoch "$path")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(tsv_output_value "$project_id")" \
      "$(tsv_output_value "$title")" \
      "$(tsv_output_value "$project_type")" \
      "$(tsv_output_value "$development_context")" \
      "$(tsv_output_value "$targets")" \
      "$(tsv_output_value "$path")" \
      "$mtime_epoch" \
      "$runnable" \
      "$(tsv_output_value "$git_repo_present")" \
      "$(tsv_output_value "$git_status_label")" \
      "$(tsv_output_value "$git_status_tone")" \
      "$(tsv_output_value "$git_status_reason")" \
      "$(tsv_output_value "$git_release_available")"
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
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }

  [ -n "$project_root" ] || project_root=$(workspace_default_root)
  reject_line_breaks "$project_root" "project root"
  project_root_abs=$(ensure_dir_path "$project_root")
  reject_line_breaks "$project_root_abs" "project root"

  profile_meta=$(ensure_importable_workspace_profile "$workspace_abs")
  profile_path=$(printf '%s\n' "$profile_meta" | cut -f1)
  profile_created=$(printf '%s\n' "$profile_meta" | cut -f2)
  project_title=$(workspace_field "$profile_path" title "$(basename "$workspace_abs")")
  project_context=$(workspace_field "$profile_path" development_context "web")
  write_imported_project_readme_if_missing "$workspace_abs" "$project_title" "$project_context"
  workspace_id=$(resolve_workspace_slug "$profile_path" "$workspace_abs")
  registered_path=""
  existing_registered_path=""

  for existing_path in "$project_root_abs"/*; do
    [ -d "$existing_path" ] || continue
    [ -f "$existing_path/wizardry.workspace.conf" ] || continue
    existing_target=$(resolve_existing_dir_path "$existing_path" 2>/dev/null || true)
    if [ -n "$existing_target" ] && [ "$existing_target" = "$workspace_abs" ]; then
      existing_registered_path="$existing_path"
      break
    fi
  done

  if [ -n "$existing_registered_path" ]; then
    registered_path="$existing_registered_path"
  fi

  if [ -z "$registered_path" ]; then
    workspace_parent=$(dirname "$workspace_abs")
    if [ "$workspace_parent" = "$project_root_abs" ]; then
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
  fi

  [ -n "$registered_path" ] || {
    printf '%s\n' "forge-backend: failed to register project: $workspace_abs" >&2
    exit 1
  }

  [ -f "$registered_path/wizardry.workspace.conf" ] || {
    printf '%s\n' "forge-backend: registered project is missing wizardry.workspace.conf: $registered_path" >&2
    exit 1
  }

  registration_mode="linked"
  if [ "$registered_path" = "$workspace_abs" ]; then
    registration_mode="direct"
  fi

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

cmd_get_workspace_profile() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: get-workspace-profile requires WORKSPACE_PATH" >&2
    exit 2
  }

  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"

  conf="$workspace_abs/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: project profile missing: $workspace_abs" >&2
    exit 1
  }

  git_info=$(workspace_git_collect_status "$workspace_abs" "1" "1")
  git_repo_present=$(printf '%s\n' "$git_info" | kv_read git_repo_present)
  git_remote_origin=$(printf '%s\n' "$git_info" | kv_read git_remote_origin)
  git_branch=$(printf '%s\n' "$git_info" | kv_read git_branch)
  if [ -n "$git_repo_present" ] && [ -n "$git_branch" ] && [ "$git_repo_present" = "yes" ]; then
    :
  elif [ "$git_repo_present" != "yes" ]; then
    git_branch=$(workspace_git_cached_value "$workspace_abs" default_branch)
    [ -n "$git_branch" ] || git_branch=main
  fi

  printf 'root_hint=%s\n' "$(kv_output_value "$root")"
  printf 'workspace=%s\n' "$(kv_output_value "$workspace_abs")"
  printf 'profile=%s\n' "$(kv_output_value "$conf")"
  profile_project_id=$(workspace_field "$conf" project_id "")
  [ -n "$profile_project_id" ] || profile_project_id=$(workspace_field "$conf" slug "")
  if ! is_valid_slug_value "$profile_project_id"; then
    profile_project_id=$(derive_workspace_slug "$(basename "$workspace_abs")")
  fi
  title_value=$(workspace_field "$conf" title "$(workspace_field "$conf" name "$(basename "$workspace_abs")")")
  printf 'project_id=%s\n' "$(kv_output_value "$profile_project_id")"
  printf 'title=%s\n' "$(kv_output_value "$title_value")"
  printf 'project_type=%s\n' "$(kv_output_value "$(workspace_field "$conf" project_type "application")")"
  printf 'development_context=%s\n' "$(kv_output_value "$(workspace_field "$conf" development_context "web")")"
  printf 'starter=%s\n' "$(kv_output_value "$(workspace_field "$conf" starter "")")"
  printf 'targets=%s\n' "$(kv_output_value "$(workspace_field "$conf" targets "")")"
  printf 'source=%s\n' "$(kv_output_value "$(workspace_field "$conf" source "")")"
  printf 'root=%s\n' "$(kv_output_value "$(workspace_field "$conf" root "$workspace_abs")")"
  printf 'profile_kind=%s\n' "$(kv_output_value "$(workspace_field "$conf" profile_kind "")")"
  printf 'app_subpath=%s\n' "$(kv_output_value "$(workspace_field "$conf" app_subpath "")")"
  printf 'native_ir_path=%s\n' "$(kv_output_value "$(workspace_field "$conf" native_ir_path "")")"
  printf 'hosted_web_mode=%s\n' "$(kv_output_value "$(workspace_field "$conf" hosted_web_mode "")")"
  printf 'hosted_web_site_name=%s\n' "$(kv_output_value "$(workspace_field "$conf" hosted_web_site_name "")")"
  printf 'hosted_web_serve_script=%s\n' "$(kv_output_value "$(workspace_field "$conf" hosted_web_serve_script "")")"
  printf 'hosted_web_serve_action=%s\n' "$(kv_output_value "$(workspace_field "$conf" hosted_web_serve_action "")")"
  printf 'run_rebuild_command=%s\n' "$(kv_output_value "$(workspace_rebuild_command "$conf")")"
  printf 'git_default_branch=%s\n' "$(kv_output_value "$git_branch")"
  printf '%s\n' "$git_info"
}

validate_git_branch_name() {
  branch_name=${1-}
  [ -n "$branch_name" ] || {
    printf '%s\n' "forge-backend: branch name is required" >&2
    exit 2
  }
  if command -v git >/dev/null 2>&1 && git check-ref-format --branch "$branch_name" >/dev/null 2>&1; then
    return 0
  fi
  case "$branch_name" in
    *".."*|*' '*|*~*|*^*|*:*|*\\*|*\?*|*\[*|*@\{*|*//*|/*|.|..)
      printf '%s\n' "forge-backend: invalid branch name '$branch_name'" >&2
      exit 2
      ;;
  esac
}

workspace_profile_path() {
  workspace_path=${1-}
  conf="$workspace_path/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: project profile missing: $workspace_path" >&2
    exit 1
  }
  printf '%s\n' "$conf"
}

workspace_profile_path_if_exists() {
  workspace_path=${1-}
  conf="$workspace_path/wizardry.workspace.conf"
  if [ -f "$conf" ]; then
    printf '%s\n' "$conf"
    return 0
  fi
  printf '%s\n' ""
}

cmd_workspace_git_status() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-status requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "1" "1")"
}

cmd_workspace_git_init() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  remote_url=${3-}
  branch_name=${4-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-init requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -n "$branch_name" ] || branch_name=main
  validate_git_branch_name "$branch_name"
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  [ -z "$remote_url" ] || reject_line_breaks "$remote_url" "remote URL"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  if workspace_git_repo_exists "$workspace_abs"; then
    printf '%s\n' "forge-backend: project already has a git repo" >&2
    exit 1
  fi

  if git -C "$workspace_abs" init -b "$branch_name" >/dev/null 2>&1; then
    :
  else
    git -C "$workspace_abs" init >/dev/null
    git -C "$workspace_abs" symbolic-ref HEAD "refs/heads/$branch_name" >/dev/null 2>&1 || true
  fi
  if [ -n "$remote_url" ]; then
    git -C "$workspace_abs" remote add origin "$remote_url" >/dev/null 2>&1 || git -C "$workspace_abs" remote set-url origin "$remote_url" >/dev/null 2>&1
  fi
  workspace_git_state_write "$workspace_abs" default_branch "$branch_name"

  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'status=ok\n'
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1")"
}

cmd_workspace_git_set_remote() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  remote_url=${3-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-set-remote requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -n "$remote_url" ] || {
    printf '%s\n' "forge-backend: workspace-git-set-remote requires REMOTE_URL" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  reject_line_breaks "$remote_url" "remote URL"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  workspace_git_repo_exists "$workspace_abs" || {
    printf '%s\n' "forge-backend: project does not have a git repo yet" >&2
    exit 1
  }
  if git -C "$workspace_abs" remote get-url origin >/dev/null 2>&1; then
    git -C "$workspace_abs" remote set-url origin "$remote_url"
  else
    git -C "$workspace_abs" remote add origin "$remote_url"
  fi
  workspace_git_state_write "$workspace_abs" remote_check_error ""
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'status=ok\n'
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1")"
}

cmd_workspace_git_set_branch() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  branch_name=${3-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-set-branch requires WORKSPACE_PATH" >&2
    exit 2
  }
  validate_git_branch_name "$branch_name"
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  workspace_git_repo_exists "$workspace_abs" || {
    printf '%s\n' "forge-backend: project does not have a git repo yet" >&2
    exit 1
  }

  current_head=$(workspace_git_head_commit "$workspace_abs")
  if git -C "$workspace_abs" show-ref --verify --quiet "refs/heads/$branch_name"; then
    git -C "$workspace_abs" checkout "$branch_name" >/dev/null
  elif git -C "$workspace_abs" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
    git -C "$workspace_abs" checkout -B "$branch_name" --track "origin/$branch_name" >/dev/null
  elif [ -n "$current_head" ]; then
    git -C "$workspace_abs" checkout -b "$branch_name" >/dev/null
  else
    git -C "$workspace_abs" symbolic-ref HEAD "refs/heads/$branch_name" >/dev/null 2>&1 || true
  fi
  workspace_git_state_write "$workspace_abs" default_branch "$branch_name"

  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'status=ok\n'
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1")"
}

cmd_workspace_git_fetch() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-fetch requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  workspace_git_repo_exists "$workspace_abs" || {
    printf '%s\n' "forge-backend: project does not have a git repo yet" >&2
    exit 1
  }
  workspace_git_fetch_origin "$workspace_abs"
  workspace_git_state_write "$workspace_abs" remote_check_epoch "$(date +%s 2>/dev/null || printf '0')"
  workspace_git_state_write "$workspace_abs" remote_check_error ""
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'status=ok\n'
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1")"
}

cmd_workspace_git_pull() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-pull requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  workspace_git_repo_exists "$workspace_abs" || {
    printf '%s\n' "forge-backend: project does not have a git repo yet" >&2
    exit 1
  }
  if [ -n "$(git -C "$workspace_abs" status --porcelain 2>/dev/null || true)" ]; then
    printf '%s\n' "forge-backend: commit or stash local changes before pull" >&2
    exit 1
  fi

  branch_name=$(workspace_git_current_branch "$workspace_abs")
  [ -n "$branch_name" ] || branch_name=$(workspace_git_cached_value "$workspace_abs" default_branch)
  [ -n "$branch_name" ] || branch_name=main
  workspace_git_fetch_origin "$workspace_abs"
  workspace_git_state_write "$workspace_abs" remote_check_epoch "$(date +%s 2>/dev/null || printf '0')"
  workspace_git_state_write "$workspace_abs" remote_check_error ""

  if [ -z "$(workspace_git_head_commit "$workspace_abs")" ] && git -C "$workspace_abs" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
    git -C "$workspace_abs" checkout -B "$branch_name" "origin/$branch_name" >/dev/null
  else
    if ! git -C "$workspace_abs" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1 && git -C "$workspace_abs" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
      git -C "$workspace_abs" branch --set-upstream-to "origin/$branch_name" "$branch_name" >/dev/null 2>&1 || true
    fi
    GIT_TERMINAL_PROMPT=0 git -C "$workspace_abs" pull --ff-only origin "$branch_name"
  fi

  if [ -n "$conf" ]; then
    rebuild_out=$(run_workspace_rebuild "$root" "$workspace_abs" "$conf")
  else
    rebuild_out=$(printf 'status=noop\nmode=none\n')
  fi

  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'status=ok\n'
  printf '%s\n' "$rebuild_out"
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1")"
}

cmd_workspace_git_push() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-push requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  workspace_git_repo_exists "$workspace_abs" || {
    printf '%s\n' "forge-backend: project does not have a git repo yet" >&2
    exit 1
  }
  if [ -n "$(git -C "$workspace_abs" status --porcelain 2>/dev/null || true)" ]; then
    printf '%s\n' "forge-backend: commit local changes before push" >&2
    exit 1
  fi

  git_info=$(workspace_git_collect_status "$workspace_abs" "1" "0")
  git_diverged=$(printf '%s\n' "$git_info" | kv_read git_diverged)
  git_behind=$(printf '%s\n' "$git_info" | kv_read git_behind)
  branch_name=$(printf '%s\n' "$git_info" | kv_read git_branch)
  [ -n "$branch_name" ] || {
    printf '%s\n' "forge-backend: current branch could not be determined" >&2
    exit 1
  }
  if [ "$git_diverged" = 'yes' ] || [ "${git_behind:-0}" -gt 0 ]; then
    printf '%s\n' "forge-backend: pull and resolve upstream changes before push" >&2
    exit 1
  fi

  if git -C "$workspace_abs" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    GIT_TERMINAL_PROMPT=0 git -C "$workspace_abs" push origin "$branch_name"
  else
    GIT_TERMINAL_PROMPT=0 git -C "$workspace_abs" push -u origin "$branch_name"
  fi
  workspace_git_state_write "$workspace_abs" remote_check_epoch "$(date +%s 2>/dev/null || printf '0')"
  workspace_git_state_write "$workspace_abs" remote_check_error ""

  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'status=ok\n'
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1")"
}

cmd_workspace_git_repo_url() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-repo-url requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  git_info=$(workspace_git_collect_status "$workspace_abs" "0" "0")
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'remote_url=%s\n' "$(printf '%s\n' "$git_info" | kv_read git_remote_origin)"
  printf 'browser_url=%s\n' "$(printf '%s\n' "$git_info" | kv_read git_remote_browser_url)"
  printf 'github_slug=%s\n' "$(printf '%s\n' "$git_info" | kv_read git_github_slug)"
}

cmd_workspace_git_pr_url() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-pr-url requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  git_info=$(workspace_git_collect_status "$workspace_abs" "0" "1")
  github_slug=$(printf '%s\n' "$git_info" | kv_read git_github_slug)
  branch_name=$(printf '%s\n' "$git_info" | kv_read git_branch)
  [ -n "$github_slug" ] || {
    printf '%s\n' "forge-backend: PR URL is available for GitHub remotes only" >&2
    exit 1
  }
  [ -n "$branch_name" ] || {
    printf '%s\n' "forge-backend: current branch could not be determined" >&2
    exit 1
  }
  base_branch=$(workspace_git_default_base_branch "$workspace_abs")
  repo_url=$(workspace_git_browser_url_from_remote "$(printf '%s\n' "$git_info" | kv_read git_remote_origin)")
  pr_url="$repo_url/compare/$base_branch...$branch_name?expand=1"
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'repo_url=%s\n' "$repo_url"
  printf 'base_branch=%s\n' "$base_branch"
  printf 'branch=%s\n' "$branch_name"
  printf 'pr_url=%s\n' "$pr_url"
}

cmd_workspace_git_release() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-release requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf '%s\n' "$(workspace_git_collect_status "$workspace_abs" "0" "1" | awk -F= '/^git_release_/ { print }')"
}

cmd_workspace_git_install_release() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: workspace-git-install-release requires WORKSPACE_PATH" >&2
    exit 2
  }
  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf=$(workspace_profile_path_if_exists "$workspace_abs")
  git_info=$(workspace_git_collect_status "$workspace_abs" "1" "1")
  asset_url=$(printf '%s\n' "$git_info" | kv_read git_release_asset_url)
  asset_name=$(printf '%s\n' "$git_info" | kv_read git_release_asset_name)
  install_supported=$(printf '%s\n' "$git_info" | kv_read git_release_install_supported)
  install_reason=$(printf '%s\n' "$git_info" | kv_read git_release_install_reason)
  release_tag=$(printf '%s\n' "$git_info" | kv_read git_release_tag)
  github_slug=$(printf '%s\n' "$git_info" | kv_read git_github_slug)
  [ "$install_supported" = 'yes' ] || {
    printf '%s\n' "forge-backend: ${install_reason:-No supported release install flow is available.}" >&2
    exit 1
  }
  [ -n "$asset_url" ] || {
    printf '%s\n' "forge-backend: release asset URL missing" >&2
    exit 1
  }
  validate_release_asset_name "$asset_name"
  command -v curl >/dev/null 2>&1 || {
    printf '%s\n' "forge-backend: curl is required to install a GitHub release asset" >&2
    exit 1
  }

  release_dir=$(workspace_git_release_dir "$workspace_abs")
  workspace_slug=$(resolve_workspace_slug "$conf" "$workspace_abs")
  download_path="$release_dir/$asset_name"
  extract_dir="$release_dir/extracted"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  curl -fsSL "$asset_url" -o "$download_path"

  os_name=$(os_id)
  case "$os_name" in
    darwin)
      case "$asset_name" in
        *.zip)
          if command -v ditto >/dev/null 2>&1; then
            ditto -x -k "$download_path" "$extract_dir"
          elif command -v unzip >/dev/null 2>&1; then
            unzip -oq "$download_path" -d "$extract_dir" >/dev/null
          else
            printf '%s\n' "forge-backend: ditto or unzip is required to install macOS release archives" >&2
            exit 1
          fi
          ;;
        *.tar.gz|*.tgz)
          tar -xzf "$download_path" -C "$extract_dir"
          ;;
        *)
          printf '%s\n' "forge-backend: unsupported macOS release asset: $asset_name" >&2
          exit 1
          ;;
      esac
      app_bundle=$(find "$extract_dir" -type d -name '*.app' -print | head -n 1)
      [ -n "$app_bundle" ] || {
        printf '%s\n' "forge-backend: no macOS app bundle was found in the release archive" >&2
        exit 1
      }
      install_path="/Applications/$(basename "$app_bundle")"
      rm -rf "$install_path"
      if command -v ditto >/dev/null 2>&1; then
        ditto "$app_bundle" "$install_path"
      else
        cp -R "$app_bundle" "$install_path"
      fi
      printf 'root_hint=%s\n' "$root"
      printf 'workspace=%s\n' "$workspace_abs"
      printf 'profile=%s\n' "$conf"
      printf 'status=ok\n'
      printf 'github_slug=%s\n' "$github_slug"
      printf 'release_tag=%s\n' "$release_tag"
      printf 'asset=%s\n' "$download_path"
      printf 'installed=%s\n' "$install_path"
      ;;
    linux)
      case "$(printf '%s' "$asset_name" | tr '[:upper:]' '[:lower:]')" in
        *.appimage)
          install_root="$HOME/.local/share/wizardry-apps/$workspace_slug-release"
          launcher_dir="$HOME/.local/bin"
          launcher_path="$launcher_dir/wizardry-$workspace_slug-release"
          mkdir -p "$install_root" "$launcher_dir"
          install_path="$install_root/$asset_name"
          cp "$download_path" "$install_path"
          chmod +x "$install_path"
          cat > "$launcher_path" <<LAUNCHER
#!/bin/sh
set -eu
exec "$install_path" "\$@"
LAUNCHER
          chmod +x "$launcher_path"
          printf 'root_hint=%s\n' "$root"
          printf 'workspace=%s\n' "$workspace_abs"
          printf 'profile=%s\n' "$conf"
          printf 'status=ok\n'
          printf 'github_slug=%s\n' "$github_slug"
          printf 'release_tag=%s\n' "$release_tag"
          printf 'asset=%s\n' "$download_path"
          printf 'installed=%s\n' "$install_path"
          printf 'launcher=%s\n' "$launcher_path"
          ;;
        *)
          printf '%s\n' "forge-backend: unsupported Linux release asset: $asset_name" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      printf '%s\n' "forge-backend: release install is supported on macOS and Linux only" >&2
      exit 1
      ;;
  esac
}

pick_directory_under_workspace() {
  workspace_abs=$1
  prompt=${2-Choose folder}
  os_name=$(os_id)

  if [ "$os_name" = "darwin" ] && command -v osascript >/dev/null 2>&1; then
    osascript - "$workspace_abs" "$prompt" <<'OSA' 2>/dev/null || true
on run argv
  set defaultDir to POSIX file (item 1 of argv)
  set dialogPrompt to item 2 of argv
  try
    set chosenFolder to choose folder with prompt dialogPrompt default location defaultDir
    return POSIX path of chosenFolder
  on error number -128
    return ""
  end try
end run
OSA
    return 0
  fi

  if [ "$os_name" = "linux" ]; then
    if command -v zenity >/dev/null 2>&1; then
      zenity --file-selection --directory --filename="$workspace_abs/" --title="$prompt" 2>/dev/null || true
      return 0
    fi
    if command -v kdialog >/dev/null 2>&1; then
      kdialog --getexistingdirectory "$workspace_abs" --title "$prompt" 2>/dev/null || true
      return 0
    fi
  fi

  printf '%s\n' "forge-backend: no folder picker is available on this OS" >&2
  exit 1
}

cmd_pick_workspace_subpath() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: pick-workspace-subpath requires WORKSPACE_PATH" >&2
    exit 2
  }

  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"

  picked_path=$(pick_directory_under_workspace "$workspace_abs" "Choose app subpath")
  [ -n "$picked_path" ] || exit 0

  picked_abs=$(resolve_existing_dir_path "$picked_path" 2>/dev/null || true)
  [ -n "$picked_abs" ] || {
    printf '%s\n' "forge-backend: selected folder no longer exists" >&2
    exit 1
  }

  case "$picked_abs" in
    "$workspace_abs")
      relative="."
      ;;
    "$workspace_abs"/*)
      relative=${picked_abs#"$workspace_abs"/}
      ;;
    *)
      printf '%s\n' "forge-backend: selected folder must stay inside the project root" >&2
      exit 1
      ;;
  esac

  [ -f "$picked_abs/index.html" ] || {
    printf '%s\n' "forge-backend: selected folder must contain index.html" >&2
    exit 1
  }

  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'absolute=%s\n' "$picked_abs"
  printf 'relative=%s\n' "$relative"
}

validate_workspace_profile_field_key() {
  key=${1-}
  case "$key" in
    project_type|development_context|starter|app_subpath|native_ir_path|hosted_web_mode|hosted_web_site_name|hosted_web_serve_script|hosted_web_serve_action|run_rebuild_command)
      return 0
      ;;
  esac
  printf '%s\n' "forge-backend: unsupported project field '$key'" >&2
  exit 2
}

validate_workspace_relative_field() {
  workspace_abs=$1
  rel_value=$2
  field_name=$3
  must_exist=$4

  [ -n "$rel_value" ] || return 0
  case "$rel_value" in
    /*)
      printf '%s\n' "forge-backend: $field_name must stay relative to the project root" >&2
      exit 2
      ;;
    *".."*)
      printf '%s\n' "forge-backend: $field_name must not escape the project root" >&2
      exit 2
      ;;
  esac

  if [ "$must_exist" = "file" ]; then
    abs_path=$(resolve_workspace_relative_path "$workspace_abs" "$rel_value" 2>/dev/null || true)
    [ -n "$abs_path" ] && [ -f "$abs_path" ] || {
      printf '%s\n' "forge-backend: $field_name not found in project: $rel_value" >&2
      exit 1
    }
  fi
}

cmd_set_workspace_field() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  key=${3-}
  value=${4-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: set-workspace-field requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -n "$key" ] || {
    printf '%s\n' "forge-backend: set-workspace-field requires KEY" >&2
    exit 2
  }

  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"
  conf="$workspace_abs/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: project profile missing: $workspace_abs" >&2
    exit 1
  }

  validate_workspace_profile_field_key "$key"

  normalized_value=$(printf '%s' "${value-}" | tr '\r\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$key" in
    project_type)
      case "$normalized_value" in
        application|native-desktop|game) ;;
        *)
          printf '%s\n' "forge-backend: project_type must be application, native-desktop, or game" >&2
          exit 2
          ;;
      esac
      ;;
    development_context)
      case "$normalized_value" in
        web|native-desktop|godot) ;;
        *)
          printf '%s\n' "forge-backend: development_context must be web, native-desktop, or godot" >&2
          exit 2
          ;;
      esac
      ;;
    starter)
      case "$normalized_value" in
        ""|import-web|import-native-desktop|import-godot|import-generic|blank|minimal|reference-app|panel|sidebar|topbar|dashboard|studio|clone)
          ;;
        *)
          printf '%s\n' "forge-backend: unsupported starter '$normalized_value'" >&2
          exit 2
          ;;
      esac
      ;;
    app_subpath)
      if [ "$normalized_value" = "." ]; then
        [ -f "$workspace_abs/index.html" ] || {
          printf '%s\n' "forge-backend: project root does not contain index.html" >&2
          exit 1
        }
      elif [ -n "$normalized_value" ]; then
        validate_workspace_relative_field "$workspace_abs" "$normalized_value" "app_subpath" "dir"
        [ -f "$workspace_abs/$normalized_value/index.html" ] || {
          printf '%s\n' "forge-backend: app_subpath must point to a folder containing index.html" >&2
          exit 1
        }
      fi
      ;;
    native_ir_path)
      validate_workspace_relative_field "$workspace_abs" "$normalized_value" "native_ir_path" "file"
      case "$normalized_value" in
        *.yaml|*.yml) ;;
        *)
          printf '%s\n' "forge-backend: native_ir_path must point to a .yaml or .yml file" >&2
          exit 2
          ;;
      esac
      ;;
    hosted_web_mode)
      case "$normalized_value" in
        ""|web-wizardry-site) ;;
        *)
          printf '%s\n' "forge-backend: hosted_web_mode must be blank or web-wizardry-site" >&2
          exit 2
          ;;
      esac
      ;;
    hosted_web_site_name)
      if [ -n "$normalized_value" ]; then
        validate_site_name "$normalized_value"
      fi
      ;;
    hosted_web_serve_script)
      validate_workspace_relative_field "$workspace_abs" "$normalized_value" "hosted_web_serve_script" "file"
      ;;
    hosted_web_serve_action)
      case "$normalized_value" in
        "")
          ;;
        [A-Za-z0-9]*)
          case "$normalized_value" in
            *[!A-Za-z0-9._:-]*)
              printf '%s\n' "forge-backend: invalid hosted_web_serve_action '$normalized_value'" >&2
              exit 2
              ;;
          esac
          ;;
        *)
          printf '%s\n' "forge-backend: invalid hosted_web_serve_action '$normalized_value'" >&2
          exit 2
          ;;
      esac
      ;;
    run_rebuild_command)
      :
      ;;
  esac

  write_key_value_file "$conf" "$key" "$normalized_value"
  printf 'root_hint=%s\n' "$root"
  printf 'workspace=%s\n' "$workspace_abs"
  printf 'profile=%s\n' "$conf"
  printf 'key=%s\n' "$key"
  printf 'value=%s\n' "$normalized_value"
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
  targets=$(normalize_targets_value "$targets")
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
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  conf="$workspace_path/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: project profile missing: $workspace_path" >&2
    exit 1
  }

  targets=$(normalize_targets_value "$targets")
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
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  [ -n "$title" ] || {
    printf '%s\n' "forge-backend: rename-workspace requires NEW_TITLE" >&2
    exit 2
  }

  workspace_abs=$(resolve_existing_dir_path "$workspace_path" 2>/dev/null || true)
  [ -n "$workspace_abs" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_abs" "project path"

  conf="$workspace_abs/wizardry.workspace.conf"
  [ -f "$conf" ] || {
    printf '%s\n' "forge-backend: project profile missing: $workspace_abs" >&2
    exit 1
  }

  cleaned_title=$(printf '%s' "$title" | tr '\r\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$cleaned_title" ] || {
    printf '%s\n' "forge-backend: rename-workspace requires a non-empty NEW_TITLE" >&2
    exit 2
  }
  validate_generated_display_name "$cleaned_title" "NEW_TITLE"

  old_path="$workspace_abs"
  parent_dir=$(dirname "$workspace_abs")
  new_slug=$(derive_workspace_slug "$cleaned_title")
  target_path="$parent_dir/$new_slug"
  reject_line_breaks "$target_path" "project path"
  moved=0

  if [ "$workspace_abs" != "$target_path" ]; then
    [ ! -e "$target_path" ] || {
      printf '%s\n' "forge-backend: project path already exists: $target_path" >&2
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
  shape_mode=${3-squircle}

  [ -d "$project_dir" ] || {
    printf '%s\n' "forge-backend: project path not found: $project_dir" >&2
    exit 1
  }

  icon_path="$project_dir/assets/forge-icon.png"
  legacy_icns_path="$project_dir/assets/forge.icns"
  generated_icons_dir="$project_dir/assets/icons"
  mkdir -p "$(dirname "$icon_path")"

  if [ -z "$data_url" ]; then
    rm -f "$icon_path"
    rm -f "$legacy_icns_path"
    rm -rf "$generated_icons_dir"
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

  rm -rf "$generated_icons_dir"

  if command -v magick >/dev/null 2>&1; then
    root=$(require_root "")
    generator="$root/tools/icons/generate-platform-icons.sh"
    generator_mode=--squircle
    if [ "$shape_mode" = "plain" ]; then
      generator_mode=--plain
    fi
    if [ -f "$generator" ]; then
      sh "$generator" "$tmp_icon" "$project_dir" "$generator_mode"
      rm -f "$tmp_icon"
      rm -f "$legacy_icns_path"
      return 0
    fi
  fi

  normalized_icon=$tmp_icon
  if command -v sips >/dev/null 2>&1; then
    resized_icon_base=$(mktemp "${TMPDIR:-/tmp}/app-forge-icon-resized.XXXXXX")
    resized_icon="$resized_icon_base.png"
    rm -f "$resized_icon"
    if sips -s format png -z 1024 1024 "$tmp_icon" --out "$resized_icon" >/dev/null 2>&1; then
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

project_icon_meta_dir() {
  project_dir=$1
  printf '%s\n' "$project_dir/assets/icons/meta"
}

project_icon_shape_mode() {
  project_dir=$1
  requested_mode=${2-}
  config_path="$project_dir/assets/icons/meta/icon-settings.conf"

  case "$requested_mode" in
    plain|squircle)
      printf '%s\n' "$requested_mode"
      return 0
      ;;
  esac

  if [ -f "$config_path" ]; then
    config_squircle=$(awk -F= '/^squircle=/{print $2; exit}' "$config_path" 2>/dev/null | tr -d '\r')
    if [ "$config_squircle" = "0" ]; then
      printf '%s\n' plain
      return 0
    fi
    if [ "$config_squircle" = "1" ]; then
      printf '%s\n' squircle
      return 0
    fi
  fi

  printf '%s\n' squircle
}

resolve_project_icon_config_file() {
  project_dir=$1
  configured_path=${2-}

  [ -n "$configured_path" ] || return 1
  has_line_break "$configured_path" && return 1

  project_abs=$(CDPATH= cd -- "$project_dir" && pwd -P) || return 1

  case "$configured_path" in
    /*)
      candidate=$configured_path
      ;;
    *)
      candidate=$(resolve_workspace_relative_path "$project_abs" "$configured_path" 2>/dev/null) || return 1
      [ -f "$candidate" ] || return 1
      printf '%s\n' "$candidate"
      return 0
      ;;
  esac

  [ -f "$candidate" ] || return 1
  candidate_dir=$(dirname "$candidate")
  candidate_base=$(basename "$candidate")
  candidate_abs_dir=$(CDPATH= cd -- "$candidate_dir" 2>/dev/null && pwd -P) || return 1
  candidate_abs="$candidate_abs_dir/$candidate_base"

  case "$candidate_abs" in
    "$project_abs"/*)
      printf '%s\n' "$candidate_abs"
      return 0
      ;;
  esac

  return 1
}

project_original_icon_source() {
  project_dir=$1
  meta_dir=$(project_icon_meta_dir "$project_dir")
  config_path="$meta_dir/icon-settings.conf"
  configured_path=''

  if [ -f "$config_path" ]; then
    configured_path=$(awk -F= '/^original_source=/{print substr($0, index($0, "=") + 1); exit}' "$config_path" 2>/dev/null | tr -d '\r')
    resolved_path=$(resolve_project_icon_config_file "$project_dir" "$configured_path" 2>/dev/null || true)
    if [ -n "$resolved_path" ]; then
      printf '%s\n' "$resolved_path"
      return 0
    fi
  fi

  for candidate in "$meta_dir"/original-source.*; do
    [ -f "$candidate" ] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  return 1
}

regenerate_project_icon_assets() {
  root_hint=$1
  project_dir=$2
  requested_mode=${3-}

  [ -d "$project_dir" ] || {
    printf '%s\n' "forge-backend: project path not found: $project_dir" >&2
    exit 1
  }

  original_source=$(project_original_icon_source "$project_dir" || true)
  [ -n "$original_source" ] || {
    printf '%s\n' "forge-backend: no saved original icon source was found for $project_dir" >&2
    exit 1
  }

  root=$(require_root "$root_hint")
  generator="$root/tools/icons/generate-platform-icons.sh"
  [ -f "$generator" ] || {
    printf '%s\n' "forge-backend: icon generator not found: $generator" >&2
    exit 1
  }

  shape_mode=$(project_icon_shape_mode "$project_dir" "$requested_mode")
  generator_mode=--squircle
  if [ "$shape_mode" = "plain" ]; then
    generator_mode=--plain
  fi

  legacy_icns_path="$project_dir/assets/forge.icns"
  sh "$generator" "$original_source" "$project_dir" "$generator_mode"
  rm -f "$legacy_icns_path"
}

write_project_icon_from_file() {
  project_dir=$1
  image_path=$2
  shape_mode=${3-squircle}

  [ -d "$project_dir" ] || {
    printf '%s\n' "forge-backend: project path not found: $project_dir" >&2
    exit 1
  }

  [ -n "$image_path" ] || {
    printf '%s\n' "forge-backend: image path is required" >&2
    exit 2
  }

  [ -f "$image_path" ] || {
    printf '%s\n' "forge-backend: image path not found: $image_path" >&2
    exit 1
  }

  icon_path="$project_dir/assets/forge-icon.png"
  legacy_icns_path="$project_dir/assets/forge.icns"
  generated_icons_dir="$project_dir/assets/icons"
  mkdir -p "$(dirname "$icon_path")"
  rm -rf "$generated_icons_dir"

  if command -v magick >/dev/null 2>&1; then
    root=$(require_root "")
    generator="$root/tools/icons/generate-platform-icons.sh"
    generator_mode=--squircle
    if [ "$shape_mode" = "plain" ]; then
      generator_mode=--plain
    fi
    if [ -f "$generator" ]; then
      sh "$generator" "$image_path" "$project_dir" "$generator_mode"
      rm -f "$legacy_icns_path"
      return 0
    fi
  fi

  tmp_copy=''
  if command -v sips >/dev/null 2>&1; then
    tmp_copy_base=$(mktemp "${TMPDIR:-/tmp}/app-forge-icon-file.XXXXXX")
    tmp_copy="$tmp_copy_base.png"
    rm -f "$tmp_copy"
    if sips -s format png -z 1024 1024 "$image_path" --out "$tmp_copy" >/dev/null 2>&1; then
      mv "$tmp_copy" "$icon_path"
      rm -f "$legacy_icns_path"
      printf 'icon=%s\n' "$icon_path"
      printf 'status=updated\n'
      return 0
    fi
    rm -f "$tmp_copy"
  fi

  cp "$image_path" "$icon_path"
  rm -f "$legacy_icns_path"
  printf 'icon=%s\n' "$icon_path"
  printf 'status=updated\n'
}

cmd_set_app_icon() {
  root=$(require_root "${1-}")
  slug=${2-}
  data_url=${3-}
  shape_mode=${4-squircle}

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

  write_project_icon_from_data_url "$app_dir" "$data_url" "$shape_mode"
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
  shape_mode=${4-squircle}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: set-workspace-icon requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  write_project_icon_from_data_url "$workspace_path" "$data_url" "$shape_mode"
  workspace_app_dir="$workspace_path/app"
  if [ -f "$workspace_app_dir/index.html" ]; then
    # Keep workspace root and nested app icon assets synchronized so runtime,
    # splash, and bundle icon resolution cannot diverge.
  write_project_icon_from_data_url "$workspace_app_dir" "$data_url" "$shape_mode" >/dev/null
  fi
  sync_workspace_godot_icon_config_if_needed "$workspace_path"
  printf 'workspace=%s\n' "$workspace_path"
}

cmd_set_app_icon_file() {
  root=$(require_root "${1-}")
  slug=${2-}
  image_path=${3-}
  shape_mode=${4-squircle}

  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: set-app-icon-file requires APP_SLUG" >&2
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

  write_project_icon_from_file "$app_dir" "$image_path" "$shape_mode"
  if [ "$distribution" = "optional" ] && [ -n "$override_icon" ] && [ -f "$app_dir/assets/forge-icon.png" ]; then
    mkdir -p "$(dirname "$override_icon")"
    cp "$app_dir/assets/forge-icon.png" "$override_icon"
  fi
  synced_install=$(sync_macos_install_for_slug "$root" "$slug" 2>/dev/null || true)
  [ -n "$synced_install" ] && printf 'installed_synced=%s\n' "$synced_install"
  printf 'slug=%s\n' "$slug"
}

cmd_set_workspace_icon_file() {
  require_root "${1-}" >/dev/null
  workspace_path=${2-}
  image_path=${3-}
  shape_mode=${4-squircle}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: set-workspace-icon-file requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  write_project_icon_from_file "$workspace_path" "$image_path" "$shape_mode"
  workspace_app_dir="$workspace_path/app"
  if [ -f "$workspace_app_dir/index.html" ]; then
    write_project_icon_from_file "$workspace_app_dir" "$image_path" "$shape_mode" >/dev/null
  fi
  sync_workspace_godot_icon_config_if_needed "$workspace_path"
  printf 'workspace=%s\n' "$workspace_path"
}

cmd_regenerate_app_icon_assets() {
  root=$(require_root "${1-}")
  slug=${2-}
  requested_mode=${3-}

  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: regenerate-app-icon-assets requires APP_SLUG" >&2
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

  regenerate_project_icon_assets "$root" "$app_dir" "$requested_mode"
  if [ "$distribution" = "optional" ] && [ -n "$override_icon" ] && [ -f "$app_dir/assets/forge-icon.png" ]; then
    mkdir -p "$(dirname "$override_icon")"
    cp "$app_dir/assets/forge-icon.png" "$override_icon"
  fi
  synced_install=$(sync_macos_install_for_slug "$root" "$slug" 2>/dev/null || true)
  [ -n "$synced_install" ] && printf 'installed_synced=%s\n' "$synced_install"
  printf 'icon=%s\n' "$app_dir/assets/forge-icon.png"
  printf 'status=regenerated\n'
  printf 'slug=%s\n' "$slug"
}

cmd_regenerate_workspace_icon_assets() {
  require_root "${1-}" >/dev/null
  workspace_path=${2-}
  requested_mode=${3-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: regenerate-workspace-icon-assets requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  root=$(require_root "${1-}")
  regenerate_project_icon_assets "$root" "$workspace_path" "$requested_mode"
  workspace_app_dir="$workspace_path/app"
  if [ -f "$workspace_app_dir/index.html" ]; then
    regenerate_project_icon_assets "$root" "$workspace_app_dir" "$requested_mode"
  fi
  sync_workspace_godot_icon_config_if_needed "$workspace_path"
  printf 'icon=%s\n' "$workspace_path/assets/forge-icon.png"
  printf 'status=regenerated\n'
  printf 'workspace=%s\n' "$workspace_path"
}

cmd_icon_tool_status() {
  root=$(require_root "${1-}")
  run_icon_creation_script "$root" check-imagemagick
  if command -v iconutil >/dev/null 2>&1; then
    printf 'iconutil=1\n'
  else
    printf 'iconutil=0\n'
  fi
}

cmd_install_icon_tool() {
  root=$(require_root "${1-}")
  tool=${2-imagemagick}

  case "$tool" in
    imagemagick)
      run_icon_creation_script "$root" install-imagemagick
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported icon tool: $tool" >&2
      exit 2
      ;;
  esac
}

cmd_uninstall_icon_tool() {
  root=$(require_root "${1-}")
  tool=${2-imagemagick}

  case "$tool" in
    imagemagick)
      run_icon_creation_script "$root" uninstall-imagemagick
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported icon tool: $tool" >&2
      exit 2
      ;;
  esac
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
         [ -f "$bundle/Contents/Resources/wizardry-apps-root.txt" ] &&
         [ -f "$hash_path" ]; then
        cached_hash=$(head -n 1 "$hash_path" 2>/dev/null | tr -d '\r')
        cached_root=$(head -n 1 "$bundle/Contents/Resources/wizardry-apps-root.txt" 2>/dev/null | tr -d '\r')
        if [ "$cached_hash" = "$expected_hash" ] && [ "$cached_root" = "$root" ] && ensure_macos_bundle_signature "$bundle"; then
          cache_hit=true
        fi
      fi

      if [ "$cache_hit" = false ]; then
        rm -rf "$bundle"
        mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/$slug" "$bundle/Contents/Resources/.host" "$bundle/Contents/Resources/wizardry-apps/core"

        copy_tree_for_bundle "$app_dir" "$bundle/Contents/Resources/$slug/"
        rm -rf "$bundle/Contents/Resources/$slug/themes"
        mkdir -p "$bundle/Contents/Resources/$slug/.host"
        cp -R "$root/apps/.host/shared" "$bundle/Contents/Resources/$slug/.host/"
        cp -R "$root/apps/.host/shared" "$bundle/Contents/Resources/.host/"
        printf '%s\n' "$root" > "$bundle/Contents/Resources/wizardry-apps-root.txt"
        printf '%s\n' "$expected_hash" > "$hash_path"
        cp -R "$root/core/include" "$bundle/Contents/Resources/wizardry-apps/core/"
        cp -R "$root/core/src" "$bundle/Contents/Resources/wizardry-apps/core/"
        cp "$host_bin" "$bundle/Contents/MacOS/wizardry-host"

        icon_source=''
        icon_source_format=''
        icon_override=$(app_icon_override_path "$slug")
        app_icon_source=$(project_preferred_bundle_icon_path "$app_dir" || true)
        if [ -n "$app_icon_source" ]; then
          icon_source="$app_icon_source"
          icon_source_format=$(icon_source_format_for_path "$icon_source")
        elif [ -f "$icon_override" ]; then
          icon_source="$icon_override"
          icon_source_format='png'
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
            sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
            sips -s format png -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
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
<key>CFBundleExecutable</key><string>wizardry-host</string>
<key>WizardryAppEntry</key><string>Resources/$slug</string>
$icon_key
</dict></plist>
PLIST

        ensure_macos_bundle_signature "$bundle" || {
          printf '%s\n' "forge-backend: failed to sign macOS app bundle: $bundle" >&2
          exit 1
        }
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
        elif [ -f "$app_dir/assets/icons/linux/256x256/forge-icon.png" ]; then
          linux_icon_source="$app_dir/assets/icons/linux/256x256/forge-icon.png"
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

resolve_native_workspace_metadata() {
  workspace_path=${1-}
  workspace_conf=${2-}
  [ -n "$workspace_path" ] || return 1
  [ -n "$workspace_conf" ] || return 1
  require_jq

  native_ir_rel=$(resolve_workspace_native_ir_path "$workspace_path" "$workspace_conf")
  native_ir="$workspace_path/$native_ir_rel"
  [ -f "$native_ir" ] || return 1

  app_id=$(jq -r '.app.id // ""' "$native_ir")
  app_name=$(jq -r '.app.name // ""' "$native_ir")
  [ -n "$app_id" ] || return 1
  [ -n "$app_name" ] || app_name=$(workspace_field "$workspace_conf" title "$(basename "$workspace_path")")
  workspace_slug=$(resolve_workspace_slug "$workspace_conf" "$workspace_path")

  printf 'ir=%s\n' "$native_ir"
  printf 'app_id=%s\n' "$app_id"
  printf 'app_name=%s\n' "$app_name"
  printf 'workspace_slug=%s\n' "$workspace_slug"
}

workspace_native_bundle_icon_path() {
  workspace_path=${1-}
  if [ -n "$workspace_path" ]; then
    icon_source=$(project_preferred_bundle_icon_path "$workspace_path" || true)
    if [ -n "$icon_source" ]; then
      printf '%s\n' "$icon_source"
      return 0
    fi
  fi
  return 1
}

build_godot_workspace_macos_launcher() {
  root=${1-}
  workspace_path=${2-}
  workspace_conf=${3-}
  project_path=${4-}
  godot_app=${5-}

  [ -n "$root" ] || return 1
  [ -n "$workspace_path" ] || return 1
  [ -n "$workspace_conf" ] || return 1
  [ -n "$project_path" ] || return 1
  [ -n "$godot_app" ] || return 1
  [ -d "$godot_app" ] || return 1

  workspace_title=$(workspace_display_title "$workspace_path" "$workspace_conf")
  workspace_slug=$(resolve_workspace_slug "$workspace_conf" "$workspace_path")
  bundle_root="$root/_tmp/workbench/dist/macos-godot-workspaces/$workspace_slug"
  final_bundle="$bundle_root/$workspace_title.app"
  hash_path="$final_bundle/Contents/Resources/wizardry-build-input.sha256"

  icon_source=''
  workspace_icon_source=$(project_preferred_bundle_icon_path "$workspace_path" || true)
  project_icon_source=$(project_preferred_bundle_icon_path "$project_path" || true)
  if [ -n "$workspace_icon_source" ]; then
    icon_source="$workspace_icon_source"
  elif [ -n "$project_icon_source" ]; then
    icon_source="$project_icon_source"
  fi
  icon_source_format=''
  icon_hash=''
  if [ -n "$icon_source" ]; then
    icon_source_format=$(icon_source_format_for_path "$icon_source")
    icon_hash=$(hash_path_sha256 "$icon_source")
  fi

  expected_hash=$({
    printf 'backend=%s\n' "$(hash_path_sha256 "$SCRIPT_DIR/forge-backend.sh")"
    printf 'godot_app=%s\n' "$(hash_path_sha256 "$godot_app")"
    printf 'project=%s\n' "$(hash_path_sha256 "$project_path")"
    printf 'project_path=%s\n' "$project_path"
    printf 'workspace_title=%s\n' "$workspace_title"
    printf 'workspace_slug=%s\n' "$workspace_slug"
    printf 'icon=%s\n' "${icon_hash:-missing}"
  } | hash_stdin_sha256)

  cache_hit=false
  if [ -d "$final_bundle" ] &&
     [ -f "$hash_path" ] &&
     [ "$(head -n 1 "$hash_path" 2>/dev/null | tr -d '\r')" = "$expected_hash" ] &&
     ensure_macos_bundle_signature "$final_bundle"; then
    cache_hit=true
  fi

  if [ "$cache_hit" = false ]; then
    staged_root=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-godot-workspace.XXXXXX")
    staged_bundle="$staged_root/$workspace_title.app"
    if command -v ditto >/dev/null 2>&1; then
      ditto "$godot_app" "$staged_bundle"
    else
      cp -R "$godot_app" "$staged_bundle"
    fi

    mkdir -p "$staged_bundle/Contents/Resources"
    bundled_exec="$staged_bundle/Contents/MacOS/Godot"
    bundled_real_exec="$staged_bundle/Contents/MacOS/Godot-real"
    mv "$bundled_exec" "$bundled_real_exec"
    cat > "$bundled_exec" <<'APP'
#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
PROJECT_PATH=$(cat "$HERE/../Resources/wizardry-godot-project-path.txt")
exec "$HERE/Godot-real" --path "$PROJECT_PATH" "$@"
APP
    chmod +x "$bundled_exec"

    printf '%s\n' "$project_path" > "$staged_bundle/Contents/Resources/wizardry-godot-project-path.txt"
    printf '%s\n' "$expected_hash" > "$staged_bundle/Contents/Resources/wizardry-build-input.sha256"

    plist_path="$staged_bundle/Contents/Info.plist"
    if command -v plutil >/dev/null 2>&1; then
      plutil -replace CFBundleName -string "$workspace_title" "$plist_path" >/dev/null
      plutil -replace CFBundleDisplayName -string "$workspace_title" "$plist_path" >/dev/null
      plutil -replace CFBundleIdentifier -string "com.wizardry.workspace.$workspace_slug.godot" "$plist_path" >/dev/null
      plutil -replace CFBundleVersion -string "$(printf '%s' "$expected_hash" | cksum | awk '{ print $1 }')" "$plist_path" >/dev/null
      plutil -replace CFBundleShortVersionString -string "1.0" "$plist_path" >/dev/null
    fi

    if [ "$icon_source_format" = 'png' ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
      iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-godot-iconset.XXXXXX")
      iconset="${iconset_tmp}.iconset"
      mv "$iconset_tmp" "$iconset"
      for size in 16 32 128 256 512; do
        sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -s format png -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
      done
      icon_name="forge-${icon_hash}.icns"
      if iconutil -c icns "$iconset" -o "$staged_bundle/Contents/Resources/$icon_name" >/dev/null 2>&1; then
        :
      else
        icon_name="forge-icon-${icon_hash}.png"
        cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
      fi
      rm -rf "$iconset"
    elif [ "$icon_source_format" = 'png' ]; then
      icon_name="forge-icon-${icon_hash}.png"
      cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
    elif [ "$icon_source_format" = 'icns' ]; then
      icon_name="forge-${icon_hash}.icns"
      cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
    else
      icon_name=''
    fi

    if [ -n "${icon_name-}" ] && command -v plutil >/dev/null 2>&1; then
      plutil -replace CFBundleIconFile -string "${icon_name%.icns}" "$plist_path" >/dev/null
      plutil -remove CFBundleIconName "$plist_path" >/dev/null 2>&1 || true
    fi

    ensure_macos_bundle_signature "$staged_bundle" || {
      printf '%s\n' "forge-backend: failed to sign macOS Godot workspace bundle: $staged_bundle" >&2
      exit 1
    }

    mkdir -p "$bundle_root"
    rm -rf "$final_bundle"
    mv "$staged_bundle" "$final_bundle"
    rmdir "$staged_root" 2>/dev/null || :
  fi

  printf 'status=ok\n'
  printf 'target=macos\n'
  printf 'app_name=%s\n' "$workspace_title"
  printf 'artifact=%s\n' "$final_bundle"
  printf 'cache=%s\n' "$([ "$cache_hit" = true ] && printf hit || printf miss)"
}

build_native_workspace_host() {
  root=${1-}
  workspace_path=${2-}
  workspace_conf=${3-}

  [ -n "$root" ] || return 1
  [ -n "$workspace_path" ] || return 1
  [ -n "$workspace_conf" ] || return 1

  meta=$(resolve_native_workspace_metadata "$workspace_path" "$workspace_conf") || {
    printf '%s\n' "forge-backend: native desktop workspace IR is missing or invalid: $workspace_path" >&2
    exit 1
  }
  app_id=$(printf '%s\n' "$meta" | kv_read app_id)
  app_name=$(printf '%s\n' "$meta" | kv_read app_name)
  workspace_slug=$(printf '%s\n' "$meta" | kv_read workspace_slug)

  os=$(os_id)
  case "$os" in
    darwin)
      require_tool swift
      package_dir="$workspace_path/generated/macos"
      [ -f "$package_dir/Package.swift" ] || {
        printf '%s\n' "forge-backend: native macOS package is missing Package.swift: $package_dir" >&2
        exit 1
      }

      build_dir="$root/_tmp/workbench/build/native-macos-workspaces/$workspace_slug"
      bundle_root="$root/_tmp/workbench/dist/macos-native-workspaces/$workspace_slug"
      bundle="$bundle_root/$app_name.app"
      rm -rf "$build_dir"
      mkdir -p "$build_dir"
      (
        cd "$workspace_path" &&
        swift build --package-path "$package_dir" --scratch-path "$build_dir"
      ) >/dev/null

      built_exec=$(find "$build_dir" -type f -path "*/debug/$app_id" | head -n 1)
      [ -n "$built_exec" ] && [ -x "$built_exec" ] || {
        printf '%s\n' "forge-backend: swift build did not produce executable '$app_id' for $workspace_path" >&2
        exit 1
      }

      staged_root=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-native-workspace-bundle.XXXXXX")
      staged_bundle="$staged_root/$app_name.app"
      mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources"
      cp "$built_exec" "$staged_bundle/Contents/MacOS/$app_id"
      chmod +x "$staged_bundle/Contents/MacOS/$app_id"

      icon_source=$(workspace_native_bundle_icon_path "$workspace_path" || true)
      icon_source_format=''
      icon_key=''
      icon_hash=''
      if [ -n "$icon_source" ]; then
        icon_source_format=$(icon_source_format_for_path "$icon_source")
        icon_hash=$(hash_path_sha256 "$icon_source")
      fi
      if [ "$icon_source_format" = 'png' ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
        iconset_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-native-iconset.XXXXXX")
        iconset="${iconset_tmp}.iconset"
        mv "$iconset_tmp" "$iconset"
        for size in 16 32 128 256 512; do
          sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
          sips -s format png -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
        done
        icon_name="forge-${icon_hash}.icns"
        if iconutil -c icns "$iconset" -o "$staged_bundle/Contents/Resources/$icon_name" >/dev/null 2>&1; then
          icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
        else
          icon_name="forge-icon-${icon_hash}.png"
          cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
          icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
        fi
        rm -rf "$iconset"
      elif [ "$icon_source_format" = 'png' ]; then
        icon_name="forge-icon-${icon_hash}.png"
        cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
        icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
      elif [ "$icon_source_format" = 'icns' ]; then
        icon_name="forge-${icon_hash}.icns"
        cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
        icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
      fi

      bundle_id="com.wizardry.workspace.$workspace_slug.native"
      bundle_version=$(printf '%s' "${icon_hash:-$workspace_slug}" | cksum | awk '{ print $1 }')
      [ -n "$bundle_version" ] || bundle_version=1
      cat > "$staged_bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$app_name</string>
<key>CFBundleDisplayName</key><string>$app_name</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>$bundle_version</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>$app_id</string>
$icon_key
</dict></plist>
PLIST

      ensure_macos_bundle_signature "$staged_bundle" || {
        printf '%s\n' "forge-backend: failed to sign native workspace bundle: $staged_bundle" >&2
        exit 1
      }

      mkdir -p "$bundle_root"
      rm -rf "$bundle"
      mv "$staged_bundle" "$bundle"
      rmdir "$staged_root" 2>/dev/null || :

      printf 'status=ok\n'
      printf 'target=macos\n'
      printf 'app_name=%s\n' "$app_name"
      printf 'artifact=%s\n' "$bundle"
      printf 'built_exec=%s\n' "$built_exec"
      ;;
    linux)
      require_tool pkg-config
      require_tool cc
      if ! pkg-config --exists gtk4; then
        printf '%s\n' "forge-backend: gtk4 development files are required to build native Linux workspaces" >&2
        exit 1
      fi
      src="$workspace_path/generated/linux/src/main.c"
      [ -f "$src" ] || {
        printf '%s\n' "forge-backend: native Linux source is missing: $src" >&2
        exit 1
      }

      build_root="$root/_tmp/workbench/dist/linux-native-workspaces/$workspace_slug"
      built_exec="$build_root/$app_id"
      mkdir -p "$build_root"
      cc -O2 $(pkg-config --cflags gtk4) "$src" -o "$built_exec" $(pkg-config --libs gtk4)
      chmod +x "$built_exec"

      printf 'status=ok\n'
      printf 'target=linux\n'
      printf 'app_name=%s\n' "$app_name"
      printf 'artifact=%s\n' "$built_exec"
      printf 'built_exec=%s\n' "$built_exec"
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac
}

workspace_display_title() {
  workspace_path=${1-}
  workspace_conf=${2-}

  [ -n "$workspace_path" ] || return 1
  [ -n "$workspace_conf" ] || return 1

  workspace_title=$(workspace_field "$workspace_conf" title "")
  [ -n "$workspace_title" ] || workspace_title=$(workspace_field "$workspace_conf" name "")
  [ -n "$workspace_title" ] || workspace_title=$(basename "$workspace_path")
  printf '%s\n' "$workspace_title"
}

host_workspace_target_id() {
  case "$(os_id)" in
    darwin) printf '%s\n' "macos" ;;
    linux) printf '%s\n' "linux" ;;
    *) return 1 ;;
  esac
}

build_workspace_desktop_host() {
  root=${1-}
  workspace_path=${2-}
  workspace_conf=${3-}

  [ -n "$root" ] || return 1
  [ -n "$workspace_path" ] || return 1
  [ -n "$workspace_conf" ] || return 1

  run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
  if ! app_dir=$(resolve_workspace_app_dir "$workspace_path" "$workspace_conf" 2>/dev/null); then
    printf '%s\n' "forge-backend: project app index not found: $workspace_path" >&2
    exit 1
  fi

  app_entry_suffix=''
  if [ "$app_dir" != "$workspace_path" ]; then
    app_entry_suffix=${app_dir#"$workspace_path"}
  fi

  host_target=$(host_workspace_target_id 2>/dev/null || true)
  [ -n "$host_target" ] || {
    printf '%s\n' "forge-backend: install-workspace is only supported on macOS and Linux hosts" >&2
    exit 1
  }

  targets_csv=$(workspace_field "$workspace_conf" targets "")
  case ",$targets_csv," in
    *,"$host_target",*)
      ;;
    *)
      printf '%s\n' "forge-backend: project has no installable target for this host (enable $host_target)" >&2
      exit 1
      ;;
  esac

  workspace_title=$(workspace_display_title "$workspace_path" "$workspace_conf")
  workspace_slug=$(resolve_workspace_slug "$workspace_conf" "$workspace_path")

  os=$(os_id)
  case "$os" in
    darwin)
      host_bin=$(ensure_macos_host "$root")
      bundle_root="$root/_tmp/workbench/dist/macos-workspaces/$workspace_slug"
      final_bundle="$bundle_root/$workspace_title.app"
      staged_root=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-workspace-bundle.XXXXXX")
      staged_bundle="$staged_root/$workspace_title.app"
      mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources/$workspace_slug" "$staged_bundle/Contents/Resources/.host"

      copy_tree_for_bundle "$workspace_path" "$staged_bundle/Contents/Resources/$workspace_slug/"
      rm -rf "$staged_bundle/Contents/Resources/$workspace_slug/themes"
      mkdir -p "$staged_bundle/Contents/Resources/$workspace_slug/.host"
      cp -R "$root/apps/.host/shared" "$staged_bundle/Contents/Resources/$workspace_slug/.host/"
      cp -R "$root/apps/.host/shared" "$staged_bundle/Contents/Resources/.host/"
      printf '%s\n' "$root" > "$staged_bundle/Contents/Resources/wizardry-apps-root.txt"
      cp "$host_bin" "$staged_bundle/Contents/MacOS/wizardry-host"

      bundle_app_dir="$app_dir"

      icon_source=''
      icon_source_format=''
      workspace_icon_source=$(project_preferred_bundle_icon_path "$workspace_path" || true)
      app_icon_source=$(project_preferred_bundle_icon_path "$app_dir" || true)
      if [ -n "$workspace_icon_source" ]; then
        icon_source="$workspace_icon_source"
        icon_source_format=$(icon_source_format_for_path "$icon_source")
      elif [ -n "$app_icon_source" ]; then
        icon_source="$app_icon_source"
        icon_source_format=$(icon_source_format_for_path "$icon_source")
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
          sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
          sips -s format png -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
        done
        icon_name="forge-${icon_hash}.icns"
        if iconutil -c icns "$iconset" -o "$staged_bundle/Contents/Resources/$icon_name" >/dev/null 2>&1; then
          icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
        else
          icon_name="forge-icon-${icon_hash}.png"
          cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
          icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
        fi
        rm -rf "$iconset"
      elif [ "$icon_source_format" = 'png' ]; then
        icon_name="forge-icon-${icon_hash}.png"
        cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
        icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
      elif [ "$icon_source_format" = 'icns' ]; then
        icon_name="forge-${icon_hash}.icns"
        cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
        icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
      fi

      bundle_id="com.wizardry.workspace.$workspace_slug"
      bundle_version=$(printf '%s' "${icon_hash:-$workspace_slug}" | cksum | awk '{ print $1 }')
      [ -n "$bundle_version" ] || bundle_version=1
      cat > "$staged_bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$workspace_title</string>
<key>CFBundleDisplayName</key><string>$workspace_title</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>$bundle_version</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>wizardry-host</string>
<key>WizardryAppEntry</key><string>$bundle_app_dir</string>
$icon_key
</dict></plist>
PLIST

      ensure_macos_bundle_signature "$staged_bundle" || {
        printf '%s\n' "forge-backend: failed to sign macOS project bundle: $staged_bundle" >&2
        exit 1
      }

      mkdir -p "$bundle_root"
      rm -rf "$final_bundle"
      mv "$staged_bundle" "$final_bundle"
      rmdir "$staged_root" 2>/dev/null || :

      printf 'status=ok\n'
      printf 'target=macos\n'
      printf 'workspace_title=%s\n' "$workspace_title"
      printf 'workspace_slug=%s\n' "$workspace_slug"
      printf 'artifact=%s\n' "$final_bundle"
      printf 'entry=%s\n' "$bundle_app_dir"
      ;;
    linux)
      host_bin=$(ensure_linux_host "$root")
      bundle_root="$root/_tmp/workbench/dist/linux-workspaces/$workspace_slug"
      appdir="$bundle_root/AppDir"
      rm -rf "$appdir"
      mkdir -p "$appdir/usr/bin" "$appdir/usr/share/$workspace_slug" "$appdir/usr/share/.host" "$appdir/usr/share/wizardry-apps/core"

      copy_tree_for_bundle "$workspace_path" "$appdir/usr/share/$workspace_slug/"
      linux_ws_icon_source=''
      if [ -f "$workspace_path/assets/icons/linux/256x256/forge-icon.png" ]; then
        linux_ws_icon_source="$workspace_path/assets/icons/linux/256x256/forge-icon.png"
      elif [ -f "$workspace_path/assets/forge-icon.png" ]; then
        linux_ws_icon_source="$workspace_path/assets/forge-icon.png"
      elif [ -f "$app_dir/assets/icons/linux/256x256/forge-icon.png" ]; then
        linux_ws_icon_source="$app_dir/assets/icons/linux/256x256/forge-icon.png"
      elif [ -f "$app_dir/assets/forge-icon.png" ]; then
        linux_ws_icon_source="$app_dir/assets/forge-icon.png"
      fi
      if [ -n "$linux_ws_icon_source" ]; then
        mkdir -p "$appdir/usr/share/$workspace_slug/assets"
        cp "$linux_ws_icon_source" "$appdir/usr/share/$workspace_slug/assets/forge-icon.png"
      fi
      mkdir -p "$appdir/usr/share/$workspace_slug/.host"
      cp -R "$root/apps/.host/shared" "$appdir/usr/share/$workspace_slug/.host/"
      cp -R "$root/apps/.host/shared" "$appdir/usr/share/.host/"
      cp -R "$root/core/include" "$appdir/usr/share/wizardry-apps/core/"
      cp -R "$root/core/src" "$appdir/usr/share/wizardry-apps/core/"
      cp "$host_bin" "$appdir/usr/bin/wizardry-host"

      cat > "$appdir/AppRun" <<APP
#!/bin/sh
set -eu
HERE=\$(CDPATH= cd -- "\$(dirname "\$0")" && pwd -P)
exec env WIZARDRY_DIR="$root" WIZARDRY_APPS_ROOT="$root" "\$HERE/usr/bin/wizardry-host" "\$HERE/usr/share/$workspace_slug$app_entry_suffix"
APP
      chmod +x "$appdir/AppRun"

      app_entry="$appdir/usr/share/$workspace_slug$app_entry_suffix"
      printf 'status=ok\n'
      printf 'target=linux\n'
      printf 'workspace_title=%s\n' "$workspace_title"
      printf 'workspace_slug=%s\n' "$workspace_slug"
      printf 'artifact=%s\n' "$appdir"
      printf 'entry=%s\n' "$app_entry"
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac
}

cmd_install_workspace() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  context_hint=${3-}
  target_id=${4-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: install-workspace requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  workspace_conf="$workspace_path/wizardry.workspace.conf"
  [ -f "$workspace_conf" ] || {
    printf '%s\n' "forge-backend: project is missing wizardry.workspace.conf: $workspace_path" >&2
    exit 1
  }

  context=$context_hint
  if [ -z "$context" ]; then
    context=$(workspace_field "$workspace_conf" development_context "")
  fi
  [ -n "$context" ] || context='web'
  case "$context" in
    native-desktop|web|godot)
      ;;
    *)
      printf '%s\n' "forge-backend: install-workspace currently supports web, native-desktop, and macOS Godot projects only" >&2
      exit 1
      ;;
  esac

  os=$(os_id)
  case "$os" in
    darwin)
      expected_target=macos
      ;;
    linux)
      expected_target=linux
      ;;
    *)
      printf '%s\n' "forge-backend: install-workspace is only supported on macOS and Linux hosts" >&2
      exit 1
      ;;
  esac
  if [ -n "$target_id" ] && [ "$target_id" != "$expected_target" ]; then
    printf '%s\n' "forge-backend: install-workspace target '$target_id' does not match current host '$expected_target'" >&2
    exit 2
  fi

  case "$context" in
    godot)
      [ "$os" = "darwin" ] || {
        printf '%s\n' "forge-backend: install-workspace currently supports Godot projects on macOS only" >&2
        exit 1
      }
      run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
      workspace_title=$(workspace_display_title "$workspace_path" "$workspace_conf")
      if ! project_path=$(ensure_godot_project "$workspace_path" "$workspace_title"); then
        printf '%s\n' "forge-backend: Godot project is missing project.godot: $workspace_path" >&2
        exit 1
      fi
      sync_godot_project_icon_config "$project_path"
      godot_app=$(resolve_godot_app_bundle 2>/dev/null || true)
      [ -n "$godot_app" ] || {
        printf '%s\n' "forge-backend: Godot.app is required to install Godot workspaces on macOS" >&2
        exit 1
      }
      build_out=$(build_godot_workspace_macos_launcher "$root" "$workspace_path" "$workspace_conf" "$project_path" "$godot_app")
      artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
      [ -d "$artifact" ] || {
        printf '%s\n' "forge-backend: expected Godot workspace launcher bundle artifact, got: $artifact" >&2
        exit 1
      }
      install_path="/Applications/$(basename "$artifact")"
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
      printf 'entry=%s\n' "$project_path"
      printf 'installed=%s\n' "$install_path"
      printf 'app_name=%s\n' "$workspace_title"
      ;;
    native-desktop)
      run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
      build_out=$(build_native_workspace_host "$root" "$workspace_path" "$workspace_conf")
      artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
      app_name=$(printf '%s\n' "$build_out" | kv_read app_name)
      built_exec=$(printf '%s\n' "$build_out" | kv_read built_exec)
      meta=$(resolve_native_workspace_metadata "$workspace_path" "$workspace_conf")
      workspace_slug=$(printf '%s\n' "$meta" | kv_read workspace_slug)
      app_id=$(printf '%s\n' "$meta" | kv_read app_id)

      case "$os" in
        darwin)
          [ -d "$artifact" ] || {
            printf '%s\n' "forge-backend: expected native macOS app bundle artifact, got: $artifact" >&2
            exit 1
          }
          install_path="/Applications/$(basename "$artifact")"
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
          printf 'built_exec=%s\n' "$built_exec"
          printf 'installed=%s\n' "$install_path"
          printf 'app_name=%s\n' "$app_name"
          ;;
        linux)
          install_root="$HOME/.local/share/wizardry-apps/$workspace_slug-native"
          launcher_dir="$HOME/.local/bin"
          launcher_path="$launcher_dir/wizardry-$workspace_slug-native"
          bin_dir="$install_root/bin"
          exec_path="$bin_dir/$app_id"
          icon_path=''
          desktop_file=''

          rm -rf "$install_root"
          mkdir -p "$bin_dir" "$launcher_dir"
          cp "$artifact" "$exec_path"
          chmod +x "$exec_path"

          cat > "$launcher_path" <<LAUNCHER
#!/bin/sh
set -eu
exec "$exec_path" "\$@"
LAUNCHER
          chmod +x "$launcher_path"

          icon_source=$(workspace_native_bundle_icon_path "$workspace_path" || true)
          if [ -n "$icon_source" ]; then
            mkdir -p "$install_root/assets"
            icon_path="$install_root/assets/forge-icon.png"
            cp "$icon_source" "$icon_path"
          fi

          desktop_dir="$HOME/.local/share/applications"
          mkdir -p "$desktop_dir"
          desktop_file="$desktop_dir/wizardry-$workspace_slug-native.desktop"
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
          printf 'built_exec=%s\n' "$built_exec"
          printf 'launcher=%s\n' "$launcher_path"
          printf 'installed=%s\n' "$install_root"
          printf 'desktop_entry=%s\n' "$desktop_file"
          printf 'app_name=%s\n' "$app_name"
          ;;
      esac
      ;;
    web)
      build_out=$(build_workspace_desktop_host "$root" "$workspace_path" "$workspace_conf")
      artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
      app_entry=$(printf '%s\n' "$build_out" | kv_read entry)
      workspace_title=$(printf '%s\n' "$build_out" | kv_read workspace_title)
      workspace_slug=$(printf '%s\n' "$build_out" | kv_read workspace_slug)

      case "$os" in
        darwin)
          [ -d "$artifact" ] || {
            printf '%s\n' "forge-backend: expected project macOS app bundle artifact, got: $artifact" >&2
            exit 1
          }
          install_path="/Applications/$(basename "$artifact")"
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
          printf 'entry=%s\n' "$app_entry"
          printf 'installed=%s\n' "$install_path"
          printf 'app_name=%s\n' "$workspace_title"
          ;;
        linux)
          [ -d "$artifact" ] || {
            printf '%s\n' "forge-backend: expected project Linux AppDir artifact, got: $artifact" >&2
            exit 1
          }
          install_root="$HOME/.local/share/wizardry-apps/$workspace_slug"
          launcher_dir="$HOME/.local/bin"
          launcher_path="$launcher_dir/wizardry-$workspace_slug"
          desktop_dir="$HOME/.local/share/applications"
          desktop_file="$desktop_dir/wizardry-$workspace_slug.desktop"
          icon_path="$install_root/usr/share/$workspace_slug/assets/forge-icon.png"

          rm -rf "$install_root"
          mkdir -p "$(dirname "$install_root")" "$launcher_dir" "$desktop_dir"
          cp -R "$artifact" "$install_root"

          cat > "$launcher_path" <<LAUNCHER
#!/bin/sh
set -eu
exec "$install_root/AppRun" "\$@"
LAUNCHER
          chmod +x "$launcher_path"

          cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$workspace_title
Exec=$launcher_path
Terminal=false
Categories=Development;
Icon=$icon_path
DESKTOP

          printf 'status=ok\n'
          printf 'target=linux\n'
          printf 'install_mode=%s\n' "$(normalize_linux_install_mode)"
          printf 'artifact=%s\n' "$artifact"
          printf 'entry=%s\n' "$app_entry"
          printf 'launcher=%s\n' "$launcher_path"
          printf 'installed=%s\n' "$install_root"
          printf 'desktop_entry=%s\n' "$desktop_file"
          printf 'app_name=%s\n' "$workspace_title"
          ;;
      esac
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
  run_mode=${3-}
  [ -n "$run_mode" ] || run_mode='normal'
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: run-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  case "$run_mode" in
    normal|install-first)
      ;;
    bundle)
      run_mode='normal'
      ;;
    *)
      printf '%s\n' "forge-backend: run-desktop mode must be normal, install-first, or bundle" >&2
      exit 2
      ;;
  esac

  require_jq
  manifest_app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found in manifest: $slug" >&2
    exit 1
  }
  os=$(os_id)
  if [ "$run_mode" = "install-first" ]; then
    install_out=$(cmd_install_desktop "$root" "$slug")
    bundle_artifact=$(printf '%s\n' "$install_out" | kv_read artifact)
    installed_path=$(printf '%s\n' "$install_out" | kv_read installed)
    launcher_path=$(printf '%s\n' "$install_out" | kv_read launcher)
    [ -n "$bundle_artifact" ] || {
      printf '%s\n' "forge-backend: install-desktop did not return an artifact" >&2
      exit 1
    }

    case "$os" in
      darwin)
        app_name=$(app_name_from_manifest "$root" "$slug")
        self_relaunch=0
        if [ "$slug" = "forge" ]; then
          self_relaunch=1
        fi
        if [ "$self_relaunch" -eq 0 ]; then
          stop_desktop_instances_for_slug "$root" "$slug" "$app_name" "$os"
        fi
        [ -n "$installed_path" ] || installed_path="$bundle_artifact"
        [ -d "$installed_path" ] || {
          printf '%s\n' "forge-backend: installed macOS bundle missing: $installed_path" >&2
          exit 1
        }
        command -v open >/dev/null 2>&1 || {
          printf '%s\n' "forge-backend: open command not available on this system" >&2
          exit 1
        }
        if [ "$self_relaunch" -eq 1 ]; then
          # Let the active host process perform a native self-restart.
          printf 'launched=1\n'
          printf 'mode=desktop-installed\n'
          printf 'artifact=%s\n' "$installed_path"
          printf 'built_artifact=%s\n' "$bundle_artifact"
          printf 'installed=%s\n' "$installed_path"
          printf 'restart_bundle=%s\n' "$installed_path"
          [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
          exit 0
        else
          open "$installed_path"
        fi
        printf 'launched=1\n'
        printf 'mode=desktop-installed\n'
        printf 'artifact=%s\n' "$installed_path"
        printf 'built_artifact=%s\n' "$bundle_artifact"
        printf 'installed=%s\n' "$installed_path"
        [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
        exit 0
        ;;
      linux)
        stop_desktop_instances_for_slug "$root" "$slug" "" "$os"
        launch_exec=''
        if [ -n "$launcher_path" ] && [ -x "$launcher_path" ]; then
          launch_exec="$launcher_path"
        elif [ -n "$installed_path" ] && [ -x "$installed_path/AppRun" ]; then
          launch_exec="$installed_path/AppRun"
        fi
        [ -n "$launch_exec" ] || {
          printf '%s\n' "forge-backend: installed Linux launcher missing for $slug" >&2
          exit 1
        }
        log_dir="$root/_tmp/workbench/log"
        mkdir -p "$log_dir"
        log_path="$log_dir/$slug-run.log"
        if command -v nohup >/dev/null 2>&1; then
          nohup "$launch_exec" >"$log_path" 2>&1 &
        else
          "$launch_exec" >"$log_path" 2>&1 &
        fi
        pid=$!
        printf 'launched=1\n'
        printf 'mode=desktop-installed\n'
        printf 'artifact=%s\n' "$launch_exec"
        printf 'built_artifact=%s\n' "$bundle_artifact"
        printf 'installed=%s\n' "$installed_path"
        [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
        printf 'pid=%s\n' "$pid"
        printf 'log=%s\n' "$log_path"
        exit 0
        ;;
      *)
        printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
        exit 1
        ;;
    esac
  fi

  build_out=$(cmd_build_desktop "$root" "$slug")
  bundle_artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
  appdir=$(printf '%s\n' "$build_out" | kv_read appdir)
  [ -n "$bundle_artifact" ] || {
    printf '%s\n' "forge-backend: build-desktop did not return an artifact" >&2
    exit 1
  }

  case "$os" in
    darwin)
      app_name=$(app_name_from_manifest "$root" "$slug")
      self_relaunch=0
      if [ "$slug" = "forge" ]; then
        self_relaunch=1
      fi
      if [ "$self_relaunch" -eq 0 ]; then
        stop_desktop_instances_for_slug "$root" "$slug" "$app_name" "$os"
      fi
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
      if [ "$self_relaunch" -eq 1 ]; then
        # Let the active host process perform a native self-restart.
        printf 'launched=1\n'
        printf 'mode=desktop-executable\n'
        printf 'artifact=%s\n' "$launch_bundle"
        printf 'built_artifact=%s\n' "$bundle_artifact"
        [ -n "$synced_install" ] && printf 'installed_synced=%s\n' "$synced_install"
        printf 'restart_bundle=%s\n' "$launch_bundle"
        exit 0
      else
        open "$launch_bundle"
      fi
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
  app_dir="$appdir/usr/share/$slug"

  case "$bundle_artifact" in
    *.AppImage)
      if command -v nohup >/dev/null 2>&1; then
        nohup "$bundle_artifact" >"$log_path" 2>&1 &
      else
        "$bundle_artifact" >"$log_path" 2>&1 &
      fi
      pid=$!
      ;;
    *)
      pid=$(launch_desktop_host_linux "$appdir/AppRun" "$app_dir" "$log_path") || {
        printf '%s\n' "forge-backend: failed to launch desktop app: $app_dir" >&2
        exit 1
      }
      ;;
  esac

  printf 'launched=1\n'
  printf 'mode=desktop-executable\n'
  printf 'entry=%s\n' "$app_dir"
  printf 'artifact=%s\n' "$bundle_artifact"
  printf 'built_artifact=%s\n' "$bundle_artifact"
  printf 'pid=%s\n' "$pid"
  printf 'log=%s\n' "$log_path"
}

cmd_rebuild_workspace() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  context_hint=${3-}

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: rebuild-workspace requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  workspace_path=$(CDPATH= cd -- "$workspace_path" && pwd -P)
  reject_line_breaks "$workspace_path" "project path"
  workspace_conf="$workspace_path/wizardry.workspace.conf"
  [ -f "$workspace_conf" ] || {
    printf '%s\n' "forge-backend: project is missing wizardry.workspace.conf: $workspace_path" >&2
    exit 1
  }
  ensure_workspace_emitted_legal_files "$root" "$workspace_path" "$workspace_conf"

  context=$context_hint
  if [ -z "$context" ]; then
    context=$(workspace_field "$workspace_conf" development_context "")
  fi
  [ -n "$context" ] || context=web

  rebuild_out=$(run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf")
  printf '%s\n' "$rebuild_out"
  printf 'workspace=%s\n' "$workspace_path"
  printf 'context=%s\n' "$context"
  case "$context" in
    native-desktop)
      printf 'app_entry=%s\n' "$workspace_path/generated"
      printf 'native_ir=%s\n' "$(resolve_workspace_native_ir_path "$workspace_path" "$workspace_conf" 2>/dev/null || printf '%s' "$workspace_path/ir/app.ir.yaml")"
      ;;
    *)
      printf 'app_entry=%s\n' "$(resolve_workspace_app_dir "$workspace_path" "$workspace_conf" 2>/dev/null || printf '%s' "$workspace_path")"
      ;;
  esac
}

cmd_run_workspace() {
  root=$(require_root "${1-}")
  workspace_path=${2-}
  context_hint=${3-}
  run_mode=${4-}
  [ -n "$run_mode" ] || run_mode='normal'

  [ -n "$workspace_path" ] || {
    printf '%s\n' "forge-backend: run-workspace requires WORKSPACE_PATH" >&2
    exit 2
  }
  [ -d "$workspace_path" ] || {
    printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
    exit 1
  }
  reject_line_breaks "$workspace_path" "project path"

  context=$context_hint
  if [ -z "$context" ] && [ -f "$workspace_path/wizardry.workspace.conf" ]; then
    context=$(workspace_field "$workspace_path/wizardry.workspace.conf" development_context "")
  fi
  [ -n "$context" ] || context=web
  case "$run_mode" in
    normal|install-first)
      ;;
    bundle)
      run_mode='normal'
      ;;
    *)
      printf '%s\n' "forge-backend: run-workspace mode must be normal, install-first, or bundle" >&2
      exit 2
      ;;
  esac

  workspace_conf="$workspace_path/wizardry.workspace.conf"
  [ -f "$workspace_conf" ] || {
    printf '%s\n' "forge-backend: project is missing wizardry.workspace.conf: $workspace_path" >&2
    exit 1
  }
  ensure_workspace_emitted_legal_files "$root" "$workspace_path" "$workspace_conf"

  case "$context" in
    godot)
      run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
      project_title=''
      if [ -f "$workspace_path/wizardry.workspace.conf" ]; then
        project_title=$(workspace_field "$workspace_path/wizardry.workspace.conf" title "")
      fi
      if ! project_path=$(ensure_godot_project "$workspace_path" "$project_title"); then
        printf '%s\n' "forge-backend: Godot project is missing project.godot: $workspace_path" >&2
        exit 1
      fi
      sync_godot_project_icon_config "$project_path"

      if [ "$(os_id)" = "darwin" ] && godot_app=$(resolve_godot_app_bundle 2>/dev/null || true) && [ -n "$godot_app" ]; then
        bundle_out=$(build_godot_workspace_macos_launcher "$root" "$workspace_path" "$workspace_conf" "$project_path" "$godot_app")
        launcher_bundle=$(printf '%s\n' "$bundle_out" | kv_read artifact)
        [ -d "$launcher_bundle" ] || {
          printf '%s\n' "forge-backend: failed to build Godot workspace launcher bundle: $workspace_path" >&2
          exit 1
        }

        workspace_id=$(basename "$workspace_path")
        log_dir="$root/_tmp/workbench/log"
        mkdir -p "$log_dir"
        log_path="$log_dir/workspace-$workspace_id-godot.log"

        open -na "$launcher_bundle" >/dev/null 2>&1 || {
          printf '%s\n' "forge-backend: failed to launch Godot workspace bundle: $launcher_bundle" >&2
          exit 1
        }
        printf 'launched=1\n'
        printf 'mode=godot-workspace-bundle\n'
        printf 'entry=%s\n' "$project_path"
        printf 'artifact=%s\n' "$launcher_bundle"
        printf 'log=%s\n' "$log_path"
        return 0
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
    native-desktop)
      meta=$(resolve_native_workspace_metadata "$workspace_path" "$workspace_conf") || {
        printf '%s\n' "forge-backend: native desktop workspace IR is missing or invalid: $workspace_path" >&2
        exit 1
      }
      app_id=$(printf '%s\n' "$meta" | kv_read app_id)
      app_name=$(printf '%s\n' "$meta" | kv_read app_name)
      workspace_slug=$(printf '%s\n' "$meta" | kv_read workspace_slug)
      os=$(os_id)
      host_target=''
      case "$os" in
        darwin) host_target=macos ;;
        linux) host_target=linux ;;
      esac
      log_dir="$root/_tmp/workbench/log"
      mkdir -p "$log_dir"
      log_path="$log_dir/workspace-$workspace_slug-native.log"

      if [ "$run_mode" = 'install-first' ]; then
        install_out=$(cmd_install_workspace "$root" "$workspace_path" "$context" "$host_target")
        artifact=$(printf '%s\n' "$install_out" | kv_read artifact)
        built_exec=$(printf '%s\n' "$install_out" | kv_read built_exec)
        installed_path=$(printf '%s\n' "$install_out" | kv_read installed)
        launcher_path=$(printf '%s\n' "$install_out" | kv_read launcher)
        case "$os" in
          darwin)
            [ -n "$installed_path" ] || installed_path="$artifact"
            [ -d "$installed_path" ] || {
              printf '%s\n' "forge-backend: installed native macOS bundle missing: $installed_path" >&2
              exit 1
            }
            command -v open >/dev/null 2>&1 || {
              printf '%s\n' "forge-backend: open command not available on this system" >&2
              exit 1
            }
            open "$installed_path"
            printf 'launched=1\n'
            printf 'mode=native-desktop-installed\n'
            printf 'artifact=%s\n' "$installed_path"
            printf 'built_artifact=%s\n' "$artifact"
            printf 'built_exec=%s\n' "$built_exec"
            printf 'installed=%s\n' "$installed_path"
            [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
            printf 'entry=%s\n' "$workspace_path/generated"
            printf 'log=%s\n' "$log_path"
            return 0
            ;;
          linux)
            launch_exec=''
            if [ -n "$launcher_path" ] && [ -x "$launcher_path" ]; then
              launch_exec="$launcher_path"
            elif [ -n "$installed_path" ] && [ -x "$installed_path/bin/$app_id" ]; then
              launch_exec="$installed_path/bin/$app_id"
            fi
            [ -n "$launch_exec" ] || {
              printf '%s\n' "forge-backend: installed native Linux launcher missing for $workspace_path" >&2
              exit 1
            }
            if command -v nohup >/dev/null 2>&1; then
              nohup "$launch_exec" >"$log_path" 2>&1 &
            else
              "$launch_exec" >"$log_path" 2>&1 &
            fi
            pid=$!
            printf 'launched=1\n'
            printf 'mode=native-desktop-installed\n'
            printf 'artifact=%s\n' "$launch_exec"
            printf 'built_artifact=%s\n' "$artifact"
            printf 'built_exec=%s\n' "$built_exec"
            printf 'installed=%s\n' "$installed_path"
            [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
            printf 'entry=%s\n' "$workspace_path/generated"
            printf 'pid=%s\n' "$pid"
            printf 'log=%s\n' "$log_path"
            return 0
            ;;
          *)
            printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
            exit 1
            ;;
        esac
      fi

      run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
      build_out=$(build_native_workspace_host "$root" "$workspace_path" "$workspace_conf")
      artifact=$(printf '%s\n' "$build_out" | kv_read artifact)
      built_exec=$(printf '%s\n' "$build_out" | kv_read built_exec)
      case "$os" in
        darwin)
          [ -d "$artifact" ] || {
            printf '%s\n' "forge-backend: built native macOS bundle missing: $artifact" >&2
            exit 1
          }
          command -v open >/dev/null 2>&1 || {
            printf '%s\n' "forge-backend: open command not available on this system" >&2
            exit 1
          }
          open "$artifact"
          printf 'launched=1\n'
          printf 'mode=native-desktop-executable\n'
          printf 'artifact=%s\n' "$artifact"
          printf 'built_artifact=%s\n' "$artifact"
          printf 'built_exec=%s\n' "$built_exec"
          printf 'entry=%s\n' "$workspace_path/generated"
          printf 'log=%s\n' "$log_path"
          return 0
          ;;
        linux)
          [ -x "$artifact" ] || {
            printf '%s\n' "forge-backend: built native Linux executable missing: $artifact" >&2
            exit 1
          }
          if command -v nohup >/dev/null 2>&1; then
            nohup "$artifact" >"$log_path" 2>&1 &
          else
            "$artifact" >"$log_path" 2>&1 &
          fi
          pid=$!
          printf 'launched=1\n'
          printf 'mode=native-desktop-executable\n'
          printf 'artifact=%s\n' "$artifact"
          printf 'built_artifact=%s\n' "$artifact"
          printf 'built_exec=%s\n' "$built_exec"
          printf 'entry=%s\n' "$workspace_path/generated"
          printf 'pid=%s\n' "$pid"
          printf 'log=%s\n' "$log_path"
          return 0
          ;;
        *)
          printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
          exit 1
          ;;
      esac
      ;;
    web)
      os=$(os_id)
      host_target=$(host_workspace_target_id 2>/dev/null || true)
      workspace_slug=$(resolve_workspace_slug "$workspace_conf" "$workspace_path")
      log_dir="$root/_tmp/workbench/log"
      mkdir -p "$log_dir"
      log_path="$log_dir/workspace-$workspace_slug-run.log"
      if [ "$run_mode" = 'install-first' ]; then
        install_out=$(cmd_install_workspace "$root" "$workspace_path" "$context" "$host_target")
        built_artifact=$(printf '%s\n' "$install_out" | kv_read artifact)
        installed_path=$(printf '%s\n' "$install_out" | kv_read installed)
        launcher_path=$(printf '%s\n' "$install_out" | kv_read launcher)
        workspace_title=$(printf '%s\n' "$install_out" | kv_read app_name)
        [ -n "$workspace_title" ] || workspace_title=$(workspace_display_title "$workspace_path" "$workspace_conf")
        stop_desktop_instances_for_slug "$root" "$workspace_slug" "$workspace_title" "$os"
        case "$os" in
          darwin)
            [ -n "$installed_path" ] || installed_path="$built_artifact"
            [ -d "$installed_path" ] || {
              printf '%s\n' "forge-backend: installed project macOS bundle missing: $installed_path" >&2
              exit 1
            }
            command -v open >/dev/null 2>&1 || {
              printf '%s\n' "forge-backend: open command not available on this system" >&2
              exit 1
            }
            open "$installed_path"
            printf 'launched=1\n'
            printf 'mode=desktop-installed\n'
            printf 'artifact=%s\n' "$installed_path"
            printf 'built_artifact=%s\n' "$built_artifact"
            printf 'installed=%s\n' "$installed_path"
            [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
            printf 'entry=%s\n' "$(printf '%s\n' "$install_out" | kv_read entry)"
            printf 'log=%s\n' "$log_path"
            return 0
            ;;
          linux)
            launch_exec=''
            if [ -n "$launcher_path" ] && [ -x "$launcher_path" ]; then
              launch_exec="$launcher_path"
            elif [ -n "$installed_path" ] && [ -x "$installed_path/AppRun" ]; then
              launch_exec="$installed_path/AppRun"
            fi
            [ -n "$launch_exec" ] || {
              printf '%s\n' "forge-backend: installed project Linux launcher missing for $workspace_path" >&2
              exit 1
            }
            if command -v nohup >/dev/null 2>&1; then
              nohup "$launch_exec" >"$log_path" 2>&1 &
            else
              "$launch_exec" >"$log_path" 2>&1 &
            fi
            pid=$!
            printf 'launched=1\n'
            printf 'mode=desktop-installed\n'
            printf 'artifact=%s\n' "$launch_exec"
            printf 'built_artifact=%s\n' "$built_artifact"
            printf 'installed=%s\n' "$installed_path"
            [ -n "$launcher_path" ] && printf 'launcher=%s\n' "$launcher_path"
            printf 'entry=%s\n' "$(printf '%s\n' "$install_out" | kv_read entry)"
            printf 'pid=%s\n' "$pid"
            printf 'log=%s\n' "$log_path"
            return 0
            ;;
          *)
            printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
            exit 1
            ;;
        esac
      fi
      ;;
    *)
      printf '%s\n' "forge-backend: project context must be web, native-desktop, or godot" >&2
      exit 2
      ;;
  esac

  run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
  if ! app_dir=$(resolve_workspace_app_dir "$workspace_path" "$workspace_conf" 2>/dev/null); then
    printf '%s\n' "forge-backend: project app index not found: $workspace_path" >&2
    exit 1
  fi
  app_entry_suffix=''
  if [ "$app_dir" != "$workspace_path" ]; then
    app_entry_suffix=${app_dir#"$workspace_path"}
  fi

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
    printf '%s\n' "forge-backend: project has no runnable target for this host (enable $host_target or hosted-web)" >&2
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
    final_bundle="$bundle_root/$workspace_title.app"
    staged_root=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-workspace-bundle.XXXXXX")
    staged_bundle="$staged_root/$workspace_title.app"
    mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources/$workspace_slug" "$staged_bundle/Contents/Resources/.host"

    copy_tree_for_bundle "$workspace_path" "$staged_bundle/Contents/Resources/$workspace_slug/"
    rm -rf "$staged_bundle/Contents/Resources/$workspace_slug/themes"
    mkdir -p "$staged_bundle/Contents/Resources/$workspace_slug/.host"
    cp -R "$root/apps/.host/shared" "$staged_bundle/Contents/Resources/$workspace_slug/.host/"
    cp -R "$root/apps/.host/shared" "$staged_bundle/Contents/Resources/.host/"
    printf '%s\n' "$root" > "$staged_bundle/Contents/Resources/wizardry-apps-root.txt"
    cp "$host_bin" "$staged_bundle/Contents/MacOS/wizardry-host"

    bundle_app_dir="$app_dir"

    icon_source=''
    icon_source_format=''
    workspace_icon_source=$(project_preferred_bundle_icon_path "$workspace_path" || true)
    app_icon_source=$(project_preferred_bundle_icon_path "$app_dir" || true)
    if [ -n "$workspace_icon_source" ]; then
      icon_source="$workspace_icon_source"
      icon_source_format=$(icon_source_format_for_path "$icon_source")
    elif [ -n "$app_icon_source" ]; then
      icon_source="$app_icon_source"
      icon_source_format=$(icon_source_format_for_path "$icon_source")
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
        sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -s format png -z $((size * 2)) $((size * 2)) "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
      done
      icon_name="forge-${icon_hash}.icns"
      if iconutil -c icns "$iconset" -o "$staged_bundle/Contents/Resources/$icon_name" >/dev/null 2>&1; then
        icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
      else
        icon_name="forge-icon-${icon_hash}.png"
        cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
        icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
      fi
      rm -rf "$iconset"
    elif [ "$icon_source_format" = 'png' ]; then
      icon_name="forge-icon-${icon_hash}.png"
      cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
      icon_key="<key>CFBundleIconFile</key><string>$icon_name</string>"
    elif [ "$icon_source_format" = 'icns' ]; then
      icon_name="forge-${icon_hash}.icns"
      cp "$icon_source" "$staged_bundle/Contents/Resources/$icon_name"
      icon_key="<key>CFBundleIconFile</key><string>${icon_name%.icns}</string>"
    fi

    bundle_id="com.wizardry.workspace.$workspace_slug"
    bundle_version=$(printf '%s' "${icon_hash:-$workspace_slug}" | cksum | awk '{ print $1 }')
    [ -n "$bundle_version" ] || bundle_version=1
    desktop_window_keys=''
    desktop_initial_width=$(workspace_field "$workspace_conf" desktop_initial_width "")
    desktop_initial_height=$(workspace_field "$workspace_conf" desktop_initial_height "")
    desktop_min_width=$(workspace_field "$workspace_conf" desktop_min_width "")
    desktop_min_height=$(workspace_field "$workspace_conf" desktop_min_height "")
    case "$desktop_initial_width" in ''|*[!0-9]*) ;; *) desktop_window_keys="${desktop_window_keys}<key>WizardryInitialWidth</key><integer>$desktop_initial_width</integer>
" ;; esac
    case "$desktop_initial_height" in ''|*[!0-9]*) ;; *) desktop_window_keys="${desktop_window_keys}<key>WizardryInitialHeight</key><integer>$desktop_initial_height</integer>
" ;; esac
    case "$desktop_min_width" in ''|*[!0-9]*) ;; *) desktop_window_keys="${desktop_window_keys}<key>WizardryMinimumWidth</key><integer>$desktop_min_width</integer>
" ;; esac
    case "$desktop_min_height" in ''|*[!0-9]*) ;; *) desktop_window_keys="${desktop_window_keys}<key>WizardryMinimumHeight</key><integer>$desktop_min_height</integer>
" ;; esac
    cat > "$staged_bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$workspace_title</string>
<key>CFBundleDisplayName</key><string>$workspace_title</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>$bundle_version</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>wizardry-host</string>
<key>WizardryAppEntry</key><string>$bundle_app_dir</string>
$desktop_window_keys$icon_key
</dict></plist>
PLIST

    ensure_macos_bundle_signature "$staged_bundle" || {
      printf '%s\n' "forge-backend: failed to sign macOS project bundle: $staged_bundle" >&2
      exit 1
    }

    stop_desktop_instances_for_slug "$root" "$workspace_slug" "$workspace_title" "$os"
    mkdir -p "$bundle_root"
    rm -rf "$final_bundle"
    mv "$staged_bundle" "$final_bundle"
    rmdir "$staged_root" 2>/dev/null || :
    bundle_app_dir="$app_dir"
    if ! launch_workspace_bundle_macos "$final_bundle" "$final_bundle/Contents/MacOS/wizardry-host" "$bundle_app_dir"; then
      printf '%s\n' "forge-backend: failed to launch project bundle: $final_bundle" >&2
      exit 1
    fi
    printf 'launched=1\n'
    printf 'mode=desktop-executable\n'
    printf 'artifact=%s\n' "$final_bundle"
    printf 'entry=%s\n' "$bundle_app_dir"
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
    if [ -f "$workspace_path/assets/icons/linux/256x256/forge-icon.png" ]; then
      linux_ws_icon_source="$workspace_path/assets/icons/linux/256x256/forge-icon.png"
    elif [ -f "$workspace_path/assets/forge-icon.png" ]; then
      linux_ws_icon_source="$workspace_path/assets/forge-icon.png"
    elif [ -f "$app_dir/assets/icons/linux/256x256/forge-icon.png" ]; then
      linux_ws_icon_source="$app_dir/assets/icons/linux/256x256/forge-icon.png"
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

    app_entry="$appdir/usr/share/$bundle_slug$app_entry_suffix"
    pid=$(launch_desktop_host_linux "$appdir/AppRun" "$app_entry" "$log_path") || {
      printf '%s\n' "forge-backend: failed to launch project desktop host: $app_entry" >&2
      exit 1
    }
    printf 'launched=1\n'
    printf 'mode=desktop-executable\n'
    printf 'artifact=%s\n' "$appdir"
    printf 'entry=%s\n' "$app_entry"
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
    printf '%s\n' "forge-backend: serve-hosted-web requires REF (APP_SLUG or PROJECT_PATH)" >&2
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
        printf '%s\n' "forge-backend: project not found: $workspace_path" >&2
        exit 1
      }
      workspace_path=$(CDPATH= cd -- "$workspace_path" && pwd -P)
      workspace_slug=$(sanitize_bundle_component "$(basename "$workspace_path")")
      workspace_conf="$workspace_path/wizardry.workspace.conf"
      [ -f "$workspace_conf" ] || {
        printf '%s\n' "forge-backend: project is missing wizardry.workspace.conf: $workspace_path" >&2
        exit 1
      }
      ensure_workspace_emitted_legal_files "$root" "$workspace_path" "$workspace_conf"
      run_workspace_rebuild "$root" "$workspace_path" "$workspace_conf" >/dev/null
      workspace_hosted_web_mode=$(workspace_field "$workspace_conf" hosted_web_mode "")
      case "$workspace_hosted_web_mode" in
        "")
          ;;
        web-wizardry-site)
          serve_workspace_managed_hosted_web "$root" "$workspace_path" "$workspace_conf" "$workspace_slug" || exit 1
          return 0
          ;;
        *)
          printf '%s\n' "forge-backend: unknown project hosted_web_mode: $workspace_hosted_web_mode" >&2
          exit 1
          ;;
      esac
      if ! app_dir=$(resolve_workspace_app_dir "$workspace_path" "$workspace_conf" 2>/dev/null); then
        printf '%s\n' "forge-backend: project app index not found: $workspace_path" >&2
        exit 1
      fi
      command -v python3 >/dev/null 2>&1 || {
        printf '%s\n' "forge-backend: python3 is required to serve project hosted web targets" >&2
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
  sh "$root/tools/icons/stage-android-launcher-icons.sh" "$root/apps/$slug" "$root/apps/.host/android/app/src/main/res"

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

is_generic_web_starter() {
  starter=${1-}
  case "$starter" in
    minimal|reference-app|panel|sidebar|topbar|dashboard|studio)
      return 0
      ;;
  esac
  return 1
}

workspace_uses_emitted_project_license() {
  starter=${1-}
  context=${2-}
  case "$context:$starter" in
    web:minimal|web:reference-app|web:panel|web:sidebar|web:topbar|web:dashboard|web:studio|godot:blank|native-desktop:blank)
      return 0
      ;;
  esac
  return 1
}

escape_sed_replacement() {
  printf '%s' "${1-}" | sed 's/[\/&]/\\&/g'
}

render_app_template_file() {
  src_path=$1
  dest_path=$2
  app_name=$3
  app_slug=$4
  escaped_name=$(escape_sed_replacement "$app_name")
  escaped_slug=$(escape_sed_replacement "$app_slug")
  sed \
    -e "s/__APP_NAME__/$escaped_name/g" \
    -e "s/__APP_SLUG__/$escaped_slug/g" \
    "$src_path" > "$dest_path"
}

render_native_template_file() {
  src_path=$1
  dest_path=$2
  app_name=$3
  app_id=$4
  escaped_name=$(escape_sed_replacement "$app_name")
  escaped_id=$(escape_sed_replacement "$app_id")
  sed \
    -e "s/__APP_NAME__/$escaped_name/g" \
    -e "s/__APP_ID__/$escaped_id/g" \
    "$src_path" > "$dest_path"
}

write_web_starter_template() {
  root=$1
  starter=$2
  app_dir=$3
  app_name=$4
  app_slug=$5

  template_dir="$root/apps/forge/starter-templates/web/$starter"
  [ -d "$template_dir" ] || {
    printf '%s\n' "forge-backend: web starter template directory missing: $template_dir" >&2
    exit 1
  }

  mkdir -p "$app_dir"
  (
    cd "$template_dir"
    find . -type d | while IFS= read -r rel_dir; do
      rel_dir=$(printf '%s' "$rel_dir" | sed 's#^\./##')
      [ -n "$rel_dir" ] || continue
      rendered_dir=$(printf '%s' "$rel_dir" | sed "s/__APP_SLUG__/$app_slug/g")
      mkdir -p "$app_dir/$rendered_dir"
    done

    find . -type f | while IFS= read -r rel_file; do
      rel_file=$(printf '%s' "$rel_file" | sed 's#^\./##')
      rendered_rel=$(printf '%s' "$rel_file" | sed "s/__APP_SLUG__/$app_slug/g")
      src_path="$template_dir/$rel_file"
      dest_path="$app_dir/$rendered_rel"
      mkdir -p "$(dirname "$dest_path")"
      case "$src_path" in
        *.html|*.css|*.js|*.md|*.txt|*.json|*.svg|*.conf|*.sh|*.yaml|*.yml)
          render_app_template_file "$src_path" "$dest_path" "$app_name" "$app_slug"
          ;;
        *)
          cp "$src_path" "$dest_path"
          ;;
      esac
      if [ -x "$src_path" ]; then
        chmod +x "$dest_path"
      fi
    done
  )
}

write_native_desktop_starter_template() {
  root=$1
  workspace_dir=$2
  app_name=$3
  app_id=$4

  template_dir="$root/apps/forge/starter-templates/native-desktop/blank"
  [ -d "$template_dir" ] || {
    printf '%s\n' "forge-backend: native desktop starter template directory missing: $template_dir" >&2
    exit 1
  }

  mkdir -p \
    "$workspace_dir/ir" \
    "$workspace_dir/scripts" \
    "$workspace_dir/generated/macos/Sources/App" \
    "$workspace_dir/generated/linux/src" \
    "$workspace_dir/schemas"

  render_native_template_file "$template_dir/ir/app.ir.yaml" "$workspace_dir/ir/app.ir.yaml" "$app_name" "$app_id"
  render_native_template_file "$template_dir/scripts/render-native-desktop.sh" "$workspace_dir/scripts/render-native-desktop.sh" "$app_name" "$app_id"
  render_native_template_file "$template_dir/scripts/validate-native-desktop-ir.sh" "$workspace_dir/scripts/validate-native-desktop-ir.sh" "$app_name" "$app_id"
  chmod +x "$workspace_dir/scripts/render-native-desktop.sh" "$workspace_dir/scripts/validate-native-desktop-ir.sh"
  cp "$root/schemas/native-desktop-ir-v1.json" "$workspace_dir/schemas/native-desktop-ir-v1.json"
  (
    cd "$workspace_dir"
    sh "scripts/render-native-desktop.sh"
  )
}

write_emitted_project_legal_files() {
  root=$1
  project_dir=$2

  mkdir -p "$project_dir"
  cp "$root/licenses/AGPL-3.0-or-later.txt" "$project_dir/LICENSE"
  cp "$root/licenses/WIZARDRY_ADDENDUM.md" "$project_dir/WIZARDRY_ADDENDUM.md"
}

write_emitted_project_readme_if_missing() {
  project_dir=$1
  app_name=$2
  context=$3
  readme_path="$project_dir/README.md"
  [ -f "$readme_path" ] && return 0

  summary="Generated by App Forge."
  case "$context" in
    native-desktop)
      summary="Native desktop app scaffolded by App Forge."
      ;;
  esac

  cat > "$readme_path" <<README
# $app_name

$summary

- Development context: $context
- License: GNU AGPL-3.0-or-later
- Additional terms: see WIZARDRY_ADDENDUM.md
README
}

write_imported_project_readme_if_missing() {
  project_dir=$1
  app_name=$2
  context=$3
  readme_path="$project_dir/README.md"
  [ -f "$readme_path" ] && return 0

  cat > "$readme_path" <<README
# $app_name

Imported into App Forge as a managed workspace.

- Development context: $context
README
}

ensure_workspace_emitted_legal_files() {
  root=$1
  workspace_path=$2
  workspace_conf=$3

  starter=$(workspace_field "$workspace_conf" starter "")
  context=$(workspace_field "$workspace_conf" development_context "")
  if ! workspace_uses_emitted_project_license "$starter" "$context"; then
    return 0
  fi

  license_path="$workspace_path/LICENSE"
  addendum_path="$workspace_path/WIZARDRY_ADDENDUM.md"
  if [ ! -f "$license_path" ] || [ ! -f "$addendum_path" ]; then
    write_emitted_project_legal_files "$root" "$workspace_path"
  fi
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
  app_name=$(normalize_generated_display_name "$app_name")
  validate_generated_display_name "$app_name" "APP_NAME"
  require_jq

  app_dir="$root/apps/$slug"
  [ ! -e "$app_dir" ] || {
    printf '%s\n' "forge-backend: app path already exists: $app_dir" >&2
    exit 1
  }
  if manifest_app_exists "$root" "$slug"; then
    printf '%s\n' "forge-backend: app slug already exists in manifest: $slug" >&2
    exit 1
  fi

  case "$template" in
    minimal|reference-app|panel|sidebar|topbar|dashboard|studio) ;;
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
    minimal|reference-app|panel|sidebar|topbar|dashboard|studio)
      write_web_starter_template "$root" "$template" "$app_dir" "$app_name" "$slug"
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
  app_name=$(normalize_generated_display_name "$app_name")
  validate_generated_display_name "$app_name" "APP_NAME"

  targets=$(normalize_targets_value "$targets")
  [ -n "$targets" ] || {
    printf '%s\n' "forge-backend: scaffold-workspace requires non-empty TARGETS" >&2
    exit 2
  }

  [ -n "$project_root" ] || project_root=$(workspace_default_root)
  case "$project_root" in
    /*) ;;
    *)
      project_root="$(pwd -P)/$project_root"
      ;;
  esac
  reject_line_breaks "$project_root" "project root"
  mkdir -p "$project_root"

  workspace_dir="$project_root/$slug"
  reject_line_breaks "$workspace_dir" "project path"
  [ ! -e "$workspace_dir" ] || {
    printf '%s\n' "forge-backend: project path already exists: $workspace_dir" >&2
    exit 1
  }

  case "$context" in
    web)
      project_type=application
      development_context=web

      case "$starter" in
        minimal|reference-app|panel|sidebar|topbar|dashboard|studio|clone) ;;
        *)
          printf '%s\n' "forge-backend: scaffold-workspace unknown web starter: $starter" >&2
          exit 2
          ;;
      esac

      app_dir="$workspace_dir/app"
      mkdir -p "$app_dir"

      case "$starter" in
        minimal|reference-app|panel|sidebar|topbar|dashboard|studio)
          write_web_starter_template "$root" "$starter" "$app_dir" "$app_name" "$slug"
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

      if workspace_uses_emitted_project_license "$starter" "$development_context"; then
        write_emitted_project_legal_files "$root" "$workspace_dir"
        write_emitted_project_readme_if_missing "$workspace_dir" "$app_name" "$development_context"
      else
        write_imported_project_readme_if_missing "$workspace_dir" "$app_name" "$development_context"
      fi
      ;;

    native-desktop)
      project_type=native-desktop
      development_context=native-desktop

      case "$starter" in
        blank|clone) ;;
        *)
          printf '%s\n' "forge-backend: scaffold-workspace unknown native desktop starter: $starter" >&2
          exit 2
          ;;
      esac

      mkdir -p "$workspace_dir"
      native_ir_path="ir/app.ir.yaml"

      case "$starter" in
        blank)
          write_native_desktop_starter_template "$root" "$workspace_dir" "$app_name" "$slug"
          write_emitted_project_legal_files "$root" "$workspace_dir"
          write_emitted_project_readme_if_missing "$workspace_dir" "$app_name" "$development_context"
          ;;
        clone)
          [ -n "$source" ] || {
            printf '%s\n' "forge-backend: scaffold-workspace native desktop clone requires SOURCE" >&2
            exit 2
          }
          validate_slug "$source"

          source_dir=''
          for candidate in \
            "$project_root/$source" \
            "$root/apps/$source"; do
            if [ -d "$candidate" ]; then
              source_dir=$candidate
              break
            fi
          done

          [ -d "$source_dir" ] || {
            printf '%s\n' "forge-backend: source native desktop project not found: $source" >&2
            exit 1
          }
          rm -rf "$workspace_dir"
          mkdir -p "$workspace_dir"
          cp -R "$source_dir"/. "$workspace_dir/"
          native_ir_path=$(resolve_workspace_native_ir_path "$workspace_dir" "$workspace_dir/wizardry.workspace.conf" 2>/dev/null || printf '%s' "ir/app.ir.yaml")
          write_imported_project_readme_if_missing "$workspace_dir" "$app_name" "$development_context"
          ;;
      esac

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
          cat > "$workspace_dir/tool_main.gd" <<'GDSCRIPT'
extends Node

func _ready():
    print("Wizardry Godot tool project ready.")
GDSCRIPT
          sync_godot_project_icon_config "$workspace_dir"
          write_emitted_project_legal_files "$root" "$workspace_dir"
          write_emitted_project_readme_if_missing "$workspace_dir" "$app_name" "$development_context"
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
          write_imported_project_readme_if_missing "$workspace_dir" "$app_name" "$development_context"
          ;;
        *)
          printf '%s\n' "forge-backend: scaffold-workspace unknown godot starter: $starter" >&2
          exit 2
          ;;
      esac

      ;;

    *)
      printf '%s\n' "forge-backend: scaffold-workspace context must be web, native-desktop, or godot" >&2
      exit 2
      ;;
  esac

  run_rebuild_command=":"
  case "$development_context" in
    native-desktop)
      run_rebuild_command="sh scripts/render-native-desktop.sh"
      ;;
  esac

  profile_source=""
  case "$starter" in
    clone)
      profile_source=${source-}
      ;;
  esac

  profile="$workspace_dir/wizardry.workspace.conf"
  cat > "$profile" <<CONF
# Wizardry Apps project profile
project_id=$slug
title=$app_name
project_type=$project_type
development_context=$development_context
starter=$starter
targets=$targets
run_rebuild_command=$run_rebuild_command
source=$profile_source
root=$workspace_dir
CONF

  case "$development_context" in
    web)
      if [ -f "$workspace_dir/app/index.html" ]; then
        printf 'app_subpath=%s\n' "app" >>"$profile"
      fi
      ;;
    native-desktop)
      printf 'native_ir_path=%s\n' "${native_ir_path:-ir/app.ir.yaml}" >>"$profile"
      ;;
  esac

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
    mkdir -p "$site_dir/site/static"
    rm -rf "$site_dir/site/static/themes"
    ln -s "$root/web/.themes" "$site_dir/site/static/themes"
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

  case "$task" in
    validate-manifest|test-core|test-adapters|test-release-tools)
      ;;
    *)
      printf '%s\n' "forge-backend: unknown task: $task" >&2
      exit 2
      ;;
  esac

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
  get-workspace-profile)
    cmd_get_workspace_profile "${2-}" "${3-}"
    ;;
  workspace-git-status)
    cmd_workspace_git_status "${2-}" "${3-}"
    ;;
  workspace-git-init)
    cmd_workspace_git_init "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  workspace-git-set-remote)
    cmd_workspace_git_set_remote "${2-}" "${3-}" "${4-}"
    ;;
  workspace-git-set-branch)
    cmd_workspace_git_set_branch "${2-}" "${3-}" "${4-}"
    ;;
  workspace-git-fetch)
    cmd_workspace_git_fetch "${2-}" "${3-}"
    ;;
  workspace-git-pull)
    cmd_workspace_git_pull "${2-}" "${3-}"
    ;;
  workspace-git-push)
    cmd_workspace_git_push "${2-}" "${3-}"
    ;;
  workspace-git-repo-url)
    cmd_workspace_git_repo_url "${2-}" "${3-}"
    ;;
  workspace-git-pr-url)
    cmd_workspace_git_pr_url "${2-}" "${3-}"
    ;;
  workspace-git-release)
    cmd_workspace_git_release "${2-}" "${3-}"
    ;;
  workspace-git-install-release)
    cmd_workspace_git_install_release "${2-}" "${3-}"
    ;;
  pick-workspace-subpath)
    cmd_pick_workspace_subpath "${2-}" "${3-}"
    ;;
  get-ui-prefs)
    cmd_get_ui_prefs "${2-}"
    ;;
  set-ui-pref)
    cmd_set_ui_pref "${2-}" "${3-}" "${4-}"
    ;;
  set-workspace-field)
    cmd_set_workspace_field "${2-}" "${3-}" "${4-}" "${5-}"
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
    cmd_set_app_icon "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  set-workspace-icon)
    cmd_set_workspace_icon "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  set-app-icon-file)
    cmd_set_app_icon_file "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  set-workspace-icon-file)
    cmd_set_workspace_icon_file "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  regenerate-app-icon-assets)
    cmd_regenerate_app_icon_assets "${2-}" "${3-}" "${4-}"
    ;;
  regenerate-workspace-icon-assets)
    cmd_regenerate_workspace_icon_assets "${2-}" "${3-}" "${4-}"
    ;;
  icon-tool-status)
    cmd_icon_tool_status "${2-}"
    ;;
  install-icon-tool)
    cmd_install_icon_tool "${2-}" "${3-}"
    ;;
  uninstall-icon-tool)
    cmd_uninstall_icon_tool "${2-}" "${3-}"
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
    cmd_run_desktop "${2-}" "${3-}" "${4-}"
    ;;
  rebuild-workspace)
    cmd_rebuild_workspace "${2-}" "${3-}" "${4-}"
    ;;
  install-desktop)
    cmd_install_desktop "${2-}" "${3-}" "${4-}"
    ;;
  install-workspace)
    cmd_install_workspace "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  run-workspace)
    cmd_run_workspace "${2-}" "${3-}" "${4-}" "${5-}"
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
