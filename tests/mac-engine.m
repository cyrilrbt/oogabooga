// Test-only in-process transport and native-view integration for the assembly engine.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sqlite3.h>
#include <assert.h>
extern Class mac_register_class(void);
extern void mac_engine_toggle(id,SEL,id);
extern void mac_engine_navigate(void);
extern void mac_engine_back(void);
extern void mac_engine_forward(void);
extern void mac_engine_complete(id,SEL,id,id,NSError *);
extern int history_open(const char *, sqlite3 **);
extern __unsafe_unretained id mac_app,mac_delegate;
extern __unsafe_unretained NSWindow *mac_window;
extern __unsafe_unretained WKWebView *mac_web;
extern __unsafe_unretained NSTextField *mac_address,*mac_status;
extern __unsafe_unretained NSButton *mac_back,*mac_forward;
extern sqlite3 *mac_db;
extern uint64_t mac_engine_enabled;
// The renderer must work without a WebKit instance; only engine switching touches this stub.
@interface EngineWebStub : NSView
- (void)stopLoading;
@end
@implementation EngineWebStub
- (void)stopLoading {}
@end
@interface EngineProtocol : NSURLProtocol
@end
@implementation EngineProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqual:@"engine.test"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSString *path=self.request.URL.path;
    NSDictionary *headers=@{@"Content-Type":@"text/html; charset=utf-8"};
    NSInteger status=200;
    NSString *html=@"<title>First</title><h1>Hello 🌐</h1><p><a href='/second?a=1&amp;b=2'>next café</a> <a href='javascript:alert(1)'>bad link</a></p><script>SHOULD NOT RENDER</script>";
    if ([path isEqual:@"/css"]) html=@"<html><body><style>body{color:#123456;background:#faf5ed;font-family:Arial,sans-serif;line-height:1.5}h1{font-size:32px;color:#2450aa}.card{background:#fff2cc;color:red}#notice{color:green}.hide{display:none}a{color:inherit;text-decoration:none}</style><title>CSS</title><h1>Styled 🌐 heading</h1><p id=notice class=card style='margin:12px 14px 16px 18px;text-align:center'>Colored <span style='font-weight:700;font-style:italic'>nested</span><span class=hide>INVISIBLE🌐</span><a href='/second'>styled link</a></p></body></html>";
    if ([path isEqual:@"/second"]) html=@"<title>Second</title><p>Second page</p>";
    if ([path isEqual:@"/latin1"] || [path isEqual:@"/expanded"]) headers=@{@"Content-Type":@"text/html; charset=ISO-8859-1"};
    if ([path isEqual:@"/plain"]) headers=@{@"Content-Type":@"application/json"};
    if ([path isEqual:@"/large"]) headers=@{@"Content-Type":@"text/html",@"Content-Length":@"1048577"};
    if ([path isEqual:@"/missing"]) status=404;
    if ([path isEqual:@"/long"]) {
        NSMutableString *s=[NSMutableString stringWithString:@"<title>Long</title>"];
        for(int i=0;i<120;i++) [s appendFormat:@"<p>Paragraph %d with wrapped text for scrolling.</p>",i];
        html=s;
    }
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    NSData *data=[html dataUsingEncoding:NSUTF8StringEncoding];
    if ([path isEqual:@"/latin1"]) { const char legacy[]="<title>Legacy</title><p>caf\xe9 \x93hello\x94 \x80</p>"; data=[NSData dataWithBytes:legacy length:sizeof(legacy)-1]; }
    if ([path isEqual:@"/expanded"]) { NSMutableData *large=[NSMutableData dataWithLength:600000]; memset(large.mutableBytes,0x80,large.length); data=large; }
    if ([path isEqual:@"/stream"]) data=[NSMutableData dataWithLength:1048577];
    if ([path isEqual:@"/encoding"]) { unsigned char bad[]={0xff,0xfe,0xff}; data=[NSData dataWithBytes:bad length:sizeof(bad)]; }
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
static id (*originalConfiguration)(id,SEL);
static id config(id cls,SEL cmd) {
    NSURLSessionConfiguration *c=originalConfiguration(cls,cmd);
    c.URLCache=nil;
    c.protocolClasses=@[EngineProtocol.class];
    c.HTTPCookieStorage=nil;
    return c;
}
static void waitFor(BOOL (^condition)(void)) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while(!condition() && deadline.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    if(!condition()) { NSLog(@"Engine state: %@ / %@",mac_window.title,mac_status.stringValue); abort(); }
}
static void navigate(NSString *path) {
    mac_address.stringValue=[@"https://engine.test" stringByAppendingString:path];
    mac_engine_navigate();
}
static int count(void) {
    sqlite3_stmt *s=NULL; assert(sqlite3_prepare_v2(mac_db,"SELECT count(*) FROM visits",-1,&s,NULL)==SQLITE_OK);
    assert(sqlite3_step(s)==SQLITE_ROW); int result=sqlite3_column_int(s,0); sqlite3_finalize(s); return result;
}
int main(void) {
    @autoreleasepool {
        NSApplication *app=NSApplication.sharedApplication;
        id delegate=[[mac_register_class() alloc] init];
        NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1160,780) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed=NO;
        NSTextField *address=[NSTextField new],*status=[NSTextField new];
        NSButton *back=[NSButton new],*forward=[NSButton new];
        EngineWebStub *web=[[EngineWebStub alloc] initWithFrame:NSZeroRect];
        mac_app=app;mac_delegate=delegate;mac_window=window;mac_address=address;mac_status=status;mac_back=back;mac_forward=forward;mac_web=(WKWebView *)(id)web;
        assert(history_open(":memory:",&mac_db)==SQLITE_OK);
        Method method=class_getClassMethod(NSURLSessionConfiguration.class,@selector(ephemeralSessionConfiguration));
        originalConfiguration=(id (*)(id,SEL))method_getImplementation(method);
        IMP original=method_setImplementation(method,(IMP)config);
        address.stringValue=@"https://engine.test/first";
        mac_engine_toggle(nil,NULL,nil);
        waitFor(^BOOL { return [window.title hasPrefix:@"First — Assembly"]; });
        assert(mac_engine_enabled && web.hidden && count()==1);
        NSScrollView *scroll=(NSScrollView *)window.contentView.subviews.lastObject;
        NSTextView *text=(NSTextView *)scroll.documentView;
        assert([text.string containsString:@"Hello 🌐"] && ![text.string containsString:@"SHOULD NOT RENDER"]);
        NSRange link=[text.string rangeOfString:@"next café"];
        NSURL *target=[text.textStorage attribute:NSLinkAttributeName atIndex:link.location effectiveRange:NULL];
        assert([target.absoluteString isEqual:@"https://engine.test/second?a=1&b=2"]);
        NSRange bad=[text.string rangeOfString:@"bad link"];
        assert(![text.textStorage attribute:NSLinkAttributeName atIndex:bad.location effectiveRange:NULL]);
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert(count()==2 && back.enabled && !forward.enabled);
        mac_engine_back(); waitFor(^BOOL { return [window.title hasPrefix:@"First — Assembly"]; });
        assert(forward.enabled);
        mac_engine_forward(); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        navigate(@"/latin1"); waitFor(^BOOL { return [window.title hasPrefix:@"Legacy — Assembly"]; });
        assert([text.string containsString:@"café “hello” €"]);
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        int before=count();
        NSArray *paths=@[@"/plain",@"/large",@"/stream",@"/expanded",@"/missing",@"/encoding"];
        NSArray *messages=@[@"only HTML",@"exceeds",@"exceeds",@"exceeds",@"successful page",@"encoding is unsupported"];
        for(NSUInteger i=0;i<paths.count;i++) {
            navigate(paths[i]);
            NSString *expected=messages[i];
            waitFor(^BOOL { return [status.stringValue containsString:expected]; });
            assert(count()==before && [text.string containsString:@"Second page"]);
        }
        NSString *message=status.stringValue;
        mac_engine_complete(nil,NULL,nil,[NSObject new],[NSError errorWithDomain:@"stale" code:1 userInfo:nil]);
        assert([status.stringValue isEqual:message]);
        navigate(@"/long"); waitFor(^BOOL { return [window.title hasPrefix:@"Long — Assembly"]; });
        assert(text.frame.size.height>scroll.contentView.bounds.size.height);
        [text scrollRangeToVisible:NSMakeRange(text.string.length-1,1)];
        assert(scroll.contentView.bounds.origin.y>0);
        navigate(@"/css"); waitFor(^BOOL { return [window.title hasPrefix:@"CSS — Assembly"]; });
        assert(![text.string containsString:@"INVISIBLE"]);
        NSRange heading=[text.string rangeOfString:@"Styled 🌐 heading"];
        NSFont *headingFont=[text.textStorage attribute:NSFontAttributeName atIndex:heading.location effectiveRange:NULL];
        assert(headingFont.pointSize==32 && (headingFont.fontDescriptor.symbolicTraits & NSFontBoldTrait));
        NSColor *canvas=[text.backgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(fabs(canvas.redComponent-250.0/255)<.001 && fabs(canvas.greenComponent-245.0/255)<.001);
        NSRange nested=[text.string rangeOfString:@"nested"];
        NSFont *nestedFont=[text.textStorage attribute:NSFontAttributeName atIndex:nested.location effectiveRange:NULL];
        assert((nestedFont.fontDescriptor.symbolicTraits & NSFontBoldTrait) && (nestedFont.fontDescriptor.symbolicTraits & NSFontItalicTrait));
        NSRange styled=[text.string rangeOfString:@"styled link"];
        assert([[text.textStorage attribute:NSLinkAttributeName atIndex:styled.location effectiveRange:NULL] isKindOfClass:NSURL.class]);
        assert([[text.textStorage attribute:NSUnderlineStyleAttributeName atIndex:styled.location effectiveRange:NULL] integerValue]==0);
        NSColor *foreground=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:styled.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(foreground.redComponent<.001 && fabs(foreground.greenComponent-128.0/255)<.001);
        NSRange paragraph=[text.string rangeOfString:@"Colored"];
        NSParagraphStyle *ps=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:paragraph.location effectiveRange:NULL];
        assert(ps.alignment==NSTextAlignmentCenter && ps.paragraphSpacingBefore==12 && ps.paragraphSpacing==16 && ps.headIndent==18 && ps.tailIndent==-14);
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert([text.backgroundColor isEqual:NSColor.textBackgroundColor]);
        NSFont *reset=[text.textStorage attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
        assert(reset.pointSize==14);
        // Switching engines cancels in-flight work and hides the native renderer.
        address.stringValue=@"";
        mac_engine_toggle(nil,NULL,nil);
        assert(!mac_engine_enabled && !web.hidden && scroll.hidden);
        method_setImplementation(method,original);
        sqlite3_close(mac_db);mac_db=NULL;
        puts("PASS: assembly renderer transport, native links/Unicode ranges, back/forward, scrolling, history, CSS fonts/colors/spacing/visibility, response limits, stale callbacks, and WebKit switching");
    }
    return 0;
}
