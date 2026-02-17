#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_wizardry_apps_menu_help() {
  run_spell "spells/.arcana/wizardry-apps/wizardry-apps-menu" --help
  assert_success && assert_output_contains "Usage:"
}

test_wizardry_apps_menu_sections() {
  tmp=$(make_tempdir)
  trap 'rm -rf "$tmp"' EXIT INT TERM

  sh "$test_root/spells/.imps/test/stub-menu" "$tmp/stub"
  MENU_LOG="$tmp/menu.log" PATH="$tmp/stub:$PATH" WIZARDRY_APPS_STATE_DIR="$tmp/state" \
    run_spell "spells/.arcana/wizardry-apps/wizardry-apps-menu"

  assert_success || return 1
  [ -f "$tmp/menu.log" ] || {
    TEST_FAILURE_REASON="menu log not written"
    return 1
  }

  grep -q "Web:" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing Web section"; return 1; }
  grep -q "Desktop:" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing Desktop section"; return 1; }
  grep -q "Mobile:" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing Mobile section"; return 1; }
  grep -q "Enable all web%" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing web enable-all"; return 1; }
  grep -q "Disable all desktop%" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing desktop disable-all"; return 1; }
  grep -q "Enable all mobile%" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing mobile enable-all"; return 1; }
  grep -q "Enable all and exit%" "$tmp/menu.log" || { TEST_FAILURE_REASON="missing global enable/disable and exit"; return 1; }
}

run_test_case "wizardry-apps-menu shows help" test_wizardry_apps_menu_help
run_test_case "wizardry-apps-menu includes required sections and toggles" test_wizardry_apps_menu_sections
finish_tests
