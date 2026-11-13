#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <sqlite3.h>
extern int history_open(const char *, sqlite3 **);
extern int history_add(sqlite3 *, const char *, const char *);

static NSURL *Destination(NSString *input) {
    NSString *s = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!s.length) return nil;
    if ([s containsString:@"://"]) {
        NSURL *url = [NSURL URLWithString:s];
        return ([@[@"http", @"https"] containsObject:url.scheme.lowercaseString] && url.host.length) ? url : nil;
    }
    if (![s containsString:@" "] && ([s containsString:@"."] || [s hasPrefix:@"localhost"] || [s hasPrefix:@"["])) {
        BOOL local = [s hasPrefix:@"localhost"] || [s hasPrefix:@"127."] || [s hasPrefix:@"[::1]"];
        return [NSURL URLWithString:[(local ? @"http://" : @"https://") stringByAppendingString:s]];
    }
    NSURLComponents *c = [NSURLComponents componentsWithString:@"https://duckduckgo.com/"];
    c.queryItems = @[[NSURLQueryItem queryItemWithName:@"q" value:s]];
    return c.URL;
}

@interface Browser : NSObject <NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property NSWindow *window;
@property WKWebView *web;
@property NSTextField *address;
@property NSTextField *status;
@property NSButton *back;
@property NSButton *forward;
@property NSPanel *historyPanel;
@property NSSearchField *search;
@property NSTableView *table;
@property NSArray<NSDictionary *> *rows;
@property NSMutableSet<NSWindow *> *popups;
@property sqlite3 *db;
@end
@implementation Browser
- (NSButton *)button:(NSString *)title action:(SEL)action {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:action];
    b.bezelStyle = NSBezelStyleTexturedRounded;
    return b;
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Oogabooga"];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error] || history_open([[dir stringByAppendingPathComponent:@"history.sqlite3"] fileSystemRepresentation], &_db)) {
        NSAlert *a = [NSAlert new]; a.messageText = @"Could not open browsing history";
        a.informativeText = error.localizedDescription ?: @"Check that your Application Support folder is writable.";
        [a runModal]; [NSApp terminate:nil]; return;
    }
    self.popups = [NSMutableSet set];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1160,780) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Oogabooga"; [self.window center];
    NSView *root = self.window.contentView;
    self.back = [self button:@"←" action:@selector(goBack:)]; self.forward = [self button:@"→" action:@selector(goForward:)];
    NSButton *reload = [self button:@"↻" action:@selector(reload:)];
    self.address = [NSTextField new]; self.address.placeholderString = @"Search or enter address";
    self.address.target = self; self.address.action = @selector(navigate:);
    NSButton *history = [self button:@"History" action:@selector(showHistory:)];
    NSStackView *bar = [NSStackView stackViewWithViews:@[self.back,self.forward,reload,self.address,history]];
    bar.spacing = 8; bar.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    [self.address setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    self.web = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:config];
    self.web.navigationDelegate = self; self.web.UIDelegate = self; self.web.allowsBackForwardNavigationGestures = YES;
    self.status = [NSTextField labelWithString:@"Ready"];
    self.status.font = [NSFont systemFontOfSize:11]; self.status.textColor = NSColor.secondaryLabelColor;
    for (NSView *v in @[bar,self.web,self.status]) { v.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:v]; }
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:root.topAnchor constant:10], [bar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:12], [bar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-12], [bar.heightAnchor constraintEqualToConstant:30],
        [self.web.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:10], [self.web.leadingAnchor constraintEqualToAnchor:root.leadingAnchor], [self.web.trailingAnchor constraintEqualToAnchor:root.trailingAnchor], [self.web.bottomAnchor constraintEqualToAnchor:self.status.topAnchor constant:-4],
        [self.status.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:12], [self.status.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-12], [self.status.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-5], [self.status.heightAnchor constraintEqualToConstant:16]
    ]];
    [self makeMenus]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    NSString *initial = NSProcessInfo.processInfo.arguments.count > 1 ? NSProcessInfo.processInfo.arguments[1] : @"https://example.com";
    self.address.stringValue = initial; [self navigate:nil];
}
- (void)makeMenus {
    NSMenu *menu = [NSMenu new]; NSMenuItem *app = [NSMenuItem new]; [menu addItem:app]; app.submenu = [NSMenu new];
    [app.submenu addItemWithTitle:@"Quit Oogabooga" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *edit = [NSMenuItem new]; edit.title = @"Edit"; edit.submenu = [NSMenu new]; [menu addItem:edit];
    NSArray *titles = @[@"Undo",@"Cut",@"Copy",@"Paste",@"Select All"];
    NSArray *actions = @[@"undo:",@"cut:",@"copy:",@"paste:",@"selectAll:"];
    NSArray *keys = @[@"z",@"x",@"c",@"v",@"a"];
    for (NSUInteger i=0;i<titles.count;i++) [edit.submenu addItemWithTitle:titles[i] action:NSSelectorFromString(actions[i]) keyEquivalent:keys[i]];
    NSMenuItem *nav = [NSMenuItem new]; nav.title = @"Navigate"; nav.submenu = [NSMenu new]; [menu addItem:nav];
    NSArray *nt = @[@"Open Location",@"Reload",@"Back",@"Forward",@"History"];
    NSArray *na = @[@"focusAddress:",@"reload:",@"goBack:",@"goForward:",@"showHistory:"];
    NSArray *nk = @[@"l",@"r",@"[",@"]",@"y"];
    for (NSUInteger i=0;i<nt.count;i++) { NSMenuItem *item = [nav.submenu addItemWithTitle:nt[i] action:NSSelectorFromString(na[i]) keyEquivalent:nk[i]]; item.target = self; }
    NSApp.mainMenu = menu;
}
- (void)focusAddress:(id)sender { [self.window makeFirstResponder:self.address]; [self.address selectText:nil]; }
- (void)navigate:(id)sender { NSURL *u = Destination(self.address.stringValue); if (u) [self.web loadRequest:[NSURLRequest requestWithURL:u]]; else self.status.stringValue = @"Enter an HTTP(S) address or search terms."; }
- (void)goBack:(id)sender { [self.web goBack]; }
- (void)goForward:(id)sender { [self.web goForward]; }
- (void)reload:(id)sender { if (self.web.loading) [self.web stopLoading]; else [self.web reload]; }
- (void)sync:(WKWebView *)web {
    if (web != self.web) return;
    if (web.URL) self.address.stringValue = web.URL.absoluteString;
    self.back.enabled = web.canGoBack; self.forward.enabled = web.canGoForward;
    self.window.title = web.title.length ? [web.title stringByAppendingString:@" — Oogabooga"] : @"Oogabooga";
}
- (void)webView:(WKWebView *)web didStartProvisionalNavigation:(WKNavigation *)nav { if (web == self.web) self.status.stringValue = @"Loading…"; }
- (void)webView:(WKWebView *)web didCommitNavigation:(WKNavigation *)nav { [self sync:web]; }
- (void)webView:(WKWebView *)web didFinishNavigation:(WKNavigation *)nav {
    [self sync:web];
    if ([@[@"http",@"https"] containsObject:web.URL.scheme.lowercaseString]) {
        int rc = history_add(self.db, web.URL.absoluteString.UTF8String, (web.title ?: @"").UTF8String);
        if (web == self.web) self.status.stringValue = rc ? @"Page loaded; history could not be saved." : @"Ready";
    }
}
- (void)failed:(WKWebView *)web error:(NSError *)error { if (web == self.web && error.code != NSURLErrorCancelled) self.status.stringValue = error.localizedDescription; }
- (void)webView:(WKWebView *)web didFailNavigation:(WKNavigation *)nav withError:(NSError *)error { [self failed:web error:error]; }
- (void)webView:(WKWebView *)web didFailProvisionalNavigation:(WKNavigation *)nav withError:(NSError *)error { [self failed:web error:error]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)web { if (web == self.web) self.status.stringValue = @"Page process stopped. Press ⌘R to reload."; }
- (void)webView:(WKWebView *)web decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))done {
    NSString *scheme = action.request.URL.scheme.lowercaseString;
    // No implicit launches of external applications or script/file URLs from the address bar.
    done(([@[@"http",@"https",@"about"] containsObject:scheme]) ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}
- (void)webView:(WKWebView *)web didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))done {
    NSString *method = challenge.protectionSpace.authenticationMethod;
    if (![@[NSURLAuthenticationMethodHTTPBasic,NSURLAuthenticationMethodHTTPDigest,NSURLAuthenticationMethodNTLM] containsObject:method]) { done(NSURLSessionAuthChallengePerformDefaultHandling,nil); return; }
    if (challenge.previousFailureCount >= 3) { done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil); return; }
    NSAlert *a = [NSAlert new]; a.messageText = @"Sign in";
    a.informativeText = [NSString stringWithFormat:@"%@://%@\n%@",challenge.protectionSpace.protocol,challenge.protectionSpace.host, challenge.previousFailureCount ? @"Credentials were rejected. Try again." : @"Enter your username and password."];
    [a addButtonWithTitle:@"Sign In"]; [a addButtonWithTitle:@"Cancel"];
    NSTextField *user = [NSTextField new]; user.placeholderString = @"Username";
    NSSecureTextField *pass = [NSSecureTextField new]; pass.placeholderString = @"Password";
    NSStackView *fields = [NSStackView stackViewWithViews:@[user,pass]]; fields.orientation = NSUserInterfaceLayoutOrientationVertical; fields.frame = NSMakeRect(0,0,300,60); fields.alignment = NSLayoutAttributeWidth;
    a.accessoryView = fields;
    [a beginSheetModalForWindow:web.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) done(NSURLSessionAuthChallengeUseCredential,[NSURLCredential credentialWithUser:user.stringValue password:pass.stringValue persistence:NSURLCredentialPersistenceForSession]);
        else done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);
    }];
}
- (WKWebView *)webView:(WKWebView *)web createWebViewWithConfiguration:(WKWebViewConfiguration *)config forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features {
    // Preserve WebKit's supplied configuration and window.opener for OAuth popups.
    WKWebView *popup = [[WKWebView alloc] initWithFrame:NSMakeRect(0,0,700,720) configuration:config];
    popup.navigationDelegate = self; popup.UIDelegate = self;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:popup.frame styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    w.releasedWhenClosed = NO; w.title = @"Oogabooga — New Window"; w.contentView = popup;
    [self.popups addObject:w];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(popupClosed:) name:NSWindowWillCloseNotification object:w];
    [w center]; [w makeKeyAndOrderFront:nil]; return popup;
}
- (void)popupClosed:(NSNotification *)note { [NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowWillCloseNotification object:note.object]; [self.popups removeObject:note.object]; }
- (void)webViewDidClose:(WKWebView *)web { if (web != self.web) [web.window close]; }
- (void)webView:(WKWebView *)web runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))done {
    NSAlert *a = [NSAlert new]; a.messageText = frame.request.URL.host ?: @"Page"; a.informativeText = message;
    [a beginSheetModalForWindow:web.window completionHandler:^(NSModalResponse r) { done(); }];
}
- (void)webView:(WKWebView *)web runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))done {
    NSAlert *a = [NSAlert new]; a.messageText = frame.request.URL.host ?: @"Page"; a.informativeText = message; [a addButtonWithTitle:@"OK"]; [a addButtonWithTitle:@"Cancel"];
    [a beginSheetModalForWindow:web.window completionHandler:^(NSModalResponse r) { done(r == NSAlertFirstButtonReturn); }];
}
- (void)webView:(WKWebView *)web runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)text initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))done {
    NSAlert *a = [NSAlert new]; a.messageText = frame.request.URL.host ?: @"Page"; a.informativeText = prompt; [a addButtonWithTitle:@"OK"]; [a addButtonWithTitle:@"Cancel"];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,300,24)]; field.stringValue = text ?: @""; a.accessoryView = field;
    [a beginSheetModalForWindow:web.window completionHandler:^(NSModalResponse r) { done(r == NSAlertFirstButtonReturn ? field.stringValue : nil); }];
}
- (void)showHistory:(id)sender {
    if (!self.historyPanel) {
        self.historyPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,850,480) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
        self.historyPanel.title = @"History — double-click to open";
        NSView *root = self.historyPanel.contentView;
        self.search = [[NSSearchField alloc] initWithFrame:NSMakeRect(12,440,826,28)]; self.search.autoresizingMask = NSViewWidthSizable|NSViewMinYMargin; self.search.placeholderString = @"Search history"; self.search.target = self; self.search.action = @selector(refreshHistory:); [root addSubview:self.search];
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(12,12,826,416)]; scroll.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable; scroll.hasVerticalScroller = YES;
        self.table = [NSTableView new]; self.table.dataSource = self; self.table.delegate = self; self.table.target = self; self.table.doubleAction = @selector(openHistory:);
        for (NSString *key in @[@"title",@"url",@"date"]) { NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:key]; c.title = key.capitalizedString; c.width = [key isEqual:@"url"] ? 390 : 200; [self.table addTableColumn:c]; }
        scroll.documentView = self.table; [root addSubview:scroll]; [self.historyPanel center];
    }
    [self refreshHistory:nil]; [self.historyPanel makeKeyAndOrderFront:nil];
}
- (void)refreshHistory:(id)sender {
    sqlite3_stmt *stmt = NULL;
    NSMutableArray *rows = [NSMutableArray array];
    const char *sql = "SELECT title,url,datetime(visited_at,'unixepoch','localtime') FROM visits WHERE instr(lower(url),lower(?1)) OR instr(lower(title),lower(?1)) ORDER BY visited_at DESC,id DESC LIMIT 1000";
    if (sqlite3_prepare_v2(self.db,sql,-1,&stmt,NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt,1,self.search.stringValue.UTF8String,-1,SQLITE_TRANSIENT);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSMutableDictionary *r = [NSMutableDictionary dictionary]; int i=0;
            for (NSString *key in @[@"title",@"url",@"date"]) { const char *v = (const char *)sqlite3_column_text(stmt,i++); r[key] = v ? [NSString stringWithUTF8String:v] : @""; }
            [rows addObject:r];
        }
    }
    sqlite3_finalize(stmt); self.rows = rows; [self.table reloadData];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table { return self.rows.count; }
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row { return self.rows[row][column.identifier]; }
- (void)openHistory:(id)sender { NSInteger row = self.table.clickedRow; if (row < 0 || row >= (NSInteger)self.rows.count) return; self.address.stringValue = self.rows[row][@"url"]; [self navigate:nil]; [self.window makeKeyAndOrderFront:nil]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return YES; }
- (void)applicationWillTerminate:(NSNotification *)note { if (self.db) sqlite3_close(self.db); }
@end

int browser_main(int argc, const char **argv) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        Browser *browser = [Browser new]; app.delegate = browser; [app run];
    }
    return 0;
}
