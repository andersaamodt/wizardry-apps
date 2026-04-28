#!/bin/sh
# Test stop-site spell

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_stop_site_help() {
  run_spell spells/web/stop-site --help
  assert_success
  assert_output_contains "Usage:"
}

test_stop_site_rejects_path_traversal() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  outside_dir="$(dirname "$web_root")/wizardry-stop-escape-$$"
  rm -rf "$outside_dir"
  mkdir -p "$outside_dir/nginx"
  printf '999999\n' > "$outside_dir/nginx/nginx.pid"

  WEB_WIZARDRY_ROOT="$web_root" run_spell spells/web/stop-site "../$(basename "$outside_dir")"
  assert_status 2 || {
    rm -rf "$web_root" "$outside_dir"
    return 1
  }

  [ -f "$outside_dir/nginx/nginx.pid" ] || {
    TEST_FAILURE_REASON="stop-site removed PID file outside WEB_WIZARDRY_ROOT"
    rm -rf "$web_root" "$outside_dir"
    return 1
  }

  rm -rf "$web_root" "$outside_dir"
}

run_test_case "stop-site --help" test_stop_site_help
run_test_case "stop-site rejects path traversal" test_stop_site_rejects_path_traversal

finish_tests
