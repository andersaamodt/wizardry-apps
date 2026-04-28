#!/bin/sh
# Test setup-https spell

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_setup_https_help() {
  run_spell spells/web/setup-https --help
  assert_success
  assert_output_contains "Usage:"
}

run_test_case "setup-https --help" test_setup_https_help

test_setup_https_rejects_prompted_invalid_domain_before_persisting() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  mkdir -p "$web_root/mysite"
  printf 'site-name=mysite\ndomain=localhost\n' > "$web_root/mysite/site.conf"

  spell_path="$ROOT_DIR/spells/web/setup-https"
  run_cmd env WEB_WIZARDRY_ROOT="$web_root" WIZARDRY_SITE_USER_REEXEC=1 \
    sh -c 'printf "y\nbad/domain\n" | "$1" mysite' sh "$spell_path"
  assert_status 2
  assert_error_contains "invalid domain"
  if grep -q 'bad/domain' "$web_root/mysite/site.conf"; then
    TEST_FAILURE_REASON="setup-https persisted an invalid prompted domain"
    rm -rf "$web_root"
    return 1
  fi

  rm -rf "$web_root"
}

run_test_case "setup-https rejects prompted invalid domain before persisting" test_setup_https_rejects_prompted_invalid_domain_before_persisting

finish_tests
