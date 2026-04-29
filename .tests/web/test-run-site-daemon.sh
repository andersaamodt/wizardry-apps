#!/bin/sh
# Tests for run-site-daemon spell

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_run_site_daemon_help() {
  run_spell spells/web/run-site-daemon --help
  assert_success
  assert_output_contains "Usage: run-site-daemon"
}

test_run_site_daemon_rejects_path_site_name() {
  skip-if-compiled || return $?

  base_dir=$(temp-dir web-wizardry-test)
  web_root="$base_dir/sites"
  outside_site="$base_dir/sibling"
  mkdir -p "$web_root" "$outside_site"

  WEB_WIZARDRY_ROOT="$web_root" run_spell spells/web/run-site-daemon ../sibling
  assert_status 2
  assert_error_contains "invalid site name"

  rm -rf "$base_dir"
}

test_run_site_daemon_rejects_invalid_fcgiwrap_workers() {
  skip-if-compiled || return $?

  base_dir=$(temp-dir web-wizardry-test)
  web_root="$base_dir/sites"
  site_dir="$web_root/mysite"
  stub_dir=$(temp-dir web-wizardry-stub)
  stub_log="$base_dir/stub.log"
  mkdir -p "$site_dir/build/pages" "$site_dir/nginx" "$stub_dir"
  printf '%s\n' '<!doctype html><title>test</title>' > "$site_dir/build/pages/index.html"
  printf '%s\n' 'events {}' 'http {}' > "$site_dir/nginx/nginx.conf"

  cat > "$stub_dir/nginx" <<'STUB'
#!/bin/sh
printf '%s\n' "nginx $*" >> "${DAEMON_STUB_LOG:?}"
exit 0
STUB
  chmod +x "$stub_dir/nginx"

  cat > "$stub_dir/fcgiwrap" <<'STUB'
#!/bin/sh
printf '%s\n' "fcgiwrap $*" >> "${DAEMON_STUB_LOG:?}"
exit 0
STUB
  chmod +x "$stub_dir/fcgiwrap"

  for workers in 0 65 9999 '8;touch /tmp/wizardry-fcgiwrap-workers-bad'; do
    rm -f "$stub_log"
    run_cmd env PATH="$stub_dir:$PATH" WEB_WIZARDRY_ROOT="$web_root" \
      DAEMON_STUB_LOG="$stub_log" "FCGIWRAP_WORKERS=$workers" \
      "$ROOT_DIR/spells/web/run-site-daemon" mysite
    assert_status 2 || return 1
    assert_error_contains "invalid FCGIWRAP_WORKERS" || return 1

    if [ -f "$stub_log" ]; then
      TEST_FAILURE_REASON="daemon commands were called for invalid FCGIWRAP_WORKERS=$workers"
      return 1
    fi
  done

  rm -rf "$base_dir" "$stub_dir"
}

run_test_case "run-site-daemon --help works" test_run_site_daemon_help
run_test_case "run-site-daemon rejects path site name" test_run_site_daemon_rejects_path_site_name
run_test_case "run-site-daemon rejects invalid fcgiwrap worker counts" test_run_site_daemon_rejects_invalid_fcgiwrap_workers

finish_tests
