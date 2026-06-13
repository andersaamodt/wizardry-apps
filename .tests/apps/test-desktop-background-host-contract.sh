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
grep -F 'isHeadquartersApp' "$mac_host" >/dev/null
grep -F '[slug isEqualToString:@"artificer-native"]' "$mac_host" >/dev/null
grep -F 'Bellheim is running in background' "$mac_host" >/dev/null
grep -F 'Headquarters is running in background' "$mac_host" >/dev/null
grep -F 'clapperRadius' "$mac_host" >/dev/null
grep -F 'lineToPoint:NSMakePoint(minX + side * 0.005, lipY)' "$mac_host" >/dev/null
grep -F 'desktop_background_mode' "$mac_host" >/dev/null
grep -F 'desktop_menu_bar_icon' "$mac_host" >/dev/null
grep -F 'syncHeadquartersBackgroundModeFromConfig' "$mac_host" >/dev/null
grep -F 'Hide Headquarters' "$mac_host" >/dev/null
grep -F 'Open Headquarters' "$mac_host" >/dev/null
grep -F 'backgroundMode' "$mac_host" >/dev/null
grep -F 'syncBellheimBackgroundModeFromConfig' "$mac_host" >/dev/null
grep -F 'self.appSlug = @"artificer";' "$mac_host" >/dev/null
grep -F 'NSWorkspaceWillPowerOffNotification' "$mac_host" >/dev/null
grep -F 'isSystemTerminationRequest' "$mac_host" >/dev/null
grep -F 'kAEQuitReason' "$mac_host" >/dev/null
grep -F 'kAEShutDown' "$mac_host" >/dev/null
grep -F 'kAERestart' "$mac_host" >/dev/null
grep -F 'kAEReallyLogOut' "$mac_host" >/dev/null
grep -F 'if (self.explicitQuitRequested || [self isSystemTerminationRequest]) {' "$mac_host" >/dev/null
grep -F 'quitFromAppMenu:' "$mac_host" >/dev/null
grep -F 'action:@selector(quitFromAppMenu:)' "$mac_host" >/dev/null
grep -F '&& ![self isBellheimApp] && ![self isHeadquartersApp]) {' "$mac_host" >/dev/null
grep -F '? NSApplicationActivationPolicyAccessory' "$mac_host" >/dev/null
if grep -F 'self.explicitQuitRequested || [self isSystemTerminationRequest] || [self isBellheimApp]' "$mac_host" >/dev/null; then
  printf '%s\n' "Bellheim Dock Quit must respect background mode" >&2
  exit 1
fi
awk '
  /- \(void\)quitFromAppMenu:/ { in_quit=1; next }
  in_quit && /^- \(/ { in_quit=0 }
  in_quit && /\[self syncBellheimBackgroundModeFromConfig\];/ { sync=1 }
  in_quit && /self.keepRunningInBackground \|\| self.showStatusItem/ { background=1 }
  in_quit && /\[self.window orderOut:nil\];/ { hides=1 }
  in_quit && /self.explicitQuitRequested = YES/ { explicit=1 }
  END { exit (sync && background && hides && !explicit) ? 0 : 1 }
' "$mac_host"
grep -F '[self syncBellheimBackgroundModeFromConfig];' "$mac_host" >/dev/null
grep -F 'NSVariableStatusItemLength' "$mac_host" >/dev/null
grep -F 'setTemplate:YES' "$mac_host" >/dev/null
grep -F 'BOOL relayStillRunning = [normalized isEqualToString:@"running"];' "$mac_host" >/dev/null
grep -F 'if (relayStillRunning) {' "$mac_host" >/dev/null
grep -F 'windowShouldClose:' "$mac_host" >/dev/null
grep -F 'applicationShouldHandleReopen:' "$mac_host" >/dev/null
grep -F '[self.window deminiaturize:nil];' "$mac_host" >/dev/null
grep -F '[self.window isMiniaturized]' "$mac_host" >/dev/null
grep -F 'BOOL hiddenStartMode = [self hostStartHiddenModeEnabled] || [self hostArgumentsRequestStartHidden:args];' "$mac_host" >/dev/null
grep -F 'self.hostHiddenStartMode = hiddenStartMode;' "$mac_host" >/dev/null
grep -F '[NSApp setActivationPolicy:(hiddenStartMode ? NSApplicationActivationPolicyAccessory : NSApplicationActivationPolicyRegular)];' "$mac_host" >/dev/null
grep -F 'self.hostHiddenStartMode = NO;' "$mac_host" >/dev/null
grep -F 'safelyShowMainWindowActivatingApp:' "$mac_host" >/dev/null
grep -F 'skipped unsafe window activation' "$mac_host" >/dev/null
if grep -F 'runtimeCommandInFlight' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not serialize runtime commands behind a launch-pressure gate" >&2
  exit 1
fi
if grep -F 'runtimeCommandBackoffUntil' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not keep launch-pressure backoff state" >&2
  exit 1
fi
if grep -F 'acquireRuntimeCommandSlotWithError' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not defer runtime commands behind a launch-pressure check" >&2
  exit 1
fi
if grep -F 'markRuntimeCommandLaunchPressure' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not synthesize launch-pressure failures" >&2
  exit 1
fi
if grep -F 'launch assessment is under pressure' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not report launch-pressure defer messages" >&2
  exit 1
fi
if grep -F 'deferred to avoid macOS launch-assessment pressure' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not enforce launch-pressure startup timeouts" >&2
  exit 1
fi
if grep -F 'dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC))' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not impose the removed launch-pressure startup timeout" >&2
  exit 1
fi
if grep -F '[self.window makeMainWindow];' "$mac_host" >/dev/null; then
  printf '%s\n' "macOS host must not force makeMainWindow during startup activation" >&2
  exit 1
fi
grep -F '[self.window orderOut:nil];' "$mac_host" >/dev/null
grep -F 'self.hostHiddenStartMode || (keepBackground && !hasVisibleMainWindow)' "$mac_host" >/dev/null
awk '
  /if \(self.hostHiddenStartMode\) \{/ { in_hidden=1; next }
  in_hidden && /^    \}/ { in_hidden=0 }
  in_hidden && /self.keepRunningInBackground = YES;/ { background=1 }
  in_hidden && /self.showStatusItem = YES;/ { status_item=1 }
  END { exit (background && status_item) ? 0 : 1 }
' "$mac_host"
awk '
  /- \(void\)applyBackgroundModeEnabled:/ { in_apply=1; next }
  in_apply && /^- \(/ { in_apply=0 }
  in_apply && /if \(self.hostHiddenStartMode\) \{/ { hidden_guard=1 }
  in_apply && /self.keepRunningInBackground = YES;/ { background=1 }
  in_apply && /self.showStatusItem = YES;/ { status_item=1 }
  END { exit (hidden_guard && background && status_item) ? 0 : 1 }
' "$mac_host"
if grep -F 'offscreenFrame.origin.x = -20000.0' "$mac_host" >/dev/null; then
  printf '%s\n' "hidden startup must not order an offscreen main window front" >&2
  exit 1
fi
grep -F 'WizardryHostShowWindowNotification' "$mac_host" >/dev/null
grep -F 'handleDistributedShowWindowRequest:' "$mac_host" >/dev/null
awk '
  /- \(void\)handleDistributedShowWindowRequest:/ { in_handler=1; next }
  in_handler && /^- \(/ { in_handler=0 }
  in_handler && /isStonrApp/ { bad=1 }
  END { exit bad ? 1 : 0 }
' "$mac_host"
awk '
  /- \(void\)syncStonrActivationPolicy/ { in_sync=1; next }
  in_sync && /^- \(/ { in_sync=0 }
  in_sync && /isBellheimApp/ { bellheim=1 }
  in_sync && /isHeadquartersApp/ { headquarters=1 }
  in_sync && /self.hostHiddenStartMode/ { hidden=1 }
  in_sync && /NSApplicationActivationPolicyAccessory/ { accessory=1 }
  END { exit (bellheim && headquarters && hidden && accessory) ? 0 : 1 }
' "$mac_host"

grep -F '__wizardry_host_set_background_mode' "$linux_host" >/dev/null
grep -F 'GtkStatusIcon *status_icon' "$linux_host" >/dev/null
grep -F 'window_delete_event_cb' "$linux_host" >/dev/null
grep -F 'apply_background_mode' "$linux_host" >/dev/null
grep -F 'tray_popup_menu_cb' "$linux_host" >/dev/null

printf '%s\n' "desktop background host contract tests passed"
