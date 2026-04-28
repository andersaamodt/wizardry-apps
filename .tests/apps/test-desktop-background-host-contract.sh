#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
mac_host="$root/apps/.host/macos/main.m"
linux_host="$root/apps/.host/linux/main.c"

[ -f "$mac_host" ]
[ -f "$linux_host" ]

grep -F '__wizardry_host_set_background_mode' "$mac_host" >/dev/null
grep -F '__wizardry_host_status_item_state' "$mac_host" >/dev/null
grep -F '__wizardry_host_matchbook_status_item_sync' "$mac_host" >/dev/null
grep -F 'status_item_rendered=' "$mac_host" >/dev/null
grep -F 'applyBackgroundModeEnabled:' "$mac_host" >/dev/null
grep -F 'showStatusItem:' "$mac_host" >/dev/null
grep -F 'NSStatusItem *statusItem' "$mac_host" >/dev/null
grep -F 'renderedStatusItemImage' "$mac_host" >/dev/null
grep -F 'isMatchbookApp' "$mac_host" >/dev/null
grep -F 'isBellheimApp' "$mac_host" >/dev/null
grep -F 'Bellheim is running in background' "$mac_host" >/dev/null
grep -F 'clapperRadius' "$mac_host" >/dev/null
grep -F 'lineToPoint:NSMakePoint(minX + side * 0.005, lipY)' "$mac_host" >/dev/null
grep -F 'backgroundMode' "$mac_host" >/dev/null
grep -F 'NSVariableStatusItemLength' "$mac_host" >/dev/null
grep -F 'setTemplate:YES' "$mac_host" >/dev/null
grep -F 'windowShouldClose:' "$mac_host" >/dev/null
grep -F 'applicationShouldHandleReopen:' "$mac_host" >/dev/null

grep -F '__wizardry_host_set_background_mode' "$linux_host" >/dev/null
grep -F 'GtkStatusIcon *status_icon' "$linux_host" >/dev/null
grep -F 'window_delete_event_cb' "$linux_host" >/dev/null
grep -F 'apply_background_mode' "$linux_host" >/dev/null
grep -F 'tray_popup_menu_cb' "$linux_host" >/dev/null

printf '%s\n' "desktop background host contract tests passed"
