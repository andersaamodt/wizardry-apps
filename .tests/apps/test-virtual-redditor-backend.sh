#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
app_dir="$root/apps/virtual-redditor"
backend="$app_dir/scripts/virtual-redditor-backend.sh"
daemon="$app_dir/scripts/virtual-redditor-daemon.sh"
extractor="$app_dir/scripts/extract_norms.sh"

[ -d "$app_dir" ] || {
  printf '%s\n' "skip: optional virtual-redditor app is not checked out"
  exit 0
}

[ -d "$app_dir" ]
[ -f "$app_dir/index.html" ]
[ -f "$app_dir/style.css" ]
[ -f "$app_dir/README.md" ]
[ -f "$app_dir/manifesto.md" ]
[ -f "$app_dir/norms.jsonl" ]
[ -x "$backend" ]
[ -x "$daemon" ]
[ -x "$extractor" ]

grep -F "Virtual Redditor" "$app_dir/index.html" >/dev/null
grep -F "virtual-redditor-backend.sh" "$app_dir/index.html" >/dev/null
grep -F "bridge.exec" "$app_dir/index.html" >/dev/null

grep -F "launchd-install" "$daemon" >/dev/null
grep -F "reply -> randomized delay -> ban" "$app_dir/README.md" >/dev/null
grep -F "apply_reply_delay" "$daemon" >/dev/null
grep -F "latencyJitterSec" "$daemon" >/dev/null

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "skip: jq not installed" >&2
  exit 0
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-virtual-redditor.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
state_dir="$scratch/state"

init_out=$(VR_STATE_DIR="$state_dir" "$backend" init)
printf '%s' "$init_out" | jq -e '.ok == true and (.paths.manifesto | type == "string")' >/dev/null

[ -f "$state_dir/reddit.env" ]
[ -f "$state_dir/bot.env" ]
[ -f "$state_dir/manifesto.md" ]
[ -f "$state_dir/norms.jsonl" ]
[ -f "$state_dir/last_seen.txt" ]
[ -f "$state_dir/modes.json" ]
[ -f "$state_dir/relationships.json" ]

status_out=$(VR_STATE_DIR="$state_dir" "$backend" status)
printf '%s' "$status_out" | jq -e '.ok == true and .settings.ok == true and .metrics.ok == true and .launchd.ok == true' >/dev/null
printf '%s' "$status_out" | jq -e '.launchd.label | test("^com\\.wizardry\\.virtualredditor\\.[a-z0-9_-]+\\.[a-z0-9_-]+$")' >/dev/null

actions_out=$(VR_STATE_DIR="$state_dir" "$backend" list-actions 5)
printf '%s' "$actions_out" | jq -e '.ok == true and (.actions | type == "array")' >/dev/null

replies_out=$(VR_STATE_DIR="$state_dir" "$backend" list-replies 5)
printf '%s' "$replies_out" | jq -e '.ok == true and (.replies | type == "array")' >/dev/null

modes_out=$(VR_STATE_DIR="$state_dir" "$backend" get-modes-config)
printf '%s' "$modes_out" | jq -e '.ok == true and (.config.modes | type == "array") and (.config.behaviors | type == "object")' >/dev/null

patched_modes=$(printf '%s' "$modes_out" | jq -c '.config + {behaviors:(.config.behaviors + {humorStyle:"shady",humorAmount:"high"})}')
save_modes_out=$(VR_STATE_DIR="$state_dir" "$backend" save-modes-config "$patched_modes")
printf '%s' "$save_modes_out" | jq -e '.ok == true and .config.behaviors.humorStyle == "shady" and .config.behaviors.humorAmount == "high"' >/dev/null

relationships_out=$(VR_STATE_DIR="$state_dir" "$backend" list-relationships 5)
printf '%s' "$relationships_out" | jq -e '.ok == true and (.relationships | type == "array")' >/dev/null

set_rel_out=$(VR_STATE_DIR="$state_dir" "$backend" set-relationship test_user SHADE 48 manual-test)
printf '%s' "$set_rel_out" | jq -e '.ok == true and .relationship.user_id == "test_user" and .relationship.current_mode == "SHADE"' >/dev/null

mode_log_out=$(VR_STATE_DIR="$state_dir" "$backend" list-mode-log 5)
printf '%s' "$mode_log_out" | jq -e '.ok == true and (.events | type == "array")' >/dev/null

VR_STATE_DIR="$state_dir" "$backend" write-file manifesto "# Edited Manifesto" >/dev/null
manifesto_out=$(VR_STATE_DIR="$state_dir" "$backend" read-file manifesto)
printf '%s' "$manifesto_out" | jq -e '.ok == true and (.content | contains("Edited Manifesto"))' >/dev/null

log_out=$(VR_STATE_DIR="$state_dir" "$backend" tail-log 10)
printf '%s' "$log_out" | jq -e '.ok == true and .stdout.path != null and .stderr.path != null' >/dev/null

oauth_begin=$(VR_STATE_DIR="$state_dir" "$backend" oauth-begin test_client_id test_client_secret testsub testuser)
printf '%s' "$oauth_begin" | jq -e '.ok == true and (.status == "waiting" or .status == "error")' >/dev/null

oauth_status=$(VR_STATE_DIR="$state_dir" "$backend" oauth-status)
printf '%s' "$oauth_status" | jq -e '.ok == true and (.status == "waiting" or .status == "error")' >/dev/null

oauth_cancel=$(VR_STATE_DIR="$state_dir" "$backend" oauth-cancel)
printf '%s' "$oauth_cancel" | jq -e '.ok == true and .status == "cancelled"' >/dev/null

thread_cap_set=$(VR_STATE_DIR="$state_dir" "$backend" set-setting THREAD_INITIATE_MAX_PCT 15)
printf '%s' "$thread_cap_set" | jq -e '.ok == true and .threadInitiateMaxPct == 15' >/dev/null

printf '%s\n' "virtual redditor backend tests passed"
