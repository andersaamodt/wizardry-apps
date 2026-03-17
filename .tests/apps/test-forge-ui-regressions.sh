#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
ui="$root/apps/forge/index.html"
host_macos="$root/apps/.host/macos/main.m"

[ -f "$ui" ] || {
  printf '%s\n' "forge ui file missing: $ui" >&2
  exit 1
}
[ -f "$host_macos" ] || {
  printf '%s\n' "forge macOS host file missing: $host_macos" >&2
  exit 1
}

grep -F 'id="footer-status"' "$ui" >/dev/null
grep -F "function setFooterStatus(kind, msg)" "$ui" >/dev/null
grep -F "function shouldShowFooterStatusForAction(label, opts)" "$ui" >/dev/null
grep -F "setFooterStatus('working', label + '...');" "$ui" >/dev/null
grep -F "setFooterStatus('ok', label + ' complete');" "$ui" >/dev/null
grep -F "setFooterStatus('bad', message);" "$ui" >/dev/null
grep -F "return !/^(open|copy)\\b/i.test(String(label || ''));" "$ui" >/dev/null

grep -F "perform('Import project folder'" "$ui" >/dev/null
grep -F "perform('Create project', createProject, { swallow: true });" "$ui" >/dev/null
grep -F "backend('run-workspace', [item.path, item.context]);" "$ui" >/dev/null
grep -F "backend('rebuild-workspace', [selected.path, selected.context]);" "$ui" >/dev/null
grep -F "built and launched from the desktop app bundle." "$ui" >/dev/null
grep -F "launched as hosted web." "$ui" >/dev/null

grep -F "var directTypes = ['text/uri-list', 'public.file-url', 'text/plain', 'public.utf8-plain-text'];" "$ui" >/dev/null
grep -F "types.indexOf('public.utf8-plain-text') >= 0" "$ui" >/dev/null
grep -F "itemType === 'public.utf8-plain-text'" "$ui" >/dev/null
grep -F "window.forgeHostFileDrag = handleForgeHostFileDrag;" "$ui" >/dev/null
grep -F "var argv = ['__wizardry_host_forge_drop_zone'];" "$ui" >/dev/null
grep -F "toast('Drop a project folder to import.', 'bad');" "$ui" >/dev/null

grep -F "window.forgeHostFileDrag" "$host_macos" >/dev/null
grep -F "__wizardry_host_forge_drop_zone" "$host_macos" >/dev/null

printf '%s\n' "forge ui regression tests passed"
