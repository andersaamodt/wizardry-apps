#!/bin/sh
set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
# shellcheck source=/dev/null
. "$test_root/spells/.imps/test/test-bootstrap"

spell_is_executable() {
  [ -x "$ROOT_DIR/spells/web/toggle-site-tor-hosting" ]
}

run_test_case "web/toggle-site-tor-hosting is executable" spell_is_executable

spell_has_content() {
  [ -s "$ROOT_DIR/spells/web/toggle-site-tor-hosting" ]
}

run_test_case "web/toggle-site-tor-hosting has content" spell_has_content

shows_help() {
  run_spell spells/web/toggle-site-tor-hosting --help
  true
}

run_test_case "toggle-site-tor-hosting shows help" shows_help

rejects_regex_site_name() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  mkdir -p "$web_root/foo.*"
  printf 'site-name=foo.*\nport=8080\n' > "$web_root/foo.*/site.conf"

  WEB_WIZARDRY_ROOT="$web_root" WIZARDRY_SITES_DIR="$web_root" \
    run_spell spells/web/toggle-site-tor-hosting 'foo.*'
  assert_status 2
  assert_error_contains "invalid site name"

  rm -rf "$web_root"
}

run_test_case "toggle-site-tor-hosting rejects regex site name" rejects_regex_site_name

rejects_configured_nonnumeric_port_before_tor_side_effects() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  mkdir -p "$web_root/mysite"
  printf 'site-name=mysite\nport=abc;HiddenServiceDir /tmp/owned\n' > "$web_root/mysite/site.conf"

  WEB_WIZARDRY_ROOT="$web_root" WIZARDRY_SITES_DIR="$web_root" \
    run_spell spells/web/toggle-site-tor-hosting mysite
  assert_status 2
  assert_error_contains "port must be numeric"

  rm -rf "$web_root"
}

run_test_case "toggle-site-tor-hosting rejects configured nonnumeric port before tor side effects" rejects_configured_nonnumeric_port_before_tor_side_effects

rejects_configured_out_of_range_port_before_tor_side_effects() {
  skip-if-compiled || return $?

  web_root=$(temp-dir web-wizardry-test)
  mkdir -p "$web_root/mysite"
  printf 'site-name=mysite\nport=70000\n' > "$web_root/mysite/site.conf"

  WEB_WIZARDRY_ROOT="$web_root" WIZARDRY_SITES_DIR="$web_root" \
    run_spell spells/web/toggle-site-tor-hosting mysite
  assert_status 2
  assert_error_contains "port must be between 1 and 65535"

  rm -rf "$web_root"
}

run_test_case "toggle-site-tor-hosting rejects configured out-of-range port before tor side effects" rejects_configured_out_of_range_port_before_tor_side_effects
finish_tests
