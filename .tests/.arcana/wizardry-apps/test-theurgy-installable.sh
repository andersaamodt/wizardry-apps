#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_theurgy_arcana_help() {
  for spell in \
    spells/.arcana/theurgy/install-theurgy \
    spells/.arcana/theurgy/install-browser-proof-runtime \
    spells/.arcana/theurgy/uninstall-theurgy \
    spells/.arcana/theurgy/is-theurgy-installed \
    spells/.arcana/theurgy/check-theurgy \
    spells/.arcana/theurgy/invoke-theurgy \
    spells/.arcana/theurgy/theurgy-status \
    spells/.arcana/theurgy/theurgy-menu
  do
    run_spell "$spell" --help
    assert_success && assert_output_contains "Usage:"
  done
}

test_theurgy_status_reports_without_install() {
  tmp_home=$(mktemp -d "${TMPDIR:-/tmp}/theurgy-test-home.XXXXXX")
  tmp_bin=$(mktemp -d "${TMPDIR:-/tmp}/theurgy-test-bin.XXXXXX")
  HOME=$tmp_home XDG_BIN_HOME=$tmp_bin run_spell "spells/.arcana/theurgy/check-theurgy"
  assert_success
  assert_output_contains "status=bad"
  rm -rf "$tmp_home" "$tmp_bin"
}

test_theurgy_installable_is_in_wizardry_projects_menu_source() {
  grep -F "wizardry apps%" "spells/.arcana/wizardry-projects/wizardry-projects-menu" >/dev/null
  grep -F "theurgy%" "spells/.arcana/wizardry-projects/wizardry-projects-menu" >/dev/null
  grep -F "theurgy/is-theurgy-installed" "spells/.arcana/wizardry-projects/wizardry-projects-status" >/dev/null
}

test_theurgy_browser_proof_runtime_is_menu_installable() {
  grep -F 'Install browser proof runtime%$script_dir/install-browser-proof-runtime' \
    "spells/.arcana/theurgy/theurgy-menu" >/dev/null
  grep -F "install-theurgy-browser-proof-runtime" \
    "spells/.arcana/theurgy/install-browser-proof-runtime" >/dev/null
}

run_test_case "theurgy arcana spells show help" test_theurgy_arcana_help
run_test_case "theurgy status reports missing install" test_theurgy_status_reports_without_install
run_test_case "theurgy is wired into wizardry projects menu/status" test_theurgy_installable_is_in_wizardry_projects_menu_source
run_test_case "theurgy browser proof runtime is menu-installable" test_theurgy_browser_proof_runtime_is_menu_installable
finish_tests
