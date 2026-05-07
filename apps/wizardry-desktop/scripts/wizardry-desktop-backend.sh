#!/bin/sh

set -eu

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: wizardry-desktop-backend.sh ACTION [ARGS...]

Actions:
  root-hint [ROOT_HINT]
  list-themes [ROOT_HINT]
  get-ui-prefs
  set-ui-pref KEY VALUE
  list-spell-categories [ROOT_HINT]
  list-spells SPELL_REF [ROOT_HINT]
  list-synonyms
  add-synonym ALIAS TARGET
  remove-synonym ALIAS
  run-spell SPELL_REF SPELL_NAME [ROOT_HINT]
  spell-help SPELL_REF SPELL_NAME [ROOT_HINT]
  list-menu-spells [ROOT_HINT]
  list-main-menu-entries [ROOT_HINT]
  list-system-menu-actions [ROOT_HINT]
  list-mud-actions [ROOT_HINT]
  menu-help MENU_NAME [ROOT_HINT]
  run-menu MENU_NAME [MENU_ARG] [ROOT_HINT]
  open-menu-terminal MENU_NAME [MENU_ARG] [ROOT_HINT]
  list-memorized-spells
  memorize-spell SPELL_NAME [COMMAND]
  list-arcana-install [INSTALL_ROOT]
  list-arcana-module-items MODULE [INSTALL_ROOT]
  run-arcana-install MODULE
  run-action ACTION [ARG1] [ARG2] [ROOT_HINT]
  run-system ACTION
  run-mud-action ACTION [ARG] [ROOT_HINT]
  list-watch [N]
USAGE
  exit 0
  ;;
esac

SCRIPT_DIR=${SCRIPT_DIR-$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)}
WIZARDRY_DIR_FALLBACK=${WIZARDRY_DIR:-"${HOME}/.wizardry"}
WIZARDRY_APPS_ROOT_FALLBACK="${HOME}/git/wizardry-apps"
PREFS_ROOT=${XDG_CONFIG_HOME:-${HOME}/.config}/wizardry-apps/wizardry-desktop

hascmd() {
  [ -n "${1-}" ] && command -v "$1" >/dev/null 2>&1
}

platform_id() {
  if hascmd os_id; then
    os_id 2>/dev/null || true
    return
  fi
  kernel=$(uname -s 2>/dev/null || printf 'unknown')
  case "$kernel" in
    Darwin) printf '%s\n' "darwin" ;;
    Linux) printf '%s\n' "linux" ;;
    FreeBSD|OpenBSD|NetBSD) printf '%s\n' "bsd" ;;
    *) printf '%s\n' "$kernel" ;;
  esac
}

safe_name() {
  case "${1-}" in
    ""|*[!a-zA-Z0-9._-]*)
      return 1
      ;;
  esac
  return 0
}

config_path() {
  printf '%s\n' "$PREFS_ROOT/config"
}

normalize_pref_key() {
  case "${1-}" in
    ""|*[!a-zA-Z0-9._-]*)
      return 1
      ;;
  esac
  printf '%s\n' "$1"
  return 0
}

sanitize_value() {
  printf '%s' "${1-}" | tr '\r\n' ' '
}

sanitize_record_field() {
  printf '%s' "${1-}" | tr '\r\n\t|' '    '
}

has_line_break() {
  value=${1-}
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  case "$value" in *"$nl_char"*|*"$cr_char"*) return 0 ;; esac
  return 1
}

normalize_watch_actor() {
  actor=${1-}
  if [ -z "$actor" ]; then
    return 0
  fi
  actor=$(printf '%s' "$actor" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
  if [ -z "$actor" ]; then
    return 0
  fi
  case "$actor" in
    wizardry-* ) printf '%s\n' "$actor" ;;
    * ) printf 'wizardry-%s\n' "$actor" ;;
  esac
}

watch_actor_for_source() {
  source=${1-}
  case "$source" in
    builtin|custom|web)
      printf 'wizardry-core'
      ;;
    *)
      normalize_watch_actor "$source"
      ;;
  esac
}

watch_app_for_spell_file() {
  file=${1-}
  [ -n "$file" ] || return 0

  if [ -n "$WIZARDRY_DESKTOP_APP" ]; then
    normalize_watch_actor "$WIZARDRY_DESKTOP_APP"
    return
  fi
  if [ -n "$WIZARDRY_APP_NAME" ]; then
    normalize_watch_actor "$WIZARDRY_APP_NAME"
    return
  fi

  case "$file" in
    "$WIZARDRY_APPS_ROOT_FALLBACK/spells/.arcana/"*)
      module=${file#"$WIZARDRY_APPS_ROOT_FALLBACK/spells/.arcana/"}
      module=${module%%/*}
      if [ -n "$module" ]; then
        printf '%s\n' "arcana-${module}"
      fi
      return
      ;;
    "$WIZARDRY_DIR_FALLBACK/spells/"*)
      printf '%s\n' "wizardry-core"
      return
      ;;
    "$HOME/.wizardry/spells/"*)
      printf '%s\n' "wizardry-home"
      return
      ;;
    "$HOME/spells/"*)
      printf '%s\n' "wizardry-local"
      return
      ;;
    *)
      ;;
  esac
}

strip_ansi() {
  printf '%s\n' "${1-}" | sed 's/\x1b\[[0-9;]*m//g'
}

normalize_status() {
  status=${1-}
  status=$(strip_ansi "$status")
  status=$(sanitize_record_field "$status")
  status=$(printf '%s' "$status" | awk '{$1=$1; print}' )
  if [ -z "$status" ]; then
    status='not installed'
  fi
  printf '%s\n' "$status"
}

watch_log_path() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/wizardry/wizardry-desktop/watch.log"
}

record_watch() {
  kind=${1-}
  source=${2-}
  app=${3-}
  status=${4-}

  path=$(watch_log_path)
  mkdir -p "${path%/*}" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s 2>/dev/null || printf '0')" \
    "$kind" \
    "$(printf '%s' "$source" | tr '\r\n\t' '   ')" \
    "$(printf '%s' "$app" | tr '\r\n\t' '   ')" \
    "$(printf '%s' "$status" | tr '\r\n\t' '   ')" >>"$path"
}

list_watch() {
  path=$(watch_log_path)
  limit=${1-200}
  case "$limit" in
    ''|*[!0-9]*)
      limit=200
      ;;
  esac
  if [ -f "$path" ]; then
    tab=$(printf '\t')
    tail -n "$limit" "$path" | awk -F "$tab" 'NF == 5 { gsub(/\r/, " "); print }'
  fi
}

write_pref_file() {
  file=$1
  key=$2
  value=$3

  mkdir -p "$PREFS_ROOT"
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-pref.XXXXXX")

  found=0
  if [ -f "$file" ]; then
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
  fi

  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
  fi

  mv "$tmp_file" "$file"
}

require_root() {
  hint=${1-}
  if [ -n "$hint" ]; then
    if has_line_break "$hint"; then
      printf '%s\n' "wizardry-desktop-backend: root hint must not contain line breaks" >&2
      exit 2
    fi
    printf '%s\n' "$hint"
    return 0
  fi

  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && [ -d "$WIZARDRY_APPS_ROOT" ]; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT"
    return 0
  fi
  if [ -n "${WIZARDRY_DIR-}" ] && [ -d "$WIZARDRY_DIR" ]; then
    if [ -d "$WIZARDRY_DIR/spells" ] || [ -d "$WIZARDRY_DIR/web/.themes" ] || [ -d "$WIZARDRY_DIR/apps/wizardry-desktop" ]; then
      printf '%s\n' "$WIZARDRY_DIR"
      return 0
    fi
  fi
  if [ -d "$WIZARDRY_APPS_ROOT_FALLBACK" ]; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT_FALLBACK"
    return 0
  fi
  if [ -d "$SCRIPT_DIR/../.." ]; then
    printf '%s\n' "$SCRIPT_DIR/../.."
    return 0
  fi

  printf '%s\n' "$WIZARDRY_APPS_ROOT_FALLBACK"
}

cmd_root_hint() {
  hint=${1-}
  root=$(require_root "$hint")
  printf '%s\n' "$root"
}

theme_files() {
  theme_root=${1-}
  if [ -z "$theme_root" ] || [ ! -d "$theme_root" ]; then
    return 0
  fi
  find "$theme_root" -maxdepth 1 -type f -name '*.css' 2>/dev/null | \
    sed 's#^.*/##' | sed 's/\.css$//' | \
    grep -E '^[a-z0-9_-]+$' | sort -u
}

cmd_list_themes() {
  root=$(require_root "${1-}")
  root="${root:-$WIZARDRY_APPS_ROOT_FALLBACK}"
  themes=$(theme_files "$root/templates/web/.themes")
  if [ -z "$themes" ] && [ -d "$WIZARDRY_APPS_ROOT_FALLBACK/templates/web/.themes" ]; then
    themes=$(theme_files "$WIZARDRY_APPS_ROOT_FALLBACK/templates/web/.themes")
  fi
  if [ -z "$themes" ] && [ -d "$root/apps/forge/themes" ]; then
    themes=$(theme_files "$root/apps/forge/themes")
  fi
  printf '%s\n' "$themes"
}

cmd_get_ui_prefs() {
  cfg=$(config_path)
  if [ -f "$cfg" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        *=*)
          key=${line%%=*}
          value=${line#*=}
          if normalized_key=$(normalize_pref_key "$key" 2>/dev/null); then
            printf '%s=%s\n' "$normalized_key" "$(sanitize_value "$value")"
          fi
          ;;
      esac
    done <"$cfg"
  fi
}

cmd_set_ui_pref() {
  key=${1-}
  value=${2-}
  [ -n "$key" ] || {
    printf '%s\n' "wizardry-desktop-backend: set-ui-pref requires KEY VALUE" >&2
    exit 2
  }
  key=$(normalize_pref_key "$key") || {
    printf '%s\n' "wizardry-desktop-backend: invalid key: $key" >&2
    exit 2
  }
  value=$(sanitize_value "$value")
  cfg=$(config_path)
  mkdir -p "$PREFS_ROOT"
  [ -f "$cfg" ] || : >"$cfg"
  write_pref_file "$cfg" "$key" "$value"
  printf 'key=%s\n' "$key"
  printf 'value=%s\n' "$value"
}

spell_roots() {
  root=${1-}
  [ -d "$root" ] || return 0

  # Core repository-backed spell roots.
  printf '%s|builtin\n' "$root/spells"
  if [ -d "$WIZARDRY_DIR_FALLBACK/spells" ]; then
    printf '%s|builtin\n' "$WIZARDRY_DIR_FALLBACK/spells"
  fi

  # User and environment spell roots.
  printf '%s|custom\n' "$HOME/.wizardry/spells"
  printf '%s|custom\n' "$HOME/spells"
}

collect_category_rows() {
  source_root=${1-}
  source_kind=${2-}
  [ -d "$source_root" ] || return 0
  [ "$source_kind" = "builtin" ] || [ "$source_kind" = "custom" ] || source_kind="custom"
  for cat_dir in "$source_root"/*; do
    [ -d "$cat_dir" ] || continue
    cat_name=$(basename "$cat_dir")
    case "$cat_name" in
      .*|menu) continue ;;
    esac
    safe_name "$cat_name" || continue
    count=$(count_spell_files "$cat_dir")
    [ "$count" -gt 0 ] || continue
    printf '%s|%s|%s|%s\n' "$source_kind:$cat_name" "$source_kind" "$cat_name" "$count"
  done
}

count_spell_files() {
  dir=${1-}
  if [ ! -d "$dir" ]; then
    printf '0\n'
    return
  fi
  n=0
  while IFS= read -r file || [ -n "$file" ]; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    if [ "$name" = menu ]; then
      continue
    fi
    case "$name" in
      .* ) continue ;;
    esac
    spell_name=${name%.sh}
    safe_name "$spell_name" || continue
    n=$((n + 1))
  done <<EOF
$(find "$dir" -maxdepth 1 -type f 2>/dev/null | sort)
EOF
  printf '%s\n' "$n"
}

cmd_list_spell_categories() {
  root=$(require_root "${1-}")
  seen=""

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-cats.XXXXXX")
  {
    collect_category_rows "$root/spells" "builtin"
    if [ "$WIZARDRY_APPS_ROOT_FALLBACK" != "$root" ]; then
      collect_category_rows "$WIZARDRY_APPS_ROOT_FALLBACK/spells" "builtin"
    fi
    if [ -d "$WIZARDRY_DIR_FALLBACK/spells" ]; then
      collect_category_rows "$WIZARDRY_DIR_FALLBACK/spells" "builtin"
    fi
    if [ "$HOME/.wizardry/spells" != "$WIZARDRY_DIR_FALLBACK/spells" ] && [ "$HOME/.wizardry/spells" != "$root/spells" ] && [ "$HOME/.wizardry/spells" != "$WIZARDRY_APPS_ROOT_FALLBACK/spells" ]; then
      collect_category_rows "$HOME/.wizardry/spells" "custom"
    fi
    if [ "$HOME/spells" != "$WIZARDRY_DIR_FALLBACK/spells" ] && [ "$HOME/spells" != "$root/spells" ] && [ "$HOME/spells" != "$WIZARDRY_APPS_ROOT_FALLBACK/spells" ]; then
      collect_category_rows "$HOME/spells" "custom"
    fi
  } >"$tmp_file"

  while IFS='|' read -r raw_id raw_kind raw_category count || [ -n "$raw_id" ]; do
    raw_id=${raw_id-}
    raw_kind=${raw_kind-}
    raw_category=${raw_category-}
    count=${count-}
    raw_id=$(printf '%s' "$raw_id" | sed 's/\r//g')
    raw_kind=$(printf '%s' "$raw_kind" | sed 's/\r//g')
    raw_category=$(printf '%s' "$raw_category" | sed 's/\r//g')
    count=$(printf '%s' "$count" | sed 's/\r//g')

    source_kind=${raw_id%%:*}
    category_name=${raw_id#*:}
    if [ -z "$source_kind" ] || [ -z "$category_name" ] || [ "$category_name" = "$raw_id" ]; then
      source_kind=$raw_kind
      category_name=$raw_category
    fi

    source_kind=$(printf '%s' "$source_kind" | sed 's/\r//g')
    category_name=$(printf '%s' "$category_name" | sed 's/\r//g')
    [ -n "$source_kind" ] || source_kind="builtin"
    [ -n "$category_name" ] || continue

    key="$source_kind|$category_name"
    case " $seen " in
      *" $key "*) continue ;;
    esac
    seen="$seen $key "
    [ "$count" -gt 0 ] || continue
    printf '%s|%s|%s|%s\n' "$source_kind:$category_name" "$source_kind" "$category_name" "$count"
  done <"$tmp_file" | sort -u

  rm -f "$tmp_file"
}

list_spell_files_in_dir() {
  dir=$1
  if [ ! -d "$dir" ]; then
    return 0
  fi
  while IFS= read -r file || [ -n "$file" ]; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    if [ "$name" = menu ]; then
      continue
    fi
    case "$name" in
      .* ) continue ;;
    esac
    spell_name=${name%.sh}
    safe_name "$spell_name" || continue
    printf '%s\n' "$spell_name"
  done <<EOF
$(find "$dir" -maxdepth 1 -type f 2>/dev/null | sort)
EOF
}

parse_spell_ref() {
  ref=${1-}
  case "$ref" in
    builtin:*|custom:*)
      ;;
    *)
      return 1
      ;;
  esac
  source=${ref%%:*}
  category=${ref#*:}
  [ "$source" = "builtin" ] || [ "$source" = "custom" ] || return 1
  safe_name "$category" || return 1
  return 0
}

cmd_list_spells() {
  ref=${1-}
  [ -n "$ref" ] || exit 0
  root=$(require_root "${2-}")

  parse_spell_ref "$ref" || {
    printf '%s\n' "wizardry-desktop-backend: invalid spell reference: $ref" >&2
    exit 2
  }
  source=${ref%%:*}
  category=${ref#*:}

  spell_dir_for "$root" "$source" "$category" | while IFS= read -r file_dir || [ -n "$file_dir" ]; do
    list_spell_files_in_dir "$file_dir"
  done | sort -u
}

spell_dir_for() {
  root=${1-}
  source=${2-}
  category=${3-}

  [ -n "$category" ] && safe_name "$category" || return 1
  if [ "$source" = "custom" ]; then
    [ -d "$HOME/.wizardry/spells/$category" ] && printf '%s\n' "$HOME/.wizardry/spells/$category"
    [ -d "$HOME/spells/$category" ] && printf '%s\n' "$HOME/spells/$category"
    [ -d "$WIZARDRY_DIR_FALLBACK/spells/$category" ] && printf '%s\n' "$WIZARDRY_DIR_FALLBACK/spells/$category"
    return
  fi
  [ -d "$root/spells/$category" ] && printf '%s\n' "$root/spells/$category"
  [ "$WIZARDRY_APPS_ROOT_FALLBACK" != "$root" ] && [ -d "$WIZARDRY_APPS_ROOT_FALLBACK/spells/$category" ] && printf '%s\n' "$WIZARDRY_APPS_ROOT_FALLBACK/spells/$category"
  [ -d "$WIZARDRY_DIR_FALLBACK/spells/$category" ] && printf '%s\n' "$WIZARDRY_DIR_FALLBACK/spells/$category"
}

cmd_run_spell() {
  ref=${1-}
  spell=${2-}
  root=$(require_root "${3-}")

  [ -n "$ref" ] && [ -n "$spell" ] || {
    printf '%s\n' "wizardry-desktop-backend: run-spell requires spell reference and name" >&2
    exit 2
  }

  parse_spell_ref "$ref" || {
    printf '%s\n' "wizardry-desktop-backend: invalid spell reference: $ref" >&2
    exit 2
  }
  source=${ref%%:*}
  category=${ref#*:}
  safe_name "$spell" || {
    printf '%s\n' "wizardry-desktop-backend: invalid spell name: $spell" >&2
    exit 2
  }

  status=127
  app_label=$(normalize_watch_actor "${WIZARDRY_DESKTOP_APP-}") || true
  app_label=${app_label-}
  if [ -z "$app_label" ]; then
    app_label=$(normalize_watch_actor "${WIZARDRY_APP_NAME-}") || true
    app_label=${app_label-}
  fi
  if [ -z "$app_label" ]; then
    app_label=$(watch_actor_for_source "$source")
  fi

  while IFS= read -r file || [ -n "$file" ]; do
    [ -f "$file" ] || continue
    spell_base=$(basename "$file")
    if [ "$spell_base" != "$spell" ] && [ "$spell_base" != "$spell.sh" ]; then
      continue
    fi
    file_app_label=$(watch_app_for_spell_file "$file")
    if [ -n "$file_app_label" ]; then
      app_label=$file_app_label
    fi
    output=$(sh "$file" 2>&1)
    status=$?
    if [ "$status" -eq 0 ]; then
      printf '%s\n' "$output"
      break
    fi
    printf '%s\n' "$output"
  done <<EOF
$(spell_dir_for "$root" "$source" "$category" | while IFS= read -r file_dir || [ -n "$file_dir" ]; do
  [ -f "$file_dir/$spell" ] && printf '%s\n' "$file_dir/$spell"
  [ -f "$file_dir/$spell.sh" ] && printf '%s\n' "$file_dir/$spell.sh"
done)
EOF

  if [ "$status" -ne 0 ]; then
    if [ -z "$app_label" ]; then
      app_label=$(watch_actor_for_source "$source")
    fi
    [ -n "$app_label" ] || app_label='wizardry-core'
    record_watch "cast" "$source/$category/$spell" "$app_label" "failed:$status"
    printf '%s\n' "wizardry-desktop-backend: spell not found: $source/$category/$spell" >&2
    exit 2
  fi
  if [ -z "$app_label" ]; then
    app_label=$(normalize_watch_actor "$source")
  fi
  [ -n "$app_label" ] || app_label='wizardry-core'
  record_watch "cast" "$source/$category/$spell" "$app_label" "ok"
}

cmd_spell_help() {
  ref=${1-}
  spell=${2-}
  root=$(require_root "${3-}")

  [ -n "$ref" ] && [ -n "$spell" ] || {
    printf '%s\n' "wizardry-desktop-backend: spell-help requires spell reference and name" >&2
    exit 2
  }

  parse_spell_ref "$ref" || {
    printf '%s\n' "wizardry-desktop-backend: invalid spell reference: $ref" >&2
    exit 2
  }
  source=${ref%%:*}
  category=${ref#*:}
  safe_name "$spell" || {
    printf '%s\n' "wizardry-desktop-backend: invalid spell name: $spell" >&2
    exit 2
  }

  while IFS= read -r file || [ -n "$file" ]; do
    [ -f "$file" ] || continue
    if [ -x "$file" ]; then
      sh "$file" --help 2>&1
      return
    fi
    head -n 30 "$file"
    return
  done <<EOF
$(spell_dir_for "$root" "$source" "$category" | while IFS= read -r file_dir || [ -n "$file_dir" ]; do
  [ -f "$file_dir/$spell" ] && printf '%s\n' "$file_dir/$spell"
  [ -f "$file_dir/$spell.sh" ] && printf '%s\n' "$file_dir/$spell.sh"
done)
EOF

  printf '%s\n' "wizardry-desktop-backend: spell not found: $source/$category/$spell" >&2
  exit 2
}

filter_memorized_rows() {
  tab_char=$(printf '\t')
  awk -F "$tab_char" 'NF == 2 { gsub(/\r/, " "); print }'
}

cmd_list_memorized_spells() {
  spellbook_dir="${XDG_DATA_HOME:-$HOME/.local/share}/wizardry/spellbook"
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  tab_char=$(printf '\t')
  if [ -x "$HOME/.wizardry/spells/menu/cast" ]; then
    sh "$HOME/.wizardry/spells/menu/cast" --list 2>/dev/null | filter_memorized_rows
    return
  fi
  if hascmd cast; then
    cast --list 2>/dev/null | filter_memorized_rows
    return
  fi
  if [ -d "$spellbook_dir" ]; then
    for f in "$spellbook_dir"/*; do
      [ -f "$f" ] || continue
      file_base=$(basename "$f")
      case "$file_base" in
        .* ) continue ;;
      esac
      safe_name "$file_base" || continue
      cmd=$(cat "$f" 2>/dev/null || printf '')
      case "$cmd" in
        *"$nl_char"*|*"$cr_char"*|*"$tab_char"*) continue ;;
      esac
      [ -n "$cmd" ] && printf '%s\t%s\n' "$file_base" "$cmd"
    done
  fi
}

memorized_spellbook_dir() {
  if hascmd cast; then
    spellbook_dir=$(cast --dir 2>/dev/null || printf '')
    if [ -n "$spellbook_dir" ]; then
      printf '%s\n' "$spellbook_dir"
      return 0
    fi
  fi
  if [ -x "$HOME/.wizardry/spells/menu/cast" ]; then
    spellbook_dir=$(sh "$HOME/.wizardry/spells/menu/cast" --dir 2>/dev/null || printf '')
    if [ -n "$spellbook_dir" ]; then
      printf '%s\n' "$spellbook_dir"
      return 0
    fi
  fi
  printf '%s\n' "${SPELLBOOK_DIR:-"${HOME:-.}/.spellbook"}"
}

memorized_commands_file() {
  spellbook_dir=$(memorized_spellbook_dir)
  printf '%s\n' "$spellbook_dir/.memorized"
}

cmd_memorize_spell() {
  spell_name=${1-}
  command_value=${2-}

  [ -n "$spell_name" ] || {
    printf '%s\n' "wizardry-desktop-backend: memorize-spell requires SPELL_NAME" >&2
    exit 2
  }
  safe_name "$spell_name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid spell name: $spell_name" >&2
    exit 2
  }
  if [ -z "$command_value" ]; then
    command_value=$spell_name
  fi
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  tab_char=$(printf '\t')
  case "$command_value" in
    *"$nl_char"*|*"$cr_char"*|*"$tab_char"*)
      printf '%s\n' "wizardry-desktop-backend: spell command must be one line without tabs" >&2
      exit 2
      ;;
    *)
      :
      ;;
  esac

  if [ "$command_value" = "$spell_name" ]; then
    if hascmd memorize; then
      memorize "$spell_name"
      printf '%s\t%s\n' "$spell_name" "$command_value"
      record_watch "app" "cast:memorize:$spell_name" "wizardry-core" "ok"
      return 0
    fi
    if [ -x "$HOME/.wizardry/spells/cantrips/memorize" ]; then
      sh "$HOME/.wizardry/spells/cantrips/memorize" "$spell_name"
      printf '%s\t%s\n' "$spell_name" "$command_value"
      record_watch "app" "cast:memorize:$spell_name" "wizardry-core" "ok"
      return 0
    fi
  fi

  memorized_file=$(memorized_commands_file)
  memorized_dir=${memorized_file%/*}
  if [ "$memorized_dir" != "$memorized_file" ]; then
    mkdir -p "$memorized_dir"
  fi
  [ -f "$memorized_file" ] || : >"$memorized_file"

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-memorized.XXXXXX")
  while IFS= read -r line || [ -n "$line" ]; do
    current_name=$line
    case "$line" in
      *"$tab_char"*)
        current_name=${line%%"$tab_char"*}
        ;;
      *)
        ;;
    esac
    if [ -z "$current_name" ] || [ "$current_name" = "$spell_name" ]; then
      continue
    fi
    printf '%s\n' "$line" >>"$tmp_file"
  done <"$memorized_file"

  {
    printf '%s\t%s\n' "$spell_name" "$command_value"
    cat "$tmp_file"
  } >"$memorized_file"
  rm -f "$tmp_file"

  printf '%s\t%s\n' "$spell_name" "$command_value"
  record_watch "app" "cast:memorize:$spell_name" "wizardry-core" "ok"
}

parse_synonym_kv_file() {
  file=${1-}
  scope=${2-}
  [ -f "$file" ] || return 0
  tab_char=$(printf '\t')
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | sed 's/\r//g')
    case "$line" in
      ''|'#'*) continue ;;
      *=*)
        word=$(printf '%s' "${line%%=*}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        target=$(printf '%s' "${line#*=}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -n "$word" ] || continue
        [ -n "$target" ] || continue
        safe_name "$word" || continue
        case "$target" in
          *"$tab_char"*|*"|"*) continue ;;
        esac
        printf '%s|%s|%s\n' "$word" "$target" "$scope"
        ;;
      *)
        continue
        ;;
    esac
  done <"$file"
}

cmd_list_synonyms() {
  spell_home=${SPELLBOOK_DIR:-"${HOME:-.}/.spellbook"}
  custom_file="$spell_home/.synonyms"
  default_file="$spell_home/.default-synonyms"

  custom_tmp=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-synonyms-custom.XXXXXX")
  default_tmp=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-synonyms-default.XXXXXX")

  parse_synonym_kv_file "$custom_file" "custom" >"$custom_tmp"
  parse_synonym_kv_file "$default_file" "default" >"$default_tmp"

  awk -F'|' '
    NR==FNR {
      if ($1 != "") {
        custom[$1] = 1
        print
      }
      next
    }
    {
      if ($1 != "" && !custom[$1]) {
        print
      }
    }
  ' "$custom_tmp" "$default_tmp" | sort -t '|' -k1,1

  rm -f "$custom_tmp" "$default_tmp"
}

spellbook_home_dir() {
  printf '%s\n' "${SPELLBOOK_DIR:-"${HOME:-.}/.spellbook"}"
}

spellbook_custom_synonyms_file() {
  spell_home=$(spellbook_home_dir)
  printf '%s\n' "$spell_home/.synonyms"
}

cmd_add_synonym() {
  alias_name=${1-}
  target=${2-}

  [ -n "$alias_name" ] && [ -n "$target" ] || {
    printf '%s\n' "wizardry-desktop-backend: add-synonym requires ALIAS TARGET" >&2
    exit 2
  }
  safe_name "$alias_name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid synonym alias: $alias_name" >&2
    exit 2
  }
  nl_char=$(printf '\nX')
  nl_char=${nl_char%X}
  cr_char=$(printf '\r')
  tab_char=$(printf '\t')
  case "$target" in
    *"$nl_char"*|*"$cr_char"*|*"$tab_char"*|*"|"*)
      printf '%s\n' "wizardry-desktop-backend: synonym target must be one line without tabs or pipes" >&2
      exit 2
      ;;
    *)
      ;;
  esac

  custom_file=$(spellbook_custom_synonyms_file)
  spell_home=${custom_file%/*}
  mkdir -p "$spell_home"
  [ -f "$custom_file" ] || : >"$custom_file"

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-synonyms-write.XXXXXX")
  awk -v key="$alias_name" -v value="$target" '
    BEGIN {
      replaced = 0
    }
    {
      line = $0
      gsub(/\r/, "", line)
      if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
        print line
        next
      }
      split(line, parts, "=")
      existing = parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", existing)
      if (existing == key) {
        if (replaced == 0) {
          print key "=" value
          replaced = 1
        }
        next
      }
      print line
    }
    END {
      if (replaced == 0) {
        print key "=" value
      }
    }
  ' "$custom_file" >"$tmp_file"

  mv "$tmp_file" "$custom_file"
  printf '%s|%s\n' "$alias_name" "$target"
  record_watch "app" "spellbook:add-synonym:$alias_name" "wizardry-core" "ok"
}

cmd_remove_synonym() {
  alias_name=${1-}
  [ -n "$alias_name" ] || {
    printf '%s\n' "wizardry-desktop-backend: remove-synonym requires ALIAS" >&2
    exit 2
  }
  safe_name "$alias_name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid synonym alias: $alias_name" >&2
    exit 2
  }

  custom_file=$(spellbook_custom_synonyms_file)
  [ -f "$custom_file" ] || {
    printf '%s\n' "$alias_name"
    record_watch "app" "spellbook:remove-synonym:$alias_name" "wizardry-core" "ok"
    return
  }

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-synonyms-write.XXXXXX")
  awk -v key="$alias_name" '
    {
      line = $0
      gsub(/\r/, "", line)
      if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
        print line
        next
      }
      split(line, parts, "=")
      existing = parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", existing)
      if (existing == key) {
        next
      }
      print line
    }
  ' "$custom_file" >"$tmp_file"

  mv "$tmp_file" "$custom_file"
  printf '%s\n' "$alias_name"
  record_watch "app" "spellbook:remove-synonym:$alias_name" "wizardry-core" "ok"
}

menu_script_dirs() {
  root=${1-}
  for dir in \
    "$root/spells/menu" \
    "$WIZARDRY_DIR_FALLBACK/spells/menu" \
    "$WIZARDRY_APPS_ROOT_FALLBACK/spells/menu" \
    "$HOME/.wizardry/spells/menu" \
    "$HOME/spells/menu"
  do
    [ -d "$dir" ] || continue
    printf '%s\n' "$dir"
  done | awk '!seen[$0]++'
}

resolve_menu_script() {
  root=${1-}
  name=${2-}
  safe_name "$name" || return 1
  menu_script_dirs "$root" | while IFS= read -r dir || [ -n "$dir" ]; do
    [ -n "$dir" ] || continue
    file="$dir/$name"
    if [ -f "$file" ] && [ ! -d "$file" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done
  return 1
}

menu_is_sourced_only() {
  file=${1-}
  [ -f "$file" ] || return 1
  if grep -qi 'must be sourced' "$file" 2>/dev/null; then
    return 0
  fi
  return 1
}

menu_argument_mode_from_usage() {
  file=${1-}
  [ -f "$file" ] || {
    printf '%s\n' "none"
    return 0
  }
  if awk '
    /^Usage:/ {
      line=$0
      if (line ~ /\[[^]]*<[A-Za-z0-9_ .:\/-]+>[^]]*\]/ || line ~ /\[[A-Za-z0-9_ .:\/|-]+\]/) {
        opt=1
      }
      if (line ~ /<[A-Za-z0-9_ .:\/-]+>/ && line !~ /\[[^]]*<[A-Za-z0-9_ .:\/-]+>[^]]*\]/) {
        req=1
      }
    }
    END {
      if (req == 1) print "required";
      else if (opt == 1) print "optional";
      else print "none";
    }' "$file" | head -n 1 | grep -E '^(required|optional)$' >/dev/null 2>&1; then
    awk '
      /^Usage:/ {
        line=$0
        if (line ~ /\[[^]]*<[A-Za-z0-9_ .:\/-]+>[^]]*\]/ || line ~ /\[[A-Za-z0-9_ .:\/|-]+\]/) {
          opt=1
        }
        if (line ~ /<[A-Za-z0-9_ .:\/-]+>/ && line !~ /\[[^]]*<[A-Za-z0-9_ .:\/-]+>[^]]*\]/) {
          req=1
        }
      }
      END {
        if (req == 1) print "required";
        else if (opt == 1) print "optional";
        else print "none";
      }' "$file" | head -n 1
    return 0
  fi
  printf '%s\n' "none"
}

menu_argument_spec() {
  name=${1-}
  file=${2-}

  case "$name" in
    spell-menu)
      printf '%s|%s|%s|%s|%s\n' \
        "required" \
        "Spell name" \
        "Spell name to inspect in spell-menu (for example: status)." \
        "status" \
        ""
      return 0
      ;;
    synonym-menu)
      printf '%s|%s|%s|%s|%s\n' \
        "required" \
        "Synonym alias" \
        "Existing synonym alias to inspect or modify." \
        "lsall" \
        ""
      return 0
      ;;
    priority-menu)
      printf '%s|%s|%s|%s|%s\n' \
        "required" \
        "Path" \
        "File or folder path that already has a priority marker." \
        "~/git/wizardry-apps" \
        ""
      return 0
      ;;
    spellbook)
      printf '%s|%s|%s|%s|%s\n' \
        "optional" \
        "Path or --list" \
        "Optional path to open in spellbook, or --list to print entries." \
        "--list" \
        "--list"
      return 0
      ;;
    thesaurus)
      printf '%s|%s|%s|%s|%s\n' \
        "optional" \
        "--list" \
        "Optional --list flag to print synonyms without opening interactive mode." \
        "--list" \
        "--list"
      return 0
      ;;
    priorities)
      printf '%s|%s|%s|%s|%s\n' \
        "optional" \
        "-v" \
        "Optional verbose flag." \
        "-v" \
        "-v"
      return 0
      ;;
    *)
      ;;
  esac

  mode=$(menu_argument_mode_from_usage "$file")
  if [ "$mode" = "required" ]; then
    printf '%s|%s|%s|%s|%s\n' \
      "required" \
      "Argument" \
      "Required menu argument." \
      "" \
      ""
    return 0
  fi
  if [ "$mode" = "optional" ]; then
    printf '%s|%s|%s|%s|%s\n' \
      "optional" \
      "Argument" \
      "Optional menu argument." \
      "" \
      ""
    return 0
  fi

  printf '%s|%s|%s|%s|%s\n' \
    "none" \
    "" \
    "" \
    "" \
    ""
}

menu_invocation_text() {
  name=${1-}
  sourced_only=${2-0}
  arg_mode=${3-none}
  cmd="$name"
  if [ "$sourced_only" = "1" ]; then
    cmd=". $name"
  fi
  if [ "$arg_mode" = "required" ]; then
    cmd="$cmd <arg>"
  elif [ "$arg_mode" = "optional" ]; then
    cmd="$cmd [arg]"
  fi
  printf '%s\n' "$cmd"
}

menu_rank() {
  case "${1-}" in
    main-menu) printf '001' ;;
    cast) printf '002' ;;
    mud) printf '003' ;;
    spellbook) printf '004' ;;
    install-menu) printf '005' ;;
    system-menu) printf '006' ;;
    *) printf '100' ;;
  esac
}

menu_top_level_flag() {
  case "${1-}" in
    main-menu|cast|mud|spellbook|install-menu|system-menu)
      printf '1\n'
      ;;
    *)
      printf '0\n'
      ;;
  esac
}

cmd_list_menu_spells() {
  root=$(require_root "${1-}")
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-menus.XXXXXX")
  seen_names=''

  menu_script_dirs "$root" | while IFS= read -r dir || [ -n "$dir" ]; do
    [ -d "$dir" ] || continue
    for file in "$dir"/*; do
      [ -f "$file" ] || continue
      [ -d "$file" ] && continue
      name=$(basename "$file")
      case "$name" in
        ''|.*|menu)
          continue
          ;;
      esac
      safe_name "$name" || continue
      case " $seen_names " in
        *" $name "*)
          continue
          ;;
      esac
      seen_names="$seen_names $name "
      sourced_only=0
      if menu_is_sourced_only "$file"; then
        sourced_only=1
      fi
      arg_spec=$(menu_argument_spec "$name" "$file")
      arg_mode=$(printf '%s\n' "$arg_spec" | cut -d'|' -f1)
      arg_label=$(printf '%s\n' "$arg_spec" | cut -d'|' -f2)
      arg_help=$(printf '%s\n' "$arg_spec" | cut -d'|' -f3)
      arg_example=$(printf '%s\n' "$arg_spec" | cut -d'|' -f4)
      arg_values=$(printf '%s\n' "$arg_spec" | cut -d'|' -f5)
      invocation=$(menu_invocation_text "$name" "$sourced_only" "$arg_mode")
      top_level=$(menu_top_level_flag "$name")
      rank=$(menu_rank "$name")
      printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$rank" \
        "$name" \
        "$sourced_only" \
        "$arg_mode" \
        "$top_level" \
        "$invocation" \
        "$arg_label" \
        "$arg_help" \
        "$arg_example" \
        "$arg_values"
    done
  done >"$tmp_file"

  sort -t'|' -k1,1 -k2,2 "$tmp_file" | while IFS='|' read -r rank name sourced_only arg_mode top_level invocation arg_label arg_help arg_example arg_values || [ -n "$name" ]; do
    [ -n "$name" ] || continue
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$name" \
      "$sourced_only" \
      "$arg_mode" \
      "$top_level" \
      "$invocation" \
      "$arg_label" \
      "$arg_help" \
      "$arg_example" \
      "$arg_values"
  done
  rm -f "$tmp_file"
}

main_menu_mud_enabled() {
  spell_home=${SPELLBOOK_DIR:-"${HOME:-.}/.spellbook"}
  mud_config_file="$spell_home/.mud"
  mud_enabled=1

  if [ -f "$mud_config_file" ]; then
    value=''
    if hascmd config-get; then
      value=$(config-get "$mud_config_file" "mud-enabled" 2>/dev/null || printf '')
    fi
    if [ -z "$value" ]; then
      value=$(awk -F'=' '
        {
          key=$1
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
          if (key == "mud-enabled") {
            val=$2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
            print val
            exit
          }
        }
      ' "$mud_config_file" 2>/dev/null | head -n 1)
    fi
    if [ -n "$value" ]; then
      if [ "$value" = "1" ]; then
        mud_enabled=1
      else
        mud_enabled=0
      fi
    fi
  fi

  printf '%s\n' "$mud_enabled"
}

cmd_list_main_menu_entries() {
  mud_enabled=$(main_menu_mud_enabled)
  printf '%s\n' "cast|Cast|cast"
  if [ "$mud_enabled" = "1" ]; then
    printf '%s\n' "mud|MUD|mud"
  fi
  printf '%s\n' "spellbook|Spellbook|spellbook"
  printf '%s\n' "arcana|Arcana|install-menu"
  printf '%s\n' "system|Computer|system-menu"
}

is_nixos_host() {
  if hascmd detect-distro; then
    distro=$(detect-distro 2>/dev/null || printf '')
    if [ "$distro" = "nixos" ]; then
      return 0
    fi
  fi
  if [ -r /etc/os-release ] && grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    return 0
  fi
  return 1
}

print_system_menu_action() {
  id=${1-}
  label=${2-}
  mode=${3-}
  description=${4-}
  danger=${5-0}
  available=${6-1}
  reason=${7-}
  printf '%s|%s|%s|%s|%s|%s|%s\n' \
    "$id" \
    "$label" \
    "$mode" \
    "$description" \
    "$danger" \
    "$available" \
    "$reason"
}

menu_action_available() {
  root=${1-}
  menu_name=${2-}
  if [ -n "$(resolve_menu_script "$root" "$menu_name" || true)" ]; then
    return 0
  fi
  return 1
}

cmd_list_system_menu_actions() {
  root=$(require_root "${1-}")
  uninstall_script="$root/.uninstall"
  if [ ! -f "$uninstall_script" ]; then
    uninstall_script="$WIZARDRY_DIR_FALLBACK/.uninstall"
  fi

  if menu_action_available "$root" "shutdown-menu"; then
    print_system_menu_action "system:restart-menu" "Restart..." "menu" "Open the shutdown/restart power menu in Terminal." "0" "1" ""
  else
    print_system_menu_action "system:restart-menu" "Restart..." "menu" "Open the shutdown/restart power menu in Terminal." "0" "0" "shutdown-menu is unavailable."
  fi

  if hascmd update-all || [ -x "$WIZARDRY_DIR_FALLBACK/spells/system/update-all" ]; then
    print_system_menu_action "system:update-all" "Update all software" "spell" "Run update-all with verbose output." "0" "1" ""
  else
    print_system_menu_action "system:update-all" "Update all software" "spell" "Run update-all with verbose output." "0" "0" "update-all is unavailable."
  fi

  if hascmd update-wizardry || [ -x "$WIZARDRY_DIR_FALLBACK/spells/.wizardry/update-wizardry" ]; then
    print_system_menu_action "system:update-wizardry" "Update wizardry" "spell" "Update wizardry core scripts and metadata." "0" "1" ""
  else
    print_system_menu_action "system:update-wizardry" "Update wizardry" "spell" "Update wizardry core scripts and metadata." "0" "0" "update-wizardry is unavailable."
  fi

  if menu_action_available "$root" "services-menu"; then
    print_system_menu_action "system:services-menu" "Manage services" "menu" "Open services-menu in Terminal." "0" "1" ""
  else
    print_system_menu_action "system:services-menu" "Manage services" "menu" "Open services-menu in Terminal." "0" "0" "services-menu is unavailable."
  fi

  if is_nixos_host; then
    if hascmd nixos-rebuild; then
      print_system_menu_action "system:nixos-rebuild" "Rebuild NixOS" "command" "Run sudo nixos-rebuild switch in Terminal." "0" "1" ""
    else
      print_system_menu_action "system:nixos-rebuild" "Rebuild NixOS" "command" "Run sudo nixos-rebuild switch in Terminal." "0" "0" "nixos-rebuild is unavailable."
    fi
  fi

  if hascmd verify-posix || [ -x "$WIZARDRY_DIR_FALLBACK/spells/.wizardry/verify-posix" ]; then
    print_system_menu_action "system:verify-posix" "Verify POSIX spells" "spell" "Run POSIX compatibility verification checks." "0" "1" ""
  else
    print_system_menu_action "system:verify-posix" "Verify POSIX spells" "spell" "Run POSIX compatibility verification checks." "0" "0" "verify-posix is unavailable."
  fi

  if hascmd test-magic || [ -x "$WIZARDRY_DIR_FALLBACK/spells/.wizardry/test-magic" ]; then
    print_system_menu_action "system:test-magic" "Test all wizardry spells" "spell" "Run full wizardry spell test suite." "0" "1" ""
  else
    print_system_menu_action "system:test-magic" "Test all wizardry spells" "spell" "Run full wizardry spell test suite." "0" "0" "test-magic is unavailable."
  fi

  if hascmd profile-tests || [ -x "$WIZARDRY_DIR_FALLBACK/spells/.wizardry/profile-tests" ]; then
    print_system_menu_action "system:profile-tests" "Profile test performance" "spell" "Profile wizardry test runtime and hotspots." "0" "1" ""
  else
    print_system_menu_action "system:profile-tests" "Profile test performance" "spell" "Profile wizardry test runtime and hotspots." "0" "0" "profile-tests is unavailable."
  fi

  if [ -f "$uninstall_script" ]; then
    print_system_menu_action "system:uninstall-wizardry" "Uninstall wizardry" "script" "Run wizardry uninstall script." "0" "1" ""
  else
    print_system_menu_action "system:uninstall-wizardry" "Uninstall wizardry" "script" "Run wizardry uninstall script." "0" "0" ".uninstall script is unavailable."
  fi
}

mud_spell_dirs() {
  root=${1-}
  for dir in \
    "$root/spells/mud" \
    "$WIZARDRY_DIR_FALLBACK/spells/mud" \
    "$WIZARDRY_APPS_ROOT_FALLBACK/spells/mud" \
    "$HOME/.wizardry/spells/mud" \
    "$HOME/spells/mud"
  do
    [ -d "$dir" ] || continue
    printf '%s\n' "$dir"
  done | awk '!seen[$0]++'
}

path_in_mud_spell_dirs() {
  root=${1-}
  candidate=${2-}
  [ -n "$candidate" ] || return 1
  dirs=$(mud_spell_dirs "$root")
  while IFS= read -r dir || [ -n "$dir" ]; do
    [ -n "$dir" ] || continue
    case "$candidate" in
      "$dir"|"$dir"/*)
        return 0
        ;;
      *)
        ;;
    esac
  done <<EOF
$dirs
EOF
  return 1
}

resolve_mud_spell() {
  root=${1-}
  spell_name=${2-}
  safe_name "$spell_name" || return 1

  dirs=$(mud_spell_dirs "$root")
  while IFS= read -r dir || [ -n "$dir" ]; do
    [ -n "$dir" ] || continue
    for candidate in "$dir/$spell_name" "$dir/$spell_name.sh"; do
      if [ -f "$candidate" ] && [ ! -d "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  done <<EOF
$dirs
EOF

  if hascmd "$spell_name"; then
    resolved=$(command -v "$spell_name" 2>/dev/null | awk '{print $1}')
    if [ -n "$resolved" ] && path_in_mud_spell_dirs "$root" "$resolved"; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi
  return 1
}

mud_action_menu_name() {
  action_id=${1-}
  case "$action_id" in
    mud:menu) printf '%s\n' "mud" ;;
    mud:settings-menu) printf '%s\n' "mud-settings" ;;
    mud:admin-menu) printf '%s\n' "mud-admin-menu" ;;
    mud:install-menu) printf '%s\n' "mud-menu" ;;
    *) printf '\n' ;;
  esac
}

mud_action_spell_name() {
  action_id=${1-}
  case "$action_id" in
    mud:look) printf '%s\n' "look" ;;
    mud:listen) printf '%s\n' "listen" ;;
    mud:stats) printf '%s\n' "stats" ;;
    mud:say) printf '%s\n' "say" ;;
    mud:think) printf '%s\n' "think" ;;
    mud:magic-missile) printf '%s\n' "magic-missile" ;;
    mud:shocking-grasp) printf '%s\n' "shocking-grasp" ;;
    mud:heal) printf '%s\n' "heal" ;;
    mud:lesser-heal) printf '%s\n' "lesser-heal" ;;
    mud:greater-heal) printf '%s\n' "greater-heal" ;;
    mud:resurrect) printf '%s\n' "resurrect" ;;
    mud:demo-multiplayer) printf '%s\n' "demo-multiplayer" ;;
    *) printf '\n' ;;
  esac
}

mud_action_spec() {
  action_id=${1-}
  case "$action_id" in
    mud:menu)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Open MUD Menu" \
        "menu" \
        "Open the interactive MUD menu in Terminal." \
        "none" \
        "" \
        ""
      ;;
    mud:look)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Look Around" \
        "spell" \
        "Inspect the current room or a target path." \
        "optional" \
        "Path" \
        "."
      ;;
    mud:listen)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Listen" \
        "command" \
        "Start live room monitoring in Terminal (sourced listener)." \
        "optional" \
        "Room Path" \
        "."
      ;;
    mud:stats)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "View Stats" \
        "spell" \
        "Show avatar or target stats (HP/MP/XP)." \
        "optional" \
        "Target" \
        "."
      ;;
    mud:say)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Say" \
        "spell" \
        "Speak in the current room log so other players can hear you." \
        "required" \
        "Message" \
        "Hello, adventurers."
      ;;
    mud:think)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Think" \
        "spell" \
        "Write a private thought to your avatar log." \
        "required" \
        "Thought" \
        "I should inspect this room."
      ;;
    mud:magic-missile)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Magic Missile" \
        "spell" \
        "Cast a ranged attack at a target or random object in the room." \
        "optional" \
        "Target" \
        "goblin"
      ;;
    mud:shocking-grasp)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Shocking Grasp" \
        "spell" \
        "Charge your avatar so your next touch deals damage." \
        "none" \
        "" \
        ""
      ;;
    mud:heal)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Heal" \
        "spell" \
        "Cast the best available healing spell for you or a target." \
        "optional" \
        "Target" \
        "other-avatar"
      ;;
    mud:lesser-heal)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Lesser Heal" \
        "spell" \
        "Restore a small amount of HP (10)." \
        "optional" \
        "Target" \
        "other-avatar"
      ;;
    mud:greater-heal)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Greater Heal" \
        "spell" \
        "Restore a large amount of HP (100)." \
        "optional" \
        "Target" \
        "other-avatar"
      ;;
    mud:resurrect)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Resurrect" \
        "spell" \
        "Resurrect your avatar when dead, if location rules permit." \
        "none" \
        "" \
        ""
      ;;
    mud:demo-multiplayer)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "Demo Multiplayer" \
        "spell" \
        "Run the built-in multiplayer MUD demonstration script." \
        "none" \
        "" \
        ""
      ;;
    mud:settings-menu)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "MUD Settings" \
        "menu" \
        "Open MUD settings menu in Terminal." \
        "none" \
        "" \
        ""
      ;;
    mud:admin-menu)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "MUD Admin" \
        "menu" \
        "Open MUD admin hosting menu in Terminal." \
        "none" \
        "" \
        ""
      ;;
    mud:install-menu)
      printf '%s|%s|%s|%s|%s|%s\n' \
        "MUD Install Menu" \
        "menu" \
        "Open MUD install/toggle menu in Terminal." \
        "none" \
        "" \
        ""
      ;;
    *)
      return 1
      ;;
  esac
}

print_mud_action() {
  action_id=${1-}
  label=${2-}
  mode=${3-}
  description=${4-}
  arg_mode=${5-}
  arg_label=${6-}
  arg_example=${7-}
  available=${8-1}
  reason=${9-}
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$action_id" \
    "$label" \
    "$mode" \
    "$description" \
    "$arg_mode" \
    "$arg_label" \
    "$arg_example" \
    "$available" \
    "$reason"
}

mud_action_available() {
  root=${1-}
  action_id=${2-}
  mode=${3-}
  reason=''
  available=0

  if [ "$mode" = "menu" ]; then
    menu_name=$(mud_action_menu_name "$action_id")
    if [ -n "$menu_name" ] && menu_action_available "$root" "$menu_name"; then
      available=1
    else
      reason="$menu_name menu is unavailable."
    fi
  else
    spell_name=$(mud_action_spell_name "$action_id")
    if [ -n "$spell_name" ] && [ -n "$(resolve_mud_spell "$root" "$spell_name" || true)" ]; then
      available=1
    else
      reason="$spell_name spell is unavailable."
    fi
  fi

  printf '%s|%s\n' "$available" "$reason"
}

cmd_list_mud_actions() {
  root=$(require_root "${1-}")
  for action_id in \
    mud:menu \
    mud:look \
    mud:listen \
    mud:stats \
    mud:say \
    mud:think \
    mud:magic-missile \
    mud:shocking-grasp \
    mud:heal \
    mud:lesser-heal \
    mud:greater-heal \
    mud:resurrect \
    mud:demo-multiplayer \
    mud:settings-menu \
    mud:admin-menu \
    mud:install-menu
  do
    spec=$(mud_action_spec "$action_id" || true)
    [ -n "$spec" ] || continue
    label=$(printf '%s\n' "$spec" | cut -d'|' -f1)
    mode=$(printf '%s\n' "$spec" | cut -d'|' -f2)
    description=$(printf '%s\n' "$spec" | cut -d'|' -f3)
    arg_mode=$(printf '%s\n' "$spec" | cut -d'|' -f4)
    arg_label=$(printf '%s\n' "$spec" | cut -d'|' -f5)
    arg_example=$(printf '%s\n' "$spec" | cut -d'|' -f6)
    availability=$(mud_action_available "$root" "$action_id" "$mode")
    available=$(printf '%s\n' "$availability" | cut -d'|' -f1)
    reason=$(printf '%s\n' "$availability" | cut -d'|' -f2-)
    print_mud_action "$action_id" "$label" "$mode" "$description" "$arg_mode" "$arg_label" "$arg_example" "$available" "$reason"
  done
}

run_mud_spell_action() {
  root=${1-}
  action_id=${2-}
  spell_name=${3-}
  arg_mode=${4-}
  action_arg=${5-}

  executable=$(resolve_mud_spell "$root" "$spell_name" || true)
  if [ -z "$executable" ]; then
    printf '%s\n' "wizardry-desktop-backend: spell unavailable for $action_id: $spell_name" >&2
    record_watch "app" "$action_id" "wizardry-core" "failed:missing"
    exit 2
  fi

  if [ "$arg_mode" = "required" ] && [ -z "$action_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: action '$action_id' requires an argument" >&2
    exit 2
  fi
  if [ "$arg_mode" = "none" ] && [ -n "$action_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: action '$action_id' does not take an argument" >&2
    exit 2
  fi

  if [ -f "$executable" ] && [ ! -d "$executable" ]; then
    if [ -n "$action_arg" ]; then
      run_system_command "$action_id" "sh" "$executable" "$action_arg"
    else
      run_system_command "$action_id" "sh" "$executable"
    fi
    return
  fi

  if [ -n "$action_arg" ]; then
    run_system_command "$action_id" "$executable" "$action_arg"
  else
    run_system_command "$action_id" "$executable"
  fi
}

run_mud_sourced_spell_action() {
  root=${1-}
  action_id=${2-}
  spell_name=${3-}
  arg_mode=${4-}
  action_arg=${5-}

  executable=$(resolve_mud_spell "$root" "$spell_name" || true)
  if [ -z "$executable" ]; then
    printf '%s\n' "wizardry-desktop-backend: spell unavailable for $action_id: $spell_name" >&2
    record_watch "app" "$action_id" "wizardry-core" "failed:missing"
    exit 2
  fi

  if [ "$arg_mode" = "required" ] && [ -z "$action_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: action '$action_id' requires an argument" >&2
    exit 2
  fi
  if [ "$arg_mode" = "none" ] && [ -n "$action_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: action '$action_id' does not take an argument" >&2
    exit 2
  fi

  command_text=". $(shell_quote "$executable")"
  if [ -n "$action_arg" ]; then
    command_text="$command_text $(shell_quote "$action_arg")"
  fi
  run_terminal_command "$command_text" "$action_id" "wizardry-core"
}

cmd_run_mud_action() {
  action_id=${1-}
  action_arg=${2-}
  root=$(require_root "${3-}")

  [ -n "$action_id" ] || {
    printf '%s\n' "wizardry-desktop-backend: run-mud-action requires ACTION" >&2
    exit 2
  }

  case "$action_arg" in
    *'
'*|*''*)
      printf '%s\n' "wizardry-desktop-backend: MUD action argument must be one line" >&2
      exit 2
      ;;
    *)
      ;;
  esac

  case "$action_id" in
    mud:menu)
      cmd_open_menu_terminal "mud" "" "$root"
      ;;
    mud:settings-menu)
      cmd_open_menu_terminal "mud-settings" "" "$root"
      ;;
    mud:admin-menu)
      cmd_open_menu_terminal "mud-admin-menu" "" "$root"
      ;;
    mud:install-menu)
      cmd_open_menu_terminal "mud-menu" "" "$root"
      ;;
    mud:look)
      run_mud_spell_action "$root" "$action_id" "look" "optional" "$action_arg"
      ;;
    mud:listen)
      run_mud_sourced_spell_action "$root" "$action_id" "listen" "optional" "$action_arg"
      ;;
    mud:stats)
      run_mud_spell_action "$root" "$action_id" "stats" "optional" "$action_arg"
      ;;
    mud:say)
      run_mud_spell_action "$root" "$action_id" "say" "required" "$action_arg"
      ;;
    mud:think)
      run_mud_spell_action "$root" "$action_id" "think" "required" "$action_arg"
      ;;
    mud:magic-missile)
      run_mud_spell_action "$root" "$action_id" "magic-missile" "optional" "$action_arg"
      ;;
    mud:shocking-grasp)
      run_mud_spell_action "$root" "$action_id" "shocking-grasp" "none" "$action_arg"
      ;;
    mud:heal)
      run_mud_spell_action "$root" "$action_id" "heal" "optional" "$action_arg"
      ;;
    mud:lesser-heal)
      run_mud_spell_action "$root" "$action_id" "lesser-heal" "optional" "$action_arg"
      ;;
    mud:greater-heal)
      run_mud_spell_action "$root" "$action_id" "greater-heal" "optional" "$action_arg"
      ;;
    mud:resurrect)
      run_mud_spell_action "$root" "$action_id" "resurrect" "none" "$action_arg"
      ;;
    mud:demo-multiplayer)
      run_mud_spell_action "$root" "$action_id" "demo-multiplayer" "none" "$action_arg"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unsupported MUD action: $action_id" >&2
      exit 2
      ;;
  esac
}

cmd_menu_help() {
  name=${1-}
  root=$(require_root "${2-}")
  [ -n "$name" ] || {
    printf '%s\n' "wizardry-desktop-backend: menu-help requires MENU_NAME" >&2
    exit 2
  }
  safe_name "$name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid menu name: $name" >&2
    exit 2
  }
  script=$(resolve_menu_script "$root" "$name" || true)
  [ -n "$script" ] || {
    printf '%s\n' "wizardry-desktop-backend: menu not found: $name" >&2
    exit 2
  }
  output=$(sh "$script" --help 2>&1 || true)
  if [ -n "$output" ]; then
    printf '%s\n' "$output"
    return
  fi
  head -n 60 "$script"
}

cmd_run_menu() {
  name=${1-}
  menu_arg=${2-}
  root=$(require_root "${3-}")

  [ -n "$name" ] || {
    printf '%s\n' "wizardry-desktop-backend: run-menu requires MENU_NAME" >&2
    exit 2
  }
  safe_name "$name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid menu name: $name" >&2
    exit 2
  }

  case "$menu_arg" in
    *'
'*|*''*)
      printf '%s\n' "wizardry-desktop-backend: menu argument must be one line" >&2
      exit 2
      ;;
    *)
      ;;
  esac

  script=$(resolve_menu_script "$root" "$name" || true)
  [ -n "$script" ] || {
    printf '%s\n' "wizardry-desktop-backend: menu not found: $name" >&2
    exit 2
  }

  sourced_only=0
  arg_mode="none"
  if menu_is_sourced_only "$script"; then
    sourced_only=1
  fi
  arg_spec=$(menu_argument_spec "$name" "$script")
  arg_mode=$(printf '%s\n' "$arg_spec" | cut -d'|' -f1)

  if [ "$arg_mode" = "required" ] && [ -z "$menu_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: menu '$name' requires an argument" >&2
    exit 2
  fi
  if [ "$arg_mode" = "none" ] && [ -n "$menu_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: menu '$name' does not take an argument" >&2
    exit 2
  fi

  invocation=$(menu_invocation_text "$name" "$sourced_only" "$arg_mode")

  case "$name" in
    cast)
      status=0
      output=$(sh "$script" --list 2>&1) || status=$?
      status=${status:-0}
      printf '%s\n' "$output"
      if [ "$status" -eq 0 ]; then
        record_watch "app" "menu:$name" "wizardry-core" "ok"
        return
      fi
      record_watch "app" "menu:$name" "wizardry-core" "failed:$status"
      exit 2
      ;;
    spellbook)
      status=0
      output=$(sh "$script" --list 2>&1) || status=$?
      status=${status:-0}
      printf '%s\n' "$output"
      if [ "$status" -eq 0 ]; then
        record_watch "app" "menu:$name" "wizardry-core" "ok"
        return
      fi
      record_watch "app" "menu:$name" "wizardry-core" "failed:$status"
      exit 2
      ;;
    thesaurus)
      status=0
      output=$(sh "$script" --list 2>&1) || status=$?
      status=${status:-0}
      printf '%s\n' "$output"
      if [ "$status" -eq 0 ]; then
        record_watch "app" "menu:$name" "wizardry-core" "ok"
        return
      fi
      record_watch "app" "menu:$name" "wizardry-core" "failed:$status"
      exit 2
      ;;
  esac

  if [ "$sourced_only" -eq 1 ]; then
    printf '%s\n' "menu=$name"
    printf '%s\n' "mode=sourced-only"
    printf '%s\n' "command=$invocation"
    printf '%s\n' "Run this command in a shell to launch the interactive menu."
    record_watch "app" "menu:$name" "wizardry-core" "sourced-only"
    return
  fi

  status=0
  if [ -n "$menu_arg" ]; then
    output=$(sh "$script" "$menu_arg" 2>&1) || status=$?
  else
    output=$(sh "$script" --help 2>&1) || status=$?
  fi
  status=${status:-0}
  if [ -n "$output" ]; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "menu=$name"
    printf '%s\n' "command=$invocation"
  fi
  if [ "$status" -eq 0 ]; then
    record_watch "app" "menu:$name" "wizardry-core" "ok"
    return
  fi
  record_watch "app" "menu:$name" "wizardry-core" "failed:$status"
  exit 2
}

shell_quote() {
  value=${1-}
  quoted=$(printf '%s' "$value" | sed "s/'/'\\\\''/g")
  printf "'%s'" "$quoted"
}

cmd_open_menu_terminal() {
  name=${1-}
  menu_arg=${2-}
  root=$(require_root "${3-}")

  [ -n "$name" ] || {
    printf '%s\n' "wizardry-desktop-backend: open-menu-terminal requires MENU_NAME" >&2
    exit 2
  }
  safe_name "$name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid menu name: $name" >&2
    exit 2
  }

  case "$menu_arg" in
    *'
'*|*''*)
      printf '%s\n' "wizardry-desktop-backend: menu argument must be one line" >&2
      exit 2
      ;;
    *)
      ;;
  esac

  script=$(resolve_menu_script "$root" "$name" || true)
  [ -n "$script" ] || {
    printf '%s\n' "wizardry-desktop-backend: menu not found: $name" >&2
    exit 2
  }

  sourced_only=0
  if menu_is_sourced_only "$script"; then
    sourced_only=1
  fi

  arg_spec=$(menu_argument_spec "$name" "$script")
  arg_mode=$(printf '%s\n' "$arg_spec" | cut -d'|' -f1)
  if [ "$arg_mode" = "required" ] && [ -z "$menu_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: menu '$name' requires an argument" >&2
    exit 2
  fi
  if [ "$arg_mode" = "none" ] && [ -n "$menu_arg" ]; then
    printf '%s\n' "wizardry-desktop-backend: menu '$name' does not take an argument" >&2
    exit 2
  fi

  command_text=""
  if [ "$sourced_only" -eq 1 ]; then
    command_text=". $(shell_quote "$script")"
  else
    command_text="$(shell_quote "$script")"
  fi
  if [ -n "$menu_arg" ]; then
    command_text="$command_text $(shell_quote "$menu_arg")"
  fi
  command_output=$(sanitize_value "$command_text")

  if [ "$(platform_id)" != "darwin" ] || ! command -v osascript >/dev/null 2>&1; then
    printf 'mode=%s\n' "manual"
    printf 'command=%s\n' "$command_output"
    printf '%s\n' "Automatic terminal launch is unavailable on this platform."
    record_watch "app" "menu:terminal:$name" "wizardry-core" "manual"
    return
  fi

  terminal_line="cd $(shell_quote "$HOME"); $command_text"
  if osascript - "$terminal_line" <<'OSA' >/dev/null 2>&1
on run argv
  set cmd to item 1 of argv
  tell application "Terminal"
    activate
    do script cmd
  end tell
end run
OSA
  then
    printf 'mode=%s\n' "terminal"
    printf 'command=%s\n' "$command_output"
    printf '%s\n' "Opened Terminal and sent command."
    record_watch "app" "menu:terminal:$name" "wizardry-core" "ok"
    return
  fi

  printf 'mode=%s\n' "manual"
  printf 'command=%s\n' "$command_output"
  printf '%s\n' "Terminal automation failed; run command manually."
  record_watch "app" "menu:terminal:$name" "wizardry-core" "failed:osascript"
}

run_terminal_command() {
  command_text=${1-}
  source=${2-}
  app=${3-}
  [ -n "$source" ] || source="system:terminal"
  [ -n "$app" ] || app="wizardry-core"

  [ -n "$command_text" ] || {
    printf '%s\n' "wizardry-desktop-backend: terminal command is required" >&2
    exit 2
  }
  command_output=$(sanitize_value "$command_text")

  if [ "$(platform_id)" != "darwin" ] || ! command -v osascript >/dev/null 2>&1; then
    printf 'mode=%s\n' "manual"
    printf 'command=%s\n' "$command_output"
    printf '%s\n' "Automatic terminal launch is unavailable on this platform."
    record_watch "app" "$source" "$app" "manual"
    return 0
  fi

  terminal_line="cd $(shell_quote "$HOME"); $command_text"
  if osascript - "$terminal_line" <<'OSA' >/dev/null 2>&1
on run argv
  set cmd to item 1 of argv
  tell application "Terminal"
    activate
    do script cmd
  end tell
end run
OSA
  then
    printf 'mode=%s\n' "terminal"
    printf 'command=%s\n' "$command_output"
    printf '%s\n' "Opened Terminal and sent command."
    record_watch "app" "$source" "$app" "ok"
    return 0
  fi

  printf 'mode=%s\n' "manual"
  printf 'command=%s\n' "$command_output"
  printf '%s\n' "Terminal automation failed; run command manually."
  record_watch "app" "$source" "$app" "failed:osascript"
}

resolve_system_command() {
  name=${1-}
  [ -n "$name" ] || return 1
  if hascmd "$name"; then
    # shellcheck disable=SC2230
    command -v "$name" 2>/dev/null | awk '{print $1}'
    return 0
  fi

  root=$(require_root "")
  for file in \
    "$root/spells/.wizardry/$name" \
    "$root/spells/system/$name" \
    "$WIZARDRY_DIR_FALLBACK/spells/.wizardry/$name" \
    "$WIZARDRY_DIR_FALLBACK/spells/system/$name" \
    "$HOME/.wizardry/spells/.wizardry/$name" \
    "$HOME/.wizardry/spells/system/$name"
  do
    [ -f "$file" ] || continue
    if [ -x "$file" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done

  return 1
}

run_system_command() {
  action_name=${1-}
  executable=${2-}
  shift 2 || true

  [ -n "$action_name" ] || action_name="system:command"
  [ -n "$executable" ] || {
    printf '%s\n' "wizardry-desktop-backend: missing executable for $action_name" >&2
    exit 2
  }

  status=0
  output=$("$executable" "$@" 2>&1) || status=$?
  status=${status:-0}
  if [ -n "$output" ]; then
    printf '%s\n' "$output"
  fi
  if [ "$status" -eq 0 ]; then
    record_watch "app" "$action_name" "wizardry-core" "ok"
    return 0
  fi
  if [ -z "$output" ]; then
    printf '%s\n' "wizardry-desktop-backend: $action_name failed with status $status" >&2
  fi
  record_watch "app" "$action_name" "wizardry-core" "failed:$status"
  exit 2
}

run_named_system_command() {
  action_name=${1-}
  command_name=${2-}
  shift 2 || true
  executable=$(resolve_system_command "$command_name" || true)
  if [ -z "$executable" ]; then
    printf '%s\n' "wizardry-desktop-backend: command unavailable for $action_name: $command_name" >&2
    record_watch "app" "$action_name" "wizardry-core" "failed:missing"
    exit 2
  fi
  run_system_command "$action_name" "$executable" "$@"
}

run_system_uninstall() {
  root=$(require_root "")
  uninstall_script="$root/.uninstall"
  if [ ! -f "$uninstall_script" ]; then
    uninstall_script="$WIZARDRY_DIR_FALLBACK/.uninstall"
  fi
  if [ ! -f "$uninstall_script" ]; then
    printf '%s\n' "wizardry-desktop-backend: uninstall script not found" >&2
    record_watch "app" "system:uninstall-wizardry" "wizardry-core" "failed:missing"
    exit 2
  fi
  run_system_command "system:uninstall-wizardry" "sh" "$uninstall_script"
}

resolve_arcana_module_script() {
  install_root=${1-}
  name=${2-}
  script_suffix=${3-}
  safe_name "$name" || return 1

  for file in \
    "$install_root/$name-${script_suffix}" \
    "$install_root/$name/$name-${script_suffix}" \
    "$install_root/$name/${script_suffix}" \
    "$install_root/$name/$name/$script_suffix"; do
    [ -f "$file" ] && [ ! -d "$file" ] && printf '%s\n' "$file" && return
  done

  if [ -n "$script_suffix" ] && hascmd "${name}-${script_suffix}" 2>/dev/null; then
    # shellcheck disable=SC2230
    command -v "${name}-${script_suffix}" 2>/dev/null | awk '{print $1}'
  fi
}

arcana_label_for_name() {
  case ${1-} in
    core) printf 'core wizardry' ;;
    mud) printf 'wizardry MUD' ;;
    web-wizardry) printf 'web wizardry' ;;
    wizardry-apps) printf 'wizardry apps' ;;
    native-desktop-compilation) printf 'native desktop compilation' ;;
    ai-dev) printf 'AI dev' ;;
    yt-dlp) printf 'yt-dlp' ;;
    voice-recognition) printf 'voice recognition' ;;
    nostr) printf 'Nostr' ;;
    btcpay) printf 'BTCPay Server' ;;
    * ) printf '%s\n' "$1" ;;
  esac
}

arcana_entry_names() {
  install_root=${1-}
  if [ -n "${INSTALL_MENU_DIRS-}" ]; then
    printf '%s\n' $INSTALL_MENU_DIRS
    return
  fi

  if [ ! -d "$install_root" ]; then
    return
  fi

  preferred='core mud web-wizardry wizardry-apps native-desktop-compilation ai-dev yt-dlp voice-recognition nostr btcpay'
  for name in $preferred; do
    [ -e "$install_root/$name" ] && printf '%s\n' "$name"
  done

  for entry in "$install_root"/*; do
    [ -e "$entry" ] || continue
    entry_name=$(basename "$entry")
    case "$entry_name" in
      core|mud|web-wizardry|wizardry-apps|native-desktop-compilation|ai-dev|yt-dlp|voice-recognition|nostr|btcpay|import-arcanum|.)
        continue
        ;;
    esac
    printf '%s\n' "$entry_name"
  done
}

arcana_install_roots() {
  install_root=${1-}
  root=$(require_root "")
  seen_roots='
'
  for candidate in "$install_root" "$root/spells/.arcana" "$WIZARDRY_DIR_FALLBACK/spells/.arcana" "$WIZARDRY_APPS_ROOT_FALLBACK/spells/.arcana"; do
    [ -n "$candidate" ] || continue
    has_line_break "$candidate" && continue
    [ -d "$candidate" ] || continue
    case "$seen_roots" in
      *"
$candidate
"*) continue ;;
    esac
    seen_roots="$seen_roots$candidate
"
    printf '%s\n' "$candidate"
  done
}

arcana_status_script_for_module() {
  module_name=${1-}
  roots=${2-}
  while IFS= read -r root_dir || [ -n "$root_dir" ]; do
    [ -n "$root_dir" ] || continue
    if [ -x "$root_dir/$module_name-status" ] && [ ! -d "$root_dir/$module_name-status" ]; then
      printf '%s\n' "$root_dir/$module_name-status"
      return
    fi
    if [ -x "$root_dir/$module_name/$module_name-status" ] && [ ! -d "$root_dir/$module_name/$module_name-status" ]; then
      printf '%s\n' "$root_dir/$module_name/$module_name-status"
      return
    fi
  done <<EOF
$roots
EOF
  printf '\n'
}

run_status_capture() {
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  (
    set +e
    "$@" 2>&1
    exit 0
  )
}

best_status_summary_line() {
  output=${1-}
  summary=$(printf '%s\n' "$output" | sed '/^[[:space:]]*$/d' | grep -iE 'installed|not installed|partial|running|ready|enabled|missing|bootstrapped|unavailable' | head -n 1)
  if [ -n "$summary" ]; then
    printf '%s\n' "$summary"
    return
  fi
  printf '%s\n' "$output" | sed '/^[[:space:]]*$/d' | head -n 1
}

arcana_status_output_for_module() {
  module_name=${1-}
  status_script=${2-}
  status_cmd=""
  if hascmd "${module_name}-status" 2>/dev/null; then
    status_cmd="${module_name}-status"
  fi

  if [ -n "$status_cmd" ]; then
    if [ "$module_name" = "wizardry-apps" ]; then
      merged=''
      for section in web desktop mobile; do
        section_output=$(run_status_capture "$status_cmd" --section "$section")
        [ -n "$section_output" ] || continue
        if [ -n "$merged" ]; then
          merged="$merged
$section_output"
        else
          merged=$section_output
        fi
      done
      if [ -n "$merged" ]; then
        printf '%s\n' "$merged"
        return
      fi
    fi
    run_status_capture "$status_cmd"
    return
  fi

  if [ -n "$status_script" ]; then
    if [ "$module_name" = "wizardry-apps" ]; then
      merged=''
      for section in web desktop mobile; do
        section_output=$(run_status_capture "$status_script" --section "$section")
        if [ -z "$section_output" ]; then
          section_output=$(run_status_capture sh "$status_script" --section "$section")
        fi
        [ -n "$section_output" ] || continue
        if [ -n "$merged" ]; then
          merged="$merged
$section_output"
        else
          merged=$section_output
        fi
      done
      if [ -n "$merged" ]; then
        printf '%s\n' "$merged"
        return
      fi
    fi
    output=$(run_status_capture "$status_script")
    if [ -z "$output" ]; then
      output=$(run_status_capture sh "$status_script")
    fi
    printf '%s\n' "$output"
    return
  fi
}

resolve_arcana_status() {
  module_name=$1
  roots=${2-}
  output=''
  status_script=$(arcana_status_script_for_module "$module_name" "$roots")
  output=$(arcana_status_output_for_module "$module_name" "$status_script")

  if [ -z "$output" ]; then
    normalize_status 'not installed'
    return
  fi

  checked=$(printf '%s\n' "$output" | grep -E '^\[[Xx]\][[:space:]]' | wc -l | tr -d ' ')
  unchecked=$(printf '%s\n' "$output" | grep -E '^\[[[:space:]]\][[:space:]]' | wc -l | tr -d ' ')
  case "$checked" in
    ''|*[!0-9]*) checked=0 ;;
  esac
  case "$unchecked" in
    ''|*[!0-9]*) unchecked=0 ;;
  esac
  if [ "$checked" -gt 0 ] || [ "$unchecked" -gt 0 ]; then
    if [ "$checked" -gt 0 ] && [ "$unchecked" -eq 0 ]; then
      normalize_status "installed ($checked/$checked)"
      return
    fi
    if [ "$checked" -eq 0 ] && [ "$unchecked" -gt 0 ]; then
      normalize_status "not installed (0/$unchecked)"
      return
    fi
    total=$((checked + unchecked))
    normalize_status "partial install ($checked/$total)"
    return
  fi

  summary=$(best_status_summary_line "$output")
  normalize_status "$summary"
}

arcana_item_kind_for_file() {
  case ${1-} in
    *-menu) printf '%s\n' "menu" ;;
    *-status) printf '%s\n' "status" ;;
    install-*) printf '%s\n' "install" ;;
    uninstall-*) printf '%s\n' "uninstall" ;;
    toggle-*) printf '%s\n' "toggle" ;;
    is-*) printf '%s\n' "check" ;;
    *) printf '%s\n' "action" ;;
  esac
}

arcana_item_label_for_file() {
  printf '%s\n' "${1-}" | tr '-' ' '
}

arcana_module_script_dirs() {
  module_name=${1-}
  roots=${2-}
  seen='
'
  while IFS= read -r root_dir || [ -n "$root_dir" ]; do
    [ -n "$root_dir" ] || continue
    module_dir="$root_dir/$module_name"
    [ -d "$module_dir" ] || continue
    has_line_break "$module_dir" && continue
    case "$seen" in
      *"
$module_dir
"*) continue ;;
    esac
    seen="$seen$module_dir
"
    printf '%s\n' "$module_dir"
  done <<EOF
$roots
EOF
}

arcana_status_details_for_module() {
  module_name=${1-}
  roots=${2-}
  status_script=$(arcana_status_script_for_module "$module_name" "$roots")
  output=$(arcana_status_output_for_module "$module_name" "$status_script")
  [ -n "$output" ] || return 0
  printf '%s\n' "$output" | while IFS= read -r line || [ -n "$line" ]; do
    line=$(sanitize_record_field "$line")
    case "$line" in
      \[*\]\ *) printf 'status-detail|%s|%s\n' "$line" "$line" ;;
      *) continue ;;
    esac
  done
}

cmd_list_arcana_module_items() {
  module_name=${1-}
  safe_name "$module_name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid arcana module: $module_name" >&2
    exit 2
  }
  install_root=${2-}
  roots=$(arcana_install_roots "$install_root")
  [ -n "$roots" ] || return 0

  {
    arcana_status_details_for_module "$module_name" "$roots"
    arcana_module_script_dirs "$module_name" "$roots" | while IFS= read -r module_dir || [ -n "$module_dir" ]; do
      [ -n "$module_dir" ] || continue
      find "$module_dir" -maxdepth 1 -type f 2>/dev/null | while IFS= read -r file || [ -n "$file" ]; do
        [ -n "$file" ] || continue
        item_name=$(basename "$file")
        case "$item_name" in
          ''|.*|_*) continue ;;
        esac
        safe_name "$item_name" || continue
        kind=$(arcana_item_kind_for_file "$item_name")
        label=$(arcana_item_label_for_file "$item_name")
        printf '%s|%s|%s\n' "$kind" "$item_name" "$label"
      done
    done
  } | awk -F'|' '!seen[$2]++' | sort -t '|' -k1,1 -k2,2
}

cmd_list_arcana_install() {
  install_root=${1-}
  roots=$(arcana_install_roots "$install_root")
  [ -n "$roots" ] || return 0

  list_entries=""
  seen_entries=""

  while IFS= read -r root_dir || [ -n "$root_dir" ]; do
    [ -n "$root_dir" ] || continue
    while IFS= read -r name || [ -n "$name" ]; do
      [ -n "$name" ] || continue
      safe_name "$name" || continue
      case " $seen_entries " in
        *" $name "*)
          continue
          ;;
      esac
      seen_entries="$seen_entries $name "
      list_entries="$list_entries $name"
    done <<EOF
$(arcana_entry_names "$root_dir")
EOF
  done <<EOF
$roots
EOF

  for name in $list_entries; do
    case "$name" in
      import-arcanum| '')
        continue
        ;;
    esac
    emit=false
    if hascmd "$name-menu" || hascmd "$name-status" || hascmd "$name"; then
      emit=true
    else
      while IFS= read -r root_dir || [ -n "$root_dir" ]; do
        [ -n "$root_dir" ] || continue
        if [ -d "$root_dir/$name" ] || [ -f "$root_dir/$name-menu" ] || [ -f "$root_dir/$name" ] || [ -f "$root_dir/$name/$name-status" ] || [ -f "$root_dir/$name-status" ] || [ -f "$root_dir/$name/$name" ] || [ -f "$root_dir/$name/install-$name" ]; then
          emit=true
          break
        fi
      done <<EOF
$roots
EOF
    fi
    if [ "$emit" = "true" ]; then
      printf '%s|%s|%s\n' "$name" "$(resolve_arcana_status "$name" "$roots")" "$(arcana_label_for_name "$name")"
    fi
  done

  import_ready=false
  if hascmd import-arcanum; then
    import_ready=true
  else
    while IFS= read -r root_dir || [ -n "$root_dir" ]; do
      [ -n "$root_dir" ] || continue
      if [ -f "$root_dir/import-arcanum" ]; then
        import_ready=true
        break
      fi
    done <<EOF
$roots
EOF
  fi
  if [ "$import_ready" = "true" ]; then
    printf 'import-arcanum|%s|import arcanum\n' "ready"
  fi
}

resolve_arcana_launch_script() {
  install_root=${1-}
  name=${2-}
  if [ -f "$install_root/$name-menu" ] && [ ! -d "$install_root/$name-menu" ]; then
    printf '%s\n' "$install_root/$name-menu"
    return
  fi
  if [ -f "$install_root/$name/$name-menu" ] && [ ! -d "$install_root/$name/$name-menu" ]; then
    printf '%s\n' "$install_root/$name/$name-menu"
    return
  fi
  if [ -f "$install_root/$name" ] && [ ! -d "$install_root/$name" ]; then
    printf '%s\n' "$install_root/$name"
    return
  fi
  if [ -f "$install_root/$name/$name" ] && [ ! -d "$install_root/$name/$name" ]; then
    printf '%s\n' "$install_root/$name/$name"
    return
  fi
  if [ -f "$install_root/$name/install-$name" ] && [ ! -d "$install_root/$name/install-$name" ]; then
    printf '%s\n' "$install_root/$name/install-$name"
    return
  fi
  printf '\n'
}

cmd_run_arcana_install() {
  name=${1-}
  safe_name "$name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid arcana module: $name" >&2
    exit 2
  }
  root=$(require_root "")
  launcher=''
  for candidate in "$root/spells/.arcana" "$WIZARDRY_DIR_FALLBACK/spells/.arcana" "$WIZARDRY_APPS_ROOT_FALLBACK/spells/.arcana"; do
    [ -d "$candidate" ] || continue
    launcher=$(resolve_arcana_launch_script "$candidate" "$name")
    [ -n "$launcher" ] && break
  done
  app_label=$(normalize_watch_actor "$name")
  app_label=${app_label-}
  [ -n "$app_label" ] || app_label='wizardry-arcana'
  if [ -n "$launcher" ]; then
    if sh "$launcher"; then
      record_watch "app" "arcana-install:$name" "$app_label" "ok"
      return
    fi
    code=$?
    record_watch "app" "arcana-install:$name" "$app_label" "failed:$code"
    exit 2
  fi
  record_watch "app" "arcana-install:$name" "$app_label" "failed:no-launcher"
  printf '%s\n' "wizardry-desktop-backend: no launcher for arcana module '$name'" >&2
  exit 2
}

cmd_run_arcana_menu() {
  name=${1-}
  install_root=${2-}
  safe_name "$name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid arcana module: $name" >&2
    exit 2
  }
  script=''
  if [ -n "$install_root" ] && [ -d "$install_root" ]; then
    script=$(resolve_arcana_module_script "$install_root" "$name" "menu")
  else
    root=$(require_root "")
    for candidate in "$root/spells/.arcana" "$WIZARDRY_DIR_FALLBACK/spells/.arcana" "$WIZARDRY_APPS_ROOT_FALLBACK/spells/.arcana"; do
      [ -d "$candidate" ] || continue
      script=$(resolve_arcana_module_script "$candidate" "$name" "menu")
      [ -n "$script" ] && break
    done
  fi
  app_label=$(normalize_watch_actor "$name")
  app_label=${app_label-}
  [ -n "$app_label" ] || app_label='wizardry-arcana'
  if [ -n "$script" ]; then
    if sh "$script"; then
      record_watch "app" "arcana:menu:$name" "$app_label" "ok"
      return
    fi
    code=$?
    record_watch "app" "arcana:menu:$name" "$app_label" "failed:$code"
    exit 2
  fi
  record_watch "app" "arcana:menu:$name" "$app_label" "failed:missing"
  printf '%s\n' "wizardry-desktop-backend: no menu for arcana module '$name'" >&2
  exit 2
}

resolve_arcana_module_item_script() {
  module_name=${1-}
  item_name=${2-}
  install_root=${3-}
  safe_name "$module_name" || return 1
  safe_name "$item_name" || return 1

  if [ -n "$install_root" ] && [ -d "$install_root" ]; then
    if [ -f "$install_root/$module_name/$item_name" ] && [ ! -d "$install_root/$module_name/$item_name" ]; then
      printf '%s\n' "$install_root/$module_name/$item_name"
      return
    fi
  else
    root=$(require_root "")
    for candidate in "$root/spells/.arcana" "$WIZARDRY_DIR_FALLBACK/spells/.arcana" "$WIZARDRY_APPS_ROOT_FALLBACK/spells/.arcana"; do
      [ -d "$candidate" ] || continue
      if [ -f "$candidate/$module_name/$item_name" ] && [ ! -d "$candidate/$module_name/$item_name" ]; then
        printf '%s\n' "$candidate/$module_name/$item_name"
        return
      fi
    done
  fi
  printf '\n'
}

cmd_run_arcana_module_item() {
  module_name=${1-}
  item_name=${2-}
  install_root=${3-}
  if [ "$#" -ge 3 ]; then
    shift 3
  else
    set --
  fi
  safe_name "$module_name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid arcana module: $module_name" >&2
    exit 2
  }
  safe_name "$item_name" || {
    printf '%s\n' "wizardry-desktop-backend: invalid arcana module item: $item_name" >&2
    exit 2
  }
  case "$(arcana_item_kind_for_file "$item_name")" in
    install|uninstall|toggle|action|check) ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unsupported arcana module item: $item_name" >&2
      exit 2
      ;;
  esac
  script=$(resolve_arcana_module_item_script "$module_name" "$item_name" "$install_root")
  app_label=$(normalize_watch_actor "$module_name")
  app_label=${app_label-}
  [ -n "$app_label" ] || app_label='wizardry-arcana'
  if [ -n "$script" ]; then
    if sh "$script" "$@"; then
      record_watch "app" "arcana:item:$module_name:$item_name" "$app_label" "ok"
      return
    fi
    code=$?
    record_watch "app" "arcana:item:$module_name:$item_name" "$app_label" "failed:$code"
    exit 2
  fi
  record_watch "app" "arcana:item:$module_name:$item_name" "$app_label" "failed:missing"
  printf '%s\n' "wizardry-desktop-backend: no arcana module item '$item_name' for '$module_name'" >&2
  exit 2
}

cmd_app_help() {
  target=${1-}
  root=${2-}

  [ -n "$target" ] || {
    printf '%s\n' "wizardry-desktop-backend: app-help requires a target command" >&2
    return 2
  }

  case "$target" in
    cast|mud|spellbook|main-menu)
      cmd_menu_help "$target" "$root"
      ;;
    arcana)
      cmd_menu_help "install-menu" "$root"
      ;;
    system)
      cmd_menu_help "system-menu" "$root"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unsupported app help target: $target" >&2
      return 2
      ;;
  esac
}

cmd_run_action() {
  action=${1-}
  arg1=${2-}
  arg2=${3-}
  root=$(require_root "${4-}")

  case "$action" in
    arcana:module-menu)
      cmd_run_arcana_menu "$arg1" "$root/spells/.arcana"
      ;;
    arcana:menu)
      if [ -n "$arg1" ]; then
        cmd_run_arcana_menu "$arg1" "$root/spells/.arcana"
        return
      fi
      menu_script="$WIZARDRY_DIR_FALLBACK/spells/menu/main-menu"
      if [ -f "$menu_script" ]; then
        if sh "$menu_script"; then
          record_watch "app" "arcana:menu" "wizardry-core" "ok"
          return
        fi
        code=$?
        record_watch "app" "arcana:menu" "wizardry-core" "failed:$code"
        exit 2
      fi
      record_watch "app" "arcana:menu" "wizardry-core" "failed:missing"
      printf '%s\n' "wizardry-desktop-backend: arcana menu unavailable" >&2
      exit 2
      ;;
    arcana:install-menu)
      cmd_list_arcana_install "$root/spells/.arcana"
      record_watch "app" "arcana:install-menu" "wizardry-core" "ok"
      ;;
    arcana:install)
      if cmd_run_arcana_install "$arg1"; then
        record_watch "app" "arcana:install:$arg1" "wizardry-core" "ok"
      else
        code=$?
        record_watch "app" "arcana:install:$arg1" "wizardry-core" "failed:$code"
        exit 2
      fi
      ;;
    arcana:item)
      cmd_run_arcana_module_item "$arg1" "$arg2" "$root/spells/.arcana"
      ;;
    arcana:themes)
      record_watch "app" "arcana:themes" "wizardry-core" "queued"
      cmd_list_themes "$root"
      ;;
    arcana:reload)
      record_watch "app" "arcana:reload" "wizardry-core" "queued"
      printf '%s\n' "wizardry-desktop-backend: arcana cache reload requested"
      ;;
    app-help)
      if cmd_app_help "$arg1" "$root"; then
        record_watch "app" "app-help:$arg1" "wizardry-core" "ok"
        return
      fi
      code=$?
      record_watch "app" "app-help:$arg1" "wizardry-core" "failed:$code"
      exit 2
      ;;
    menu:list)
      cmd_list_menu_spells "$root"
      record_watch "app" "menu:list" "wizardry-core" "ok"
      ;;
    menu:help)
      cmd_menu_help "$arg1" "$root"
      record_watch "app" "menu:help:$arg1" "wizardry-core" "ok"
      ;;
    menu:run)
      menu_name=$arg1
      menu_arg=$arg2
      if [ -n "$menu_name" ] && [ -z "$menu_arg" ]; then
        case "$menu_name" in
          *:*)
            menu_arg=${menu_name#*:}
            menu_name=${menu_name%%:*}
            ;;
        esac
      fi
      cmd_run_menu "$menu_name" "$menu_arg" "$root"
      ;;
    menu:terminal)
      cmd_open_menu_terminal "$arg1" "$arg2" "$root"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unsupported action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_run_system() {
  command=${1-}
  case "$command" in
    system:restart-menu|restart-menu)
      root=$(require_root "")
      cmd_open_menu_terminal "shutdown-menu" "" "$root"
      ;;
    system:services-menu|services-menu)
      root=$(require_root "")
      cmd_open_menu_terminal "services-menu" "" "$root"
      ;;
    system:verify-posix|verify-posix)
      run_named_system_command "system:verify-posix" "verify-posix"
      ;;
    system:update-wizardry|update-wizardry)
      run_named_system_command "system:update-wizardry" "update-wizardry"
      ;;
    system:test-magic|test-magic)
      run_named_system_command "system:test-magic" "test-magic"
      ;;
    system:profile-tests|profile-tests)
      run_named_system_command "system:profile-tests" "profile-tests"
      ;;
    system:update-all|update-all)
      run_named_system_command "system:update-all" "update-all" "-v"
      ;;
    system:uninstall-wizardry|uninstall-wizardry)
      run_system_uninstall
      ;;
    system:nixos-rebuild|nixos-rebuild)
      if ! is_nixos_host; then
        printf '%s\n' "wizardry-desktop-backend: nixos-rebuild is only available on NixOS" >&2
        record_watch "app" "system:nixos-rebuild" "host" "failed:unsupported"
        exit 2
      fi
      if ! hascmd nixos-rebuild; then
        printf '%s\n' "wizardry-desktop-backend: nixos-rebuild command unavailable" >&2
        record_watch "app" "system:nixos-rebuild" "host" "failed:missing"
        exit 2
      fi
      run_terminal_command "sudo nixos-rebuild switch" "system:nixos-rebuild" "host"
      ;;
    system:whoami)
      if whoami; then
        record_watch "app" "system:whoami" "host" "ok"
      else
        code=$?
        record_watch "app" "system:whoami" "host" "failed:$code"
        exit 2
      fi
      ;;
    system:pwd)
      if pwd; then
        record_watch "app" "system:pwd" "host" "ok"
      else
        code=$?
        record_watch "app" "system:pwd" "host" "failed:$code"
        exit 2
      fi
      ;;
    system:date)
      if date; then
        record_watch "app" "system:date" "host" "ok"
      else
        code=$?
        record_watch "app" "system:date" "host" "failed:$code"
        exit 2
      fi
      ;;
    status)
      printf '%s\n' "status=ok"
      record_watch "app" "system:status" "host" "ok"
      ;;
    environment)
      printf 'shell=%s\n' "$(sanitize_value "${SHELL-}")"
      printf 'pwd=%s\n' "$(sanitize_value "${PWD-}")"
      record_watch "app" "system:environment" "host" "ok"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unsupported system command: $command" >&2
      exit 2
      ;;
  esac
}

action=${1-}
if [ -z "$action" ]; then
  printf '%s\n' "wizardry-desktop-backend: action required" >&2
  exit 2
fi
shift || true

case "$action" in
  root-hint)
    cmd_root_hint "$@"
    ;;
  list-themes)
    cmd_list_themes "$@"
    ;;
  get-ui-prefs)
    cmd_get_ui_prefs "$@"
    ;;
  set-ui-pref)
    cmd_set_ui_pref "$@"
    ;;
  list-spell-categories)
    cmd_list_spell_categories "$@"
    ;;
  list-spells)
    cmd_list_spells "$@"
    ;;
  list-synonyms)
    cmd_list_synonyms "$@"
    ;;
  add-synonym)
    cmd_add_synonym "$@"
    ;;
  remove-synonym)
    cmd_remove_synonym "$@"
    ;;
  run-spell)
    cmd_run_spell "$@"
    ;;
  spell-help)
    cmd_spell_help "$@"
    ;;
  list-menu-spells)
    cmd_list_menu_spells "$@"
    ;;
  list-main-menu-entries)
    cmd_list_main_menu_entries "$@"
    ;;
  list-system-menu-actions)
    cmd_list_system_menu_actions "$@"
    ;;
  list-mud-actions)
    cmd_list_mud_actions "$@"
    ;;
  menu-help)
    cmd_menu_help "$@"
    ;;
  run-menu)
    cmd_run_menu "$@"
    ;;
  open-menu-terminal)
    cmd_open_menu_terminal "$@"
    ;;
  list-memorized-spells)
    cmd_list_memorized_spells "$@"
    ;;
  memorize-spell)
    cmd_memorize_spell "$@"
    ;;
  list-arcana-install)
    cmd_list_arcana_install "$@"
    ;;
  list-arcana-module-items)
    cmd_list_arcana_module_items "$@"
    ;;
  list-watch)
    list_watch "$@"
    ;;
  run-arcana-install)
    cmd_run_arcana_install "$@"
    ;;
  run-arcana-module-item)
    cmd_run_arcana_module_item "$@"
    ;;
  run-action)
    cmd_run_action "$@"
    ;;
  run-system)
    cmd_run_system "$@"
    ;;
  run-mud-action)
    cmd_run_mud_action "$@"
    ;;
  *)
    printf '%s\n' "wizardry-desktop-backend: unknown action: $action" >&2
    exit 2
    ;;
esac
