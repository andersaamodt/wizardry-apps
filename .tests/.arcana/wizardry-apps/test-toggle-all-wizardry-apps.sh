#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_toggle_all_help() {
  run_spell "spells/.arcana/wizardry-apps/toggle-all-wizardry-apps" --help
  assert_success && assert_output_contains "Usage:"
}

test_toggle_all_enable_disable() {
  tmp=$(make_tempdir)
  trap 'rm -rf "$tmp"' EXIT INT TERM

  WIZARDRY_APPS_STATE_DIR="$tmp/state" run_spell "spells/.arcana/wizardry-apps/toggle-all-wizardry-apps" --enable
  assert_success || return 1

  count=$(find "$tmp/state/components-enabled" -type f -name '*.enabled' 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$count" = "9" ] || {
    TEST_FAILURE_REASON="expected 9 enabled component files, got $count"
    return 1
  }

  WIZARDRY_APPS_STATE_DIR="$tmp/state" run_spell "spells/.arcana/wizardry-apps/toggle-all-wizardry-apps" --disable
  assert_success || return 1

  count=$(find "$tmp/state/components-enabled" -type f -name '*.enabled' 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$count" = "0" ] || {
    TEST_FAILURE_REASON="expected 0 enabled component files after disable, got $count"
    return 1
  }
}

run_test_case "toggle-all-wizardry-apps shows help" test_toggle_all_help
run_test_case "toggle-all-wizardry-apps toggles all components" test_toggle_all_enable_disable
finish_tests
