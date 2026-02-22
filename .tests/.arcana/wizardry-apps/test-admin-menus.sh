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

test_desktop_admin_contains_forge_entries() {
  tmp=$(make_tempdir)
  trap 'rm -rf "$tmp"' EXIT INT TERM

  sh "$test_root/spells/.imps/test/stub-menu" "$tmp/stub"
  MENU_LOG="$tmp/menu.log" PATH="$tmp/stub:$PATH" run_spell "spells/.arcana/wizardry-apps/wizardry-apps-desktop-admin"
  assert_success || return 1

  [ -f "$tmp/menu.log" ] || {
    TEST_FAILURE_REASON="menu log not written"
    return 1
  }

  grep -q "App Forge doctor%" "$tmp/menu.log" || {
    TEST_FAILURE_REASON="missing App Forge doctor entry"
    return 1
  }

  grep -q "Run App Forge%" "$tmp/menu.log" || {
    TEST_FAILURE_REASON="missing Run App Forge entry"
    return 1
  }

  grep -q "Install App Forge launcher%" "$tmp/menu.log" || {
    TEST_FAILURE_REASON="missing Install App Forge launcher entry"
    return 1
  }

  grep -q "Uninstall App Forge launcher%" "$tmp/menu.log" || {
    TEST_FAILURE_REASON="missing Uninstall App Forge launcher entry"
    return 1
  }
}

run_test_case "wizardry-apps-web-admin shows help" test_web_admin_help
run_test_case "wizardry-apps-desktop-admin shows help" test_desktop_admin_help
run_test_case "wizardry-apps-mobile-admin shows help" test_mobile_admin_help
run_test_case "wizardry-apps-desktop-admin includes forge entries" test_desktop_admin_contains_forge_entries
finish_tests
