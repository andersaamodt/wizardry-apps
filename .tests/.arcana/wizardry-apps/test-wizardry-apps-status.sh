#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_wizardry_apps_status_help() {
  run_spell "spells/.arcana/wizardry-apps/wizardry-apps-status" --help
  assert_success && assert_output_contains "Usage:"
}

test_wizardry_apps_status_section() {
  tmp=$(make_tempdir)
  trap 'rm -rf "$tmp"' EXIT INT TERM

  WIZARDRY_APPS_STATE_DIR="$tmp/state" run_spell "spells/.arcana/wizardry-apps/set-apps-component-state" mobile-ios --enable
  assert_success || return 1

  WIZARDRY_APPS_STATE_DIR="$tmp/state" run_spell "spells/.arcana/wizardry-apps/wizardry-apps-status" --section mobile
  assert_success || return 1
  assert_output_contains "mobile" || return 1
  assert_output_contains "[X] iOS host pipeline" || return 1
  assert_output_contains "[ ] Android host pipeline" || return 1
}

run_test_case "wizardry-apps-status shows help" test_wizardry_apps_status_help
run_test_case "wizardry-apps-status reports section state" test_wizardry_apps_status_section
finish_tests
