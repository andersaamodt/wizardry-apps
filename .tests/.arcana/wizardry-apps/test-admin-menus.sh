#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_web_admin_help() {
  run_spell "spells/.arcana/wizardry-apps/wizardry-apps-web-admin" --help
  assert_success && assert_output_contains "Usage:"
}

test_desktop_admin_help() {
  run_spell "spells/.arcana/wizardry-apps/wizardry-apps-desktop-admin" --help
  assert_success && assert_output_contains "Usage:"
}

test_mobile_admin_help() {
  run_spell "spells/.arcana/wizardry-apps/wizardry-apps-mobile-admin" --help
  assert_success && assert_output_contains "Usage:"
}

run_test_case "wizardry-apps-web-admin shows help" test_web_admin_help
run_test_case "wizardry-apps-desktop-admin shows help" test_desktop_admin_help
run_test_case "wizardry-apps-mobile-admin shows help" test_mobile_admin_help
finish_tests
