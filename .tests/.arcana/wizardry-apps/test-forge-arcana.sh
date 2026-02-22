#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_launch_app_forge_help() {
  run_spell "spells/.arcana/wizardry-apps/launch-app-forge" --help
  assert_success && assert_output_contains "Usage:"
}

test_install_app_forge_help() {
  run_spell "spells/.arcana/wizardry-apps/install-app-forge" --help
  assert_success && assert_output_contains "Usage:"
}

test_uninstall_app_forge_help() {
  run_spell "spells/.arcana/wizardry-apps/uninstall-app-forge" --help
  assert_success && assert_output_contains "Usage:"
}

run_test_case "launch-app-forge shows help" test_launch_app_forge_help
run_test_case "install-app-forge shows help" test_install_app_forge_help
run_test_case "uninstall-app-forge shows help" test_uninstall_app_forge_help
finish_tests
