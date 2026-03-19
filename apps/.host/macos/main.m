// Wizardry Desktop Host - macOS native WebView wrapper
// Minimal Objective-C implementation using Cocoa + WebKit
// Build: clang -O2 -fobjc-arc -fmodules main.m -o wizardry-host -framework Cocoa -framework WebKit -framework Carbon

@import Cocoa;
@import WebKit;
@import Carbon;

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

@class AppDelegate;

@interface WizardryForgeWebView : WKWebView <NSDraggingDestination>
@property (weak) AppDelegate *appDelegate;
@property (assign) BOOL nativeFileDragActive;
@property (copy) NSString *nativeFileDragTarget;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler, NSWindowDelegate, WKUIDelegate>
@property (strong) NSWindow *window;
@property (strong) WKWebView *webView;
@property (strong) NSMutableArray<NSWindow *> *auxWindows;
@property (strong) NSView *hostRootView;
@property (strong) NSString *appPath;
@property (strong) NSImage *appIconImage;
@property (strong) NSView *nativeBootSplashView;
@property (strong) NSColor *prioritiesBootBgColor;
@property (strong) NSColor *prioritiesBootTextColor;
@property (assign) BOOL enableNativeViewMenu;
@property (assign) BOOL enableNativeBootSplash;
@property (assign) BOOL enableForgeAppMenu;
@property (assign) BOOL prefersWideDragStrip;
@property (assign) BOOL enableHeaderDragHoles;
@property (assign) BOOL prefersLeftOnlyHeaderDragArea;
@property (assign) CGFloat bootSplashLogoSize;
@property (strong) NSView *prioritiesTopDragStrip;
@property (strong) NSView *prioritiesLeftHeaderDragStrip;
@property (strong) NSView *prioritiesRightHeaderDragStrip;
@property (assign) CGFloat prioritiesTitleHoleLeftWidth;
@property (assign) CGFloat prioritiesTitleHoleRightWidth;
@property (assign) CGFloat prioritiesRightControlsReservedWidth;
@property (assign) CGFloat forgeWorkspaceDropZoneLeft;
@property (assign) CGFloat forgeWorkspaceDropZoneTop;
@property (assign) CGFloat forgeWorkspaceDropZoneRight;
@property (assign) CGFloat forgeWorkspaceDropZoneBottom;
@property (assign) BOOL forgeWorkspaceDropZoneActive;
@property (assign) CGFloat forgeIconDropZoneLeft;
@property (assign) CGFloat forgeIconDropZoneTop;
@property (assign) CGFloat forgeIconDropZoneRight;
@property (assign) CGFloat forgeIconDropZoneBottom;
@property (assign) BOOL forgeIconDropZoneActive;
@property (strong) NSString *forgeIconDropRootHint;
@property (strong) NSString *forgeIconDropItemKey;
@property (strong) NSString *forgeIconDropTargetKind;
@property (strong) NSString *forgeIconDropTargetValue;
@property (strong) NSString *forgeIconDropShapeMode;
@property (assign) BOOL forgeIconDropBusy;
@property (assign) EventHotKeyRef favoriteTrackHotKeyRef;
@property (assign) EventHandlerRef favoriteTrackHotKeyHandlerRef;
@property (assign) BOOL keepRunningInBackground;
@property (assign) BOOL showStatusItem;
@property (strong) NSStatusItem *statusItem;
- (void)emitGlobalFavoriteTrackHotkey;
- (NSDictionary<NSString *, NSString *> *)resolvedCommandEnvironment;
- (NSString *)normalizedCommandPath;
- (NSString *)resolvedWizardryAppsRoot;
- (NSString *)resolvedSharedThemeFileForTheme:(NSString *)themeName;
- (NSArray<NSString *> *)filePathsFromDraggingInfo:(id<NSDraggingInfo>)draggingInfo;
- (BOOL)draggingInfoContainsImagePayload:(id<NSDraggingInfo>)draggingInfo;
- (NSString *)stagedImagePathFromDraggingInfo:(id<NSDraggingInfo>)draggingInfo;
- (NSString *)forgeDropTargetAtDomX:(CGFloat)domX domY:(CGFloat)domY paths:(NSArray<NSString *> *)paths hasImagePayload:(BOOL)hasImagePayload;
- (void)dispatchForgeFileDragPhase:(NSString *)phase target:(NSString *)target domX:(CGFloat)domX domY:(CGFloat)domY paths:(NSArray<NSString *> *)paths hasImagePayload:(BOOL)hasImagePayload;
- (void)dispatchForgeHostCallbackNamed:(NSString *)functionName payload:(NSDictionary *)payload toWebView:(WKWebView *)targetWebView;
- (NSArray<NSString *> *)forgeIconDropCommandArgumentsForPath:(NSString *)imagePath;
- (void)runForgeIconDropForPath:(NSString *)imagePath fromWebView:(WKWebView *)sourceWebView;
- (WKWebView *)createAuxWindowWithConfiguration:(WKWebViewConfiguration *)configuration
                                         request:(NSURLRequest *)request
                                     windowTitle:(NSString *)windowTitle
                                          width:(CGFloat)width
                                         height:(CGFloat)height;
- (void)applyBackgroundModeEnabled:(BOOL)enabled showStatusItem:(BOOL)showStatusItem;
- (void)updateStatusItemVisibility;
- (NSImage *)renderedStatusItemImage;
- (void)showMainWindow;
- (void)toggleMainWindowFromStatusItem:(id)sender;
- (void)quitFromStatusItem:(id)sender;
@end

static OSStatus WizardryHandleGlobalHotKey(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    (void)nextHandler;
    if (!userData) return noErr;
    AppDelegate *delegate = (__bridge AppDelegate *)userData;
    EventHotKeyID hotKeyID;
    OSStatus status = GetEventParameter(event,
                                        kEventParamDirectObject,
                                        typeEventHotKeyID,
                                        NULL,
                                        sizeof(hotKeyID),
                                        NULL,
                                        &hotKeyID);
    if (status != noErr) return status;
    if (hotKeyID.signature == 'WSHK' && hotKeyID.id == 1) {
        [delegate emitGlobalFavoriteTrackHotkey];
    }
    return noErr;
}

@implementation WizardryForgeWebView

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSArray<NSString *> *paths = [self.appDelegate filePathsFromDraggingInfo:sender];
    BOOL hasImagePayload = [self.appDelegate draggingInfoContainsImagePayload:sender];
    NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    CGFloat domX = localPoint.x;
    CGFloat domY = self.bounds.size.height - localPoint.y;
    NSString *target = [self.appDelegate forgeDropTargetAtDomX:domX domY:domY paths:paths hasImagePayload:hasImagePayload];
    if (target.length) {
        self.nativeFileDragActive = YES;
        self.nativeFileDragTarget = target;
        [self.appDelegate dispatchForgeFileDragPhase:@"enter" target:target domX:domX domY:domY paths:paths hasImagePayload:hasImagePayload];
        return NSDragOperationCopy;
    }
    return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    NSArray<NSString *> *paths = [self.appDelegate filePathsFromDraggingInfo:sender];
    BOOL hasImagePayload = [self.appDelegate draggingInfoContainsImagePayload:sender];
    NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    CGFloat domX = localPoint.x;
    CGFloat domY = self.bounds.size.height - localPoint.y;
    NSString *target = [self.appDelegate forgeDropTargetAtDomX:domX domY:domY paths:paths hasImagePayload:hasImagePayload];
    if (target.length) {
        NSString *phase = self.nativeFileDragActive ? @"update" : @"enter";
        self.nativeFileDragActive = YES;
        self.nativeFileDragTarget = target;
        [self.appDelegate dispatchForgeFileDragPhase:phase target:target domX:domX domY:domY paths:paths hasImagePayload:hasImagePayload];
        return NSDragOperationCopy;
    }
    if (self.nativeFileDragActive) {
        self.nativeFileDragActive = NO;
        [self.appDelegate dispatchForgeFileDragPhase:@"leave" target:(self.nativeFileDragTarget ?: @"") domX:domX domY:domY paths:@[] hasImagePayload:NO];
        self.nativeFileDragTarget = nil;
    }
    return [super draggingUpdated:sender];
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    if (self.nativeFileDragActive) {
        NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
        CGFloat domX = localPoint.x;
        CGFloat domY = self.bounds.size.height - localPoint.y;
        self.nativeFileDragActive = NO;
        [self.appDelegate dispatchForgeFileDragPhase:@"leave" target:(self.nativeFileDragTarget ?: @"") domX:domX domY:domY paths:@[] hasImagePayload:NO];
        self.nativeFileDragTarget = nil;
    }
    [super draggingExited:sender];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSArray<NSString *> *paths = [self.appDelegate filePathsFromDraggingInfo:sender];
    BOOL hasImagePayload = [self.appDelegate draggingInfoContainsImagePayload:sender];
    NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    CGFloat domX = localPoint.x;
    CGFloat domY = self.bounds.size.height - localPoint.y;
    NSString *target = [self.appDelegate forgeDropTargetAtDomX:domX domY:domY paths:paths hasImagePayload:hasImagePayload];
    if (target.length) {
        if ([target isEqualToString:@"icon"] && !paths.count && hasImagePayload) {
            NSString *stagedImagePath = [self.appDelegate stagedImagePathFromDraggingInfo:sender];
            if (stagedImagePath.length) {
                paths = @[stagedImagePath];
            }
        }
        self.nativeFileDragActive = NO;
        [self.appDelegate dispatchForgeFileDragPhase:@"drop" target:target domX:domX domY:domY paths:paths hasImagePayload:hasImagePayload];
        self.nativeFileDragTarget = nil;
        if ([target isEqualToString:@"icon"]) {
            NSString *imagePath = @"";
            for (NSString *path in paths) {
                BOOL isDirectory = NO;
                if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory) {
                    imagePath = path;
                    break;
                }
            }
            [self.appDelegate runForgeIconDropForPath:imagePath fromWebView:self];
        }
        return YES;
    }
    if (self.nativeFileDragActive) {
        self.nativeFileDragActive = NO;
        [self.appDelegate dispatchForgeFileDragPhase:@"leave" target:(self.nativeFileDragTarget ?: @"") domX:domX domY:domY paths:@[] hasImagePayload:NO];
        self.nativeFileDragTarget = nil;
    }
    return [super performDragOperation:sender];
}

@end

@implementation AppDelegate

- (NSString *)desktopBridgeBootstrapSource {
    return @"(function () {"
           @"  window.__wizardry_callbacks = window.__wizardry_callbacks || {};"
           @"  function nextId() { return Math.random().toString(36).slice(2); }"
           @"  function post(message) {"
           @"    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wizardry) {"
           @"      window.webkit.messageHandlers.wizardry.postMessage(message);"
           @"      return true;"
           @"    }"
           @"    if (window.WizardryBridge && typeof window.WizardryBridge.postMessage === 'function') {"
           @"      window.WizardryBridge.postMessage(JSON.stringify(message));"
           @"      return true;"
           @"    }"
           @"    return false;"
           @"  }"
           @"  function execCommand(argv) {"
           @"    if (!Array.isArray(argv)) {"
           @"      return Promise.reject(new Error('argv must be an array'));"
           @"    }"
           @"    return new Promise(function (resolve) {"
           @"      var id = nextId();"
           @"      window.__wizardry_callbacks[id] = function (payload) {"
           @"        resolve(payload || { stdout: '', stderr: '', exit_code: 0, error: null });"
           @"      };"
           @"      if (!post({ id: id, command: argv })) {"
           @"        setTimeout(function () {"
           @"          if (window.__wizardry_callbacks[id]) {"
           @"            window.__wizardry_callbacks[id]({ stdout: '', stderr: 'native bridge unavailable', exit_code: 1, error: null });"
           @"            delete window.__wizardry_callbacks[id];"
           @"          }"
           @"        }, 0);"
           @"      }"
           @"    });"
           @"  }"
           @"  function rpcBridge(method, payload) {"
           @"    if (method !== 'bridge.exec') {"
           @"      return Promise.reject(new Error('unsupported rpc method: ' + String(method || '')));"
           @"    }"
           @"    var argv = payload;"
           @"    if (payload && typeof payload === 'object' && Array.isArray(payload.argv)) {"
           @"      argv = payload.argv;"
           @"    }"
           @"    return execCommand(argv);"
           @"  }"
           @"  window.wizardry = window.wizardry || {};"
           @"  if (typeof window.wizardry.exec !== 'function') {"
           @"    window.wizardry.exec = execCommand;"
           @"  }"
           @"  if (typeof window.wizardry.rpc !== 'function') {"
           @"    window.wizardry.rpc = rpcBridge;"
           @"  }"
           @"})();";
}

- (void)webView:(WKWebView *)webView
runJavaScriptAlertPanelWithMessage:(NSString *)message
initiatedByFrame:(WKFrameInfo *)frame
completionHandler:(void (^)(void))completionHandler {
    (void)webView;
    (void)frame;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert setMessageText:@"Priorities"];
        [alert setInformativeText:(message.length ? message : @" ")];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:^(__unused NSModalResponse returnCode) {
            if (completionHandler) {
                completionHandler();
            }
        }];
    });
}

- (void)webView:(WKWebView *)webView
runJavaScriptConfirmPanelWithMessage:(NSString *)message
initiatedByFrame:(WKFrameInfo *)frame
completionHandler:(void (^)(BOOL result))completionHandler {
    (void)webView;
    (void)frame;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert setMessageText:@"Confirm"];
        [alert setInformativeText:(message.length ? message : @"Are you sure?")];
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            BOOL confirmed = (returnCode == NSAlertFirstButtonReturn);
            if (completionHandler) {
                completionHandler(confirmed);
            }
        }];
    });
}

- (WKWebView *)createAuxWindowWithConfiguration:(WKWebViewConfiguration *)configuration
                                         request:(NSURLRequest *)request
                                     windowTitle:(NSString *)windowTitle
                                           width:(CGFloat)width
                                          height:(CGFloat)height
{
    WKWebViewConfiguration *resolvedConfiguration = configuration ?: [[WKWebViewConfiguration alloc] init];
    if (resolvedConfiguration.preferences) {
        resolvedConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    }
    WKUserContentController *contentController = resolvedConfiguration.userContentController;
    if (!contentController) {
        contentController = [[WKUserContentController alloc] init];
        resolvedConfiguration.userContentController = contentController;
    }
    @try {
        [contentController addScriptMessageHandler:self name:@"wizardry"];
    } @catch (NSException *exception) {
        (void)exception;
    }
    WKUserScript *bridgeBootstrap =
        [[WKUserScript alloc] initWithSource:[self desktopBridgeBootstrapSource]
                               injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                            forMainFrameOnly:YES];
    [contentController addUserScript:bridgeBootstrap];

    CGFloat resolvedWidth = MAX(420.0, width);
    CGFloat resolvedHeight = MAX(320.0, height);
    NSRect frame = NSMakeRect(0.0, 0.0, resolvedWidth, resolvedHeight);
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
                                   NSWindowStyleMaskClosable |
                                   NSWindowStyleMaskMiniaturizable |
                                   NSWindowStyleMaskResizable |
                                   NSWindowStyleMaskFullSizeContentView;
    NSWindow *childWindow = [[NSWindow alloc] initWithContentRect:frame
                                                         styleMask:styleMask
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO];
    childWindow.delegate = self;
    [childWindow setMinSize:NSMakeSize(380.0, 260.0)];
    [childWindow setTitle:(windowTitle.length ? windowTitle : @"Wizardry")];
    [childWindow setTitlebarAppearsTransparent:YES];
    [childWindow setTitleVisibility:NSWindowTitleHidden];
    [childWindow setBackgroundColor:[NSColor colorWithSRGBRed:0.93 green:0.95 blue:0.98 alpha:1.0]];
    if (@available(macOS 11.0, *)) {
        [childWindow setToolbarStyle:NSWindowToolbarStyleUnified];
        [childWindow setTitlebarSeparatorStyle:NSTitlebarSeparatorStyleNone];
    }

    WKWebView *childWebView = [[WKWebView alloc] initWithFrame:frame configuration:resolvedConfiguration];
    childWebView.UIDelegate = self;
    @try {
        [childWebView setValue:@NO forKey:@"drawsBackground"];
    } @catch (NSException *exception) {
        (void)exception;
    }
    if (@available(macOS 11.0, *)) {
        childWebView.underPageBackgroundColor = self.prioritiesBootBgColor ?: [NSColor clearColor];
    }
    [childWebView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [childWindow setContentView:childWebView];

    [childWindow makeKeyAndOrderFront:nil];
    [childWindow orderFrontRegardless];
    if (!self.auxWindows) {
        self.auxWindows = [NSMutableArray array];
    }
    [self.auxWindows addObject:childWindow];

    if (request) {
        NSURL *url = request.URL;
        if (url.isFileURL) {
            NSURL *allowDir = [NSURL fileURLWithPath:@"/" isDirectory:YES];
            [childWebView loadFileURL:url allowingReadAccessToURL:allowDir];
        } else {
            [childWebView loadRequest:request];
        }
    }

    return childWebView;
}

- (WKWebView *)webView:(WKWebView *)webView
createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
forNavigationAction:(WKNavigationAction *)navigationAction
windowFeatures:(WKWindowFeatures *)windowFeatures {
    (void)webView;
    if (navigationAction.targetFrame && navigationAction.targetFrame.isMainFrame) {
        return nil;
    }
    CGFloat width = windowFeatures.width ? MAX(420.0, windowFeatures.width.doubleValue) : 980.0;
    CGFloat height = windowFeatures.height ? MAX(320.0, windowFeatures.height.doubleValue) : 720.0;
    NSString *title = self.window ? self.window.title : @"Wizardry";
    return [self createAuxWindowWithConfiguration:configuration
                                          request:navigationAction.request
                                      windowTitle:title
                                            width:width
                                           height:height];
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutPrioritiesDragStrips];
}

- (void)layoutPrioritiesDragStrips {
    if (!self.enableHeaderDragHoles || !self.hostRootView || !self.window) {
        return;
    }
    NSRect frame = [self.window frame];
    CGFloat dragStripHeight = 44.0;
    CGFloat topStripHeight = 18.0;
    CGFloat titleHoleLeftWidth = self.prioritiesTitleHoleLeftWidth > 0.0 ? self.prioritiesTitleHoleLeftWidth : 36.0;
    CGFloat titleHoleRightWidth = self.prioritiesTitleHoleRightWidth > 0.0 ? self.prioritiesTitleHoleRightWidth : 10.0;
    CGFloat rightControlsReservedWidth = self.prioritiesRightControlsReservedWidth > 0.0 ? self.prioritiesRightControlsReservedWidth : 168.0;

    CGFloat centerX = floor(frame.size.width / 2.0);
    CGFloat holeStartX = centerX - titleHoleLeftWidth;
    CGFloat holeEndX = centerX + titleHoleRightWidth;
    if (holeStartX < 0.0) {
        holeStartX = 0.0;
    }
    if (holeEndX > frame.size.width) {
        holeEndX = frame.size.width;
    }
    CGFloat leftStripWidth = holeStartX;
    if (leftStripWidth < 0.0) {
        leftStripWidth = 0.0;
    }
    CGFloat rightStripX = holeEndX;
    CGFloat rightStripWidth = frame.size.width - rightStripX - rightControlsReservedWidth;
    if (rightStripWidth < 0.0) {
        rightStripWidth = 0.0;
    }

    if (self.prioritiesTopDragStrip) {
        CGFloat topStripWidth = self.prefersLeftOnlyHeaderDragArea ? leftStripWidth : frame.size.width;
        [self.prioritiesTopDragStrip setFrame:NSMakeRect(0.0,
                                                         frame.size.height - topStripHeight,
                                                         topStripWidth,
                                                         topStripHeight)];
        [self.prioritiesTopDragStrip setHidden:(topStripWidth <= 0.0)];
    }
    if (self.prioritiesLeftHeaderDragStrip) {
        [self.prioritiesLeftHeaderDragStrip setFrame:NSMakeRect(0.0,
                                                                frame.size.height - dragStripHeight,
                                                                leftStripWidth,
                                                                dragStripHeight)];
        [self.prioritiesLeftHeaderDragStrip setHidden:(leftStripWidth <= 0.0)];
    }
    if (self.prioritiesRightHeaderDragStrip) {
        [self.prioritiesRightHeaderDragStrip setFrame:NSMakeRect(rightStripX,
                                                                 frame.size.height - dragStripHeight,
                                                                 rightStripWidth,
                                                                 dragStripHeight)];
        [self.prioritiesRightHeaderDragStrip setHidden:(rightStripWidth <= 0.0)];
    }
}

- (void)emitGlobalFavoriteTrackHotkey {
    if (!self.webView) return;
    NSString *js = @"if (window.__serenity_on_global_favorite_hotkey) { window.__serenity_on_global_favorite_hotkey(); } "
                   @"if (window.__wizardry_emit) { window.__wizardry_emit('host.global_hotkey', { id: 'serenity.favoriteTrack' }); }";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        (void)result;
        if (error) {
            NSLog(@"Global hotkey emit error: %@", error);
        }
    }];
}

- (NSString *)normalizedCommandPath {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    NSString *currentPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"] ?: @"";
    if (currentPath.length) {
        [components addObjectsFromArray:[currentPath componentsSeparatedByString:@":"]];
    }

    NSString *homeDir = NSHomeDirectory();
    NSArray<NSString *> *fallbacks = @[
        @"/opt/homebrew/bin",
        @"/opt/homebrew/sbin",
        @"/usr/local/bin",
        @"/usr/local/sbin",
        @"/usr/bin",
        @"/bin",
        @"/usr/sbin",
        @"/sbin",
        [homeDir stringByAppendingPathComponent:@".local/bin"],
        [homeDir stringByAppendingPathComponent:@"bin"],
        [homeDir stringByAppendingPathComponent:@".cargo/bin"]
    ];
    [components addObjectsFromArray:fallbacks];

    NSMutableArray<NSString *> *deduped = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSString *entry in components) {
        NSString *path = [[NSString stringWithFormat:@"%@", entry ?: @""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!path.length || [seen containsObject:path]) {
            continue;
        }
        [seen addObject:path];
        [deduped addObject:path];
    }
    return [deduped componentsJoinedByString:@":"];
}

- (NSDictionary<NSString *, NSString *> *)resolvedCommandEnvironment {
    NSMutableDictionary<NSString *, NSString *> *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    environment[@"PATH"] = [self normalizedCommandPath];
    return environment;
}

- (NSArray<NSString *> *)filePathsFromDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
    if (!draggingInfo) {
        return @[];
    }
    NSPasteboard *pasteboard = [draggingInfo draggingPasteboard];
    if (!pasteboard) {
        return @[];
    }
    NSDictionary *options = @{ NSPasteboardURLReadingFileURLsOnlyKey: @YES };
    NSArray<NSURL *> *urls = [pasteboard readObjectsForClasses:@[[NSURL class]] options:options];
    if (!urls.count) {
        return @[];
    }

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSURL *url in urls) {
        if (![url isFileURL]) {
            continue;
        }
        NSString *path = [[url path] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!path.length || [seen containsObject:path]) {
            continue;
        }
        [seen addObject:path];
        [paths addObject:path];
    }
    return paths;
}

- (BOOL)draggingInfoContainsImagePayload:(id<NSDraggingInfo>)draggingInfo {
    if (!draggingInfo) {
        return NO;
    }
    NSPasteboard *pasteboard = [draggingInfo draggingPasteboard];
    if (!pasteboard) {
        return NO;
    }
    return [NSImage canInitWithPasteboard:pasteboard];
}

- (NSString *)stagedImagePathFromDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
    if (!draggingInfo) {
        return @"";
    }
    NSPasteboard *pasteboard = [draggingInfo draggingPasteboard];
    if (!pasteboard || ![NSImage canInitWithPasteboard:pasteboard]) {
        return @"";
    }
    NSImage *image = [[NSImage alloc] initWithPasteboard:pasteboard];
    if (!image) {
        return @"";
    }

    NSBitmapImageRep *bitmapRep = nil;
    for (NSImageRep *candidate in [image representations]) {
        if ([candidate isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapRep = (NSBitmapImageRep *)candidate;
            break;
        }
    }
    if (!bitmapRep) {
        NSData *tiffData = [image TIFFRepresentation];
        if (tiffData.length) {
            bitmapRep = [NSBitmapImageRep imageRepWithData:tiffData];
        }
    }
    if (!bitmapRep) {
        return @"";
    }

    NSData *pngData = [bitmapRep representationUsingType:NSPNGFileType properties:@{}];
    if (!pngData.length) {
        return @"";
    }

    NSString *tempDir = NSTemporaryDirectory();
    if (!tempDir.length) {
        tempDir = @"/tmp";
    }
    NSString *fileName = [NSString stringWithFormat:@"wizardry-forge-drop-%@.png", [[NSUUID UUID] UUIDString]];
    NSString *path = [tempDir stringByAppendingPathComponent:fileName];
    NSError *writeError = nil;
    if (![pngData writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        NSLog(@"Forge staged image write failed: %@", writeError);
        return @"";
    }
    return path;
}

- (NSString *)forgeDropTargetAtDomX:(CGFloat)domX domY:(CGFloat)domY paths:(NSArray<NSString *> *)paths hasImagePayload:(BOOL)hasImagePayload {
    if (!self.enableForgeAppMenu) {
        return @"";
    }

    if (self.forgeIconDropZoneActive &&
        !self.forgeIconDropBusy &&
        domX >= self.forgeIconDropZoneLeft &&
        domX <= self.forgeIconDropZoneRight &&
        domY >= self.forgeIconDropZoneTop &&
        domY <= self.forgeIconDropZoneBottom) {
        if (!paths.count && hasImagePayload) {
            return @"icon";
        }
        for (NSString *path in paths) {
            BOOL isDirectory = NO;
            if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory) {
                continue;
            }
            NSString *ext = [[[path pathExtension] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([@[@"png", @"jpg", @"jpeg", @"webp", @"gif", @"bmp", @"tif", @"tiff", @"svg", @"heic", @"heif", @"avif", @"icns"] containsObject:ext]) {
                return @"icon";
            }
        }
    }

    if (self.forgeWorkspaceDropZoneActive &&
        domX >= self.forgeWorkspaceDropZoneLeft &&
        domX <= self.forgeWorkspaceDropZoneRight &&
        domY >= self.forgeWorkspaceDropZoneTop &&
        domY <= self.forgeWorkspaceDropZoneBottom) {
        for (NSString *path in paths) {
            BOOL isDirectory = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
                return @"workspace";
            }
        }
    }

    return @"";
}

- (void)dispatchForgeFileDragPhase:(NSString *)phase target:(NSString *)target domX:(CGFloat)domX domY:(CGFloat)domY paths:(NSArray<NSString *> *)paths hasImagePayload:(BOOL)hasImagePayload {
    if (!self.enableForgeAppMenu || !self.webView || !phase.length) {
        return;
    }

    NSDictionary *payload = @{
        @"phase": phase,
        @"target": target ?: @"",
        @"nativeHandled": @([phase isEqualToString:@"drop"] && [target isEqualToString:@"icon"]),
        @"hasImagePayload": @(hasImagePayload),
        @"clientX": @(domX),
        @"clientY": @(domY),
        @"paths": paths ?: @[]
    };
    [self dispatchForgeHostCallbackNamed:@"forgeHostFileDrag" payload:payload toWebView:self.webView];
}

- (void)dispatchForgeHostCallbackNamed:(NSString *)functionName payload:(NSDictionary *)payload toWebView:(WKWebView *)targetWebView {
    WKWebView *resolvedTarget = targetWebView ?: self.webView;
    if (!self.enableForgeAppMenu || !resolvedTarget || !functionName.length || !payload) {
        return;
    }

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!jsonData || jsonError) {
        NSLog(@"Forge host callback payload serialization error: %@", jsonError);
        return;
    }
    NSString *payloadJSON = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (!payloadJSON.length) {
        return;
    }

    NSString *js = [NSString stringWithFormat:@"if (window && typeof window.%@ === 'function') { window.%@(%@); }", functionName, functionName, payloadJSON];
    dispatch_async(dispatch_get_main_queue(), ^{
        [resolvedTarget evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
            (void)result;
            if (error) {
                NSLog(@"Forge host callback dispatch error: %@", error);
            }
        }];
    });
}

- (NSArray<NSString *> *)forgeIconDropCommandArgumentsForPath:(NSString *)imagePath {
    NSString *trimmedPath = [[NSString stringWithString:(imagePath ?: @"")] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *backendScript = [[self.appPath stringByAppendingPathComponent:@"scripts"] stringByAppendingPathComponent:@"forge-backend.sh"];
    NSString *shapeMode = [[NSString stringWithString:(self.forgeIconDropShapeMode ?: @"squircle")] lowercaseString];
    NSString *targetKind = [[NSString stringWithString:(self.forgeIconDropTargetKind ?: @"")] lowercaseString];
    NSString *targetValue = [NSString stringWithString:(self.forgeIconDropTargetValue ?: @"")];
    NSString *rootHint = [NSString stringWithString:(self.forgeIconDropRootHint ?: @"")];

    if (!trimmedPath.length || !backendScript.length || ![[NSFileManager defaultManager] fileExistsAtPath:backendScript]) {
        return nil;
    }
    if (![shapeMode isEqualToString:@"plain"]) {
        shapeMode = @"squircle";
    }
    if ([targetKind isEqualToString:@"builtin"] && targetValue.length) {
        return @[backendScript, @"set-app-icon-file", rootHint, targetValue, trimmedPath, shapeMode];
    }
    if ([targetKind isEqualToString:@"workspace"] && targetValue.length) {
        return @[backendScript, @"set-workspace-icon-file", rootHint, targetValue, trimmedPath, shapeMode];
    }
    return nil;
}

- (void)runForgeIconDropForPath:(NSString *)imagePath fromWebView:(WKWebView *)sourceWebView {
    WKWebView *resolvedTarget = sourceWebView ?: self.webView;
    NSString *itemKey = [NSString stringWithString:(self.forgeIconDropItemKey ?: @"")];
    NSString *trimmedPath = [[NSString stringWithString:(imagePath ?: @"")] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray<NSString *> *commandArgs = [self forgeIconDropCommandArgumentsForPath:trimmedPath];
    if (!trimmedPath.length || !commandArgs.count) {
        NSDictionary *payload = @{
            @"ok": @NO,
            @"itemKey": itemKey ?: @"",
            @"imagePath": trimmedPath ?: @"",
            @"stdout": @"",
            @"stderr": @"",
            @"exitCode": @1,
            @"error": @"Forge icon drop target is not ready."
        };
        [self dispatchForgeHostCallbackNamed:@"forgeHostIconDropResult" payload:payload toWebView:resolvedTarget];
        return;
    }

    self.forgeIconDropBusy = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/sh";
        task.arguments = commandArgs;
        task.environment = [self resolvedCommandEnvironment];

        NSPipe *outPipe = [NSPipe pipe];
        NSPipe *errPipe = [NSPipe pipe];
        task.standardOutput = outPipe;
        task.standardError = errPipe;

        @try {
            [task launch];
        } @catch (NSException *exception) {
            NSDictionary *payload = @{
                @"ok": @NO,
                @"itemKey": itemKey ?: @"",
                @"imagePath": trimmedPath ?: @"",
                @"stdout": @"",
                @"stderr": @"",
                @"exitCode": @1,
                @"error": [NSString stringWithFormat:@"Failed to launch icon drop command: %@", exception.reason ?: @"unknown error"]
            };
            dispatch_async(dispatch_get_main_queue(), ^{
                self.forgeIconDropBusy = NO;
                [self dispatchForgeHostCallbackNamed:@"forgeHostIconDropResult" payload:payload toWebView:resolvedTarget];
            });
            return;
        }

        [task waitUntilExit];

        NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
        NSString *stdout = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
        NSString *stderr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @"";
        int exitCode = [task terminationStatus];

        NSMutableDictionary *payload = [@{
            @"ok": @(exitCode == 0),
            @"itemKey": itemKey ?: @"",
            @"imagePath": trimmedPath ?: @"",
            @"stdout": stdout,
            @"stderr": stderr,
            @"exitCode": @(exitCode)
        } mutableCopy];
        if (exitCode != 0) {
            NSString *errorMessage = stderr.length ? stderr : (stdout.length ? stdout : @"Icon drop failed.");
            payload[@"error"] = errorMessage;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.forgeIconDropBusy = NO;
            [self dispatchForgeHostCallbackNamed:@"forgeHostIconDropResult" payload:payload toWebView:resolvedTarget];
        });
    });
}

- (void)clearFavoriteTrackHotkeyRegistration {
    if (self.favoriteTrackHotKeyRef) {
        UnregisterEventHotKey(self.favoriteTrackHotKeyRef);
        self.favoriteTrackHotKeyRef = NULL;
    }
}

- (BOOL)registerFavoriteTrackHotkey:(NSString *)hotkey errorMessage:(NSString **)errorMessage {
    [self clearFavoriteTrackHotkeyRegistration];
    NSString *trimmed = [[NSString stringWithString:(hotkey ?: @"")] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return YES;
    }

    if (!self.favoriteTrackHotKeyHandlerRef) {
        EventTypeSpec eventType;
        eventType.eventClass = kEventClassKeyboard;
        eventType.eventKind = kEventHotKeyPressed;
        OSStatus installStatus = InstallEventHandler(GetApplicationEventTarget(),
                                                     WizardryHandleGlobalHotKey,
                                                     1,
                                                     &eventType,
                                                     (__bridge void *)self,
                                                     &_favoriteTrackHotKeyHandlerRef);
        if (installStatus != noErr) {
            if (errorMessage) {
                *errorMessage = [NSString stringWithFormat:@"InstallEventHandler failed (%d)", (int)installStatus];
            }
            return NO;
        }
    }

    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSString *part in [trimmed componentsSeparatedByString:@"+"]) {
        NSString *token = [[part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (token.length) [tokens addObject:token];
    }
    if (tokens.count == 0) {
        if (errorMessage) *errorMessage = @"Hotkey is empty";
        return NO;
    }

    static NSDictionary<NSString *, NSNumber *> *keyMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyMap = @{
            @"A": @0, @"S": @1, @"D": @2, @"F": @3, @"H": @4, @"G": @5, @"Z": @6, @"X": @7, @"C": @8, @"V": @9, @"B": @11,
            @"Q": @12, @"W": @13, @"E": @14, @"R": @15, @"Y": @16, @"T": @17,
            @"1": @18, @"2": @19, @"3": @20, @"4": @21, @"6": @22, @"5": @23, @"=": @24, @"9": @25, @"7": @26, @"-": @27, @"8": @28, @"0": @29,
            @"]": @30, @"O": @31, @"U": @32, @"[": @33, @"I": @34, @"P": @35, @"ENTER": @36, @"RETURN": @36,
            @"L": @37, @"J": @38, @"'": @39, @"K": @40, @";": @41, @"\\": @42, @",": @43, @"/": @44, @"N": @45, @"M": @46, @".": @47,
            @"TAB": @48, @"SPACE": @49, @"`": @50, @"BACKSPACE": @51, @"DELETE": @51, @"ESCAPE": @53, @"ESC": @53,
            @"F1": @122, @"F2": @120, @"F3": @99, @"F4": @118, @"F5": @96, @"F6": @97, @"F7": @98, @"F8": @100, @"F9": @101, @"F10": @109, @"F11": @103, @"F12": @111
        };
    });

    UInt32 modifiers = 0;
    NSString *keyToken = @"";
    for (NSString *token in tokens) {
        if ([token isEqualToString:@"CMD"] || [token isEqualToString:@"COMMAND"] || [token isEqualToString:@"META"]) {
            modifiers |= cmdKey;
            continue;
        }
        if ([token isEqualToString:@"CTRL"] || [token isEqualToString:@"CONTROL"]) {
            modifiers |= controlKey;
            continue;
        }
        if ([token isEqualToString:@"ALT"] || [token isEqualToString:@"OPTION"] || [token isEqualToString:@"OPT"]) {
            modifiers |= optionKey;
            continue;
        }
        if ([token isEqualToString:@"SHIFT"]) {
            modifiers |= shiftKey;
            continue;
        }
        keyToken = token;
    }

    if (modifiers == 0 || keyToken.length == 0) {
        if (errorMessage) *errorMessage = @"Hotkey must include at least one modifier and one key";
        return NO;
    }

    NSNumber *keyCodeNumber = keyMap[keyToken];
    if (!keyCodeNumber) {
        if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Unsupported hotkey key '%@'", keyToken];
        return NO;
    }

    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'WSHK';
    hotKeyID.id = 1;
    OSStatus registerStatus = RegisterEventHotKey((UInt32)[keyCodeNumber unsignedIntValue],
                                                  modifiers,
                                                  hotKeyID,
                                                  GetApplicationEventTarget(),
                                                  0,
                                                  &_favoriteTrackHotKeyRef);
    if (registerStatus != noErr) {
        if (errorMessage) {
            *errorMessage = [NSString stringWithFormat:@"RegisterEventHotKey failed (%d)", (int)registerStatus];
        }
        return NO;
    }

    return YES;
}

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

- (NSString *)resolvedWizardryAppsRoot {
    NSString *envRoot = [[[NSProcessInfo processInfo] environment] objectForKey:@"WIZARDRY_APPS_ROOT"];
    if (envRoot.length && [[NSFileManager defaultManager] fileExistsAtPath:envRoot]) {
        return envRoot;
    }

    NSString *rootFile = [[[self.appPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"wizardry-apps-root.txt"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSError *error = nil;
    NSString *rootFromFile = [[NSString stringWithContentsOfFile:rootFile encoding:NSUTF8StringEncoding error:&error] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (rootFromFile.length && [[NSFileManager defaultManager] fileExistsAtPath:rootFromFile]) {
        return rootFromFile;
    }

    return @"";
}

- (NSString *)resolvedSharedThemeFileForTheme:(NSString *)themeName {
    NSString *cleanTheme = [[themeName ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!cleanTheme.length) {
        cleanTheme = @"psionic";
    }

    NSString *appThemePath = [[self.appPath stringByAppendingPathComponent:@"themes"] stringByAppendingPathComponent:[cleanTheme stringByAppendingString:@".css"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:appThemePath]) {
        return appThemePath;
    }

    NSString *repoRoot = [self resolvedWizardryAppsRoot];
    if (repoRoot.length) {
        NSString *sharedThemePath = [[[repoRoot stringByAppendingPathComponent:@"web/.themes"] stringByAppendingPathComponent:cleanTheme] stringByAppendingString:@".css"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:sharedThemePath]) {
            return sharedThemePath;
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

    NSString *themeFile = [self resolvedSharedThemeFileForTheme:theme];
    NSDictionary<NSString *, NSString *> *vars = [self readThemeVariablesFromFile:themeFile];
    NSColor *bg = [self parseCSSColorToken:vars[@"bg"]];
    NSColor *text = [self parseCSSColorToken:vars[@"text"]];
    NSColor *muted = [self parseCSSColorToken:vars[@"light-text"]];

    self.prioritiesBootBgColor = bg ?: [NSColor whiteColor];
    self.prioritiesBootTextColor = muted ?: text ?: [NSColor colorWithSRGBRed:0.42 green:0.45 blue:0.50 alpha:1.0];
}

- (void)loadForgeBootPalette {
    NSString *xdgConfig = [[[NSProcessInfo processInfo] environment] objectForKey:@"XDG_CONFIG_HOME"];
    NSString *configFile = xdgConfig.length
        ? [xdgConfig stringByAppendingPathComponent:@"wizardry-apps/forge-ui.conf"]
        : [NSHomeDirectory() stringByAppendingPathComponent:@".config/wizardry-apps/forge-ui.conf"];

    NSString *theme = [[self readConfigValueForKey:@"theme" fromFile:configFile] lowercaseString];
    if (!theme.length) {
        theme = @"psionic";
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789_-"];
    if ([[theme stringByTrimmingCharactersInSet:allowed] length] > 0) {
        theme = @"psionic";
    }

    NSString *themeFile = [self resolvedSharedThemeFileForTheme:theme];
    NSDictionary<NSString *, NSString *> *vars = [self readThemeVariablesFromFile:themeFile];
    NSColor *bg = [self parseCSSColorToken:vars[@"bg"]];
    NSColor *text = [self parseCSSColorToken:vars[@"text"]];
    NSColor *muted = [self parseCSSColorToken:vars[@"light-text"]];

    self.prioritiesBootBgColor = bg ?: [NSColor colorWithSRGBRed:0.93 green:0.95 blue:0.98 alpha:1.0];
    self.prioritiesBootTextColor = muted ?: text ?: [NSColor colorWithSRGBRed:0.42 green:0.45 blue:0.50 alpha:1.0];
}

- (void)loadArtificerBootPalette {
    NSString *xdgConfig = [[[NSProcessInfo processInfo] environment] objectForKey:@"XDG_CONFIG_HOME"];
    NSString *configFile = xdgConfig.length
        ? [xdgConfig stringByAppendingPathComponent:@"wizardry-apps/artificer-ui.conf"]
        : [NSHomeDirectory() stringByAppendingPathComponent:@".config/wizardry-apps/artificer-ui.conf"];

    NSString *theme = [[self readConfigValueForKey:@"theme" fromFile:configFile] lowercaseString];
    if (!theme.length) {
        theme = @"psionic";
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789_-"];
    if ([[theme stringByTrimmingCharactersInSet:allowed] length] > 0) {
        theme = @"psionic";
    }

    NSString *themeFile = @"";
    NSString *appThemePath = [[self.appPath stringByAppendingPathComponent:@"themes"] stringByAppendingPathComponent:[theme stringByAppendingString:@".css"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:appThemePath]) {
        themeFile = appThemePath;
    } else {
        NSString *repoRoot = [self.appPath stringByDeletingLastPathComponent];
        repoRoot = [repoRoot stringByDeletingLastPathComponent];
        NSString *repoThemePath = [[[repoRoot stringByAppendingPathComponent:@"web/artificer/static/themes"] stringByAppendingPathComponent:theme] stringByAppendingString:@".css"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:repoThemePath]) {
            themeFile = repoThemePath;
        }
    }

    NSDictionary<NSString *, NSString *> *vars = [self readThemeVariablesFromFile:themeFile];
    NSColor *bg = [self parseCSSColorToken:vars[@"bg"]];
    NSColor *text = [self parseCSSColorToken:vars[@"text"]];
    NSColor *muted = [self parseCSSColorToken:vars[@"light-text"]];

    self.prioritiesBootBgColor = bg ?: [NSColor colorWithSRGBRed:0.925 green:0.918 blue:0.957 alpha:1.0];
    self.prioritiesBootTextColor = muted ?: text ?: [NSColor colorWithSRGBRed:0.365 green:0.392 blue:0.525 alpha:1.0];
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
    CGFloat logoSize = self.bootSplashLogoSize > 0.0 ? self.bootSplashLogoSize : 192.0;
    [NSLayoutConstraint activateConstraints:@[
        [logoView.widthAnchor constraintEqualToConstant:logoSize],
        [logoView.heightAnchor constraintEqualToConstant:logoSize],
        [stack.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor]
    ]];

    [rootView addSubview:overlay];
    self.nativeBootSplashView = overlay;

    // Failsafe: never leave the native splash up forever if the web app cannot
    // notify readiness (for example when startup bridge bootstrap fails).
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.nativeBootSplashView == overlay) {
            [self hideNativeBootSplash];
        }
    });
}

- (void)hideNativeBootSplash {
    if (!self.nativeBootSplashView) {
        return;
    }
    NSView *overlay = self.nativeBootSplashView;
    self.nativeBootSplashView = nil;
    [overlay removeFromSuperview];
}

- (void)showMainWindow {
    if (!self.window) {
        return;
    }
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self updateStatusItemVisibility];
}

- (void)toggleMainWindowFromStatusItem:(id)sender {
    (void)sender;
    if (!self.window) {
        return;
    }
    if ([self.window isVisible]) {
        [self.window orderOut:nil];
        [self updateStatusItemVisibility];
        return;
    }
    [self showMainWindow];
}

- (void)quitFromStatusItem:(id)sender {
    (void)sender;
    [NSApp terminate:nil];
}

- (NSImage *)renderedStatusItemImage {
    NSImage *source = self.appIconImage ?: [NSApp applicationIconImage];
    if (!source || source.size.width <= 0.0 || source.size.height <= 0.0) {
        if (@available(macOS 11.0, *)) {
            NSImage *fallback = [NSImage imageWithSystemSymbolName:@"play.square.fill" accessibilityDescription:nil];
            if (fallback) {
                [fallback setTemplate:YES];
                return fallback;
            }
        }
        return nil;
    }

    CGFloat side = MAX(14.0, [NSStatusBar systemStatusBar].thickness - 4.0);
    NSImage *rendered = [[NSImage alloc] initWithSize:NSMakeSize(side, side)];
    [rendered lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [source drawInRect:NSMakeRect(0, 0, side, side)
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0
        respectFlipped:YES
                 hints:nil];
    [rendered unlockFocus];
    [rendered setTemplate:YES];
    return rendered;
}

- (void)updateStatusItemVisibility {
    BOOL wantsStatusItem = self.keepRunningInBackground && self.showStatusItem;
    if (!wantsStatusItem) {
        if (self.statusItem) {
            [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
            self.statusItem = nil;
        }
        return;
    }
    if (!self.statusItem) {
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    }
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        NSImage *icon = [self renderedStatusItemImage];
        if (icon) {
            button.image = icon;
            button.title = @"";
            button.imagePosition = NSImageOnly;
        } else {
            button.image = nil;
            button.title = @"S";
            button.imagePosition = NSNoImage;
        }
        button.toolTip = self.window ? self.window.title : @"Wizardry";
    }
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Relay"];
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:([self.window isVisible] ? @"Hide Window" : @"Show Window")
                                                        action:@selector(toggleMainWindowFromStatusItem:)
                                                 keyEquivalent:@""];
    [toggleItem setTarget:self];
    [menu addItem:toggleItem];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quitFromStatusItem:)
                                               keyEquivalent:@""];
    [quitItem setTarget:self];
    [menu addItem:quitItem];
    self.statusItem.menu = menu;
}

- (void)applyBackgroundModeEnabled:(BOOL)enabled showStatusItem:(BOOL)showStatusItem {
    self.keepRunningInBackground = enabled;
    self.showStatusItem = enabled && showStatusItem;
    [self updateStatusItemVisibility];
}

- (void)setupMainMenuWithAppName:(NSString *)appName {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    NSString *aboutTitle = [NSString stringWithFormat:@"About %@", appName];
    [appMenu addItemWithTitle:aboutTitle action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    if (self.enableForgeAppMenu) {
        NSMenuItem *prefs = [appMenu addItemWithTitle:@"Settings…"
                                               action:@selector(nativeForgeOpenSettings:)
                                        keyEquivalent:@","];
        [prefs setTarget:self];

        NSMenuItem *createMode = [appMenu addItemWithTitle:@"Create App Workflow"
                                                    action:@selector(nativeForgeOpenCreateWorkflow:)
                                             keyEquivalent:@"2"];
        [createMode setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [createMode setTarget:self];

        NSMenuItem *pipelineMode = [appMenu addItemWithTitle:@"App Pipeline Workflow"
                                                      action:@selector(nativeForgeOpenPipelineWorkflow:)
                                               keyEquivalent:@"1"];
        [pipelineMode setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [pipelineMode setTarget:self];
        [appMenu addItem:[NSMenuItem separatorItem]];
    }

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

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    NSMenuItem *undoItem = [editMenu addItemWithTitle:@"Undo"
                                               action:@selector(undo:)
                                        keyEquivalent:@"z"];
    [undoItem setTarget:nil];

    NSMenuItem *redoItem = [editMenu addItemWithTitle:@"Redo"
                                               action:@selector(redo:)
                                        keyEquivalent:@"Z"];
    [redoItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    [redoItem setTarget:nil];

    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *cutItem = [editMenu addItemWithTitle:@"Cut"
                                              action:@selector(cut:)
                                       keyEquivalent:@"x"];
    [cutItem setTarget:nil];

    NSMenuItem *copyItem = [editMenu addItemWithTitle:@"Copy"
                                               action:@selector(copy:)
                                        keyEquivalent:@"c"];
    [copyItem setTarget:nil];

    NSMenuItem *pasteItem = [editMenu addItemWithTitle:@"Paste"
                                                action:@selector(paste:)
                                         keyEquivalent:@"v"];
    [pasteItem setTarget:nil];

    NSMenuItem *deleteItem = [editMenu addItemWithTitle:@"Delete"
                                                 action:@selector(delete:)
                                          keyEquivalent:@""];
    [deleteItem setTarget:nil];

    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *selectAllItem = [editMenu addItemWithTitle:@"Select All"
                                                    action:@selector(selectAll:)
                                             keyEquivalent:@"a"];
    [selectAllItem setTarget:nil];

    [editMenuItem setSubmenu:editMenu];

    if (self.enableForgeAppMenu) {
        NSMenuItem *projectMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        [mainMenu addItem:projectMenuItem];
        NSMenu *projectMenu = [[NSMenu alloc] initWithTitle:@"Project"];

        NSMenuItem *runCurrent = [projectMenu addItemWithTitle:@"Run Current Project"
                                                         action:@selector(nativeForgeRunCurrentProject:)
                                                  keyEquivalent:@"r"];
        [runCurrent setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [runCurrent setTarget:self];

        NSMenuItem *serveWebHost = [projectMenu addItemWithTitle:@"Serve Web Host"
                                                           action:@selector(nativeForgeServeWebHost:)
                                                    keyEquivalent:@"r"];
        [serveWebHost setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagShift)];
        [serveWebHost setTarget:self];

        NSMenuItem *buildEnabled = [projectMenu addItemWithTitle:@"Build Enabled Targets"
                                                           action:@selector(nativeForgeBuildEnabledTargets:)
                                                    keyEquivalent:@"b"];
        [buildEnabled setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [buildEnabled setTarget:self];

        [projectMenuItem setSubmenu:projectMenu];
    }

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

- (void)dispatchForgeMenuAction:(NSString *)actionName {
    if (!self.webView || !actionName.length) {
        return;
    }
    NSString *js = [NSString stringWithFormat:@"if (window && typeof window.forgeHostAction === 'function') { window.forgeHostAction('%@'); }", actionName];
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

- (void)nativeForgeRunCurrentProject:(id)sender {
    (void)sender;
    [self dispatchForgeMenuAction:@"run-current"];
}

- (void)nativeForgeBuildEnabledTargets:(id)sender {
    (void)sender;
    [self dispatchForgeMenuAction:@"build-enabled"];
}

- (void)nativeForgeServeWebHost:(id)sender {
    (void)sender;
    [self dispatchForgeMenuAction:@"serve-web-host"];
}

- (void)nativeForgeOpenSettings:(id)sender {
    (void)sender;
    [self dispatchForgeMenuAction:@"open-settings"];
}

- (void)nativeForgeOpenCreateWorkflow:(id)sender {
    (void)sender;
    [self dispatchForgeMenuAction:@"open-create-workflow"];
}

- (void)nativeForgeOpenPipelineWorkflow:(id)sender {
    (void)sender;
    [self dispatchForgeMenuAction:@"open-pipeline-workflow"];
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
    NSString *appLeafComponent = [self.appPath lastPathComponent];
    BOOL isNestedWorkspaceApp = [[appLeafComponent lowercaseString] isEqualToString:@"app"];
    NSString *appComponent = appLeafComponent;
    if (isNestedWorkspaceApp) {
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
    BOOL prefersHeaderDragHoles = ([appSlug isEqualToString:@"headquarters"] || [appSlug isEqualToString:@"priorities"] || [appSlug isEqualToString:@"serenity"] || [appSlug isEqualToString:@"boycott"]);
    BOOL prefersLeftOnlyHeaderDragArea = [appSlug isEqualToString:@"boycott"];
    BOOL isForgeApp = [appSlug isEqualToString:@"forge"];
    BOOL isArtificerApp = [appSlug isEqualToString:@"artificer"];
    self.enableNativeViewMenu = [appSlug isEqualToString:@"priorities"];
    self.enableHeaderDragHoles = prefersHeaderDragHoles;
    self.prefersLeftOnlyHeaderDragArea = prefersLeftOnlyHeaderDragArea;
    self.enableForgeAppMenu = isForgeApp;
    self.enableNativeBootSplash = self.enableNativeViewMenu || isForgeApp || isArtificerApp;
    self.prefersWideDragStrip = [appSlug isEqualToString:@"virtual-redditor"];
    self.bootSplashLogoSize = isForgeApp ? 156.0 : (isArtificerApp ? 176.0 : 192.0);
    if (self.enableNativeViewMenu) {
        [self loadPrioritiesBootPalette];
    } else if (isArtificerApp) {
        [self loadArtificerBootPalette];
    } else if (self.enableNativeBootSplash) {
        [self loadForgeBootPalette];
    }

    [self setupMainMenuWithAppName:appName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSImage *resolvedBundleIcon = nil;
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleIconFile = [[[mainBundle infoDictionary] objectForKey:@"CFBundleIconFile"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (bundleIconFile.length > 0) {
        NSString *iconBase = [bundleIconFile stringByDeletingPathExtension];
        NSString *iconExt = [bundleIconFile pathExtension];
        if (iconExt.length == 0) {
            iconExt = @"icns";
        }
        NSString *bundleIconPath = [mainBundle pathForResource:iconBase ofType:iconExt];
        if (bundleIconPath.length > 0 && [fileManager fileExistsAtPath:bundleIconPath]) {
            resolvedBundleIcon = [[NSImage alloc] initWithContentsOfFile:bundleIconPath];
        }
    }
    if (!resolvedBundleIcon) {
        resolvedBundleIcon = [NSApp applicationIconImage];
    }
    NSString *resolvedIconPath = nil;
    if (isNestedWorkspaceApp && [fileManager fileExistsAtPath:parentIconPath]) {
        // For workspace apps launched from .../app, prefer the workspace-level icon.
        resolvedIconPath = parentIconPath;
    } else if ([fileManager fileExistsAtPath:customIconPath]) {
        resolvedIconPath = customIconPath;
    } else if ([fileManager fileExistsAtPath:parentIconPath]) {
        resolvedIconPath = parentIconPath;
    }

    NSImage *resolvedFileIcon = nil;
    if (resolvedIconPath && [fileManager fileExistsAtPath:resolvedIconPath]) {
        resolvedFileIcon = [[NSImage alloc] initWithContentsOfFile:resolvedIconPath];
    }

    if (resolvedBundleIcon) {
        // Keep the packaged app icon for Dock/Finder identity when available.
        [NSApp setApplicationIconImage:resolvedBundleIcon];
    } else if (resolvedFileIcon) {
        [NSApp setApplicationIconImage:resolvedFileIcon];
    }

    // Prefer a direct packaged/workspace icon file for the splash logo because
    // it is more reliable than bundle-icon lookup during early startup.
    self.appIconImage = resolvedFileIcon ?: resolvedBundleIcon;
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
    self.window.delegate = self;
    [self.window setMinSize:minSize];
    if (!prefersNarrowTallLayout && !self.enableNativeViewMenu) {
        [self.window center];
    }
    [self.window setTitle:[NSString stringWithFormat:@"Wizardry - %@", appName]];
    [self.window setTitlebarAppearsTransparent:YES];
    [self.window setTitleVisibility:NSWindowTitleHidden];
    // Owl uses explicit side drag zones so tab clicks/drags never move the window.
    [self.window setMovableByWindowBackground:!prefersSideDragZones];
    if (self.enableNativeBootSplash && self.prioritiesBootBgColor) {
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
    if (config.preferences) {
        config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    }
    WKUserContentController *contentController = [[WKUserContentController alloc] init];
    [contentController addScriptMessageHandler:self name:@"wizardry"];
    WKUserScript *bridgeBootstrap =
        [[WKUserScript alloc] initWithSource:[self desktopBridgeBootstrapSource]
                               injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                            forMainFrameOnly:YES];
    [contentController addUserScript:bridgeBootstrap];
    config.userContentController = contentController;
    
    NSView *rootView = [[NSView alloc] initWithFrame:frame];
    self.hostRootView = rootView;
    [rootView setAutoresizesSubviews:YES];
    if (self.enableNativeBootSplash && self.prioritiesBootBgColor) {
        [rootView setWantsLayer:YES];
        rootView.layer.backgroundColor = [self.prioritiesBootBgColor CGColor];
    }

    CGFloat dragStripHeight = 44.0;
    NSRect webFrame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
    if (isForgeApp) {
        WizardryForgeWebView *forgeWebView = [[WizardryForgeWebView alloc] initWithFrame:webFrame configuration:config];
        forgeWebView.appDelegate = self;
        NSMutableArray<NSPasteboardType> *dragTypes = [NSMutableArray arrayWithArray:[NSImage imagePasteboardTypes]];
        if (![dragTypes containsObject:NSPasteboardTypeFileURL]) {
            [dragTypes addObject:NSPasteboardTypeFileURL];
        }
        [forgeWebView registerForDraggedTypes:dragTypes];
        self.webView = forgeWebView;
    } else {
        self.webView = [[WKWebView alloc] initWithFrame:webFrame configuration:config];
    }
    self.webView.UIDelegate = self;
    @try {
        // Avoid white intermediate paint by letting the themed host window color
        // show through until page styles apply.
        [self.webView setValue:@NO forKey:@"drawsBackground"];
    } @catch (NSException *exception) {
        (void)exception;
    }
    if (@available(macOS 11.0, *)) {
        self.webView.underPageBackgroundColor = self.prioritiesBootBgColor ?: [NSColor clearColor];
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
    } else if (self.enableHeaderDragHoles) {
        // Priorities and Headquarters need broad drag affordance in the top band,
        // but interactive controls (tabs + right controls) must remain clickable.
        if ([appSlug isEqualToString:@"headquarters"]) {
            self.prioritiesTitleHoleLeftWidth = 240.0;
            self.prioritiesTitleHoleRightWidth = 240.0;
            self.prioritiesRightControlsReservedWidth = 200.0;
        } else if ([appSlug isEqualToString:@"boycott"]) {
            CGFloat centerX = floor(frame.size.width / 2.0);
            self.prioritiesTitleHoleLeftWidth = MAX(0.0, centerX - 40.0);
            self.prioritiesTitleHoleRightWidth = MAX(0.0, frame.size.width - centerX);
            self.prioritiesRightControlsReservedWidth = 0.0;
        } else if ([appSlug isEqualToString:@"serenity"]) {
            self.prioritiesTitleHoleLeftWidth = 420.0;
            self.prioritiesTitleHoleRightWidth = 24.0;
            self.prioritiesRightControlsReservedWidth = 320.0;
        } else {
            self.prioritiesTitleHoleLeftWidth = 36.0;
            self.prioritiesTitleHoleRightWidth = 10.0;
            self.prioritiesRightControlsReservedWidth = 168.0;
        }

        self.prioritiesTopDragStrip = [[WizardryDragStripView alloc] initWithFrame:NSZeroRect];
        [self.prioritiesTopDragStrip setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [self.prioritiesTopDragStrip setWantsLayer:YES];
        self.prioritiesTopDragStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:self.prioritiesTopDragStrip];

        self.prioritiesLeftHeaderDragStrip = [[WizardryDragStripView alloc] initWithFrame:NSZeroRect];
        [self.prioritiesLeftHeaderDragStrip setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
        [self.prioritiesLeftHeaderDragStrip setWantsLayer:YES];
        self.prioritiesLeftHeaderDragStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:self.prioritiesLeftHeaderDragStrip];

        self.prioritiesRightHeaderDragStrip = [[WizardryDragStripView alloc] initWithFrame:NSZeroRect];
        [self.prioritiesRightHeaderDragStrip setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [self.prioritiesRightHeaderDragStrip setWantsLayer:YES];
        self.prioritiesRightHeaderDragStrip.layer.backgroundColor = [[NSColor clearColor] CGColor];
        [rootView addSubview:self.prioritiesRightHeaderDragStrip];

        [self layoutPrioritiesDragStrips];
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

    if (self.enableNativeBootSplash) {
        [self showNativeBootSplashInView:rootView];
    }

    [self.window setContentView:rootView];
    if (self.webView) {
        [self.window makeFirstResponder:self.webView];
    }

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
        if (self.webView) {
            [self.window makeFirstResponder:self.webView];
        }
        [NSApp unhide:nil];
        [NSApp activateIgnoringOtherApps:YES];
    });
    
    // Load the app HTML
    NSURL *url = [NSURL fileURLWithPath:indexPath];
    // Forge renders app/workspace icons from absolute file paths (often outside the
    // current app folder), so read access must include the broader filesystem tree.
    NSURL *allowDir = [NSURL fileURLWithPath:@"/" isDirectory:YES];
    [self.webView loadFileURL:url allowingReadAccessToURL:allowDir];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.webView) {
            [self.window makeFirstResponder:self.webView];
        }
    });
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
    [self executeCommand:command withId:messageId fromWebView:(message.webView ?: self.webView)];
}

- (void)executeCommand:(NSArray *)command withId:(NSString *)messageId fromWebView:(WKWebView *)sourceWebView {
    NSArray *commandCopy = [command copy];
    NSString *messageIdCopy = [messageId copy];
    WKWebView *sourceWebViewCopy = sourceWebView ?: self.webView;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *program = commandCopy[0];
        NSArray *args = (commandCopy.count > 1) ? [commandCopy subarrayWithRange:NSMakeRange(1, commandCopy.count - 1)] : @[];

        if ([program isEqualToString:@"__wizardry_host_open_window"]) {
            NSString *urlString = @"";
            NSString *windowTitle = self.window ? self.window.title : @"Wizardry";
            CGFloat width = 980.0;
            CGFloat height = 720.0;
            if (args.count >= 1) {
                urlString = [NSString stringWithFormat:@"%@", args[0]];
            }
            if (args.count >= 2) {
                windowTitle = [NSString stringWithFormat:@"%@", args[1]];
            }
            if (args.count >= 3) {
                double parsedWidth = [[NSString stringWithFormat:@"%@", args[2]] doubleValue];
                width = MAX(420.0, parsedWidth);
            }
            if (args.count >= 4) {
                double parsedHeight = [[NSString stringWithFormat:@"%@", args[3]] doubleValue];
                height = MAX(320.0, parsedHeight);
            }
            if (urlString.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"missing window URL" exitCode:1 error:nil];
                });
                return;
            }

            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"invalid window URL" exitCode:1 error:nil];
                });
                return;
            }

            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createAuxWindowWithConfiguration:nil
                                               request:request
                                           windowTitle:windowTitle
                                                 width:width
                                                height:height];
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"ok" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

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
                    [self layoutPrioritiesDragStrips];
                }
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
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
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
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
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
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
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
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
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
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
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:snapState stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_boot_ready"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideNativeBootSplash];
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_set_background_mode"]) {
            BOOL enabled = NO;
            BOOL wantsStatusItem = NO;
            if (args.count >= 1) {
                NSString *raw = [NSString stringWithFormat:@"%@", args[0]];
                enabled = [@[@"1", @"true", @"yes", @"on"] containsObject:[raw lowercaseString]];
            }
            if (args.count >= 2) {
                NSString *raw = [NSString stringWithFormat:@"%@", args[1]];
                wantsStatusItem = [@[@"1", @"true", @"yes", @"on"] containsObject:[raw lowercaseString]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self applyBackgroundModeEnabled:enabled showStatusItem:wantsStatusItem];
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_priorities_drag_hole"]) {
            CGFloat holeLeft = self.prioritiesTitleHoleLeftWidth;
            CGFloat holeRight = self.prioritiesTitleHoleRightWidth;
            CGFloat rightReserved = self.prioritiesRightControlsReservedWidth;
            if (args.count >= 1) {
                holeLeft = MAX(0.0, [args[0] doubleValue]);
            }
            if (args.count >= 2) {
                holeRight = MAX(0.0, [args[1] doubleValue]);
            }
            if (args.count >= 3) {
                rightReserved = MAX(0.0, [args[2] doubleValue]);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.prioritiesTitleHoleLeftWidth = holeLeft;
                self.prioritiesTitleHoleRightWidth = holeRight;
                self.prioritiesRightControlsReservedWidth = rightReserved;
                [self layoutPrioritiesDragStrips];
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_forge_workspace_drop_zone"]) {
            CGFloat left = 0.0;
            CGFloat top = 0.0;
            CGFloat right = 0.0;
            CGFloat bottom = 0.0;
            BOOL active = NO;
            if (args.count >= 4) {
                left = MAX(0.0, [args[0] doubleValue]);
                top = MAX(0.0, [args[1] doubleValue]);
                right = MAX(left, [args[2] doubleValue]);
                bottom = MAX(top, [args[3] doubleValue]);
                active = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.forgeWorkspaceDropZoneLeft = left;
                self.forgeWorkspaceDropZoneTop = top;
                self.forgeWorkspaceDropZoneRight = right;
                self.forgeWorkspaceDropZoneBottom = bottom;
                self.forgeWorkspaceDropZoneActive = active;
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_forge_icon_drop_zone"]) {
            CGFloat left = 0.0;
            CGFloat top = 0.0;
            CGFloat right = 0.0;
            CGFloat bottom = 0.0;
            BOOL active = NO;
            if (args.count >= 4) {
                left = MAX(0.0, [args[0] doubleValue]);
                top = MAX(0.0, [args[1] doubleValue]);
                right = MAX(left, [args[2] doubleValue]);
                bottom = MAX(top, [args[3] doubleValue]);
                active = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.forgeIconDropZoneLeft = left;
                self.forgeIconDropZoneTop = top;
                self.forgeIconDropZoneRight = right;
                self.forgeIconDropZoneBottom = bottom;
                self.forgeIconDropZoneActive = active;
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_forge_icon_drop_target"]) {
            NSString *rootHint = @"";
            NSString *itemKey = @"";
            NSString *targetKind = @"";
            NSString *targetValue = @"";
            NSString *shapeMode = @"squircle";
            if (args.count >= 5) {
                rootHint = [NSString stringWithFormat:@"%@", args[0]];
                itemKey = [NSString stringWithFormat:@"%@", args[1]];
                targetKind = [NSString stringWithFormat:@"%@", args[2]];
                targetValue = [NSString stringWithFormat:@"%@", args[3]];
                shapeMode = [NSString stringWithFormat:@"%@", args[4]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.forgeIconDropRootHint = rootHint;
                self.forgeIconDropItemKey = itemKey;
                self.forgeIconDropTargetKind = targetKind;
                self.forgeIconDropTargetValue = targetValue;
                self.forgeIconDropShapeMode = shapeMode;
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        if ([program isEqualToString:@"__wizardry_host_set_global_hotkey"]) {
            NSString *hotkey = @"";
            if (args.count >= 1) {
                hotkey = [NSString stringWithString:[NSString stringWithFormat:@"%@", args[0]]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *errorMessage = nil;
                BOOL ok = [self registerFavoriteTrackHotkey:hotkey errorMessage:&errorMessage];
                if (!ok) {
                    [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:@"" stderr:(errorMessage ?: @"hotkey registration failed") exitCode:1 error:nil];
                    return;
                }
                [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:hotkey stderr:@"" exitCode:0 error:nil];
            });
            return;
        }

        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/env";
        task.environment = [self resolvedCommandEnvironment];

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
                [self sendErrorToWebView:sourceWebViewCopy messageId:messageIdCopy message:[NSString stringWithFormat:@"Failed to launch: %@", exception.reason]];
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
            [self sendResultToWebView:sourceWebViewCopy messageId:messageIdCopy stdout:stdout stderr:stderr exitCode:exitCode error:nil];
        });
    });
}

- (void)sendResultToWebView:(WKWebView *)targetWebView
                   messageId:(NSString *)messageId
                      stdout:(NSString *)stdout
                      stderr:(NSString *)stderr
                    exitCode:(int)exitCode
                       error:(NSString *)error
{
    WKWebView *resolvedTarget = targetWebView ?: self.webView;
    if (!resolvedTarget) {
        return;
    }
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
    
    [resolvedTarget evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"Error evaluating JavaScript: %@", error);
        }
    }];
}

- (void)sendResult:(NSString *)messageId
            stdout:(NSString *)stdout
            stderr:(NSString *)stderr
          exitCode:(int)exitCode
             error:(NSString *)error
{
    [self sendResultToWebView:self.webView messageId:messageId stdout:stdout stderr:stderr exitCode:exitCode error:error];
}

- (void)sendErrorToWebView:(WKWebView *)targetWebView messageId:(NSString *)messageId message:(NSString *)message {
    [self sendResultToWebView:targetWebView messageId:messageId stdout:@"" stderr:@"" exitCode:-1 error:message];
}

- (void)sendError:(NSString *)messageId message:(NSString *)message {
    [self sendErrorToWebView:self.webView messageId:messageId message:message];
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
    (void)sender;
    return !self.keepRunningInBackground;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    if (!flag) {
        [self showMainWindow];
    }
    return YES;
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (self.keepRunningInBackground && sender == self.window) {
        [sender orderOut:nil];
        [self updateStatusItemVisibility];
        return NO;
    }
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    id object = notification.object;
    if (![object isKindOfClass:[NSWindow class]]) {
        return;
    }
    NSWindow *closingWindow = (NSWindow *)object;
    if (self.auxWindows && closingWindow != self.window) {
        [self.auxWindows removeObject:closingWindow];
    }
    [self updateStatusItemVisibility];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self clearFavoriteTrackHotkeyRegistration];
    if (self.favoriteTrackHotKeyHandlerRef) {
        RemoveEventHandler(self.favoriteTrackHotKeyHandlerRef);
        self.favoriteTrackHotKeyHandlerRef = NULL;
    }
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
