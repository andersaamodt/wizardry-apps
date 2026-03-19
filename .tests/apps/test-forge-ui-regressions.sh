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
grep -F "var successLabel = String(opts.successLabel || (label + ' complete'));" "$ui" >/dev/null
grep -F "setFooterStatus('ok', successLabel);" "$ui" >/dev/null
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
grep -F "window.forgeHostIconDropResult = finishNativeHostIconDrop;" "$ui" >/dev/null
grep -F "beginNativeHostIconDrop(paths[0] || '');" "$ui" >/dev/null
grep -F "argv = ['__wizardry_host_forge_icon_drop_target'];" "$ui" >/dev/null
grep -F "nativeHostIconDropArmed: false," "$ui" >/dev/null
grep -F "nativeHostIconDropHandledUntil: 0," "$ui" >/dev/null
grep -F "nativeHostIconDropFallbackTimer: 0," "$ui" >/dev/null
grep -F "hostIconDropVisualPendingKey: ''," "$ui" >/dev/null
grep -F "function setHostIconDropVisualPending(item, flag)" "$ui" >/dev/null
grep -F "function markNativeHostIconDropHandled()" "$ui" >/dev/null
grep -F "function nativeHostRecentlyHandledIconDrop()" "$ui" >/dev/null
grep -F "scheduleNativeHostIconDropFallback(droppedPath, file);" "$ui" >/dev/null
grep -F "setHostIconDropVisualPending(selected, true);" "$ui" >/dev/null
grep -F "setHostIconDropVisualPending(selected, false);" "$ui" >/dev/null
grep -F "markNativeHostIconDropHandled();" "$ui" >/dev/null
grep -F "state.hostIconDropPendingKey || nativeHostRecentlyHandledIconDrop()" "$ui" >/dev/null
grep -F "state.hostIconDropPendingKey) {" "$ui" >/dev/null
grep -F "}, 900);" "$ui" >/dev/null
grep -F "setNativeHostIconDropExpected(true);" "$ui" >/dev/null
grep -F "toast('Drop a project folder to import.', 'bad');" "$ui" >/dev/null

grep -F 'dispatchForgeHostCallbackNamed:@"forgeHostFileDrag"' "$host_macos" >/dev/null
grep -F "forgeHostIconDropResult" "$host_macos" >/dev/null
grep -F "__wizardry_host_forge_icon_drop_target" "$host_macos" >/dev/null
grep -F "runForgeIconDropForPath" "$host_macos" >/dev/null
grep -F 'NSPasteboardTypeFileURL' "$host_macos" >/dev/null
grep -F '"public.file-url"' "$host_macos" >/dev/null
grep -F '"text/uri-list"' "$host_macos" >/dev/null
grep -F 'NSFilenamesPboardType' "$host_macos" >/dev/null

printf '%s\n' "forge ui regression tests passed"
