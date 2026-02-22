#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/.apps/priorities/scripts/priorities-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "priorities backend missing or not executable: $backend" >&2
  exit 1
}

if ! command -v hashchant >/dev/null 2>&1; then
  printf '%s\n' "skip: hashchant not installed" >&2
  exit 0
fi

tab=$(printf '\t')
scratch=$(mktemp -d "${TMPDIR:-/tmp}/priorities-backend.XXXXXX")
prefs_home="$scratch/prefs-home"
mkdir -p "$prefs_home"
fake_bin="$scratch/fake-bin"
mkdir -p "$fake_bin"
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  actual=$1
  expected=$2
  msg=$3
  if [ "$actual" != "$expected" ]; then
    fail "$msg (expected '$expected', got '$actual')"
  fi
}

assert_nonempty() {
  value=$1
  msg=$2
  [ -n "$value" ] || fail "$msg"
}

assert_status_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

row_by_name() {
  list_blob=$1
  item_name=$2
  printf '%s\n' "$list_blob" | awk -F "$tab" -v n="$item_name" '$2==n { print; exit }'
}

field() {
  row=$1
  idx=$2
  printf '%s\n' "$row" | awk -F "$tab" -v i="$idx" '{ print $i }'
}

list_root() {
  "$backend" list "$scratch"
}

list_blob=$(list_root)
assert_eq "$list_blob" "" "new temp root should start empty"

"$backend" add-fast "$scratch" "task one" >/dev/null
list_blob=$(list_root)
row_task_one=$(row_by_name "$list_blob" "task one")
assert_nonempty "$row_task_one" "task one should exist after add-fast"
assert_eq "$(field "$row_task_one" 3)" "file" "task one kind should be file"
assert_eq "$(field "$row_task_one" 6)" "0" "task one should start unchecked"

"$backend" add-fast "$scratch" "task two" >/dev/null
list_blob=$(list_root)
first_name=$(printf '%s\n' "$list_blob" | awk -F "$tab" 'NR==1 { print $2 }')
assert_eq "$first_name" "task one" "first-added item should remain first within same echelon"
row_task_two=$(row_by_name "$list_blob" "task two")
assert_eq "$(field "$row_task_two" 5)" "2" "second add-fast should use next priority value"

"$backend" check-toggle-fast "$scratch/task two" >/dev/null
list_blob=$(list_root)
row_task_two=$(row_by_name "$list_blob" "task two")
assert_eq "$(field "$row_task_two" 6)" "1" "check-toggle-fast should set checked=1"

"$backend" check-toggle-fast "$scratch/task two" >/dev/null
list_blob=$(list_root)
row_task_two=$(row_by_name "$list_blob" "task two")
assert_eq "$(field "$row_task_two" 6)" "0" "second check-toggle-fast should set checked=0"

"$backend" rename-fast "$scratch/task two" "task renamed" >/dev/null
list_blob=$(list_root)
row_renamed=$(row_by_name "$list_blob" "task renamed")
assert_nonempty "$row_renamed" "rename-fast should rename target"
old_row=$(row_by_name "$list_blob" "task two")
assert_eq "$old_row" "" "old task name should not appear after rename-fast"

quick=$("$backend" prioritize-quick "$scratch/task one")
qe=$(printf '%s\n' "$quick" | awk -F "$tab" 'NR==1{print $1}')
qp=$(printf '%s\n' "$quick" | awk -F "$tab" 'NR==1{print $2}')
qc=$(printf '%s\n' "$quick" | awk -F "$tab" 'NR==1{print $3}')
case "$qe:$qp:$qc" in
  *[!0-9:]*|'') fail "prioritize-quick should return numeric echelon/priority/checked triple" ;;
esac

"$backend" make-project "$scratch/task one" >/dev/null
"$backend" add-fast "$scratch/task one" "child note" >/dev/null
list_blob=$(list_root)
row_project=$(row_by_name "$list_blob" "task one")
assert_eq "$(field "$row_project" 3)" "dir" "make-project should convert file to dir"
assert_eq "$(field "$row_project" 8)" "1" "project should report hasSubpriorities=1 when child exists"

children=$("$backend" list "$scratch/task one")
child_row=$(row_by_name "$children" "child note")
assert_nonempty "$child_row" "child note should exist inside converted project"

copy_root="$scratch/copy-root"
mkdir -p "$copy_root"
"$backend" add-fast "$copy_root" "alpha" >/dev/null
"$backend" add-fast "$copy_root" "beta" >/dev/null
"$backend" check-toggle-fast "$copy_root/beta" >/dev/null
"$backend" make-project "$copy_root/alpha" >/dev/null
"$backend" add-fast "$copy_root/alpha" "alpha child" >/dev/null

cat > "$fake_bin/pbcopy" <<'EOF'
#!/bin/sh
set -eu
cat > "${COPY_CAPTURE_PATH:?}"
EOF
chmod +x "$fake_bin/pbcopy"

COPY_CAPTURE_PATH="$scratch/clipboard-default.md" PATH="$fake_bin:$PATH" "$backend" copy-priorities "$copy_root" > "$scratch/stdout-default.md"
default_md=$(cat "$scratch/stdout-default.md")
default_clip=$(cat "$scratch/clipboard-default.md")
assert_eq "$default_md" "$default_clip" "copy-priorities should write the same markdown to stdout and clipboard"
printf '%s\n' "$default_md" | grep -F -- "- [ ] alpha" >/dev/null || fail "default copy should include top-level alpha"
printf '%s\n' "$default_md" | grep -F -- "- [x] beta" >/dev/null || fail "default copy should include checked beta"
if printf '%s\n' "$default_md" | grep -F -- "alpha child" >/dev/null; then
  fail "default copy should not include nested child without --expanded"
fi

COPY_CAPTURE_PATH="$scratch/clipboard-expanded.md" PATH="$fake_bin:$PATH" "$backend" copy-priorities --expanded "$copy_root" > "$scratch/stdout-expanded.md"
expanded_md=$(cat "$scratch/stdout-expanded.md")
expanded_clip=$(cat "$scratch/clipboard-expanded.md")
assert_eq "$expanded_md" "$expanded_clip" "expanded copy should write the same markdown to stdout and clipboard"
printf '%s\n' "$expanded_md" | grep -F -- "- [ ] alpha" >/dev/null || fail "expanded copy should include top-level alpha"
printf '%s\n' "$expanded_md" | grep -F -- "  - [ ] alpha child" >/dev/null || fail "expanded copy should include indented alpha child"
printf '%s\n' "$expanded_md" | grep -F -- "- [x] beta" >/dev/null || fail "expanded copy should include checked beta"

cat > "$fake_bin/open" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "${1-}" > "${OPEN_CAPTURE_PATH:?}"
EOF
chmod +x "$fake_bin/open"
OPEN_CAPTURE_PATH="$scratch/open-dir-path.txt" PATH="$fake_bin:$PATH" "$backend" open-dir "$copy_root" >/dev/null
opened_path=$(cat "$scratch/open-dir-path.txt")
copy_root_abs=$(CDPATH= cd -- "$copy_root" && pwd -P)
assert_eq "$opened_path" "$copy_root_abs" "open-dir should invoke OS opener with absolute directory path"

desc=$("$backend" descendant-count "$scratch/task one")
case "$desc" in
  ''|*[!0-9]*) fail "descendant-count should return a numeric value" ;;
esac
[ "$desc" -ge 1 ] || fail "descendant-count should be >= 1 for project with one child"

parent=$("$backend" parent "$scratch/task one")
scratch_abs=$(CDPATH= cd -- "$scratch" && pwd -P)
assert_eq "$parent" "$scratch_abs" "parent action should return parent directory"

assert_status_fail "$backend" rename-fast "$scratch/task one" "bad/name"
assert_status_fail "$backend" check-toggle-fast "$scratch/does-not-exist"
assert_status_fail "$backend" remove-fast "$scratch/does-not-exist"

cat > "$fake_bin/trash" <<'EOF'
#!/bin/sh
set -eu
for target in "$@"; do
  rm -rf -- "$target"
done
EOF
chmod +x "$fake_bin/trash"
PATH="$fake_bin:$PATH" "$backend" remove-fast "$scratch/task renamed" >/dev/null
list_blob=$(list_root)
removed_row=$(row_by_name "$list_blob" "task renamed")
assert_eq "$removed_row" "" "remove-fast should remove item from list output"

set_pref_out=$(XDG_CONFIG_HOME="$prefs_home" "$backend" set-ui-pref theme psionic)
printf '%s\n' "$set_pref_out" | grep -F "key=theme" >/dev/null || fail "set-ui-pref should echo key"
pref_blob=$(XDG_CONFIG_HOME="$prefs_home" "$backend" get-ui-prefs)
printf '%s\n' "$pref_blob" | grep -F "theme=psionic" >/dev/null || fail "get-ui-prefs should include saved value"

themes=$("$backend" list-themes)
printf '%s\n' "$themes" | grep -F "psionic" >/dev/null || fail "list-themes should include psionic"

printf '%s\n' "priorities backend behavior tests passed"
