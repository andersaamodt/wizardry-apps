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

assert_status_fail "$backend" rename-fast "$scratch/task one" "task two"
list_blob=$(list_root)
rename_collision_src=$(row_by_name "$list_blob" "task one")
rename_collision_dst=$(row_by_name "$list_blob" "task two")
assert_nonempty "$rename_collision_src" "rename collision should keep source task"
assert_nonempty "$rename_collision_dst" "rename collision should keep destination task"

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
assert_status_fail "$backend" rename-fast "$scratch/task renamed" "task one"
list_blob=$(list_root)
file_row_after_dir_collision=$(row_by_name "$list_blob" "task renamed")
dir_row_after_dir_collision=$(row_by_name "$list_blob" "task one")
assert_nonempty "$file_row_after_dir_collision" "rename collision against directory should keep source task"
assert_nonempty "$dir_row_after_dir_collision" "rename collision against directory should keep destination project"

children=$("$backend" list "$scratch/task one")
child_row=$(row_by_name "$children" "child note")
assert_nonempty "$child_row" "child note should exist inside converted project"
self_row=$(row_by_name "$children" "task one")
assert_eq "$self_row" "" "make-project should not leave a self-named placeholder task"

"$backend" rename-fast "$scratch/task one" "task one renamed" >/dev/null
children_after_rename=$("$backend" list "$scratch/task one renamed")
old_name_row=$(row_by_name "$children_after_rename" "task one")
assert_eq "$old_name_row" "" "renaming a project should not leave old-name placeholder task"
child_after_rename=$(row_by_name "$children_after_rename" "child note")
assert_nonempty "$child_after_rename" "renaming project should keep real child tasks"
project_path="$scratch/task one renamed"

"$backend" add-fast "$scratch" "fallback project" >/dev/null
cat > "$fake_bin/file-to-folder" <<'EOF'
#!/bin/sh
set -eu
exit 1
EOF
chmod +x "$fake_bin/file-to-folder"
PATH="$fake_bin:$PATH" "$backend" make-project-fast "$scratch/fallback project" >/dev/null
list_blob=$(list_root)
fallback_row=$(row_by_name "$list_blob" "fallback project")
assert_eq "$(field "$fallback_row" 3)" "dir" "make-project-fast should fallback when file-to-folder fails"
fallback_children=$("$backend" list "$scratch/fallback project")
fallback_self_row=$(row_by_name "$fallback_children" "fallback project")
assert_eq "$fallback_self_row" "" "make-project-fast fallback should not create self-named child task"

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

desc=$("$backend" descendant-count "$project_path")
case "$desc" in
  ''|*[!0-9]*) fail "descendant-count should return a numeric value" ;;
esac
[ "$desc" -ge 1 ] || fail "descendant-count should be >= 1 for project with one child"

parent=$("$backend" parent "$project_path")
scratch_abs=$(CDPATH= cd -- "$scratch" && pwd -P)
assert_eq "$parent" "$scratch_abs" "parent action should return parent directory"

assert_status_fail "$backend" rename-fast "$project_path" "bad/name"
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
