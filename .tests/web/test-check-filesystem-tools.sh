#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_help() {
  run_spell spells/web/check-filesystem-tools --help
  assert_success
  assert_output_contains "Usage: check-filesystem-tools"
}

test_ok_when_tools_exist() {
  tmp_bin=$(temp-dir check-filesystem-tools-bin)
  cat > "$tmp_bin/resize2fs" <<'EOF'
#!/bin/sh
exit 0
EOF
  cat > "$tmp_bin/xfs_growfs" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$tmp_bin/resize2fs" "$tmp_bin/xfs_growfs"

  PATH="$tmp_bin:/usr/bin:/bin:/usr/sbin:/sbin" run_spell spells/web/check-filesystem-tools
  assert_success
  assert_output_contains "status=ok"

  rm -rf "$tmp_bin"
}

test_bad_when_tools_missing() {
  tmp_bin=$(temp-dir check-filesystem-tools-bin)
  PATH="$tmp_bin" run_spell spells/web/check-filesystem-tools
  assert_success
  assert_output_contains "status=bad"
  assert_output_contains "Missing filesystem tools"
  rm -rf "$tmp_bin"
}

run_test_case "check-filesystem-tools shows help" test_help
run_test_case "check-filesystem-tools returns ok when tools exist" test_ok_when_tools_exist
run_test_case "check-filesystem-tools reports missing tools" test_bad_when_tools_missing

finish_tests
