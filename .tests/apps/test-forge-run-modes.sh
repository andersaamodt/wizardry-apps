#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable: $backend" >&2
  exit 1
}

assert_contains() {
  haystack=$1
  needle=$2
  if ! printf '%s\n' "$haystack" | grep -F "$needle" >/dev/null; then
    printf '%s\n' "missing expected text: $needle" >&2
    exit 1
  fi
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
  [ -f "$file" ] && cat "$file" >&2
  exit 1
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
<title>Forge Mode Test Workspace</title>
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

started_pids=''
register_pid() {
  pid=$1
  [ -n "$pid" ] || return 0
  case "$pid" in
    *[!0-9]*)
      printf '%s\n' "expected numeric pid, got: $pid" >&2
      exit 1
      ;;
  esac
  started_pids="$started_pids $pid"
}

cleanup() {
  for pid in $started_pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  [ -n "${scratch-}" ] && rm -rf "$scratch"
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-run-modes.XXXXXX")
trap cleanup EXIT HUP INT TERM

fake_bin="$scratch/fake-bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/uname" <<'SH_UNAME'
#!/bin/sh
printf '%s\n' "${FORGE_TEST_UNAME:-Linux}"
SH_UNAME
chmod +x "$fake_bin/uname"

cat > "$fake_bin/pkg-config" <<'SH_PKG'
#!/bin/sh
exit 0
SH_PKG
chmod +x "$fake_bin/pkg-config"

cat > "$fake_bin/cc" <<'SH_CC'
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
log_file=${WIZARDRY_FAKE_HOST_LOG-}
mode=${WIZARDRY_FAKE_HOST_MODE-loop}
sleep_seconds=${WIZARDRY_FAKE_HOST_SLEEP-30}

if [ -n "$log_file" ]; then
  printf '%s\n' "$app_dir" >>"$log_file"
fi

case "$mode" in
  fail)
    exit 1
    ;;
  once)
    sleep "$sleep_seconds"
    exit 0
    ;;
  loop)
    while :; do
      sleep 1
    done
    ;;
  *)
    while :; do
      sleep 1
    done
    ;;
esac
HOST
chmod +x "$out"
SH_CC
chmod +x "$fake_bin/cc"

cat > "$fake_bin/open" <<'SH_OPEN'
#!/bin/sh
exit 0
SH_OPEN
chmod +x "$fake_bin/open"

help_out=$(sh "$backend" --help)
assert_contains "$help_out" "install-desktop [ROOT_HINT] APP_SLUG [TARGET_ID]"
assert_contains "$help_out" "run-desktop [ROOT_HINT] APP_SLUG"
assert_contains "$help_out" "run-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT]"
assert_contains "$help_out" "import-workspace [ROOT_HINT] WORKSPACE_PATH [PROJECT_ROOT]"
assert_contains "$help_out" "rename-workspace [ROOT_HINT] WORKSPACE_PATH NEW_TITLE"
assert_contains "$help_out" "CONTEXT values for scaffold-workspace:"
assert_contains "$help_out" "  web | godot"

# Behavior: desktop app targets launch desktop host mode.
desktop_log="$scratch/desktop-host.log"
desktop_out=$(PATH="$fake_bin:$PATH" FORGE_TEST_UNAME=Linux WIZARDRY_FAKE_HOST_LOG="$desktop_log" WIZARDRY_FAKE_HOST_MODE=loop sh "$backend" run-desktop "$root" forge)
assert_contains "$desktop_out" "launched=1"
assert_contains "$desktop_out" "mode=desktop-executable"
desktop_pid=$(printf '%s\n' "$desktop_out" | kv_read pid)
register_pid "$desktop_pid"
desktop_entry=$(printf '%s\n' "$desktop_out" | kv_read entry)
[ -n "$desktop_entry" ]
[ -f "$desktop_entry/index.html" ]
wait_for_file_contains "$desktop_log" "$desktop_entry" 60

# Behavior: workspace preferring host target launches desktop mode even when hosted-web is enabled.
workspace_host="$scratch/workspace-host"
make_workspace "$workspace_host" "workspace-host" "Workspace Host" "hosted-web,linux"
workspace_host_log="$scratch/workspace-host.log"
workspace_host_out=$(PATH="$fake_bin:$PATH" FORGE_TEST_UNAME=Linux WIZARDRY_FAKE_HOST_LOG="$workspace_host_log" WIZARDRY_FAKE_HOST_MODE=loop sh "$backend" run-workspace "$root" "$workspace_host" web)
assert_contains "$workspace_host_out" "launched=1"
assert_contains "$workspace_host_out" "mode=desktop-executable"
workspace_host_pid=$(printf '%s\n' "$workspace_host_out" | kv_read pid)
register_pid "$workspace_host_pid"
workspace_host_entry=$(printf '%s\n' "$workspace_host_out" | kv_read entry)
[ -n "$workspace_host_entry" ]
wait_for_file_contains "$workspace_host_log" "$workspace_host_entry" 60

# Behavior: workspace with no native host target falls back to hosted-web mode.
workspace_web="$scratch/workspace-web"
make_workspace "$workspace_web" "workspace-web" "Workspace Web" "hosted-web"
workspace_web_out=$(PATH="$fake_bin:$PATH" FORGE_TEST_UNAME=Linux sh "$backend" run-workspace "$root" "$workspace_web" web)
assert_contains "$workspace_web_out" "mode=python-http"
workspace_web_url=$(printf '%s\n' "$workspace_web_out" | kv_read url)
printf '%s\n' "$workspace_web_url" | grep -E '^http://127\.0\.0\.1:[0-9]+$' >/dev/null
workspace_web_pid=$(printf '%s\n' "$workspace_web_out" | kv_read pid)
register_pid "$workspace_web_pid"

printf '%s\n' "forge run-mode behavior tests passed"
