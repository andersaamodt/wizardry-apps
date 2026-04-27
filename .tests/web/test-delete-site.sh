#!/bin/sh
# Test delete-site spell

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_delete_site_help() {
  run_spell spells/web/delete-site --help
  assert_success
  assert_output_contains "Usage:"
}

test_delete_site_rejects_path_traversal() {
  skip-if-compiled || return $?

  test_web_root=$(temp-dir web-wizardry-test)
  outside_dir="$(dirname "$test_web_root")/wizardry-delete-escape-$$"
  rm -rf "$outside_dir"
  mkdir -p "$outside_dir"
  printf 'site-name=outside\nsite-user=%s\n' "$(id -un)" > "$outside_dir/site.conf"

  run_cmd sh -c 'printf "y\n" | WIZARDRY_SITES_DIR="$1" "$2/spells/web/delete-site" "../$3"' \
    sh "$test_web_root" "$ROOT_DIR" "$(basename "$outside_dir")"
  assert_status 2 || {
    rm -rf "$test_web_root" "$outside_dir"
    return 1
  }

  [ -d "$outside_dir" ] || {
    TEST_FAILURE_REASON="delete-site removed a directory outside WIZARDRY_SITES_DIR"
    rm -rf "$test_web_root" "$outside_dir"
    return 1
  }

  rm -rf "$test_web_root" "$outside_dir"
}

run_test_case "delete-site --help" test_delete_site_help
run_test_case "delete-site rejects path traversal" test_delete_site_rejects_path_traversal

finish_tests
