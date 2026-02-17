// Wizardry Desktop Host - macOS native WebView wrapper
// Minimal Objective-C implementation using Cocoa + WebKit
// Build: clang -O2 -fobjc-arc -fmodules main.m -o wizardry-host -framework Cocoa -framework WebKit

@import Cocoa;
@import WebKit;

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler>
@property (strong) NSWindow *window;
@property (strong) WKWebView *webView;
@property (strong) NSString *appPath;
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

    [NSApp setWindowsMenu:windowMenu];
    [NSApp setMainMenu:mainMenu];
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

    [self setupMainMenuWithAppName:appName];
    [NSApp activateIgnoringOtherApps:YES];
    
    // Create window
    NSRect frame = NSMakeRect(0, 0, 1024, 768);
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled | 
                                   NSWindowStyleMaskClosable | 
                                   NSWindowStyleMaskMiniaturizable |
                                   NSWindowStyleMaskResizable;
    
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:styleMask
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:[NSString stringWithFormat:@"Wizardry - %@", appName]];
    [self.window makeKeyAndOrderFront:nil];
    
    // Create WebView with message handler
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *contentController = [[WKUserContentController alloc] init];
    [contentController addScriptMessageHandler:self name:@"wizardry"];
    config.userContentController = contentController;
    
    self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    [self.window setContentView:self.webView];
    
    // Load the app HTML
    NSURL *url = [NSURL fileURLWithPath:indexPath];
    NSURL *allowDir = [NSURL fileURLWithPath:self.appPath];
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
    NSString *program = command[0];
    NSArray *args = (command.count > 1) ? [command subarrayWithRange:NSMakeRange(1, command.count - 1)] : @[];
    
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
        [self sendError:messageId message:[NSString stringWithFormat:@"Failed to launch: %@", exception.reason]];
        return;
    }
    
    [task waitUntilExit];
    
    NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
    
    NSString *stdout = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
    NSString *stderr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @"";
    int exitCode = [task terminationStatus];
    
    [self sendResult:messageId stdout:stdout stderr:stderr exitCode:exitCode error:nil];
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
