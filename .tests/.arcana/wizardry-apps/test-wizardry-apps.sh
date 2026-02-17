#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_wizardry_apps_help() {
  run_spell "spells/.arcana/wizardry-apps/wizardry-apps" --help
  assert_success && assert_output_contains "Usage:"
}

run_test_case "wizardry-apps shows help" test_wizardry_apps_help
finish_tests
