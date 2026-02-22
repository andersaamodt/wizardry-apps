#!/bin/sh
# Behavioral tests for blog template CGI/admin workflows.

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

SITE_NAME="blogspec"
CGI_BODY=''

setup_blog_fixture() {
  skip-if-compiled || return $?

  test_web_root=$(temp-dir web-blog-test)
  WEB_WIZARDRY_ROOT="$test_web_root" WIZARDRY_DIR="$ROOT_DIR" run_spell spells/web/create-from-template "$SITE_NAME" blog
  if [ "$STATUS" -ne 0 ]; then
    TEST_FAILURE_REASON="failed to create blog template fixture"
    rm -rf "$test_web_root"
    return 1
  fi

  site_dir="$test_web_root/$SITE_NAME"
  cgi_dir="$site_dir/cgi"
  data_dir="$test_web_root/.sitedata/$SITE_NAME"

  mkdir -p "$data_dir/ssh-auth/users/testadmin/delegates"
  mkdir -p "$data_dir/ssh-auth/sessions"

  profile="$data_dir/ssh-auth/users/testadmin/profile.conf"
  config-set "$profile" username testadmin
  config-set "$profile" fingerprint test-fingerprint
  config-set "$profile" is_admin true

  session_token="test-session-token"
  csrf_token="test-csrf-token"
  session_file="$data_dir/ssh-auth/sessions/$session_token.conf"
  now_epoch=$(date +%s)
  config-set "$session_file" username testadmin
  config-set "$session_file" fingerprint test-fingerprint
  config-set "$session_file" csrf_token "$csrf_token"
  config-set "$session_file" created_at "$now_epoch"
  config-set "$session_file" expires_at "$((now_epoch + 3600))"
  config-set "$session_file" is_admin true

  return 0
}

teardown_blog_fixture() {
  if [ -n "${test_web_root-}" ] && [ -d "$test_web_root" ]; then
    rm -rf "$test_web_root"
  fi
}

run_cgi_post() {
  script=$1
  body=$2

  out_file=$(temp_file cgi-out)
  err_file=$(temp_file cgi-err)
  had_errexit=0
  case $- in
    *e*) had_errexit=1 ;;
  esac

  cl=$(printf '%s' "$body" | wc -c | tr -d ' ')

  set +e
  printf '%s' "$body" | \
    REQUEST_METHOD=POST \
    CONTENT_LENGTH="$cl" \
    QUERY_STRING='' \
    WIZARDRY_DIR="$ROOT_DIR" \
    WIZARDRY_SITES_DIR="$test_web_root" \
    WIZARDRY_SITE_NAME="$SITE_NAME" \
    "$script" >"$out_file" 2>"$err_file"
  STATUS=$?
  if [ "$had_errexit" -eq 1 ]; then
    set -e
  else
    set +e
  fi

  OUTPUT=$(cat "$out_file")
  ERROR=$(cat "$err_file")
  CGI_BODY=$(printf '%s\n' "$OUTPUT" | awk 'seen {print} /^[[:space:]]*$/ {seen=1}')

  rm -f "$out_file" "$err_file"
}

run_cgi_get() {
  script=$1
  query=${2-}

  out_file=$(temp_file cgi-out)
  err_file=$(temp_file cgi-err)
  had_errexit=0
  case $- in
    *e*) had_errexit=1 ;;
  esac

  set +e
  REQUEST_METHOD=GET \
    QUERY_STRING="$query" \
    WIZARDRY_DIR="$ROOT_DIR" \
    WIZARDRY_SITES_DIR="$test_web_root" \
    WIZARDRY_SITE_NAME="$SITE_NAME" \
    "$script" >"$out_file" 2>"$err_file"
  STATUS=$?
  if [ "$had_errexit" -eq 1 ]; then
    set -e
  else
    set +e
  fi

  OUTPUT=$(cat "$out_file")
  ERROR=$(cat "$err_file")
  CGI_BODY=$(printf '%s\n' "$OUTPUT" | awk 'seen {print} /^[[:space:]]*$/ {seen=1}')

  rm -f "$out_file" "$err_file"
}

json_field() {
  key=$1
  printf '%s' "$CGI_BODY" | sed -n "s/.*\"$key\":\"\([^\"]*\)\".*/\1/p"
}

auth_body_prefix() {
  printf 'session_token=%s&csrf_token=%s' "$session_token" "$csrf_token"
}

test_blog_draft_scheduler_flow() {
  setup_blog_fixture || return $?

  save_body="$(auth_body_prefix)&action=save_draft&title=Scheduler+Draft&tags=ci%2Ctests&summary=scheduled+summary&content=Hello+scheduled+draft"
  run_cgi_post "$cgi_dir/blog-save-post" "$save_body"
  if [ "$STATUS" -ne 0 ]; then
    TEST_FAILURE_REASON="blog-save-post failed"
    teardown_blog_fixture
    return 1
  fi
  case "$CGI_BODY" in
    *'"success":true'*) ;;
    *)
      TEST_FAILURE_REASON="save draft did not return success"
      teardown_blog_fixture
      return 1
      ;;
  esac

  draft_id=$(json_field draft_id)
  if [ -z "$draft_id" ]; then
    TEST_FAILURE_REASON="save draft should return draft_id"
    teardown_blog_fixture
    return 1
  fi

  queue_body="$(auth_body_prefix)&action=queue_scheduled&draft_id=$draft_id&scheduled_at=2000-01-01T00%3A00%3A00Z"
  run_cgi_post "$cgi_dir/blog-save-post" "$queue_body"
  case "$CGI_BODY" in
    *'"success":true'*) ;;
    *)
      TEST_FAILURE_REASON="queue_scheduled should succeed"
      teardown_blog_fixture
      return 1
      ;;
  esac

  run_cgi_post "$cgi_dir/blog-run-scheduler" "$(auth_body_prefix)"
  case "$CGI_BODY" in
    *'"scheduled_published":1'*) ;;
    *)
      TEST_FAILURE_REASON="scheduler should publish one due scheduled draft"
      teardown_blog_fixture
      return 1
      ;;
  esac

  if ! grep -R "Scheduler Draft" "$site_dir/site/pages/posts" >/dev/null 2>&1; then
    TEST_FAILURE_REASON="scheduler did not write published markdown post"
    teardown_blog_fixture
    return 1
  fi

  run_cgi_post "$cgi_dir/blog-list-drafts" "$(auth_body_prefix)"
  case "$CGI_BODY" in
    *"$draft_id"*)
      TEST_FAILURE_REASON="published scheduled draft should be removed from drafts"
      teardown_blog_fixture
      return 1
      ;;
    *) ;;
  esac

  teardown_blog_fixture
}

test_blog_drip_interval_enforced() {
  setup_blog_fixture || return $?

  config-set "$site_dir/site.conf" drip_interval_hours 0.5
  config-set "$site_dir/site.conf" drip_randomness_minutes 0

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=queue_drip&title=Drip+A&content=First"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="queue_drip A failed"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=queue_drip&title=Drip+B&content=Second"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="queue_drip B failed"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-run-scheduler" "$(auth_body_prefix)"
  case "$CGI_BODY" in *'"drip_published":1'*) ;; *) TEST_FAILURE_REASON="first drip run should publish one"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-run-scheduler" "$(auth_body_prefix)"
  case "$CGI_BODY" in *'"drip_published":0'*) ;; *) TEST_FAILURE_REASON="second drip run should respect interval"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

test_blog_media_upload_and_auth_csrf() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/blog-save-post" "session_token=$session_token&csrf_token=wrong&action=save_draft&title=x"
  case "$CGI_BODY" in
    *'csrf_invalid'*) ;;
    *)
      TEST_FAILURE_REASON="invalid csrf should be rejected"
      teardown_blog_fixture
      return 1
      ;;
  esac

  run_cgi_post "$cgi_dir/blog-upload-media" "$(auth_body_prefix)&filename=test.png&mime_type=image%2Fpng&data_base64=aGVsbG8="
  case "$CGI_BODY" in
    *'"success":true'*) ;;
    *)
      TEST_FAILURE_REASON="media upload should succeed"
      teardown_blog_fixture
      return 1
      ;;
  esac

  media_url=$(json_field url)
  if [ -z "$media_url" ]; then
    TEST_FAILURE_REASON="media upload should return URL"
    teardown_blog_fixture
    return 1
  fi

  rel_path=${media_url#/uploads/}
  if [ ! -f "$data_dir/uploads/$rel_path" ]; then
    TEST_FAILURE_REASON="uploaded media file not written to site data uploads"
    teardown_blog_fixture
    return 1
  fi

  teardown_blog_fixture
}

test_blog_public_index_hides_drafts() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=save_draft&title=Invisible+Draft&content=hidden"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="save draft failed"; teardown_blog_fixture; return 1 ;; esac
  draft_id=$(json_field draft_id)

  run_cgi_get "$cgi_dir/blog-index" ""
  case "$CGI_BODY" in
    *"Invisible Draft"*)
      TEST_FAILURE_REASON="draft should not appear in public index"
      teardown_blog_fixture
      return 1
      ;;
    *) ;;
  esac

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=publish_now&draft_id=$draft_id"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="publish_now failed"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_get "$cgi_dir/blog-index" ""
  case "$CGI_BODY" in
    *"Invisible Draft"*) ;;
    *)
      TEST_FAILURE_REASON="published post should appear in public index"
      teardown_blog_fixture
      return 1
      ;;
  esac

  teardown_blog_fixture
}

test_blog_config_and_queue_metadata() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/blog-update-config" "$(auth_body_prefix)&site_title=Spec+Blog&drip_interval_hours=0.25&drip_randomness_minutes=2&feed_full_text=false&feed_items=7"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="blog-update-config should succeed"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_get "$cgi_dir/blog-get-config" ""
  case "$CGI_BODY" in *'"site_title":"Spec Blog"'*) ;; *) TEST_FAILURE_REASON="site_title should update in config"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"drip_interval_hours":0.25'*) ;; *) TEST_FAILURE_REASON="drip interval hours should be 0.25"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"drip_interval_minutes":15'*) ;; *) TEST_FAILURE_REASON="drip interval should be 15"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"drip_randomness_minutes":2'*) ;; *) TEST_FAILURE_REASON="drip randomness should be 2"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"feed_full_text":false'*) ;; *) TEST_FAILURE_REASON="feed_full_text should be false"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"feed_items":7'*) ;; *) TEST_FAILURE_REASON="feed_items should be 7"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=queue_scheduled&title=Queue+Meta&content=queued&scheduled_at=2999-01-01T00%3A00%3A00Z"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="queue_scheduled should succeed"; teardown_blog_fixture; return 1 ;; esac
  queued_id=$(json_field draft_id)

  run_cgi_post "$cgi_dir/blog-list-queue" "$(auth_body_prefix)"
  case "$CGI_BODY" in *'"drip_interval_hours":0.25'*) ;; *) TEST_FAILURE_REASON="queue response should include updated drip interval hours"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"drip_interval_minutes":15'*) ;; *) TEST_FAILURE_REASON="queue response should include updated drip interval"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"drip_randomness_minutes":2'*) ;; *) TEST_FAILURE_REASON="queue response should include updated drip randomness"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *"$queued_id"*) ;; *) TEST_FAILURE_REASON="queued draft should appear in queue listing"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

test_blog_autosave_and_validation_behavior() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=queue_scheduled&title=Missing+Date&content=x"
  case "$CGI_BODY" in
    *'scheduled_at_required'*) ;;
    *)
      TEST_FAILURE_REASON="queue_scheduled should reject missing scheduled_at"
      teardown_blog_fixture
      return 1
      ;;
  esac

  run_cgi_post "$cgi_dir/blog-save-post" "$(auth_body_prefix)&action=autosave&title=Auto+Draft&content=autosaved+content"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="autosave should succeed"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"autosaved":true'*) ;; *) TEST_FAILURE_REASON="autosave response should include autosaved=true"; teardown_blog_fixture; return 1 ;; esac
  auto_id=$(json_field draft_id)
  if [ -z "$auto_id" ]; then
    TEST_FAILURE_REASON="autosave should return a draft_id"
    teardown_blog_fixture
    return 1
  fi

  run_cgi_post "$cgi_dir/blog-get-draft" "$(auth_body_prefix)&draft_id=$auto_id"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="blog-get-draft should succeed"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *"autosaved content"*) ;; *) TEST_FAILURE_REASON="draft content should round-trip through autosave"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-delete-draft" "$(auth_body_prefix)&draft_id=$auto_id"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="blog-delete-draft should succeed"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-list-drafts" "$(auth_body_prefix)"
  case "$CGI_BODY" in
    *"$auto_id"*)
      TEST_FAILURE_REASON="deleted draft should not remain in list"
      teardown_blog_fixture
      return 1
      ;;
    *) ;;
  esac

  teardown_blog_fixture
}

test_blog_auth_delegate_and_session_behavior() {
  setup_blog_fixture || return $?

  delegates_dir="$data_dir/ssh-auth/users/testadmin/delegates"
  delegate_file="$delegates_dir/demo.conf"
  config-set "$delegate_file" delegate_id demo
  config-set "$delegate_file" credential_id demo-cred
  config-set "$delegate_file" public_key_b64 ZGVtbw==
  config-set "$delegate_file" created_at "2026-01-01T00:00:00Z"
  config-set "$delegate_file" sign_count 0
  config-set "$delegate_file" last_used_at ""

  run_cgi_get "$cgi_dir/ssh-auth-check-session" "session_token=$session_token"
  case "$CGI_BODY" in *'"authenticated":true'*) ;; *) TEST_FAILURE_REASON="session should be valid initially"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"is_admin":true'*) ;; *) TEST_FAILURE_REASON="session should be admin in fixture"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/ssh-auth-list-delegates" "$(auth_body_prefix)&username=testadmin"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="ssh-auth-list-delegates should succeed"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"delegate_id":"demo"'*) ;; *) TEST_FAILURE_REASON="delegate listing should include demo delegate"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/ssh-auth-revoke-delegate" "$(auth_body_prefix)&username=testadmin&delegate_id=demo"
  case "$CGI_BODY" in *'"revoked":true'*) ;; *) TEST_FAILURE_REASON="ssh-auth-revoke-delegate should revoke delegate"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/ssh-auth-list-delegates" "$(auth_body_prefix)&username=testadmin"
  case "$CGI_BODY" in
    *'"delegate_id":"demo"'*)
      TEST_FAILURE_REASON="revoked delegate should no longer appear"
      teardown_blog_fixture
      return 1
      ;;
    *) ;;
  esac

  run_cgi_post "$cgi_dir/ssh-auth-logout" "session_token=$session_token"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="ssh-auth-logout should succeed"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_get "$cgi_dir/ssh-auth-check-session" "session_token=$session_token"
  case "$CGI_BODY" in *'"authenticated":false'*) ;; *) TEST_FAILURE_REASON="session should be invalid after logout"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

test_blog_admin_resolution_by_fingerprint_alias() {
  setup_blog_fixture || return $?

  alias_user="player938786"
  real_user="Anders"
  shared_fp="shared-fingerprint-xyz"

  mkdir -p "$data_dir/ssh-auth/users/$alias_user/delegates"
  mkdir -p "$data_dir/ssh-auth/users/$real_user/delegates"

  alias_profile="$data_dir/ssh-auth/users/$alias_user/profile.conf"
  real_profile="$data_dir/ssh-auth/users/$real_user/profile.conf"

  config-set "$alias_profile" username "$alias_user"
  config-set "$alias_profile" fingerprint "$shared_fp"
  config-set "$alias_profile" is_admin false

  config-set "$real_profile" username "$real_user"
  config-set "$real_profile" fingerprint "$shared_fp"
  config-set "$real_profile" is_admin true

  alias_token="alias-session-token"
  alias_csrf="alias-csrf-token"
  alias_session="$data_dir/ssh-auth/sessions/$alias_token.conf"
  now_epoch=$(date +%s)
  config-set "$alias_session" username "$alias_user"
  config-set "$alias_session" fingerprint "$shared_fp"
  config-set "$alias_session" csrf_token "$alias_csrf"
  config-set "$alias_session" created_at "$now_epoch"
  config-set "$alias_session" expires_at "$((now_epoch + 3600))"
  config-set "$alias_session" is_admin false

  run_cgi_get "$cgi_dir/ssh-auth-check-session" "session_token=$alias_token"
  case "$CGI_BODY" in *'"authenticated":true'*) ;; *) TEST_FAILURE_REASON="alias session should authenticate"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"is_admin":true'*) ;; *) TEST_FAILURE_REASON="alias fingerprint should inherit admin status"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-list-drafts" "session_token=$alias_token&csrf_token=$alias_csrf"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="alias admin should access admin CGI endpoints"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

test_blog_passkey_login_begin_behavior() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/ssh-auth-login-begin" "username=testadmin"
  case "$CGI_BODY" in
    *'no_credentials'*) ;;
    *)
      TEST_FAILURE_REASON="login-begin should require at least one bound credential"
      teardown_blog_fixture
      return 1
      ;;
  esac

  delegates_dir="$data_dir/ssh-auth/users/testadmin/delegates"
  delegate_file="$delegates_dir/passkey.conf"
  config-set "$delegate_file" delegate_id passkey
  config-set "$delegate_file" credential_id test-credential-id
  config-set "$delegate_file" public_key_b64 ZGVtbw==
  config-set "$delegate_file" created_at "2026-01-01T00:00:00Z"
  config-set "$delegate_file" sign_count 0
  config-set "$delegate_file" last_used_at ""

  run_cgi_post "$cgi_dir/ssh-auth-login-begin" "username=testadmin"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="login-begin should succeed with delegate present"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"allow_credentials":["test-credential-id"]'*) ;; *) TEST_FAILURE_REASON="allow_credentials should include configured credential"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"request_id":"'*) ;; *) TEST_FAILURE_REASON="login-begin should return request_id"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/ssh-auth-login-begin" ""
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="login-begin should support username-less passkey flow"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"allow_credentials":["test-credential-id"]'*) ;; *) TEST_FAILURE_REASON="username-less login-begin should include configured credential"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"request_id":"'*) ;; *) TEST_FAILURE_REASON="username-less login-begin should return request_id"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

test_blog_passkey_register_normalizes_multiline_key() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/ssh-auth-register" "username=alice&ssh_public_key=ssh-ed25519%0AAAAAB3NzaC1yc2EAAAADAQABAAABAQDtestkey%0Aalice%40MUD"
  case "$CGI_BODY" in
    *'"success":true'*) ;;
    *)
      TEST_FAILURE_REASON="ssh-auth-register should return JSON success for normalized multiline key"
      teardown_blog_fixture
      return 1
      ;;
  esac

  profile="$data_dir/ssh-auth/users/alice/profile.conf"
  if [ ! -f "$profile" ]; then
    TEST_FAILURE_REASON="ssh-auth-register should create user profile"
    teardown_blog_fixture
    return 1
  fi

  normalized_key=$(config-get "$profile" ssh_public_key 2>/dev/null || printf '')
  case "$normalized_key" in
    "ssh-ed25519 AAAAB3NzaC1yc2EAAAADAQABAAABAQDtestkey alice@MUD") ;;
    *)
      TEST_FAILURE_REASON="ssh-auth-register should normalize multiline key into single-line public key"
      teardown_blog_fixture
      return 1
      ;;
  esac

  teardown_blog_fixture
}

test_blog_passkey_register_resolves_stable_username() {
  setup_blog_fixture || return $?

  run_cgi_post "$cgi_dir/ssh-auth-register" "ssh_public_key=ssh-ed25519%20AAAAB3NzaC1yc2EAAAADAQABAAABAQDstablekey%20alice%40MUD"
  case "$CGI_BODY" in
    *'"success":true'*) ;;
    *)
      TEST_FAILURE_REASON="ssh-auth-register should succeed without explicit username"
      teardown_blog_fixture
      return 1
      ;;
  esac
  case "$CGI_BODY" in
    *'"username":"alice"'*) ;;
    *)
      TEST_FAILURE_REASON="ssh-auth-register should derive username from SSH key comment"
      teardown_blog_fixture
      return 1
      ;;
  esac

  profile="$data_dir/ssh-auth/users/alice/profile.conf"
  if [ ! -f "$profile" ]; then
    TEST_FAILURE_REASON="derived username profile should be created"
    teardown_blog_fixture
    return 1
  fi

  run_cgi_post "$cgi_dir/ssh-auth-register" "username=player-999999&ssh_public_key=ssh-ed25519%20AAAAB3NzaC1yc2EAAAADAQABAAABAQDstablekey%20alice%40MUD"
  case "$CGI_BODY" in
    *'"success":true'*) ;;
    *)
      TEST_FAILURE_REASON="ssh-auth-register second call should still succeed"
      teardown_blog_fixture
      return 1
      ;;
  esac
  case "$CGI_BODY" in
    *'"username":"alice"'*) ;;
    *)
      TEST_FAILURE_REASON="ssh-auth-register should reuse existing username for same fingerprint"
      teardown_blog_fixture
      return 1
      ;;
  esac

  if [ -e "$data_dir/ssh-auth/users/player-999999/profile.conf" ]; then
    TEST_FAILURE_REASON="ssh-auth-register should not create duplicate profile for same fingerprint"
    teardown_blog_fixture
    return 1
  fi

  teardown_blog_fixture
}

test_blog_archive_endpoint_renders_posts() {
  setup_blog_fixture || return $?

  run_cgi_get "$cgi_dir/blog-archive" ""
  case "$CGI_BODY" in *"archive-month"*) ;; *) TEST_FAILURE_REASON="archive endpoint should render month sections"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *"Welcome to My Blog"*) ;; *) TEST_FAILURE_REASON="archive endpoint should include sample posts"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

test_blog_post_context_endpoint() {
  setup_blog_fixture || return $?

  run_cgi_get "$cgi_dir/blog-post-context" "path=2024-01-15-welcome.html"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="blog-post-context should succeed for valid post"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"title":"Welcome to My Blog"'*) ;; *) TEST_FAILURE_REASON="post context should include current post title"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"reading_minutes":'*) ;; *) TEST_FAILURE_REASON="post context should include reading time"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"tags":["welcome","meta"]'*) ;; *) TEST_FAILURE_REASON="post context should include normalized tags array"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_get "$cgi_dir/blog-post-context" "path=../secrets"
  case "$CGI_BODY" in
    *'invalid_path'*) ;;
    *)
      TEST_FAILURE_REASON="post context should reject path traversal"
      teardown_blog_fixture
      return 1
      ;;
  esac

  teardown_blog_fixture
}

test_blog_nostr_bridge_projection_and_comments() {
  setup_blog_fixture || return $?

  config-set "$site_dir/site.conf" nostr_bridge_enabled true

  post_pubkey="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  post_event_old="1111111111111111111111111111111111111111111111111111111111111111"
  post_event_new="2222222222222222222222222222222222222222222222222222222222222222"
  post_addr="30023:$post_pubkey:nostr-post"

  post_event_dir="$site_dir/site/nostr/events/$post_pubkey/30023"
  mkdir -p "$post_event_dir"
  cat > "$post_event_dir/$post_event_old.json" <<EOF
{"id":"$post_event_old","pubkey":"$post_pubkey","created_at":1700000000,"kind":30023,"tags":[["d","nostr-post"],["title","Old Bridge Title"],["summary","old summary"],["published_at","2024-01-01T00:00:00Z"],["t","nostr"]],"content":"# Old\\nold content","sig":"legacy"}
EOF
  cat > "$post_event_dir/$post_event_new.json" <<EOF
{"id":"$post_event_new","pubkey":"$post_pubkey","created_at":1700000500,"kind":30023,"tags":[["d","nostr-post"],["title","Fresh Bridge Title"],["summary","fresh summary"],["published_at","2024-01-02T00:00:00Z"],["t","nostr"],["t","bridge"]],"content":"# Fresh\\nlatest content","sig":"latest"}
EOF

  allowed_comment_pubkey="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  blocked_comment_pubkey="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  comment_dir_allowed="$site_dir/site/nostr/events/$allowed_comment_pubkey/1"
  comment_dir_blocked="$site_dir/site/nostr/events/$blocked_comment_pubkey/1"
  mkdir -p "$comment_dir_allowed" "$comment_dir_blocked"
  cat > "$comment_dir_allowed/3333333333333333333333333333333333333333333333333333333333333333.json" <<EOF
{"id":"3333333333333333333333333333333333333333333333333333333333333333","pubkey":"$allowed_comment_pubkey","created_at":1700000600,"kind":1,"tags":[["a","$post_addr"]],"content":"Allowed comment","sig":"ok"}
EOF
  cat > "$comment_dir_blocked/4444444444444444444444444444444444444444444444444444444444444444.json" <<EOF
{"id":"4444444444444444444444444444444444444444444444444444444444444444","pubkey":"$blocked_comment_pubkey","created_at":1700000700,"kind":1,"tags":[["a","$post_addr"]],"content":"Blocked comment","sig":"nope"}
EOF

  printf '%s\n' "$blocked_comment_pubkey" > "$site_dir/site/nostr/state/blocklist.txt"

  run_cgi_get "$cgi_dir/blog-index" ""
  case "$CGI_BODY" in *"Fresh Bridge Title"*) ;; *) TEST_FAILURE_REASON="nostr projection should render latest event title"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in
    *"Old Bridge Title"*)
      TEST_FAILURE_REASON="older replaceable event version should not be rendered"
      teardown_blog_fixture
      return 1
      ;;
    *) ;;
  esac

  if [ ! -f "$site_dir/site/pages/posts/nostr-post.md" ]; then
    TEST_FAILURE_REASON="nostr projection should generate markdown render file"
    teardown_blog_fixture
    return 1
  fi

  run_cgi_get "$cgi_dir/blog-post-context" "path=nostr-post.html"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="post context should resolve projected nostr post"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"nostr":{"id":"'"$post_event_new"*) ;; *) TEST_FAILURE_REASON="post context should expose nostr proof metadata"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_get "$cgi_dir/blog-comments" "path=nostr-post.html"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="blog-comments should return success"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *"Allowed comment"*) ;; *) TEST_FAILURE_REASON="allowed mirrored comment should be visible"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in
    *"Blocked comment"*)
      TEST_FAILURE_REASON="blocklisted comment should be filtered from local comments index"
      teardown_blog_fixture
      return 1
      ;;
    *) ;;
  esac

  teardown_blog_fixture
}

test_blog_open_post_redirects() {
  setup_blog_fixture || return $?

  # Create built page so opener should redirect without 404.
  WEB_WIZARDRY_ROOT="$test_web_root" WIZARDRY_DIR="$ROOT_DIR" run_spell spells/web/build "$SITE_NAME" --full
  if [ "$STATUS" -ne 0 ]; then
    TEST_FAILURE_REASON="pre-build for open-post test failed"
    teardown_blog_fixture
    return 1
  fi

  run_cgi_get "$cgi_dir/blog-open-post" "path=2024-01-25-shell-web.html"
  case "$OUTPUT" in
    *"Status: 302 Found"*) ;;
    *)
      TEST_FAILURE_REASON="blog-open-post should return 302 redirect"
      teardown_blog_fixture
      return 1
      ;;
  esac
  case "$OUTPUT" in
    *"Location: /pages/posts/2024-01-25-shell-web.html"*) ;;
    *)
      TEST_FAILURE_REASON="blog-open-post should redirect to post html path"
      teardown_blog_fixture
      return 1
      ;;
  esac

  run_cgi_get "$cgi_dir/blog-open-post" "path=../bad"
  case "$OUTPUT" in
    *"Status: 400 Bad Request"*) ;;
    *)
      TEST_FAILURE_REASON="blog-open-post should reject invalid path traversal"
      teardown_blog_fixture
      return 1
      ;;
  esac

  teardown_blog_fixture
}

test_blog_account_update_and_player_name() {
  setup_blog_fixture || return $?

  mkdir -p "$data_dir/ssh-auth/users/testuser/delegates"
  user_profile="$data_dir/ssh-auth/users/testuser/profile.conf"
  config-set "$user_profile" username testuser
  config-set "$user_profile" fingerprint user-fingerprint
  config-set "$user_profile" is_admin false

  user_token="test-user-session-token"
  user_csrf="test-user-csrf-token"
  user_session_file="$data_dir/ssh-auth/sessions/$user_token.conf"
  now_epoch=$(date +%s)
  config-set "$user_session_file" username testuser
  config-set "$user_session_file" fingerprint user-fingerprint
  config-set "$user_session_file" csrf_token "$user_csrf"
  config-set "$user_session_file" created_at "$now_epoch"
  config-set "$user_session_file" expires_at "$((now_epoch + 3600))"
  config-set "$user_session_file" is_admin false

  run_cgi_post "$cgi_dir/blog-update-account" "session_token=$user_token&csrf_token=$user_csrf&player_name=Test+User"
  case "$CGI_BODY" in *'"success":true'*) ;; *) TEST_FAILURE_REASON="blog-update-account should save player_name for authenticated user"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"player_name":"Test User"'*) ;; *) TEST_FAILURE_REASON="blog-update-account should echo saved player_name"; teardown_blog_fixture; return 1 ;; esac

  saved_name=$(config-get "$user_profile" player_name 2>/dev/null || printf '')
  if [ "$saved_name" != "Test User" ]; then
    TEST_FAILURE_REASON="player_name should be stored in profile"
    teardown_blog_fixture
    return 1
  fi

  run_cgi_get "$cgi_dir/ssh-auth-check-session" "session_token=$user_token"
  case "$CGI_BODY" in *'"authenticated":true'*) ;; *) TEST_FAILURE_REASON="check-session should authenticate user session"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"player_name":"Test User"'*) ;; *) TEST_FAILURE_REASON="check-session should include updated player_name"; teardown_blog_fixture; return 1 ;; esac
  case "$CGI_BODY" in *'"is_admin":false'*) ;; *) TEST_FAILURE_REASON="non-admin session should remain non-admin"; teardown_blog_fixture; return 1 ;; esac

  run_cgi_post "$cgi_dir/blog-update-account" "session_token=$user_token&csrf_token=$user_csrf&player_name=%21bad"
  case "$CGI_BODY" in *'invalid_player_name'*) ;; *) TEST_FAILURE_REASON="blog-update-account should reject invalid player_name"; teardown_blog_fixture; return 1 ;; esac

  teardown_blog_fixture
}

run_test_case "blog scheduler publishes due scheduled drafts" test_blog_draft_scheduler_flow
run_test_case "blog drip interval is global and enforced" test_blog_drip_interval_enforced
run_test_case "blog media upload works and csrf is enforced" test_blog_media_upload_and_auth_csrf
run_test_case "blog public index hides drafts until publish" test_blog_public_index_hides_drafts
run_test_case "blog config updates drive queue metadata" test_blog_config_and_queue_metadata
run_test_case "blog autosave and save validation behave correctly" test_blog_autosave_and_validation_behavior
run_test_case "blog auth delegate/session lifecycle works" test_blog_auth_delegate_and_session_behavior
run_test_case "blog admin resolves across same-fingerprint aliases" test_blog_admin_resolution_by_fingerprint_alias
run_test_case "blog passkey login-begin enforces credentials" test_blog_passkey_login_begin_behavior
run_test_case "blog passkey register normalizes multiline keys" test_blog_passkey_register_normalizes_multiline_key
run_test_case "blog passkey register resolves stable username" test_blog_passkey_register_resolves_stable_username
run_test_case "blog archive endpoint renders grouped posts" test_blog_archive_endpoint_renders_posts
run_test_case "blog post-context endpoint returns post metadata" test_blog_post_context_endpoint
run_test_case "blog nostr bridge projects events and filters comments" test_blog_nostr_bridge_projection_and_comments
run_test_case "blog open-post redirects to post html" test_blog_open_post_redirects
run_test_case "blog account update persists player name" test_blog_account_update_and_player_name

finish_tests
