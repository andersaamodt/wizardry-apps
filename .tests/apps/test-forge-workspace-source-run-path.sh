#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-workspace-source-run.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

rm -f "$root/_tmp/workbench/bin/wizardry-host-macos"
rm -rf "$root/_tmp/workbench/dist/macos-workspaces/workspace-source-run"

fake_bin="$scratch/fake-bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/uname" <<'SH'
#!/bin/sh
printf '%s\n' "Darwin"
SH
chmod +x "$fake_bin/uname"

cat > "$fake_bin/clang" <<'SH'
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

[ -n "$out" ] || exit 2

cat > "$out" <<'HOST'
#!/bin/sh
set -eu

app_dir=${1-}
log_file=${WIZARDRY_FAKE_HOST_LOG:-}

[ -n "$log_file" ] && printf 'host-start app=%s\n' "$app_dir" >>"$log_file"

trap 'exit 0' TERM INT
sleep "${WIZARDRY_FAKE_HOST_SLEEP:-5}" &
child=$!
wait "$child"
HOST
chmod +x "$out"
SH
chmod +x "$fake_bin/clang"

cat > "$fake_bin/lipo" <<'SH'
#!/bin/sh
if [ "${1-}" = '-archs' ]; then
  printf '%s\n' "arm64 x86_64"
  exit 0
fi
exit 0
SH
chmod +x "$fake_bin/lipo"

cat > "$fake_bin/open" <<'SH'
#!/bin/sh
set -eu

bundle=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|-a|-na|-an)
      shift
      ;;
    --args)
      shift
      break
      ;;
    *)
      bundle=$1
      shift
      ;;
  esac
done

[ -n "$bundle" ] || exit 2
launcher=$(find "$bundle/Contents/MacOS" -maxdepth 1 -type f ! -name 'wizardry-host' | head -n 1)
if [ -z "$launcher" ] && [ -x "$bundle/Contents/MacOS/wizardry-host" ]; then
  launcher="$bundle/Contents/MacOS/wizardry-host"
fi
[ -n "$launcher" ] || exit 1
entry=$(
  awk '
    /<key>WizardryAppEntry<\/key>/ {
      sub(/^.*<string>/, "")
      sub(/<\/string>.*$/, "")
      print
      exit
    }
  ' "$bundle/Contents/Info.plist"
)
nohup "$launcher" "$entry" "$@" >/dev/null 2>&1 &
exit 0
SH
chmod +x "$fake_bin/open"

cat > "$fake_bin/osascript" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$fake_bin/osascript"

workspace="$scratch/workspace"
mkdir -p "$workspace/app"
cat > "$workspace/app/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Workspace</title>
HTML
cat > "$workspace/wizardry.workspace.conf" <<CONF
project_id=workspace-source-run
title=Workspace Source Run
project_type=application
development_context=web
targets=macos
root=$workspace
starter=import-web
CONF

app_entry=$(CDPATH= cd -- "$workspace/app" && pwd -P)

host_log="$scratch/host.log"
run_out=$(
  env \
    PATH="$fake_bin:$PATH" \
    WIZARDRY_FAKE_HOST_LOG="$host_log" \
    WIZARDRY_FAKE_HOST_SLEEP=8 \
    sh "$backend" run-workspace "$root" "$workspace"
)

printf '%s\n' "$run_out" | grep -F "launched=1" >/dev/null
printf '%s\n' "$run_out" | grep -F "mode=desktop-executable" >/dev/null
printf '%s\n' "$run_out" | grep -F "entry=$app_entry" >/dev/null

i=0
while [ "$i" -lt 40 ]; do
  if [ -f "$host_log" ] && grep -F "host-start app=$app_entry" "$host_log" >/dev/null 2>&1; then
    printf '%s\n' "forge workspace source run path test passed"
    exit 0
  fi
  i=$((i + 1))
  sleep 0.1
done

printf '%s\n' "forge workspace source run path test failed: host did not start with source app dir" >&2
[ -f "$host_log" ] && cat "$host_log" >&2
exit 1
