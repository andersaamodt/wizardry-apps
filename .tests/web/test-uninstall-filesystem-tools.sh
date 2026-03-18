#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_help() {
  run_spell spells/web/uninstall-filesystem-tools --help
  assert_success
  assert_output_contains "Usage: uninstall-filesystem-tools"
}

test_success_when_tools_missing() {
  tmp_bin=$(temp-dir uninstall-filesystem-tools-bin)
  PATH="$tmp_bin:/usr/bin:/bin:/usr/sbin:/sbin" run_spell spells/web/uninstall-filesystem-tools
  assert_success
  assert_output_contains "already absent"
  rm -rf "$tmp_bin"
}

run_test_case "uninstall-filesystem-tools shows help" test_help
run_test_case "uninstall-filesystem-tools succeeds when tools are missing" test_success_when_tools_missing

finish_tests
