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

run_test_case "run-site-daemon --help works" test_run_site_daemon_help
run_test_case "run-site-daemon rejects path site name" test_run_site_daemon_rejects_path_site_name

finish_tests
