#!/bin/sh

# Backend actions for the Priorities desktop app.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: priorities-backend.sh ACTION [ARGS...]

Actions:
  list-themes           List Wizardry theme names from global theme directory
  get-ui-prefs          Print UI preferences as key=value lines
  set-ui-pref KEY VALUE Persist a UI preference key=value
  list [DIR]            List prioritized items in DIR (default: current dir)
  copy-priorities [DIR] [--expanded]
                        Copy priorities as markdown checklist to clipboard
  prioritize PATH       Promote PATH using the prioritize spell
  prioritize-quick PATH Promote PATH and print: echelon<tab>priority<tab>checked
  check-toggle PATH     Toggle checked state using check/uncheck spells
  make-project PATH     Convert PATH file to project folder
  make-project-fast PATH
                        Convert PATH file to project folder and emit parent listing
  rename PATH NAME      Rename PATH to NAME in same directory
  add DIR NAME          Add NAME in DIR and prioritize it
  remove PATH           Move PATH to system trash
  descendant-count PATH Count nested items beneath PATH
  open-dir [DIR]        Open DIR in the system file browser
  pick-dir              Open a native folder picker (prints selected path)
  parent DIR            Print parent directory path
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
  [ -d "$root/apps" ] || return 1
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

resolve_wizardry_root() {
  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && is_workspace_root "$WIZARDRY_APPS_ROOT"; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT"
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

theme_names_from_dir() {
  dir=${1-}
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.css' 2>/dev/null \
    | awk -F/ '{ print $NF }' \
    | sed 's/\.css$//' \
    | awk '/^[a-z0-9_-]+$/' \
    | sort -u
}

emit_theme_names() {
  app_theme_dir="$SCRIPT_DIR/../themes"
  theme_root=''
  root=$(resolve_wizardry_root 2>/dev/null || true)
  if [ -n "$root" ] && [ -d "$root/web/.themes" ]; then
    theme_root="$root/web/.themes"
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

priorities_ui_config_file() {
  base="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/priorities"
  mkdir -p "$base"
  printf '%s\n' "$base/config"
}

validate_ui_pref_key() {
  key=${1-}
  case "$key" in
    [a-z0-9][a-z0-9._-]*)
      ;;
    *)
      printf '%s\n' "priorities-backend: invalid UI pref key: $key" >&2
      exit 2
      ;;
  esac
}

sanitize_ui_pref_value() {
  value=${1-}
  printf '%s' "$value" | tr '\r\n' ' '
}

write_key_value_file() {
  file=$1
  key=$2
  value=$3

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/priorities-kv.XXXXXX")
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

expand_home_path() {
  path=${1-}
  case "$path" in
    "~")
      if [ -n "${HOME-}" ]; then
        printf '%s\n' "$HOME"
      else
        printf '%s\n' "$path"
      fi
      ;;
    "~/"*)
      if [ -n "${HOME-}" ]; then
        printf '%s/%s\n' "$HOME" "${path#\~/}"
      else
        printf '%s\n' "$path"
      fi
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

action=${1-}
if [ -z "$action" ]; then
  printf '%s\n' "priorities-backend: action required" >&2
  exit 2
fi
shift

ATTR_BACKEND=spell
case "${PRIORITIES_ATTR_BACKEND-}" in
  xattr|getfattr|attr|spell)
    ATTR_BACKEND=${PRIORITIES_ATTR_BACKEND}
    ;;
  *)
    if command -v xattr >/dev/null 2>&1; then
      ATTR_BACKEND=xattr
    elif command -v getfattr >/dev/null 2>&1 && command -v setfattr >/dev/null 2>&1; then
      ATTR_BACKEND=getfattr
    elif command -v attr >/dev/null 2>&1; then
      ATTR_BACKEND=attr
    fi
    ;;
esac

unquote_attr_value() {
  value=$1
  case "$value" in
    \"*\")
      value=${value#\"}
      value=${value%\"}
      ;;
  esac
  printf '%s' "$value"
}

set_user_attr() {
  file=$1
  key=$2
  value=$3
  case "$ATTR_BACKEND" in
    xattr)
      xattr -w "user.$key" "$value" "$file" >/dev/null 2>&1
      ;;
    getfattr)
      setfattr -n "user.$key" -v "$value" "$file" >/dev/null 2>&1
      ;;
    attr)
      attr -s "user.$key" -V "$value" "$file" >/dev/null 2>&1
      ;;
    *)
      enchant "$file" "$key" "$value" >/dev/null
      ;;
  esac
}

unset_user_attr() {
  file=$1
  key=$2
  case "$ATTR_BACKEND" in
    xattr)
      xattr -d "user.$key" "$file" >/dev/null 2>&1 || true
      ;;
    getfattr)
      setfattr -x "user.$key" "$file" >/dev/null 2>&1 || true
      ;;
    attr)
      attr -r "user.$key" "$file" >/dev/null 2>&1 || true
      ;;
    *)
      disenchant "$file" "user.$key" >/dev/null 2>&1 || true
      ;;
  esac
}

child_has_echelon() {
  child=$1
  case "$ATTR_BACKEND" in
    xattr)
      child_echelon=$(xattr -p user.echelon "$child" 2>/dev/null || true)
      ;;
    getfattr)
      child_echelon=$(getfattr -n user.echelon --only-values "$child" 2>/dev/null || true)
      ;;
    attr)
      child_echelon=$(attr -g user.echelon "$child" 2>/dev/null | sed '1d' || true)
      ;;
    *)
      child_echelon=$(read-magic "$child" echelon 2>/dev/null || true)
      ;;
  esac
  case "$child_echelon" in
    *Error*|''|*[!0-9]*) return 1 ;;
  esac
  [ "$child_echelon" -ge 1 ]
}

# Populate global attrs for a file:
# attr_echelon attr_priority attr_checked attr_upvotes
read_item_attrs() {
  file=$1
  attr_echelon=''
  attr_priority=''
  attr_checked=''
  attr_upvotes=''

  case "$ATTR_BACKEND" in
    xattr)
      dump=$(xattr -l "$file" 2>/dev/null || true)
      if [ -n "$dump" ]; then
        old_ifs=$IFS
        IFS='
'
        for line in $dump; do
          case "$line" in
            user.echelon:*)
              val=${line#user.echelon:}
              attr_echelon=${val# }
              ;;
            user.priority:*)
              val=${line#user.priority:}
              attr_priority=${val# }
              ;;
            user.checked:*)
              val=${line#user.checked:}
              attr_checked=${val# }
              ;;
            user.upvotes:*)
              val=${line#user.upvotes:}
              attr_upvotes=${val# }
              ;;
          esac
        done
        IFS=$old_ifs
      fi
      return 0
      ;;
    getfattr)
      dump=$(getfattr -d --absolute-names "$file" 2>/dev/null || true)
      if [ -n "$dump" ]; then
        old_ifs=$IFS
        IFS='
'
        for line in $dump; do
          case "$line" in
            user.echelon=*)
              attr_echelon=$(unquote_attr_value "${line#user.echelon=}")
              ;;
            user.priority=*)
              attr_priority=$(unquote_attr_value "${line#user.priority=}")
              ;;
            user.checked=*)
              attr_checked=$(unquote_attr_value "${line#user.checked=}")
              ;;
            user.upvotes=*)
              attr_upvotes=$(unquote_attr_value "${line#user.upvotes=}")
              ;;
          esac
        done
        IFS=$old_ifs
      fi
      return 0
      ;;
    attr)
      attr_echelon=$(attr -g user.echelon "$file" 2>/dev/null | sed '1d' || true)
      attr_priority=$(attr -g user.priority "$file" 2>/dev/null | sed '1d' || true)
      attr_checked=$(attr -g user.checked "$file" 2>/dev/null | sed '1d' || true)
      attr_upvotes=$(attr -g user.upvotes "$file" 2>/dev/null | sed '1d' || true)
      return 0
      ;;
  esac

  attrs=$(get-attribute-batch "$file" echelon priority checked upvotes 2>/dev/null || true)
  for pair in $attrs; do
    case "$pair" in
      echelon=*) attr_echelon=${pair#echelon=} ;;
      priority=*) attr_priority=${pair#priority=} ;;
      checked=*) attr_checked=${pair#checked=} ;;
      upvotes=*) attr_upvotes=${pair#upvotes=} ;;
    esac
  done
}

# Build top-level summary from a single recursive xattr pass.
# Output rows:
#   path \t echelon \t priority \t checked \t upvotes \t has_subpriorities
collect_top_summary_xattr() {
  dir=$1
  out_file=$2
  xattr -lr "$dir" 2>/dev/null | awk -v root="$dir" '
    function is_num(v) { return v ~ /^[0-9]+$/ }
    {
      sep1 = index($0, ": ")
      if (sep1 == 0) {
        next
      }
      path = substr($0, 1, sep1 - 1)
      rest = substr($0, sep1 + 2)
      sep2 = index(rest, ": ")
      if (sep2 == 0) {
        next
      }
      key = substr(rest, 1, sep2 - 1)
      val = substr(rest, sep2 + 2)
      prefix = root "/"
      if (index(path, prefix) != 1) {
        next
      }
      rel = substr(path, length(prefix) + 1)
      if (rel == "") {
        next
      }
      split(rel, parts, "/")
      top = parts[1]
      if (top == "") {
        next
      }
      top_path = prefix top
      seen[top_path] = 1

      if (index(rel, "/") == 0) {
        if (key == "user.echelon") {
          echelon[top_path] = val
        } else if (key == "user.priority") {
          priority[top_path] = val
        } else if (key == "user.checked") {
          checked[top_path] = val
        } else if (key == "user.upvotes") {
          upvotes[top_path] = val
        }
      } else if (key == "user.echelon" && is_num(val) && (val + 0) >= 1) {
        has_sub[top_path] = 1
      }
    }
    END {
      for (p in seen) {
        e = (p in echelon) ? echelon[p] : ""
        pr = (p in priority) ? priority[p] : ""
        ch = (p in checked) ? checked[p] : ""
        up = (p in upvotes) ? upvotes[p] : ""
        hs = (p in has_sub) ? 1 : 0
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", p, e, pr, ch, up, hs
      }
    }
  ' > "$out_file"
}

# Build prioritized top-level rows from keyed xattr batch queries.
# Output rows:
#   path \t echelon \t priority \t checked \t upvotes \t has_subpriorities
collect_prioritized_rows_xattr() {
  dir=$1
  out_file=$2

  # shellcheck disable=SC2039
  set -- "$dir"/*
  [ -e "${1-}" ] || return 0
  if [ "$#" -eq 1 ]; then
    single_path=$1
    read_item_attrs "$single_path"
    single_echelon=$attr_echelon
    single_priority=$attr_priority
    single_checked=$attr_checked
    single_upvotes=$attr_upvotes
    case "$single_echelon" in
      ''|*Error*|*[!0-9]*) return 0 ;;
    esac
    case "$single_priority" in
      ''|*Error*|*[!0-9]*) single_priority=0 ;;
    esac
    case "$single_checked" in
      ''|*Error*|*[!0-9]*) single_checked=0 ;;
    esac
    case "$single_upvotes" in
      ''|*Error*|*[!0-9]*) single_upvotes=0 ;;
    esac
    has_sub=0
    if [ -d "$single_path" ]; then
      for child in "$single_path"/*; do
        [ -e "$child" ] || continue
        if child_has_echelon "$child"; then
          has_sub=1
          break
        fi
      done
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$single_path" \
      "$single_echelon" \
      "$single_priority" \
      "$single_checked" \
      "$single_upvotes" \
      "$has_sub" > "$out_file"
    return 0
  fi

  tmp_e=$(mktemp "${TMPDIR:-/tmp}/priorities-e.XXXXXX")
  tmp_p=$(mktemp "${TMPDIR:-/tmp}/priorities-p.XXXXXX")
  tmp_c=$(mktemp "${TMPDIR:-/tmp}/priorities-c.XXXXXX")
  tmp_u=$(mktemp "${TMPDIR:-/tmp}/priorities-u.XXXXXX")
  tmp_ep=$(mktemp "${TMPDIR:-/tmp}/priorities-ep.XXXXXX")
  tmp_epc=$(mktemp "${TMPDIR:-/tmp}/priorities-epc.XXXXXX")

  xattr -p user.echelon "$@" 2>/dev/null | awk '
    {
      sep = index($0, ": ")
      if (sep == 0) next
      path = substr($0, 1, sep - 1)
      val = substr($0, sep + 2)
      if (val ~ /^[0-9]+$/) {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_e"

  if [ ! -s "$tmp_e" ]; then
    rm -f "$tmp_e" "$tmp_p" "$tmp_c" "$tmp_u" "$tmp_ep" "$tmp_epc"
    return 0
  fi

  xattr -p user.priority "$@" 2>/dev/null | awk '
    {
      sep = index($0, ": ")
      if (sep == 0) next
      path = substr($0, 1, sep - 1)
      val = substr($0, sep + 2)
      if (val ~ /^[0-9]+$/) {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_p"

  xattr -p user.checked "$@" 2>/dev/null | awk '
    {
      sep = index($0, ": ")
      if (sep == 0) next
      path = substr($0, 1, sep - 1)
      val = substr($0, sep + 2)
      if (val ~ /^[0-9]+$/) {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_c"

  xattr -p user.upvotes "$@" 2>/dev/null | awk '
    {
      sep = index($0, ": ")
      if (sep == 0) next
      path = substr($0, 1, sep - 1)
      val = substr($0, sep + 2)
      if (val ~ /^[0-9]+$/) {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_u"

  tab=$(printf '\t')
  join -t "$tab" -a 1 -e 0 -o '1.1,1.2,2.2' "$tmp_e" "$tmp_p" > "$tmp_ep"
  join -t "$tab" -a 1 -e 0 -o '1.1,1.2,1.3,2.2' "$tmp_ep" "$tmp_c" > "$tmp_epc"
  join -t "$tab" -a 1 -e 0 -o '1.1,1.2,1.3,1.4,2.2' "$tmp_epc" "$tmp_u" | while IFS="$tab" read -r path echelon priority checked upvotes; do
    [ -n "$path" ] || continue
    has_sub=0
    if [ -d "$path" ]; then
      for child in "$path"/*; do
        [ -e "$child" ] || continue
        if child_has_echelon "$child"; then
          has_sub=1
          break
        fi
      done
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$path" "$echelon" "$priority" "$checked" "$upvotes" "$has_sub"
  done > "$out_file"

  rm -f "$tmp_e" "$tmp_p" "$tmp_c" "$tmp_u" "$tmp_ep" "$tmp_epc"
}

collect_prioritized_rows_getfattr() {
  dir=$1
  out_file=$2

  # shellcheck disable=SC2039
  set -- "$dir"/*
  [ -e "${1-}" ] || return 0
  if [ "$#" -eq 1 ]; then
    single_path=$1
    read_item_attrs "$single_path"
    single_echelon=$attr_echelon
    single_priority=$attr_priority
    single_checked=$attr_checked
    single_upvotes=$attr_upvotes
    case "$single_echelon" in
      ''|*Error*|*[!0-9]*) return 0 ;;
    esac
    case "$single_priority" in
      ''|*Error*|*[!0-9]*) single_priority=0 ;;
    esac
    case "$single_checked" in
      ''|*Error*|*[!0-9]*) single_checked=0 ;;
    esac
    case "$single_upvotes" in
      ''|*Error*|*[!0-9]*) single_upvotes=0 ;;
    esac
    has_sub=0
    if [ -d "$single_path" ]; then
      for child in "$single_path"/*; do
        [ -e "$child" ] || continue
        if child_has_echelon "$child"; then
          has_sub=1
          break
        fi
      done
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$single_path" \
      "$single_echelon" \
      "$single_priority" \
      "$single_checked" \
      "$single_upvotes" \
      "$has_sub" > "$out_file"
    return 0
  fi

  tmp_e=$(mktemp "${TMPDIR:-/tmp}/priorities-e.XXXXXX")
  tmp_p=$(mktemp "${TMPDIR:-/tmp}/priorities-p.XXXXXX")
  tmp_c=$(mktemp "${TMPDIR:-/tmp}/priorities-c.XXXXXX")
  tmp_u=$(mktemp "${TMPDIR:-/tmp}/priorities-u.XXXXXX")
  tmp_ep=$(mktemp "${TMPDIR:-/tmp}/priorities-ep.XXXXXX")
  tmp_epc=$(mktemp "${TMPDIR:-/tmp}/priorities-epc.XXXXXX")

  getfattr -n user.echelon --absolute-names "$@" 2>/dev/null | awk '
    /^# file: / { path = substr($0, 9); next }
    /^user\.echelon=/ {
      val = $0
      sub(/^user\.echelon=/, "", val)
      gsub(/^"|"$/, "", val)
      if (val ~ /^[0-9]+$/ && path != "") {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_e"

  if [ ! -s "$tmp_e" ]; then
    rm -f "$tmp_e" "$tmp_p" "$tmp_c" "$tmp_u" "$tmp_ep" "$tmp_epc"
    return 0
  fi

  getfattr -n user.priority --absolute-names "$@" 2>/dev/null | awk '
    /^# file: / { path = substr($0, 9); next }
    /^user\.priority=/ {
      val = $0
      sub(/^user\.priority=/, "", val)
      gsub(/^"|"$/, "", val)
      if (val ~ /^[0-9]+$/ && path != "") {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_p"

  getfattr -n user.checked --absolute-names "$@" 2>/dev/null | awk '
    /^# file: / { path = substr($0, 9); next }
    /^user\.checked=/ {
      val = $0
      sub(/^user\.checked=/, "", val)
      gsub(/^"|"$/, "", val)
      if (val ~ /^[0-9]+$/ && path != "") {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_c"

  getfattr -n user.upvotes --absolute-names "$@" 2>/dev/null | awk '
    /^# file: / { path = substr($0, 9); next }
    /^user\.upvotes=/ {
      val = $0
      sub(/^user\.upvotes=/, "", val)
      gsub(/^"|"$/, "", val)
      if (val ~ /^[0-9]+$/ && path != "") {
        printf "%s\t%s\n", path, val
      }
    }
  ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 > "$tmp_u"

  tab=$(printf '\t')
  join -t "$tab" -a 1 -e 0 -o '1.1,1.2,2.2' "$tmp_e" "$tmp_p" > "$tmp_ep"
  join -t "$tab" -a 1 -e 0 -o '1.1,1.2,1.3,2.2' "$tmp_ep" "$tmp_c" > "$tmp_epc"
  join -t "$tab" -a 1 -e 0 -o '1.1,1.2,1.3,1.4,2.2' "$tmp_epc" "$tmp_u" | while IFS="$tab" read -r path echelon priority checked upvotes; do
    [ -n "$path" ] || continue
    has_sub=0
    if [ -d "$path" ]; then
      for child in "$path"/*; do
        [ -e "$child" ] || continue
        if child_has_echelon "$child"; then
          has_sub=1
          break
        fi
      done
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$path" "$echelon" "$priority" "$checked" "$upvotes" "$has_sub"
  done > "$out_file"

  rm -f "$tmp_e" "$tmp_p" "$tmp_c" "$tmp_u" "$tmp_ep" "$tmp_epc"
}

collect_prioritized_rows_fast() {
  dir=$1
  out_file=$2
  case "$ATTR_BACKEND" in
    xattr) collect_prioritized_rows_xattr "$dir" "$out_file" ;;
    getfattr) collect_prioritized_rows_getfattr "$dir" "$out_file" ;;
    *) return 1 ;;
  esac
}

compute_highest_priority_xattr() {
  directory=$1

  # shellcheck disable=SC2039
  set -- "$directory"/*
  if [ ! -e "${1-}" ]; then
    printf '%s\t%s\n' "0" "0"
    return 0
  fi

  xattr -l "$@" 2>/dev/null | awk '
    function is_num(v) { return v ~ /^[0-9]+$/ }
    {
      sep1 = index($0, ": ")
      if (sep1 == 0) next
      path = substr($0, 1, sep1 - 1)
      rest = substr($0, sep1 + 2)
      sep2 = index(rest, ": ")
      if (sep2 == 0) next
      key = substr(rest, 1, sep2 - 1)
      val = substr(rest, sep2 + 2)
      if (key == "user.echelon" && is_num(val)) {
        e[path] = val + 0
        seen[path] = 1
      } else if (key == "user.priority" && is_num(val)) {
        p[path] = val + 0
        seen[path] = 1
      }
    }
    END {
      he = 0
      hp = 0
      for (path in seen) {
        if (!(path in e)) continue
        fe = e[path] + 0
        fp = (path in p) ? (p[path] + 0) : 0
        if (fe > he) {
          he = fe
          hp = fp
        } else if (fe == he && fp > hp) {
          hp = fp
        }
      }
      printf "%d\t%d\n", he, hp
    }
  '
}

prepare_target_for_attrs() {
  target=${1-}
  [ -n "$target" ] || return 1

  case "$ATTR_BACKEND" in
    spell)
      if ! hashchant "$target" >/dev/null 2>&1; then
        printf '%s\n' "priorities-backend: hashchant failed: $target" >&2
        return 1
      fi
      ;;
    *)
      # Non-spell backends read/write native attrs; hashchant is best-effort.
      hashchant "$target" >/dev/null 2>&1 || true
      ;;
  esac
  return 0
}

prioritize_impl() {
  target=$1
  auto_create=${2:-0}
  target_existed=0
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for prioritize-fast" >&2
    return 2
  fi

  if [ -e "$target" ]; then
    target_existed=1
  else
    if [ "$auto_create" = "1" ]; then
      touch "$target"
    else
      printf '%s\n' "priorities-backend: file not found: $target" >&2
      return 1
    fi
  fi

  prepare_target_for_attrs "$target" || return 1

  directory=$(dirname "$target")
  if [ "$directory" = "." ]; then
    directory=$(pwd -P)
  fi

  read_item_attrs "$target"
  current_echelon=0
  checked_value=0

  current_echelon=${attr_echelon}
  checked_value=${attr_checked}

  case "$current_echelon" in
    *Error*|''|*[!0-9]*) current_echelon=0 ;;
  esac
  case "$checked_value" in
    *Error*|''|*[!0-9]*) checked_value=0 ;;
  esac

  if [ "$checked_value" = "1" ]; then
    set_user_attr "$target" checked 0
  fi

  highest_echelon=0
  highest_priority_in_echelon=0
  case "$ATTR_BACKEND" in
    xattr)
      summary=$(compute_highest_priority_xattr "$directory")
      tab=$(printf '\t')
      highest_echelon=0
      highest_priority_in_echelon=0
      IFS="$tab" read -r highest_echelon highest_priority_in_echelon <<EOF
$summary
EOF
      case "$highest_echelon" in
        *Error*|''|*[!0-9]*) highest_echelon=0 ;;
      esac
      case "$highest_priority_in_echelon" in
        *Error*|''|*[!0-9]*) highest_priority_in_echelon=0 ;;
      esac
      ;;
    *)
      for f in "$directory"/*; do
        [ -e "$f" ] || continue
        read_item_attrs "$f"
        file_echelon=$attr_echelon
        file_priority=$attr_priority
        case "$file_echelon" in
          *Error*|''|*[!0-9]*) continue ;;
        esac
        if [ "$file_echelon" -gt "$highest_echelon" ]; then
          highest_echelon=$file_echelon
          highest_priority_in_echelon=0
        fi
        if [ "$file_echelon" -eq "$highest_echelon" ]; then
          case "$file_priority" in
            *Error*|''|*[!0-9]*) file_priority=0 ;;
          esac
          if [ "$file_priority" -gt "$highest_priority_in_echelon" ]; then
            highest_priority_in_echelon=$file_priority
          fi
        fi
      done
      ;;
  esac

  if [ "$highest_echelon" -eq 0 ]; then
    set_user_attr "$target" echelon 1
    set_user_attr "$target" priority 1
    return 0
  fi

  if [ "$current_echelon" -eq "$highest_echelon" ] && [ "$current_echelon" -gt 0 ]; then
    if [ "$auto_create" = "1" ] && [ "$target_existed" -eq 1 ]; then
      new_priority=$((highest_priority_in_echelon + 1))
      set_user_attr "$target" echelon "$highest_echelon"
      set_user_attr "$target" priority "$new_priority"
      return 0
    fi
    new_echelon=$((highest_echelon + 1))
    set_user_attr "$target" echelon "$new_echelon"
    set_user_attr "$target" priority 1
    return 0
  fi

  new_priority=$((highest_priority_in_echelon + 1))
  set_user_attr "$target" echelon "$highest_echelon"
  set_user_attr "$target" priority "$new_priority"
}

prioritize_quick_impl() {
  target=$1
  auto_create=${2:-0}
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for prioritize-quick" >&2
    return 2
  fi

  prioritize_impl "$target" "$auto_create"
  read_item_attrs "$target"

  quick_echelon=$attr_echelon
  quick_priority=$attr_priority
  quick_checked=$attr_checked

  case "$quick_echelon" in
    *Error*|''|*[!0-9]*) quick_echelon=0 ;;
  esac
  case "$quick_priority" in
    *Error*|''|*[!0-9]*) quick_priority=0 ;;
  esac
  case "$quick_checked" in
    *Error*|''|*[!0-9]*) quick_checked=0 ;;
  esac

  printf '%s\t%s\t%s\n' "$quick_echelon" "$quick_priority" "$quick_checked"
}

check_toggle_impl() {
  target=$1
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for check-toggle-fast" >&2
    return 2
  fi
  if [ ! -e "$target" ]; then
    printf '%s\n' "priorities-backend: file not found: $target" >&2
    return 1
  fi

  read_item_attrs "$target"
  checked_value=$attr_checked
  case "$checked_value" in
    *Error*|''|*[!0-9]*) checked_value=0 ;;
  esac

  if [ "$checked_value" = "1" ]; then
    set_user_attr "$target" checked 0
  else
    set_user_attr "$target" checked 1
  fi
}

deprioritize_impl() {
  target=$1
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for remove-fast" >&2
    return 2
  fi
  if [ ! -e "$target" ]; then
    printf '%s\n' "priorities-backend: file not found: $target" >&2
    return 1
  fi
  unset_user_attr "$target" echelon
  unset_user_attr "$target" priority
}

resolve_abs_path() {
  input_path=$1
  case "$input_path" in
    /*) printf '%s\n' "$input_path" ;;
    *) printf '%s/%s\n' "$(pwd -P)" "$input_path" ;;
  esac
}

TRASH_BACKEND=''
detect_trash_backend() {
  if [ -n "$TRASH_BACKEND" ]; then
    return 0
  fi

  kernel=$(uname -s 2>/dev/null || printf 'unknown')
  case "$kernel" in
    Darwin)
      # Prefer CLI trash on macOS to avoid Finder Automation permission prompts.
      if command -v trash >/dev/null 2>&1; then
        TRASH_BACKEND=spell
      elif command -v osascript >/dev/null 2>&1; then
        TRASH_BACKEND=osascript
      fi
      ;;
    Linux)
      if command -v gio >/dev/null 2>&1; then
        TRASH_BACKEND=gio
      elif command -v trash-put >/dev/null 2>&1; then
        TRASH_BACKEND=trash-put
      elif command -v kioclient5 >/dev/null 2>&1; then
        TRASH_BACKEND=kioclient5
      fi
      ;;
  esac

  if [ -z "$TRASH_BACKEND" ]; then
    if command -v trash >/dev/null 2>&1; then
      TRASH_BACKEND=spell
    else
      TRASH_BACKEND=none
    fi
  fi
}

safe_trash_impl() {
  target=$1
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for remove-fast" >&2
    return 2
  fi
  if [ ! -e "$target" ]; then
    printf '%s\n' "priorities-backend: file not found: $target" >&2
    return 1
  fi

  try_trash_backend() {
    backend=$1
    case "$backend" in
      osascript)
        abs_path=$(resolve_abs_path "$target")
        escaped_path=$(printf '%s' "$abs_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
        osascript -e "tell application \"Finder\" to delete POSIX file \"$escaped_path\"" >/dev/null 2>&1
        ;;
      gio)
        gio trash -- "$target" >/dev/null 2>&1
        ;;
      trash-put)
        trash-put -- "$target" >/dev/null 2>&1
        ;;
      kioclient5)
        abs_path=$(resolve_abs_path "$target")
        kioclient5 move "$abs_path" trash:/ >/dev/null 2>&1
        ;;
      spell)
        trash -r -- "$target" >/dev/null 2>&1
        ;;
      *)
        return 1
        ;;
    esac
  }

  detect_trash_backend

  if [ "$TRASH_BACKEND" != "none" ] && try_trash_backend "$TRASH_BACKEND"; then
    return 0
  fi

  for backend in spell osascript gio trash-put kioclient5; do
    if [ "$backend" = "$TRASH_BACKEND" ]; then
      continue
    fi
    case "$backend" in
      osascript) command -v osascript >/dev/null 2>&1 || continue ;;
      gio) command -v gio >/dev/null 2>&1 || continue ;;
      trash-put) command -v trash-put >/dev/null 2>&1 || continue ;;
      kioclient5) command -v kioclient5 >/dev/null 2>&1 || continue ;;
      spell) command -v trash >/dev/null 2>&1 || continue ;;
    esac
    if try_trash_backend "$backend"; then
      TRASH_BACKEND=$backend
      return 0
    fi
  done

  printf '%s\n' "priorities-backend: failed to move to trash: $target" >&2
  return 1
}

descendant_count_impl() {
  target=$1
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for descendant-count" >&2
    return 2
  fi
  if [ ! -e "$target" ]; then
    printf '%s\n' "priorities-backend: file not found: $target" >&2
    return 1
  fi

  if [ ! -d "$target" ]; then
    printf '%s\n' "0"
    return 0
  fi

  count=$(find "$target" -mindepth 1 -print 2>/dev/null | wc -l | tr -d '[:space:]')
  case "$count" in
    ''|*[!0-9]*) count=0 ;;
  esac
  printf '%s\n' "$count"
}

make_project_convert_impl() {
  target=$1
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for make-project" >&2
    return 2
  fi
  if [ ! -e "$target" ]; then
    printf '%s\n' "priorities-backend: file not found: $target" >&2
    return 1
  fi
  if [ -d "$target" ]; then
    return 0
  fi

  parent_dir=$(dirname "$target")
  project_name=$(basename "$target")
  tmp_item=$parent_dir/."$project_name".priorities-project.$$
  tmp_index=0
  while [ -e "$tmp_item" ]; do
    tmp_index=$((tmp_index + 1))
    tmp_item=$parent_dir/."$project_name".priorities-project.$$.${tmp_index}
  done

  mv -- "$target" "$tmp_item"
  if ! mkdir -- "$target"; then
    mv -- "$tmp_item" "$target" >/dev/null 2>&1 || true
    printf '%s\n' "priorities-backend: could not create project directory: $target" >&2
    return 1
  fi
  if ! rm -f -- "$tmp_item"; then
    rmdir -- "$target" >/dev/null 2>&1 || true
    mv -- "$tmp_item" "$target" >/dev/null 2>&1 || true
    printf '%s\n' "priorities-backend: could not finalize project conversion: $target" >&2
    return 1
  fi
  return 0
}

cleanup_project_placeholder_after_rename() {
  project_dir=$1
  old_name=$2
  [ -d "$project_dir" ] || return 0
  [ -n "$old_name" ] || return 0
  placeholder=$project_dir/$old_name
  [ -f "$placeholder" ] || return 0
  size_bytes=$(wc -c <"$placeholder" 2>/dev/null | tr -d '[:space:]')
  case "$size_bytes" in
    ''|*[!0-9]*) return 0 ;;
  esac
  if [ "$size_bytes" -ne 0 ]; then
    return 0
  fi
  rm -f -- "$placeholder" >/dev/null 2>&1 || true
}

make_project_impl() {
  target=$1
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for make-project" >&2
    return 2
  fi

  read_item_attrs "$target"
  preserve_echelon=$attr_echelon
  preserve_priority=$attr_priority
  preserve_checked=$attr_checked
  preserve_upvotes=$attr_upvotes

  make_project_convert_impl "$target"

  case "$preserve_echelon" in
    ''|*Error*|*[!0-9]*) ;;
    *) set_user_attr "$target" echelon "$preserve_echelon" ;;
  esac
  case "$preserve_priority" in
    ''|*Error*|*[!0-9]*) ;;
    *) set_user_attr "$target" priority "$preserve_priority" ;;
  esac
  case "$preserve_checked" in
    ''|*Error*|*[!0-9]*) ;;
    *) set_user_attr "$target" checked "$preserve_checked" ;;
  esac
  case "$preserve_upvotes" in
    ''|*Error*|*[!0-9]*) ;;
    *) set_user_attr "$target" upvotes "$preserve_upvotes" ;;
  esac
}

set_order_emit_impl() {
  directory=$1
  echelon=$2
  shift 2

  if [ -z "$directory" ] || [ -z "$echelon" ]; then
    printf '%s\n' "priorities-backend: set-order-fast requires DIR and ECHELON" >&2
    return 2
  fi
  if [ ! -d "$directory" ]; then
    printf '%s\n' "priorities-backend: directory not found: $directory" >&2
    return 1
  fi
  case "$echelon" in
    *[!0-9]*|'')
      printf '%s\n' "priorities-backend: ECHELON must be an integer" >&2
      return 2
      ;;
  esac

  next_priority=1
  for target in "$@"; do
    if [ -z "$target" ] || [ ! -e "$target" ]; then
      continue
    fi
    target_parent=$(dirname "$target")
    if [ "$target_parent" != "$directory" ]; then
      continue
    fi
    set_user_attr "$target" echelon "$echelon"
    set_user_attr "$target" priority "$next_priority"
    next_priority=$((next_priority + 1))
  done

  emit_list "$directory"
}

emit_sorted_rows() {
  src_file=$1
  if [ ! -s "$src_file" ]; then
    return 0
  fi
  tab=$(printf '\t')
  LC_ALL=C sort -t "$tab" -k1,1rn -k2,2n -k4,4 "$src_file" | while IFS="$(printf '\t')" read -r echelon priority path name kind checked upvotes has_subpriorities; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$path" \
      "$name" \
      "$kind" \
      "$echelon" \
      "$priority" \
      "$checked" \
      "$upvotes" \
      "$has_subpriorities"
  done
}

emit_list() {
  dir=${1:-.}
  if [ ! -d "$dir" ]; then
    printf '%s\n' "priorities-backend: directory not found: $dir" >&2
    return 1
  fi

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/priorities-app.XXXXXX")
  summary_file=$(mktemp "${TMPDIR:-/tmp}/priorities-summary.XXXXXX")
  trap 'rm -f "$tmp_file" "$summary_file"' EXIT HUP INT TERM

  if collect_prioritized_rows_fast "$dir" "$summary_file"; then
    while IFS="$(printf '\t')" read -r item echelon priority checked upvotes has_subpriorities; do
      [ -n "$item" ] || continue

      case "$priority" in
        ''|*Error*|*[!0-9]*) priority=0 ;;
      esac
      case "$checked" in
        ''|*Error*|*[!0-9]*) checked=0 ;;
      esac
      case "$upvotes" in
        ''|*Error*|*[!0-9]*) upvotes=0 ;;
      esac
      case "$has_subpriorities" in
        1) ;;
        *) has_subpriorities=0 ;;
      esac

      kind='file'
      if [ -d "$item" ]; then
        kind='dir'
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$echelon" \
        "$priority" \
        "$item" \
        "$(basename "$item")" \
        "$kind" \
        "$checked" \
        "$upvotes" \
        "$has_subpriorities" >> "$tmp_file"
    done < "$summary_file"

    emit_sorted_rows "$tmp_file"
    return 0
  fi

  for item in "$dir"/*; do
    [ -e "$item" ] || continue

    read_item_attrs "$item"
    echelon=$attr_echelon
    priority=$attr_priority
    checked=$attr_checked
    upvotes=$attr_upvotes

    case "$echelon" in
      ''|*Error*|*[!0-9]*) continue ;;
    esac
    case "$priority" in
      ''|*Error*|*[!0-9]*) priority=0 ;;
    esac
    case "$checked" in
      ''|*Error*|*[!0-9]*) checked=0 ;;
    esac
    case "$upvotes" in
      ''|*Error*|*[!0-9]*) upvotes=0 ;;
    esac

    has_subpriorities=0
    kind='file'
    if [ -d "$item" ]; then
      kind='dir'
      for child in "$item"/*; do
        [ -e "$child" ] || continue
        if child_has_echelon "$child"; then
          has_subpriorities=1
          break
        fi
      done
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$echelon" \
      "$priority" \
      "$item" \
      "$(basename "$item")" \
      "$kind" \
      "$checked" \
      "$upvotes" \
      "$has_subpriorities" >> "$tmp_file"
  done

  emit_sorted_rows "$tmp_file"
}

markdown_lines_for_dir() {
  dir=${1-}
  depth=${2-0}
  expanded=${3-0}
  tab=$(printf '\t')

  list_blob=$(emit_list "$dir")
  [ -n "$list_blob" ] || return 0

  printf '%s\n' "$list_blob" | while IFS="$tab" read -r path name kind echelon priority checked upvotes has_subpriorities; do
    [ -n "$path" ] || continue
    case "$checked" in
      1) mark='x' ;;
      *) mark=' ' ;;
    esac
    clean_name=$(printf '%s' "$name" | tr '\r\n' '  ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
    indent=''
    i=0
    while [ "$i" -lt "$depth" ]; do
      indent="${indent}  "
      i=$((i + 1))
    done
    printf '%s- [%s] %s\n' "$indent" "$mark" "$clean_name"

    if [ "$expanded" = "1" ] && [ "$kind" = "dir" ] && [ "$has_subpriorities" = "1" ]; then
      markdown_lines_for_dir "$path" $((depth + 1)) "$expanded"
    fi
  done
}

copy_text_to_clipboard() {
  text=${1-}

  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$text" | pbcopy
    return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$text" | wl-copy
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    printf '%s' "$text" | xclip -selection clipboard
    return 0
  fi
  if command -v xsel >/dev/null 2>&1; then
    printf '%s' "$text" | xsel --clipboard --input
    return 0
  fi
  return 1
}

prioritize_emit_impl() {
  target=$1
  auto_create=${2:-0}
  target_existed=0
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for prioritize-fast" >&2
    return 2
  fi

  if [ -e "$target" ]; then
    target_existed=1
  else
    if [ "$auto_create" = "1" ]; then
      touch "$target"
    else
      printf '%s\n' "priorities-backend: file not found: $target" >&2
      return 1
    fi
  fi

  prepare_target_for_attrs "$target" || return 1

  directory=$(dirname "$target")
  if [ "$directory" = "." ]; then
    directory=$(pwd -P)
  fi

  read_item_attrs "$target"
  current_echelon=$attr_echelon
  checked_value=$attr_checked

  case "$current_echelon" in
    *Error*|''|*[!0-9]*) current_echelon=0 ;;
  esac
  case "$checked_value" in
    *Error*|''|*[!0-9]*) checked_value=0 ;;
  esac

  scan_file=$(mktemp "${TMPDIR:-/tmp}/priorities-scan.XXXXXX")
  emit_file=$(mktemp "${TMPDIR:-/tmp}/priorities-out.XXXXXX")
  summary_file=$(mktemp "${TMPDIR:-/tmp}/priorities-summary.XXXXXX")
  trap 'rm -f "$scan_file" "$emit_file" "$summary_file"' EXIT HUP INT TERM

  highest_echelon=0
  highest_priority_in_echelon=0

  if collect_prioritized_rows_fast "$directory" "$summary_file"; then
    while IFS="$(printf '\t')" read -r item row_echelon row_priority row_checked row_upvotes row_has_sub; do
      [ -n "$item" ] || continue
      [ -e "$item" ] || continue
      row_prioritized=1
      row_name=$(basename "$item")
      row_kind='file'
      if [ -d "$item" ]; then
        row_kind='dir'
      fi
      case "$row_priority" in
        ''|*Error*|*[!0-9]*) row_priority=0 ;;
      esac
      case "$row_checked" in
        ''|*Error*|*[!0-9]*) row_checked=0 ;;
      esac
      case "$row_upvotes" in
        ''|*Error*|*[!0-9]*) row_upvotes=0 ;;
      esac
      case "$row_has_sub" in
        1) ;;
        *) row_has_sub=0 ;;
      esac

      if [ "$row_prioritized" -eq 1 ]; then
        if [ "$row_echelon" -gt "$highest_echelon" ]; then
          highest_echelon=$row_echelon
          highest_priority_in_echelon=0
        fi
        if [ "$row_echelon" -eq "$highest_echelon" ] && [ "$row_priority" -gt "$highest_priority_in_echelon" ]; then
          highest_priority_in_echelon=$row_priority
        fi
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$item" \
        "$row_name" \
        "$row_kind" \
        "$row_echelon" \
        "$row_priority" \
        "$row_checked" \
        "$row_upvotes" \
        "$row_has_sub" \
        "$row_prioritized" >> "$scan_file"
    done < "$summary_file"
  else
    for item in "$directory"/*; do
      [ -e "$item" ] || continue

      read_item_attrs "$item"
      row_echelon=$attr_echelon
      row_priority=$attr_priority
      row_checked=$attr_checked
      row_upvotes=$attr_upvotes
      row_prioritized=1

      case "$row_echelon" in
        ''|*Error*|*[!0-9]*)
          row_prioritized=0
          row_echelon=0
          ;;
      esac
      case "$row_priority" in
        ''|*Error*|*[!0-9]*) row_priority=0 ;;
      esac
      case "$row_checked" in
        ''|*Error*|*[!0-9]*) row_checked=0 ;;
      esac
      case "$row_upvotes" in
        ''|*Error*|*[!0-9]*) row_upvotes=0 ;;
      esac

      if [ "$row_prioritized" -eq 1 ]; then
        if [ "$row_echelon" -gt "$highest_echelon" ]; then
          highest_echelon=$row_echelon
          highest_priority_in_echelon=0
        fi
        if [ "$row_echelon" -eq "$highest_echelon" ] && [ "$row_priority" -gt "$highest_priority_in_echelon" ]; then
          highest_priority_in_echelon=$row_priority
        fi
      fi

      row_kind='file'
      row_has_sub=0
      if [ -d "$item" ]; then
        row_kind='dir'
        for child in "$item"/*; do
          [ -e "$child" ] || continue
          if child_has_echelon "$child"; then
            row_has_sub=1
            break
          fi
        done
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$item" \
        "$(basename "$item")" \
        "$row_kind" \
        "$row_echelon" \
        "$row_priority" \
        "$row_checked" \
        "$row_upvotes" \
        "$row_has_sub" \
        "$row_prioritized" >> "$scan_file"
    done
  fi

  if [ "$highest_echelon" -eq 0 ]; then
    new_echelon=1
    new_priority=1
  elif [ "$current_echelon" -eq "$highest_echelon" ] && [ "$current_echelon" -gt 0 ]; then
    if [ "$auto_create" = "1" ] && [ "$target_existed" -eq 1 ]; then
      new_echelon=$highest_echelon
      new_priority=$((highest_priority_in_echelon + 1))
    else
      new_echelon=$((highest_echelon + 1))
      new_priority=1
    fi
  else
    new_echelon=$highest_echelon
    new_priority=$((highest_priority_in_echelon + 1))
  fi

  if [ "$checked_value" = "1" ]; then
    set_user_attr "$target" checked 0
  fi
  set_user_attr "$target" echelon "$new_echelon"
  set_user_attr "$target" priority "$new_priority"

  target_found=0
  while IFS="$(printf '\t')" read -r row_path row_name row_kind row_echelon row_priority row_checked row_upvotes row_has_sub row_prioritized; do
    [ -n "$row_path" ] || continue
    [ -e "$row_path" ] || continue
    if [ "$row_path" = "$target" ]; then
      target_found=1
      row_echelon=$new_echelon
      row_priority=$new_priority
      row_checked=0
      row_prioritized=1
    fi
    if [ "$row_prioritized" -ne 1 ] 2>/dev/null; then
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$row_echelon" \
      "$row_priority" \
      "$row_path" \
      "$row_name" \
      "$row_kind" \
      "$row_checked" \
      "$row_upvotes" \
      "$row_has_sub" >> "$emit_file"
  done < "$scan_file"

  if [ "$target_found" -ne 1 ]; then
    read_item_attrs "$target"
    target_upvotes=$attr_upvotes
    case "$target_upvotes" in
      ''|*Error*|*[!0-9]*) target_upvotes=0 ;;
    esac
    target_kind='file'
    target_has_sub=0
    if [ -d "$target" ]; then
      target_kind='dir'
      for child in "$target"/*; do
        [ -e "$child" ] || continue
        if child_has_echelon "$child"; then
          target_has_sub=1
          break
        fi
      done
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$new_echelon" \
      "$new_priority" \
      "$target" \
      "$(basename "$target")" \
      "$target_kind" \
      "0" \
      "$target_upvotes" \
      "$target_has_sub" >> "$emit_file"
  fi

  emit_sorted_rows "$emit_file"
}

case "$action" in
  list-themes)
    emit_theme_names
    ;;

  get-ui-prefs)
    cfg=$(priorities_ui_config_file)
    [ -f "$cfg" ] && cat "$cfg"
    ;;

  set-ui-pref)
    key=${1-}
    value=${2-}
    if [ -z "$key" ]; then
      printf '%s\n' "priorities-backend: set-ui-pref requires KEY VALUE" >&2
      exit 2
    fi
    validate_ui_pref_key "$key"
    value=$(sanitize_ui_pref_value "$value")
    cfg=$(priorities_ui_config_file)
    [ -f "$cfg" ] || : >"$cfg"
    write_key_value_file "$cfg" "$key" "$value"
    printf 'key=%s\n' "$key"
    printf 'value=%s\n' "$value"
    ;;

  list)
    emit_list "$(expand_home_path "${1:-.}")"
    ;;

  copy-priorities)
    copy_dir='.'
    copy_dir_set=0
    expanded=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --expanded)
          expanded=1
          ;;
        --help|--usage|-h)
          printf '%s\n' "Usage: priorities-backend.sh copy-priorities [DIR] [--expanded]"
          exit 0
          ;;
        -*)
          printf '%s\n' "priorities-backend: unknown option for copy-priorities: $1" >&2
          exit 2
          ;;
        *)
          if [ "$copy_dir_set" = "1" ]; then
            printf '%s\n' "priorities-backend: copy-priorities accepts at most one DIR argument" >&2
            exit 2
          fi
          copy_dir=$1
          copy_dir_set=1
          ;;
      esac
      shift
    done

    copy_dir=$(expand_home_path "$copy_dir")
    markdown=$(markdown_lines_for_dir "$copy_dir" 0 "$expanded")
    if [ -z "$markdown" ]; then
      printf '%s\n' "priorities-backend: no priorities found to copy in $copy_dir" >&2
      exit 0
    fi
    if ! copy_text_to_clipboard "$markdown"; then
      printf '%s\n' "priorities-backend: no clipboard command found (pbcopy, wl-copy, xclip, xsel)" >&2
      exit 1
    fi
    printf '%s\n' "$markdown"
    ;;

  prioritize)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for prioritize" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    prioritize_impl "$target" 0
    ;;

  prioritize-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for prioritize-fast" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    prioritize_emit_impl "$target" 0
    ;;

  prioritize-quick)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for prioritize-quick" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    prioritize_quick_impl "$target" 0
    ;;

  check-toggle)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for check-toggle" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    check_toggle_impl "$target"
    ;;

  check-toggle-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for check-toggle-fast" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    check_toggle_impl "$target"
    emit_list "$(dirname "$target")"
    ;;

  make-project)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for make-project" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    make_project_impl "$target"
    printf '%s\n' "$target"
    ;;

  make-project-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for make-project-fast" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    make_project_impl "$target"
    emit_list "$(dirname "$target")"
    ;;

  rename)
    target=${1-}
    new_name=${2-}
    if [ -z "$target" ] || [ -z "$new_name" ]; then
      printf '%s\n' "priorities-backend: rename requires PATH and NAME" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    case "$new_name" in
      */*|*\\*)
        printf '%s\n' "priorities-backend: rename name must not include path separators" >&2
        exit 2
        ;;
      .|..)
        printf '%s\n' "priorities-backend: invalid rename target name" >&2
        exit 2
        ;;
    esac
    old_name=$(basename "$target")
    parent_dir=$(dirname "$target")
    renamed_path=$parent_dir/$new_name
    if [ "$target" = "$renamed_path" ]; then
      printf '%s\n' "$renamed_path"
      exit 0
    fi
    if [ -e "$renamed_path" ]; then
      printf '%s\n' "priorities-backend: rename target already exists: $new_name" >&2
      exit 1
    fi
    mv -- "$target" "$renamed_path"
    cleanup_project_placeholder_after_rename "$renamed_path" "$old_name"
    printf '%s\n' "$renamed_path"
    ;;

  rename-fast)
    target=${1-}
    new_name=${2-}
    if [ -z "$target" ] || [ -z "$new_name" ]; then
      printf '%s\n' "priorities-backend: rename-fast requires PATH and NAME" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    case "$new_name" in
      */*|*\\*)
        printf '%s\n' "priorities-backend: rename name must not include path separators" >&2
        exit 2
        ;;
      .|..)
        printf '%s\n' "priorities-backend: invalid rename target name" >&2
        exit 2
        ;;
    esac
    old_name=$(basename "$target")
    parent_dir=$(dirname "$target")
    renamed_path=$parent_dir/$new_name
    if [ "$target" = "$renamed_path" ]; then
      emit_list "$parent_dir"
      exit 0
    fi
    if [ -e "$renamed_path" ]; then
      printf '%s\n' "priorities-backend: rename target already exists: $new_name" >&2
      exit 1
    fi
    mv -- "$target" "$renamed_path"
    cleanup_project_placeholder_after_rename "$renamed_path" "$old_name"
    emit_list "$parent_dir"
    ;;

  add)
    dir=${1-}
    name=${2-}
    if [ -z "$dir" ] || [ -z "$name" ]; then
      printf '%s\n' "priorities-backend: add requires DIR and NAME" >&2
      exit 2
    fi
    dir=$(expand_home_path "$dir")
    target=$dir/$name
    prioritize_impl "$target" 1
    ;;

  add-fast)
    dir=${1-}
    name=${2-}
    if [ -z "$dir" ] || [ -z "$name" ]; then
      printf '%s\n' "priorities-backend: add-fast requires DIR and NAME" >&2
      exit 2
    fi
    dir=$(expand_home_path "$dir")
    target=$dir/$name
    prioritize_emit_impl "$target" 1
    ;;

  remove)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for remove" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    safe_trash_impl "$target"
    ;;

  remove-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for remove-fast" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    safe_trash_impl "$target"
    emit_list "$(dirname "$target")"
    ;;

  descendant-count)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for descendant-count" >&2
      exit 2
    fi
    target=$(expand_home_path "$target")
    descendant_count_impl "$target"
    ;;

  open-dir)
    dir=${1:-.}
    dir=$(expand_home_path "$dir")
    if [ ! -d "$dir" ]; then
      printf '%s\n' "priorities-backend: directory not found: $dir" >&2
      exit 1
    fi
    abs=$(CDPATH= cd -- "$dir" && pwd -P)
    if command -v open >/dev/null 2>&1; then
      open "$abs" >/dev/null 2>&1
      exit 0
    fi
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$abs" >/dev/null 2>&1
      exit 0
    fi
    if command -v explorer.exe >/dev/null 2>&1; then
      explorer.exe "$abs" >/dev/null 2>&1
      exit 0
    fi
    printf '%s\n' "priorities-backend: no file browser opener found (open, xdg-open, explorer.exe)" >&2
    exit 1
    ;;

  pick-dir)
    case "$(uname -s 2>/dev/null || printf '')" in
      Darwin)
        osascript -e 'set chosenFolder to choose folder with prompt "Choose priorities folder"' \
          -e 'POSIX path of chosenFolder' | sed 's:/*$::'
        ;;
      Linux)
        if command -v zenity >/dev/null 2>&1; then
          zenity --file-selection --directory --title="Choose priorities folder" | sed 's:/*$::'
        else
          printf '%s\n' "priorities-backend: zenity not found for folder picker" >&2
          exit 1
        fi
        ;;
      *)
        printf '%s\n' "priorities-backend: folder picker unsupported on this platform" >&2
        exit 1
        ;;
    esac
    ;;

  parent)
    dir=${1-}
    if [ -z "$dir" ]; then
      printf '%s\n' "priorities-backend: parent requires DIR" >&2
      exit 2
    fi
    dir=$(expand_home_path "$dir")
    if [ ! -d "$dir" ]; then
      printf '%s\n' "priorities-backend: directory not found: $dir" >&2
      exit 1
    fi
    abs=$(CDPATH= cd -- "$dir" && pwd -P)
    parent=$(dirname "$abs")
    printf '%s\n' "$parent"
    ;;

  *)
    printf '%s\n' "priorities-backend: unknown action '$action'" >&2
    exit 2
    ;;
esac
