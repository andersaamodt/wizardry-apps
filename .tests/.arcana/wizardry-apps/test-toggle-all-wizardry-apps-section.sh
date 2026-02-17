#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_toggle_section_help() {
  run_spell "spells/.arcana/wizardry-apps/toggle-all-wizardry-apps-section" --help
  assert_success && assert_output_contains "Usage:"
}

test_toggle_web_section_only() {
  tmp=$(make_tempdir)
  trap 'rm -rf "$tmp"' EXIT INT TERM

  WIZARDRY_APPS_STATE_DIR="$tmp/state" run_spell "spells/.arcana/wizardry-apps/toggle-all-wizardry-apps-section" web --enable
  assert_success || return 1

  total=$(find "$tmp/state/components-enabled" -type f -name '*.enabled' 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$total" = "3" ] || {
    TEST_FAILURE_REASON="expected 3 enabled component files for web section, got $total"
    return 1
  }

  for c in web-hosted web-templates web-cgi-adapter; do
    [ -f "$tmp/state/components-enabled/$c.enabled" ] || {
      TEST_FAILURE_REASON="missing expected enabled file for $c"
      return 1
    }
  done
}

run_test_case "toggle-all-wizardry-apps-section shows help" test_toggle_section_help
run_test_case "toggle-all-wizardry-apps-section enables web only" test_toggle_web_section_only
finish_tests
