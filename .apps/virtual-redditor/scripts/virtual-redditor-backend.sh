#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: virtual-redditor-backend.sh ACTION [ARGS...]

Actions:
  init
  status
  start
  stop
  restart
  run-once
  extract-norms
  list-actions [LIMIT]
  list-replies [LIMIT]
  undo ACTION_ID
  apologize ACTION_ID [MESSAGE]
  set-setting KEY VALUE
  set-reddit-setting KEY VALUE
  list-profiles
  create-profile NAME
  select-profile PROFILE_ID
  oauth-begin CLIENT_ID CLIENT_SECRET [SUBREDDIT] [USERNAME_HINT]
  oauth-status
  oauth-submit-callback CALLBACK_URL_OR_QUERY
  oauth-finish
  oauth-cancel
  read-file TARGET
  write-file TARGET CONTENT
  tail-log [LINES]

TARGET values for read-file:
  manifesto | norms | bot-env | reddit-env | daemon-log | daemon-error-log
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DAEMON_SCRIPT="$SCRIPT_DIR/virtual-redditor-daemon.sh"

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
  if [ -z "$active" ]; then
    active=default
  fi

  active=$(slugify_profile_id "$active")
  ensure_profile_runtime "$active"
  printf '%s\n' "$active" > "$ACTIVE_PROFILE_FILE"

  ACTIVE_PROFILE_ID=$active
  CURRENT_STATE_DIR=$(profile_dir "$active")
  return 0
}

refresh_paths() {
  BANS_LOG="$CURRENT_STATE_DIR/bans.jsonl"
  REPLIES_LOG="$CURRENT_STATE_DIR/replies.jsonl"
  ACTIONS_LOG="$CURRENT_STATE_DIR/actions.jsonl"
  MANIFESTO_FILE="$CURRENT_STATE_DIR/manifesto.md"
  NORMS_FILE="$CURRENT_STATE_DIR/norms.jsonl"
  BOT_ENV_FILE="$CURRENT_STATE_DIR/bot.env"
  REDDIT_ENV_FILE="$CURRENT_STATE_DIR/reddit.env"
  DAEMON_STDOUT_LOG="$CURRENT_STATE_DIR/daemon.log"
  DAEMON_STDERR_LOG="$CURRENT_STATE_DIR/daemon-error.log"
  OAUTH_PENDING_FILE="$CURRENT_STATE_DIR/.oauth-pending.json"
  OAUTH_RESULT_FILE="$CURRENT_STATE_DIR/.oauth-result.json"
  OAUTH_LISTENER_PID_FILE="$CURRENT_STATE_DIR/.oauth-listener.pid"
}

run_daemon() {
  VR_STATE_DIR="$CURRENT_STATE_DIR" "$DAEMON_SCRIPT" "$@"
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
  subreddit=$(read_env_var "$env_file" SUBREDDIT)
  if [ -n "$client_id" ] && [ -n "$refresh_token" ] && [ -n "$username" ] && [ -n "$subreddit" ]; then
    printf '%s' "true"
  else
    printf '%s' "false"
  fi
}

list_profiles_json() {
  if [ "$MULTI_PROFILE" -eq 0 ]; then
    reddit_env="$CURRENT_STATE_DIR/reddit.env"
    username=$(read_env_var "$reddit_env" REDDIT_USERNAME)
    subreddit=$(read_env_var "$reddit_env" SUBREDDIT)
    client_id=$(read_env_var "$reddit_env" REDDIT_CLIENT_ID)
    refresh_token=$(read_env_var "$reddit_env" REDDIT_REFRESH_TOKEN)
    connected=false
    if [ -n "$client_id" ] && [ -n "$refresh_token" ] && [ -n "$username" ] && [ -n "$subreddit" ]; then
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

  if ! find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d >/dev/null 2>&1; then
    ensure_profile_runtime default
    printf '%s\n' default > "$ACTIVE_PROFILE_FILE"
    ACTIVE_PROFILE_ID=default
    CURRENT_STATE_DIR=$(profile_dir default)
    refresh_paths
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
  run_daemon bootstrap >/dev/null 2>&1 || true

  jq -cn --arg active "$ACTIVE_PROFILE_ID" '{ok:true,activeProfile:$active}'
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

write_file_json() {
  target=$1
  content=$2
  file=''

  case "$target" in
    manifesto) file="$MANIFESTO_FILE" ;;
    norms) file="$NORMS_FILE" ;;
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

oauth_default_user_agent() {
  uname_raw=${1-}
  uname_safe=$(printf '%s' "$uname_raw" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9_-]#_#g')
  [ -z "$uname_safe" ] && uname_safe=virtual_redditor
  printf 'virtual-redditor/0.1-by-u/%s' "$uname_safe"
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
  user_agent=$(oauth_default_user_agent "$username_hint")

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
    user_agent=$(oauth_default_user_agent "$username_hint")
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
  [ -z "$user_agent" ] && user_agent=$(oauth_default_user_agent "$reddit_username")

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

main() {
  action=${1-}
  if [ -z "$action" ]; then
    jq -cn '{ok:false,error:"action required"}'
    exit 2
  fi
  shift || true

  resolve_current_state
  refresh_paths

  case "$action" in
    init)
      run_daemon bootstrap
      ;;

    status)
      merge_status
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

    list-actions)
      run_daemon list-actions "${1-80}"
      ;;

    list-replies)
      run_daemon list-replies "${1-120}"
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
      run_daemon set-reddit-setting "$key" "$value"
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

    read-file)
      target=${1-}
      if [ -z "$target" ]; then
        jq -cn '{ok:false,error:"TARGET required"}'
        exit 2
      fi
      read_file_json "$target"
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
        --arg manifesto "$MANIFESTO_FILE" \
        --arg norms "$NORMS_FILE" \
        --arg reddit_env "$REDDIT_ENV_FILE" \
        --arg bot_env "$BOT_ENV_FILE" \
        --arg daemon_log "$DAEMON_STDOUT_LOG" \
        --arg daemon_error_log "$DAEMON_STDERR_LOG" \
        --arg active_profile "$ACTIVE_PROFILE_ID" \
        --argjson multi_profile "$MULTI_PROFILE" \
        '{ok:true,stateRoot:$root,stateDir:$state,activeProfile:$active_profile,multiProfile:($multi_profile==1),paths:{actions:$actions,bans:$bans,replies:$replies,manifesto:$manifesto,norms:$norms,redditEnv:$reddit_env,botEnv:$bot_env,daemonLog:$daemon_log,daemonErrorLog:$daemon_error_log}}'
      ;;

    *)
      jq -cn --arg err "unknown action: $action" '{ok:false,error:$err}'
      exit 2
      ;;
  esac
}

main "$@"
