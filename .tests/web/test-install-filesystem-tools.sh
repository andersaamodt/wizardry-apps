#!/bin/sh
test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
while [ ! -f "$test_root/spells/.imps/test/test-bootstrap" ] && [ "$test_root" != "/" ]; do
  test_root=$(dirname "$test_root")
done
. "$test_root/spells/.imps/test/test-bootstrap"

test_help() {
  run_spell spells/web/install-filesystem-tools --help
  assert_success
  assert_output_contains "Usage: install-filesystem-tools"
}

test_success_when_tools_already_present() {
  tmp_bin=$(temp-dir install-filesystem-tools-bin)
  cat > "$tmp_bin/resize2fs" <<'EOF'
#!/bin/sh
exit 0
EOF
  cat > "$tmp_bin/xfs_growfs" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$tmp_bin/resize2fs" "$tmp_bin/xfs_growfs"

  PATH="$tmp_bin:/usr/bin:/bin:/usr/sbin:/sbin" run_spell spells/web/install-filesystem-tools
  assert_success
  assert_output_contains "already installed"

  rm -rf "$tmp_bin"
}

test_failure_without_supported_package_manager() {
  tmp_bin=$(temp-dir install-filesystem-tools-bin)
  PATH="$tmp_bin" run_spell spells/web/install-filesystem-tools
  assert_failure
  assert_output_contains "no supported package manager"
  rm -rf "$tmp_bin"
}

run_test_case "install-filesystem-tools shows help" test_help
run_test_case "install-filesystem-tools succeeds when tools already exist" test_success_when_tools_already_present
run_test_case "install-filesystem-tools fails clearly without package manager" test_failure_without_supported_package_manager

finish_tests
