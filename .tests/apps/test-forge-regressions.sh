#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-regressions.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fake_bin="$scratch/fake-bin"
mkdir -p "$fake_bin"

assert_contains() {
  haystack=$1
  needle=$2
  if ! printf '%s\n' "$haystack" | grep -F "$needle" >/dev/null; then
    printf '%s\n' "assert_contains failed: missing '$needle'" >&2
    exit 1
  fi
}

assert_file_contains() {
  file=$1
  needle=$2
  if ! grep -F "$needle" "$file" >/dev/null 2>&1; then
    printf '%s\n' "assert_file_contains failed: '$needle' missing in $file" >&2
    exit 1
  fi
}

wait_for_file_contains() {
  file=$1
  needle=$2
  attempts=${3-50}
  i=0
  while [ "$i" -lt "$attempts" ]; do
    if [ -f "$file" ] && grep -F "$needle" "$file" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.1
  done
  printf '%s\n' "timed out waiting for '$needle' in $file" >&2
  if [ -f "$file" ]; then
    cat "$file" >&2
  fi
  exit 1
}

wait_for_file_line_count() {
  file=$1
  min_count=$2
  attempts=${3-50}
  i=0
  while [ "$i" -lt "$attempts" ]; do
    count=0
    if [ -f "$file" ]; then
      count=$(wc -l <"$file" | tr -d ' ')
    fi
    if [ "$count" -ge "$min_count" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.1
  done
  printf '%s\n' "timed out waiting for $file to reach $min_count lines" >&2
  if [ -f "$file" ]; then
    cat "$file" >&2
  fi
  exit 1
}

kv_read() {
  key=$1
  awk -F= -v target="$key" '
    $1 == target {
      sub(/^[^=]*=/, "", $0)
      print $0
      exit
    }
  '
}

make_workspace() {
  workspace=$1
  project_id=$2
  title=$3
  targets=$4

  mkdir -p "$workspace/app"
  cat > "$workspace/app/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Forge Test Workspace</title>
HTML
  cat > "$workspace/wizardry.workspace.conf" <<CONF
project_id=$project_id
title=$title
project_type=application
development_context=web
targets=$targets
root=$workspace
starter=import-web
CONF
}

kill_test_workbench_hosts() {
  workbench_root=$1
  command -v ps >/dev/null 2>&1 || return 0
  pids=$(
    ps -axo pid=,command= 2>/dev/null \
      | awk -v root="$workbench_root" '
          index($0, root) > 0 && index($0, "wizardry-host") > 0 { print $1 }
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
      | awk -v root="$workbench_root" '
          index($0, root) > 0 && index($0, "wizardry-host") > 0 { print $1 }
        ' \
      | tr '\n' ' ' \
      | sed 's/[[:space:]]*$//'
  )
  if [ -n "$still" ]; then
    # shellcheck disable=SC2086
    kill -9 $still >/dev/null 2>&1 || true
  fi
}

cat > "$fake_bin/uname" <<'SH'
#!/bin/sh
printf '%s\n' "${FORGE_TEST_UNAME:-Linux}"
SH
chmod +x "$fake_bin/uname"

cat > "$fake_bin/pkg-config" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$fake_bin/pkg-config"

cat > "$fake_bin/cc" <<'SH'
#!/bin/sh
set -eu

out=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then
    out=$2
    shift 2
    continue
  fi
  shift
done

[ -n "$out" ] || {
  printf '%s\n' "fake cc requires -o OUTPUT" >&2
  exit 2
}

cat > "$out" <<'HOST'
#!/bin/sh
set -eu

app_dir=${1-}
log_file=${WIZARDRY_FAKE_HOST_LOG:-}
order_log=${WIZARDRY_FAKE_HOST_ORDER_LOG:-}
mode=${WIZARDRY_FAKE_HOST_MODE:-run}

if [ -n "$log_file" ]; then
  printf 'host-start pid=%s app=%s mode=%s\n' "$$" "$app_dir" "$mode" >>"$log_file"
fi
if [ -n "$order_log" ]; then
  printf 'host-start %s\n' "$app_dir" >>"$order_log"
fi

if [ "$mode" = 'fail' ]; then
  if [ -n "$log_file" ]; then
    printf 'host-fail pid=%s app=%s\n' "$$" "$app_dir" >>"$log_file"
  fi
  if [ -n "$order_log" ]; then
    printf 'host-fail %s\n' "$app_dir" >>"$order_log"
  fi
  exit 1
fi

trap '
  if [ -n "$log_file" ]; then
    printf "host-term pid=%s app=%s\n" "$$" "$app_dir" >>"$log_file"
  fi
  if [ -n "$order_log" ]; then
    printf "host-term %s\n" "$app_dir" >>"$order_log"
  fi
  exit 0
' TERM INT

sleep "${WIZARDRY_FAKE_HOST_SLEEP:-30}" &
child=$!
wait "$child"
HOST
chmod +x "$out"
SH
chmod +x "$fake_bin/cc"

cat > "$fake_bin/zenity" <<'SH'
#!/bin/sh
printf '%s\n' "${FORGE_TEST_PICK_DIR:-}"
SH
chmod +x "$fake_bin/zenity"


test_env() {
  env \
    PATH="$fake_bin:$PATH" \
    FORGE_TEST_UNAME=Linux \
    "$@"
}

# Keep the harness deterministic: these tests rely on fake host/tool stubs,
# so cached real host binaries or prior desktop bundles under _tmp must not leak in.
rm -f "$root/_tmp/workbench/bin/wizardry-host-linux"
rm -rf "$root/_tmp/workbench/dist/linux" "$root/_tmp/workbench/dist/linux-workspaces"
kill_test_workbench_hosts "$root/_tmp/workbench/dist/"

explicit_blank_ws="$scratch/explicit-blank"
make_workspace "$explicit_blank_ws" "explicit-blank" "Explicit Blank" "linux"
cat >> "$explicit_blank_ws/wizardry.workspace.conf" <<CONF
run_rebuild_command=
rebuild_command=printf '%s\n' "legacy-should-not-run" >> "$scratch/explicit-blank.log"
CONF

explicit_blank_out=$(test_env sh "$backend" rebuild-workspace "$root" "$explicit_blank_ws")
assert_contains "$explicit_blank_out" "status=noop"
assert_contains "$explicit_blank_out" "mode=none"
[ ! -f "$scratch/explicit-blank.log" ] || {
  printf '%s\n' "explicit blank run_rebuild_command should suppress legacy rebuild_command" >&2
  exit 1
}

legacy_fallback_ws="$scratch/legacy-fallback"
make_workspace "$legacy_fallback_ws" "legacy-fallback" "Legacy Fallback" "linux"
cat >> "$legacy_fallback_ws/wizardry.workspace.conf" <<CONF
rebuild_command=printf '%s\n' "legacy-rebuild" >> "$scratch/legacy-fallback.log"
CONF

legacy_fallback_out=$(test_env sh "$backend" rebuild-workspace "$root" "$legacy_fallback_ws")
assert_contains "$legacy_fallback_out" "status=ok"
assert_contains "$legacy_fallback_out" "mode=command"
assert_file_contains "$scratch/legacy-fallback.log" "legacy-rebuild"

rebuild_status_ws="$scratch/rebuild-status"
make_workspace "$rebuild_status_ws" "rebuild-status" "Rebuild Status" "linux"
cat >> "$rebuild_status_ws/wizardry.workspace.conf" <<CONF
run_rebuild_command=true #$(printf '\r')forged=1
CONF

rebuild_status_out=$(test_env sh "$backend" rebuild-workspace "$root" "$rebuild_status_ws")
assert_contains "$rebuild_status_out" "status=ok"
assert_contains "$rebuild_status_out" "mode=command"
if printf '%s\n' "$rebuild_status_out" | tr '\r' '\n' | grep -E '^forged=' >/dev/null 2>&1; then
  printf '%s\n' "rebuild-workspace emitted forged key-value output from rebuild command" >&2
  exit 1
fi

pick_ws="$scratch/pick-workspace"
make_workspace "$pick_ws" "pick-workspace" "Pick Workspace" "hosted-web"
mkdir -p "$pick_ws/sub-app"
cp "$pick_ws/app/index.html" "$pick_ws/sub-app/index.html"
cp "$pick_ws/app/index.html" "$pick_ws/index.html"
mkdir -p "$pick_ws/docs"
mkdir -p "$scratch/outside"
cp "$pick_ws/app/index.html" "$scratch/outside/index.html"

pick_valid_out=$(test_env FORGE_TEST_PICK_DIR="$pick_ws/sub-app" sh "$backend" pick-workspace-subpath "$root" "$pick_ws")
assert_contains "$pick_valid_out" "relative=sub-app"

pick_root_out=$(test_env FORGE_TEST_PICK_DIR="$pick_ws" sh "$backend" pick-workspace-subpath "$root" "$pick_ws")
assert_contains "$pick_root_out" "relative=."

if test_env FORGE_TEST_PICK_DIR="$scratch/outside" sh "$backend" pick-workspace-subpath "$root" "$pick_ws" >/tmp/forge-pick-outside.out 2>/tmp/forge-pick-outside.err; then
  printf '%s\n' "pick-workspace-subpath unexpectedly accepted an external folder" >&2
  exit 1
fi
grep -F "selected folder must stay inside the project root" /tmp/forge-pick-outside.err >/dev/null

if test_env FORGE_TEST_PICK_DIR="$pick_ws/docs" sh "$backend" pick-workspace-subpath "$root" "$pick_ws" >/tmp/forge-pick-docs.out 2>/tmp/forge-pick-docs.err; then
  printf '%s\n' "pick-workspace-subpath unexpectedly accepted a folder without index.html" >&2
  exit 1
fi
grep -F "selected folder must contain index.html" /tmp/forge-pick-docs.err >/dev/null

workspace_run_ws="$scratch/run-workspace"
make_workspace "$workspace_run_ws" "run-workspace" "Run Workspace" "linux"
cat >> "$workspace_run_ws/wizardry.workspace.conf" <<CONF
run_rebuild_command=printf '%s\n' "rebuild" >> "$scratch/workspace-order.log"
CONF

workspace_host_log="$scratch/workspace-host.log"
workspace_order_log="$scratch/workspace-order.log"

workspace_run_one=$(test_env \
  WIZARDRY_FAKE_HOST_LOG="$workspace_host_log" \
  WIZARDRY_FAKE_HOST_ORDER_LOG="$workspace_order_log" \
  WIZARDRY_FAKE_HOST_SLEEP=12 \
  sh "$backend" run-workspace "$root" "$workspace_run_ws")
assert_contains "$workspace_run_one" "launched=1"
assert_contains "$workspace_run_one" "mode=desktop-executable"
workspace_pid_one=$(printf '%s\n' "$workspace_run_one" | kv_read pid)
[ -n "$workspace_pid_one" ]
wait_for_file_contains "$workspace_host_log" "host-start"
wait_for_file_line_count "$workspace_order_log" 2
first_order_line=$(sed -n '1p' "$workspace_order_log")
[ "$first_order_line" = "rebuild" ] || {
  printf '%s\n' "workspace rebuild should happen before host launch" >&2
  cat "$workspace_order_log" >&2
  exit 1
}

workspace_run_two=$(test_env \
  WIZARDRY_FAKE_HOST_LOG="$workspace_host_log" \
  WIZARDRY_FAKE_HOST_ORDER_LOG="$workspace_order_log" \
  WIZARDRY_FAKE_HOST_SLEEP=12 \
  sh "$backend" run-workspace "$root" "$workspace_run_ws")
assert_contains "$workspace_run_two" "launched=1"
workspace_pid_two=$(printf '%s\n' "$workspace_run_two" | kv_read pid)
[ -n "$workspace_pid_two" ]
wait_for_file_contains "$workspace_host_log" "host-term"
wait_for_file_line_count "$workspace_host_log" 3
host_start_count=$(grep -c '^host-start ' "$workspace_host_log" || true)
[ "$host_start_count" -ge 2 ] || {
  printf '%s\n' "workspace rerun should launch twice across two runs" >&2
  cat "$workspace_host_log" >&2
  exit 1
}

kill "$workspace_pid_two" >/dev/null 2>&1 || true
sleep 0.2

workspace_fail_ws="$scratch/fail-workspace"
make_workspace "$workspace_fail_ws" "fail-workspace" "Fail Workspace" "linux"
if test_env \
  WIZARDRY_FAKE_HOST_LOG="$scratch/workspace-fail.log" \
  WIZARDRY_FAKE_HOST_MODE=fail \
  sh "$backend" run-workspace "$root" "$workspace_fail_ws" >/tmp/forge-run-workspace-fail.out 2>/tmp/forge-run-workspace-fail.err; then
  printf '%s\n' "run-workspace unexpectedly succeeded even though the host exited immediately" >&2
  exit 1
fi
grep -F "failed to launch project desktop host" /tmp/forge-run-workspace-fail.err >/dev/null

builtin_host_log="$scratch/builtin-host.log"
builtin_run_out=$(test_env \
  WIZARDRY_FAKE_HOST_LOG="$builtin_host_log" \
  WIZARDRY_FAKE_HOST_SLEEP=12 \
  sh "$backend" run-desktop "$root" forge)
assert_contains "$builtin_run_out" "launched=1"
assert_contains "$builtin_run_out" "mode=desktop-executable"
assert_contains "$builtin_run_out" "built_artifact="
assert_contains "$builtin_run_out" "artifact="
wait_for_file_contains "$builtin_host_log" "host-start"
builtin_pid=$(printf '%s\n' "$builtin_run_out" | kv_read pid)
[ -n "$builtin_pid" ]
kill "$builtin_pid" >/dev/null 2>&1 || true
sleep 0.2

if test_env \
  WIZARDRY_FAKE_HOST_LOG="$scratch/builtin-fail.log" \
  WIZARDRY_FAKE_HOST_MODE=fail \
  sh "$backend" run-desktop "$root" forge >/tmp/forge-run-desktop-fail.out 2>/tmp/forge-run-desktop-fail.err; then
  printf '%s\n' "run-desktop unexpectedly succeeded even though the host exited immediately" >&2
  exit 1
fi
grep -F "failed to launch desktop app" /tmp/forge-run-desktop-fail.err >/dev/null

printf '%s\n' "forge regression tests passed"
