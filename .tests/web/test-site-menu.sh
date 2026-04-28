#!/bin/sh
# Test site-menu spell

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_site_menu_help() {
  run_spell spells/web/site-menu --help
  assert_success
  assert_output_contains "Usage:"
}

test_site_menu_rejects_regex_site_name() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  mkdir -p "$web_root/foo.*/site"
  printf 'site-name=foo.*\nport=8080\n' > "$web_root/foo.*/site.conf"

  WEB_WIZARDRY_ROOT="$web_root" WIZARDRY_SITES_DIR="$web_root" \
    run_spell spells/web/site-menu 'foo.*'
  assert_status 2
  assert_error_contains "invalid site name"

  rm -rf "$web_root"
}

run_test_case "site-menu --help" test_site_menu_help
run_test_case "site-menu rejects regex site name" test_site_menu_rejects_regex_site_name

finish_tests
