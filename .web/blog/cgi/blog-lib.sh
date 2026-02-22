#!/bin/sh
# Shared helpers for blog CGI scripts.

set -eu

blog_site_name=${WIZARDRY_SITE_NAME:-default}
blog_sites_dir=${WIZARDRY_SITES_DIR:-$HOME/sites}
blog_site_root="$blog_sites_dir/$blog_site_name"
blog_site_data="$blog_sites_dir/.sitedata/$blog_site_name"
blog_site_conf="$blog_site_root/site.conf"
blog_posts_dir="$blog_site_root/site/pages/posts"
blog_auth_dir="$blog_site_data/ssh-auth"
blog_users_dir="$blog_auth_dir/users"
blog_sessions_dir="$blog_auth_dir/sessions"
blog_state_dir="$blog_site_data/blog"
blog_drafts_dir="$blog_state_dir/drafts"
blog_uploads_dir="$blog_site_data/uploads"

BLOG_REQUEST_BODY=${BLOG_REQUEST_BODY-}
BLOG_SESSION_USERNAME=${BLOG_SESSION_USERNAME-}
BLOG_SESSION_FINGERPRINT=${BLOG_SESSION_FINGERPRINT-}
BLOG_SESSION_IS_ADMIN=${BLOG_SESSION_IS_ADMIN-}
BLOG_SESSION_TOKEN=${BLOG_SESSION_TOKEN-}
BLOG_SESSION_CSRF=${BLOG_SESSION_CSRF-}

blog_init() {
  mkdir -p "$blog_auth_dir" "$blog_users_dir" "$blog_sessions_dir" "$blog_state_dir" "$blog_drafts_dir" "$blog_uploads_dir"
  mkdir -p "$blog_posts_dir"
}

blog_now_epoch() {
  date +%s
}

blog_now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

blog_iso_to_epoch() {
  iso=${1-}
  if [ -z "$iso" ]; then
    printf '0\n'
    return 0
  fi

  if date -u -d "$iso" +%s >/dev/null 2>&1; then
    date -u -d "$iso" +%s
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s
    return 0
  fi

  printf '0\n'
}

blog_month_name() {
  month=${1-}
  case "$month" in
    01) printf 'January\n' ;;
    02) printf 'February\n' ;;
    03) printf 'March\n' ;;
    04) printf 'April\n' ;;
    05) printf 'May\n' ;;
    06) printf 'June\n' ;;
    07) printf 'July\n' ;;
    08) printf 'August\n' ;;
    09) printf 'September\n' ;;
    10) printf 'October\n' ;;
    11) printf 'November\n' ;;
    12) printf 'December\n' ;;
    *) printf 'Unknown\n' ;;
  esac
}

blog_iso_to_human_date() {
  iso=${1-}
  if [ -z "$iso" ]; then
    printf 'Unknown date\n'
    return 0
  fi

  if date -u -d "$iso" '+%B %e, %Y' >/dev/null 2>&1; then
    date -u -d "$iso" '+%B %e, %Y' | sed 's/  / /g'
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" '+%B %e, %Y' >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" '+%B %e, %Y' | sed 's/  / /g'
    return 0
  fi

  date_only=${iso%%T*}
  year=$(printf '%s' "$date_only" | cut -d- -f1)
  month=$(printf '%s' "$date_only" | cut -d- -f2)
  day=$(printf '%s' "$date_only" | cut -d- -f3 | sed 's/^0//')
  month_name=$(blog_month_name "$month")
  if [ -n "$year" ] && [ -n "$month" ] && [ -n "$day" ]; then
    printf '%s %s, %s\n' "$month_name" "$day" "$year"
    return 0
  fi

  printf '%s\n' "$date_only"
}

blog_word_count() {
  text=${1-}
  printf '%s' "$text" | tr -cs '[:alnum:]' '\n' | awk 'NF { c++ } END { print c + 0 }'
}

blog_estimated_read_minutes() {
  words=${1-0}
  case "$words" in ''|*[!0-9]*) words=0 ;; esac
  minutes=$(( (words + 199) / 200 ))
  if [ "$minutes" -lt 1 ]; then
    minutes=1
  fi
  printf '%s\n' "$minutes"
}

blog_json_escape() {
  printf '%s' "${1-}" | awk 'BEGIN{ORS=""} {
    gsub(/\\/, "\\\\");
    gsub(/"/, "\\\"");
    gsub(/\t/, "\\t");
    gsub(/\r/, "\\r");
    if (NR > 1) {
      printf "\\n";
    }
    printf "%s", $0;
  }'
}

blog_html_escape() {
  printf '%s' "${1-}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

blog_url_encode() {
  # URL-encode common path/query characters without external deps.
  printf '%s' "${1-}" | sed \
    -e 's/%/%25/g' \
    -e 's/ /%20/g' \
    -e 's/#/%23/g' \
    -e 's/?/%3F/g' \
    -e 's/&/%26/g' \
    -e 's/=/%3D/g' \
    -e 's/+/%2B/g' \
    -e 's/:/%3A/g' \
    -e 's/;/%3B/g' \
    -e 's/@/%40/g' \
    -e 's/,/%2C/g'
}

blog_yaml_escape() {
  printf '%s' "${1-}" | sed 's/"/\\"/g'
}

blog_slugify() {
  text=${1-}
  slug=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//')
  if [ -z "$slug" ]; then
    slug="post"
  fi
  printf '%s\n' "$slug"
}

blog_random_token() {
  bytes=${1:-24}
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
    return 0
  fi
  dd if=/dev/urandom bs="$bytes" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'
  printf '\n'
}

blog_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | awk '{print $NF}'
    return 0
  fi
  printf '0000000000000000000000000000000000000000000000000000000000000000\n'
}

blog_b64_to_file() {
  # blog_b64_to_file BASE64 OUTPUT_FILE
  b64=${1-}
  out=${2-}
  if [ -z "$out" ]; then
    return 1
  fi

  if command -v base64 >/dev/null 2>&1; then
    if printf '%s' "$b64" | base64 --decode > "$out" 2>/dev/null; then
      return 0
    fi
    if printf '%s' "$b64" | base64 -d > "$out" 2>/dev/null; then
      return 0
    fi
    if printf '%s' "$b64" | base64 -D > "$out" 2>/dev/null; then
      return 0
    fi
  fi

  if command -v openssl >/dev/null 2>&1; then
    printf '%s' "$b64" | openssl base64 -d -A > "$out" 2>/dev/null
    return $?
  fi

  return 1
}

blog_to_base64url() {
  printf '%s' "${1-}" | tr '+/' '-_' | tr -d '='
}

blog_from_base64url() {
  in=${1-}
  raw=$(printf '%s' "$in" | tr '-_' '+/')
  mod=$(( ${#raw} % 4 ))
  case "$mod" in
    0) ;;
    2) raw="${raw}==" ;;
    3) raw="${raw}=" ;;
    *) ;;
  esac
  printf '%s\n' "$raw"
}

blog_read_request_body() {
  BLOG_REQUEST_BODY=""
  method=${REQUEST_METHOD-GET}
  if [ "$method" != "POST" ]; then
    return 0
  fi

  cl=${CONTENT_LENGTH-0}
  case "$cl" in
    ''|*[!0-9]*) cl=0 ;;
  esac

  if [ "$cl" -gt 0 ]; then
    BLOG_REQUEST_BODY=$(dd bs=1 count="$cl" 2>/dev/null || true)
    return 0
  fi

  BLOG_REQUEST_BODY=$(cat 2>/dev/null || true)
}

blog_param() {
  key=${1-}
  val=$(get-query-param "$key" "${QUERY_STRING-}" 2>/dev/null || printf '')
  if [ -n "${BLOG_REQUEST_BODY-}" ]; then
    body_val=$(get-query-param "$key" "$BLOG_REQUEST_BODY" 2>/dev/null || printf '')
    if [ -n "$body_val" ]; then
      val=$body_val
    fi
  fi
  printf '%s\n' "$val"
}

blog_send_json_headers() {
  http-status 200 "OK"
  http-header "Content-Type" "application/json"
  http-end-headers
}

blog_send_html_headers() {
  http-ok-html
}

blog_json_error() {
  msg=${1-Unknown error}
  code=${2-false}
  esc=$(blog_json_escape "$msg")
  printf '{"success":false,"error":"%s","code":"%s"}\n' "$esc" "$code"
}

blog_validate_username() {
  name=${1-}
  case "$name" in
    ''|*[!a-zA-Z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

blog_validate_player_name() {
  name=$(printf '%s' "${1-}" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
  [ -n "$name" ] || return 1
  len=$(printf '%s' "$name" | wc -c | tr -d ' ')
  [ "$len" -le 40 ] || return 1
  printf '%s\n' "$name" | grep -Eq '^[A-Za-z0-9._ -]+$'
}

blog_user_dir() {
  printf '%s/%s\n' "$blog_users_dir" "$1"
}

blog_user_profile() {
  printf '%s/profile.conf\n' "$(blog_user_dir "$1")"
}

blog_get_player_name() {
  username=${1-}
  if [ -z "$username" ]; then
    return 1
  fi
  profile=$(blog_user_profile "$username")
  player_name=""
  if [ -f "$profile" ]; then
    player_name=$(config-get "$profile" player_name 2>/dev/null || printf '')
  fi
  if [ -z "$player_name" ]; then
    player_name=$username
  fi
  printf '%s\n' "$player_name"
}

blog_set_player_name() {
  username=${1-}
  player_name=${2-}
  if [ -z "$username" ] || [ -z "$player_name" ]; then
    return 1
  fi
  dir=$(blog_user_dir "$username")
  profile=$(blog_user_profile "$username")
  mkdir -p "$dir/delegates"
  config-set "$profile" username "$username"
  config-set "$profile" player_name "$player_name"
  config-set "$profile" updated_at "$(blog_now_iso)"
}

blog_find_username_by_fingerprint() {
  fingerprint=${1-}
  if [ -z "$fingerprint" ] || [ ! -d "$blog_users_dir" ]; then
    return 1
  fi

  find "$blog_users_dir" -mindepth 2 -maxdepth 2 -type f -name profile.conf 2>/dev/null | while IFS= read -r profile; do
    [ -n "$profile" ] || continue
    saved_fp=$(config-get "$profile" fingerprint 2>/dev/null || printf '')
    if [ "$saved_fp" = "$fingerprint" ]; then
      saved_user=$(config-get "$profile" username 2>/dev/null || printf '')
      if [ -n "$saved_user" ]; then
        printf '%s\n' "$saved_user"
        exit 0
      fi
    fi
  done
}

blog_user_is_admin_direct() {
  username=${1-}
  if [ -z "$username" ]; then
    return 1
  fi

  profile=$(blog_user_profile "$username")
  if [ -f "$profile" ]; then
    is_admin=$(config-get "$profile" is_admin 2>/dev/null || printf '')
    if [ "$is_admin" = "true" ]; then
      return 0
    fi
  fi

  if id "$username" >/dev/null 2>&1; then
    if id -nG "$username" 2>/dev/null | grep -Eq '(^|[[:space:]])blog-admin($|[[:space:]])'; then
      return 0
    fi
  fi

  return 1
}

blog_user_is_admin() {
  username=${1-}
  if [ -z "$username" ]; then
    return 1
  fi

  if blog_user_is_admin_direct "$username"; then
    return 0
  fi

  profile=$(blog_user_profile "$username")
  if [ -f "$profile" ]; then
    fingerprint=$(config-get "$profile" fingerprint 2>/dev/null || printf '')
    if [ -n "$fingerprint" ] && [ -d "$blog_users_dir" ]; then
      for alt_profile in "$blog_users_dir"/*/profile.conf; do
        [ -f "$alt_profile" ] || continue
        alt_user=$(config-get "$alt_profile" username 2>/dev/null || printf '')
        [ -n "$alt_user" ] || continue
        if [ "$alt_user" = "$username" ]; then
          continue
        fi
        alt_fingerprint=$(config-get "$alt_profile" fingerprint 2>/dev/null || printf '')
        if [ "$alt_fingerprint" = "$fingerprint" ] && blog_user_is_admin_direct "$alt_user"; then
          return 0
        fi
      done
    fi
  fi

  return 1
}

blog_save_user_profile() {
  username=$1
  fingerprint=$2
  ssh_public_key=$3

  dir=$(blog_user_dir "$username")
  profile="$dir/profile.conf"
  mkdir -p "$dir/delegates"
  config-set "$profile" username "$username"
  config-set "$profile" fingerprint "$fingerprint"
  config-set "$profile" ssh_public_key "$ssh_public_key"
  config-set "$profile" updated_at "$(blog_now_iso)"

  if blog_user_is_admin "$username"; then
    config-set "$profile" is_admin true
  else
    config-set "$profile" is_admin false
  fi
}

blog_session_path() {
  printf '%s/%s.conf\n' "$blog_sessions_dir" "$1"
}

blog_create_session() {
  username=$1
  fingerprint=$2

  token=$(blog_random_token 24)
  csrf=$(blog_random_token 16)
  now=$(blog_now_epoch)
  expires=$((now + 43200))
  is_admin=false
  if blog_user_is_admin "$username"; then
    is_admin=true
  fi

  path=$(blog_session_path "$token")
  config-set "$path" username "$username"
  config-set "$path" fingerprint "$fingerprint"
  config-set "$path" csrf_token "$csrf"
  config-set "$path" created_at "$now"
  config-set "$path" expires_at "$expires"
  config-set "$path" is_admin "$is_admin"

  printf '%s;%s;%s\n' "$token" "$csrf" "$is_admin"
}

blog_load_session() {
  load_token=${1-}
  if [ -z "$load_token" ]; then
    return 1
  fi

  load_path=$(blog_session_path "$load_token")
  if [ ! -f "$load_path" ]; then
    return 1
  fi

  load_username=$(config-get "$load_path" username 2>/dev/null || printf '')
  load_fingerprint=$(config-get "$load_path" fingerprint 2>/dev/null || printf '')
  load_csrf=$(config-get "$load_path" csrf_token 2>/dev/null || printf '')
  load_expires=$(config-get "$load_path" expires_at 2>/dev/null || printf '0')
  load_is_admin=$(config-get "$load_path" is_admin 2>/dev/null || printf 'false')

  if [ -z "$load_username" ] || [ -z "$load_csrf" ]; then
    return 1
  fi

  load_now=$(blog_now_epoch)
  case "$load_expires" in
    ''|*[!0-9]*) load_expires=0 ;;
  esac
  if [ "$load_expires" -le "$load_now" ]; then
    rm -f "$load_path"
    return 1
  fi

  BLOG_SESSION_TOKEN=$load_token
  BLOG_SESSION_USERNAME=$load_username
  BLOG_SESSION_FINGERPRINT=$load_fingerprint
  BLOG_SESSION_CSRF=$load_csrf
  BLOG_SESSION_IS_ADMIN=$load_is_admin
  return 0
}

blog_extend_session() {
  if [ -z "${BLOG_SESSION_TOKEN-}" ]; then
    return 0
  fi
  path=$(blog_session_path "$BLOG_SESSION_TOKEN")
  now=$(blog_now_epoch)
  expires=$((now + 43200))
  config-set "$path" expires_at "$expires"
}

blog_require_session() {
  require_admin=${1:-false}

  req_token=$(blog_param "session_token")
  req_csrf=$(blog_param "csrf_token")

  if ! blog_load_session "$req_token"; then
    blog_json_error "Not authenticated" "auth_required"
    return 1
  fi

  if [ -z "$req_csrf" ] || [ "$req_csrf" != "$BLOG_SESSION_CSRF" ]; then
    blog_json_error "Invalid CSRF token" "csrf_invalid"
    return 1
  fi

  # Re-check admin dynamically in case group membership changed.
  if blog_user_is_admin "$BLOG_SESSION_USERNAME"; then
    BLOG_SESSION_IS_ADMIN=true
  fi

  if [ "$require_admin" = "true" ] && [ "$BLOG_SESSION_IS_ADMIN" != "true" ]; then
    blog_json_error "Admin permission required" "admin_required"
    return 1
  fi

  blog_extend_session
  return 0
}

blog_read_front_matter_value() {
  file=$1
  key=$2
  awk -v key="$key" '
    BEGIN { in_fm = 0; }
    /^---$/ {
      if (in_fm == 0) { in_fm = 1; next; }
      exit;
    }
    in_fm == 1 {
      if (index($0, key ":") == 1) {
        sub(/^[^:]*:[[:space:]]*/, "", $0);
        gsub(/^"|"$/, "", $0);
        print $0;
        exit;
      }
    }
  ' "$file"
}

blog_read_markdown_body() {
  file=$1
  awk '
    BEGIN { d = 0; }
    /^---$/ { d++; next; }
    d >= 2 { print; }
    d == 0 { print; }
  ' "$file"
}

blog_normalize_tags() {
  tags=${1-}
  printf '%s' "$tags" | tr '\n' ',' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk 'NF { if (!seen[$0]++) { if (out != "") out = out ", "; out = out $0; } } END { printf "%s", out }'
}

blog_tags_to_json_array() {
  tags=$(blog_normalize_tags "${1-}")
  if [ -z "$tags" ]; then
    printf '[]'
    return 0
  fi

  printf '['
  first=1
  printf '%s\n' "$tags" | tr ',' '\n' | while IFS= read -r tag || [ -n "$tag" ]; do
    clean=$(printf '%s' "$tag" | sed 's/^ *//;s/ *$//')
    [ -n "$clean" ] || continue
    esc=$(blog_json_escape "$clean")
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '"%s"' "$esc"
  done
  printf ']'
}

blog_tags_to_yaml_array() {
  tags=$(blog_normalize_tags "${1-}")
  if [ -z "$tags" ]; then
    printf '[]'
    return 0
  fi

  out='['
  first=1
  printf '%s\n' "$tags" | tr ',' '\n' | while IFS= read -r tag || [ -n "$tag" ]; do
    clean=$(printf '%s' "$tag" | sed 's/^ *//;s/ *$//')
    [ -n "$clean" ] || continue
    esc=$(blog_yaml_escape "$clean")
    if [ "$first" -eq 0 ]; then
      printf ', '
    fi
    first=0
    printf '"%s"' "$esc"
  done | {
    body=$(cat)
    printf '%s%s]\n' "$out" "$body"
  }
}

blog_new_draft_id() {
  blog_random_token 12
}

blog_draft_dir() {
  printf '%s/%s\n' "$blog_drafts_dir" "$1"
}

blog_draft_meta_path() {
  printf '%s/meta.conf\n' "$(blog_draft_dir "$1")"
}

blog_draft_content_path() {
  printf '%s/content.md\n' "$(blog_draft_dir "$1")"
}

blog_draft_exists() {
  [ -f "$(blog_draft_meta_path "$1")" ]
}

blog_save_draft() {
  draft_id=$1
  title=$2
  tags=$3
  summary=$4
  content=$5
  author=$6
  publish_mode=$7
  scheduled_at=$8
  status=$9

  dir=$(blog_draft_dir "$draft_id")
  meta=$(blog_draft_meta_path "$draft_id")
  body=$(blog_draft_content_path "$draft_id")
  mkdir -p "$dir"

  created=$(config-get "$meta" created_at 2>/dev/null || printf '')
  if [ -z "$created" ]; then
    created=$(blog_now_iso)
  fi

  normalized_tags=$(blog_normalize_tags "$tags")
  slug=$(blog_slugify "$title")
  now_iso=$(blog_now_iso)

  config-set "$meta" draft_id "$draft_id"
  config-set "$meta" title "$title"
  config-set "$meta" slug "$slug"
  config-set "$meta" tags "$normalized_tags"
  config-set "$meta" summary "$summary"
  config-set "$meta" author "$author"
  config-set "$meta" publish_mode "$publish_mode"
  config-set "$meta" scheduled_at "$scheduled_at"
  config-set "$meta" status "$status"
  config-set "$meta" created_at "$created"
  config-set "$meta" updated_at "$now_iso"

  printf '%s' "$content" > "$body"
}

blog_delete_draft() {
  draft_id=$1
  dir=$(blog_draft_dir "$draft_id")
  rm -rf "$dir"
}

blog_find_draft_meta() {
  find "$blog_drafts_dir" -mindepth 2 -maxdepth 2 -type f -name meta.conf 2>/dev/null
}

blog_compute_post_filename() {
  title=$1
  date_prefix=$(date -u +%Y-%m-%d)
  slug=$(blog_slugify "$title")
  base="${date_prefix}-${slug}"
  file="$blog_posts_dir/${base}.md"

  if [ ! -f "$file" ]; then
    printf '%s\n' "${base}.md"
    return 0
  fi

  n=2
  while :; do
    candidate="${base}-${n}.md"
    if [ ! -f "$blog_posts_dir/$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    n=$((n + 1))
  done
}

blog_publish_content() {
  # args: title tags summary content author draft_id publish_mode scheduled_at
  title=$1
  tags=$2
  summary=$3
  content=$4
  author=$5
  draft_id=$6
  publish_mode=$7
  scheduled_at=$8

  filename=$(blog_compute_post_filename "$title")
  post_path="$blog_posts_dir/$filename"
  now_iso=$(blog_now_iso)
  normalized_tags=$(blog_normalize_tags "$tags")
  tags_yaml=$(blog_tags_to_yaml_array "$normalized_tags")
  content_hash=$(printf '%s' "$content" | blog_sha256)

  {
    printf '%s\n' '---'
    printf 'title: "%s"\n' "$(blog_yaml_escape "$title")"
    printf 'published_at: "%s"\n' "$now_iso"
    printf 'content_hash: "%s"\n' "$content_hash"
    printf 'tags: %s\n' "$tags_yaml"
    printf 'author: "%s"\n' "$(blog_yaml_escape "$author")"
    if [ -n "$summary" ]; then
      printf 'summary: "%s"\n' "$(blog_yaml_escape "$summary")"
    fi
    printf 'visibility: "public"\n'
    printf 'license: "CC BY 4.0"\n'
    printf 'draft_id: "%s"\n' "$draft_id"
    printf 'publish_mode: "%s"\n' "$publish_mode"
    if [ -n "$scheduled_at" ]; then
      printf 'scheduled_at: "%s"\n' "$scheduled_at"
    fi
    printf '%s\n\n' '---'
    printf '%s\n' "$content"
  } > "$post_path"

  printf '%s\n' "$filename"
}

blog_run_build_async() {
  if [ -z "${WIZARDRY_DIR-}" ]; then
    return 0
  fi
  if [ ! -x "$WIZARDRY_DIR/spells/web/build" ]; then
    return 0
  fi

  (
    WEB_WIZARDRY_ROOT="$blog_sites_dir" WIZARDRY_DIR="$WIZARDRY_DIR" "$WIZARDRY_DIR/spells/web/build" "$blog_site_name" >/dev/null 2>&1 || true
  ) &
}

blog_scheduler_state() {
  printf '%s/scheduler.conf\n' "$blog_state_dir"
}

blog_scheduler_lock_dir() {
  printf '%s/scheduler.lock\n' "$blog_state_dir"
}

blog_random_int() {
  max=${1:-0}
  case "$max" in
    ''|*[!0-9]*) max=0 ;;
  esac
  if [ "$max" -le 0 ]; then
    printf '0\n'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    val=$(openssl rand -hex 2 | awk '{print strtonum("0x" $0)}')
  else
    val=$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')
  fi
  printf '%s\n' $(( val % (max + 1) ))
}

blog_format_decimal() {
  value=${1-0}
  trimmed=$(printf '%s' "$value" | sed 's/0*$//;s/\.$//')
  if [ -z "$trimmed" ]; then
    trimmed=0
  fi
  printf '%s\n' "$trimmed"
}

blog_is_positive_decimal() {
  value=${1-}
  awk -v value="$value" 'BEGIN { if (value ~ /^[0-9]+([.][0-9]+)?$/ && value + 0 > 0) exit 0; exit 1 }'
}

blog_drip_interval_hours() {
  interval_hours=$(config-get "$blog_site_conf" drip_interval_hours 2>/dev/null || printf '')
  if ! blog_is_positive_decimal "$interval_hours"; then
    legacy_minutes=$(config-get "$blog_site_conf" drip_interval_minutes 2>/dev/null || printf '240')
    case "$legacy_minutes" in ''|*[!0-9]*) legacy_minutes=240 ;; esac
    if [ "$legacy_minutes" -lt 1 ]; then
      legacy_minutes=1
    fi
    interval_hours=$(awk -v m="$legacy_minutes" 'BEGIN { printf "%.4f", m / 60 }')
  fi
  normalized=$(awk -v h="$interval_hours" 'BEGIN { min_h = 1.0 / 60.0; x = h + 0; if (x < min_h) x = min_h; printf "%.4f", x }')
  blog_format_decimal "$normalized"
}

blog_drip_interval_minutes() {
  interval_hours=$(blog_drip_interval_hours)
  awk -v h="$interval_hours" 'BEGIN { m = int(h * 60 + 0.5); if (m < 1) m = 1; print m }'
}

blog_drip_interval_seconds() {
  interval_minutes=$(blog_drip_interval_minutes)
  printf '%s\n' $((interval_minutes * 60))
}

blog_drip_randomness_minutes() {
  randomness=$(config-get "$blog_site_conf" drip_randomness_minutes 2>/dev/null || printf '')
  if [ -z "$randomness" ]; then
    randomness=$(config-get "$blog_site_conf" drip_jitter_minutes 2>/dev/null || printf '0')
  fi
  case "$randomness" in ''|*[!0-9]*) randomness=0 ;; esac
  if [ "$randomness" -lt 0 ]; then
    randomness=0
  fi
  printf '%s\n' "$randomness"
}

blog_drip_jitter_minutes() {
  blog_drip_randomness_minutes
}

blog_run_scheduler() {
  lock_dir=$(blog_scheduler_lock_dir)
  if ! mkdir "$lock_dir" 2>/dev/null; then
    printf 'locked\n'
    return 0
  fi
  trap 'rm -rf "$lock_dir"' EXIT HUP INT TERM

  now_epoch=$(blog_now_epoch)
  now_iso=$(blog_now_iso)
  state=$(blog_scheduler_state)

  interval_seconds=$(blog_drip_interval_seconds)
  randomness=$(blog_drip_randomness_minutes)

  last_drip=$(config-get "$state" last_drip_epoch 2>/dev/null || printf '0')
  case "$last_drip" in ''|*[!0-9]*) last_drip=0 ;; esac

  scheduled_published=0
  drip_published=0

  # Publish all due scheduled drafts.
  due_file=$(mktemp "${TMPDIR:-/tmp}/blog-due.XXXXXX")
  trap 'rm -f "$due_file"; rm -rf "$lock_dir"' EXIT HUP INT TERM

  blog_find_draft_meta | while IFS= read -r meta; do
    mode=$(config-get "$meta" publish_mode 2>/dev/null || printf 'draft')
    status=$(config-get "$meta" status 2>/dev/null || printf 'draft')
    draft_id=$(config-get "$meta" draft_id 2>/dev/null || printf '')
    if [ "$mode" = "scheduled" ] && [ "$status" = "scheduled" ] && [ -n "$draft_id" ]; then
      at=$(config-get "$meta" scheduled_at 2>/dev/null || printf '')
      at_epoch=$(blog_iso_to_epoch "$at")
      if [ "$at_epoch" -gt 0 ] && [ "$at_epoch" -le "$now_epoch" ]; then
        printf 'scheduled|%s|%s\n' "$at_epoch" "$draft_id"
      fi
    fi
  done | sort -t'|' -k2,2n > "$due_file"

  if [ -s "$due_file" ]; then
    while IFS='|' read -r _ at_epoch draft_id; do
      meta=$(blog_draft_meta_path "$draft_id")
      body=$(blog_draft_content_path "$draft_id")
      [ -f "$meta" ] || continue
      [ -f "$body" ] || continue

      title=$(config-get "$meta" title 2>/dev/null || printf 'Untitled')
      tags=$(config-get "$meta" tags 2>/dev/null || printf '')
      summary=$(config-get "$meta" summary 2>/dev/null || printf '')
      author=$(config-get "$meta" author 2>/dev/null || printf 'author')
      content=$(cat "$body" 2>/dev/null || printf '')
      published_file=$(blog_publish_content "$title" "$tags" "$summary" "$content" "$author" "$draft_id" scheduled "$now_iso")
      if [ -n "$published_file" ]; then
        blog_delete_draft "$draft_id"
        scheduled_published=$((scheduled_published + 1))
      fi
    done < "$due_file"
  fi

  next_drip=$((last_drip + interval_seconds))
  if [ "$last_drip" -eq 0 ]; then
    next_drip=0
  fi

  if [ "$now_epoch" -ge "$next_drip" ]; then
    drip_file=$(mktemp "${TMPDIR:-/tmp}/blog-drip.XXXXXX")
    blog_find_draft_meta | while IFS= read -r meta; do
      mode=$(config-get "$meta" publish_mode 2>/dev/null || printf 'draft')
      status=$(config-get "$meta" status 2>/dev/null || printf 'draft')
      draft_id=$(config-get "$meta" draft_id 2>/dev/null || printf '')
      if [ "$mode" = "drip" ] && [ "$status" = "queued" ] && [ -n "$draft_id" ]; then
        created=$(config-get "$meta" created_at 2>/dev/null || printf '')
        created_epoch=$(blog_iso_to_epoch "$created")
        printf '%s|%s\n' "$created_epoch" "$draft_id"
      fi
    done | sort -t'|' -k1,1n > "$drip_file"

    if [ -s "$drip_file" ]; then
      first=$(head -n 1 "$drip_file")
      draft_id=${first#*|}
      meta=$(blog_draft_meta_path "$draft_id")
      body=$(blog_draft_content_path "$draft_id")
      if [ -f "$meta" ] && [ -f "$body" ]; then
        title=$(config-get "$meta" title 2>/dev/null || printf 'Untitled')
        tags=$(config-get "$meta" tags 2>/dev/null || printf '')
        summary=$(config-get "$meta" summary 2>/dev/null || printf '')
        author=$(config-get "$meta" author 2>/dev/null || printf 'author')
        content=$(cat "$body" 2>/dev/null || printf '')
        published_file=$(blog_publish_content "$title" "$tags" "$summary" "$content" "$author" "$draft_id" drip "")
        if [ -n "$published_file" ]; then
          blog_delete_draft "$draft_id"
          drip_published=1
          randomness_minutes=$(blog_random_int "$randomness")
          config-set "$state" last_drip_epoch "$((now_epoch + randomness_minutes * 60))"
        fi
      fi
    fi

    rm -f "$drip_file"
  fi

  rm -f "$due_file"
  if [ "$scheduled_published" -gt 0 ] || [ "$drip_published" -gt 0 ]; then
    blog_run_build_async
  fi

  trap - EXIT HUP INT TERM
  rm -rf "$lock_dir"
  printf '%s|%s\n' "$scheduled_published" "$drip_published"
}

blog_collect_public_posts() {
  # Writes sorted markdown file paths to output file argument.
  out_file=$1
  temp=$(mktemp "${TMPDIR:-/tmp}/blog-posts.XXXXXX")
  find "$blog_posts_dir" -type f -name '*.md' 2>/dev/null | while IFS= read -r file; do
    visibility=$(blog_read_front_matter_value "$file" visibility 2>/dev/null || printf '')
    if [ -z "$visibility" ]; then
      visibility="public"
    fi
    if [ "$visibility" != "public" ]; then
      continue
    fi

    published_at=$(blog_read_front_matter_value "$file" published_at 2>/dev/null || printf '')
    if [ -z "$published_at" ]; then
      published_at="1970-01-01T00:00:00Z"
    fi

    printf '%s|%s\n' "$published_at" "$file"
  done | sort -r > "$temp"

  awk -F'|' '{print $2}' "$temp" > "$out_file"
  rm -f "$temp"
}

blog_base_url() {
  domain=$(config-get "$blog_site_conf" domain 2>/dev/null || printf 'localhost')
  use_https=$(config-get "$blog_site_conf" https 2>/dev/null || printf 'false')
  scheme=http
  if [ "$use_https" = "true" ]; then
    scheme=https
  fi
  printf '%s://%s\n' "$scheme" "$domain"
}

blog_rel_post_html_url() {
  file=$1
  rel=${file#"$blog_posts_dir/"}
  rel_html=${rel%.md}.html
  rel_enc=$(blog_url_encode "$rel_html")
  printf '/cgi/blog-open-post?path=%s\n' "$rel_enc"
}
