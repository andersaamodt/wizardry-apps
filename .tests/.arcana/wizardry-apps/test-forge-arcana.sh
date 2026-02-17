#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_launch_wizardry_forge_help() {
  run_spell "spells/.arcana/wizardry-apps/launch-wizardry-forge" --help
  assert_success && assert_output_contains "Usage:"
}

test_install_wizardry_forge_help() {
  run_spell "spells/.arcana/wizardry-apps/install-wizardry-forge" --help
  assert_success && assert_output_contains "Usage:"
}

test_uninstall_wizardry_forge_help() {
  run_spell "spells/.arcana/wizardry-apps/uninstall-wizardry-forge" --help
  assert_success && assert_output_contains "Usage:"
}

run_test_case "launch-wizardry-forge shows help" test_launch_wizardry_forge_help
run_test_case "install-wizardry-forge shows help" test_install_wizardry_forge_help
run_test_case "uninstall-wizardry-forge shows help" test_uninstall_wizardry_forge_help
finish_tests
