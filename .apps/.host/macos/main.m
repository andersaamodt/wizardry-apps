// Wizardry Desktop Host - macOS native WebView wrapper
// Minimal Objective-C implementation using Cocoa + WebKit
// Build: clang -O2 -fobjc-arc -fmodules main.m -o wizardry-host -framework Cocoa -framework WebKit

@import Cocoa;
@import WebKit;

@interface WizardryDragStripView : NSView
@end

@implementation WizardryDragStripView
- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    NSWindow *window = [self window];
    if (window) {
        [window performWindowDragWithEvent:event];
        return;
    }
    [super mouseDown:event];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler>
@property (strong) NSWindow *window;
@property (strong) WKWebView *webView;
@property (strong) NSString *appPath;
@property (strong) NSImage *appIconImage;
@property (assign) BOOL enableNativeViewMenu;
@end

@implementation AppDelegate

- (void)setupMainMenuWithAppName:(NSString *)appName {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    NSString *aboutTitle = [NSString stringWithFormat:@"About %@", appName];
    [appMenu addItemWithTitle:aboutTitle action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *hideItem = [appMenu addItemWithTitle:[NSString stringWithFormat:@"Hide %@", appName]
                                             action:@selector(hide:)
                                      keyEquivalent:@"h"];
    (void)hideItem;

    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others"
                                                action:@selector(hideOtherApplications:)
                                         keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagOption)];

    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSString *quitTitle = [NSString stringWithFormat:@"Quit %@", appName];
    [appMenu addItemWithTitle:quitTitle action:@selector(terminate:) keyEquivalent:@"q"];

    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    [windowMenuItem setSubmenu:windowMenu];

    if (self.enableNativeViewMenu) {
        NSMenuItem *viewMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        [mainMenu addItem:viewMenuItem];
        NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

        NSMenuItem *increase = [viewMenu addItemWithTitle:@"Increase Text Size"
                                                    action:@selector(nativeIncreaseTextSize:)
                                             keyEquivalent:@"+"];
        [increase setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

        NSMenuItem *decrease = [viewMenu addItemWithTitle:@"Decrease Text Size"
                                                    action:@selector(nativeDecreaseTextSize:)
                                             keyEquivalent:@"-"];
        [decrease setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

        NSMenuItem *reset = [viewMenu addItemWithTitle:@"Actual Size"
                                                 action:@selector(nativeResetTextSize:)
                                          keyEquivalent:@"0"];
        [reset setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

        [viewMenuItem setSubmenu:viewMenu];
    }

    [NSApp setWindowsMenu:windowMenu];
    [NSApp setMainMenu:mainMenu];
}

- (void)dispatchPrioritiesViewAction:(NSString *)actionName {
    if (!self.webView || !actionName) {
        return;
    }
    NSString *js = [NSString stringWithFormat:@"if (window && typeof window.prioritiesHostAction === 'function') { window.prioritiesHostAction('%@'); }", actionName];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)nativeIncreaseTextSize:(id)sender {
    (void)sender;
    [self dispatchPrioritiesViewAction:@"increase-text-size"];
}

- (void)nativeDecreaseTextSize:(id)sender {
    (void)sender;
    [self dispatchPrioritiesViewAction:@"decrease-text-size"];
}

- (void)nativeResetTextSize:(id)sender {
    (void)sender;
    [self dispatchPrioritiesViewAction:@"reset-text-size"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    // Get app directory from command line argument
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if (args.count < 2) {
        NSLog(@"Usage: %@ <app-directory>", args[0]);
        [NSApp terminate:nil];
        return;
    }
    
    self.appPath = args[1];
    NSString *indexPath = [self.appPath stringByAppendingPathComponent:@"index.html"];
    NSString *customIconPath = [self.appPath stringByAppendingPathComponent:@"assets/forge-icon.png"];
    
    // Check if index.html exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:indexPath]) {
        NSLog(@"Error: index.html not found at %@", indexPath);
        [NSApp terminate:nil];
        return;
    }
    
    // Get app name from directory
    NSString *appName = [[self.appPath lastPathComponent] 
                         stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    appName = [appName capitalizedString];
    NSString *appSlug = [[self.appPath lastPathComponent] lowercaseString];
    self.enableNativeViewMenu = [appSlug isEqualToString:@"priorities"];

    [self setupMainMenuWithAppName:appName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:customIconPath]) {
        NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:customIconPath];
        if (iconImage) {
            self.appIconImage = iconImage;
            [NSApp setApplicationIconImage:self.appIconImage];
        }
    }
    [NSApp activateIgnoringOtherApps:YES];
    
    // Create window
    NSRect frame = NSMakeRect(0, 0, 860, 620);
    NSSize minSize = NSMakeSize(860, 620);
    if (self.enableNativeViewMenu) {
        // Priorities starts narrow and should remain resizable down to a compact width.
        minSize = NSMakeSize(340, 260);
    }
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
                                   NSWindowStyleMaskClosable |
                                   NSWindowStyleMaskMiniaturizable |
                                   NSWindowStyleMaskResizable |
                                   NSWindowStyleMaskFullSizeContentView;
    
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:styleMask
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setMinSize:minSize];
    [self.window center];
    [self.window setTitle:[NSString stringWithFormat:@"Wizardry - %@", appName]];
    [self.window setTitlebarAppearsTransparent:YES];
    [self.window setTitleVisibility:NSWindowTitleHidden];
    [self.window setMovableByWindowBackground:YES];
    [self.window setBackgroundColor:[NSColor colorWithSRGBRed:0.93 green:0.95 blue:0.98 alpha:1.0]];
    if (@available(macOS 11.0, *)) {
        [self.window setToolbarStyle:NSWindowToolbarStyleUnified];
    }
    if (@available(macOS 11.0, *)) {
        [self.window setTitlebarSeparatorStyle:NSTitlebarSeparatorStyleNone];
    }
    [self.window makeKeyAndOrderFront:nil];
    
    // Create WebView with message handler
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *contentController = [[WKUserContentController alloc] init];
    [contentController addScriptMessageHandler:self name:@"wizardry"];
    config.userContentController = contentController;
    
    NSView *rootView = [[NSView alloc] initWithFrame:frame];
    [rootView setAutoresizesSubviews:YES];

    CGFloat dragStripHeight = 44.0;
    NSRect webFrame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
    self.webView = [[WKWebView alloc] initWithFrame:webFrame configuration:config];
    NSString *pageZoomEnv = [[[NSProcessInfo processInfo] environment] objectForKey:@"WIZARDRY_PAGE_ZOOM"];
    if (pageZoomEnv) {
        if (@available(macOS 11.0, *)) {
            double pageZoom = [pageZoomEnv doubleValue];
            if (pageZoom >= 0.50 && pageZoom <= 2.00) {
                self.webView.pageZoom = pageZoom;
            }
        }
    }
    [self.webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [rootView addSubview:self.webView];

    // Keep the drag area centered around the title region, leaving side controls clickable.
    CGFloat dragStripWidth = self.enableNativeViewMenu ? 140.0 : 320.0;
    if (dragStripWidth > frame.size.width) {
        dragStripWidth = frame.size.width;
    }
    NSRect stripFrame = NSMakeRect((frame.size.width - dragStripWidth) / 2.0,
                                   frame.size.height - dragStripHeight,
                                   dragStripWidth,
                                   dragStripHeight);
    NSView *dragStrip = [[WizardryDragStripView alloc] initWithFrame:stripFrame];
    [dragStrip setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin)];
    [dragStrip setWantsLayer:YES];
    dragStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
    [rootView addSubview:dragStrip];

    [self.window setContentView:rootView];
    
    // Load the app HTML
    NSURL *url = [NSURL fileURLWithPath:indexPath];
    // Forge renders app/workspace icons from absolute file paths (often outside the
    // current app folder), so read access must include the broader filesystem tree.
    NSURL *allowDir = [NSURL fileURLWithPath:@"/" isDirectory:YES];
    [self.webView loadFileURL:url allowingReadAccessToURL:allowDir];
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    // Expect: { command: ["spell-name", "arg1", "arg2"] }
    if (![message.body isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Invalid message format: not a dictionary");
        return;
    }
    
    NSDictionary *body = (NSDictionary *)message.body;
    NSString *messageId = body[@"id"];
    NSArray *command = body[@"command"];
    
    if (![command isKindOfClass:[NSArray class]] || command.count == 0) {
        [self sendError:messageId message:@"Command must be a non-empty array"];
        return;
    }
    
    // Execute the command
    [self executeCommand:command withId:messageId];
}

- (void)executeCommand:(NSArray *)command withId:(NSString *)messageId {
    NSArray *commandCopy = [command copy];
    NSString *messageIdCopy = [messageId copy];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *program = commandCopy[0];
        NSArray *args = (commandCopy.count > 1) ? [commandCopy subarrayWithRange:NSMakeRange(1, commandCopy.count - 1)] : @[];

        if ([program isEqualToString:@"__wizardry_host_resize"]) {
            CGFloat width = 1060.0;
            CGFloat height = 860.0;
            if (args.count >= 1) {
                width = MAX(420.0, [args[0] doubleValue]);
            }
            if (args.count >= 2) {
                height = MAX(520.0, [args[1] doubleValue]);
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.window) {
                    NSRect frame = [self.window frame];
                    NSRect newFrame = frame;
                    newFrame.origin.y = NSMaxY(frame) - height;
                    newFrame.size.width = width;
                    newFrame.size.height = height;
                    [self.window setFrame:newFrame display:YES animate:NO];
                }
                [self sendResult:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_center_x"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.window) {
                    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
                    if (screen) {
                        NSRect visible = [screen visibleFrame];
                        NSRect frame = [self.window frame];
                        frame.origin.x = NSMinX(visible) + (visible.size.width - frame.size.width) / 2.0;
                        if (frame.origin.x < NSMinX(visible)) {
                            frame.origin.x = NSMinX(visible);
                        }
                        [self.window setFrame:frame display:YES animate:NO];
                    }
                }
                [self sendResult:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_pin_top"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.window) {
                    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
                    if (screen) {
                        NSRect visible = [screen visibleFrame];
                        NSRect frame = [self.window frame];
                        frame.origin.y = NSMaxY(visible) - frame.size.height;
                        if (frame.origin.y < NSMinY(visible)) {
                            frame.origin.y = NSMinY(visible);
                        }
                        [self.window setFrame:frame display:YES animate:NO];
                    }
                }
                [self sendResult:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_snap_top_left"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.window) {
                    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
                    if (screen) {
                        NSRect visible = [screen visibleFrame];
                        NSRect frame = [self.window frame];
                        frame.origin.x = NSMinX(visible);
                        frame.origin.y = NSMaxY(visible) - frame.size.height;
                        if (frame.origin.y < NSMinY(visible)) {
                            frame.origin.y = NSMinY(visible);
                        }
                        [self.window setFrame:frame display:YES animate:NO];
                    }
                }
                [self sendResult:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_snap_top_right"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.window) {
                    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
                    if (screen) {
                        NSRect visible = [screen visibleFrame];
                        NSRect frame = [self.window frame];
                        frame.origin.x = NSMaxX(visible) - frame.size.width;
                        if (frame.origin.x < NSMinX(visible)) {
                            frame.origin.x = NSMinX(visible);
                        }
                        frame.origin.y = NSMaxY(visible) - frame.size.height;
                        if (frame.origin.y < NSMinY(visible)) {
                            frame.origin.y = NSMinY(visible);
                        }
                        [self.window setFrame:frame display:YES animate:NO];
                    }
                }
                [self sendResult:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_snap_state"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *snapState = @"none";
                if (self.window) {
                    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
                    if (screen) {
                        NSRect visible = [screen visibleFrame];
                        NSRect frame = [self.window frame];
                        CGFloat tol = 2.0;
                        BOOL topAligned = fabs(NSMaxY(frame) - NSMaxY(visible)) <= tol;
                        if (topAligned) {
                            if (fabs(NSMinX(frame) - NSMinX(visible)) <= tol) {
                                snapState = @"left";
                            } else if (fabs(NSMaxX(frame) - NSMaxX(visible)) <= tol) {
                                snapState = @"right";
                            } else if (fabs(NSMidX(frame) - NSMidX(visible)) <= tol) {
                                snapState = @"center";
                            }
                        }
                    }
                }
                [self sendResult:messageIdCopy stdout:snapState stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/env";

        // Build arguments: env program arg1 arg2 ...
        NSMutableArray *taskArgs = [NSMutableArray arrayWithObject:program];
        [taskArgs addObjectsFromArray:args];
        task.arguments = taskArgs;

        NSPipe *outPipe = [NSPipe pipe];
        NSPipe *errPipe = [NSPipe pipe];
        task.standardOutput = outPipe;
        task.standardError = errPipe;

        @try {
            [task launch];
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendError:messageIdCopy message:[NSString stringWithFormat:@"Failed to launch: %@", exception.reason]];
            });
            return;
        }

        [task waitUntilExit];

        NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];

        NSString *stdout = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
        NSString *stderr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @"";
        int exitCode = [task terminationStatus];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendResult:messageIdCopy stdout:stdout stderr:stderr exitCode:exitCode error:nil];
        });
    });
}

- (void)sendResult:(NSString *)messageId 
            stdout:(NSString *)stdout 
            stderr:(NSString *)stderr 
          exitCode:(int)exitCode 
             error:(NSString *)error
{
    // Escape strings for JSON
    NSString *escapedStdout = [self escapeJSON:stdout];
    NSString *escapedStderr = [self escapeJSON:stderr];
    NSString *escapedError = error ? [self escapeJSON:error] : @"null";
    
    NSString *js = [NSString stringWithFormat:
        @"if (window.__wizardry_callbacks && window.__wizardry_callbacks['%@']) { "
        @"  window.__wizardry_callbacks['%@']({ "
        @"    stdout: \"%@\", "
        @"    stderr: \"%@\", "
        @"    exit_code: %d, "
        @"    error: %@ "
        @"  }); "
        @"  delete window.__wizardry_callbacks['%@']; "
        @"}",
        messageId, messageId, escapedStdout, escapedStderr, exitCode, escapedError, messageId];
    
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"Error evaluating JavaScript: %@", error);
        }
    }];
}

- (void)sendError:(NSString *)messageId message:(NSString *)message {
    [self sendResult:messageId stdout:@"" stderr:@"" exitCode:-1 error:message];
}

- (NSString *)escapeJSON:(NSString *)string {
    string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    string = [string stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
    return string;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
