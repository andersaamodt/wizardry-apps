#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: virtual-redditor-backend.sh ACTION [ARGS...]

Actions:
  list-themes
  get-ui-prefs
  set-ui-pref KEY VALUE
  init
  status
  install
  uninstall
  start
  stop
  restart
  run-once
  extract-norms
  extract-norms-full
  extract-norms-all
  list-actions [LIMIT]
  list-replies [LIMIT]
  get-modes-config
  save-modes-config JSON
  list-relationships [LIMIT]
  set-relationship USER MODE [DURATION_HOURS] [TRIGGER]
  cancel-relationship-override USER
  list-mode-log [LIMIT]
  undo ACTION_ID
  apologize ACTION_ID [MESSAGE]
  set-setting KEY VALUE
  set-reddit-setting KEY VALUE
  check-subreddit NAME
  list-profiles
  create-profile NAME
  select-profile PROFILE_ID
  rename-profile PROFILE_ID NAME
  delete-profile PROFILE_ID
  oauth-begin CLIENT_ID CLIENT_SECRET [SUBREDDIT] [USERNAME_HINT]
  oauth-status
  oauth-submit-callback CALLBACK_URL_OR_QUERY
  oauth-finish
  oauth-cancel
  compiled-instructions
  read-file TARGET
  read-doctrine
  write-file TARGET CONTENT
  tail-log [LINES]

TARGET values for read-file:
  manifesto | norms | shared-instructions | core-instructions | bot-env | reddit-env | daemon-log | daemon-error-log
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DAEMON_SCRIPT="$SCRIPT_DIR/virtual-redditor-daemon.sh"

is_workspace_root() {
  root=${1-}
  [ -n "$root" ] || return 1
  [ -f "$root/config/apps.manifest.json" ] || return 1
  [ -d "$root/.apps" ] || return 1
  [ -d "$root/.web" ] || return 1
}

find_root_from() {
  start=${1-}
  [ -n "$start" ] || return 1
  dir=$start
  while :; do
    if is_workspace_root "$dir"; then
      printf '%s\n' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done
  return 1
}

resolve_wizardry_root() {
  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && is_workspace_root "$WIZARDRY_APPS_ROOT"; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT"
    return 0
  fi

  if root=$(find_root_from "$SCRIPT_DIR" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if pwd_now=$(pwd -P 2>/dev/null); then
    if root=$(find_root_from "$pwd_now" 2>/dev/null); then
      printf '%s\n' "$root"
      return 0
    fi
  fi

  return 1
}

theme_names_from_dir() {
  dir=${1-}
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.css' 2>/dev/null \
    | awk -F/ '{ print $NF }' \
    | sed 's/\.css$//' \
    | awk '/^[a-z0-9_-]+$/' \
    | sort -u
}

emit_theme_names() {
  app_theme_dir="$SCRIPT_DIR/../themes"
  theme_root=''
  root=$(resolve_wizardry_root 2>/dev/null || true)
  if [ -n "$root" ] && [ -d "$root/.web/.themes" ]; then
    theme_root="$root/.web/.themes"
    mkdir -p "$app_theme_dir"
    cp -f "$theme_root"/*.css "$app_theme_dir/" 2>/dev/null || true
  fi

  themes=$(theme_names_from_dir "$theme_root" || true)
  if [ -z "$themes" ]; then
    themes=$(theme_names_from_dir "$app_theme_dir" || true)
  fi

  if [ -n "$themes" ]; then
    printf '%s\n' "$themes"
  fi
}

if [ ! -x "$DAEMON_SCRIPT" ]; then
  jq -cn --arg err "backend missing daemon script at $DAEMON_SCRIPT" '{ok:false,error:$err}'
  exit 1
fi

EXPLICIT_STATE_DIR=${VR_STATE_DIR-}
if [ -n "$EXPLICIT_STATE_DIR" ]; then
  MULTI_PROFILE=0
  STATE_ROOT=$(CDPATH= cd -- "$(dirname "$EXPLICIT_STATE_DIR")" && pwd -P)
  CURRENT_STATE_DIR=$EXPLICIT_STATE_DIR
  PROFILES_DIR=''
  ACTIVE_PROFILE_FILE=''
  ACTIVE_PROFILE_ID='single'
else
  MULTI_PROFILE=1
  STATE_ROOT=${VR_HOME_DIR:-"${XDG_STATE_HOME:-$HOME/.local/state}/wizardry/virtual-redditor"}
  PROFILES_DIR="$STATE_ROOT/profiles"
  ACTIVE_PROFILE_FILE="$STATE_ROOT/active-profile.txt"
  ACTIVE_PROFILE_ID=''
  CURRENT_STATE_DIR=''
fi

slugify_profile_id() {
  raw=$1
  out=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9_-]#-#g; s#--*#-#g; s#^-##; s#-$##')
  [ -z "$out" ] && out=profile
  printf '%s' "$out"
}

profile_dir() {
  profile_id=$1
  printf '%s/%s' "$PROFILES_DIR" "$profile_id"
}

profile_name_file() {
  profile_id=$1
  printf '%s/.profile-name' "$(profile_dir "$profile_id")"
}

ensure_profile_runtime() {
  profile_id=$1
  dir=$(profile_dir "$profile_id")
  mkdir -p "$dir"
  VR_STATE_DIR="$dir" "$DAEMON_SCRIPT" bootstrap >/dev/null 2>&1 || true
  if [ ! -f "$(profile_name_file "$profile_id")" ]; then
    printf '%s\n' "$profile_id" > "$(profile_name_file "$profile_id")"
  fi
}

ensure_multi_profile_root() {
  [ "$MULTI_PROFILE" -eq 1 ] || return 0
  mkdir -p "$PROFILES_DIR"
}

runtime_state_dir() {
  printf '%s/.runtime' "$STATE_ROOT"
}

force_delete_dir() {
  target=${1-}
  [ -n "$target" ] || return 1
  [ -d "$target" ] || return 0

  chmod -R u+w "$target" >/dev/null 2>&1 || true
  rm -rf "$target" >/dev/null 2>&1 || true

  if [ ! -d "$target" ]; then
    return 0
  fi

  # Retry briefly for files still being closed/flushed by background processes.
  i=0
  while [ $i -lt 10 ]; do
    sleep 0.08
    chmod -R u+w "$target" >/dev/null 2>&1 || true
    rm -rf "$target" >/dev/null 2>&1 || true
    [ -d "$target" ] || return 0
    i=$((i + 1))
  done

  return 1
}

resolve_current_state() {
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    CURRENT_STATE_DIR=$EXPLICIT_STATE_DIR
    ACTIVE_PROFILE_ID='single'
    return 0
  fi

  ensure_multi_profile_root
  active=''
  if [ -f "$ACTIVE_PROFILE_FILE" ]; then
    active=$(head -n 1 "$ACTIVE_PROFILE_FILE" 2>/dev/null | tr -d '\r')
  fi
  active=$(slugify_profile_id "$active")

  # Keep app functional even with zero profiles, without auto-creating "default".
  if [ -n "$active" ] && [ -d "$(profile_dir "$active")" ]; then
    ACTIVE_PROFILE_ID=$active
    CURRENT_STATE_DIR=$(profile_dir "$active")
    return 0
  fi

  next_active=''
  for d in "$PROFILES_DIR"/*; do
    [ -d "$d" ] || continue
    next_active=$(basename "$d")
    break
  done

  if [ -n "$next_active" ]; then
    ACTIVE_PROFILE_ID=$next_active
    CURRENT_STATE_DIR=$(profile_dir "$next_active")
    printf '%s\n' "$next_active" > "$ACTIVE_PROFILE_FILE"
    return 0
  fi

  ACTIVE_PROFILE_ID=''
  CURRENT_STATE_DIR=$(runtime_state_dir)
  mkdir -p "$CURRENT_STATE_DIR"
  printf '%s\n' '' > "$ACTIVE_PROFILE_FILE"
  VR_STATE_DIR="$CURRENT_STATE_DIR" "$DAEMON_SCRIPT" bootstrap >/dev/null 2>&1 || true
  return 0
}

refresh_paths() {
  BANS_LOG="$CURRENT_STATE_DIR/bans.jsonl"
  REPLIES_LOG="$CURRENT_STATE_DIR/replies.jsonl"
  ACTIONS_LOG="$CURRENT_STATE_DIR/actions.jsonl"
  MODES_CONFIG_FILE="$CURRENT_STATE_DIR/modes.json"
  RELATIONSHIPS_FILE="$CURRENT_STATE_DIR/relationships.json"
  MODE_LOG_FILE="$CURRENT_STATE_DIR/mode-log.jsonl"
  MANIFESTO_FILE="$CURRENT_STATE_DIR/manifesto.md"
  NORMS_FILE="$CURRENT_STATE_DIR/norms.jsonl"
  BOT_ENV_FILE="$CURRENT_STATE_DIR/bot.env"
  REDDIT_ENV_FILE="$CURRENT_STATE_DIR/reddit.env"
  DAEMON_STDOUT_LOG="$CURRENT_STATE_DIR/daemon.log"
  DAEMON_STDERR_LOG="$CURRENT_STATE_DIR/daemon-error.log"
  if [ "$MULTI_PROFILE" -eq 1 ]; then
    SHARED_INSTRUCTIONS_FILE="$STATE_ROOT/shared-instructions.md"
    CORE_DEFAULT_INSTRUCTIONS_FILE="$STATE_ROOT/core-default-instructions.md"
    LEGACY_GLOBAL_INSTRUCTIONS_FILE="$STATE_ROOT/global-default-instructions.md"
  else
    SHARED_INSTRUCTIONS_FILE="$CURRENT_STATE_DIR/shared-instructions.md"
    CORE_DEFAULT_INSTRUCTIONS_FILE="$CURRENT_STATE_DIR/core-default-instructions.md"
    LEGACY_GLOBAL_INSTRUCTIONS_FILE="$CURRENT_STATE_DIR/global-default-instructions.md"
  fi
  OAUTH_PENDING_FILE="$CURRENT_STATE_DIR/.oauth-pending.json"
  OAUTH_RESULT_FILE="$CURRENT_STATE_DIR/.oauth-result.json"
  OAUTH_LISTENER_PID_FILE="$CURRENT_STATE_DIR/.oauth-listener.pid"
}

run_daemon() {
  VR_STATE_DIR="$CURRENT_STATE_DIR" \
  VR_SHARED_INSTRUCTIONS_FILE="$SHARED_INSTRUCTIONS_FILE" \
  VR_CORE_INSTRUCTIONS_FILE="$CORE_DEFAULT_INSTRUCTIONS_FILE" \
  "$DAEMON_SCRIPT" "$@"
}

is_legacy_manifesto_default_file() {
  file=${1-}
  [ -f "$file" ] || return 1
  tmp_legacy=$(mktemp "${TMPDIR:-/tmp}/vr-legacy-manifesto.XXXXXX")
  cat > "$tmp_legacy" <<'LEGACY'
# Virtual Redditor Manifesto

1. Protect discourse continuity over rhetorical purity.
2. Prefer specific correction to vague condemnation.
3. Keep sanctions legible unless mode doctrine permits opacity.
4. Never punish without first speaking directly to the triggering utterance.
5. Treat repeat behavior as context, not destiny.
6. Separate playful persona from enforcement authority when possible.
7. Keep reversible records for every enforcement action.
LEGACY
  if cmp -s "$file" "$tmp_legacy"; then
    rm -f "$tmp_legacy"
    return 0
  fi
  rm -f "$tmp_legacy"
  return 1
}

ensure_instruction_files() {
  mkdir -p "$(dirname "$SHARED_INSTRUCTIONS_FILE")"
  app_default="$SCRIPT_DIR/../manifesto.md"
  if [ ! -f "$CORE_DEFAULT_INSTRUCTIONS_FILE" ]; then
    if [ -f "$app_default" ]; then
      cp "$app_default" "$CORE_DEFAULT_INSTRUCTIONS_FILE" 2>/dev/null || cat "$app_default" > "$CORE_DEFAULT_INSTRUCTIONS_FILE"
    else
      cat > "$CORE_DEFAULT_INSTRUCTIONS_FILE" <<'DEFAULTS'
# Global Default Instructions

1. Optimize for useful participation in the live thread.
   - Add signal, context, synthesis, or levity with purpose.
   - Avoid generic filler, repetitive moralizing, or performative moderation.
2. Match persona style without losing factual discipline.
   - Persona may be playful, sharp, or formal.
   - Facts, uncertainty, and policy constraints still take priority.
3. Keep claims truthful and bounded.
   - Do not invent facts, quotes, sources, or prior interactions.
   - If uncertain, say so briefly and continue with best-effort reasoning.
4. Keep interventions specific and actionable.
   - Prefer concrete correction over vague condemnation.
   - Critique ideas and behavior, not identity.
5. Keep tone non-escalatory by default.
   - Never escalate intensity, hostility, or rhetoric first.
   - Mirror or less; prefer de-escalation whenever possible.
6. Keep participation targeted to avoid saturation.
   - Prioritize high-value moments over replying everywhere.
   - Remain available to others while avoiding dogpile behavior.
7. Keep enforcement legible and proportional.
   - Separate conversational voice from enforcement authority when possible.
   - Do not punish without first addressing the triggering utterance.
8. Keep sanctions auditable and reversible where platform allows.
   - Leave clear, factual public notices when notices are enabled.
   - Avoid humiliation language, taunting, or victory framing.
9. After sanctioning a user in a thread, sever that dyad for that thread.
   - No further replies to that user in that thread.
   - No @mention, quoting, or alluding to that exchange.
   - No reference to the pre-ban exchange inside ban reasoning text.
10. Apply a cooling window after sanctioning.
    - For 24-72 hours, do not reply to that user in any thread.
    - Exception: allow replies only when explicitly summoned by mention, if summon behavior is enabled.
11. Respect moderator governance and subreddit context.
    - Follow moderator instructions when relevant and lawful under platform rules.
    - Treat norms as local and evolving; update behavior from observed context.
12. Protect users and operators from unnecessary risk.
    - No doxxing, no private-data speculation, no targeted harassment.
    - No calls to unsafe real-world behavior or illegal activity.
DEFAULTS
    fi
  fi

  if [ ! -f "$SHARED_INSTRUCTIONS_FILE" ]; then
    if [ -f "$LEGACY_GLOBAL_INSTRUCTIONS_FILE" ]; then
      if cmp -s "$LEGACY_GLOBAL_INSTRUCTIONS_FILE" "$CORE_DEFAULT_INSTRUCTIONS_FILE" || is_legacy_manifesto_default_file "$LEGACY_GLOBAL_INSTRUCTIONS_FILE"; then
        : > "$SHARED_INSTRUCTIONS_FILE"
      else
        cp "$LEGACY_GLOBAL_INSTRUCTIONS_FILE" "$SHARED_INSTRUCTIONS_FILE" 2>/dev/null || cat "$LEGACY_GLOBAL_INSTRUCTIONS_FILE" > "$SHARED_INSTRUCTIONS_FILE"
      fi
    else
      : > "$SHARED_INSTRUCTIONS_FILE"
    fi
  fi
}

ui_config_file() {
  base="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/virtual-redditor"
  mkdir -p "$base"
  printf '%s\n' "$base/config"
}

validate_ui_pref_key() {
  key=${1-}
  case "$key" in
    [a-z0-9][a-z0-9._-]*)
      ;;
    *)
      jq -cn --arg err "invalid ui pref key: $key" '{ok:false,error:$err}'
      exit 2
      ;;
  esac
}

sanitize_ui_pref_value() {
  value=${1-}
  printf '%s' "$value" | tr '\r\n' ' '
}

write_key_value_file() {
  file=$1
  key=$2
  value=$3

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/vr-ui-kv.XXXXXX")
  found=0
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "$key="*)
          if [ "$found" -eq 0 ]; then
            printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
            found=1
          fi
          ;;
        *)
          printf '%s\n' "$line" >>"$tmp_file"
          ;;
      esac
    done <"$file"
  fi
  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
  fi
  mv "$tmp_file" "$file"
}

profile_name_from_fs() {
  profile_id=$1
  name_file=$(profile_name_file "$profile_id")
  if [ -f "$name_file" ]; then
    head -n 1 "$name_file" 2>/dev/null | tr -d '\r'
    return
  fi
  printf '%s' "$profile_id"
}

read_env_var() {
  file=$1
  key=$2
  if [ ! -f "$file" ]; then
    printf '%s' ''
    return 0
  fi
  (
    # shellcheck disable=SC1090
    . "$file" >/dev/null 2>&1 || exit 1
    eval "printf '%s' \"\${$key-}\""
  ) 2>/dev/null || printf '%s' ''
}

profile_username_from_env() {
  profile_id=$1
  env_file="$(profile_dir "$profile_id")/reddit.env"
  read_env_var "$env_file" REDDIT_USERNAME
}

profile_subreddit_from_env() {
  profile_id=$1
  env_file="$(profile_dir "$profile_id")/reddit.env"
  read_env_var "$env_file" SUBREDDIT
}

profile_connected_from_env() {
  profile_id=$1
  env_file="$(profile_dir "$profile_id")/reddit.env"
  client_id=$(read_env_var "$env_file" REDDIT_CLIENT_ID)
  refresh_token=$(read_env_var "$env_file" REDDIT_REFRESH_TOKEN)
  username=$(read_env_var "$env_file" REDDIT_USERNAME)
  if [ -n "$client_id" ] && [ -n "$refresh_token" ] && [ -n "$username" ]; then
    printf '%s' "true"
  else
    printf '%s' "false"
  fi
}

normalize_name_for_compare() {
  printf '%s' "${1-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]'
}

normalize_username_for_compare() {
  printf '%s' "${1-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed 's#^/*u/##I' | tr '[:upper:]' '[:lower:]'
}

profile_name_conflicts() {
  wanted=$(normalize_name_for_compare "${1-}")
  except_id=${2-}
  [ -z "$wanted" ] && return 1
  [ "$MULTI_PROFILE" -eq 1 ] || return 1
  ensure_multi_profile_root
  for dir in "$PROFILES_DIR"/*; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    [ -n "$except_id" ] && [ "$id" = "$except_id" ] && continue
    existing=$(profile_name_from_fs "$id")
    existing_norm=$(normalize_name_for_compare "$existing")
    if [ -n "$existing_norm" ] && [ "$existing_norm" = "$wanted" ]; then
      return 0
    fi
  done
  return 1
}

profile_username_conflicts() {
  wanted=$(normalize_username_for_compare "${1-}")
  except_id=${2-}
  [ -z "$wanted" ] && return 1
  [ "$MULTI_PROFILE" -eq 1 ] || return 1
  ensure_multi_profile_root
  for dir in "$PROFILES_DIR"/*; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    [ -n "$except_id" ] && [ "$id" = "$except_id" ] && continue
    existing=$(profile_username_from_env "$id")
    existing_norm=$(normalize_username_for_compare "$existing")
    if [ -n "$existing_norm" ] && [ "$existing_norm" = "$wanted" ]; then
      return 0
    fi
  done
  return 1
}

list_profiles_json() {
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    reddit_env="$CURRENT_STATE_DIR/reddit.env"
    username=$(read_env_var "$reddit_env" REDDIT_USERNAME)
    client_id=$(read_env_var "$reddit_env" REDDIT_CLIENT_ID)
    refresh_token=$(read_env_var "$reddit_env" REDDIT_REFRESH_TOKEN)
    subreddit=$(read_env_var "$reddit_env" SUBREDDIT)
    connected=false
    if [ -n "$client_id" ] && [ -n "$refresh_token" ] && [ -n "$username" ]; then
      connected=true
    fi
    jq -cn \
      --arg id "single" \
      --arg path "$CURRENT_STATE_DIR" \
      --arg username "$username" \
      --arg subreddit "$subreddit" \
      --argjson connected "$connected" \
      '{ok:true,multiProfile:false,activeProfile:$id,profiles:[{id:$id,name:"single",path:$path,username:$username,subreddit:$subreddit,connected:$connected,selected:true}]}'
    return
  fi

  ensure_multi_profile_root

  # Clean up legacy placeholder default profile from older builds.
  default_dir=$(profile_dir default)
  if [ -d "$default_dir" ]; then
    count_dirs=$(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    default_user=$(read_env_var "$default_dir/reddit.env" REDDIT_USERNAME)
    default_sub=$(read_env_var "$default_dir/reddit.env" SUBREDDIT)
    default_client=$(read_env_var "$default_dir/reddit.env" REDDIT_CLIENT_ID)
    default_refresh=$(read_env_var "$default_dir/reddit.env" REDDIT_REFRESH_TOKEN)
    if [ "$count_dirs" = "1" ] && [ -z "$default_user" ] && [ -z "$default_sub" ] && [ -z "$default_client" ] && [ -z "$default_refresh" ]; then
      force_delete_dir "$default_dir" >/dev/null 2>&1 || true
      if [ "$ACTIVE_PROFILE_ID" = "default" ]; then
        ACTIVE_PROFILE_ID=''
        printf '%s\n' '' > "$ACTIVE_PROFILE_FILE"
      fi
    fi
  fi

  list_json='[]'
  for dir in "$PROFILES_DIR"/*; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    name=$(profile_name_from_fs "$id")
    username=$(profile_username_from_env "$id")
    subreddit=$(profile_subreddit_from_env "$id")
    connected=$(profile_connected_from_env "$id")
    selected=false
    if [ "$id" = "$ACTIVE_PROFILE_ID" ]; then
      selected=true
    fi
    row=$(jq -cn --arg id "$id" --arg name "$name" --arg path "$dir" --arg username "$username" --arg subreddit "$subreddit" --argjson connected "$connected" --argjson selected "$selected" '{id:$id,name:$name,path:$path,username:$username,subreddit:$subreddit,connected:$connected,selected:$selected}')
    list_json=$(jq -cn --argjson list "$list_json" --argjson row "$row" '$list + [$row]')
  done

  sorted=$(printf '%s' "$list_json" | jq -c 'sort_by(.name, .id)')
  if ! printf '%s' "$sorted" | jq -e --arg active "$ACTIVE_PROFILE_ID" 'map(.id) | index($active) != null' >/dev/null 2>&1; then
    ACTIVE_PROFILE_ID=''
    printf '%s\n' '' > "$ACTIVE_PROFILE_FILE"
  fi
  jq -cn --argjson profiles "$sorted" --arg active "$ACTIVE_PROFILE_ID" '{ok:true,multiProfile:true,activeProfile:$active,profiles:$profiles}'
}

create_profile_json() {
  name=${1-}
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    jq -cn '{ok:false,error:"create-profile unavailable when VR_STATE_DIR is explicitly set"}'
    return 1
  fi

  name=$(printf '%s' "$name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$name" ] && name="Virtual Redditor"

  if profile_name_conflicts "$name" ""; then
    jq -cn --arg err "local name already exists: $name" '{ok:false,error:$err}'
    return 1
  fi

  ensure_multi_profile_root

  base=$(slugify_profile_id "$name")
  id=$base
  i=2
  while [ -d "$(profile_dir "$id")" ]; do
    id="${base}-${i}"
    i=$((i + 1))
  done

  ensure_profile_runtime "$id"
  printf '%s\n' "$name" > "$(profile_name_file "$id")"
  : > "$(profile_dir "$id")/manifesto.md"
  : > "$(profile_dir "$id")/norms.jsonl"

  printf '%s\n' "$id" > "$ACTIVE_PROFILE_FILE"
  ACTIVE_PROFILE_ID=$id
  CURRENT_STATE_DIR=$(profile_dir "$id")
  refresh_paths

  jq -cn --arg id "$id" --arg name "$name" --arg path "$CURRENT_STATE_DIR" '{ok:true,profile:{id:$id,name:$name,path:$path},activeProfile:$id}'
}

select_profile_json() {
  profile_id=${1-}
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    jq -cn '{ok:false,error:"select-profile unavailable when VR_STATE_DIR is explicitly set"}'
    return 1
  fi

  profile_id=$(slugify_profile_id "$profile_id")
  dir=$(profile_dir "$profile_id")
  if [ ! -d "$dir" ]; then
    jq -cn --arg err "unknown profile: $profile_id" '{ok:false,error:$err}'
    return 1
  fi

  printf '%s\n' "$profile_id" > "$ACTIVE_PROFILE_FILE"
  ACTIVE_PROFILE_ID=$profile_id
  CURRENT_STATE_DIR=$dir
  refresh_paths
  (
    run_daemon bootstrap >/dev/null 2>&1 || true
  ) &

  jq -cn --arg active "$ACTIVE_PROFILE_ID" '{ok:true,activeProfile:$active}'
}

rename_profile_json() {
  profile_id=${1-}
  new_name=${2-}
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    jq -cn '{ok:false,error:"rename-profile unavailable when VR_STATE_DIR is explicitly set"}'
    return 1
  fi
  profile_id=$(slugify_profile_id "$profile_id")
  dir=$(profile_dir "$profile_id")
  if [ ! -d "$dir" ]; then
    jq -cn --arg err "unknown profile: $profile_id" '{ok:false,error:$err}'
    return 1
  fi
  new_name=$(printf '%s' "$new_name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$new_name" ] && new_name="$profile_id"
  if profile_name_conflicts "$new_name" "$profile_id"; then
    jq -cn --arg err "local name already exists: $new_name" '{ok:false,error:$err}'
    return 1
  fi
  printf '%s\n' "$new_name" > "$(profile_name_file "$profile_id")"
  jq -cn --arg id "$profile_id" --arg name "$new_name" '{ok:true,profile:{id:$id,name:$name}}'
}

delete_profile_json() {
  profile_id=${1-}
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    jq -cn '{ok:false,error:"delete-profile unavailable when VR_STATE_DIR is explicitly set"}'
    return 1
  fi
  profile_id=$(slugify_profile_id "$profile_id")
  dir=$(profile_dir "$profile_id")
  if [ ! -d "$dir" ]; then
    jq -cn --arg err "unknown profile: $profile_id" '{ok:false,error:$err}'
    return 1
  fi

  trash_root="$STATE_ROOT/.trash"
  mkdir -p "$trash_root"
  trash_target="$trash_root/${profile_id}-$(date +%s)-$$"
  if ! mv "$dir" "$trash_target" 2>/dev/null; then
    # Fallback for edge cases where atomic move fails.
    if ! force_delete_dir "$dir"; then
      jq -cn --arg err "could not delete profile directory: $dir" '{ok:false,error:$err}'
      return 1
    fi
  else
    (
      force_delete_dir "$trash_target" >/dev/null 2>&1 || true
    ) &
  fi

  next_active=''
  for d in "$PROFILES_DIR"/*; do
    [ -d "$d" ] || continue
    next_active=$(basename "$d")
    break
  done
  if [ -n "$next_active" ]; then
    printf '%s\n' "$next_active" > "$ACTIVE_PROFILE_FILE"
    ACTIVE_PROFILE_ID=$next_active
    CURRENT_STATE_DIR=$(profile_dir "$next_active")
    refresh_paths
    run_daemon bootstrap >/dev/null 2>&1 || true
  else
    printf '%s\n' '' > "$ACTIVE_PROFILE_FILE"
    ACTIVE_PROFILE_ID=''
    CURRENT_STATE_DIR=$(runtime_state_dir)
    mkdir -p "$CURRENT_STATE_DIR"
    refresh_paths
    run_daemon bootstrap >/dev/null 2>&1 || true
  fi

  jq -cn --arg deleted "$profile_id" --arg active "$ACTIVE_PROFILE_ID" '{ok:true,deletedProfile:$deleted,activeProfile:$active}'
}

merge_status() {
  settings=$(run_daemon settings 2>/dev/null || jq -cn '{ok:false,error:"settings unavailable"}')
  metrics=$(run_daemon metrics 2>/dev/null || jq -cn '{ok:false,error:"metrics unavailable"}')
  launchd=$(run_daemon launchd-status 2>/dev/null || jq -cn '{ok:false,error:"launchd unavailable"}')
  profiles=$(list_profiles_json 2>/dev/null || jq -cn '{ok:false,error:"profiles unavailable",profiles:[]}')

  jq -cn \
    --argjson settings "$settings" \
    --argjson metrics "$metrics" \
    --argjson launchd "$launchd" \
    --argjson profiles "$profiles" \
    --arg state_root "$STATE_ROOT" \
    --arg state_dir "$CURRENT_STATE_DIR" \
    --arg active_profile "$ACTIVE_PROFILE_ID" \
    --argjson multi_profile "$MULTI_PROFILE" \
    '{ok:true,multiProfile:($multi_profile==1),stateRoot:$state_root,stateDir:$state_dir,activeProfile:$active_profile,settings:$settings,metrics:$metrics,launchd:$launchd,profiles:$profiles}'
}

read_file_json() {
  target=$1
  file=''

  case "$target" in
    manifesto) file="$MANIFESTO_FILE" ;;
    norms) file="$NORMS_FILE" ;;
    shared-instructions) file="$SHARED_INSTRUCTIONS_FILE" ;;
    core-instructions) file="$CORE_DEFAULT_INSTRUCTIONS_FILE" ;;
    bot-env) file="$BOT_ENV_FILE" ;;
    reddit-env) file="$REDDIT_ENV_FILE" ;;
    daemon-log) file="$DAEMON_STDOUT_LOG" ;;
    daemon-error-log) file="$DAEMON_STDERR_LOG" ;;
    *)
      jq -cn --arg err "unknown read-file target: $target" '{ok:false,error:$err}'
      return 1
      ;;
  esac

  if [ ! -f "$file" ]; then
    jq -cn --arg target "$target" --arg path "$file" '{ok:true,target:$target,path:$path,content:""}'
    return 0
  fi

  jq -cn --arg target "$target" --arg path "$file" --rawfile content "$file" '{ok:true,target:$target,path:$path,content:$content}'
}

read_doctrine_json() {
  manifesto_content=''
  norms_content=''
  [ -f "$MANIFESTO_FILE" ] && manifesto_content=$(cat "$MANIFESTO_FILE" 2>/dev/null || printf '')
  [ -f "$NORMS_FILE" ] && norms_content=$(cat "$NORMS_FILE" 2>/dev/null || printf '')
  jq -cn \
    --arg manifesto_path "$MANIFESTO_FILE" \
    --arg norms_path "$NORMS_FILE" \
    --arg manifesto "$manifesto_content" \
    --arg norms "$norms_content" \
    '{ok:true,manifesto:{path:$manifesto_path,content:$manifesto},norms:{path:$norms_path,content:$norms}}'
}

write_file_json() {
  target=$1
  content=$2
  file=''

  case "$target" in
    manifesto) file="$MANIFESTO_FILE" ;;
    norms) file="$NORMS_FILE" ;;
    shared-instructions) file="$SHARED_INSTRUCTIONS_FILE" ;;
    core-instructions) file="$CORE_DEFAULT_INSTRUCTIONS_FILE" ;;
    bot-env) file="$BOT_ENV_FILE" ;;
    reddit-env) file="$REDDIT_ENV_FILE" ;;
    *)
      jq -cn --arg err "unknown write-file target: $target" '{ok:false,error:$err}'
      return 1
      ;;
  esac

  mkdir -p "$(dirname "$file")"
  printf '%s' "$content" > "$file"
  jq -cn --arg target "$target" --arg path "$file" '{ok:true,target:$target,path:$path}'
}

tail_log_json() {
  lines=${1-120}
  case "$lines" in
    ''|*[!0-9]*) lines=120 ;;
  esac
  [ "$lines" -lt 1 ] && lines=1

  stdout_tail=''
  stderr_tail=''
  if [ -f "$DAEMON_STDOUT_LOG" ]; then
    stdout_tail=$(tail -n "$lines" "$DAEMON_STDOUT_LOG" 2>/dev/null || printf '')
  fi
  if [ -f "$DAEMON_STDERR_LOG" ]; then
    stderr_tail=$(tail -n "$lines" "$DAEMON_STDERR_LOG" 2>/dev/null || printf '')
  fi

  jq -cn \
    --arg path_stdout "$DAEMON_STDOUT_LOG" \
    --arg path_stderr "$DAEMON_STDERR_LOG" \
    --arg stdout "$stdout_tail" \
    --arg stderr "$stderr_tail" \
    '{ok:true,stdout:{path:$path_stdout,tail:$stdout},stderr:{path:$path_stderr,tail:$stderr}}'
}

oauth_now_epoch() {
  date +%s
}

oauth_rand_hex() {
  if command -v od >/dev/null 2>&1; then
    od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'
  else
    printf '%s%s' "$$" "$(oauth_now_epoch)"
  fi
}

oauth_url_encode() {
  printf '%s' "${1-}" | jq -sRr @uri
}

oauth_url_decode() {
  encoded=${1-}
  encoded=$(printf '%s' "$encoded" | sed 's/+/ /g')
  printf '%b' "$(printf '%s' "$encoded" | sed 's/%/\\x/g')"
}

oauth_query_param() {
  key=$1
  query=$2
  printf '%s' "$query" | tr '&' '\n' | awk -F= -v k="$key" '$1==k { if (index($0,"=")>0) print substr($0,index($0,"=")+1); exit }'
}

oauth_shell_quote() {
  raw=${1-}
  escaped=$(printf '%s' "$raw" | sed "s/'/'\"'\"'/g")
  printf "'%s'" "$escaped"
}

oauth_env_upsert() {
  file=$1
  key=$2
  value=${3-}
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || touch "$file"
  tmp=$(mktemp "${TMPDIR:-/tmp}/vr-oauth-env.XXXXXX")
  awk -F= -v k="$key" '$1 != k { print $0 }' "$file" > "$tmp"
  printf '%s=%s\n' "$key" "$(oauth_shell_quote "$value")" >> "$tmp"
  mv "$tmp" "$file"
}

oauth_identity_slug() {
  raw=${1-}
  slug=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9_-]#-#g; s#--*#-#g; s#^-##; s#-$##')
  printf '%s' "$slug"
}

oauth_default_user_agent() {
  username_raw=${1-}
  subreddit_raw=${2-}
  profile_raw=${ACTIVE_PROFILE_ID-}

  username_safe=$(oauth_identity_slug "$username_raw")
  subreddit_safe=$(oauth_identity_slug "$subreddit_raw")
  profile_safe=$(oauth_identity_slug "$profile_raw")

  [ -z "$username_safe" ] && username_safe="virtual_redditor"
  [ -z "$subreddit_safe" ] && subreddit_safe="unknown"
  [ -z "$profile_safe" ] && profile_safe="single"

  # Reddit guidance: include platform/app/version and "by /u/<account>".
  printf 'script:virtual-redditor:%s:1.0 (by /u/%s; subreddit:r/%s)' "$profile_safe" "$username_safe" "$subreddit_safe"
}

oauth_kill_listener() {
  if [ -f "$OAUTH_LISTENER_PID_FILE" ]; then
    pid=$(cat "$OAUTH_LISTENER_PID_FILE" 2>/dev/null || printf '')
    case "$pid" in
      ''|*[!0-9]*)
        :
        ;;
      *)
        kill "$pid" >/dev/null 2>&1 || true
        ;;
    esac
    rm -f "$OAUTH_LISTENER_PID_FILE"
  fi
}

oauth_write_result_error() {
  err=$1
  desc=${2-}
  jq -cn --arg status "error" --arg error "$err" --arg error_description "$desc" --argjson at "$(oauth_now_epoch)" \
    '{ok:true,status:$status,error:$error,error_description:$error_description,receivedAt:$at}' > "$OAUTH_RESULT_FILE"
}

oauth_start_listener_background() {
  port=$1
  (
    request_file=$(mktemp "${TMPDIR:-/tmp}/vr-oauth-request.XXXXXX")
    response='HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!doctype html><html><head><meta charset="utf-8"><title>Virtual Redditor Connected</title></head><body style="font-family:-apple-system,Segoe UI,sans-serif;padding:24px;background:#f7f3ea;color:#222;"><h2>Virtual Redditor is connected.</h2><p>You can close this tab and return to the app.</p></body></html>'
    if ! command -v nc >/dev/null 2>&1; then
      oauth_write_result_error "listener_unavailable" "netcat (nc) is required for loopback capture"
      rm -f "$request_file"
      exit 0
    fi

    if ! printf '%b' "$response" | nc -l 127.0.0.1 "$port" > "$request_file" 2>/dev/null; then
      oauth_write_result_error "listener_failed" "failed while waiting for Reddit callback"
      rm -f "$request_file"
      exit 0
    fi

    req_line=$(head -n 1 "$request_file" 2>/dev/null | tr -d '\r')
    req_path=$(printf '%s' "$req_line" | awk '{print $2}')
    query=''
    case "$req_path" in
      *\?*) query=${req_path#*\?} ;;
    esac

    code=$(oauth_url_decode "$(oauth_query_param code "$query")")
    cb_state=$(oauth_url_decode "$(oauth_query_param state "$query")")
    cb_error=$(oauth_url_decode "$(oauth_query_param error "$query")")
    cb_error_desc=$(oauth_url_decode "$(oauth_query_param error_description "$query")")
    at=$(oauth_now_epoch)

    if [ -n "$cb_error" ]; then
      jq -cn \
        --arg status "error" \
        --arg error "$cb_error" \
        --arg error_description "$cb_error_desc" \
        --arg state "$cb_state" \
        --argjson at "$at" \
        '{ok:true,status:$status,error:$error,error_description:$error_description,state:$state,receivedAt:$at}' > "$OAUTH_RESULT_FILE"
    elif [ -z "$code" ]; then
      oauth_write_result_error "missing_code" "callback did not include an authorization code"
    else
      jq -cn \
        --arg status "received" \
        --arg code "$code" \
        --arg state "$cb_state" \
        --argjson at "$at" \
        '{ok:true,status:$status,code:$code,state:$state,receivedAt:$at}' > "$OAUTH_RESULT_FILE"
    fi

    rm -f "$request_file"
  ) >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$OAUTH_LISTENER_PID_FILE"
}

oauth_port_available() {
  port=$1
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

oauth_begin_json() {
  client_id=${1-}
  client_secret=${2-}
  subreddit=${3-}
  username_hint=${4-}

  if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
    jq -cn '{ok:false,error:"oauth-begin requires CLIENT_ID CLIENT_SECRET"}'
    return 1
  fi

  port=8765
  redirect_uri="http://127.0.0.1:${port}/vr/callback"
  scope='identity read submit modposts modcontributors modconfig modflair modlog modwiki modself modothers privatemessages'
  state_token=$(oauth_rand_hex)
  user_agent=$(oauth_default_user_agent "$username_hint" "$subreddit")

  if ! oauth_port_available "$port"; then
    jq -cn --arg err "loopback port ${port} is in use; close the conflicting process and try again" '{ok:false,error:$err}'
    return 1
  fi

  oauth_kill_listener
  rm -f "$OAUTH_RESULT_FILE"

  auth_url="https://www.reddit.com/api/v1/authorize?client_id=$(oauth_url_encode "$client_id")&response_type=code&state=$(oauth_url_encode "$state_token")&redirect_uri=$(oauth_url_encode "$redirect_uri")&duration=permanent&scope=$(oauth_url_encode "$scope")"
  pending=$(jq -cn \
    --arg client_id "$client_id" \
    --arg client_secret "$client_secret" \
    --arg subreddit "$subreddit" \
    --arg username_hint "$username_hint" \
    --arg user_agent "$user_agent" \
    --arg redirect_uri "$redirect_uri" \
    --arg auth_url "$auth_url" \
    --arg scope "$scope" \
    --arg state "$state_token" \
    --argjson started_at "$(oauth_now_epoch)" \
    --argjson port "$port" \
    '{ok:true,state:$state,redirect_uri:$redirect_uri,auth_url:$auth_url,scope:$scope,port:$port,startedAt:$started_at,client_id:$client_id,client_secret:$client_secret,subreddit:$subreddit,username_hint:$username_hint,user_agent:$user_agent}')
  printf '%s\n' "$pending" > "$OAUTH_PENDING_FILE"
  chmod 600 "$OAUTH_PENDING_FILE" 2>/dev/null || true

  oauth_start_listener_background "$port"

  jq -cn \
    --arg redirect_uri "$redirect_uri" \
    --arg auth_url "$auth_url" \
    --arg scope "$scope" \
    --argjson port "$port" \
    '{ok:true,status:"waiting",redirectUri:$redirect_uri,authUrl:$auth_url,scope:$scope,port:$port}'
}

oauth_status_json() {
  if [ ! -f "$OAUTH_PENDING_FILE" ]; then
    jq -cn '{ok:true,status:"idle"}'
    return 0
  fi

  pending=$(cat "$OAUTH_PENDING_FILE" 2>/dev/null || printf '{}')
  redirect_uri=$(printf '%s' "$pending" | jq -r '.redirect_uri // empty' 2>/dev/null || printf '')
  auth_url=$(printf '%s' "$pending" | jq -r '.auth_url // empty' 2>/dev/null || printf '')
  scope=$(printf '%s' "$pending" | jq -r '.scope // empty' 2>/dev/null || printf '')
  port=$(printf '%s' "$pending" | jq -r '.port // 0' 2>/dev/null || printf '0')
  listener_active=false
  if [ -f "$OAUTH_LISTENER_PID_FILE" ]; then
    pid=$(cat "$OAUTH_LISTENER_PID_FILE" 2>/dev/null || printf '')
    case "$pid" in
      ''|*[!0-9]*)
        listener_active=false
        ;;
      *)
        if kill -0 "$pid" >/dev/null 2>&1; then
          listener_active=true
        fi
        ;;
    esac
  fi

  if [ -f "$OAUTH_RESULT_FILE" ]; then
    result=$(cat "$OAUTH_RESULT_FILE" 2>/dev/null || printf '{}')
    status=$(printf '%s' "$result" | jq -r '.status // "error"' 2>/dev/null || printf 'error')
    jq -cn \
      --arg status "$status" \
      --arg redirect_uri "$redirect_uri" \
      --arg auth_url "$auth_url" \
      --arg scope "$scope" \
      --argjson port "$port" \
      --argjson listener_active "$listener_active" \
      --argjson result "$result" \
      '{ok:true,status:$status,redirectUri:$redirect_uri,authUrl:$auth_url,scope:$scope,port:$port,listenerActive:$listener_active,result:$result}'
    return 0
  fi

  jq -cn \
    --arg status "waiting" \
    --arg redirect_uri "$redirect_uri" \
    --arg auth_url "$auth_url" \
    --arg scope "$scope" \
    --argjson port "$port" \
    --argjson listener_active "$listener_active" \
    '{ok:true,status:$status,redirectUri:$redirect_uri,authUrl:$auth_url,scope:$scope,port:$port,listenerActive:$listener_active}'
}

oauth_submit_callback_json() {
  callback=${1-}
  if [ -z "$callback" ]; then
    jq -cn '{ok:false,error:"oauth-submit-callback requires CALLBACK_URL_OR_QUERY"}'
    return 1
  fi
  if [ ! -f "$OAUTH_PENDING_FILE" ]; then
    jq -cn '{ok:false,error:"no oauth flow is active"}'
    return 1
  fi

  query=$callback
  case "$query" in
    *\?*) query=${query#*\?} ;;
  esac
  case "$query" in
    *\#*) query=${query%%\#*} ;;
  esac

  code=$(oauth_url_decode "$(oauth_query_param code "$query")")
  cb_state=$(oauth_url_decode "$(oauth_query_param state "$query")")
  cb_error=$(oauth_url_decode "$(oauth_query_param error "$query")")
  cb_error_desc=$(oauth_url_decode "$(oauth_query_param error_description "$query")")
  at=$(oauth_now_epoch)

  if [ -n "$cb_error" ]; then
    jq -cn \
      --arg status "error" \
      --arg error "$cb_error" \
      --arg error_description "$cb_error_desc" \
      --arg state "$cb_state" \
      --argjson at "$at" \
      '{ok:true,status:$status,error:$error,error_description:$error_description,state:$state,receivedAt:$at}' > "$OAUTH_RESULT_FILE"
  elif [ -z "$code" ]; then
    oauth_write_result_error "missing_code" "callback input did not include an authorization code"
  else
    jq -cn \
      --arg status "received" \
      --arg code "$code" \
      --arg state "$cb_state" \
      --argjson at "$at" \
      '{ok:true,status:$status,code:$code,state:$state,receivedAt:$at}' > "$OAUTH_RESULT_FILE"
  fi

  oauth_status_json
}

oauth_finish_json() {
  if [ ! -f "$OAUTH_PENDING_FILE" ]; then
    jq -cn '{ok:false,error:"no oauth flow is active"}'
    return 1
  fi
  if [ ! -f "$OAUTH_RESULT_FILE" ]; then
    jq -cn '{ok:false,error:"no callback received yet; complete browser authorization first"}'
    return 1
  fi

  pending=$(cat "$OAUTH_PENDING_FILE" 2>/dev/null || printf '{}')
  result=$(cat "$OAUTH_RESULT_FILE" 2>/dev/null || printf '{}')

  status=$(printf '%s' "$result" | jq -r '.status // "error"' 2>/dev/null || printf 'error')
  if [ "$status" != "received" ]; then
    err=$(printf '%s' "$result" | jq -r '.error // "oauth callback did not complete successfully"' 2>/dev/null || printf 'oauth callback failed')
    jq -cn --arg err "$err" '{ok:false,error:$err}'
    return 1
  fi

  expected_state=$(printf '%s' "$pending" | jq -r '.state // empty' 2>/dev/null || printf '')
  callback_state=$(printf '%s' "$result" | jq -r '.state // empty' 2>/dev/null || printf '')
  code=$(printf '%s' "$result" | jq -r '.code // empty' 2>/dev/null || printf '')
  client_id=$(printf '%s' "$pending" | jq -r '.client_id // empty' 2>/dev/null || printf '')
  client_secret=$(printf '%s' "$pending" | jq -r '.client_secret // empty' 2>/dev/null || printf '')
  redirect_uri=$(printf '%s' "$pending" | jq -r '.redirect_uri // empty' 2>/dev/null || printf '')
  subreddit=$(printf '%s' "$pending" | jq -r '.subreddit // empty' 2>/dev/null || printf '')
  username_hint=$(printf '%s' "$pending" | jq -r '.username_hint // empty' 2>/dev/null || printf '')
  user_agent=$(printf '%s' "$pending" | jq -r '.user_agent // empty' 2>/dev/null || printf '')

  if [ -z "$code" ]; then
    jq -cn '{ok:false,error:"oauth callback did not include code"}'
    return 1
  fi
  if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
    jq -cn '{ok:false,error:"pending oauth flow is missing reddit app credentials"}'
    return 1
  fi
  if [ -z "$redirect_uri" ]; then
    jq -cn '{ok:false,error:"pending oauth flow is missing redirect URI"}'
    return 1
  fi
  if [ -z "$expected_state" ] || [ "$callback_state" != "$expected_state" ]; then
    jq -cn '{ok:false,error:"oauth state mismatch; restart Connect flow for safety"}'
    return 1
  fi
  if [ -z "$user_agent" ]; then
    user_agent=$(oauth_default_user_agent "$username_hint" "$subreddit")
  fi

  token_response=$(curl -sS --fail \
    -u "$client_id:$client_secret" \
    -H "User-Agent: $user_agent" \
    --data-urlencode "grant_type=authorization_code" \
    --data-urlencode "code=$code" \
    --data-urlencode "redirect_uri=$redirect_uri" \
    https://www.reddit.com/api/v1/access_token 2>/dev/null || printf '')

  refresh_token=$(printf '%s' "$token_response" | jq -r '.refresh_token // empty' 2>/dev/null || printf '')
  access_token=$(printf '%s' "$token_response" | jq -r '.access_token // empty' 2>/dev/null || printf '')
  token_error=$(printf '%s' "$token_response" | jq -r '.error // empty' 2>/dev/null || printf '')

  if [ -z "$refresh_token" ]; then
    [ -z "$token_error" ] && token_error="failed to exchange authorization code for refresh token"
    jq -cn --arg err "$token_error" '{ok:false,error:$err}'
    return 1
  fi

  me_response='{}'
  if [ -n "$access_token" ]; then
    me_response=$(curl -sS --fail \
      -H "Authorization: bearer $access_token" \
      -H "User-Agent: $user_agent" \
      https://oauth.reddit.com/api/v1/me 2>/dev/null || printf '{}')
  fi
  reddit_username=$(printf '%s' "$me_response" | jq -r '.name // empty' 2>/dev/null || printf '')
  [ -z "$reddit_username" ] && reddit_username=$username_hint
  [ -z "$subreddit" ] && subreddit=$(read_env_var "$REDDIT_ENV_FILE" SUBREDDIT)
  [ -z "$reddit_username" ] && reddit_username=$(read_env_var "$REDDIT_ENV_FILE" REDDIT_USERNAME)
  user_agent=$(oauth_default_user_agent "$reddit_username" "$subreddit")

  if [ -n "$reddit_username" ] && profile_username_conflicts "$reddit_username" "$ACTIVE_PROFILE_ID"; then
    jq -cn --arg err "reddit username already belongs to another virtual redditor: $reddit_username" '{ok:false,error:$err}'
    return 1
  fi

  oauth_env_upsert "$REDDIT_ENV_FILE" REDDIT_CLIENT_ID "$client_id"
  oauth_env_upsert "$REDDIT_ENV_FILE" REDDIT_CLIENT_SECRET "$client_secret"
  oauth_env_upsert "$REDDIT_ENV_FILE" REDDIT_REFRESH_TOKEN "$refresh_token"
  oauth_env_upsert "$REDDIT_ENV_FILE" REDDIT_USER_AGENT "$user_agent"
  [ -n "$reddit_username" ] && oauth_env_upsert "$REDDIT_ENV_FILE" REDDIT_USERNAME "$reddit_username"
  [ -n "$subreddit" ] && oauth_env_upsert "$REDDIT_ENV_FILE" SUBREDDIT "$subreddit"

  oauth_kill_listener
  rm -f "$OAUTH_PENDING_FILE" "$OAUTH_RESULT_FILE"

  jq -cn \
    --arg reddit_username "$reddit_username" \
    --arg subreddit "$subreddit" \
    --arg user_agent "$user_agent" \
    --arg reddit_env "$REDDIT_ENV_FILE" \
    '{ok:true,connected:true,redditUsername:$reddit_username,subreddit:$subreddit,userAgent:$user_agent,redditEnv:$reddit_env}'
}

oauth_cancel_json() {
  oauth_kill_listener
  rm -f "$OAUTH_PENDING_FILE" "$OAUTH_RESULT_FILE"
  jq -cn '{ok:true,status:"cancelled"}'
}

format_epoch_month_year() {
  epoch_raw=${1-0}
  epoch_int=$(printf '%s' "$epoch_raw" | awk '{printf "%d", $1+0}')
  if [ "$epoch_int" -le 0 ]; then
    printf '%s' ''
    return 0
  fi
  if [ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ]; then
    date -r "$epoch_int" '+%b %Y' 2>/dev/null || printf '%s' ''
    return 0
  fi
  date -d "@$epoch_int" '+%b %Y' 2>/dev/null || printf '%s' ''
}

check_subreddit_json() {
  raw_name=${1-}
  name=$(printf '%s' "$raw_name" | sed 's#^[[:space:]]*##; s#[[:space:]]*$##')
  name=$(printf '%s' "$name" | sed -E 's#^https?://(www\.)?reddit\.com/##I; s#^/+##; s#^/?r/##I; s#/*$##')
  if [ -z "$name" ]; then
    jq -cn '{ok:true,exists:false,error:"Subreddit is required."}'
    return 0
  fi

  existing_username=$(read_env_var "$REDDIT_ENV_FILE" REDDIT_USERNAME)
  check_agent=$(oauth_default_user_agent "$existing_username" "$name")
  body=''
  http_status=''
  for host in old.reddit.com www.reddit.com; do
    url="https://$host/r/$name/about.json?raw_json=1"
    response=$(curl -L -sS --connect-timeout 5 --max-time 12 -A "$check_agent" -H 'accept: application/json' -w '\n__VR_HTTP_STATUS__:%{http_code}' "$url" 2>/dev/null || printf '')
    [ -n "$response" ] || continue
    status_candidate=$(printf '%s\n' "$response" | sed -n 's/^__VR_HTTP_STATUS__://p' | tail -n 1 | tr -d '\r')
    body_candidate=$(printf '%s\n' "$response" | sed '/^__VR_HTTP_STATUS__:/d')
    [ -n "$status_candidate" ] || continue
    if [ "$status_candidate" = "429" ] && [ "$host" = "old.reddit.com" ]; then
      continue
    fi
    http_status=$status_candidate
    body=$body_candidate
    break
  done

  if [ -z "$body" ]; then
    jq -cn --arg name "$name" '{ok:true,subreddit:$name,exists:false,error:"Could not verify subreddit right now."}'
    return 0
  fi

  kind=$(printf '%s' "$body" | jq -r '.kind // empty' 2>/dev/null || printf '')
  created_utc=$(printf '%s' "$body" | jq -r '.data.created_utc // empty' 2>/dev/null || printf '')
  if [ -n "$created_utc" ] && [ "$kind" = "t5" ]; then
    display=$(printf '%s' "$body" | jq -r '.data.display_name // empty' 2>/dev/null || printf '')
    [ -z "$display" ] && display=$name
    month_year=$(format_epoch_month_year "$created_utc")
    if [ -n "$month_year" ]; then
      since="community since $month_year"
    else
      since="community found"
    fi
    jq -cn \
      --arg name "$display" \
      --argjson createdUtc "$(printf '%s' "$created_utc" | awk '{printf "%d", $1+0}')" \
      --arg since "$since" \
      '{ok:true,exists:true,subreddit:$name,createdUtc:$createdUtc,since:$since}'
    return 0
  fi

  err_code=$(printf '%s' "$body" | jq -r '.error // empty' 2>/dev/null || printf '')
  if [ "$http_status" = "404" ] || [ "$err_code" = "404" ]; then
    jq -cn --arg name "$name" '{ok:true,subreddit:$name,exists:false,error:"Subreddit not found."}'
    return 0
  fi

  if [ "$kind" = "Listing" ]; then
    child_count=$(printf '%s' "$body" | jq -r '.data.children | length' 2>/dev/null || printf '')
    if [ "$child_count" = "0" ]; then
      jq -cn --arg name "$name" '{ok:true,subreddit:$name,exists:false,error:"Subreddit not found."}'
      return 0
    fi
  fi

  jq -cn --arg name "$name" '{ok:true,subreddit:$name,exists:false,error:"Could not verify subreddit right now."}'
}

main() {
  action=${1-}
  if [ -z "$action" ]; then
    jq -cn '{ok:false,error:"action required"}'
    exit 2
  fi
  shift || true

  resolve_current_state
  refresh_paths
  ensure_instruction_files

  case "$action" in
    list-themes)
      emit_theme_names
      ;;

    get-ui-prefs)
      cfg=$(ui_config_file)
      [ -f "$cfg" ] && cat "$cfg"
      ;;

    set-ui-pref)
      key=${1-}
      value=${2-}
      if [ -z "$key" ]; then
        jq -cn '{ok:false,error:"set-ui-pref requires KEY VALUE"}'
        exit 2
      fi
      validate_ui_pref_key "$key"
      value=$(sanitize_ui_pref_value "$value")
      cfg=$(ui_config_file)
      [ -f "$cfg" ] || : >"$cfg"
      write_key_value_file "$cfg" "$key" "$value"
      printf 'key=%s\n' "$key"
      printf 'value=%s\n' "$value"
      ;;

    init)
      run_daemon bootstrap
      ;;

    status)
      merge_status
      ;;

    install)
      run_daemon launchd-install
      ;;

    uninstall)
      run_daemon launchd-uninstall
      ;;

    start)
      run_daemon launchd-start
      ;;

    stop)
      run_daemon launchd-stop
      ;;

    restart)
      run_daemon launchd-stop >/dev/null 2>&1 || true
      run_daemon launchd-start
      ;;

    run-once)
      run_daemon once
      ;;

    extract-norms)
      run_daemon extract-norms
      ;;

    extract-norms-full)
      run_daemon extract-norms full
      ;;

    extract-norms-all)
      run_daemon extract-norms all
      ;;

    list-actions)
      run_daemon list-actions "${1-80}"
      ;;

    list-replies)
      run_daemon list-replies "${1-120}"
      ;;

    get-modes-config)
      run_daemon get-modes-config
      ;;

    save-modes-config)
      run_daemon save-modes-config "${1-}"
      ;;

    list-relationships)
      run_daemon list-relationships "${1-300}"
      ;;

    set-relationship)
      run_daemon set-relationship "${1-}" "${2-}" "${3-0}" "${4-manual-override}"
      ;;

    cancel-relationship-override)
      run_daemon cancel-relationship-override "${1-}"
      ;;

    list-mode-log)
      run_daemon list-mode-log "${1-200}"
      ;;

    undo)
      aid=${1-}
      if [ -z "$aid" ]; then
        jq -cn '{ok:false,error:"ACTION_ID required"}'
        exit 2
      fi
      run_daemon undo "$aid"
      ;;

    apologize)
      aid=${1-}
      shift || true
      if [ -z "$aid" ]; then
        jq -cn '{ok:false,error:"ACTION_ID required"}'
        exit 2
      fi
      run_daemon apologize "$aid" "${1-}"
      ;;

    set-setting)
      key=${1-}
      value=${2-}
      if [ -z "$key" ] || [ -z "$value" ]; then
        jq -cn '{ok:false,error:"set-setting requires KEY VALUE"}'
        exit 2
      fi
      run_daemon set-setting "$key" "$value"
      ;;

    set-reddit-setting)
      if [ "$#" -lt 2 ]; then
        jq -cn '{ok:false,error:"set-reddit-setting requires KEY VALUE"}'
        exit 2
      fi
      key=${1-}
      value=${2-}
      if [ -z "$key" ]; then
        jq -cn '{ok:false,error:"set-reddit-setting requires KEY VALUE"}'
        exit 2
      fi
      if [ "$key" = "REDDIT_USERNAME" ] && profile_username_conflicts "$value" "$ACTIVE_PROFILE_ID"; then
        jq -cn --arg err "reddit username already belongs to another virtual redditor: $value" '{ok:false,error:$err}'
        exit 1
      fi
      run_daemon set-reddit-setting "$key" "$value"
      ;;

    check-subreddit)
      check_subreddit_json "${1-}"
      ;;

    list-profiles)
      list_profiles_json
      ;;

    create-profile)
      create_profile_json "${1-}"
      ;;

    select-profile)
      profile_id=${1-}
      if [ -z "$profile_id" ]; then
        jq -cn '{ok:false,error:"PROFILE_ID required"}'
        exit 2
      fi
      select_profile_json "$profile_id"
      ;;

    rename-profile)
      profile_id=${1-}
      profile_name=${2-}
      if [ -z "$profile_id" ] || [ -z "$profile_name" ]; then
        jq -cn '{ok:false,error:"rename-profile requires PROFILE_ID NAME"}'
        exit 2
      fi
      rename_profile_json "$profile_id" "$profile_name"
      ;;

    delete-profile)
      profile_id=${1-}
      if [ -z "$profile_id" ]; then
        jq -cn '{ok:false,error:"delete-profile requires PROFILE_ID"}'
        exit 2
      fi
      delete_profile_json "$profile_id"
      ;;

    oauth-begin)
      oauth_begin_json "${1-}" "${2-}" "${3-}" "${4-}"
      ;;

    oauth-status)
      oauth_status_json
      ;;

    oauth-submit-callback)
      oauth_submit_callback_json "${1-}"
      ;;

    oauth-finish)
      oauth_finish_json
      ;;

    oauth-cancel)
      oauth_cancel_json
      ;;

    compiled-instructions)
      run_daemon compiled-instructions
      ;;

    read-file)
      target=${1-}
      if [ -z "$target" ]; then
        jq -cn '{ok:false,error:"TARGET required"}'
        exit 2
      fi
      read_file_json "$target"
      ;;

    read-doctrine)
      read_doctrine_json
      ;;

    write-file)
      target=${1-}
      content=${2-}
      if [ -z "$target" ]; then
        jq -cn '{ok:false,error:"TARGET required"}'
        exit 2
      fi
      write_file_json "$target" "$content"
      ;;

    tail-log)
      tail_log_json "${1-120}"
      ;;

    paths)
      jq -cn \
        --arg state "$CURRENT_STATE_DIR" \
        --arg root "$STATE_ROOT" \
        --arg actions "$ACTIONS_LOG" \
        --arg bans "$BANS_LOG" \
        --arg replies "$REPLIES_LOG" \
        --arg modes "$MODES_CONFIG_FILE" \
        --arg relationships "$RELATIONSHIPS_FILE" \
        --arg mode_log "$MODE_LOG_FILE" \
        --arg manifesto "$MANIFESTO_FILE" \
        --arg norms "$NORMS_FILE" \
        --arg shared_instructions "$SHARED_INSTRUCTIONS_FILE" \
        --arg core_instructions "$CORE_DEFAULT_INSTRUCTIONS_FILE" \
        --arg reddit_env "$REDDIT_ENV_FILE" \
        --arg bot_env "$BOT_ENV_FILE" \
        --arg daemon_log "$DAEMON_STDOUT_LOG" \
        --arg daemon_error_log "$DAEMON_STDERR_LOG" \
        --arg active_profile "$ACTIVE_PROFILE_ID" \
        --argjson multi_profile "$MULTI_PROFILE" \
        '{ok:true,stateRoot:$root,stateDir:$state,activeProfile:$active_profile,multiProfile:($multi_profile==1),paths:{actions:$actions,bans:$bans,replies:$replies,modes:$modes,relationships:$relationships,modeLog:$mode_log,manifesto:$manifesto,norms:$norms,sharedInstructions:$shared_instructions,coreInstructions:$core_instructions,redditEnv:$reddit_env,botEnv:$bot_env,daemonLog:$daemon_log,daemonErrorLog:$daemon_error_log}}'
      ;;

    *)
      jq -cn --arg err "unknown action: $action" '{ok:false,error:$err}'
      exit 2
      ;;
  esac
}

main "$@"
