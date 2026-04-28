#!/bin/sh
# Test renew-https spell

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_renew_https_help() {
  run_spell spells/web/renew-https --help
  assert_success
  assert_output_contains "Usage:"
}

run_test_case "renew-https --help" test_renew_https_help

test_renew_https_rejects_configured_invalid_domain_before_certbot() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  mkdir -p "$web_root/mysite"
  printf 'site-name=mysite\ndomain=bad/domain\nhttps=true\ncert-path=/missing/cert.pem\n' > "$web_root/mysite/site.conf"

  WEB_WIZARDRY_ROOT="$web_root" WIZARDRY_SITE_USER_REEXEC=1 \
    run_spell spells/web/renew-https mysite
  assert_status 2
  assert_error_contains "invalid domain"

  rm -rf "$web_root"
}

run_test_case "renew-https rejects configured invalid domain before certbot" test_renew_https_rejects_configured_invalid_domain_before_certbot

finish_tests
