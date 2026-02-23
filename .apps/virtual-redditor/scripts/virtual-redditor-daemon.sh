#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: virtual-redditor-daemon.sh COMMAND [ARGS...]

Commands:
  bootstrap
  settings
  metrics
  once
  run
  list-actions [LIMIT]
  list-replies [LIMIT]
  get-modes-config
  save-modes-config JSON
  list-relationships [LIMIT]
  set-relationship USER MODE [DURATION_HOURS] [TRIGGER]
  list-mode-log [LIMIT]
  extract-norms [full]
  undo ACTION_ID
  apologize ACTION_ID [MESSAGE]
  launchd-status
  launchd-install
  launchd-start
  launchd-stop
  launchd-uninstall
  set-setting KEY VALUE
  set-reddit-setting KEY VALUE

Environment overrides:
  VR_STATE_DIR        Runtime/config directory (default: ~/.local/state/wizardry/virtual-redditor)
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
STATE_DIR=${VR_STATE_DIR:-"${XDG_STATE_HOME:-$HOME/.local/state}/wizardry/virtual-redditor"}
GLOBAL_INSTRUCTIONS_FILE=${VR_GLOBAL_INSTRUCTIONS_FILE:-"$STATE_DIR/global-default-instructions.md"}

BANS_LOG="$STATE_DIR/bans.jsonl"
REPLIES_LOG="$STATE_DIR/replies.jsonl"
ACTIONS_LOG="$STATE_DIR/actions.jsonl"
NORM_PROPOSALS_LOG="$STATE_DIR/norm-proposals.jsonl"
MODES_CONFIG_FILE="$STATE_DIR/modes.json"
RELATIONSHIPS_FILE="$STATE_DIR/relationships.json"
MODE_LOG_FILE="$STATE_DIR/mode-log.jsonl"
LAST_SEEN_FILE="$STATE_DIR/last_seen.txt"
LAST_STATUTE_SEEN_FILE="$STATE_DIR/last_statute_seen.txt"
LAST_STATUTE_DAY_FILE="$STATE_DIR/last_statute_day.txt"
TOKEN_FILE="$STATE_DIR/.token"
TOKEN_EXP_FILE="$STATE_DIR/.token.exp"
RUNTIME_FILE="$STATE_DIR/runtime.json"
BOT_ENV_FILE="$STATE_DIR/bot.env"
REDDIT_ENV_FILE="$STATE_DIR/reddit.env"
MANIFESTO_FILE="$STATE_DIR/manifesto.md"
NORMS_FILE="$STATE_DIR/norms.jsonl"
DAEMON_STDOUT_LOG="$STATE_DIR/daemon.log"
DAEMON_STDERR_LOG="$STATE_DIR/daemon-error.log"

require_tool() {
  tool=$1
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s\n' "virtual-redditor-daemon: required tool missing: $tool" >&2
    exit 1
  fi
}

require_tools() {
  require_tool curl
  require_tool jq
  require_tool awk
  require_tool sed
  require_tool date
}

now_epoch() {
  date +%s
}

now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

to_int() {
  raw=${1-}
  fallback=${2-0}
  case "$raw" in
    ''|*[!0-9-]*)
      printf '%s' "$fallback"
      ;;
    *)
      sign=''
      digits=$raw
      case "$raw" in
        -*)
          sign='-'
          digits=${raw#-}
          ;;
      esac
      digits=$(printf '%s' "$digits" | sed 's/^0*//')
      [ -z "$digits" ] && digits=0
      if [ "$sign" = '-' ] && [ "$digits" = '0' ]; then
        sign=''
      fi
      printf '%s%s' "$sign" "$digits"
      ;;
  esac
}

random_seed_u32() {
  if command -v od >/dev/null 2>&1; then
    od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' '
  else
    printf '%s' "$$"
  fi
}

random_between() {
  min=$(to_int "${1-}" 0)
  max=$(to_int "${2-}" 0)
  if [ "$max" -lt "$min" ]; then
    tmp=$min
    min=$max
    max=$tmp
  fi
  span=$((max - min + 1))
  if [ "$span" -le 1 ]; then
    printf '%s' "$min"
    return
  fi
  seed=$(random_seed_u32)
  case "$seed" in
    ''|*[!0-9]*) seed=$$ ;;
  esac
  printf '%s' $((min + (seed % span)))
}

new_event_id() {
  prefix=$1
  ts=$(now_epoch)
  rand=$(random_between 100000 999999)
  printf '%s-%s-%s' "$prefix" "$ts" "$rand"
}

emit_ok() {
  payload=${1-'{"ok":true}'}
  if [ -z "$payload" ]; then
    payload='{"ok":true}'
  fi
  printf '%s\n' "$payload"
}

emit_error() {
  message=${1-"unknown error"}
  jq -cn --arg msg "$message" '{ok:false,error:$msg}'
}

append_jsonl() {
  file=$1
  json=$2
  printf '%s\n' "$json" >> "$file"
}

mode_default_config_json() {
  jq -cn '
    {
      version: 1,
      actionCatalog: [
        "Reply","Initiate","Warn","Mention","Quote","Followup","Cross-thread Reply",
        "Short Ban","Medium Ban","Long Ban","Extended Ban","Year Ban","Permanent Ban",
        "Remove Content","Lock Thread","Post Neutral Ban Notice"
      ],
      templates: [
        {name:"Needler",startingMode:"SHADE"},
        {name:"Teacher",startingMode:"TEACH"},
        {name:"Celebrity",startingMode:"SPOTLIGHT"},
        {name:"Judge",startingMode:"SUMMON"},
        {name:"Moderator",startingMode:"STRICT"},
        {name:"Enforcer",startingMode:"ENFORCE"}
      ],
      behaviors: {
        mirrorTone: "mirror_or_less",
        humor: "measured",
        citations: "as-needed",
        latencyJitterSec: {min: 0, max: 0},
        banJitterSec: {min: 7, max: 45},
        summonable: true
      },
      startingMode: "SHADE",
      defaultDecayMode: "SHADE",
      restrictivenessOrder: ["STRICT","RULES","BAN","PROBATION","WARN","TEACH","SHADE"],
      modes: [
        {
          id: "SHADE",
          label: "Cordial Conversationalist",
          enabled: true,
          defaultExpiryHours: 0,
          allow: {
            Reply:true,Initiate:true,Warn:false,Mention:true,Quote:false,Followup:true,
            "Cross-thread Reply":true,"Short Ban":false,"Medium Ban":false,"Long Ban":false,
            "Extended Ban":false,"Year Ban":false,"Permanent Ban":false,"Remove Content":false,
            "Lock Thread":false,"Post Neutral Ban Notice":false
          },
          constraints: {
            maxRepliesPerUserThread24h: 4,
            noFollowup: false,
            noMention: false,
            noQuote: true
          }
        },
        {
          id: "TEACH",
          label: "Direct Speaker",
          enabled: true,
          defaultExpiryHours: 0,
          allow: {
            Reply:true,Initiate:true,Warn:true,Mention:true,Quote:true,Followup:true,
            "Cross-thread Reply":true,"Short Ban":false,"Medium Ban":false,"Long Ban":false,
            "Extended Ban":false,"Year Ban":false,"Permanent Ban":false,"Remove Content":false,
            "Lock Thread":false,"Post Neutral Ban Notice":false
          },
          constraints: {
            maxRepliesPerUserThread24h: 5,
            noFollowup: false,
            noMention: false,
            noQuote: false
          }
        },
        {
          id: "WARN",
          label: "Verbal Corrector",
          enabled: true,
          defaultExpiryHours: 24,
          allow: {
            Reply:true,Initiate:false,Warn:true,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":false,"Medium Ban":false,"Long Ban":false,
            "Extended Ban":false,"Year Ban":false,"Permanent Ban":false,"Remove Content":false,
            "Lock Thread":false,"Post Neutral Ban Notice":true
          },
          constraints: {
            maxRepliesPerUserThread24h: 2,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        },
        {
          id: "SUMMON",
          label: "On Mention",
          enabled: true,
          defaultExpiryHours: 0,
          allow: {
            Reply:true,Initiate:false,Warn:false,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":false,"Medium Ban":false,"Long Ban":false,
            "Extended Ban":false,"Year Ban":false,"Permanent Ban":false,"Remove Content":false,
            "Lock Thread":false,"Post Neutral Ban Notice":false
          },
          constraints: {
            maxRepliesPerUserThread24h: 2,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        },
        {
          id: "SPOTLIGHT",
          label: "Spotlight Presence",
          enabled: true,
          defaultExpiryHours: 0,
          allow: {
            Reply:true,Initiate:true,Warn:false,Mention:true,Quote:false,Followup:true,
            "Cross-thread Reply":true,"Short Ban":false,"Medium Ban":false,"Long Ban":false,
            "Extended Ban":false,"Year Ban":false,"Permanent Ban":false,"Remove Content":false,
            "Lock Thread":false,"Post Neutral Ban Notice":false
          },
          constraints: {
            maxRepliesPerUserThread24h: 4,
            noFollowup: false,
            noMention: false,
            noQuote: true
          }
        },
        {
          id: "PROBATION",
          label: "Watchful Referee",
          enabled: true,
          defaultExpiryHours: 72,
          allow: {
            Reply:true,Initiate:false,Warn:true,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":true,"Medium Ban":false,"Long Ban":false,
            "Extended Ban":false,"Year Ban":false,"Permanent Ban":false,"Remove Content":true,
            "Lock Thread":false,"Post Neutral Ban Notice":true
          },
          constraints: {
            maxRepliesPerUserThread24h: 1,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        },
        {
          id: "BAN",
          label: "Explicit Enforcer",
          enabled: true,
          defaultExpiryHours: 168,
          allow: {
            Reply:true,Initiate:false,Warn:true,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":true,"Medium Ban":true,"Long Ban":true,
            "Extended Ban":true,"Year Ban":true,"Permanent Ban":true,"Remove Content":true,
            "Lock Thread":false,"Post Neutral Ban Notice":true
          },
          constraints: {
            maxRepliesPerUserThread24h: 1,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        },
        {
          id: "RULES",
          label: "Silent Enforcer",
          enabled: true,
          defaultExpiryHours: 168,
          allow: {
            Reply:false,Initiate:false,Warn:false,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":true,"Medium Ban":true,"Long Ban":true,
            "Extended Ban":true,"Year Ban":true,"Permanent Ban":true,"Remove Content":true,
            "Lock Thread":true,"Post Neutral Ban Notice":true
          },
          constraints: {
            maxRepliesPerUserThread24h: 0,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        },
        {
          id: "STRICT",
          label: "Active Moderator",
          enabled: true,
          defaultExpiryHours: 336,
          allow: {
            Reply:true,Initiate:false,Warn:true,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":true,"Medium Ban":true,"Long Ban":true,
            "Extended Ban":true,"Year Ban":true,"Permanent Ban":true,"Remove Content":true,
            "Lock Thread":true,"Post Neutral Ban Notice":true
          },
          constraints: {
            maxRepliesPerUserThread24h: 1,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        },
        {
          id: "ENFORCE",
          label: "Bans First",
          enabled: true,
          defaultExpiryHours: 336,
          allow: {
            Reply:true,Initiate:false,Warn:true,Mention:false,Quote:false,Followup:false,
            "Cross-thread Reply":false,"Short Ban":true,"Medium Ban":true,"Long Ban":true,
            "Extended Ban":true,"Year Ban":true,"Permanent Ban":true,"Remove Content":true,
            "Lock Thread":true,"Post Neutral Ban Notice":true
          },
          constraints: {
            maxRepliesPerUserThread24h: 1,
            noFollowup: true,
            noMention: true,
            noQuote: true
          }
        }
      ],
      banLevels: {
        short: {enabled:true,durationHours:72},
        medium: {enabled:true,durationHours:168},
        long: {enabled:true,durationHours:720},
        extended: {enabled:true,durationHours:4380},
        year: {enabled:true,durationHours:8760},
        permanent: {enabled:true,durationHours:0}
      },
      postActionTransitions: {
        Warn: {toMode:"WARN",durationHours:24,decayTo:"SHADE",announce:false},
        "Short Ban": {toMode:"BAN",durationHours:72,decayTo:"PROBATION",announce:true},
        "Medium Ban": {toMode:"BAN",durationHours:168,decayTo:"PROBATION",announce:true},
        "Long Ban": {toMode:"RULES",durationHours:720,decayTo:"BAN",announce:true},
        "Extended Ban": {toMode:"RULES",durationHours:4380,decayTo:"BAN",announce:true},
        "Year Ban": {toMode:"STRICT",durationHours:8760,decayTo:"RULES",announce:true},
        "Permanent Ban": {toMode:"STRICT",durationHours:0,decayTo:"RULES",announce:true},
        "Remove Content": {toMode:"PROBATION",durationHours:72,decayTo:"TEACH",announce:false}
      },
      switchRules: [
        {
          id: "opt-out",
          label: "General opt-out",
          matchAny: ["leave me alone","do not reply","dont reply","stop replying","opt out"],
          toMode: "BAN",
          durationHours: 72,
          decayTo: "SHADE",
          announce: true,
          template: "Acknowledged. I will not continue this conversational dyad right now."
        }
      ],
      optInCommands: ["!summon","!engage","/u/{{bot_username}}"],
      replies: {
        warningTemplate: "Moderator notice: please follow subreddit norms.",
        modeSwitchTemplate: "Mode update: {{user}} is now in {{mode}}.",
        neutralBanTemplate: "Neutral moderator notice: enforcement was applied."
      },
      escalation: {
        onHighSeverity: false,
        targets: "modmail",
        timing: "enforce_then_escalate",
        includePayload: ["content","user_id","norm","bot_action","thread_link"],
        afterActionSwitch: {enabled:false,toMode:"STRICT",durationHours:168,decayTo:"RULES"}
      }
    }
  '
}

ensure_modes_config_file() {
  if [ ! -s "$MODES_CONFIG_FILE" ]; then
    mode_default_config_json > "$MODES_CONFIG_FILE"
    return 0
  fi
  merged=$(jq -c --argjson defaults "$(mode_default_config_json)" '$defaults * .' "$MODES_CONFIG_FILE" 2>/dev/null || printf '')
  if [ -z "$merged" ]; then
    mode_default_config_json > "$MODES_CONFIG_FILE"
    return 0
  fi
  printf '%s\n' "$merged" > "$MODES_CONFIG_FILE"
}

ensure_relationships_file() {
  if [ ! -s "$RELATIONSHIPS_FILE" ]; then
    printf '[]\n' > "$RELATIONSHIPS_FILE"
    return 0
  fi
  if ! jq -e 'type == "array"' "$RELATIONSHIPS_FILE" >/dev/null 2>&1; then
    printf '[]\n' > "$RELATIONSHIPS_FILE"
  fi
}

read_modes_config_json() {
  ensure_modes_config_file
  cat "$MODES_CONFIG_FILE" 2>/dev/null || mode_default_config_json
}

save_modes_config_json() {
  raw=${1-}
  if [ -z "$raw" ]; then
    emit_error "save-modes-config requires JSON payload"
    return 1
  fi
  normalized=$(printf '%s' "$raw" | jq -c --argjson defaults "$(mode_default_config_json)" '
    (if type == "string" then (fromjson? // {}) else . end) as $in
    | if ($in | type) != "object" then empty else ($defaults * $in) end
  ' 2>/dev/null || printf '')
  if [ -z "$normalized" ]; then
    emit_error "invalid modes config JSON"
    return 1
  fi
  printf '%s\n' "$normalized" > "$MODES_CONFIG_FILE"
  jq -cn --argjson config "$normalized" '{ok:true,config:$config}'
}

mode_config_field() {
  path_expr=$1
  read_modes_config_json | jq -c "$path_expr" 2>/dev/null || printf 'null'
}

relationship_key() {
  raw=${1-}
  printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's#^[[:space:]]*##; s#[[:space:]]*$##'
}

find_mode_id_or_default() {
  requested=$1
  fallback=$(read_modes_config_json | jq -r '.startingMode // "SHADE"' 2>/dev/null || printf 'SHADE')
  [ -z "$fallback" ] && fallback="SHADE"
  if [ -z "$requested" ]; then
    printf '%s' "$fallback"
    return 0
  fi
  valid=$(read_modes_config_json | jq -r --arg id "$requested" '
    (.modes // [])
    | map(select((.id // "") == $id and (.enabled // true)))
    | if length > 0 then $id else "" end
  ' 2>/dev/null || printf '')
  if [ -n "$valid" ]; then
    printf '%s' "$requested"
  else
    printf '%s' "$fallback"
  fi
}

relationship_default_row() {
  user_id=$1
  mode_id=$(find_mode_id_or_default "")
  ts=$(now_iso)
  epoch=$(now_epoch)
  jq -cn \
    --arg user_id "$user_id" \
    --arg mode "$mode_id" \
    --arg ts "$ts" \
    --argjson epoch "$epoch" \
    '{
      user_id:$user_id,
      current_mode:$mode,
      set_at:$ts,
      set_at_epoch:$epoch,
      expires_at:null,
      expires_at_epoch:null,
      trigger:"starting-mode",
      interaction_count:0,
      valence_history:[],
      valence_summary:{rolling:0,lifetime:0}
    }'
}

relationship_get_or_create() {
  user_id=$(relationship_key "${1-}")
  if [ -z "$user_id" ]; then
    printf '{}'
    return 0
  fi
  ensure_relationships_file
  found=$(jq -c --arg uid "$user_id" '
    map(select((.user_id // "") == $uid))
    | if length > 0 then .[0] else empty end
  ' "$RELATIONSHIPS_FILE" 2>/dev/null || printf '')
  if [ -n "$found" ]; then
    printf '%s' "$found"
    return 0
  fi
  created=$(relationship_default_row "$user_id")
  jq -c --argjson row "$created" '. + [$row]' "$RELATIONSHIPS_FILE" > "$RELATIONSHIPS_FILE.tmp" 2>/dev/null || printf '[]' > "$RELATIONSHIPS_FILE.tmp"
  mv "$RELATIONSHIPS_FILE.tmp" "$RELATIONSHIPS_FILE"
  printf '%s' "$created"
}

relationship_upsert_row() {
  row=${1-}
  if [ -z "$row" ]; then
    return 1
  fi
  user_id=$(printf '%s' "$row" | jq -r '.user_id // empty' 2>/dev/null || printf '')
  [ -n "$user_id" ] || return 1
  ensure_relationships_file
  jq -c --arg uid "$user_id" --argjson row "$row" '
    (map(select((.user_id // "") != $uid))) + [$row]
    | sort_by(.user_id // "")
  ' "$RELATIONSHIPS_FILE" > "$RELATIONSHIPS_FILE.tmp" 2>/dev/null || return 1
  mv "$RELATIONSHIPS_FILE.tmp" "$RELATIONSHIPS_FILE"
  return 0
}

relationship_mode_expiry_resolve() {
  row=${1-}
  if [ -z "$row" ]; then
    printf '{}'
    return 0
  fi
  now=$(now_epoch)
  printf '%s' "$row" | jq -c --argjson now "$now" --argjson cfg "$(read_modes_config_json)" '
    def default_decay: ($cfg.defaultDecayMode // $cfg.startingMode // "SHADE");
    if ((.expires_at_epoch // 0) > 0 and (.expires_at_epoch // 0) <= $now) then
      .current_mode = ((.decay_to_mode // default_decay) | tostring)
      | .set_at = (now | todateiso8601)
      | .set_at_epoch = $now
      | .trigger = "mode-expired"
      | .expires_at = null
      | .expires_at_epoch = null
      | .decay_to_mode = null
    else
      .
    end
  ' 2>/dev/null || printf '%s' "$row"
}

relationship_set_mode_row() {
  row=${1-}
  to_mode=${2-}
  duration_hours=${3-0}
  decay_to=${4-}
  trigger=${5-manual}
  announce=${6-false}
  duration_hours=$(to_int "$duration_hours" 0)
  if [ "$duration_hours" -lt 0 ]; then
    duration_hours=0
  fi
  now=$(now_epoch)
  now_ts=$(now_iso)
  to_mode=$(find_mode_id_or_default "$to_mode")
  decay_mode=$(find_mode_id_or_default "$decay_to")
  printf '%s' "$row" | jq -c \
    --arg mode "$to_mode" \
    --arg trigger "$trigger" \
    --arg now_ts "$now_ts" \
    --arg decay_mode "$decay_mode" \
    --argjson now "$now" \
    --argjson duration_hours "$duration_hours" \
    --argjson announce "$announce" '
    .current_mode = $mode
    | .set_at = $now_ts
    | .set_at_epoch = $now
    | .trigger = $trigger
    | .announce = ($announce == true)
    | if $duration_hours > 0 then
        .expires_at_epoch = ($now + ($duration_hours * 3600))
        | .expires_at = (.expires_at_epoch | todateiso8601)
      else
        .expires_at = null
        | .expires_at_epoch = null
      end
    | .decay_to_mode = (if $decay_mode == "" then null else $decay_mode end)
  ' 2>/dev/null || printf '%s' "$row"
}

relationship_record_interaction_row() {
  row=${1-}
  valence=${2-0}
  comment_id=${3-}
  action_name=${4-}
  ts=$(now_iso)
  valence=$(to_int "$valence" 0)
  if [ "$valence" -gt 1 ]; then valence=1; fi
  if [ "$valence" -lt -1 ]; then valence=-1; fi
  printf '%s' "$row" | jq -c \
    --arg ts "$ts" \
    --arg comment_id "$comment_id" \
    --arg action "$action_name" \
    --argjson valence "$valence" '
      .interaction_count = ((.interaction_count // 0) + 1)
      | .valence_history = ((.valence_history // []) + [{ts:$ts,valence:$valence,comment_id:$comment_id,action:$action}])
      | .valence_history = (if (.valence_history | length) > 200 then .valence_history[-200:] else .valence_history end)
      | .valence_summary.rolling = (((.valence_history | if length > 12 then .[-12:] else . end) | map(.valence // 0) | add) // 0)
      | .valence_summary.lifetime = ((.valence_history | map(.valence // 0) | add) // 0)
    ' 2>/dev/null || printf '%s' "$row"
}

append_mode_log_event() {
  event_type=$1
  payload=${2-\{\}}
  ts=$(now_iso)
  epoch=$(now_epoch)
  line=$(jq -cn \
    --arg event "$event_type" \
    --arg ts "$ts" \
    --argjson ts_epoch "$epoch" \
    --arg subreddit "${SUBREDDIT-}" \
    --argjson payload "$payload" \
    '{event:$event,ts:$ts,ts_epoch:$ts_epoch,subreddit:$subreddit,payload:$payload}')
  append_jsonl "$MODE_LOG_FILE" "$line"
}

list_relationships_json() {
  limit=$(to_int "${1-300}" 300)
  [ "$limit" -lt 1 ] && limit=1
  ensure_relationships_file
  jq -cn --argjson rows "$(cat "$RELATIONSHIPS_FILE" 2>/dev/null || printf '[]')" --argjson limit "$limit" '
    {
      ok:true,
      relationships: (
        ($rows // [])
        | map(
            .valence_summary = (.valence_summary // {
              rolling: (((.valence_history // []) | if length > 12 then .[-12:] else . end | map(.valence // 0) | add) // 0),
              lifetime: (((.valence_history // []) | map(.valence // 0) | add) // 0)
            })
          )
        | sort_by(.set_at_epoch // 0)
        | reverse
        | .[0:$limit]
      )
    }
  '
}

set_relationship_json() {
  user_raw=${1-}
  mode_raw=${2-}
  duration_raw=${3-0}
  trigger_raw=${4-manual-override}
  if [ -z "$user_raw" ] || [ -z "$mode_raw" ]; then
    emit_error "set-relationship requires USER MODE [DURATION_HOURS] [TRIGGER]"
    return 1
  fi
  user_id=$(relationship_key "$user_raw")
  [ -n "$user_id" ] || { emit_error "invalid user"; return 1; }
  row=$(relationship_get_or_create "$user_id")
  row=$(relationship_mode_expiry_resolve "$row")
  duration=$(to_int "$duration_raw" 0)
  if [ "$duration" -lt 0 ]; then duration=0; fi
  row=$(relationship_set_mode_row "$row" "$mode_raw" "$duration" "" "$trigger_raw" true)
  relationship_upsert_row "$row" || { emit_error "failed to persist relationship"; return 1; }
  append_mode_log_event "relationship-override" "$(jq -cn --arg user "$user_id" --arg mode "$(printf '%s' "$row" | jq -r '.current_mode // ""')" --arg trigger "$trigger_raw" --argjson duration "$duration" '{user_id:$user,current_mode:$mode,trigger:$trigger,duration_hours:$duration}')"
  jq -cn --argjson relationship "$row" '{ok:true,relationship:$relationship}'
}

list_mode_log_json() {
  limit=$(to_int "${1-200}" 200)
  [ "$limit" -lt 1 ] && limit=1
  jq -cs --argjson limit "$limit" '
    sort_by(.ts_epoch // 0)
    | reverse
    | .[0:$limit]
    | {ok:true,events:.}
  ' "$MODE_LOG_FILE" 2>/dev/null || jq -cn '{ok:true,events:[]}'
}

mode_allows_action() {
  mode_id=${1-}
  action_name=${2-}
  read_modes_config_json | jq -r --arg mode "$mode_id" --arg action "$action_name" '
    (.modes // [])
    | map(select((.id // "") == $mode and (.enabled // true)))
    | if length == 0 then "false" else ((.[0].allow[$action] // false) | if . then "true" else "false" end) end
  ' 2>/dev/null || printf 'false'
}

mode_constraints_for() {
  mode_id=${1-}
  read_modes_config_json | jq -c --arg mode "$mode_id" '
    (.modes // [])
    | map(select((.id // "") == $mode and (.enabled // true)))
    | if length == 0 then {} else (.[0].constraints // {}) end
  ' 2>/dev/null || printf '{}'
}

mode_switch_rule_match() {
  comment_json=$1
  body_lc=$(printf '%s' "$comment_json" | jq -r '(.body // "") | ascii_downcase' 2>/dev/null || printf '')
  [ -n "$body_lc" ] || { printf '{}'; return 0; }
  read_modes_config_json | jq -c --arg body "$body_lc" '
    (.switchRules // [])
    | map(select(
        ((.matchAny // []) | map(tostring | ascii_downcase) | map(select(length > 0)) | any($body | contains(.)))
      ))
    | if length > 0 then .[0] else {} end
  ' 2>/dev/null || printf '{}'
}

ban_action_from_decision() {
  ban_type=${1-none}
  ban_days=${2-0}
  ban_type_lc=$(printf '%s' "$ban_type" | tr '[:upper:]' '[:lower:]')
  days=$(to_int "$ban_days" 0)
  if [ "$ban_type_lc" = "none" ]; then
    printf '%s' ''
    return 0
  fi
  if [ "$ban_type_lc" = "permanent" ]; then
    printf '%s' 'Permanent Ban'
    return 0
  fi
  if [ "$days" -le 3 ]; then
    printf '%s' 'Short Ban'
  elif [ "$days" -le 7 ]; then
    printf '%s' 'Medium Ban'
  elif [ "$days" -le 30 ]; then
    printf '%s' 'Long Ban'
  elif [ "$days" -le 183 ]; then
    printf '%s' 'Extended Ban'
  elif [ "$days" -le 365 ]; then
    printf '%s' 'Year Ban'
  else
    printf '%s' 'Permanent Ban'
  fi
}

ban_days_for_action() {
  action_name=${1-}
  case "$action_name" in
    "Short Ban") level=short ;;
    "Medium Ban") level=medium ;;
    "Long Ban") level=long ;;
    "Extended Ban") level=extended ;;
    "Year Ban") level=year ;;
    "Permanent Ban") level=permanent ;;
    *) printf '%s' '0'; return 0 ;;
  esac
  read_modes_config_json | jq -r --arg level "$level" '
    .banLevels[$level] as $x
    | if ($x.enabled // true) | not then "disabled"
      elif ($level == "permanent") then "permanent"
      else (($x.durationHours // 0) | tonumber? // 0 | if . <= 0 then 0 else (((. + 23) / 24) | floor) end | tostring)
      end
  ' 2>/dev/null || printf '0'
}

action_severity_score() {
  action_name=${1-}
  case "$action_name" in
    "Permanent Ban") printf '%s' '100' ;;
    "Year Ban") printf '%s' '95' ;;
    "Extended Ban") printf '%s' '90' ;;
    "Long Ban") printf '%s' '85' ;;
    "Medium Ban") printf '%s' '80' ;;
    "Short Ban") printf '%s' '75' ;;
    "Lock Thread") printf '%s' '68' ;;
    "Remove Content") printf '%s' '65' ;;
    "Warn") printf '%s' '50' ;;
    "Post Neutral Ban Notice") printf '%s' '45' ;;
    "Cross-thread Reply") printf '%s' '35' ;;
    "Followup") printf '%s' '30' ;;
    "Mention") printf '%s' '25' ;;
    "Quote") printf '%s' '20' ;;
    "Initiate") printf '%s' '18' ;;
    "Reply") printf '%s' '16' ;;
    *) printf '%s' '0' ;;
  esac
}

mode_restrictiveness_rank() {
  mode_id=${1-}
  read_modes_config_json | jq -r --arg mode "$mode_id" '
    (.restrictivenessOrder // []) as $ord
    | ($ord | index($mode)) as $idx
    | if $idx == null then 9999 else $idx end
  ' 2>/dev/null || printf '9999'
}

resolve_post_action_transition() {
  actions_json=${1-[]}
  modes_cfg=$(read_modes_config_json)
  printf '%s' "$actions_json" | jq -c --argjson cfg "$modes_cfg" '
    def severity($a):
      if $a == "Permanent Ban" then 100
      elif $a == "Year Ban" then 95
      elif $a == "Extended Ban" then 90
      elif $a == "Long Ban" then 85
      elif $a == "Medium Ban" then 80
      elif $a == "Short Ban" then 75
      elif $a == "Lock Thread" then 68
      elif $a == "Remove Content" then 65
      elif $a == "Warn" then 50
      else 0 end;
    def mode_rank($m):
      (($cfg.restrictivenessOrder // []) | index($m)) as $idx
      | if $idx == null then 9999 else $idx end;
    map({
      action: .,
      transition: (($cfg.postActionTransitions // {})[.] // null),
      score: severity(.)
    })
    | map(select(.transition != null and (.transition.toMode // "") != ""))
    | if length == 0 then null
      else sort_by([-(.score), mode_rank(.transition.toMode // "")]) | .[0]
      end
  ' 2>/dev/null || printf 'null'
}

relationship_valence_for_decision() {
  decision_json=$1
  printf '%s' "$decision_json" | jq -r '
    if (.ban.type // "none") != "none" or (.remove_comment // false) == true then "-1"
    elif ((.reply // "") | length) > 0 then "1"
    else "0"
    end
  ' 2>/dev/null || printf '0'
}

json_array_add_unique() {
  list_json=${1-[]}
  value=${2-}
  if [ -z "$value" ]; then
    printf '%s' "$list_json"
    return 0
  fi
  jq -cn --argjson list "$list_json" --arg value "$value" '$list + [$value] | unique'
}

json_array_has() {
  list_json=${1-[]}
  value=${2-}
  jq -e --arg value "$value" 'index($value) != null' >/dev/null 2>&1 <<EOFJSON
$list_json
EOFJSON
}

bootstrap_state() {
  mkdir -p "$STATE_DIR"
  touch "$BANS_LOG" "$REPLIES_LOG" "$ACTIONS_LOG" "$NORM_PROPOSALS_LOG" "$MODE_LOG_FILE"
  ensure_modes_config_file
  ensure_relationships_file

  if [ ! -f "$LAST_SEEN_FILE" ]; then
    printf '0\n' > "$LAST_SEEN_FILE"
  fi
  if [ ! -f "$LAST_STATUTE_SEEN_FILE" ]; then
    printf '0\n' > "$LAST_STATUTE_SEEN_FILE"
  fi

  if [ ! -f "$MANIFESTO_FILE" ]; then
    : > "$MANIFESTO_FILE"
  fi

  if [ ! -f "$NORMS_FILE" ]; then
    cp "$APP_DIR/norms.jsonl" "$NORMS_FILE" 2>/dev/null || : > "$NORMS_FILE"
  fi

  if [ ! -f "$BOT_ENV_FILE" ]; then
    cat > "$BOT_ENV_FILE" <<'BOTENV'
MODE=judicial
PATROL_MODE=full
PATROL_SAMPLE_MAX=20
PATROL_INTERVAL_MIN=35
PATROL_INTERVAL_MAX=95
THREAD_INITIATE_MAX_PCT=25
SANCTION_DELAY_MIN=7
SANCTION_DELAY_MAX=45
SUMMONS_ENABLED=1
NIGHTLY_STATUTE_ENABLED=1
NIGHTLY_HOUR=03
HIGH_SIGNAL_MIN_SCORE=6
AUTO_ACCEPT_NORMS=1
USER_HISTORY_LIMIT=40
THREAD_SIBLING_LIMIT=20
OBEY_ADMINS=0
OLLAMA_MODEL=llama3.1:8b
OLLAMA_URL=http://127.0.0.1:11434/api/generate
BOTENV
  fi

  if [ ! -f "$REDDIT_ENV_FILE" ]; then
    cat > "$REDDIT_ENV_FILE" <<'REDDITENV'
# Fill in Reddit app credentials for your dedicated moderator account.
REDDIT_CLIENT_ID=
REDDIT_CLIENT_SECRET=
REDDIT_REFRESH_TOKEN=
REDDIT_USER_AGENT=
REDDIT_USERNAME=
SUBREDDIT=
REDDITENV
  fi

  if [ ! -f "$GLOBAL_INSTRUCTIONS_FILE" ]; then
    mkdir -p "$(dirname "$GLOBAL_INSTRUCTIONS_FILE")"
    if [ -f "$APP_DIR/manifesto.md" ]; then
      cp "$APP_DIR/manifesto.md" "$GLOBAL_INSTRUCTIONS_FILE" 2>/dev/null || cat "$APP_DIR/manifesto.md" > "$GLOBAL_INSTRUCTIONS_FILE"
    else
      : > "$GLOBAL_INSTRUCTIONS_FILE"
    fi
  fi
}

load_bot_env() {
  # shellcheck disable=SC1090
  . "$BOT_ENV_FILE"

  MODE=${MODE:-judicial}
  PATROL_MODE=${PATROL_MODE:-full}
  PATROL_SAMPLE_MAX=$(to_int "${PATROL_SAMPLE_MAX:-20}" 20)
  PATROL_INTERVAL_MIN=$(to_int "${PATROL_INTERVAL_MIN:-35}" 35)
  PATROL_INTERVAL_MAX=$(to_int "${PATROL_INTERVAL_MAX:-95}" 95)
  THREAD_INITIATE_MAX_PCT=$(to_int "${THREAD_INITIATE_MAX_PCT:-25}" 25)
  SANCTION_DELAY_MIN=$(to_int "${SANCTION_DELAY_MIN:-7}" 7)
  SANCTION_DELAY_MAX=$(to_int "${SANCTION_DELAY_MAX:-45}" 45)
  SUMMONS_ENABLED=$(to_int "${SUMMONS_ENABLED:-1}" 1)
  NIGHTLY_STATUTE_ENABLED=$(to_int "${NIGHTLY_STATUTE_ENABLED:-1}" 1)
  NIGHTLY_HOUR=$(to_int "${NIGHTLY_HOUR:-3}" 3)
  HIGH_SIGNAL_MIN_SCORE=$(to_int "${HIGH_SIGNAL_MIN_SCORE:-6}" 6)
  AUTO_ACCEPT_NORMS=$(to_int "${AUTO_ACCEPT_NORMS:-1}" 1)
  USER_HISTORY_LIMIT=$(to_int "${USER_HISTORY_LIMIT:-40}" 40)
  THREAD_SIBLING_LIMIT=$(to_int "${THREAD_SIBLING_LIMIT:-20}" 20)
  OBEY_ADMINS=$(to_int "${OBEY_ADMINS:-0}" 0)
  OLLAMA_MODEL=${OLLAMA_MODEL:-llama3.1:8b}
  OLLAMA_URL=${OLLAMA_URL:-http://127.0.0.1:11434/api/generate}

  case "$MODE" in
    judicial|capricious|mixed) ;;
    *) MODE=judicial ;;
  esac

  case "$PATROL_MODE" in
    full|sample) ;;
    *) PATROL_MODE=full ;;
  esac

  [ "$PATROL_SAMPLE_MAX" -lt 1 ] && PATROL_SAMPLE_MAX=1
  [ "$PATROL_INTERVAL_MIN" -lt 3 ] && PATROL_INTERVAL_MIN=3
  [ "$PATROL_INTERVAL_MAX" -lt "$PATROL_INTERVAL_MIN" ] && PATROL_INTERVAL_MAX=$PATROL_INTERVAL_MIN
  [ "$THREAD_INITIATE_MAX_PCT" -lt 0 ] && THREAD_INITIATE_MAX_PCT=0
  [ "$THREAD_INITIATE_MAX_PCT" -gt 100 ] && THREAD_INITIATE_MAX_PCT=100
  [ "$SANCTION_DELAY_MIN" -lt 0 ] && SANCTION_DELAY_MIN=0
  [ "$SANCTION_DELAY_MAX" -lt "$SANCTION_DELAY_MIN" ] && SANCTION_DELAY_MAX=$SANCTION_DELAY_MIN
  [ "$USER_HISTORY_LIMIT" -lt 1 ] && USER_HISTORY_LIMIT=1
  [ "$THREAD_SIBLING_LIMIT" -lt 1 ] && THREAD_SIBLING_LIMIT=1
  [ "$OBEY_ADMINS" -ne 1 ] && OBEY_ADMINS=0
  return 0
}

require_env_value() {
  var_name=$1
  eval "var_value=\${$var_name-}"
  if [ -z "$var_value" ]; then
    printf '%s\n' "virtual-redditor-daemon: missing required $var_name in $REDDIT_ENV_FILE" >&2
    return 1
  fi
  return 0
}

identity_slug() {
  raw=${1-}
  slug=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9_-]#-#g; s#--*#-#g; s#^-##; s#-$##')
  printf '%s' "$slug"
}

default_reddit_user_agent() {
  username_raw=${1-}
  subreddit_raw=${2-}
  profile_raw=$(basename "$STATE_DIR" 2>/dev/null || printf 'single')

  username_safe=$(identity_slug "$username_raw")
  subreddit_safe=$(identity_slug "$subreddit_raw")
  profile_safe=$(identity_slug "$profile_raw")

  [ -z "$username_safe" ] && username_safe="virtual_redditor"
  [ -z "$subreddit_safe" ] && subreddit_safe="unknown"
  [ -z "$profile_safe" ] && profile_safe="single"

  printf 'script:virtual-redditor:%s:1.0 (by /u/%s; subreddit:r/%s)' "$profile_safe" "$username_safe" "$subreddit_safe"
}

is_generic_or_masked_user_agent() {
  ua=$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')
  case "$ua" in
    ""|virtual-redditor/0.1*|*subreddit-check*|*replace_me*|*by-u/*)
      return 0
      ;;
  esac
  return 1
}

load_reddit_env() {
  # shellcheck disable=SC1090
  . "$REDDIT_ENV_FILE"

  require_env_value REDDIT_CLIENT_ID || return 1
  require_env_value REDDIT_CLIENT_SECRET || return 1
  require_env_value REDDIT_REFRESH_TOKEN || return 1
  require_env_value REDDIT_USER_AGENT || return 1
  require_env_value REDDIT_USERNAME || return 1
  require_env_value SUBREDDIT || return 1
  if is_generic_or_masked_user_agent "$REDDIT_USER_AGENT"; then
    REDDIT_USER_AGENT=$(default_reddit_user_agent "$REDDIT_USERNAME" "$SUBREDDIT")
  fi
  return 0
}

load_reddit_env_optional() {
  if [ -f "$REDDIT_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$REDDIT_ENV_FILE" >/dev/null 2>&1 || true
  fi
  REDDIT_CLIENT_ID=${REDDIT_CLIENT_ID-}
  REDDIT_CLIENT_SECRET=${REDDIT_CLIENT_SECRET-}
  REDDIT_REFRESH_TOKEN=${REDDIT_REFRESH_TOKEN-}
  REDDIT_USER_AGENT=${REDDIT_USER_AGENT-}
  REDDIT_USERNAME=${REDDIT_USERNAME-}
  SUBREDDIT=${SUBREDDIT-}
  if is_generic_or_masked_user_agent "$REDDIT_USER_AGENT"; then
    REDDIT_USER_AGENT=$(default_reddit_user_agent "$REDDIT_USERNAME" "$SUBREDDIT")
  fi
  return 0
}

shell_quote_env_value() {
  raw=${1-}
  escaped=$(printf '%s' "$raw" | sed "s/'/'\"'\"'/g")
  printf "'%s'" "$escaped"
}

set_setting() {
  key=$1
  value=$2

  case "$key" in
    MODE|PATROL_MODE|PATROL_SAMPLE_MAX|PATROL_INTERVAL_MIN|PATROL_INTERVAL_MAX|THREAD_INITIATE_MAX_PCT|SANCTION_DELAY_MIN|SANCTION_DELAY_MAX|SUMMONS_ENABLED|NIGHTLY_STATUTE_ENABLED|NIGHTLY_HOUR|HIGH_SIGNAL_MIN_SCORE|AUTO_ACCEPT_NORMS|USER_HISTORY_LIMIT|THREAD_SIBLING_LIMIT|OBEY_ADMINS|OLLAMA_MODEL|OLLAMA_URL)
      ;;
    *)
      emit_error "unsupported setting key: $key"
      return 1
      ;;
  esac

  tmp=$(mktemp "${TMPDIR:-/tmp}/vr-botenv.XXXXXX")
  awk -F= -v k="$key" '$1 != k { print $0 }' "$BOT_ENV_FILE" > "$tmp"
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$BOT_ENV_FILE"

  load_bot_env
  settings_json
}

set_reddit_setting() {
  key=$1
  value=$2

  case "$key" in
    REDDIT_USERNAME|SUBREDDIT|REDDIT_USER_AGENT)
      ;;
    *)
      emit_error "unsupported reddit setting key: $key"
      return 1
      ;;
  esac

  tmp=$(mktemp "${TMPDIR:-/tmp}/vr-redditenv.XXXXXX")
  awk -F= -v k="$key" '$1 != k { print $0 }' "$REDDIT_ENV_FILE" > "$tmp"
  printf '%s=%s\n' "$key" "$(shell_quote_env_value "$value")" >> "$tmp"
  mv "$tmp" "$REDDIT_ENV_FILE"

  settings_json
}

settings_json() {
  jq -cn \
    --arg state_dir "$STATE_DIR" \
    --arg mode "$MODE" \
    --arg patrol_mode "$PATROL_MODE" \
    --argjson patrol_sample_max "$PATROL_SAMPLE_MAX" \
    --argjson patrol_interval_min "$PATROL_INTERVAL_MIN" \
    --argjson patrol_interval_max "$PATROL_INTERVAL_MAX" \
    --argjson thread_initiate_max_pct "$THREAD_INITIATE_MAX_PCT" \
    --argjson sanction_delay_min "$SANCTION_DELAY_MIN" \
    --argjson sanction_delay_max "$SANCTION_DELAY_MAX" \
    --argjson summons_enabled "$SUMMONS_ENABLED" \
    --argjson nightly_enabled "$NIGHTLY_STATUTE_ENABLED" \
    --argjson nightly_hour "$NIGHTLY_HOUR" \
    --argjson high_signal_min_score "$HIGH_SIGNAL_MIN_SCORE" \
    --argjson auto_accept_norms "$AUTO_ACCEPT_NORMS" \
    --argjson user_history_limit "$USER_HISTORY_LIMIT" \
    --argjson thread_sibling_limit "$THREAD_SIBLING_LIMIT" \
    --argjson obey_admins "$OBEY_ADMINS" \
    --arg ollama_model "$OLLAMA_MODEL" \
    --arg ollama_url "$OLLAMA_URL" \
    --arg subreddit "${SUBREDDIT-}" \
    --arg reddit_username "${REDDIT_USERNAME-}" \
    --arg manifesto_path "$MANIFESTO_FILE" \
    --arg norms_path "$NORMS_FILE" \
    --arg reddit_env_path "$REDDIT_ENV_FILE" \
    --arg bot_env_path "$BOT_ENV_FILE" \
    --arg actions_path "$ACTIONS_LOG" \
    --arg bans_path "$BANS_LOG" \
    --arg replies_path "$REPLIES_LOG" \
    --arg modes_path "$MODES_CONFIG_FILE" \
    --arg relationships_path "$RELATIONSHIPS_FILE" \
    --arg mode_log_path "$MODE_LOG_FILE" \
    --arg last_seen_path "$LAST_SEEN_FILE" \
    --arg daemon_log_path "$DAEMON_STDOUT_LOG" \
    --arg daemon_error_path "$DAEMON_STDERR_LOG" \
    '{ok:true,stateDir:$state_dir,mode:$mode,patrolMode:$patrol_mode,patrolSampleMax:$patrol_sample_max,patrolIntervalMin:$patrol_interval_min,patrolIntervalMax:$patrol_interval_max,threadInitiateMaxPct:$thread_initiate_max_pct,sanctionDelayMin:$sanction_delay_min,sanctionDelayMax:$sanction_delay_max,summonsEnabled:($summons_enabled==1),nightlyStatuteEnabled:($nightly_enabled==1),nightlyHour:$nightly_hour,highSignalMinScore:$high_signal_min_score,autoAcceptNorms:($auto_accept_norms==1),userHistoryLimit:$user_history_limit,threadSiblingLimit:$thread_sibling_limit,obeyAdmins:($obey_admins==1),ollamaModel:$ollama_model,ollamaUrl:$ollama_url,subreddit:$subreddit,redditUsername:$reddit_username,paths:{manifesto:$manifesto_path,norms:$norms_path,redditEnv:$reddit_env_path,botEnv:$bot_env_path,actions:$actions_path,bans:$bans_path,replies:$replies_path,modes:$modes_path,relationships:$relationships_path,modeLog:$mode_log_path,lastSeen:$last_seen_path,daemonLog:$daemon_log_path,daemonErrorLog:$daemon_error_path}}'
}

metrics_json() {
  actions_count=$(jq -s 'length' "$ACTIONS_LOG" 2>/dev/null || printf '0')
  bans_count=$(jq -s 'map(select((.type // "") == "ban" and (.event // "") == "enforce")) | length' "$BANS_LOG" 2>/dev/null || printf '0')
  replies_count=$(jq -s 'length' "$REPLIES_LOG" 2>/dev/null || printf '0')
  last_seen=$(to_int "$(cat "$LAST_SEEN_FILE" 2>/dev/null || printf '0')" 0)
  runtime='{}'
  if [ -f "$RUNTIME_FILE" ]; then
    runtime=$(cat "$RUNTIME_FILE" 2>/dev/null || printf '{}')
  fi

  jq -cn \
    --argjson actions_count "$(to_int "$actions_count" 0)" \
    --argjson bans_count "$(to_int "$bans_count" 0)" \
    --argjson replies_count "$(to_int "$replies_count" 0)" \
    --argjson last_seen "$last_seen" \
    --argjson runtime "$runtime" \
    '{ok:true,counts:{actions:$actions_count,bans:$bans_count,replies:$replies_count},lastSeen:$last_seen,runtime:$runtime}'
}

reddit_refresh_token() {
  response=$(curl -sS --fail \
    -u "$REDDIT_CLIENT_ID:$REDDIT_CLIENT_SECRET" \
    -H "User-Agent: $REDDIT_USER_AGENT" \
    -d "grant_type=refresh_token" \
    -d "refresh_token=$REDDIT_REFRESH_TOKEN" \
    https://www.reddit.com/api/v1/access_token)

  token=$(printf '%s' "$response" | jq -r '.access_token // empty')
  expires_in=$(printf '%s' "$response" | jq -r '.expires_in // 3600')
  expires_in=$(to_int "$expires_in" 3600)
  [ "$expires_in" -lt 120 ] && expires_in=120

  if [ -z "$token" ]; then
    printf '%s\n' "virtual-redditor-daemon: failed to obtain reddit access token" >&2
    return 1
  fi

  now=$(now_epoch)
  exp=$((now + expires_in - 90))

  printf '%s\n' "$token" > "$TOKEN_FILE"
  printf '%s\n' "$exp" > "$TOKEN_EXP_FILE"
  printf '%s' "$token"
}

reddit_access_token() {
  now=$(now_epoch)
  if [ -f "$TOKEN_FILE" ] && [ -f "$TOKEN_EXP_FILE" ]; then
    exp=$(to_int "$(cat "$TOKEN_EXP_FILE" 2>/dev/null || printf '0')" 0)
    if [ "$exp" -gt "$now" ]; then
      token=$(cat "$TOKEN_FILE" 2>/dev/null || printf '')
      if [ -n "$token" ]; then
        printf '%s' "$token"
        return 0
      fi
    fi
  fi

  reddit_refresh_token
}

reddit_get() {
  endpoint=$1
  token=$(reddit_access_token)

  curl -sS --fail --retry 2 --retry-delay 1 \
    -H "Authorization: bearer $token" \
    -H "User-Agent: $REDDIT_USER_AGENT" \
    "https://oauth.reddit.com$endpoint"
}

reddit_post() {
  endpoint=$1
  shift
  token=$(reddit_access_token)

  curl -sS --fail --retry 2 --retry-delay 1 \
    -X POST \
    -H "Authorization: bearer $token" \
    -H "User-Agent: $REDDIT_USER_AGENT" \
    "$@" \
    "https://oauth.reddit.com$endpoint"
}

parse_launchctl_pid() {
  file=$1
  awk '
    /pid =/ {
      for (i=1; i<=NF; i++) {
        if ($i == "=") {
          print $(i+1)
          exit
        }
      }
    }
  ' "$file" 2>/dev/null | tr -d ';'
}

subreddit_slug() {
  raw=${SUBREDDIT-}
  if [ -z "$raw" ]; then
    printf '%s' "unknown"
    return
  fi
  printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9_-]#-#g'
}

launchd_label() {
  printf 'com.wizardry.virtualredditor.%s' "$(subreddit_slug)"
}

launchd_plist_path() {
  printf '%s/Library/LaunchAgents/%s.plist' "$HOME" "$(launchd_label)"
}

launchd_status_json() {
  label=$(launchd_label)
  plist=$(launchd_plist_path)
  uid=$(id -u)

  if [ "$(uname -s 2>/dev/null || printf unknown)" != "Darwin" ] || ! command -v launchctl >/dev/null 2>&1; then
    jq -cn \
      --arg label "$label" \
      --arg plist "$plist" \
      '{ok:true,label:$label,plist:$plist,supported:false,installed:false,loaded:false,pid:null}'
    return 0
  fi

  installed=0
  loaded=0
  pid=''

  [ -f "$plist" ] && installed=1

  out_file=$(mktemp "${TMPDIR:-/tmp}/vr-launchctl.XXXXXX")
  if launchctl print "gui/$uid/$label" >"$out_file" 2>/dev/null; then
    loaded=1
    pid=$(parse_launchctl_pid "$out_file")
  fi
  rm -f "$out_file"

  jq -cn \
    --arg label "$label" \
    --arg plist "$plist" \
    --argjson installed "$installed" \
    --argjson loaded "$loaded" \
    --arg pid "$pid" \
    '{ok:true,label:$label,plist:$plist,installed:($installed==1),loaded:($loaded==1),pid:(if $pid=="" then null else ($pid|tonumber? // $pid) end)}'
}

launchd_install() {
  if [ "$(uname -s 2>/dev/null || printf unknown)" != "Darwin" ] || ! command -v launchctl >/dev/null 2>&1; then
    emit_error "launchd-install requires macOS launchctl"
    return 1
  fi

  label=$(launchd_label)
  plist=$(launchd_plist_path)
  uid=$(id -u)

  mkdir -p "$HOME/Library/LaunchAgents" "$STATE_DIR"

  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>$SCRIPT_DIR/virtual-redditor-daemon.sh</string>
    <string>run</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$STATE_DIR</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>VR_STATE_DIR</key>
    <string>$STATE_DIR</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$DAEMON_STDOUT_LOG</string>
  <key>StandardErrorPath</key>
  <string>$DAEMON_STDERR_LOG</string>
</dict>
</plist>
PLIST

  launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$uid" "$plist" >/dev/null 2>&1 || launchctl load "$plist" >/dev/null 2>&1 || true
  launchctl enable "gui/$uid/$label" >/dev/null 2>&1 || true
  launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>&1 || launchctl start "$label" >/dev/null 2>&1 || true

  launchd_status_json
}

launchd_start() {
  if [ "$(uname -s 2>/dev/null || printf unknown)" != "Darwin" ] || ! command -v launchctl >/dev/null 2>&1; then
    emit_error "launchd-start requires macOS launchctl"
    return 1
  fi

  label=$(launchd_label)
  plist=$(launchd_plist_path)
  uid=$(id -u)

  if [ ! -f "$plist" ]; then
    launchd_install >/dev/null
  else
    launchctl bootstrap "gui/$uid" "$plist" >/dev/null 2>&1 || true
    launchctl enable "gui/$uid/$label" >/dev/null 2>&1 || true
    launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>&1 || launchctl start "$label" >/dev/null 2>&1 || true
  fi

  launchd_status_json
}

launchd_stop() {
  if [ "$(uname -s 2>/dev/null || printf unknown)" != "Darwin" ] || ! command -v launchctl >/dev/null 2>&1; then
    emit_error "launchd-stop requires macOS launchctl"
    return 1
  fi

  label=$(launchd_label)
  plist=$(launchd_plist_path)
  uid=$(id -u)

  launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || launchctl remove "$label" >/dev/null 2>&1 || true
  launchd_status_json
}

launchd_uninstall() {
  if [ "$(uname -s 2>/dev/null || printf unknown)" != "Darwin" ] || ! command -v launchctl >/dev/null 2>&1; then
    emit_error "launchd-uninstall requires macOS launchctl"
    return 1
  fi

  plist=$(launchd_plist_path)

  launchd_stop >/dev/null 2>&1 || true
  rm -f "$plist"

  launchd_status_json
}

json_bool() {
  raw=${1-0}
  case "$raw" in
    1|true|TRUE|yes|YES) printf '%s' "true" ;;
    *) printf '%s' "false" ;;
  esac
}

is_summons_comment() {
  comment_json=$1
  if [ "$SUMMONS_ENABLED" -ne 1 ]; then
    printf '%s' "0"
    return
  fi

  uname=$(printf '%s' "$REDDIT_USERNAME" | tr '[:upper:]' '[:lower:]')
  if [ -z "$uname" ]; then
    printf '%s' "0"
    return
  fi

  hit=$(printf '%s' "$comment_json" | jq -r --arg uname "$uname" '
    ((.body // "") | ascii_downcase) as $b
    | if ($b | contains("/u/" + $uname)) or ($b | contains("u/" + $uname)) then "1" else "0" end
  ' 2>/dev/null || printf '0')

  case "$hit" in
    1) printf '%s' "1" ;;
    *) printf '%s' "0" ;;
  esac
}

comment_parent_is_bot() {
  cache_dir=$1
  comment_json=$2
  parent_id=$(printf '%s' "$comment_json" | jq -r '.parent_id // empty' 2>/dev/null || printf '')
  case "$parent_id" in
    t1_*) ;;
    *) printf '%s' "0"; return 0 ;;
  esac

  parent_payload=$(cached_reddit_get "$cache_dir" "parent-$parent_id" "/api/info.json?id=$parent_id&raw_json=1")
  parent_author=$(printf '%s' "$parent_payload" | jq -r '.data.children[0].data.author // empty' 2>/dev/null || printf '')
  if [ -n "$parent_author" ] && [ "$(printf '%s' "$parent_author" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$REDDIT_USERNAME" | tr '[:upper:]' '[:lower:]')" ]; then
    printf '%s' "1"
  else
    printf '%s' "0"
  fi
}

is_direct_engagement_comment() {
  cache_dir=$1
  comment_json=$2
  if [ "$(is_summons_comment "$comment_json")" = "1" ]; then
    printf '%s' "1"
    return 0
  fi
  comment_parent_is_bot "$cache_dir" "$comment_json"
}

thread_proactive_cap_allows() {
  cache_dir=$1
  comment_json=$2

  if [ "$THREAD_INITIATE_MAX_PCT" -ge 100 ]; then
    printf '%s' "1"
    return 0
  fi

  link_id=$(printf '%s' "$comment_json" | jq -r '.link_id // empty' 2>/dev/null || printf '')
  case "$link_id" in
    t3_*) ;;
    *) printf '%s' "1"; return 0 ;;
  esac
  post_id=${link_id#t3_}
  [ -n "$post_id" ] || { printf '%s' "1"; return 0; }

  thread_payload=$(cached_reddit_get "$cache_dir" "thread-$post_id" "/comments/$post_id/.json?limit=200&depth=6&raw_json=1&sort=new")
  replied_ids='[]'
  if [ -s "$REPLIES_LOG" ]; then
    replied_ids=$(jq -cs 'map(.comment_id // empty) | map(select(length > 0)) | unique' "$REPLIES_LOG" 2>/dev/null || printf '[]')
  fi

  stats=$(printf '%s' "$thread_payload" | jq -c --arg me "$(printf '%s' "$REDDIT_USERNAME" | tr '[:upper:]' '[:lower:]')" --argjson replied "$replied_ids" '
    [.. | objects | select(.kind? == "t1") | .data] as $all
    | ($all | map({key:(.name // ""), value:(.author // "")}) | from_entries) as $authors
    | ($all | map(select((.author // "") != "" and (.author // "") != "[deleted]" and (.author // "") != "[removed]" and ((.author // "") | ascii_downcase) != $me))) as $human
    | ($human | map(select((.name // "") as $id | ($replied | index($id)) != null))) as $replied_human
    | ($replied_human | map(select(
        (
          (((.body // "") | ascii_downcase) | contains("/u/" + $me))
          or
          (((.body // "") | ascii_downcase) | contains("u/" + $me))
        ) | not
      ))) as $not_mention
    | ($not_mention | map(select(
        (
          ((.parent_id // "") | startswith("t1_"))
          and
          (($authors[.parent_id] // "" | ascii_downcase) == $me)
        ) | not
      ))) as $proactive
    | {eligible:($human | length), proactive:($proactive | length)}
  ' 2>/dev/null || printf '{"eligible":0,"proactive":0}')

  eligible=$(printf '%s' "$stats" | jq -r '.eligible // 0' 2>/dev/null || printf '0')
  proactive=$(printf '%s' "$stats" | jq -r '.proactive // 0' 2>/dev/null || printf '0')
  eligible=$(to_int "$eligible" 0)
  proactive=$(to_int "$proactive" 0)
  if [ "$eligible" -le 0 ]; then
    printf '%s' "1"
    return 0
  fi
  max_proactive=$(awk -v n="$eligible" -v p="$THREAD_INITIATE_MAX_PCT" 'BEGIN { v=int((n*p)/100); if (v<0) v=0; printf "%d", v }')
  max_proactive=$(to_int "$max_proactive" 0)

  if [ "$proactive" -lt "$max_proactive" ]; then
    printf '%s' "1"
  else
    printf '%s' "0"
  fi
}

cache_key_safe() {
  printf '%s' "$1" | sed 's#[^A-Za-z0-9._-]#_#g'
}

cached_reddit_get() {
  cache_dir=$1
  key=$2
  endpoint=$3
  cache_file="$cache_dir/$(cache_key_safe "$key").json"

  if [ ! -f "$cache_file" ]; then
    if ! reddit_get "$endpoint" > "$cache_file" 2>/dev/null; then
      printf '{}' > "$cache_file"
    fi
  fi

  cat "$cache_file"
}

compose_context_envelope() {
  cache_dir=$1
  comment_json=$2
  relationship_json=${3-\{\}}

  comment_name=$(printf '%s' "$comment_json" | jq -r '.name // empty')
  parent_id=$(printf '%s' "$comment_json" | jq -r '.parent_id // empty')
  link_id=$(printf '%s' "$comment_json" | jq -r '.link_id // empty')
  author=$(printf '%s' "$comment_json" | jq -r '.author // empty')

  parent_json='{}'
  grandparent_json='{}'
  siblings_json='[]'
  author_recent_json='[]'
  author_top_json='[]'
  author_downvoted_json='[]'
  author_subreddit_json='[]'
  author_global_json='[]'

  if [ -n "$parent_id" ]; then
    parent_payload=$(cached_reddit_get "$cache_dir" "parent-$parent_id" "/api/info.json?id=$parent_id&raw_json=1")
    parent_json=$(printf '%s' "$parent_payload" | jq -c '.data.children[0].data // {}' 2>/dev/null || printf '{}')

    gp_id=$(printf '%s' "$parent_json" | jq -r '.parent_id // empty' 2>/dev/null || printf '')
    case "$gp_id" in
      t1_*)
        gp_payload=$(cached_reddit_get "$cache_dir" "gp-$gp_id" "/api/info.json?id=$gp_id&raw_json=1")
        grandparent_json=$(printf '%s' "$gp_payload" | jq -c '.data.children[0].data // {}' 2>/dev/null || printf '{}')
        ;;
    esac
  fi

  case "$link_id" in
    t3_*)
      post_id=${link_id#t3_}
      thread_payload=$(cached_reddit_get "$cache_dir" "thread-$post_id" "/comments/$post_id/.json?limit=120&depth=5&raw_json=1&sort=new")
      siblings_json=$(printf '%s' "$thread_payload" | jq -c --arg parent "$parent_id" --arg me "$comment_name" --argjson max "$THREAD_SIBLING_LIMIT" '
        [.. | objects | select(.kind? == "t1") | .data
          | select((.parent_id // "") == $parent and (.name // "") != $me)]
        | sort_by(.created_utc // 0)
        | if length > $max then .[length-$max:] else . end
      ' 2>/dev/null || printf '[]')
      ;;
  esac

  case "$author" in
    ''|"[deleted]"|"AutoModerator")
      :
      ;;
    *)
      author_recent_payload=$(cached_reddit_get "$cache_dir" "u-recent-$author" "/user/$author/comments/.json?limit=$USER_HISTORY_LIMIT&raw_json=1&sort=new")
      author_top_payload=$(cached_reddit_get "$cache_dir" "u-top-$author" "/user/$author/comments/.json?limit=$USER_HISTORY_LIMIT&raw_json=1&sort=top&t=month")

      author_recent_json=$(printf '%s' "$author_recent_payload" | jq -c '[.data.children[].data]' 2>/dev/null || printf '[]')
      author_top_json=$(printf '%s' "$author_top_payload" | jq -c '[.data.children[].data]' 2>/dev/null || printf '[]')
      author_downvoted_json=$(printf '%s' "$author_recent_json" | jq -c '[.[] | select((.score // 0) < 0)]' 2>/dev/null || printf '[]')
      author_subreddit_json=$(printf '%s' "$author_recent_json" | jq -c --arg sub "$SUBREDDIT" '[.[] | select(((.subreddit // "") | ascii_downcase) == ($sub | ascii_downcase))]' 2>/dev/null || printf '[]')
      author_global_json=$(printf '%s' "$author_recent_json" | jq -c --arg sub "$SUBREDDIT" '[.[] | select(((.subreddit // "") | ascii_downcase) != ($sub | ascii_downcase))] | .[0:15]' 2>/dev/null || printf '[]')
      ;;
  esac

  manifesto_text=$(cat "$MANIFESTO_FILE" 2>/dev/null || printf '')
  global_instructions_text=$(cat "$GLOBAL_INSTRUCTIONS_FILE" 2>/dev/null || printf '')
  norms_json=$(jq -cs '[.[]]' "$NORMS_FILE" 2>/dev/null || printf '[]')

  jq -cn \
    --arg mode "$MODE" \
    --arg subreddit "$SUBREDDIT" \
    --arg comment "$comment_json" \
    --arg parent "$parent_json" \
    --arg grandparent "$grandparent_json" \
    --arg siblings "$siblings_json" \
    --arg author_recent "$author_recent_json" \
    --arg author_top "$author_top_json" \
    --arg author_down "$author_downvoted_json" \
    --arg author_sub "$author_subreddit_json" \
    --arg author_global "$author_global_json" \
    --arg manifesto "$manifesto_text" \
    --arg global_instructions "$global_instructions_text" \
    --arg norms "$norms_json" \
    --arg relationship "$relationship_json" \
    '{
      mode:$mode,
      subreddit:$subreddit,
      doctrine:{global_instructions:$global_instructions, manifesto:$manifesto, norms:(($norms|fromjson?) // [])},
      utterance:($comment|fromjson),
      relationship:(($relationship|fromjson?) // {}),
      context:{
        parent:($parent|fromjson),
        grandparent:($grandparent|fromjson),
        siblings:(($siblings|fromjson?) // []),
        author:{
          recent:(($author_recent|fromjson?) // []),
          top:(($author_top|fromjson?) // []),
          downvoted:(($author_down|fromjson?) // []),
          subreddit:(($author_sub|fromjson?) // []),
          global:(($author_global|fromjson?) // [])
        }
      }
    }'
}

build_adjudication_prompt() {
  envelope_json=$1
  cat <<PROMPT
You are Virtual Redditor, the autonomous moderator and participant for r/$SUBREDDIT.

MODE: $MODE

Global default instructions (all virtual redditors):
$(cat "$GLOBAL_INSTRUCTIONS_FILE" 2>/dev/null || printf '')

Per-redditor instructions (manifesto.md):
$(cat "$MANIFESTO_FILE" 2>/dev/null || printf '')

Statutory doctrine (norms.jsonl):
$(cat "$NORMS_FILE" 2>/dev/null || printf '')

Required policy constraints:
- Judicial mode: bans only for explicit norm violations.
- Capricious mode: bans only for vibes (feeling string required).
- Mixed mode: bans may come from either pathway.
- Obey-admins mode: $(if [ "$OBEY_ADMINS" -eq 1 ]; then printf 'enabled. If subreddit admins issue a relevant instruction in context, follow it unless impossible or unsafe.'; else printf 'disabled.'; fi)
- The `relationship.current_mode` field in context is authoritative for per-user permissions.
- Never attempt actions that are disallowed by the relationship mode.
- If banning, include a reply first. The system performs reply->delay->ban ritual.
- Reply text must be concise and sub-native in style.
- Judicial bans: reply must clearly cite the violated norm.
- Capricious bans: reply must include a feeling-string.
- Mixed bans: reply should reflect whichever causal pathway fired.

Return STRICT JSON only, no markdown, with this shape:
{
  "reply": "string",
  "category": "playful|didactic|topical|obscure|enforcement",
  "actions": ["Reply","Warn","Short Ban"],
  "ban": {"type":"none|temporary|permanent","days":3},
  "remove_comment": false,
  "norm": "optional norm id or norm quote",
  "feeling": "optional feeling-string",
  "reasoning": "brief rationale"
}

Context envelope JSON:
$envelope_json
PROMPT
}

normalize_decision_json() {
  raw_response=$1

  raw_content=$(printf '%s' "$raw_response" | jq -r '.response // empty' 2>/dev/null || printf '')
  if [ -z "$raw_content" ]; then
    raw_content=$(printf '%s' "$raw_response")
  fi

  normalized=$(printf '%s' "$raw_content" | jq -c '
    def text(v): if v == null then "" else (v|tostring) end;
    def boolish(v):
      if v == null then false
      elif (v|type) == "boolean" then v
      else ((v|tostring|ascii_downcase) | test("^(1|true|yes)$"))
      end;
    def ban_kind(v):
      (text(v)|ascii_downcase) as $b
      | if ($b|test("perm")) then "permanent"
        elif ($b|test("temp|short|time")) then "temporary"
        else "none" end;

    {
      reply: text(.reply // .message // .response),
      category: text(.category // .tone // "playful"),
      actions: (if (.actions | type) == "array" then (.actions | map(text(.))) else [] end),
      norm: text(.norm // .rule // .violation_norm),
      feeling: text(.feeling // .affect // .emotion),
      reasoning: text(.reasoning // .reason // .rationale),
      remove_comment: boolish(.remove_comment // .remove // false),
      ban: {
        type: ban_kind(.ban.type // .ban // .ban_kind // .sanction),
        days: ((.ban.days // .ban_days // .duration // 3) | tonumber? // 3)
      }
    }
  ' 2>/dev/null || printf '{"reply":"","category":"playful","actions":[],"norm":"","feeling":"","reasoning":"","remove_comment":false,"ban":{"type":"none","days":3}}')

  printf '%s' "$normalized"
}

apply_mode_policy() {
  decision_json=$1

  adjusted=$(printf '%s' "$decision_json" | jq -c --arg mode "$MODE" '
    .ban.days = ((.ban.days | tonumber? // 3) | if . < 1 then 1 elif . > 3650 then 3650 else . end)
    | .pathway = (if (.norm | length) > 0 then "norm" elif (.feeling | length) > 0 then "feeling" else "none" end)
    | if $mode == "judicial" then
        if .pathway == "norm" then . else .ban.type = "none" | .remove_comment = false end
      elif $mode == "capricious" then
        if .pathway == "feeling" then . else .ban.type = "none" | .remove_comment = false end
      else
        if .pathway == "none" then .ban.type = "none" | .remove_comment = false else . end
      end
    | if .ban.type != "none" then .remove_comment = false else . end
    | .needs_enforcement = (.ban.type != "none" or .remove_comment == true)
    | if (.needs_enforcement and (.reply | length) == 0) then
        .reply = "Moderator notice: this comment triggered an enforcement action."
      else . end
    | if ($mode == "judicial" and .ban.type != "none" and (.norm | length) > 0 and ((.reply | ascii_downcase) | contains((.norm | ascii_downcase)) | not)) then
        .reply = (.reply + " (Norm: " + .norm + ")")
      else . end
    | if ($mode == "capricious" and .ban.type != "none" and (.feeling | length) > 0 and ((.reply | ascii_downcase) | contains((.feeling | ascii_downcase)) | not)) then
        .reply = (.reply + " [Feeling: " + .feeling + "]")
      else . end
    | if ($mode == "mixed" and .ban.type != "none") then
        if (.pathway == "norm" and (.norm | length) > 0 and ((.reply | ascii_downcase) | contains((.norm | ascii_downcase)) | not)) then
          .reply = (.reply + " (Norm: " + .norm + ")")
        elif (.pathway == "feeling" and (.feeling | length) > 0 and ((.reply | ascii_downcase) | contains((.feeling | ascii_downcase)) | not)) then
          .reply = (.reply + " [Feeling: " + .feeling + "]")
        else . end
      else . end
  ')

  printf '%s' "$adjusted"
}

ollama_generate() {
  prompt=$1
  payload=$(jq -cn --arg model "$OLLAMA_MODEL" --arg prompt "$prompt" '{model:$model,prompt:$prompt,stream:false,format:"json"}')
  curl -sS --fail --retry 1 --retry-delay 1 \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "$OLLAMA_URL"
}

truncate_reply() {
  reply_text=$1
  printf '%s' "$reply_text" | awk '{print substr($0,1,9500)}'
}

post_reply() {
  thing_id=$1
  reply_text=$2

  response=$(reddit_post "/api/comment" \
    --data-urlencode "api_type=json" \
    --data-urlencode "thing_id=$thing_id" \
    --data-urlencode "text=$reply_text") || return 1

  errors=$(printf '%s' "$response" | jq -c '.json.errors // []' 2>/dev/null || printf '[]')
  if [ "$errors" != "[]" ]; then
    return 1
  fi

  reply_id=$(printf '%s' "$response" | jq -r '.json.data.things[0].data.name // empty' 2>/dev/null || printf '')
  if [ -z "$reply_id" ]; then
    return 1
  fi

  printf '%s' "$reply_id"
}

post_temp_or_perm_ban() {
  username=$1
  ban_type=$2
  ban_days=$3
  note=$4

  if [ "$ban_type" = "temporary" ]; then
    response=$(reddit_post "/r/$SUBREDDIT/api/friend" \
      --data-urlencode "api_type=json" \
      --data-urlencode "name=$username" \
      --data-urlencode "type=banned" \
      --data-urlencode "duration=$ban_days" \
      --data-urlencode "ban_reason=Automated moderation" \
      --data-urlencode "note=$note") || return 1
  else
    response=$(reddit_post "/r/$SUBREDDIT/api/friend" \
      --data-urlencode "api_type=json" \
      --data-urlencode "name=$username" \
      --data-urlencode "type=banned" \
      --data-urlencode "ban_reason=Automated moderation" \
      --data-urlencode "note=$note") || return 1
  fi

  errors=$(printf '%s' "$response" | jq -c '.json.errors // []' 2>/dev/null || printf '[]')
  [ "$errors" = "[]" ]
}

post_remove_comment() {
  thing_id=$1
  response=$(reddit_post "/api/remove" \
    --data-urlencode "id=$thing_id" \
    --data-urlencode "spam=false") || return 1

  jq -e '.json.errors? // [] | length == 0' >/dev/null 2>&1 <<EOFJSON
$response
EOFJSON
}

post_lock_thread() {
  thing_id=$1
  response=$(reddit_post "/api/lock" \
    --data-urlencode "id=$thing_id") || return 1

  jq -e '.json.errors? // [] | length == 0' >/dev/null 2>&1 <<EOFJSON
$response
EOFJSON
}

check_already_replied() {
  thing_id=$1
  if [ ! -s "$REPLIES_LOG" ]; then
    return 1
  fi
  jq -e --arg cid "$thing_id" 'select((.comment_id // "") == $cid)' "$REPLIES_LOG" >/dev/null 2>&1
}

record_reply_event() {
  comment_json=$1
  reply_id=$2
  reply_text=$3
  category=$4
  decision_json=$5
  source=$6

  ts=$(now_iso)
  ts_epoch=$(now_epoch)
  reply_event_id=$(new_event_id "reply")

  event=$(jq -cn \
    --arg event "reply" \
    --arg reply_event_id "$reply_event_id" \
    --arg ts "$ts" \
    --argjson ts_epoch "$ts_epoch" \
    --arg subreddit "$SUBREDDIT" \
    --arg mode "$MODE" \
    --arg comment "$comment_json" \
    --arg reply_id "$reply_id" \
    --arg reply_text "$reply_text" \
    --arg category "$category" \
    --arg decision "$decision_json" \
    --arg source "$source" \
    '{event:$event,reply_event_id:$reply_event_id,ts:$ts,ts_epoch:$ts_epoch,subreddit:$subreddit,mode:$mode,source:$source,comment_id:(($comment|fromjson).name // ""),comment_link_id:(($comment|fromjson).link_id // ""),comment_author:(($comment|fromjson).author // ""),reply_id:$reply_id,reply:$reply_text,category:$category,decision:(($decision|fromjson? // {}))}')

  append_jsonl "$REPLIES_LOG" "$event"
}

record_action_event() {
  action_json=$1
  append_jsonl "$ACTIONS_LOG" "$action_json"

  action_type=$(printf '%s' "$action_json" | jq -r '.type // empty' 2>/dev/null || printf '')
  if [ "$action_type" = "ban" ]; then
    append_jsonl "$BANS_LOG" "$action_json"
  fi
}

process_comment() {
  cache_dir=$1
  comment_json=$2

  author=$(printf '%s' "$comment_json" | jq -r '.author // empty')
  thing_id=$(printf '%s' "$comment_json" | jq -r '.name // empty')
  link_id=$(printf '%s' "$comment_json" | jq -r '.link_id // empty')
  author_key=$(relationship_key "$author")

  case "$thing_id" in
    t1_*) ;;
    *) return 0 ;;
  esac

  case "$author" in
    ''|"[deleted]"|"[removed]") return 0 ;;
  esac

  if [ "$author" = "$REDDIT_USERNAME" ]; then
    return 0
  fi

  if check_already_replied "$thing_id"; then
    return 0
  fi

  reply_source="proactive"
  if [ "$(is_direct_engagement_comment "$cache_dir" "$comment_json")" = "1" ]; then
    reply_source="engaged"
  elif [ "$(thread_proactive_cap_allows "$cache_dir" "$comment_json")" != "1" ]; then
    return 0
  fi

  relationship_row=$(relationship_get_or_create "$author_key")
  relationship_row=$(relationship_mode_expiry_resolve "$relationship_row")
  relationship_upsert_row "$relationship_row" || :
  current_mode=$(printf '%s' "$relationship_row" | jq -r '.current_mode // empty' 2>/dev/null || printf '')
  current_mode=$(find_mode_id_or_default "$current_mode")

  switch_rule=$(mode_switch_rule_match "$comment_json")
  switch_to_mode=$(printf '%s' "$switch_rule" | jq -r '.toMode // empty' 2>/dev/null || printf '')
  if [ -n "$switch_to_mode" ]; then
    rule_id=$(printf '%s' "$switch_rule" | jq -r '.id // "switch-rule"' 2>/dev/null || printf 'switch-rule')
    duration=$(printf '%s' "$switch_rule" | jq -r '.durationHours // 0' 2>/dev/null || printf '0')
    duration=$(to_int "$duration" 0)
    decay_to=$(printf '%s' "$switch_rule" | jq -r '.decayTo // empty' 2>/dev/null || printf '')
    announce=$(printf '%s' "$switch_rule" | jq -r '.announce // true' 2>/dev/null || printf 'true')
    announce_bool=false
    [ "$announce" = "true" ] && announce_bool=true
    previous_mode=$current_mode
    relationship_row=$(relationship_set_mode_row "$relationship_row" "$switch_to_mode" "$duration" "$decay_to" "switch-rule:$rule_id" "$announce_bool")
    relationship_upsert_row "$relationship_row" || :
    current_mode=$(printf '%s' "$relationship_row" | jq -r '.current_mode // empty' 2>/dev/null || printf '')
    current_mode=$(find_mode_id_or_default "$current_mode")
    append_mode_log_event "switch-rule" "$(jq -cn --arg user "$author_key" --arg from "$previous_mode" --arg to "$current_mode" --arg rule "$rule_id" --arg comment_id "$thing_id" '{user_id:$user,from_mode:$from,to_mode:$to,rule_id:$rule,comment_id:$comment_id}')"

    if [ "$announce_bool" = true ] && [ "$(mode_allows_action "$current_mode" "Post Neutral Ban Notice")" = "true" ]; then
      notice=$(printf '%s' "$switch_rule" | jq -r '.template // empty' 2>/dev/null || printf '')
      if [ -n "$notice" ]; then
        if notice_reply_id=$(post_reply "$thing_id" "$notice" 2>/dev/null); then
          rule_decision=$(jq -cn --arg rule "$rule_id" --arg mode "$current_mode" '{rule:$rule,toMode:$mode}')
          record_reply_event "$comment_json" "$notice_reply_id" "$notice" "switch-rule" "$rule_decision" "switch-rule"
        fi
      fi
    fi
    return 0
  fi

  envelope=$(compose_context_envelope "$cache_dir" "$comment_json" "$relationship_row")
  prompt=$(build_adjudication_prompt "$envelope")

  if ! model_response=$(ollama_generate "$prompt" 2>/dev/null); then
    return 0
  fi

  decision=$(normalize_decision_json "$model_response")
  decision=$(apply_mode_policy "$decision")

  reply_text=$(printf '%s' "$decision" | jq -r '.reply // empty')
  category=$(printf '%s' "$decision" | jq -r '.category // "playful"')
  model_actions=$(printf '%s' "$decision" | jq -c '.actions // []' 2>/dev/null || printf '[]')
  ban_type=$(printf '%s' "$decision" | jq -r '.ban.type // "none"')
  ban_days=$(printf '%s' "$decision" | jq -r '.ban.days // 3')
  remove_comment=$(printf '%s' "$decision" | jq -r '.remove_comment // false')
  norm=$(printf '%s' "$decision" | jq -r '.norm // empty')
  feeling=$(printf '%s' "$decision" | jq -r '.feeling // empty')
  pathway=$(printf '%s' "$decision" | jq -r '.pathway // "none"' 2>/dev/null || printf 'none')
  reasoning=$(printf '%s' "$decision" | jq -r '.reasoning // empty' 2>/dev/null || printf '')

  proposed_actions='[]'
  if [ -n "$reply_text" ]; then
    if [ "$reply_source" = "engaged" ]; then
      proposed_actions=$(json_array_add_unique "$proposed_actions" "Reply")
    else
      proposed_actions=$(json_array_add_unique "$proposed_actions" "Initiate")
    fi
  fi
  for model_action in $(printf '%s' "$model_actions" | jq -r '.[]' 2>/dev/null); do
    [ -n "$model_action" ] || continue
    proposed_actions=$(json_array_add_unique "$proposed_actions" "$model_action")
  done
  ban_action_requested=$(ban_action_from_decision "$ban_type" "$ban_days")
  if [ -n "$ban_action_requested" ]; then
    proposed_actions=$(json_array_add_unique "$proposed_actions" "$ban_action_requested")
  fi
  if [ "$remove_comment" = "true" ]; then
    proposed_actions=$(json_array_add_unique "$proposed_actions" "Remove Content")
  fi

  norm_severity=$(jq -rs --arg norm "$norm" '
    if ($norm | length) == 0 then "low"
    else
      (map(select(((.id // "") == $norm) or ((.text // "") == $norm)))[0].severity // "low")
    end
  ' "$NORMS_FILE" 2>/dev/null || printf 'low')
  escalation_on_high=$(read_modes_config_json | jq -r '.escalation.onHighSeverity // false' 2>/dev/null || printf 'false')
  escalation_targets=$(read_modes_config_json | jq -r '.escalation.targets // "modmail"' 2>/dev/null || printf 'modmail')
  escalation_timing=$(read_modes_config_json | jq -r '.escalation.timing // "enforce_then_escalate"' 2>/dev/null || printf 'enforce_then_escalate')
  escalation_active=false
  if [ "$norm_severity" = "high" ] && [ "$escalation_on_high" = "true" ]; then
    escalation_active=true
  fi
  if [ "$escalation_active" = true ] && [ "$escalation_timing" = "escalate_immediately" ]; then
    append_mode_log_event "escalation" "$(jq -cn --arg user "$author_key" --arg norm "$norm" --arg action "pending" --arg content "$(printf '%s' "$comment_json" | jq -r '.body // ""')" --arg link "$(printf '%s' "$comment_json" | jq -r '.permalink // empty')" --arg severity "$norm_severity" --arg timing "$escalation_timing" --arg targets "$escalation_targets" '{user_id:$user,norm:$norm,action:$action,content:$content,thread_link:$link,severity:$severity,timing:$timing,targets:$targets}')"
  fi

  allowed_actions='[]'
  blocked_actions='[]'
  for action_name in $(printf '%s' "$proposed_actions" | jq -r '.[]' 2>/dev/null); do
    [ -n "$action_name" ] || continue
    if [ "$(mode_allows_action "$current_mode" "$action_name")" = "true" ]; then
      allowed_actions=$(json_array_add_unique "$allowed_actions" "$action_name")
    else
      blocked_actions=$(json_array_add_unique "$blocked_actions" "$action_name")
    fi
  done
  if [ "$(printf '%s' "$blocked_actions" | jq 'length' 2>/dev/null || printf '0')" -gt 0 ]; then
    append_mode_log_event "blocked-actions" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --argjson blocked "$blocked_actions" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,blocked:$blocked,comment_id:$comment_id}')"
  fi

  lock_target=''
  if json_array_has "$allowed_actions" "Lock Thread"; then
    case "$link_id" in
      t3_*)
        lock_target=$link_id
        ;;
      *)
        append_mode_log_event "blocked-actions" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg action "Lock Thread" --arg reason "invalid-lock-target" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,action:$action,reason:$reason,comment_id:$comment_id}')"
        ;;
    esac
  fi

  warning_template=$(read_modes_config_json | jq -r '.replies.warningTemplate // empty' 2>/dev/null || printf '')
  neutral_template=$(read_modes_config_json | jq -r '.replies.neutralBanTemplate // empty' 2>/dev/null || printf '')
  if [ -z "$reply_text" ] && json_array_has "$allowed_actions" "Warn"; then
    reply_text=$warning_template
  fi
  if [ -z "$reply_text" ] && json_array_has "$allowed_actions" "Post Neutral Ban Notice"; then
    reply_text=$neutral_template
  fi

  constraints=$(mode_constraints_for "$current_mode")
  max_replies=$(printf '%s' "$constraints" | jq -r '.maxRepliesPerUserThread24h // -1' 2>/dev/null || printf '-1')
  max_replies=$(to_int "$max_replies" -1)
  no_followup=$(printf '%s' "$constraints" | jq -r '.noFollowup // false' 2>/dev/null || printf 'false')
  no_mention=$(printf '%s' "$constraints" | jq -r '.noMention // false' 2>/dev/null || printf 'false')
  no_quote=$(printf '%s' "$constraints" | jq -r '.noQuote // false' 2>/dev/null || printf 'false')

  should_reply=false
  if [ -n "$reply_text" ]; then
    if json_array_has "$allowed_actions" "Warn" || json_array_has "$allowed_actions" "Reply" || json_array_has "$allowed_actions" "Initiate" || json_array_has "$allowed_actions" "Post Neutral Ban Notice"; then
      should_reply=true
    fi
  fi

  if [ "$should_reply" = true ] && [ "$max_replies" -ge 0 ] && [ -n "$link_id" ]; then
    cutoff=$(( $(now_epoch) - 86400 ))
    recent_replies=$(jq -cs --arg user "$author_key" --arg link "$link_id" --argjson cutoff "$cutoff" '
      map(select(((.comment_author // "") | ascii_downcase) == $user and (.comment_link_id // "") == $link and (.ts_epoch // 0) >= $cutoff))
      | length
    ' "$REPLIES_LOG" 2>/dev/null || printf '0')
    recent_replies=$(to_int "$recent_replies" 0)
    if [ "$recent_replies" -ge "$max_replies" ]; then
      should_reply=false
      append_mode_log_event "constraint-hit" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg constraint "max-replies-24h" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,constraint:$constraint,comment_id:$comment_id}')"
    fi
  fi

  if [ "$should_reply" = true ] && [ "$no_followup" = "true" ] && [ "$reply_source" = "engaged" ]; then
    should_reply=false
    append_mode_log_event "constraint-hit" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg constraint "no-followup" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,constraint:$constraint,comment_id:$comment_id}')"
  fi

  author_lc=$(printf '%s' "$author_key" | tr '[:upper:]' '[:lower:]')
  reply_lc=$(printf '%s' "$reply_text" | tr '[:upper:]' '[:lower:]')
  if [ "$should_reply" = true ] && [ "$no_mention" = "true" ]; then
    case "$reply_lc" in
      *"/u/$author_lc"*|*"u/$author_lc"*)
        should_reply=false
        append_mode_log_event "constraint-hit" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg constraint "no-mention" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,constraint:$constraint,comment_id:$comment_id}')"
        ;;
    esac
  fi

  if [ "$should_reply" = true ] && [ "$no_quote" = "true" ]; then
    if printf '%s\n' "$reply_text" | grep -Eq '^[[:space:]]*>' ; then
      should_reply=false
      append_mode_log_event "constraint-hit" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg constraint "no-quote" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,constraint:$constraint,comment_id:$comment_id}')"
    fi
  fi

  selected_ban_action=''
  for candidate in "Permanent Ban" "Year Ban" "Extended Ban" "Long Ban" "Medium Ban" "Short Ban"; do
    if json_array_has "$allowed_actions" "$candidate"; then
      selected_ban_action=$candidate
      break
    fi
  done

  ban_type_exec='none'
  ban_days_exec=0
  if [ -n "$selected_ban_action" ]; then
    ban_days_setting=$(ban_days_for_action "$selected_ban_action")
    case "$ban_days_setting" in
      disabled)
        append_mode_log_event "blocked-actions" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg action "$selected_ban_action" --arg reason "ban-level-disabled" --arg comment_id "$thing_id" '{user_id:$user,mode:$mode,action:$action,reason:$reason,comment_id:$comment_id}')"
        selected_ban_action=''
        ;;
      permanent)
        ban_type_exec='permanent'
        ban_days_exec=0
        ;;
      *)
        ban_type_exec='temporary'
        ban_days_exec=$(to_int "$ban_days_setting" 0)
        if [ "$ban_days_exec" -lt 1 ]; then
          ban_type_exec='none'
          selected_ban_action=''
        fi
        ;;
    esac
  fi

  remove_exec=false
  if json_array_has "$allowed_actions" "Remove Content"; then
    if [ "$ban_type_exec" = "none" ]; then
      remove_exec=true
    fi
  fi

  reply_id=''
  if [ "$should_reply" = true ] && [ -n "$reply_text" ]; then
    reply_text=$(truncate_reply "$reply_text")
    if reply_id=$(post_reply "$thing_id" "$reply_text" 2>/dev/null); then
      record_reply_event "$comment_json" "$reply_id" "$reply_text" "$category" "$decision" "$reply_source"
    else
      reply_id=''
    fi
  fi

  executed_actions='[]'
  if [ -n "$reply_id" ]; then
    if json_array_has "$allowed_actions" "Warn"; then
      executed_actions=$(json_array_add_unique "$executed_actions" "Warn")
    elif [ "$reply_source" = "engaged" ]; then
      executed_actions=$(json_array_add_unique "$executed_actions" "Reply")
    else
      executed_actions=$(json_array_add_unique "$executed_actions" "Initiate")
    fi
  fi

  action_id=$(new_event_id "action")
  ts=$(now_iso)
  ts_epoch=$(now_epoch)
  permalink=$(printf '%s' "$comment_json" | jq -r '.permalink // empty')

  if [ "$ban_type_exec" != "none" ]; then
    if [ -z "$reply_id" ]; then
      action=$(jq -cn \
        --arg event "enforce" \
        --arg action_id "$action_id" \
        --arg ts "$ts" \
        --argjson ts_epoch "$ts_epoch" \
        --arg status "failed" \
        --arg error "ban blocked: no direct pre-ban reply" \
        --arg type "ban" \
        --arg ban_type "$ban_type_exec" \
        --argjson ban_days "$ban_days_exec" \
        --arg subreddit "$SUBREDDIT" \
        --arg mode "$current_mode" \
        --arg pathway "$pathway" \
        --arg norm "$norm" \
        --arg feeling "$feeling" \
        --arg reasoning "$reasoning" \
        --arg comment "$comment_json" \
        --arg permalink "$permalink" \
        '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,error:$error,type:$type,ban_type:$ban_type,ban_days:$ban_days,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,reply_id:null,undoable:false}')
      record_action_event "$action"
    else
      ban_jitter_min=$(read_modes_config_json | jq -r '.behaviors.banJitterSec.min // empty' 2>/dev/null || printf '')
      ban_jitter_max=$(read_modes_config_json | jq -r '.behaviors.banJitterSec.max // empty' 2>/dev/null || printf '')
      ban_jitter_min=$(to_int "${ban_jitter_min:-$SANCTION_DELAY_MIN}" "$SANCTION_DELAY_MIN")
      ban_jitter_max=$(to_int "${ban_jitter_max:-$SANCTION_DELAY_MAX}" "$SANCTION_DELAY_MAX")
      delay=$(random_between "$ban_jitter_min" "$ban_jitter_max")
      if [ "$delay" -gt 0 ]; then
        sleep "$delay"
      fi

      ban_note=$(printf 'mode=%s pathway=%s norm=%s feeling=%s relationship_mode=%s' "$MODE" "$pathway" "$norm" "$feeling" "$current_mode")
      if post_temp_or_perm_ban "$author" "$ban_type_exec" "$ban_days_exec" "$ban_note"; then
        action=$(jq -cn \
          --arg event "enforce" \
          --arg action_id "$action_id" \
          --arg ts "$ts" \
          --argjson ts_epoch "$ts_epoch" \
          --arg status "active" \
          --arg type "ban" \
          --arg ban_type "$ban_type_exec" \
          --argjson ban_days "$ban_days_exec" \
          --arg subreddit "$SUBREDDIT" \
          --arg mode "$current_mode" \
          --arg pathway "$pathway" \
          --arg norm "$norm" \
          --arg feeling "$feeling" \
          --arg reasoning "$reasoning" \
          --arg comment "$comment_json" \
          --arg permalink "$permalink" \
          --arg reply_id "$reply_id" \
          '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,type:$type,ban_type:$ban_type,ban_days:$ban_days,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,reply_id:$reply_id,undoable:true,undone_at:null}')
        record_action_event "$action"
        executed_actions=$(json_array_add_unique "$executed_actions" "$selected_ban_action")
      else
        action=$(jq -cn \
          --arg event "enforce" \
          --arg action_id "$action_id" \
          --arg ts "$ts" \
          --argjson ts_epoch "$ts_epoch" \
          --arg status "failed" \
          --arg error "ban API request failed" \
          --arg type "ban" \
          --arg ban_type "$ban_type_exec" \
          --argjson ban_days "$ban_days_exec" \
          --arg subreddit "$SUBREDDIT" \
          --arg mode "$current_mode" \
          --arg pathway "$pathway" \
          --arg norm "$norm" \
          --arg feeling "$feeling" \
          --arg reasoning "$reasoning" \
          --arg comment "$comment_json" \
          --arg permalink "$permalink" \
          --arg reply_id "$reply_id" \
          '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,error:$error,type:$type,ban_type:$ban_type,ban_days:$ban_days,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,reply_id:$reply_id,undoable:false}')
        record_action_event "$action"
      fi
    fi
  elif [ "$remove_exec" = true ]; then
    if [ -z "$reply_id" ]; then
      action=$(jq -cn \
        --arg event "enforce" \
        --arg action_id "$action_id" \
        --arg ts "$ts" \
        --argjson ts_epoch "$ts_epoch" \
        --arg status "failed" \
        --arg error "remove blocked: no direct pre-action reply" \
        --arg type "remove" \
        --arg subreddit "$SUBREDDIT" \
        --arg mode "$current_mode" \
        --arg pathway "$pathway" \
        --arg norm "$norm" \
        --arg feeling "$feeling" \
        --arg reasoning "$reasoning" \
        --arg comment "$comment_json" \
        --arg permalink "$permalink" \
        '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,error:$error,type:$type,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,reply_id:null,undoable:false,removed:true}')
      record_action_event "$action"
    else
      if post_remove_comment "$thing_id"; then
        action=$(jq -cn \
          --arg event "enforce" \
          --arg action_id "$action_id" \
          --arg ts "$ts" \
          --argjson ts_epoch "$ts_epoch" \
          --arg status "active" \
          --arg type "remove" \
          --arg subreddit "$SUBREDDIT" \
          --arg mode "$current_mode" \
          --arg pathway "$pathway" \
          --arg norm "$norm" \
          --arg feeling "$feeling" \
          --arg reasoning "$reasoning" \
          --arg comment "$comment_json" \
          --arg permalink "$permalink" \
          --arg reply_id "$reply_id" \
          '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,type:$type,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,reply_id:$reply_id,undoable:true,removed:true,undone_at:null}')
        record_action_event "$action"
        executed_actions=$(json_array_add_unique "$executed_actions" "Remove Content")
      else
        action=$(jq -cn \
          --arg event "enforce" \
          --arg action_id "$action_id" \
          --arg ts "$ts" \
          --argjson ts_epoch "$ts_epoch" \
          --arg status "failed" \
          --arg error "remove API request failed" \
          --arg type "remove" \
          --arg subreddit "$SUBREDDIT" \
          --arg mode "$current_mode" \
          --arg pathway "$pathway" \
          --arg norm "$norm" \
          --arg feeling "$feeling" \
          --arg reasoning "$reasoning" \
          --arg comment "$comment_json" \
          --arg permalink "$permalink" \
          --arg reply_id "$reply_id" \
          '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,error:$error,type:$type,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,reply_id:$reply_id,undoable:false,removed:true}')
        record_action_event "$action"
      fi
    fi
  fi

  if [ -n "$lock_target" ]; then
    lock_action_id=$(new_event_id "action")
    lock_ts=$(now_iso)
    lock_ts_epoch=$(now_epoch)
    if post_lock_thread "$lock_target"; then
      lock_action=$(jq -cn \
        --arg event "enforce" \
        --arg action_id "$lock_action_id" \
        --arg ts "$lock_ts" \
        --argjson ts_epoch "$lock_ts_epoch" \
        --arg status "active" \
        --arg type "lock" \
        --arg subreddit "$SUBREDDIT" \
        --arg mode "$current_mode" \
        --arg pathway "$pathway" \
        --arg norm "$norm" \
        --arg feeling "$feeling" \
        --arg reasoning "$reasoning" \
        --arg comment "$comment_json" \
        --arg permalink "$permalink" \
        --arg lock_target "$lock_target" \
        '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,type:$type,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,lock_target:$lock_target,undoable:false}')
      record_action_event "$lock_action"
      executed_actions=$(json_array_add_unique "$executed_actions" "Lock Thread")
    else
      lock_action=$(jq -cn \
        --arg event "enforce" \
        --arg action_id "$lock_action_id" \
        --arg ts "$lock_ts" \
        --argjson ts_epoch "$lock_ts_epoch" \
        --arg status "failed" \
        --arg error "lock API request failed" \
        --arg type "lock" \
        --arg subreddit "$SUBREDDIT" \
        --arg mode "$current_mode" \
        --arg pathway "$pathway" \
        --arg norm "$norm" \
        --arg feeling "$feeling" \
        --arg reasoning "$reasoning" \
        --arg comment "$comment_json" \
        --arg permalink "$permalink" \
        --arg lock_target "$lock_target" \
        '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,error:$error,type:$type,subreddit:$subreddit,mode:$mode,pathway:$pathway,norm:$norm,feeling:$feeling,reasoning:$reasoning,comment_id:(($comment|fromjson).name // ""),comment_author:(($comment|fromjson).author // ""),permalink:$permalink,lock_target:$lock_target,undoable:false}')
      record_action_event "$lock_action"
    fi
  fi

  if [ "$escalation_active" = true ] && [ "$escalation_timing" != "escalate_immediately" ]; then
    append_mode_log_event "escalation" "$(jq -cn --arg user "$author_key" --arg norm "$norm" --arg action "$(printf '%s' "$executed_actions" | jq -r '.[0] // ""')" --arg content "$(printf '%s' "$comment_json" | jq -r '.body // ""')" --arg link "$permalink" --arg severity "$norm_severity" --arg timing "$escalation_timing" --arg targets "$escalation_targets" '{user_id:$user,norm:$norm,action:$action,content:$content,thread_link:$link,severity:$severity,timing:$timing,targets:$targets}')"
  fi

  append_mode_log_event "event-cycle" "$(jq -cn --arg user "$author_key" --arg mode "$current_mode" --arg comment_id "$thing_id" --argjson proposed "$proposed_actions" --argjson allowed "$allowed_actions" --argjson blocked "$blocked_actions" --argjson executed "$executed_actions" --arg severity "$norm_severity" '{user_id:$user,mode:$mode,comment_id:$comment_id,proposed:$proposed,allowed:$allowed,blocked:$blocked,executed:$executed,norm_severity:$severity}')"

  valence=$(relationship_valence_for_decision "$decision")
  primary_action=$(printf '%s' "$executed_actions" | jq -r '.[0] // "none"' 2>/dev/null || printf 'none')
  relationship_row=$(relationship_record_interaction_row "$relationship_row" "$valence" "$thing_id" "$primary_action")

  transition_row=$(resolve_post_action_transition "$executed_actions")
  if [ "$escalation_active" = true ]; then
    esc_switch_enabled=$(read_modes_config_json | jq -r '.escalation.afterActionSwitch.enabled // false' 2>/dev/null || printf 'false')
    if [ "$esc_switch_enabled" = "true" ]; then
      esc_to_mode=$(read_modes_config_json | jq -r '.escalation.afterActionSwitch.toMode // empty' 2>/dev/null || printf '')
      esc_duration=$(read_modes_config_json | jq -r '.escalation.afterActionSwitch.durationHours // 0' 2>/dev/null || printf '0')
      esc_decay=$(read_modes_config_json | jq -r '.escalation.afterActionSwitch.decayTo // empty' 2>/dev/null || printf '')
      if [ -n "$esc_to_mode" ]; then
        use_esc_switch=false
        esc_score=92
        if [ -z "$transition_row" ] || [ "$transition_row" = "null" ]; then
          use_esc_switch=true
        else
          tr_score=$(printf '%s' "$transition_row" | jq -r '.score // 0' 2>/dev/null || printf '0')
          tr_score=$(to_int "$tr_score" 0)
          if [ "$esc_score" -gt "$tr_score" ]; then
            use_esc_switch=true
          elif [ "$esc_score" -eq "$tr_score" ]; then
            tr_mode=$(printf '%s' "$transition_row" | jq -r '.transition.toMode // empty' 2>/dev/null || printf '')
            esc_rank=$(mode_restrictiveness_rank "$esc_to_mode")
            tr_rank=$(mode_restrictiveness_rank "$tr_mode")
            if [ "$esc_rank" -lt "$tr_rank" ]; then
              use_esc_switch=true
            fi
          fi
        fi
        if [ "$use_esc_switch" = true ]; then
          transition_row=$(jq -cn \
            --arg action "Escalation" \
            --arg to_mode "$esc_to_mode" \
            --argjson duration "$(to_int "$esc_duration" 0)" \
            --arg decay "$esc_decay" \
            --argjson score "$esc_score" \
            '{action:$action,transition:{toMode:$to_mode,durationHours:$duration,decayTo:$decay,announce:false},score:$score}')
        fi
      fi
    fi
  fi
  if [ -n "$transition_row" ] && [ "$transition_row" != "null" ]; then
    transition_action=$(printf '%s' "$transition_row" | jq -r '.action // empty' 2>/dev/null || printf '')
    to_mode=$(printf '%s' "$transition_row" | jq -r '.transition.toMode // empty' 2>/dev/null || printf '')
    duration=$(printf '%s' "$transition_row" | jq -r '.transition.durationHours // 0' 2>/dev/null || printf '0')
    decay_to=$(printf '%s' "$transition_row" | jq -r '.transition.decayTo // empty' 2>/dev/null || printf '')
    announce=$(printf '%s' "$transition_row" | jq -r '.transition.announce // false' 2>/dev/null || printf 'false')
    if [ -n "$to_mode" ]; then
      old_mode=$(printf '%s' "$relationship_row" | jq -r '.current_mode // ""' 2>/dev/null || printf '')
      announce_bool=false
      [ "$announce" = "true" ] && announce_bool=true
      relationship_row=$(relationship_set_mode_row "$relationship_row" "$to_mode" "$duration" "$decay_to" "post-action:$transition_action" "$announce_bool")
      new_mode=$(printf '%s' "$relationship_row" | jq -r '.current_mode // ""' 2>/dev/null || printf '')
      append_mode_log_event "mode-switch" "$(jq -cn --arg user "$author_key" --arg from "$old_mode" --arg to "$new_mode" --arg action "$transition_action" '{user_id:$user,from_mode:$from,to_mode:$to,action:$action}')"
      if [ "$announce_bool" = true ] && [ "$(mode_allows_action "$new_mode" "Post Neutral Ban Notice")" = "true" ]; then
        switch_notice=$(read_modes_config_json | jq -r --arg user "$author" --arg mode "$new_mode" '.replies.modeSwitchTemplate // "" | gsub("\\{\\{user\\}\\}";$user) | gsub("\\{\\{mode\\}\\}";$mode)' 2>/dev/null || printf '')
        if [ -n "$switch_notice" ]; then
          if switch_reply_id=$(post_reply "$thing_id" "$switch_notice" 2>/dev/null); then
            transition_decision=$(jq -cn --arg action "$transition_action" --arg mode "$new_mode" '{transitionAction:$action,toMode:$mode}')
            record_reply_event "$comment_json" "$switch_reply_id" "$switch_notice" "mode-switch" "$transition_decision" "mode-switch"
          fi
        fi
      fi
    fi
  fi

  relationship_upsert_row "$relationship_row" || :
  return 0
}

merged_action_by_id() {
  action_id=$1
  jq -cs --arg aid "$action_id" '
    reduce .[] as $row ({}; if ($row.action_id // "") == $aid then . + $row else . end)
  ' "$ACTIONS_LOG" 2>/dev/null || printf '{}'
}

undo_action_now() {
  action_id=$1
  action=$(merged_action_by_id "$action_id")

  found=$(printf '%s' "$action" | jq -r 'has("action_id")')
  if [ "$found" != "true" ]; then
    emit_error "action not found: $action_id"
    return 1
  fi

  status=$(printf '%s' "$action" | jq -r '.status // ""')
  if [ "$status" = "undone" ]; then
    emit_error "action already undone"
    return 1
  fi
  if [ "$status" != "active" ]; then
    emit_error "only active actions can be undone"
    return 1
  fi

  action_type=$(printf '%s' "$action" | jq -r '.type // ""')
  comment_author=$(printf '%s' "$action" | jq -r '.comment_author // ""')
  comment_id=$(printf '%s' "$action" | jq -r '.comment_id // ""')

  ts=$(now_iso)
  ts_epoch=$(now_epoch)

  ok=0
  case "$action_type" in
    ban)
      if reddit_post "/r/$SUBREDDIT/api/unfriend" \
        --data-urlencode "api_type=json" \
        --data-urlencode "name=$comment_author" \
        --data-urlencode "type=banned" >/dev/null 2>&1; then
        ok=1
      fi
      ;;
    remove)
      if reddit_post "/api/approve" \
        --data-urlencode "id=$comment_id" >/dev/null 2>&1; then
        ok=1
      fi
      ;;
    *)
      emit_error "unsupported undo type: $action_type"
      return 1
      ;;
  esac

  if [ "$ok" -eq 1 ]; then
    undo_event=$(jq -cn \
      --arg event "undo" \
      --arg action_id "$action_id" \
      --arg ts "$ts" \
      --argjson ts_epoch "$ts_epoch" \
      --arg status "undone" \
      --arg undone_at "$ts" \
      --arg undo_status "ok" \
      '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,undone_at:$undone_at,undo_status:$undo_status}')
    record_action_event "$undo_event"

    merged=$(merged_action_by_id "$action_id")
    jq -cn --argjson action "$merged" '{ok:true,action:$action}'
  else
    undo_event=$(jq -cn \
      --arg event "undo" \
      --arg action_id "$action_id" \
      --arg ts "$ts" \
      --argjson ts_epoch "$ts_epoch" \
      --arg status "active" \
      --arg undo_status "failed" \
      --arg error "undo API failed" \
      '{event:$event,action_id:$action_id,ts:$ts,ts_epoch:$ts_epoch,status:$status,undo_status:$undo_status,error:$error}')
    record_action_event "$undo_event"

    emit_error "undo API failed"
    return 1
  fi
}

autogen_apology_text() {
  action_json=$1

  action_type=$(printf '%s' "$action_json" | jq -r '.type // "enforcement"')
  norm=$(printf '%s' "$action_json" | jq -r '.norm // empty')
  feeling=$(printf '%s' "$action_json" | jq -r '.feeling // empty')

  prompt=$(cat <<PROMPT
Write a short apology reddit reply from an automated moderator.
Context:
- action_type: $action_type
- mode: $MODE
- norm: $norm
- feeling: $feeling
Constraints:
- Keep under 320 characters.
- Acknowledge possible mistake.
- Promise that action has been undone.
Return plain text only.
PROMPT
)

  if response=$(ollama_generate "$prompt" 2>/dev/null); then
    text=$(printf '%s' "$response" | jq -r '.response // empty' 2>/dev/null || printf '')
    if [ -n "$text" ]; then
      printf '%s' "$text"
      return
    fi
  fi

  printf '%s' "I made a moderation mistake earlier, and I have undone that action. Sorry for the disruption."
}

apologize_action_now() {
  action_id=$1
  custom_message=${2-}

  action=$(merged_action_by_id "$action_id")
  found=$(printf '%s' "$action" | jq -r 'has("action_id")')
  if [ "$found" != "true" ]; then
    emit_error "action not found: $action_id"
    return 1
  fi

  thing_id=$(printf '%s' "$action" | jq -r '.comment_id // empty')
  if [ -z "$thing_id" ]; then
    emit_error "action missing comment_id"
    return 1
  fi

  if [ -n "$custom_message" ]; then
    apology=$custom_message
    source="custom"
  else
    apology=$(autogen_apology_text "$action")
    source="autogen"
  fi

  apology=$(truncate_reply "$apology")
  if [ -z "$apology" ]; then
    apology="I made a moderation mistake earlier and have undone that action."
  fi

  if reply_id=$(post_reply "$thing_id" "$apology" 2>/dev/null); then
    ts=$(now_iso)
    ts_epoch=$(now_epoch)
    reply_event_id=$(new_event_id "apology")
    event=$(jq -cn \
      --arg event "apology" \
      --arg reply_event_id "$reply_event_id" \
      --arg ts "$ts" \
      --argjson ts_epoch "$ts_epoch" \
      --arg subreddit "$SUBREDDIT" \
      --arg mode "$MODE" \
      --arg action_id "$action_id" \
      --arg comment_id "$thing_id" \
      --arg reply_id "$reply_id" \
      --arg reply "$apology" \
      --arg source "$source" \
      '{event:$event,reply_event_id:$reply_event_id,ts:$ts,ts_epoch:$ts_epoch,subreddit:$subreddit,mode:$mode,action_id:$action_id,comment_id:$comment_id,reply_id:$reply_id,reply:$reply,category:"apology",source:$source}')
    append_jsonl "$REPLIES_LOG" "$event"

    jq -cn --arg action_id "$action_id" --arg reply_id "$reply_id" --arg source "$source" '{ok:true,actionId:$action_id,replyId:$reply_id,source:$source}'
  else
    emit_error "failed to post apology"
    return 1
  fi
}

list_actions_json() {
  limit=$(to_int "${1-80}" 80)
  [ "$limit" -lt 1 ] && limit=1

  jq -cs --argjson limit "$limit" '
    reduce .[] as $row ({};
      if ($row.action_id // "") == "" then .
      else .[$row.action_id] = ((.[$row.action_id] // {}) + $row)
      end
    )
    | [.[]]
    | sort_by(.ts_epoch // 0)
    | reverse
    | .[0:$limit]
    | {ok:true,actions:.}
  ' "$ACTIONS_LOG" 2>/dev/null || jq -cn '{ok:true,actions:[]}'
}

list_replies_json() {
  limit=$(to_int "${1-120}" 120)
  [ "$limit" -lt 1 ] && limit=1

  jq -cs --argjson limit "$limit" '
    sort_by(.ts_epoch // 0)
    | reverse
    | .[0:$limit]
    | {ok:true,replies:.}
  ' "$REPLIES_LOG" 2>/dev/null || jq -cn '{ok:true,replies:[]}'
}

extract_norms_internal() {
  cache_dir=$1
  mode=${2-incremental}

  last_seen=$(to_int "$(cat "$LAST_STATUTE_SEEN_FILE" 2>/dev/null || printf '0')" 0)
  max_seen=0
  candidates='[]'

  case "$mode" in
    full)
      # Initial bootstrap pass: scan several pages to sample broad subreddit discourse.
      after=''
      page=0
      max_pages=10
      combined='[]'
      while [ "$page" -lt "$max_pages" ]; do
        path="/r/$SUBREDDIT/comments/.json?limit=100&raw_json=1&sort=new"
        if [ -n "$after" ]; then
          path="$path&after=$after"
        fi
        feed=$(cached_reddit_get "$cache_dir" "high-signal-full-$page" "$path")
        page_batch=$(printf '%s' "$feed" | jq -c --argjson min_score "$HIGH_SIGNAL_MIN_SCORE" '
          [ .data.children[].data
            | select((.score // 0) >= $min_score or (.controversiality // 0) >= 1)
            | {id:.name,author,body,score,permalink,created_utc}
          ]
        ' 2>/dev/null || printf '[]')
        combined=$(printf '%s\n%s\n' "$combined" "$page_batch" | jq -s 'add' 2>/dev/null || printf '[]')
        next_after=$(printf '%s' "$feed" | jq -r '.data.after // empty' 2>/dev/null || printf '')
        [ -n "$next_after" ] || break
        after=$next_after
        page=$((page + 1))
      done
      candidates=$(printf '%s' "$combined" | jq -c '
        sort_by(.score // 0)
        | reverse
        | .[0:120]
      ' 2>/dev/null || printf '[]')
      ;;
    *)
      feed=$(cached_reddit_get "$cache_dir" "high-signal" "/r/$SUBREDDIT/comments/.json?limit=150&raw_json=1&sort=new")
      max_seen=$(printf '%s' "$feed" | jq '[.data.children[].data.created_utc // 0] | max // 0' 2>/dev/null || printf '0')
      max_seen=$(to_int "$max_seen" 0)
      candidates=$(printf '%s' "$feed" | jq -c --argjson last "$last_seen" --argjson min_score "$HIGH_SIGNAL_MIN_SCORE" '
        [ .data.children[].data
          | select((.created_utc // 0) > $last)
          | select((.score // 0) >= $min_score or (.controversiality // 0) >= 1)
          | {id:.name,author,body,score,permalink,created_utc}
        ]
        | sort_by(.score // 0)
        | reverse
        | .[0:40]
      ' 2>/dev/null || printf '[]')
      ;;
  esac

  candidate_count=$(printf '%s' "$candidates" | jq 'length' 2>/dev/null || printf '0')

  if [ "$mode" != "full" ] && [ "$max_seen" -gt "$last_seen" ]; then
    printf '%s\n' "$max_seen" > "$LAST_STATUTE_SEEN_FILE"
  fi

  if [ "$candidate_count" -eq 0 ]; then
    jq -cn '{ok:true,processed:0,accepted:0,proposed:0,message:"no high-signal discourse"}'
    return 0
  fi

  prompt=$(cat <<PROMPT
You are extracting candidate moderation norms for r/$SUBREDDIT.
Using the discourse samples below, propose up to 5 concise norms.
Return STRICT JSON only in this shape:
{
  "norms": [
    {"id":"n-short-id","text":"rule text","rationale":"why","evidence_ids":["t1_x"],"severity":"low|medium|high"}
  ]
}

Discourse:
$candidates
PROMPT
)

  if ! model_response=$(ollama_generate "$prompt" 2>/dev/null); then
    emit_error "norm extraction failed: ollama unavailable"
    return 1
  fi

  raw=$(printf '%s' "$model_response" | jq -r '.response // empty' 2>/dev/null || printf '')
  if [ -z "$raw" ]; then
    raw="$model_response"
  fi

  parsed=$(printf '%s' "$raw" | jq -c '(fromjson? // .)' 2>/dev/null || printf '{}')
  norms=$(printf '%s' "$parsed" | jq -c 'if type=="array" then . elif (.norms? | type)=="array" then .norms else [] end' 2>/dev/null || printf '[]')

  proposed=0
  accepted=0

  printf '%s' "$norms" | jq -c '.[]' 2>/dev/null | while IFS= read -r norm_row; do
    proposed=$((proposed + 1))
    norm_id=$(printf '%s' "$norm_row" | jq -r '.id // empty')
    [ -z "$norm_id" ] && norm_id=$(new_event_id "norm")
    norm_text=$(printf '%s' "$norm_row" | jq -r '.text // empty')
    [ -z "$norm_text" ] && continue
    severity=$(printf '%s' "$norm_row" | jq -r '.severity // "medium"')
    rationale=$(printf '%s' "$norm_row" | jq -r '.rationale // empty')
    evidence=$(printf '%s' "$norm_row" | jq -c '.evidence_ids // []')

    line=$(jq -cn \
      --arg id "$norm_id" \
      --arg text "$norm_text" \
      --arg severity "$severity" \
      --arg rationale "$rationale" \
      --arg source "$( [ "$mode" = "full" ] && printf '%s' "full-subreddit-bootstrap" || printf '%s' "nightly-extract" )" \
      --arg ts "$(now_iso)" \
      --argjson evidence "$evidence" \
      '{id:$id,text:$text,severity:$severity,rationale:$rationale,source:$source,accepted_at:$ts,evidence_ids:$evidence}')

    if [ "$AUTO_ACCEPT_NORMS" -eq 1 ]; then
      append_jsonl "$NORMS_FILE" "$line"
      accepted=$((accepted + 1))
    else
      append_jsonl "$NORM_PROPOSALS_LOG" "$line"
    fi
  done

  # shell loop above runs in subshell with pipes; recompute counts deterministically.
  proposed=$(printf '%s' "$norms" | jq 'length' 2>/dev/null || printf '0')
  if [ "$AUTO_ACCEPT_NORMS" -eq 1 ]; then
    accepted=$proposed
  else
    accepted=0
  fi

  jq -cn \
    --argjson processed "$candidate_count" \
    --argjson proposed "$proposed" \
    --argjson accepted "$accepted" \
    --arg mode "$mode" \
    '{ok:true,mode:$mode,processed:$processed,proposed:$proposed,accepted:$accepted}'
}

patrol_once() {
  cache_dir=$(mktemp -d "${TMPDIR:-/tmp}/vr-patrol.XXXXXX")
  cleanup_patrol() {
    rm -rf "$cache_dir"
  }
  trap cleanup_patrol EXIT HUP INT TERM

  last_seen=$(to_int "$(cat "$LAST_SEEN_FILE" 2>/dev/null || printf '0')" 0)
  feed=$(cached_reddit_get "$cache_dir" "comments-feed" "/r/$SUBREDDIT/comments/.json?limit=120&raw_json=1&sort=new")

  max_seen=$(printf '%s' "$feed" | jq '[.data.children[].data.created_utc // 0] | max // 0' 2>/dev/null || printf '0')
  max_seen=$(to_int "$max_seen" 0)

  new_comments_file="$cache_dir/new-comments.jsonl"
  printf '%s' "$feed" | jq -c --argjson last "$last_seen" '
    [.data.children[].data | select((.created_utc // 0) > $last)]
    | sort_by(.created_utc // 0)
    | .[]
  ' 2>/dev/null > "$new_comments_file" || :

  engaged_file="$cache_dir/engaged.jsonl"
  others_file="$cache_dir/others.jsonl"
  : > "$engaged_file"
  : > "$others_file"

  while IFS= read -r comment_row; do
    [ -z "$comment_row" ] && continue
    if [ "$(is_direct_engagement_comment "$cache_dir" "$comment_row")" = "1" ]; then
      printf '%s\n' "$comment_row" >> "$engaged_file"
    else
      printf '%s\n' "$comment_row" >> "$others_file"
    fi
  done < "$new_comments_file"

  selected_file="$cache_dir/selected.jsonl"
  : > "$selected_file"

  if [ "$PATROL_MODE" = "full" ]; then
    cat "$engaged_file" "$others_file" >> "$selected_file"
  else
    cat "$engaged_file" >> "$selected_file"

    engaged_count=$(wc -l < "$engaged_file" | tr -d ' ')
    engaged_count=$(to_int "$engaged_count" 0)
    slots=$((PATROL_SAMPLE_MAX - engaged_count))
    if [ "$slots" -gt 0 ]; then
      awk 'BEGIN { srand(); } { print rand() "\t" $0; }' "$others_file" 2>/dev/null \
        | sort -n \
        | head -n "$slots" \
        | cut -f2- >> "$selected_file"
    fi
  fi

  ordered_file="$cache_dir/ordered.jsonl"
  jq -cs 'sort_by(.created_utc // 0)[]' "$selected_file" 2>/dev/null > "$ordered_file" || : > "$ordered_file"

  processed=0
  while IFS= read -r comment_row; do
    [ -z "$comment_row" ] && continue
    if process_comment "$cache_dir" "$comment_row"; then
      processed=$((processed + 1))
    fi
  done < "$ordered_file"

  if [ "$max_seen" -gt "$last_seen" ]; then
    printf '%s\n' "$max_seen" > "$LAST_SEEN_FILE"
  fi

  now_ts=$(now_iso)
  runtime=$(jq -cn \
    --arg ts "$now_ts" \
    --argjson processed "$processed" \
    --argjson max_seen "$max_seen" \
    --argjson last_seen_prev "$last_seen" \
    --arg mode "$MODE" \
    --arg patrol_mode "$PATROL_MODE" \
    '{lastPollAt:$ts,processed:$processed,maxSeen:$max_seen,lastSeenBefore:$last_seen_prev,mode:$mode,patrolMode:$patrol_mode}')
  printf '%s\n' "$runtime" > "$RUNTIME_FILE"

  jq -cn --argjson processed "$processed" --argjson max_seen "$max_seen" --argjson previous_last_seen "$last_seen" '{ok:true,processed:$processed,maxSeen:$max_seen,previousLastSeen:$previous_last_seen}'
}

maybe_run_nightly_statute_pass() {
  if [ "$NIGHTLY_STATUTE_ENABLED" -ne 1 ]; then
    return 0
  fi

  today=$(date '+%Y-%m-%d')
  current_hour=$(to_int "$(date '+%H')" 0)
  last_day=$(cat "$LAST_STATUTE_DAY_FILE" 2>/dev/null || printf '')

  if [ "$today" = "$last_day" ]; then
    return 0
  fi

  if [ "$current_hour" -lt "$NIGHTLY_HOUR" ]; then
    return 0
  fi

  if extract_norms_internal "$STATE_DIR" >/dev/null 2>&1; then
    printf '%s\n' "$today" > "$LAST_STATUTE_DAY_FILE"
  fi
}

run_loop() {
  while :; do
    patrol_once >/dev/null 2>&1 || true
    maybe_run_nightly_statute_pass || true
    sleep_for=$(random_between "$PATROL_INTERVAL_MIN" "$PATROL_INTERVAL_MAX")
    [ "$sleep_for" -lt 1 ] && sleep_for=1
    sleep "$sleep_for"
  done
}

main() {
  command=${1-}
  shift || true

  require_tools
  bootstrap_state
  load_bot_env
  load_reddit_env_optional

  case "$command" in
    bootstrap)
      settings_json
      ;;

    settings)
      settings_json
      ;;

    metrics)
      metrics_json
      ;;

    once)
      load_reddit_env
      patrol_once
      ;;

    run)
      load_reddit_env_optional
      run_loop
      ;;

    list-actions)
      list_actions_json "${1-80}"
      ;;

    list-replies)
      list_replies_json "${1-120}"
      ;;

    get-modes-config)
      jq -cn --argjson config "$(read_modes_config_json)" '{ok:true,config:$config}'
      ;;

    save-modes-config)
      save_modes_config_json "${1-}"
      ;;

    list-relationships)
      list_relationships_json "${1-300}"
      ;;

    set-relationship)
      set_relationship_json "${1-}" "${2-}" "${3-0}" "${4-manual-override}"
      ;;

    list-mode-log)
      list_mode_log_json "${1-200}"
      ;;

    extract-norms)
      load_reddit_env
      extract_norms_internal "$STATE_DIR" "${1-incremental}"
      ;;

    undo)
      load_reddit_env
      aid=${1-}
      if [ -z "$aid" ]; then
        emit_error "ACTION_ID required"
        exit 2
      fi
      undo_action_now "$aid"
      ;;

    apologize)
      load_reddit_env
      aid=${1-}
      shift || true
      if [ -z "$aid" ]; then
        emit_error "ACTION_ID required"
        exit 2
      fi
      apologize_action_now "$aid" "${1-}"
      ;;

    launchd-status)
      launchd_status_json
      ;;

    launchd-install)
      launchd_install
      ;;

    launchd-start)
      launchd_start
      ;;

    launchd-stop)
      launchd_stop
      ;;

    launchd-uninstall)
      launchd_uninstall
      ;;

    set-setting)
      key=${1-}
      value=${2-}
      if [ -z "$key" ] || [ -z "$value" ]; then
        emit_error "set-setting requires KEY VALUE"
        exit 2
      fi
      set_setting "$key" "$value"
      ;;

    set-reddit-setting)
      if [ "$#" -lt 2 ]; then
        emit_error "set-reddit-setting requires KEY VALUE"
        exit 2
      fi
      key=${1-}
      value=${2-}
      if [ -z "$key" ]; then
        emit_error "set-reddit-setting requires KEY VALUE"
        exit 2
      fi
      set_reddit_setting "$key" "$value"
      ;;

    *)
      emit_error "unknown command: ${command:-<empty>}"
      exit 2
      ;;
  esac
}

main "$@"
