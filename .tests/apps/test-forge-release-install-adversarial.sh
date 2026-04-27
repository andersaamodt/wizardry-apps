#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-release-install.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fake_bin="$scratch/bin"
workspace="$scratch/workspace"
home_dir="$scratch/home"
mkdir -p "$fake_bin" "$workspace" "$home_dir"

cat > "$workspace/wizardry.workspace.conf" <<CONF
project_id=release-app
title=Release App
project_type=application
development_context=web
targets=linux
run_rebuild_command=:
CONF

if git -C "$workspace" init -b main >/dev/null 2>&1; then
  :
else
  git -C "$workspace" init >/dev/null
fi
printf '%s\n' "fixture" >"$workspace/file.txt"
git -C "$workspace" add file.txt >/dev/null
git -C "$workspace" -c user.name=Test -c user.email=test@example.invalid commit -m init >/dev/null
git -C "$workspace" remote add origin https://github.com/example/release-app.git

cat > "$fake_bin/uname" <<'SH'
#!/bin/sh
printf '%s\n' Linux
SH
chmod +x "$fake_bin/uname"

cat > "$fake_bin/curl" <<'SH'
#!/bin/sh
out=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -n "$out" ]; then
  mkdir -p "$(dirname "$out")"
  printf '#!/bin/sh\nprintf escaped\\n\n' >"$out"
  exit 0
fi

cat <<'JSON'
{"name":"v1","tag_name":"v1","html_url":"https://example.invalid/release","published_at":"2026-01-01T00:00:00Z","assets":[{"name":"../evil.AppImage","browser_download_url":"https://example.invalid/evil.AppImage"}]}
JSON
SH
chmod +x "$fake_bin/curl"

if HOME="$home_dir" PATH="$fake_bin:$PATH" sh "$backend" workspace-git-install-release "$root" "$workspace" >/tmp/forge-release-install.out 2>/tmp/forge-release-install.err; then
  printf '%s\n' "forge release install accepted a path-traversing asset name" >&2
  exit 1
fi

grep -F "invalid release asset name" /tmp/forge-release-install.err >/dev/null
[ ! -e "$home_dir/.local/share/wizardry-apps/evil.AppImage" ] || {
  printf '%s\n' "path-traversing asset escaped the release install directory" >&2
  exit 1
}

printf '%s\n' "forge release install adversarial tests passed"
