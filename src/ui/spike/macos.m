#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <mach/mach.h>
#import <stdbool.h>

extern const char *zigide_ui_build_mode(void);
extern size_t zigide_ui_search(const unsigned char *bytes, size_t length);

static double nowMs(void) {
    return NSProcessInfo.processInfo.systemUptime * 1000.0;
}

static void emit(NSDictionary *record) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

@interface Spike : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate,
                              WKNavigationDelegate, WKScriptMessageHandler>
@property NSWindow *window;
@property NSTextView *editor;
@property NSTextField *panel;
@property WKWebView *web;
@property NSData *fixture;
@property BOOL useWeb;
@property BOOL probe;
@property BOOL failed;
@property BOOL ready;
@property NSUInteger version;
@property NSUInteger operation;
@property double started;
@property double searchStarted;
@property double lastTick;
@property NSMutableArray<NSNumber *> *heartbeat;
@property NSTimer *timer;
@end

@implementation Spike

- (NSButton *)button:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.accessibilityLabel = title;
    return button;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 760)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                  NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = self.useWeb ? @"Zigide UI spike · WKWebView" : @"Zigide UI spike · AppKit";
    self.window.delegate = self;
    self.window.minSize = NSMakeSize(640, 480);
    [self.window center];
    if (self.useWeb) {
        WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
        [configuration.userContentController addScriptMessageHandler:self name:@"spike"];
        self.web = [[WKWebView alloc] initWithFrame:self.window.contentView.bounds
                                    configuration:configuration];
        self.web.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.web.navigationDelegate = self;
        [self.window.contentView addSubview:self.web];
        NSURL *url = [NSBundle.mainBundle URLForResource:@"web" withExtension:@"html"];
        if (!url) {
            self.failed = YES;
            emit(@{@"event": @"error", @"reason": @"Missing bundled web.html"});
            [NSApp terminate:nil];
            return;
        }
        [self.web loadFileURL:url allowingReadAccessToURL:url];
    } else {
        [self buildNativeViews];
    }
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    self.lastTick = nowMs();
    self.heartbeat = [NSMutableArray new];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        double tick = nowMs();
        if (self.heartbeat.count < 5000) [self.heartbeat addObject:@(tick - self.lastTick)];
        self.lastTick = tick;
    }];
    if (!self.useWeb) [self didBecomeReady];
    if (self.probe) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!self.ready) emit(@{@"event": @"error", @"reason": @"UI ready timeout"});
            self.failed = YES;
            [NSApp terminate:nil];
        });
    }
}

- (void)buildNativeViews {
    NSView *root = self.window.contentView;
    NSView *explorer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 220, 760)];
    explorer.autoresizingMask = NSViewHeightSizable;
    explorer.accessibilityRole = NSAccessibilityGroupRole;
    explorer.accessibilityLabel = @"Explorer";
    NSTextField *heading = [NSTextField labelWithString:@"Explorer"];
    heading.frame = NSMakeRect(18, 706, 185, 24);
    heading.autoresizingMask = NSViewMinYMargin;
    NSButton *file = [self button:@"fixture.zig" action:@selector(focusEditor:)];
    file.frame = NSMakeRect(18, 664, 185, 30);
    file.autoresizingMask = NSViewMinYMargin;
    NSButton *search = [self button:@"Search needle" action:@selector(search:)];
    search.frame = NSMakeRect(18, 622, 185, 30);
    search.autoresizingMask = NSViewMinYMargin;
    [explorer addSubview:heading];
    [explorer addSubview:file];
    [explorer addSubview:search];
    [root addSubview:explorer];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(220, 140, 880, 620)];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.accessibilityLabel = @"Editor scrolling region";
    self.editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 880, 620)];
    self.editor.font = [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightRegular];
    self.editor.richText = NO;
    self.editor.automaticQuoteSubstitutionEnabled = NO;
    self.editor.automaticDashSubstitutionEnabled = NO;
    self.editor.automaticSpellingCorrectionEnabled = NO;
    self.editor.automaticTextReplacementEnabled = NO;
    self.editor.textContainerInset = NSMakeSize(16, 16);
    self.editor.verticallyResizable = YES;
    self.editor.horizontallyResizable = YES;
    self.editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    self.editor.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    self.editor.textContainer.widthTracksTextView = NO;
    self.editor.autoresizingMask = NSViewWidthSizable;
    self.editor.accessibilityLabel = @"Zig source editor";
    self.editor.string = [[NSString alloc] initWithData:self.fixture encoding:NSUTF8StringEncoding];
    self.editor.delegate = self;
    scroll.documentView = self.editor;
    [root addSubview:scroll];

    self.panel = [NSTextField labelWithString:@"Search results\nWaiting for background search"];
    self.panel.frame = NSMakeRect(236, 16, 848, 108);
    self.panel.autoresizingMask = NSViewWidthSizable;
    self.panel.accessibilityLabel = @"Search results";
    self.panel.selectable = YES;
    [root addSubview:self.panel];
    file.nextKeyView = search;
    search.nextKeyView = self.editor;
    self.editor.nextKeyView = self.panel;
    self.panel.nextKeyView = file;
    [self.window makeFirstResponder:self.editor];
}

- (void)didBecomeReady {
    if (self.ready) return;
    self.ready = YES;
    emit(@{@"event": @"ready", @"candidate": self.useWeb ? @"webview" : @"appkit",
           @"startup_ms": @(nowMs() - self.started), @"fixture_bytes": @(self.fixture.length),
           @"scale": @(self.window.backingScaleFactor),
           @"build_mode": [NSString stringWithUTF8String:zigide_ui_build_mode()]});
    if (self.probe) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            struct mach_task_basic_info idle;
            mach_msg_type_number_t idleCount = MACH_TASK_BASIC_INFO_COUNT;
            if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&idle, &idleCount) == KERN_SUCCESS) {
                emit(@{@"event": @"idle_memory", @"host_rss_bytes": @(idle.resident_size)});
            }
            if (self.useWeb) {
                [self.web evaluateJavaScript:@"window.spikeProbe()" completionHandler:^(id value, NSError *error) {
                    NSDictionary *checks = [value isKindOfClass:NSDictionary.class] ? value : @{};
                    BOOL passed = !error && [checks[@"selection"] boolValue] &&
                        [checks[@"deferred"] boolValue] && [checks[@"committed"] boolValue] &&
                        [checks[@"stale"] boolValue];
                    self.failed |= !passed;
                    emit(@{@"event": @"web_contract_probe", @"passed": @(passed), @"checks": checks});
                    [self search:nil];
                }];
            } else {
                [self probeNative];
                [self search:nil];
            }
        });
    } else {
        [self search:nil];
    }
}

- (void)probeNative {
    NSString *original = [self.editor.string copy];
    NSString *sample = @"café 😀\n日本語\né\n";
    self.editor.string = sample;
    self.editor.selectedRange = NSMakeRange(0, sample.length);
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    [pasteboard declareTypes:self.editor.writablePasteboardTypes owner:nil];
    BOOL copied = [self.editor writeSelectionToPasteboard:pasteboard types:self.editor.writablePasteboardTypes];
    self.editor.string = @"";
    self.editor.selectedRange = NSMakeRange(0, 0);
    BOOL pasted = [self.editor readSelectionFromPasteboard:pasteboard];
    BOOL clipboard = copied && pasted && [self.editor.string isEqualToString:sample];
    [pasteboard releaseGlobally];

    self.editor.string = @"prefix suffix";
    self.editor.selectedRange = NSMakeRange(7, 0);
    [self.editor setMarkedText:@"に" selectedRange:NSMakeRange(1, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    BOOL marked = self.editor.hasMarkedText && self.editor.markedRange.length == 1;
    [self.editor setMarkedText:@"日本" selectedRange:NSMakeRange(2, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    BOOL updated = self.editor.hasMarkedText && self.editor.markedRange.length == 2;
    [self.editor insertText:@"日本語" replacementRange:NSMakeRange(NSNotFound, 0)];
    BOOL committed = !self.editor.hasMarkedText && [self.editor.string isEqualToString:@"prefix 日本語suffix"];
    [self.editor setMarkedText:@"未確定" selectedRange:NSMakeRange(3, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    [self.editor setMarkedText:@"" selectedRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    [self.editor unmarkText];
    BOOL cancelled = !self.editor.hasMarkedText && [self.editor.string isEqualToString:@"prefix 日本語suffix"];
    BOOL label = [self.editor.accessibilityLabel isEqualToString:@"Zig source editor"] &&
        [self.editor.accessibilityValue isEqualToString:self.editor.string];
    self.editor.string = original;
    double start = nowMs();
    for (NSUInteger index = 0; index < 120; index++) {
        [self.editor scrollRangeToVisible:NSMakeRange(index % 2 ? original.length - 1 : 0, 0)];
        [self.editor displayIfNeeded];
    }
    double scrollMs = nowMs() - start;
    BOOL passed = clipboard && marked && updated && committed && cancelled && label;
    self.failed |= !passed;
    emit(@{@"event": @"native_contract_probe", @"passed": @(passed), @"clipboard": @(clipboard), @"copied": @(copied), @"pasted": @(pasted),
           @"marked": @(marked), @"updated": @(updated), @"committed": @(committed),
           @"cancelled": @(cancelled), @"accessibility_value": @(label), @"scroll_ms": @(scrollMs)});
}

- (void)focusEditor:(id)sender {
    (void)sender;
    [self.window makeFirstResponder:self.editor];
}

- (void)textDidChange:(NSNotification *)notification {
    (void)notification;
    if (!self.editor.hasMarkedText) self.version += 1;
}

- (void)search:(id)sender {
    (void)sender;
    NSUInteger version = self.version;
    NSUInteger operation = ++self.operation;
    self.searchStarted = nowMs();
    // This spike searches the immutable common fixture, never mutable view storage.
    NSData *snapshot = self.fixture;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        size_t matches = zigide_ui_search(snapshot.bytes, snapshot.length);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (version != self.version || operation != self.operation || self.editor.hasMarkedText) return;
            if (self.useWeb) {
                NSString *script = [NSString stringWithFormat:@"window.spikeResult(%lu, %zu)",
                                    (unsigned long)version, matches];
                [self.web evaluateJavaScript:script completionHandler:^(id value, NSError *error) {
                    if (error) {
                        self.failed = YES;
                        emit(@{@"event": @"error", @"reason": error.localizedDescription});
                    } else if ([value boolValue]) {
                        [self resultDelivered:matches];
                    }
                }];
            } else {
                self.panel.stringValue = [NSString stringWithFormat:@"Search results\n%zu matches · version %lu",
                                         matches, (unsigned long)version];
                NSAccessibilityPostNotification(self.panel, NSAccessibilityValueChangedNotification);
                [self resultDelivered:matches];
            }
        });
    });
}

- (void)resultDelivered:(size_t)matches {
    self.failed |= self.probe && matches != 100000;
    emit(@{@"event": @"background_result", @"matches": @(matches),
           @"delivery_ms": @(nowMs() - self.searchStarted)});
    if (self.probe) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSArray<NSNumber *> *sorted = [self.heartbeat sortedArrayUsingSelector:@selector(compare:)];
            struct mach_task_basic_info memory;
            mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
            kern_return_t status = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&memory, &count);
            emit(@{@"event": @"metrics", @"heartbeat_samples": @(sorted.count),
                   @"heartbeat_p95_ms": sorted.count ? sorted[(sorted.count - 1) * 95 / 100] : @0,
                   @"heartbeat_max_ms": sorted.lastObject ?: @0,
                   @"host_rss_bytes": status == KERN_SUCCESS ? @(memory.resident_size) : @0,
                   @"passed": @(!self.failed)});
            [NSApp terminate:nil];
        });
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)navigation;
    NSString *text = [[NSString alloc] initWithData:self.fixture encoding:NSUTF8StringEncoding];
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[text] options:0 error:nil];
    NSString *array = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSString *script = [NSString stringWithFormat:@"window.spikeLoad(%@[0])", array];
    [webView evaluateJavaScript:script completionHandler:^(id value, NSError *error) {
        (void)value;
        if (error) {
            self.failed = YES;
            emit(@{@"event": @"error", @"reason": error.localizedDescription});
            [NSApp terminate:nil];
        }
    }];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    (void)webView;
    decisionHandler(action.request.URL.isFileURL ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    (void)webView;
    (void)navigation;
    self.failed = YES;
    emit(@{@"event": @"error", @"reason": error.localizedDescription});
    [NSApp terminate:nil];
}

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = message.body;
    NSString *type = body[@"type"];
    if (![type isKindOfClass:NSString.class]) return;
    if ([type isEqualToString:@"ready"]) {
        [self didBecomeReady];
    } else if ([type isEqualToString:@"edit"] || [type isEqualToString:@"search"]) {
        NSNumber *version = body[@"version"];
        if (![version isKindOfClass:NSNumber.class] || version.longLongValue < 0) return;
        self.version = version.unsignedIntegerValue;
        if ([type isEqualToString:@"search"]) [self search:nil];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    (void)application;
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.timer invalidate];
    self.operation += 1;
    [self.web.configuration.userContentController removeScriptMessageHandlerForName:@"spike"];
}
@end

static void installMenu(void) {
    NSMenu *menu = [NSMenu new];
    NSMenuItem *appItem = [NSMenuItem new];
    [menu addItem:appItem];
    NSMenu *appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"Quit UI spike" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    NSMenuItem *editItem = [NSMenuItem new];
    editItem.title = @"Edit";
    [menu addItem:editItem];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = edit;
    NSApp.mainMenu = menu;
}

size_t zigide_ui_fixture_lines(void) {
    return [NSBundle.mainBundle.infoDictionary[@"ZigideSpikeInputFixture"] boolValue] ? 32 : 100000;
}

int zigide_ui_run(const unsigned char *bytes, size_t length, bool web, bool probe) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        installMenu();
        Spike *spike = [Spike new];
        spike.fixture = [NSData dataWithBytes:bytes length:length];
        spike.useWeb = web || [NSBundle.mainBundle.infoDictionary[@"ZigideSpikeCandidate"] isEqualToString:@"webview"];
        spike.probe = probe;
        spike.started = nowMs();
        NSApp.delegate = spike;
        [NSApp run];
        return spike.failed ? 1 : 0;
    }
}
