#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
backend="$root/apps/forge/scripts/forge-backend.sh"

[ -x "$backend" ] || {
  printf '%s\n' "forge backend missing or not executable" >&2
  exit 1
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/forge-native-mobile-import.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

workspace="$scratch/mobile-repair"
mkdir -p "$workspace/app-blueprint" "$workspace/scripts"

cat >"$workspace/app-blueprint/mobile.ir.yaml" <<'IR'
{
  "schemaVersion": "1.0",
  "app": {
    "id": "mobile-repair",
    "name": "Mobile Repair"
  },
  "navigation": {
    "kind": "tabs",
    "items": [
      {
        "id": "home",
        "title": "Home",
        "screen": {
          "id": "home-screen",
          "title": "Home",
          "body": {
            "type": "Text",
            "text": "Hello"
          }
        }
      }
    ]
  }
}
IR

cat >"$workspace/scripts/render-mobile.sh" <<'SH'
#!/bin/sh
set -eu
mkdir -p generated/mobile
SH
chmod +x "$workspace/scripts/render-mobile.sh"

cat >"$workspace/wizardry.workspace.conf" <<CONF
# Wizardry Apps project profile
project_id=mobile-repair
title=Mobile Repair
project_type=native-mobile
development_context=native-mobile
starter=import-native-mobile
profile_kind=detected
targets=android,ios
root=$workspace
mobile_ir_path=app-blueprint/mobile.ir.yaml
run_rebuild_command=:
CONF

sh "$backend" import-workspace "$root" "$workspace" "$scratch" >/dev/null

grep -F 'run_rebuild_command=sh scripts/render-mobile.sh' "$workspace/wizardry.workspace.conf" >/dev/null || {
  printf '%s\n' "forge native-mobile import test: expected render-mobile rebuild command repair" >&2
  exit 1
}

workspace_rows=$(sh "$backend" list-workspaces "$root" "$scratch")
printf '%s\n' "$workspace_rows" | awk -F '\t' '
  $1 == "mobile-repair" {
    if ($2 != "Mobile Repair" || $4 != "native-mobile" || $8 != "1") exit 1
    found = 1
  }
  END { exit(found ? 0 : 1) }
' || {
  printf '%s\n' "forge native-mobile import test: workspace did not list as runnable" >&2
  printf '%s\n' "$workspace_rows" >&2
  exit 1
}

printf '%s\n' "forge native-mobile import runnable test passed"
