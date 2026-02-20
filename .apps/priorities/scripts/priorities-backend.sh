#!/bin/sh

# Backend actions for the Priorities desktop app.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: priorities-backend.sh ACTION [ARGS...]

Actions:
  list [DIR]            List prioritized items in DIR (default: current dir)
  prioritize PATH       Promote PATH using the prioritize spell
  set-order-fast DIR ECHELON PATH...
                        Persist queue order for items in one echelon
  check-toggle PATH     Toggle checked state using check/uncheck spells
  make-project PATH     Convert PATH file to project folder
  rename PATH NAME      Rename PATH to NAME in same directory
  add DIR NAME          Add NAME in DIR and prioritize it
  remove PATH           Remove PATH from priorities (deprioritize)
  pick-dir              Open a native folder picker (prints selected path)
  parent DIR            Print parent directory path
USAGE
  exit 0
  ;;
esac

set -eu

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

prioritize_impl() {
  target=$1
  auto_create=${2:-0}
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for prioritize-fast" >&2
    return 2
  fi

  if [ ! -e "$target" ]; then
    if [ "$auto_create" = "1" ]; then
      touch "$target"
    else
      printf '%s\n' "priorities-backend: file not found: $target" >&2
      return 1
    fi
  fi

  if ! hashchant "$target" >/dev/null 2>&1; then
    printf '%s\n' "priorities-backend: hashchant failed: $target" >&2
    return 1
  fi

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

  if [ "$highest_echelon" -eq 0 ]; then
    set_user_attr "$target" echelon 1
    set_user_attr "$target" priority 1
    return 0
  fi

  if [ "$current_echelon" -eq "$highest_echelon" ] && [ "$current_echelon" -gt 0 ]; then
    new_echelon=$((highest_echelon + 1))
    set_user_attr "$target" echelon "$new_echelon"
    set_user_attr "$target" priority 1
    return 0
  fi

  new_priority=$((highest_priority_in_echelon + 1))
  set_user_attr "$target" echelon "$highest_echelon"
  set_user_attr "$target" priority "$new_priority"
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

prioritize_emit_impl() {
  target=$1
  auto_create=${2:-0}
  if [ -z "$target" ]; then
    printf '%s\n' "priorities-backend: path required for prioritize-fast" >&2
    return 2
  fi

  if [ ! -e "$target" ]; then
    if [ "$auto_create" = "1" ]; then
      touch "$target"
    else
      printf '%s\n' "priorities-backend: file not found: $target" >&2
      return 1
    fi
  fi

  if ! hashchant "$target" >/dev/null 2>&1; then
    printf '%s\n' "priorities-backend: hashchant failed: $target" >&2
    return 1
  fi

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
  out_file=$(mktemp "${TMPDIR:-/tmp}/priorities-out.XXXXXX")
  summary_file=$(mktemp "${TMPDIR:-/tmp}/priorities-summary.XXXXXX")
  trap 'rm -f "$scan_file" "$out_file" "$summary_file"' EXIT HUP INT TERM

  highest_echelon=0
  highest_priority_in_echelon=0

  if collect_prioritized_rows_fast "$directory" "$summary_file"; then
    while IFS="$(printf '\t')" read -r item row_echelon row_priority row_checked row_upvotes row_has_sub; do
      [ -n "$item" ] || continue
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
    new_echelon=$((highest_echelon + 1))
    new_priority=1
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
      "$row_has_sub" >> "$out_file"
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
      "$target_has_sub" >> "$out_file"
  fi

  emit_sorted_rows "$out_file"
}

case "$action" in
  list)
    emit_list "${1:-.}"
    ;;

  prioritize)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for prioritize" >&2
      exit 2
    fi
    prioritize_impl "$target" 0
    ;;

  prioritize-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for prioritize-fast" >&2
      exit 2
    fi
    prioritize_emit_impl "$target" 0
    ;;

  set-order-fast)
    directory=${1-}
    echelon=${2-}
    shift 2 || true
    set_order_emit_impl "$directory" "$echelon" "$@"
    ;;

  check-toggle)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for check-toggle" >&2
      exit 2
    fi
    check_toggle_impl "$target"
    ;;

  check-toggle-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for check-toggle-fast" >&2
      exit 2
    fi
    check_toggle_impl "$target"
    emit_list "$(dirname "$target")"
    ;;

  make-project)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for make-project" >&2
      exit 2
    fi
    file-to-folder "$target" >/dev/null
    printf '%s\n' "$target"
    ;;

  rename)
    target=${1-}
    new_name=${2-}
    if [ -z "$target" ] || [ -z "$new_name" ]; then
      printf '%s\n' "priorities-backend: rename requires PATH and NAME" >&2
      exit 2
    fi
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
    parent_dir=$(dirname "$target")
    renamed_path=$parent_dir/$new_name
    mv -- "$target" "$renamed_path"
    printf '%s\n' "$renamed_path"
    ;;

  rename-fast)
    target=${1-}
    new_name=${2-}
    if [ -z "$target" ] || [ -z "$new_name" ]; then
      printf '%s\n' "priorities-backend: rename-fast requires PATH and NAME" >&2
      exit 2
    fi
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
    parent_dir=$(dirname "$target")
    renamed_path=$parent_dir/$new_name
    mv -- "$target" "$renamed_path"
    emit_list "$parent_dir"
    ;;

  add)
    dir=${1-}
    name=${2-}
    if [ -z "$dir" ] || [ -z "$name" ]; then
      printf '%s\n' "priorities-backend: add requires DIR and NAME" >&2
      exit 2
    fi
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
    target=$dir/$name
    prioritize_emit_impl "$target" 1
    ;;

  remove)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for remove" >&2
      exit 2
    fi
    deprioritize_impl "$target"
    ;;

  remove-fast)
    target=${1-}
    if [ -z "$target" ]; then
      printf '%s\n' "priorities-backend: path required for remove-fast" >&2
      exit 2
    fi
    deprioritize_impl "$target"
    emit_list "$(dirname "$target")"
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
