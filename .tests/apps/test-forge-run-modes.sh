#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/apps/forge/index.html"
backend="$root/apps/forge/scripts/forge-backend.sh"

[ -f "$ui" ] || {
  printf '%s\n' "forge ui file missing: $ui" >&2
  exit 1
}
[ -f "$backend" ] || {
  printf '%s\n' "forge backend file missing: $backend" >&2
  exit 1
}

# Strict standardization: no per-app run/install branch config in Forge UI.
! grep -F "LINUX_INSTALL_MODE_KEY" "$ui" >/dev/null
! grep -F "workspaceRunModeForItem" "$ui" >/dev/null
! grep -F "runModeRequest" "$ui" >/dev/null
! grep -F "run_mode=host" "$ui" >/dev/null
grep -F "built and launched from the compiled desktop app bundle." "$ui" >/dev/null
grep -F "if (enabledTargets[nativeTarget]) {" "$ui" >/dev/null
grep -F "if (enabledTargets['hosted-web']) {" "$ui" >/dev/null

# Desktop precedence in builtin run pipeline (desktop branch appears before hosted-web fallback).
builtin_desktop_line=$(grep -nF "if (enabledTargets[nativeTarget]) {" "$ui" | head -n 1 | cut -d: -f1)
builtin_web_line=$(grep -nF "if (enabledTargets['hosted-web']) {" "$ui" | head -n 1 | cut -d: -f1)
[ "${builtin_desktop_line:-0}" -gt 0 ]
[ "${builtin_web_line:-0}" -gt 0 ]
[ "$builtin_desktop_line" -lt "$builtin_web_line" ]

# Desktop precedence in workspace run pipeline.
workspace_desktop_line=$(grep -nF "if (hostTarget && hasEnabledHostRunTarget(selected)) {" "$ui" | head -n 1 | cut -d: -f1)
workspace_web_line=$(grep -nF "if (hasEnabledHostedWebTarget(selected)) {" "$ui" | head -n 1 | cut -d: -f1)
[ "${workspace_desktop_line:-0}" -gt 0 ]
[ "${workspace_web_line:-0}" -gt 0 ]
[ "$workspace_desktop_line" -lt "$workspace_web_line" ]

# Backend CLI contract is strict and single-path.
help_out=$("$backend" --help)
printf '%s\n' "$help_out" | grep -F "install-desktop [ROOT_HINT] APP_SLUG [TARGET_ID]" >/dev/null
printf '%s\n' "$help_out" | grep -F "run-desktop [ROOT_HINT] APP_SLUG" >/dev/null
printf '%s\n' "$help_out" | grep -F "run-workspace [ROOT_HINT] WORKSPACE_PATH [CONTEXT]" >/dev/null
printf '%s\n' "$help_out" | grep -F "CONTEXT values for scaffold-workspace:" >/dev/null
printf '%s\n' "$help_out" | grep -F "  web | godot" >/dev/null

! grep -F "RUN_MODE" "$backend" >/dev/null
! grep -F "run_mode=host" "$backend" >/dev/null
! grep -F "appimage-local-bin" "$backend" >/dev/null
! grep -F "workspace_field \"\$conf\" context" "$backend" >/dev/null
grep -F 'if [ "$has_host_target" = false ] && [ "$has_hosted_web" = true ]; then' "$backend" >/dev/null
grep -F "printf 'install_mode=%s\\n' \"\$(normalize_linux_install_mode)\"" "$backend" >/dev/null
grep -F "install_root=\"\$HOME/.local/share/wizardry-apps/\$slug\"" "$backend" >/dev/null
grep -F "launcher_path=\"\$launcher_dir/wizardry-\$slug\"" "$backend" >/dev/null
grep -F "wizardry-apps-root.txt" "$backend" >/dev/null

printf '%s\n' "forge standardized run/install pipeline tests passed"
