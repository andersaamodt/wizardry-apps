#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$test_root/.apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "skip: jq not installed" >&2
  exit 0
fi

out=$("$backend" --help)
printf '%s' "$out" | grep -F "Usage:" >/dev/null

out=$("$backend" doctor "$test_root")
printf '%s\n' "$out" | grep -F "root=$test_root" >/dev/null
printf '%s\n' "$out" | grep -F "os=" >/dev/null

apps=$("$backend" list-apps "$test_root")
printf '%s\n' "$apps" | grep -E '^artificer\t' >/dev/null
printf '%s\n' "$apps" | grep -E '^forge\t' >/dev/null

templates=$("$backend" list-templates "$test_root")
printf '%s\n' "$templates" | grep -E '^demo\t' >/dev/null

scratch=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-forge-backend.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

bundle_scripts="$scratch/Wizardry Forge.app/Contents/Resources/forge/scripts"
bundle_root_file="$scratch/Wizardry Forge.app/Contents/Resources/wizardry-apps-root.txt"
mkdir -p "$bundle_scripts"
cp "$backend" "$bundle_scripts/forge-backend.sh"
chmod +x "$bundle_scripts/forge-backend.sh"
printf '%s\n' "$test_root" > "$bundle_root_file"
bundle_doctor=$("$bundle_scripts/forge-backend.sh" doctor)
printf '%s\n' "$bundle_doctor" | grep -F "root=$test_root" >/dev/null

rm -f "$bundle_root_file"
home_dir="$scratch/home"
mkdir -p "$home_dir/.config/wizardry-apps"
printf '%s\n' "$test_root" > "$home_dir/.config/wizardry-apps/forge-root"
config_doctor=$(HOME="$home_dir" "$bundle_scripts/forge-backend.sh" doctor)
printf '%s\n' "$config_doctor" | grep -F "root=$test_root" >/dev/null

mkdir -p "$scratch/config" "$scratch/.apps" "$scratch/.web"
cp "$test_root/config/apps.manifest.json" "$scratch/config/apps.manifest.json"
cp "$test_root/config/templates.manifest.json" "$scratch/config/templates.manifest.json"
cp -R "$test_root/.web/demo" "$scratch/.web/demo"
cp -R "$test_root/.web/.themes" "$scratch/.web/.themes"

"$backend" scaffold-app "$scratch" sandbox-tool "Sandbox Tool" minimal >/tmp/forge-scaffold-app.log
[ -f "$scratch/.apps/sandbox-tool/index.html" ]
[ -f "$scratch/.apps/sandbox-tool/style.css" ]

jq -e '.apps[] | select(.slug == "sandbox-tool" and .production == false)' "$scratch/config/apps.manifest.json" >/dev/null

site_out=$("$backend" scaffold-site "$scratch" sandbox-site demo "$scratch/sites")
printf '%s\n' "$site_out" | grep -F "created=$scratch/sites/sandbox-site" >/dev/null
[ -f "$scratch/sites/sandbox-site/site.conf" ]
[ -f "$scratch/sites/sandbox-site/site.allowlist" ]
[ -d "$scratch/sites/sandbox-site/site/pages" ]
[ -d "$scratch/sites/sandbox-site/build" ]

printf '%s\n' "forge backend tests passed"
