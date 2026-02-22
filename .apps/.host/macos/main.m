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
@property (strong) NSView *nativeBootSplashView;
@property (strong) NSColor *prioritiesBootBgColor;
@property (strong) NSColor *prioritiesBootTextColor;
@property (assign) BOOL enableNativeViewMenu;
@property (assign) BOOL prefersWideDragStrip;
@end

@implementation AppDelegate

- (NSString *)readConfigValueForKey:(NSString *)key fromFile:(NSString *)filePath {
    if (!key.length || !filePath.length) {
        return @"";
    }
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    if (!content.length || error) {
        return @"";
    }
    NSArray<NSString *> *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *prefix = [key stringByAppendingString:@"="];
    for (NSString *line in lines) {
        if ([line hasPrefix:prefix]) {
            return [line substringFromIndex:prefix.length];
        }
    }
    return @"";
}

- (NSColor *)parseCSSColorToken:(NSString *)token {
    NSString *raw = [[token ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!raw.length) {
        return nil;
    }

    if ([raw hasPrefix:@"#"]) {
        NSString *hex = [raw substringFromIndex:1];
        unsigned int value = 0;
        if (hex.length == 3) {
            NSString *expanded = [NSString stringWithFormat:@"%C%C%C%C%C%C",
                                  [hex characterAtIndex:0], [hex characterAtIndex:0],
                                  [hex characterAtIndex:1], [hex characterAtIndex:1],
                                  [hex characterAtIndex:2], [hex characterAtIndex:2]];
            hex = expanded;
        }
        if (hex.length == 6 && [[NSScanner scannerWithString:hex] scanHexInt:&value]) {
            CGFloat r = ((value >> 16) & 0xFF) / 255.0;
            CGFloat g = ((value >> 8) & 0xFF) / 255.0;
            CGFloat b = (value & 0xFF) / 255.0;
            return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1.0];
        }
        return nil;
    }

    NSRange rgbOpen = [raw rangeOfString:@"rgb("];
    if (rgbOpen.location == 0 && [raw hasSuffix:@")"]) {
        NSString *inside = [raw substringWithRange:NSMakeRange(4, raw.length - 5)];
        NSArray<NSString *> *parts = [inside componentsSeparatedByString:@","];
        if (parts.count == 3) {
            CGFloat r = [[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] doubleValue] / 255.0;
            CGFloat g = [[parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] doubleValue] / 255.0;
            CGFloat b = [[parts[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] doubleValue] / 255.0;
            return [NSColor colorWithSRGBRed:MAX(0.0, MIN(1.0, r))
                                       green:MAX(0.0, MIN(1.0, g))
                                        blue:MAX(0.0, MIN(1.0, b))
                                       alpha:1.0];
        }
    }

    return nil;
}

- (NSDictionary<NSString *, NSString *> *)readThemeVariablesFromFile:(NSString *)themeFile {
    if (!themeFile.length) {
        return @{};
    }
    NSError *error = nil;
    NSString *css = [NSString stringWithContentsOfFile:themeFile encoding:NSUTF8StringEncoding error:&error];
    if (!css.length || error) {
        return @{};
    }

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"--([a-z0-9_-]+)\\s*:\\s*([^;]+);" options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:css options:0 range:NSMakeRange(0, css.length)];
    NSMutableDictionary<NSString *, NSString *> *out = [NSMutableDictionary dictionaryWithCapacity:matches.count];
    for (NSTextCheckingResult *match in matches) {
        if (match.numberOfRanges < 3) {
            continue;
        }
        NSRange keyRange = [match rangeAtIndex:1];
        NSRange valueRange = [match rangeAtIndex:2];
        if (keyRange.location == NSNotFound || valueRange.location == NSNotFound) {
            continue;
        }
        NSString *key = [[css substringWithRange:keyRange] lowercaseString];
        NSString *value = [[css substringWithRange:valueRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (key.length && value.length) {
            out[key] = value;
        }
    }
    return out;
}

- (void)loadPrioritiesBootPalette {
    NSString *xdgConfig = [[[NSProcessInfo processInfo] environment] objectForKey:@"XDG_CONFIG_HOME"];
    NSString *configDir = xdgConfig.length
        ? [xdgConfig stringByAppendingPathComponent:@"wizardry-apps/priorities"]
        : [NSHomeDirectory() stringByAppendingPathComponent:@".config/wizardry-apps/priorities"];
    NSString *configFile = [configDir stringByAppendingPathComponent:@"config"];

    NSString *theme = [[self readConfigValueForKey:@"theme" fromFile:configFile] lowercaseString];
    if (!theme.length) {
        theme = @"psionic";
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789_-"];
    if ([[theme stringByTrimmingCharactersInSet:allowed] length] > 0) {
        theme = @"psionic";
    }

    NSString *themeFile = [[self.appPath stringByAppendingPathComponent:@"themes"] stringByAppendingPathComponent:[theme stringByAppendingString:@".css"]];
    NSDictionary<NSString *, NSString *> *vars = [self readThemeVariablesFromFile:themeFile];
    NSColor *bg = [self parseCSSColorToken:vars[@"bg"]];
    NSColor *text = [self parseCSSColorToken:vars[@"text"]];
    NSColor *muted = [self parseCSSColorToken:vars[@"light-text"]];

    self.prioritiesBootBgColor = bg ?: [NSColor whiteColor];
    self.prioritiesBootTextColor = muted ?: text ?: [NSColor colorWithSRGBRed:0.42 green:0.45 blue:0.50 alpha:1.0];
}

- (void)showNativeBootSplashInView:(NSView *)rootView {
    if (!rootView || self.nativeBootSplashView) {
        return;
    }

    NSView *overlay = [[NSView alloc] initWithFrame:rootView.bounds];
    overlay.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
    overlay.wantsLayer = YES;
    NSColor *bg = self.prioritiesBootBgColor ?: [NSColor whiteColor];
    overlay.layer.backgroundColor = [bg CGColor];

    NSImage *logoImage = self.appIconImage;
    NSImageView *logoView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    logoView.imageAlignment = NSImageAlignCenter;
    logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.wantsLayer = YES;
    logoView.layer.cornerRadius = 4.0;
    if (logoImage) {
        logoView.image = logoImage;
    } else {
        logoView.image = nil;
    }

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.alignment = NSLayoutAttributeCenterY;
    stack.spacing = 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:logoView];

    [overlay addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [logoView.widthAnchor constraintEqualToConstant:192.0],
        [logoView.heightAnchor constraintEqualToConstant:192.0],
        [stack.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor]
    ]];

    [rootView addSubview:overlay];
    self.nativeBootSplashView = overlay;
}

- (void)hideNativeBootSplash {
    if (!self.nativeBootSplashView) {
        return;
    }
    NSView *overlay = self.nativeBootSplashView;
    self.nativeBootSplashView = nil;
    [overlay removeFromSuperview];
}

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
    (void)note;
    // Ensure command-line launched hosts behave like regular foreground apps.
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

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
    NSString *parentIconPath = [[[self.appPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"assets"] stringByAppendingPathComponent:@"forge-icon.png"];
    
    // Check if index.html exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:indexPath]) {
        NSLog(@"Error: index.html not found at %@", indexPath);
        [NSApp terminate:nil];
        return;
    }
    
    // Get app name from directory
    NSString *appComponent = [self.appPath lastPathComponent];
    if ([[appComponent lowercaseString] isEqualToString:@"app"]) {
        NSString *parent = [[self.appPath stringByDeletingLastPathComponent] lastPathComponent];
        if (parent.length > 0) {
            appComponent = parent;
        }
    }
    NSString *appName = [appComponent stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    appName = [appName capitalizedString];
    NSString *appSlug = [appComponent lowercaseString];
    BOOL prefersNarrowTallLayout = [appSlug isEqualToString:@"owl"];
    BOOL prefersSideDragZones = [appSlug isEqualToString:@"owl"];
    self.enableNativeViewMenu = [appSlug isEqualToString:@"priorities"];
    self.prefersWideDragStrip = [appSlug isEqualToString:@"virtual-redditor"];
    if (self.enableNativeViewMenu) {
        [self loadPrioritiesBootPalette];
    }

    [self setupMainMenuWithAppName:appName];
    NSString *resolvedIconPath = customIconPath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedIconPath] &&
        [[NSFileManager defaultManager] fileExistsAtPath:parentIconPath]) {
        resolvedIconPath = parentIconPath;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:resolvedIconPath]) {
        NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:resolvedIconPath];
        if (iconImage) {
            self.appIconImage = iconImage;
            [NSApp setApplicationIconImage:self.appIconImage];
        }
    }
    [NSApp unhide:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    // Create window
    NSRect frame = NSMakeRect(0, 0, 860, 620);
    NSSize minSize = NSMakeSize(860, 620);
    if (self.enableNativeViewMenu) {
        // Priorities starts narrow and should remain resizable down to a compact width.
        frame = NSMakeRect(0, 0, 420, 640);
        minSize = NSMakeSize(340, 260);
        NSScreen *screen = [NSScreen mainScreen];
        if (screen) {
            NSRect visible = [screen visibleFrame];
            frame.origin.x = NSMinX(visible) + floor((visible.size.width - frame.size.width) / 2.0);
            frame.origin.y = NSMaxY(visible) - frame.size.height;
        }
    } else if (prefersNarrowTallLayout) {
        minSize = NSMakeSize(360, 420);
        NSScreen *screen = [NSScreen mainScreen];
        if (screen) {
            NSRect visible = [screen visibleFrame];
            CGFloat width = floor(visible.size.width / 3.0);
            if (width < 420.0) {
                width = 420.0;
            } else if (width > 740.0) {
                width = 740.0;
            }
            frame.size.width = width;
            frame.size.height = visible.size.height;
            frame.origin.x = NSMinX(visible) + floor((visible.size.width - width) / 2.0);
            frame.origin.y = NSMinY(visible);
        }
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
    if (!prefersNarrowTallLayout && !self.enableNativeViewMenu) {
        [self.window center];
    }
    [self.window setTitle:[NSString stringWithFormat:@"Wizardry - %@", appName]];
    [self.window setTitlebarAppearsTransparent:YES];
    [self.window setTitleVisibility:NSWindowTitleHidden];
    // Owl uses explicit side drag zones so tab clicks/drags never move the window.
    [self.window setMovableByWindowBackground:!prefersSideDragZones];
    if (self.enableNativeViewMenu && self.prioritiesBootBgColor) {
        [self.window setBackgroundColor:self.prioritiesBootBgColor];
    } else {
        [self.window setBackgroundColor:[NSColor colorWithSRGBRed:0.93 green:0.95 blue:0.98 alpha:1.0]];
    }
    if (@available(macOS 11.0, *)) {
        [self.window setToolbarStyle:NSWindowToolbarStyleUnified];
    }
    if (@available(macOS 11.0, *)) {
        [self.window setTitlebarSeparatorStyle:NSTitlebarSeparatorStyleNone];
    }
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
    @try {
        // Avoid white intermediate paint by letting the themed host window color
        // show through until page styles apply.
        [self.webView setValue:@NO forKey:@"drawsBackground"];
    } @catch (NSException *exception) {
        (void)exception;
    }
    if (@available(macOS 11.0, *)) {
        self.webView.underPageBackgroundColor = [NSColor clearColor];
    }
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

    // Keep interactive controls clickable while exposing explicit drag-only areas.
    if (prefersSideDragZones) {
        // 1) Broad top strip: draggable above controls across the whole window.
        CGFloat topStripHeight = 24.0;
        NSRect topStripFrame = NSMakeRect(0.0,
                                          frame.size.height - topStripHeight,
                                          frame.size.width,
                                          topStripHeight);
        NSView *topStrip = [[WizardryDragStripView alloc] initWithFrame:topStripFrame];
        [topStrip setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [topStrip setWantsLayer:YES];
        topStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:topStrip];

        // 2) Left header gutter: draggable to the left of tabs.
        CGFloat headerBandHeight = dragStripHeight;
        CGFloat leftGutterWidth = 84.0;
        NSRect leftHeaderGutterFrame = NSMakeRect(0.0,
                                                  frame.size.height - headerBandHeight,
                                                  leftGutterWidth,
                                                  headerBandHeight);
        NSView *leftHeaderGutter = [[WizardryDragStripView alloc] initWithFrame:leftHeaderGutterFrame];
        [leftHeaderGutter setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
        [leftHeaderGutter setWantsLayer:YES];
        leftHeaderGutter.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:leftHeaderGutter];

        // 3) Header center gap: draggable between tabs and right-side controls.
        CGFloat tabsReservedWidth = 350.0;
        CGFloat rightControlsReservedWidth = 190.0;
        CGFloat centerGapX = leftGutterWidth + tabsReservedWidth;
        CGFloat centerGapWidth = frame.size.width - centerGapX - rightControlsReservedWidth;
        if (centerGapWidth < 72.0) {
            centerGapWidth = 72.0;
        }
        if (centerGapX + centerGapWidth > frame.size.width) {
            centerGapWidth = MAX(0.0, frame.size.width - centerGapX);
        }
        NSRect centerGapFrame = NSMakeRect(centerGapX,
                                           frame.size.height - headerBandHeight,
                                           centerGapWidth,
                                           headerBandHeight);
        NSView *centerGapStrip = [[WizardryDragStripView alloc] initWithFrame:centerGapFrame];
        [centerGapStrip setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [centerGapStrip setWantsLayer:YES];
        centerGapStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:centerGapStrip];
    } else {
        CGFloat stripX = 0.0;
        CGFloat dragStripWidth = self.enableNativeViewMenu ? 140.0 : 320.0;
        NSUInteger stripMask = (NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin);
        if (self.prefersWideDragStrip) {
            CGFloat leftReserved = 300.0;
            CGFloat rightReserved = 150.0;
            dragStripWidth = frame.size.width - leftReserved - rightReserved;
            if (dragStripWidth < 220.0) {
                dragStripWidth = frame.size.width * 0.36;
            }
            if (dragStripWidth > frame.size.width) {
                dragStripWidth = frame.size.width;
            }
            stripX = leftReserved;
            if (stripX + dragStripWidth > frame.size.width) {
                stripX = frame.size.width - dragStripWidth;
            }
            if (stripX < 0.0) {
                stripX = 0.0;
            }
            stripMask = (NSViewWidthSizable | NSViewMinYMargin);
        } else {
            if (dragStripWidth > frame.size.width) {
                dragStripWidth = frame.size.width;
            }
            stripX = (frame.size.width - dragStripWidth) / 2.0;
        }
        NSRect stripFrame = NSMakeRect(stripX,
                                       frame.size.height - dragStripHeight,
                                       dragStripWidth,
                                       dragStripHeight);
        NSView *dragStrip = [[WizardryDragStripView alloc] initWithFrame:stripFrame];
        [dragStrip setAutoresizingMask:stripMask];
        [dragStrip setWantsLayer:YES];
        dragStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:dragStrip];
    }

    if (self.enableNativeViewMenu) {
        [self showNativeBootSplashInView:rootView];
    }

    [self.window setContentView:rootView];

    [self.window makeKeyAndOrderFront:nil];
    [self.window orderFrontRegardless];
    // Re-activate after the window exists so workspace launches behave like
    // regular desktop apps (not hidden/background-only processes).
    NSRunningApplication *currentApp = [NSRunningApplication currentApplication];
    [currentApp activateWithOptions:(NSApplicationActivateIgnoringOtherApps | NSApplicationActivateAllWindows)];
    [NSApp unhide:nil];
    [NSApp activateIgnoringOtherApps:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.window makeMainWindow];
        [self.window makeKeyAndOrderFront:nil];
        [self.window orderFrontRegardless];
        [NSApp unhide:nil];
        [NSApp activateIgnoringOtherApps:YES];
    });
    
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

        if ([program isEqualToString:@"__wizardry_host_boot_ready"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideNativeBootSplash];
                [self sendResult:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
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
