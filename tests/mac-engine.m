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
extern void mac_form_submit(id,SEL,id);
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
static BOOL slowStarted;
@interface EngineProtocol : NSURLProtocol
@end
@implementation EngineProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqual:@"engine.test"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSString *path=self.request.URL.path;
    if ([path isEqual:@"/assets/slow.css"]) { slowStarted=YES; return; }
    NSDictionary *headers=@{@"Content-Type":@"text/html; charset=utf-8"};
    NSInteger status=200;
    NSString *html=@"<title>First</title><h1>Hello 🌐</h1><p><a href='/second?a=1&amp;b=2'>next café</a> <a href='javascript:alert(1)'>bad link</a></p><script>SHOULD NOT RENDER</script>";
    if ([path isEqual:@"/features"]) html=@"<title>Features</title><style>.box{color:red}</style><link rel=stylesheet href='assets/first.css'><style>body{line-height:1.4}.box{color:green;font-size:19px}</style><link rel=stylesheet href='assets/huge.css'><link rel=stylesheet href='assets/not-css'><link rel=stylesheet href='assets/last.css'><link rel=stylesheet href='assets/missing.css'><h1>Four features</h1><div class=box><p>Box content with wrapping text to measure inside a fixed width and padding.</p><div style='width:120px;padding:4px;border-width:1px'><p>Nested box</p></div></div><p>Before image <img src='assets/image.png' width=120 alt='Blue rectangle'> after image.</p><p><img src='assets/missing.png' alt='Missing image fallback'></p><form action='/submitted?old=discard' method=get><input name=q value=initial><input type=hidden name=token value='a+b &amp; café'><input name=dup value=one><input name=dup value=two><input style=display:none name=csshidden value=include><input name=skip value=no disabled><input type=submit name=go value=Search><input type=submit name=other value=Other></form><form method=post action=/must-not-submit><input name=post value=secret><button value=Unsupported>Unsupported</button></form>";
    if ([path isEqual:@"/assets/first.css"]) { html=@".box{color:purple;font-size:18px;width:300px;padding:12px 16px;margin:8px 10px;border-width:2px;border-color:#2460ad;background:#fff4dc}"; headers=@{@"Content-Type":@"text/css; charset=utf-8"}; }
    if ([path isEqual:@"/slow"]) html=@"<title>Slow</title><link rel=stylesheet href='assets/slow.css'><p>Must never commit after cancellation</p>";
    if ([path isEqual:@"/assets/huge.css"]) headers=@{@"Content-Type":@"text/css"};
    if ([path isEqual:@"/assets/last.css"]) { html=@".box{color:#123456}"; headers=@{@"Content-Type":@"text/css; charset=utf-8"}; }
    if ([path isEqual:@"/assets/missing.css"] || [path isEqual:@"/assets/missing.png"]) status=404;
    if ([path isEqual:@"/assets/image.png"]) headers=@{@"Content-Type":@"image/png"};
    if ([path isEqual:@"/submitted"]) html=@"<title>Submitted</title><p>GET submitted</p>";
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
    if ([path isEqual:@"/assets/image.png"]) data=[NSData dataWithContentsOfFile:@"tests/engine-image.png"];
    if ([path isEqual:@"/latin1"]) { const char legacy[]="<title>Legacy</title><p>caf\xe9 \x93hello\x94 \x80</p>"; data=[NSData dataWithBytes:legacy length:sizeof(legacy)-1]; }
    if ([path isEqual:@"/expanded"]) { NSMutableData *large=[NSMutableData dataWithLength:600000]; memset(large.mutableBytes,0x80,large.length); data=large; }
    if ([path isEqual:@"/assets/huge.css"]) data=[NSMutableData dataWithLength:65537];
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
        // All four features together, using in-process HTTP and no WebKit view.
        navigate(@"/features"); waitFor(^BOOL { return [window.title hasPrefix:@"Features — Assembly"]; });
        NSRange boxRange=[text.string rangeOfString:@"Box content"];
        NSColor *boxColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:boxRange.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(fabs(boxColor.redComponent-18.0/255)<.001); // last linked sheet wins
        NSParagraphStyle *boxStyle=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:boxRange.location effectiveRange:NULL];
        assert(boxStyle.textBlocks.count==1);
        assert(((NSFont *)[text.textStorage attribute:NSFontAttributeName atIndex:boxRange.location effectiveRange:NULL]).pointSize==19);
        assert([text.effectiveAppearance.name isEqual:NSAppearanceNameAqua]);
        NSRange measured=[text.string rangeOfString:@"Box content with wrapping text to measure inside a fixed width and padding."];
        NSRect measuredRect=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:measured actualCharacterRange:NULL] inTextContainer:text.textContainer];
        assert(measuredRect.size.width<=301 && measuredRect.origin.x>=25 && measuredRect.size.height>20);
        NSTextBlock *box=boxStyle.textBlocks[0];
        assert(box.contentWidth==300 && [box widthForLayer:NSTextBlockPadding edge:NSMinXEdge]==16 && [box widthForLayer:NSTextBlockPadding edge:NSMinYEdge]==12);
        assert([box widthForLayer:NSTextBlockBorder edge:NSMinXEdge]==2 && [box widthForLayer:NSTextBlockMargin edge:NSMinXEdge]==10);
        NSRange nestedBoxRange=[text.string rangeOfString:@"Nested box"];
        assert(((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:nestedBoxRange.location effectiveRange:NULL]).textBlocks.count==2);
        __block NSUInteger imageCount=0; __block BOOL sawAlt=NO;
        [text.textStorage enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0,text.string.length) options:0 usingBlock:^(NSTextAttachment *attachment,NSRange range,BOOL *stop) {
            (void)range;(void)stop;
            if (attachment.image && fabs(attachment.image.size.width-120)<.01) { assert(fabs(attachment.image.size.height-60)<.01); NSRect rect=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL] inTextContainer:text.textContainer]; assert(rect.size.height>=60); imageCount++; }
            if ([[(NSTextAttachmentCell *)attachment.attachmentCell stringValue] isEqual:@"Missing image fallback"]) sawAlt=YES;
        }];
        assert(imageCount==1 && sawAlt);
        NSMutableArray<NSTextField *> *fields=[NSMutableArray new]; NSButton *submit=nil,*post=nil;
        for(NSView *view in text.subviews) {
            if ([view isKindOfClass:NSTextField.class]) [fields addObject:(NSTextField *)view];
            if ([view isKindOfClass:NSButton.class] && [[(NSButton *)view title] isEqual:@"Search"]) submit=(NSButton *)view;
            if ([view isKindOfClass:NSButton.class] && [[(NSButton *)view title] isEqual:@"Unsupported"]) post=(NSButton *)view;
        }
        assert(fields.count==5 && submit && post && submit.frame.size.width>=99);
        fields[0].stringValue=@"café + & 🌐";
        NSString *oldAddress=address.stringValue;
        mac_form_submit(nil,NULL,post);
        assert([status.stringValue containsString:@"unsupported method"] && [address.stringValue isEqual:oldAddress]);
        [submit performClick:nil];
        waitFor(^BOOL { return [window.title hasPrefix:@"Submitted — Assembly"]; });
        assert([address.stringValue isEqual:@"https://engine.test/submitted?q=caf%C3%A9+%2B+%26+%F0%9F%8C%90&token=a%2Bb+%26+caf%C3%A9&dup=one&dup=two&csshidden=include&go=Search"]);
        assert(text.subviews.count==0); // controls removed on navigation
        navigate(@"/features"); waitFor(^BOOL { return [window.title hasPrefix:@"Features — Assembly"]; });
        NSTextField *returnField=nil;
        for(NSView *view in text.subviews) if ([view isKindOfClass:NSTextField.class] && [[(NSTextField *)view stringValue] isEqual:@"initial"]) returnField=(NSTextField *)view;
        assert(returnField);
        returnField.stringValue=@"return works";
        assert([NSApp sendAction:returnField.action to:returnField.target from:returnField]);
        waitFor(^BOOL { return [window.title hasPrefix:@"Submitted — Assembly"]; });
        assert([address.stringValue containsString:@"q=return+works"] && ![address.stringValue containsString:@"&go="]);
        int beforeSlow=count();
        navigate(@"/slow"); waitFor(^BOOL { return slowStarted; });
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert(count()==beforeSlow+1 && ![text.string containsString:@"Must never commit"]);
        // Switching engines cancels in-flight work and hides the native renderer.
        address.stringValue=@"";
        mac_engine_toggle(nil,NULL,nil);
        assert(!mac_engine_enabled && !web.hidden && scroll.hidden);
        method_setImplementation(method,original);
        sqlite3_close(mac_db);mac_db=NULL;
        puts("PASS: assembly renderer transport, native links/Unicode ranges, back/forward, scrolling, history, CSS cascade/boxes, linked resources, images/alt/aspect ratio, native GET forms/encoding, response limits, stale callbacks, and WebKit switching");
    }
    return 0;
}
