#!/bin/sh

case "${1-}" in
  --help|--usage|-h)
    cat <<'USAGE'
Usage: wizardry-desktop-backend.sh COMMAND [ARGS...]

Commands:
  doctor
  list-themes [ROOT_HINT]
  get-ui-prefs
  set-ui-pref KEY VALUE
  list-categories
  list-custom-root-spells
  list-spells KIND ID
  list-arcana
  list-cast
  list-spell-activity
  list-synonyms
  list-players
  mud-status
  run-spell SPELL [ARGS...]
  spell-help SPELL
  memorize SPELL
  forget SPELL
  run-cast ALIAS
  create-category NAME
  scribe-spell NAME CATEGORY COMMAND
  synonym ACTION [ARGS...]
  system ACTION
  network ACTION
  service ACTION [UNIT]
  user ACTION [ARGS...]
  power ACTION
  mud ACTION [ARGS...]
  arcana ACTION NAME
USAGE
    exit 0
    ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)

resolve_wizardry_dir() {
  if [ -n "${WIZARDRY_DIR-}" ] && [ -d "${WIZARDRY_DIR-}" ]; then
    printf '%s\n' "$WIZARDRY_DIR"
    return 0
  fi
  if [ -d "$HOME/.wizardry" ]; then
    printf '%s\n' "$HOME/.wizardry"
    return 0
  fi
  printf '%s\n' "$APP_DIR"
}

WIZARDRY_DIR=$(resolve_wizardry_dir)
export WIZARDRY_DIR

append_path_dir() {
  dir=${1-}
  [ -d "$dir" ] || return 0
  case ":$PATH:" in
    *:"$dir":*)
      ;;
    *)
      PATH=$dir:$PATH
      ;;
  esac
}

bootstrap_wizardry_path() {
  append_path_dir "$WIZARDRY_DIR/spells"
  append_path_dir "$WIZARDRY_DIR/spells/.arcana"
  for dir in "$WIZARDRY_DIR"/spells/.arcana/*; do
    [ -d "$dir" ] || continue
    append_path_dir "$dir"
  done
  for dir in "$WIZARDRY_DIR"/spells/.imps/*; do
    [ -d "$dir" ] || continue
    append_path_dir "$dir"
  done
  append_path_dir "$WIZARDRY_DIR/spells/.imps"
}

bootstrap_wizardry_path
export PATH

spellbook_dir() {
  printf '%s\n' "${SPELLBOOK_DIR:-$HOME/.spellbook}"
}

spell_activity_catalog() {
  target=${1-}
  [ -n "$target" ] || return 1
  : >"$target"

  if [ -d "$WIZARDRY_DIR/spells" ]; then
    for dir in "$WIZARDRY_DIR"/spells/*; do
      [ -d "$dir" ] || continue
      case "$(basename "$dir")" in
        .*)
          continue
          ;;
      esac
      for spell in "$dir"/*; do
        [ -f "$spell" ] || continue
        [ -x "$spell" ] || continue
        printf 'builtin-spell\t%s\t%s\n' "$(basename "$spell")" "$spell" >>"$target"
      done
    done
  fi

  if [ -d "$HOME/spells" ]; then
    for spell in "$HOME"/spells/* "$HOME"/spells/*/*; do
      [ -f "$spell" ] || continue
      [ -x "$spell" ] || continue
      printf 'home-spell\t%s\t%s\n' "$(basename "$spell")" "$spell" >>"$target"
    done
  fi
}

ui_prefs_file() {
  base="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps"
  mkdir -p "$base"
  printf '%s\n' "$base/wizardry-desktop-ui.conf"
}

write_key_value_file() {
  file=${1-}
  key=${2-}
  value=${3-}
  [ -n "$file" ] || return 1
  [ -n "$key" ] || return 1
  tmp=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-kv.XXXXXX")
  found=0
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "$key="*)
          printf '%s=%s\n' "$key" "$value" >>"$tmp"
          found=1
          ;;
        *)
          printf '%s\n' "$line" >>"$tmp"
          ;;
      esac
    done <"$file"
  fi
  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  mv "$tmp" "$file"
}

read_key_value_file() {
  file=${1-}
  key=${2-}
  default=${3-}
  if [ -f "$file" ]; then
    value=$(awk -F= -v wanted="$key" '$1 == wanted { sub(/^[^=]*=/, "", $0); print; exit }' "$file")
    if [ -n "${value-}" ]; then
      printf '%s\n' "$value"
      return 0
    fi
  fi
  printf '%s\n' "$default"
}

ui_pref_value() {
  prefs=$(ui_prefs_file)
  read_key_value_file "$prefs" "${1-}" "${2-}"
}

validate_ui_pref_key() {
  key=${1-}
  case "$key" in
    [a-z0-9][a-z0-9._-]*)
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: invalid UI pref key: $key" >&2
      exit 2
      ;;
  esac
}

sanitize_ui_pref_value() {
  value=${1-}
  printf '%s' "$value" | tr '\r\n' '  '
}

sanitize_field() {
  value=${1-}
  printf '%s' "$value" \
    | tr '\t\r\n' '   ' \
    | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

strip_ansi() {
  printf '%s' "${1-}" | sed 's/\x1b\[[0-9;]*m//g'
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "${1-}" | sed "s/'/'\\\\''/g")"
}

trace_line() {
  out=''
  for arg in "$@"; do
    if [ -n "$out" ]; then
      out="$out "
    fi
    out="${out}$(shell_quote "$arg")"
  done
  printf '+ %s\n' "$out" >&2
}

trace_exec() {
  trace_line "$@"
  "$@"
}

trace_in_dir_exec() {
  dir=${1-}
  shift
  [ -d "$dir" ] || {
    printf '%s\n' "wizardry-desktop-backend: directory not found: $dir" >&2
    exit 1
  }
  printf '+ cd %s &&' "$(shell_quote "$dir")" >&2
  for arg in "$@"; do
    printf ' %s' "$(shell_quote "$arg")" >&2
  done
  printf '\n' >&2
  (
    cd "$dir"
    "$@"
  )
}

validate_name_token() {
  value=${1-}
  case "$value" in
    [A-Za-z0-9_][A-Za-z0-9_.-]*)
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: invalid name: $value" >&2
      exit 2
      ;;
  esac
}

validate_player_name() {
  value=${1-}
  if command -v validate-player-name >/dev/null 2>&1; then
    if validate-player-name "$value" >/dev/null 2>&1; then
      return 0
    fi
  fi
  case "$value" in
    [A-Za-z][A-Za-z0-9_][A-Za-z0-9_]*)
      if [ "${#value}" -ge 3 ] && [ "${#value}" -le 16 ]; then
        return 0
      fi
      ;;
  esac
  printf '%s\n' "wizardry-desktop-backend: invalid player name: $value" >&2
  exit 2
}

validate_service_name() {
  value=${1-}
  case "$value" in
    [A-Za-z0-9_][A-Za-z0-9_.@:-]*)
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: invalid service name: $value" >&2
      exit 2
      ;;
  esac
}

validate_simple_arg() {
  value=${1-}
  case "$value" in
    *"$(
      printf '\n'
    )"*|*"$(
      printf '\r'
    )"*)
      printf '%s\n' "wizardry-desktop-backend: invalid argument" >&2
      exit 2
      ;;
  esac
}

spell_category_description() {
  case "${1-}" in
    arcane) printf '%s\n' "Core magical utilities and hidden machinery." ;;
    cantrips) printf '%s\n' "Everyday helper spells and shell affordances." ;;
    crypto) printf '%s\n' "Hashing, signatures, and encryption helpers." ;;
    divination) printf '%s\n' "Inspection, lookup, and discovery tools." ;;
    enchant) printf '%s\n' "Metadata and file attribute manipulation." ;;
    mud) printf '%s\n' "Adventure, multiplayer, and world-building spells." ;;
    priorities) printf '%s\n' "File-backed prioritization and next-action flows." ;;
    psi) printf '%s\n' "Voice, AI, and mind-adjacent desktop powers." ;;
    spellcraft) printf '%s\n' "Create, edit, memorize, and rename spells." ;;
    system) printf '%s\n' "Machine maintenance, users, services, and shutdown." ;;
    tasks) printf '%s\n' "Simple file-backed task flows and progress helpers." ;;
    translocation) printf '%s\n' "Markers, portals, and movement across paths." ;;
    wards) printf '%s\n' "Safety, checks, and protective wrappers." ;;
    web) printf '%s\n' "Hosted site creation, serving, and web operations." ;;
    *) printf '%s\n' "Wizardry spell category." ;;
  esac
}

arcana_description() {
  case "${1-}" in
    core) printf '%s\n' "Install the core Wizardry command set." ;;
    mud) printf '%s\n' "Set up multiplayer MUD hosting and its helpers." ;;
    web-wizardry) printf '%s\n' "Install the web site and CGI authoring arcana." ;;
    wizardry-apps) printf '%s\n' "Install the desktop and mobile app surfaces." ;;
    ai-dev) printf '%s\n' "Install AI-assisted development support." ;;
    yt-dlp) printf '%s\n' "Install media download tooling." ;;
    voice-recognition) printf '%s\n' "Install dictation and voice-recognition tooling." ;;
    nostr) printf '%s\n' "Install Nostr and relay-oriented support spells." ;;
    *) printf '%s\n' "Install optional supporting software for Wizardry." ;;
  esac
}

arcana_label() {
  case "${1-}" in
    core) printf '%s\n' "core wizardry" ;;
    mud) printf '%s\n' "wizardry MUD" ;;
    web-wizardry) printf '%s\n' "web wizardry" ;;
    wizardry-apps) printf '%s\n' "wizardry apps" ;;
    ai-dev) printf '%s\n' "AI dev" ;;
    yt-dlp) printf '%s\n' "yt-dlp" ;;
    voice-recognition) printf '%s\n' "voice recognition" ;;
    nostr) printf '%s\n' "Nostr" ;;
    docker) printf '%s\n' "Docker" ;;
    *)
      printf '%s\n' "${1-}"
      ;;
  esac
}

spell_summary_from_file() {
  file=${1-}
  if [ -r "$file" ]; then
    summary=$(awk '
      NR == 1 && /^#!/ { next }
      /^[[:space:]]*#/ {
        line=$0
        sub(/^[[:space:]]*#[[:space:]]?/, "", line)
        if (line != "") {
          print line
          exit
        }
      }
    ' "$file")
    if [ -n "${summary-}" ]; then
      sanitize_field "$summary"
      return 0
    fi
  fi
  sanitize_field ""
}

custom_root_spell_summary() {
  script=${1-}
  if [ ! -r "$script" ]; then
    printf '%s\n' ""
    return 0
  fi
  extracted=$(sed -n 's/^exec sh -c '\''\(.*\)'\'' "\$0" "\$@"$/\1/p' "$script" | head -n 1)
  if [ -n "$extracted" ]; then
    extracted=$(printf '%s' "$extracted" | sed "s/'\\\\''/'/g")
    sanitize_field "$extracted"
    return 0
  fi
  spell_summary_from_file "$script"
}

spell_is_memorized() {
  spell=${1-}
  if command -v memorize >/dev/null 2>&1; then
    tab=$(printf '\t')
    memorize list 2>/dev/null | awk -F "$tab" -v wanted="$spell" '$1 == wanted { found=1 } END { exit(found ? 0 : 1) }'
    return $?
  fi
  return 1
}

spell_exists() {
  spell=${1-}
  validate_name_token "$spell"
  command -v "$spell" >/dev/null 2>&1
}

work_dir() {
  candidate=$(ui_pref_value work_dir "$HOME")
  if [ -d "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  printf '%s\n' "$HOME"
}

mud_room_path() {
  candidate=$(ui_pref_value mud_room_path "$HOME")
  if [ -d "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  printf '%s\n' "$HOME"
}

mud_config_file() {
  spell_home=$(spellbook_dir)
  mkdir -p "$spell_home"
  printf '%s\n' "$spell_home/.mud"
}

mud_feature_enabled() {
  feature=${1-}
  config_file=$(mud_config_file)
  default_enabled=0
  case "$feature" in
    parse-enabled|mud-enabled|cd-look)
      default_enabled=1
      ;;
  esac
  value=$(read_key_value_file "$config_file" "$feature" "")
  if [ -n "$value" ]; then
    [ "$value" = "1" ] && printf '%s\n' "1" || printf '%s\n' "0"
    return 0
  fi
  printf '%s\n' "$default_enabled"
}

detect_portal_location() {
  case "$(uname -s 2>/dev/null || printf '')" in
    Darwin)
      printf '%s\n' "/Volumes"
      ;;
    *)
      printf '%s\n' "/mnt"
      ;;
  esac
}

detect_tor_status() {
  torrc_path=''
  if command -v torrc-path >/dev/null 2>&1; then
    torrc_path=$(torrc-path 2>/dev/null || printf '')
  fi
  if [ -z "$torrc_path" ]; then
    for candidate in /usr/local/etc/tor/torrc /opt/local/etc/tor/torrc /etc/tor/torrc; do
      if [ -f "$candidate" ]; then
        torrc_path=$candidate
        break
      fi
    done
  fi
  if [ -n "$torrc_path" ] && [ -f "$torrc_path" ]; then
    if grep -E -q '^[[:space:]]*HiddenServiceDir.*/mud(/)?$' "$torrc_path" 2>/dev/null; then
      printf '%s\t%s\n' "1" "$torrc_path"
      return 0
    fi
  fi
  printf '%s\t%s\n' "0" "$torrc_path"
}

detect_onion_address() {
  tor_status=$(detect_tor_status)
  tor_enabled=$(printf '%s\n' "$tor_status" | awk -F '\t' '{ print $1 }')
  torrc_path=$(printf '%s\n' "$tor_status" | awk -F '\t' '{ print $2 }')
  if [ "$tor_enabled" != "1" ] || [ -z "$torrc_path" ]; then
    return 0
  fi
  hostname_dir=$(grep -E '^[[:space:]]*HiddenServiceDir.*/mud(/)?$' "$torrc_path" 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*HiddenServiceDir[[:space:]]*//')
  hostname_dir=${hostname_dir%/}
  hostname_file=$hostname_dir/hostname
  if [ -f "$hostname_file" ]; then
    head -n 1 "$hostname_file" | tr -d '\r'
  fi
}

resolve_root() {
  hint=${1-}
  if [ -n "$hint" ] && [ -d "$hint" ] && [ -f "$hint/config/apps.manifest.json" ]; then
    (CDPATH= cd -- "$hint" && pwd -P)
    return 0
  fi
  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && [ -f "$WIZARDRY_APPS_ROOT/config/apps.manifest.json" ]; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT"
    return 0
  fi
  repo_candidate=$APP_DIR
  while [ "$repo_candidate" != "/" ]; do
    if [ -f "$repo_candidate/config/apps.manifest.json" ]; then
      printf '%s\n' "$repo_candidate"
      return 0
    fi
    repo_candidate=$(dirname "$repo_candidate")
  done
  printf '%s\n' "$APP_DIR"
}

theme_names_from_dir() {
  dir=${1-}
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.css' 2>/dev/null \
    | awk -F/ '{ print $NF }' \
    | sed 's/\.css$//' \
    | awk '/^[a-z0-9_-]+$/'
}

list_built_in_categories() {
  for dir in "$WIZARDRY_DIR"/spells/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    case "$name" in
      .*|menu)
        continue
        ;;
    esac
    builtin_count=$(find "$dir" -maxdepth 1 -type f -perm -111 2>/dev/null | wc -l | tr -d ' ')
    custom_dir=$(spellbook_dir)/$name
    custom_count=0
    if [ -d "$custom_dir" ]; then
      custom_count=$(find "$custom_dir" -maxdepth 1 -type f -perm -111 2>/dev/null | wc -l | tr -d ' ')
    fi
    total_count=$((builtin_count + custom_count))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "builtin" \
      "$name" \
      "$name" \
      "$total_count" \
      "$(sanitize_field "$(spell_category_description "$name")")" \
      "$dir"
  done | sort
}

list_custom_categories() {
  spell_home=$(spellbook_dir)
  [ -d "$spell_home" ] || return 0
  for dir in "$spell_home"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    case "$name" in
      .*)
        continue
        ;;
    esac
    if [ -d "$WIZARDRY_DIR/spells/$name" ]; then
      continue
    fi
    count=$(find "$dir" -maxdepth 1 -type f -perm -111 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "custom" \
      "$name" \
      "$name" \
      "$count" \
      "$(sanitize_field "Custom spell category from your spellbook.")" \
      "$dir"
  done | sort
}

list_available_arcana() {
  install_dir=$WIZARDRY_DIR/spells/.arcana
  [ -d "$install_dir" ] || return 0
  for name in core mud web-wizardry wizardry-apps ai-dev yt-dlp voice-recognition nostr; do
    if [ -e "$install_dir/$name" ]; then
      printf '%s\n' "$name"
    fi
  done
  for entry in "$install_dir"/*; do
    [ -e "$entry" ] || continue
    name=$(basename "$entry")
    case "$name" in
      core|mud|web-wizardry|wizardry-apps|ai-dev|yt-dlp|voice-recognition|nostr|import-arcanum)
        continue
        ;;
    esac
    printf '%s\n' "$name"
  done
}

arcana_status_command() {
  install_dir=$WIZARDRY_DIR/spells/.arcana
  name=${1-}
  if command -v "${name}-status" >/dev/null 2>&1; then
    printf '%s\n' "${name}-status"
    return 0
  fi
  for candidate in "$install_dir/$name-status" "$install_dir/$name/$name-status"; do
    if [ -x "$candidate" ] && [ ! -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' ""
}

arcana_run_command() {
  install_dir=$WIZARDRY_DIR/spells/.arcana
  name=${1-}
  if command -v "${name}-menu" >/dev/null 2>&1; then
    printf '%s\n' "${name}-menu"
    return 0
  fi
  for candidate in \
    "$install_dir/$name-menu" \
    "$install_dir/$name/$name-menu" \
    "$install_dir/$name" \
    "$install_dir/$name/$name" \
    "$install_dir/$name/install-$name"; do
    if [ -x "$candidate" ] && [ ! -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' ""
}

arcana_menu_command() {
  install_dir=$WIZARDRY_DIR/spells/.arcana
  name=${1-}
  if command -v "${name}-menu" >/dev/null 2>&1; then
    printf '%s\n' "${name}-menu"
    return 0
  fi
  for candidate in "$install_dir/$name-menu" "$install_dir/$name/$name-menu"; do
    if [ -x "$candidate" ] && [ ! -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' ""
}

arcana_action_kind() {
  name=${1-}
  if [ "$name" = "import-arcanum" ]; then
    printf '%s\n' "import"
    return 0
  fi
  if [ -n "$(arcana_menu_command "$name")" ]; then
    printf '%s\n' "menu"
    return 0
  fi
  if [ -n "$(arcana_run_command "$name")" ]; then
    printf '%s\n' "install"
    return 0
  fi
  printf '%s\n' "pending"
}

arcana_action_label() {
  case "${1-}" in
    menu) printf '%s\n' "Open menu" ;;
    install) printf '%s\n' "Install" ;;
    import) printf '%s\n' "Import" ;;
    *) printf '%s\n' "Unavailable" ;;
  esac
}

safe_split_command() {
  line=${1-}
  old_ifs=${IFS}
  IFS=' '
  set -f
  # shellcheck disable=SC2086
  set -- $line
  set +f
  IFS=${old_ifs}
  [ "$#" -gt 0 ] || return 1
  for token in "$@"; do
    case "$token" in
      *[!A-Za-z0-9_./:@%+=,-]*)
        return 1
        ;;
    esac
  done
  printf '%s\n' "$#"
  for token in "$@"; do
    printf '%s\n' "$token"
  done
}

run_safe_line() {
  line=${1-}
  parsed=$(safe_split_command "$line") || {
    printf '%s\n' "wizardry-desktop-backend: memorized command is not safe to execute directly from the GUI: $line" >&2
    exit 1
  }
  count=$(printf '%s\n' "$parsed" | sed -n '1p')
  [ -n "$count" ] || exit 1
  shift_args_tmp=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-argv.XXXXXX")
  printf '%s\n' "$parsed" | sed '1d' >"$shift_args_tmp"
  set --
  while IFS= read -r token || [ -n "$token" ]; do
    set -- "$@" "$token"
  done <"$shift_args_tmp"
  rm -f "$shift_args_tmp"
  trace_in_dir_exec "$(work_dir)" "$@"
}

cmd_doctor() {
  root=$(resolve_root "${2-}")
  category_count=$(list_built_in_categories | wc -l | tr -d ' ')
  spell_count=$(find "$WIZARDRY_DIR/spells" -mindepth 2 -maxdepth 2 -type f -perm -111 2>/dev/null | wc -l | tr -d ' ')
  memorized_count=$(list_cast 2>/dev/null | wc -l | tr -d ' ')
  arcana_count=$(list_available_arcana | wc -l | tr -d ' ')
  printf 'app_dir=%s\n' "$APP_DIR"
  printf 'wizardry_apps_root=%s\n' "$root"
  printf 'wizardry_dir=%s\n' "$WIZARDRY_DIR"
  printf 'spellbook_dir=%s\n' "$(spellbook_dir)"
  printf 'work_dir=%s\n' "$(work_dir)"
  printf 'mud_room_path=%s\n' "$(mud_room_path)"
  printf 'category_count=%s\n' "$category_count"
  printf 'spell_count=%s\n' "$spell_count"
  printf 'memorized_count=%s\n' "$memorized_count"
  printf 'arcana_count=%s\n' "$arcana_count"
}

cmd_list_themes() {
  root=$(resolve_root "${2-}")
  theme_root=$root/web/.themes
  app_theme_dir=$APP_DIR/themes
  {
    theme_names_from_dir "$theme_root"
    theme_names_from_dir "$app_theme_dir"
  } | sort -u
}

cmd_get_ui_prefs() {
  prefs=$(ui_prefs_file)
  [ -f "$prefs" ] || exit 0
  cat "$prefs"
}

cmd_set_ui_pref() {
  key=${2-}
  value=${3-}
  [ -n "$key" ] || {
    printf '%s\n' "wizardry-desktop-backend: set-ui-pref requires KEY" >&2
    exit 2
  }
  validate_ui_pref_key "$key"
  value=$(sanitize_ui_pref_value "$value")
  prefs=$(ui_prefs_file)
  [ -f "$prefs" ] || : >"$prefs"
  write_key_value_file "$prefs" "$key" "$value"
  printf 'key=%s\n' "$key"
  printf 'value=%s\n' "$value"
  printf 'file=%s\n' "$prefs"
}

cmd_list_categories() {
  list_built_in_categories
  list_custom_categories
}

cmd_list_custom_root_spells() {
  spell_home=$(spellbook_dir)
  [ -d "$spell_home" ] || return 0
  for script in "$spell_home"/*; do
    [ -f "$script" ] || continue
    [ -x "$script" ] || continue
    name=$(basename "$script")
    case "$name" in
      .*)
        continue
        ;;
    esac
    if command -v "$name" >/dev/null 2>&1; then
      resolved=$(command -v "$name" 2>/dev/null || printf '')
      case "$resolved" in
        "$spell_home"/*)
          ;;
        *)
          continue
          ;;
      esac
    fi
    printf '%s\t%s\t%s\n' \
      "$name" \
      "$(custom_root_spell_summary "$script")" \
      "$script"
  done | sort
}

list_spells_for_dir() {
  dir=${1-}
  origin=${2-}
  [ -d "$dir" ] || return 0
  for spell in "$dir"/*; do
    [ -f "$spell" ] || continue
    [ -x "$spell" ] || continue
    name=$(basename "$spell")
    memorized=0
    if spell_is_memorized "$name"; then
      memorized=1
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$name" \
      "$origin" \
      "$(spell_summary_from_file "$spell")" \
      "$memorized" \
      "$spell"
  done | sort
}

cmd_list_spells() {
  kind=${2-}
  id=${3-}
  [ -n "$kind" ] || {
    printf '%s\n' "wizardry-desktop-backend: list-spells requires KIND" >&2
    exit 2
  }
  [ -n "$id" ] || {
    printf '%s\n' "wizardry-desktop-backend: list-spells requires ID" >&2
    exit 2
  }
  validate_name_token "$id"
  case "$kind" in
    builtin)
      list_spells_for_dir "$WIZARDRY_DIR/spells/$id" "builtin"
      list_spells_for_dir "$(spellbook_dir)/$id" "custom"
      ;;
    custom)
      list_spells_for_dir "$(spellbook_dir)/$id" "custom"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown spell category kind: $kind" >&2
      exit 2
      ;;
  esac
}

list_arcana() {
  for name in $(list_available_arcana); do
    status_cmd=$(arcana_status_command "$name")
    status="coming soon"
    if [ -n "$status_cmd" ]; then
      status=$(strip_ansi "$($status_cmd 2>/dev/null || printf 'available')")
    fi
    action_kind=$(arcana_action_kind "$name")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "entry" \
      "$name" \
      "$(sanitize_field "$(arcana_label "$name")")" \
      "$(sanitize_field "$status")" \
      "$(sanitize_field "$(arcana_description "$name")")" \
      "$action_kind" \
      "$(sanitize_field "$(arcana_action_label "$action_kind")")"
  done
  if [ -x "$WIZARDRY_DIR/spells/.arcana/import-arcanum" ] || command -v import-arcanum >/dev/null 2>&1; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "import" \
      "import-arcanum" \
      "Import arcanum" \
      "" \
      "Load an external arcanum into the install menu, matching the terminal menu utility item." \
      "import" \
      "Import"
  fi
}

cmd_list_arcana() {
  list_arcana
}

list_cast() {
  if command -v cast >/dev/null 2>&1; then
    cast --list 2>/dev/null || true
  elif command -v memorize >/dev/null 2>&1; then
    memorize list 2>/dev/null || true
  fi
}

cmd_list_cast() {
  list_cast
}

cmd_list_spell_activity() {
  catalog=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-activity.XXXXXX")
  trap 'rm -f "$catalog"' EXIT HUP INT TERM
  spell_activity_catalog "$catalog"
  tab=$(printf '\t')
  ps -eo pid=,ppid=,etime=,command= 2>/dev/null \
    | awk -v catalog="$catalog" -v self_pid="$$" -v builtin_root="$WIZARDRY_DIR/spells" -v home_root="$HOME/spells" '
function first_token(text, parts, count) {
  count = split(text, parts, /[[:space:]]+/)
  return parts[1]
}
function second_token(text, parts, count) {
  count = split(text, parts, /[[:space:]]+/)
  return count >= 2 ? parts[2] : ""
}
function trim_token(text) {
  gsub(/^[[:space:]]+/, "", text)
  gsub(/[[:space:]]+$/, "", text)
  gsub(/^["'"'"'"'"'"'"'"'"']+/, "", text)
  gsub(/["'"'"'"'"'"'"'"'"']+$/, "", text)
  return text
}
function basename_path(path, parts, count) {
  count = split(path, parts, "/")
  return count ? parts[count] : path
}
function slug_from_apps_path(text, idx, rest, end_idx) {
  idx = index(text, "/apps/")
  if (!idx) {
    return ""
  }
  rest = substr(text, idx + 6)
  end_idx = index(rest, "/scripts/")
  if (!end_idx) {
    return ""
  }
  return substr(rest, 1, end_idx - 1)
}
function slug_from_marker(text, marker, idx, rest, slug, i, ch) {
  idx = index(text, marker)
  if (!idx) {
    return ""
  }
  rest = substr(text, idx + length(marker))
  slug = ""
  for (i = 1; i <= length(rest); i += 1) {
    ch = substr(rest, i, 1)
    if (ch == "/" || ch == " " || ch == "\t") {
      break
    }
    slug = slug ch
  }
  return slug
}
function slug_from_host_path(text, slug) {
  slug = slug_from_marker(text, "/Resources/")
  if (slug != "") {
    return slug
  }
  return slug_from_marker(text, "/usr/share/")
}
function infer_app(pid, cur, depth, cmd, slug) {
  cur = pid
  depth = 0
  while (cur != "" && cur != "0" && depth < 16) {
    cmd = proc_cmd[cur]
    slug = slug_from_apps_path(cmd)
    if (slug != "") {
      return slug
    }
    slug = slug_from_host_path(cmd)
    if (slug != "") {
      return slug
    }
    cur = proc_ppid[cur]
    depth += 1
  }
  return "external"
}
function spell_kind_for_command(cmd, token1, token2) {
  if (slug_from_apps_path(cmd) != "") {
    return "app-backend"
  }
  token1 = trim_token(first_token(cmd))
  token2 = trim_token(second_token(cmd))
  if (token1 in catalog_kind) {
    return catalog_kind[token1]
  }
  if (token2 in catalog_kind) {
    return catalog_kind[token2]
  }
  if (index(token1, builtin_root "/") == 1 || index(token2, builtin_root "/") == 1) {
    return "builtin-spell"
  }
  if (index(token1, home_root "/") == 1 || index(token2, home_root "/") == 1) {
    return "home-spell"
  }
  return ""
}
function spell_path_for_command(cmd, kind, token1, token2) {
  token1 = trim_token(first_token(cmd))
  token2 = trim_token(second_token(cmd))
  if (kind == "app-backend") {
    return token2
  }
  if (token1 in catalog_path) {
    return catalog_path[token1]
  }
  if (token2 in catalog_path) {
    return catalog_path[token2]
  }
  if (index(token1, builtin_root "/") == 1 || index(token1, home_root "/") == 1) {
    return token1
  }
  if (index(token2, builtin_root "/") == 1 || index(token2, home_root "/") == 1) {
    return token2
  }
  return ""
}
function target_for_command(cmd, kind, path, token1, token2) {
  token1 = trim_token(first_token(cmd))
  token2 = trim_token(second_token(cmd))
  if (kind == "app-backend") {
    return basename_path(path != "" ? path : token2)
  }
  if (token1 in catalog_kind) {
    return token1
  }
  if (token2 in catalog_kind) {
    return token2
  }
  if (path != "") {
    return basename_path(path)
  }
  return token1
}
BEGIN {
  while ((getline line < catalog) > 0) {
    split(line, cols, "\t")
    if (cols[2] == "") {
      continue
    }
    if (!(cols[2] in catalog_kind)) {
      catalog_kind[cols[2]] = cols[1]
      catalog_path[cols[2]] = cols[3]
    }
  }
  close(catalog)
}
{
  pid = $1
  ppid = $2
  elapsed = $3
  cmd = $0
  sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", cmd)
  proc_ppid[pid] = ppid
  proc_etime[pid] = elapsed
  proc_cmd[pid] = cmd
}
END {
  for (pid in proc_cmd) {
    if (pid == self_pid) {
      continue
    }
    kind = spell_kind_for_command(proc_cmd[pid])
    if (kind == "") {
      continue
    }
    path = spell_path_for_command(proc_cmd[pid], kind)
    target = target_for_command(proc_cmd[pid], kind, path)
    app = infer_app(pid)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", kind, app, pid, proc_ppid[pid], proc_etime[pid], target, path, proc_cmd[pid]
  }
}
' | sort -t "$tab" -k2,2 -k1,1 -k6,6
  rm -f "$catalog"
  trap - EXIT HUP INT TERM
}

cmd_list_synonyms() {
  spell_home=$(spellbook_dir)
  custom_file=$spell_home/.synonyms
  default_file=$spell_home/.default-synonyms
  custom_words=''
  if [ -f "$custom_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ''|\#*)
          continue
          ;;
      esac
      word=${line%%=*}
      target=${line#*=}
      custom_words="${custom_words}${word}
"
      printf '%s\t%s\t%s\n' "$word" "$target" "custom"
    done <"$custom_file"
  fi
  if [ -f "$default_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ''|\#*)
          continue
          ;;
      esac
      word=${line%%=*}
      target=${line#*=}
      if printf '%s\n' "$custom_words" | grep -Fx "$word" >/dev/null 2>&1; then
        continue
      fi
      printf '%s\t%s\t%s\n' "$word" "$target" "default"
    done <"$default_file"
  fi
}

cmd_list_players() {
  config_file=$(mud_config_file)
  selected=$(read_key_value_file "$config_file" player "")
  for key_file in "$HOME"/.ssh/*.pub; do
    [ -f "$key_file" ] || continue
    name=$(basename "$key_file" .pub)
    if command -v validate-player-name >/dev/null 2>&1; then
      validate-player-name "$name" >/dev/null 2>&1 || continue
    fi
    active=0
    [ "$selected" = "$name" ] && active=1
    printf '%s\t%s\t%s\n' "$name" "$active" "$key_file"
  done | sort
}

cmd_mud_status() {
  config_file=$(mud_config_file)
  current_player=$(read_key_value_file "$config_file" player "")
  has_player_key=0
  if [ -n "$current_player" ] && [ -f "$HOME/.ssh/$current_player.pub" ]; then
    has_player_key=1
  fi
  tor_status=$(detect_tor_status)
  printf 'current_player=%s\n' "$current_player"
  printf 'has_player_key=%s\n' "$has_player_key"
  printf 'parse_enabled=%s\n' "$(mud_feature_enabled parse-enabled)"
  printf 'mud_menu_enabled=%s\n' "$(mud_feature_enabled mud-enabled)"
  printf 'cd_look_enabled=%s\n' "$(mud_feature_enabled cd-look)"
  printf 'cd_listen_enabled=%s\n' "$(mud_feature_enabled cd-listen)"
  printf 'avatar_enabled=%s\n' "$(mud_feature_enabled avatar)"
  printf 'touch_hook_enabled=%s\n' "$(mud_feature_enabled touch-hook)"
  printf 'tor_enabled=%s\n' "$(printf '%s\n' "$tor_status" | awk -F '\t' '{ print $1 }')"
  printf 'torrc_path=%s\n' "$(printf '%s\n' "$tor_status" | awk -F '\t' '{ print $2 }')"
  printf 'onion_address=%s\n' "$(detect_onion_address)"
  printf 'portal_location=%s\n' "$(detect_portal_location)"
  printf 'room_path=%s\n' "$(mud_room_path)"
}

cmd_run_spell() {
  spell=${2-}
  [ -n "$spell" ] || {
    printf '%s\n' "wizardry-desktop-backend: run-spell requires SPELL" >&2
    exit 2
  }
  spell_exists "$spell" || {
    printf '%s\n' "wizardry-desktop-backend: spell not found: $spell" >&2
    exit 1
  }
  shift 2
  for arg in "$@"; do
    validate_simple_arg "$arg"
  done
  trace_in_dir_exec "$(work_dir)" "$spell" "$@"
}

cmd_spell_help() {
  spell=${2-}
  [ -n "$spell" ] || {
    printf '%s\n' "wizardry-desktop-backend: spell-help requires SPELL" >&2
    exit 2
  }
  spell_exists "$spell" || {
    printf '%s\n' "wizardry-desktop-backend: spell not found: $spell" >&2
    exit 1
  }
  trace_exec "$spell" --help
}

cmd_memorize() {
  spell=${2-}
  [ -n "$spell" ] || {
    printf '%s\n' "wizardry-desktop-backend: memorize requires SPELL" >&2
    exit 2
  }
  spell_exists "$spell" || {
    printf '%s\n' "wizardry-desktop-backend: spell not found: $spell" >&2
    exit 1
  }
  trace_exec memorize "$spell"
}

cmd_forget() {
  spell=${2-}
  [ -n "$spell" ] || {
    printf '%s\n' "wizardry-desktop-backend: forget requires SPELL" >&2
    exit 2
  }
  validate_name_token "$spell"
  trace_exec forget "$spell"
}

cmd_run_cast() {
  alias_name=${2-}
  [ -n "$alias_name" ] || {
    printf '%s\n' "wizardry-desktop-backend: run-cast requires ALIAS" >&2
    exit 2
  }
  validate_name_token "$alias_name"
  tab=$(printf '\t')
  command_text=$(list_cast | awk -F "$tab" -v wanted="$alias_name" '$1 == wanted { print $2; exit }')
  [ -n "$command_text" ] || {
    printf '%s\n' "wizardry-desktop-backend: memorized alias not found: $alias_name" >&2
    exit 1
  }
  run_safe_line "$command_text"
}

cmd_create_category() {
  name=${2-}
  [ -n "$name" ] || {
    printf '%s\n' "wizardry-desktop-backend: create-category requires NAME" >&2
    exit 2
  }
  validate_name_token "$name"
  target=$(spellbook_dir)/$name
  mkdir -p "$target"
  printf 'category=%s\n' "$name"
  printf 'path=%s\n' "$target"
}

cmd_scribe_spell() {
  name=${2-}
  category=${3-}
  command_text=${4-}
  [ -n "$name" ] || {
    printf '%s\n' "wizardry-desktop-backend: scribe-spell requires NAME" >&2
    exit 2
  }
  [ -n "$command_text" ] || {
    printf '%s\n' "wizardry-desktop-backend: scribe-spell requires COMMAND" >&2
    exit 2
  }
  validate_name_token "$name"
  target_dir=$(spellbook_dir)
  if [ -n "$category" ]; then
    validate_name_token "$category"
    target_dir=$target_dir/$category
    mkdir -p "$target_dir"
  else
    mkdir -p "$target_dir"
  fi
  target_file=$target_dir/$name
  escaped_command=$(printf '%s' "$command_text" | sed "s/'/'\\\\''/g")
  cat >"$target_file" <<SCRIPT
#!/bin/sh
exec sh -c '$escaped_command' "\$0" "\$@"
SCRIPT
  chmod +x "$target_file"
  printf 'spell=%s\n' "$name"
  printf 'path=%s\n' "$target_file"
}

cmd_synonym() {
  action=${2-}
  case "$action" in
    add)
      word=${3-}
      target=${4-}
      [ -n "$word" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym add requires WORD" >&2
        exit 2
      }
      [ -n "$target" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym add requires TARGET" >&2
        exit 2
      }
      validate_name_token "$word"
      trace_exec add-synonym "$word" "$target"
      ;;
    edit-word)
      word=${3-}
      new_word=${4-}
      [ -n "$word" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym edit-word requires WORD" >&2
        exit 2
      }
      [ -n "$new_word" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym edit-word requires NEW_WORD" >&2
        exit 2
      }
      validate_name_token "$word"
      validate_name_token "$new_word"
      trace_exec edit-synonym "$word" --word "$new_word"
      ;;
    edit-target)
      word=${3-}
      new_target=${4-}
      [ -n "$word" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym edit-target requires WORD" >&2
        exit 2
      }
      [ -n "$new_target" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym edit-target requires TARGET" >&2
        exit 2
      }
      validate_name_token "$word"
      trace_exec edit-synonym "$word" --spell "$new_target"
      ;;
    delete)
      word=${3-}
      [ -n "$word" ] || {
        printf '%s\n' "wizardry-desktop-backend: synonym delete requires WORD" >&2
        exit 2
      }
      validate_name_token "$word"
      trace_exec delete-synonym "$word"
      ;;
    reset-defaults)
      trace_exec reset-default-synonyms
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown synonym action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_system() {
  action=${2-}
  case "$action" in
    update-all)
      trace_exec update-all -v
      ;;
    update-wizardry)
      trace_exec update-wizardry
      ;;
    verify-posix)
      trace_exec verify-posix
      ;;
    test-magic)
      trace_exec test-magic
      ;;
    profile-tests)
      trace_exec profile-tests
      ;;
    nixos-rebuild)
      trace_exec sudo nixos-rebuild switch
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown system action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_network() {
  action=${2-}
  case "$action" in
    static-ip)
      trace_exec configure-static-ip
      ;;
    dhcp)
      trace_exec configure-dhcp
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown network action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_service() {
  action=${2-}
  unit=${3-}
  case "$action" in
    start|stop|restart|enable|disable|status|installed|remove)
      [ -n "$unit" ] || {
        printf '%s\n' "wizardry-desktop-backend: service $action requires UNIT" >&2
        exit 2
      }
      validate_service_name "$unit"
      case "$action" in
        start) trace_exec start-service "$unit" ;;
        stop) trace_exec stop-service "$unit" ;;
        restart) trace_exec restart-service "$unit" ;;
        enable) trace_exec enable-service "$unit" ;;
        disable) trace_exec disable-service "$unit" ;;
        status) trace_exec service-status "$unit" ;;
        installed) trace_exec is-service-installed "$unit" ;;
        remove) trace_exec remove-service "$unit" ;;
      esac
      ;;
    install-template)
      trace_exec install-service-template
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown service action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_user() {
  action=${2-}
  user=${3-}
  group=${4-}
  case "$action" in
    list-users)
      trace_exec cut -d: -f1 /etc/passwd
      ;;
    list-groups)
      trace_exec cut -d: -f1 /etc/group
      ;;
    my-groups)
      trace_exec groups
      ;;
    user-groups)
      [ -n "$user" ] || {
        printf '%s\n' "wizardry-desktop-backend: user-groups requires USER" >&2
        exit 2
      }
      validate_name_token "$user"
      trace_exec groups "$user"
      ;;
    group-members)
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: group-members requires GROUP" >&2
        exit 2
      }
      validate_name_token "$group"
      trace_exec getent group "$group"
      ;;
    create-group)
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: create-group requires GROUP" >&2
        exit 2
      }
      validate_name_token "$group"
      trace_exec sudo groupadd "$group"
      ;;
    delete-group)
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: delete-group requires GROUP" >&2
        exit 2
      }
      validate_name_token "$group"
      trace_exec sudo groupdel "$group"
      ;;
    join-group)
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: join-group requires GROUP" >&2
        exit 2
      }
      validate_name_token "$group"
      trace_exec sudo usermod -a -G "$group" "$USER"
      ;;
    leave-group)
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: leave-group requires GROUP" >&2
        exit 2
      }
      validate_name_token "$group"
      trace_exec sudo gpasswd -d "$USER" "$group"
      ;;
    add-user-to-group)
      [ -n "$user" ] || {
        printf '%s\n' "wizardry-desktop-backend: add-user-to-group requires USER" >&2
        exit 2
      }
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: add-user-to-group requires GROUP" >&2
        exit 2
      }
      validate_name_token "$user"
      validate_name_token "$group"
      trace_exec sudo usermod -a -G "$group" "$user"
      ;;
    remove-user-from-group)
      [ -n "$user" ] || {
        printf '%s\n' "wizardry-desktop-backend: remove-user-from-group requires USER" >&2
        exit 2
      }
      [ -n "$group" ] || {
        printf '%s\n' "wizardry-desktop-backend: remove-user-from-group requires GROUP" >&2
        exit 2
      }
      validate_name_token "$user"
      validate_name_token "$group"
      trace_exec sudo gpasswd -d "$user" "$group"
      ;;
    create-user)
      [ -n "$user" ] || {
        printf '%s\n' "wizardry-desktop-backend: create-user requires USER" >&2
        exit 2
      }
      validate_name_token "$user"
      trace_exec sudo useradd "$user"
      ;;
    delete-user)
      [ -n "$user" ] || {
        printf '%s\n' "wizardry-desktop-backend: delete-user requires USER" >&2
        exit 2
      }
      validate_name_token "$user"
      trace_exec sudo userdel "$user"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown user action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_power() {
  action=${2-}
  case "$action" in
    restart)
      trace_exec sudo shutdown -r +0
      ;;
    shutdown)
      trace_exec sudo shutdown -h +0
      ;;
    logout)
      if command -v loginctl >/dev/null 2>&1; then
        trace_exec loginctl terminate-user "$USER"
      else
        trace_exec pkill -TERM -u "$USER"
      fi
      ;;
    sleep)
      case "$(uname -s 2>/dev/null || printf '')" in
        Darwin)
          trace_exec sudo pmset sleepnow
          ;;
        *)
          trace_exec sudo systemctl suspend
          ;;
      esac
      ;;
    hibernate)
      trace_exec sudo systemctl hibernate
      ;;
    force-restart)
      trace_exec sudo reboot -f
      ;;
    force-shutdown)
      trace_exec sudo poweroff -f
      ;;
    force-logout)
      trace_exec pkill -KILL -u "$USER"
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown power action: $action" >&2
      exit 2
      ;;
  esac
}

mud_set_player() {
  player=${1-}
  validate_player_name "$player"
  [ -f "$HOME/.ssh/$player.pub" ] || {
    printf '%s\n' "wizardry-desktop-backend: player key not found: $player" >&2
    exit 1
  }
  config_file=$(mud_config_file)
  [ -f "$config_file" ] || : >"$config_file"
  write_key_value_file "$config_file" player "$player"
  printf 'player=%s\n' "$player"
  printf 'config=%s\n' "$config_file"
}

mud_jump_target() {
  marker=${1-}
  current=$(mud_room_path)
  if [ -d "$current" ]; then
    cd "$current"
  else
    cd "$HOME"
  fi
  . jump-to-marker "$marker" >/dev/null 2>&1 || return 1
  pwd -P
}

cmd_mud() {
  action=${2-}
  case "$action" in
    look)
      target=${3-}
      if [ -z "$target" ]; then
        target=$(mud_room_path)
      fi
      trace_exec look "$target"
      ;;
    stats)
      target=${3-}
      if [ -n "$target" ]; then
        trace_exec stats "$target"
      else
        trace_exec stats
      fi
      ;;
    say)
      message=${3-}
      [ -n "$message" ] || {
        printf '%s\n' "wizardry-desktop-backend: mud say requires MESSAGE" >&2
        exit 2
      }
      trace_in_dir_exec "$(mud_room_path)" say "$message"
      ;;
    set-room)
      target=${3-}
      [ -n "$target" ] || {
        printf '%s\n' "wizardry-desktop-backend: mud set-room requires PATH" >&2
        exit 2
      }
      [ -d "$target" ] || {
        printf '%s\n' "wizardry-desktop-backend: room path not found: $target" >&2
        exit 1
      }
      prefs=$(ui_prefs_file)
      [ -f "$prefs" ] || : >"$prefs"
      write_key_value_file "$prefs" mud_room_path "$target"
      printf 'mud_room_path=%s\n' "$target"
      ;;
    goto-home)
      prefs=$(ui_prefs_file)
      [ -f "$prefs" ] || : >"$prefs"
      write_key_value_file "$prefs" mud_room_path "$HOME"
      printf 'mud_room_path=%s\n' "$HOME"
      ;;
    goto-portal)
      target=$(detect_portal_location)
      prefs=$(ui_prefs_file)
      [ -f "$prefs" ] || : >"$prefs"
      write_key_value_file "$prefs" mud_room_path "$target"
      printf 'mud_room_path=%s\n' "$target"
      ;;
    goto-marker)
      marker=${3-1}
      target=$(mud_jump_target "$marker") || {
        printf '%s\n' "wizardry-desktop-backend: unable to resolve marker $marker" >&2
        exit 1
      }
      prefs=$(ui_prefs_file)
      [ -f "$prefs" ] || : >"$prefs"
      write_key_value_file "$prefs" mud_room_path "$target"
      printf 'mud_room_path=%s\n' "$target"
      ;;
    set-player)
      mud_set_player "${3-}"
      ;;
    new-player)
      player=${3-}
      [ -n "$player" ] || {
        printf '%s\n' "wizardry-desktop-backend: mud new-player requires PLAYER" >&2
        exit 2
      }
      validate_player_name "$player"
      key_path=$HOME/.ssh/$player
      [ ! -f "$key_path" ] || {
        printf '%s\n' "wizardry-desktop-backend: player key already exists: $key_path" >&2
        exit 1
      }
      mkdir -p "$HOME/.ssh"
      trace_exec ssh-keygen -t ed25519 -f "$key_path" -N ""
      mud_set_player "$player"
      ;;
    player-status)
      trace_exec player-status
      ;;
    list-players)
      trace_exec list-players
      ;;
    open-portal)
      player=${3-}
      server=${4-}
      remote_path=${5-}
      local_mount=${6-}
      use_tor=${7-0}
      [ -n "$player" ] || {
        printf '%s\n' "wizardry-desktop-backend: mud open-portal requires PLAYER" >&2
        exit 2
      }
      [ -n "$server" ] || {
        printf '%s\n' "wizardry-desktop-backend: mud open-portal requires SERVER" >&2
        exit 2
      }
      [ -n "$remote_path" ] || remote_path='~'
      spec=$player@$server:$remote_path
      if [ -n "$local_mount" ]; then
        if [ "$use_tor" = "1" ]; then
          trace_exec open-portal --tor "$spec" "$local_mount"
        else
          trace_exec open-portal "$spec" "$local_mount"
        fi
      else
        if [ "$use_tor" = "1" ]; then
          trace_exec open-portal --tor "$spec"
        else
          trace_exec open-portal "$spec"
        fi
      fi
      ;;
    close-portal)
      mount_point=${3-}
      if [ -n "$mount_point" ]; then
        trace_exec close-portal "$mount_point"
      else
        trace_exec close-portal
      fi
      ;;
    toggle)
      feature=${3-}
      case "$feature" in
        parse)
          trace_exec toggle-parse
          ;;
        mud-menu)
          trace_exec toggle-mud-menu
          ;;
        cd-look)
          trace_exec toggle-cd
          ;;
        cd-listen)
          trace_exec toggle-listen
          ;;
        avatar)
          trace_exec toggle-avatar
          ;;
        touch-hook)
          trace_exec toggle-touch-hook
          ;;
        tor)
          if [ "$(printf '%s\n' "$(detect_tor_status)" | awk -F '\t' '{ print $1 }')" = "1" ]; then
            trace_exec remove-tor-hidden-service -y
          else
            trace_exec setup-tor -y
          fi
          ;;
        *)
          printf '%s\n' "wizardry-desktop-backend: unknown MUD toggle: $feature" >&2
          exit 2
          ;;
      esac
      ;;
    toggle-all)
      mode=${3-}
      case "$mode" in
        enable|disable)
          trace_exec toggle-all-mud "--$mode"
          ;;
        *)
          printf '%s\n' "wizardry-desktop-backend: mud toggle-all requires enable|disable" >&2
          exit 2
          ;;
      esac
      ;;
    *)
      printf '%s\n' "wizardry-desktop-backend: unknown mud action: $action" >&2
      exit 2
      ;;
  esac
}

cmd_arcana() {
  action=${2-}
  name=${3-}
  [ "$action" = "run" ] || {
    printf '%s\n' "wizardry-desktop-backend: unknown arcana action: $action" >&2
    exit 2
  }
  [ -n "$name" ] || {
    printf '%s\n' "wizardry-desktop-backend: arcana run requires NAME" >&2
    exit 2
  }
  validate_name_token "$name"
  if [ "$name" = "mud" ] && [ -n "$(arcana_menu_command "$name")" ]; then
    command_path=$(arcana_menu_command "$name")
    trace_line sh -c ". \$1" sh "$command_path"
    sh -c '. "$1"' sh "$command_path"
    exit 0
  fi
  command_path=$(arcana_run_command "$name")
  [ -n "$command_path" ] || {
    printf '%s\n' "wizardry-desktop-backend: no runnable arcana action found for $name" >&2
    exit 1
  }
  trace_exec "$command_path"
}

cmd=${1-}
[ -n "$cmd" ] || {
  printf '%s\n' "wizardry-desktop-backend: command required" >&2
  exit 2
}

case "$cmd" in
  doctor) cmd_doctor "$@" ;;
  list-themes) cmd_list_themes "$@" ;;
  get-ui-prefs) cmd_get_ui_prefs "$@" ;;
  set-ui-pref) cmd_set_ui_pref "$@" ;;
  list-categories) cmd_list_categories "$@" ;;
  list-custom-root-spells) cmd_list_custom_root_spells "$@" ;;
  list-spells) cmd_list_spells "$@" ;;
  list-arcana) cmd_list_arcana "$@" ;;
  list-cast) cmd_list_cast "$@" ;;
  list-spell-activity) cmd_list_spell_activity "$@" ;;
  list-synonyms) cmd_list_synonyms "$@" ;;
  list-players) cmd_list_players "$@" ;;
  mud-status) cmd_mud_status "$@" ;;
  run-spell) cmd_run_spell "$@" ;;
  spell-help) cmd_spell_help "$@" ;;
  memorize) cmd_memorize "$@" ;;
  forget) cmd_forget "$@" ;;
  run-cast) cmd_run_cast "$@" ;;
  create-category) cmd_create_category "$@" ;;
  scribe-spell) cmd_scribe_spell "$@" ;;
  synonym) cmd_synonym "$@" ;;
  system) cmd_system "$@" ;;
  network) cmd_network "$@" ;;
  service) cmd_service "$@" ;;
  user) cmd_user "$@" ;;
  power) cmd_power "$@" ;;
  mud) cmd_mud "$@" ;;
  arcana) cmd_arcana "$@" ;;
  *)
    printf '%s\n' "wizardry-desktop-backend: unknown command '$cmd'" >&2
    exit 2
    ;;
esac
