// Test-only in-process transport and native-view integration for the assembly engine.
#import <Cocoa/Cocoa.h>
#import <AppKit/NSTypesetter.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sqlite3.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
extern Class mac_register_class(void);
extern void mac_engine_toggle(id,SEL,id);
extern void mac_engine_navigate(void);
extern void mac_engine_resize(id,SEL,id);
extern void mac_engine_reload(void);
extern __unsafe_unretained NSDictionary *engine_controls;
extern __unsafe_unretained NSURLSession *engine_session;
extern void *engine_document;
typedef struct {char *text; uint64_t length,*map,lines;} TestLayout;
extern TestLayout *engine_layout(void *,size_t);
extern void engine_layout_free(TestLayout *);
static NSString *postedBody,*postedMethod,*postedType,*postedQuery;
extern void mac_engine_back(void);
extern void mac_engine_forward(void);
extern void mac_form_submit(id,SEL,id);
extern void mac_engine_complete(id,SEL,id,id,NSError *);
extern int history_add(sqlite3 *,const char *,const char *);
extern void mac_engine_refresh(void);
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
@property BOOL stopped;
@end
@implementation EngineProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqual:@"engine.test"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSString *path=self.request.URL.path;
    if ([path isEqual:@"/assets/delayed.css"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            if(self.stopped) return;
            NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"text/css"}];
            [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [self.client URLProtocol:self didLoadData:[@"p{color:green}" dataUsingEncoding:NSUTF8StringEncoding]];
            [self.client URLProtocolDidFinishLoading:self];
        });
        return;
    }
    if ([path isEqual:@"/assets/slow.css"]) { slowStarted=YES; return; }
    NSDictionary *headers=@{@"Content-Type":@"text/html; charset=utf-8"};
    NSInteger status=200;
    NSString *html=@"<title>First</title><h1>Hello 🌐</h1><p><a href='/second?a=1&amp;b=2'>next café</a> <a href='javascript:alert(1)'>bad link</a></p><script>SHOULD NOT RENDER</script>";
    if ([path isEqual:@"/paint-order"]) html=@"<title>Paint order</title><style>body{margin:0;font:10px/1 monospace}.parent{float:left;width:120px;height:100px;background:blue}.child{margin:10px;width:50px;height:30px;background:yellow}</style><div class=parent><p class=child>Child</p></div><p style='clear:both'><a href=/second>Hit target</a></p>";
    if ([path isEqual:@"/float-hardening"]) html=@"<title>Float hardening</title><style>body{width:300px;margin:0;font:10px/1 monospace}p{margin:0}</style><p>Intro paragraph</p><div id=empty style='float:left;width:50px;height:40px;background:red'></div><p>Some ordinary content follows the empty float and wraps across several lines before the next float starts in source order. More content makes this paragraph long enough.</p><div id=autofloat style='float:left;width:80px;padding:2px;background:blue'>Alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango.</div><div id=afterauto style='float:left;clear:both;width:60px;height:20px'>After auto</div><p style='clear:both'>Bottom</p><div style='width:200px;padding:20px'><div id=innerfloat style='float:right;width:50px;height:20px'>Inner</div><p>Padded content wraps around its float.</p><div id=percentfloat style='float:left;width:50%;height:10px'>Half</div><div id=widthauto style='float:left;clear:both'>A rather long unbroken-float text that must fit the padded containing width instead of the full body.</div></div><p style='clear:both'>End</p><div id=nestedauto style='float:left;width:100px;padding:4px'><div style='float:left;width:60px;height:80px'>Nested</div></div><div id=afternested style='float:left;clear:both;width:50px;height:10px'>After nested</div><p style='clear:both'>New row</p><div id=bigfirst style='float:left;width:250px;height:60px'>First</div><div id=nextrow style='float:left;width:100px;height:20px'>Next row</div><div id=lastrow style='float:left;width:40px;height:10px'>Last</div>";
    if ([path isEqual:@"/tallfloat"]) html=@"<title>Tall float</title><div style='float:left;width:90px;height:1000px;background:blue'>Tall</div>";
    if ([path isEqual:@"/floats"]) html=@"<title>Float exclusions</title><style>body{width:300px;font:10px/1 monospace}p{margin:0}.left{float:left;width:60px;height:50px;background:blue}.right{float:right;width:60px;height:80px;background:red}</style><div class=left>Float</div><div class=right>Right</div><p>ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789</p><p style='clear:both'>Clear footer</p>";
    if ([path isEqual:@"/acid1"]) html=[NSString stringWithContentsOfFile:@"tests/fixtures/acid1.html" encoding:NSUTF8StringEncoding error:NULL];
    if ([path isEqual:@"/vectors"]) html=@"<title>SVG integration</title><style>:root{--icon:11 87 208}svg{color:rgb(var(--icon));width:48px;height:48px;fill:currentColor}</style><p>Before <a href=/second><svg viewBox='0 0 24 24'><circle cx=12 cy=12 r=10/><path d='M8 12h8' stroke=white stroke-width=2/></svg></a> after vector</p><img src=assets/vector.svg width=80 alt='External vector'>";
    if ([path isEqual:@"/assets/vector.svg"]) {html=@"<svg width='40' height='20'><rect width='40' height='20' fill='blue'/></svg>";headers=@{@"Content-Type":@"image/svg+xml"};}
    if ([path isEqual:@"/flow"]) html=@"<title>Flow layout</title><style>:root{--accent:11 87 208}.row{display:flex;width:600px;gap:20px;align-items:center}.row>div{height:50px;padding:0;background:rgb(var(--accent)/.2)}.fixed{width:100px}.grow{flex:1}.wrap{display:flex;width:220px;gap:10px;flex-wrap:wrap}.wrap>div{width:100px}form.flowform{display:flex;width:500px;gap:10px}@media(max-width:600px){form.flowform{width:100%}}table{width:500px}td,th{border:1px solid #369;padding:4px}</style><div class=row><div class=fixed>Flex left</div><div class=grow>Flex middle</div><div class=fixed>Flex right</div></div><div class=wrap><div>Wrap one</div><div>Wrap two</div><div>Wrap three</div></div><form class=flowform><input id=flexq name=q style='flex:1'><input id=flexsend type=submit value=Go style='width:100px'></form><table><tr><td rowspan=2>Rowspan<td>Upper<tr><td>Lower<tr><th colspan=2>Wide footer</table>";
    if ([path isEqual:@"/inline-box"]) html=@"<title>Inline boxes</title><style>@media(max-width:500px){#signin{background:transparent!important;padding:0!important;min-height:0!important;color:blue!important}}</style><p>Before <a id=signin href=/second style='display:inline-block;background:#0b57d0;color:white;padding:10px 24px;border-radius:100px;min-height:40px;box-sizing:border-box;text-align:center;text-decoration:none'>Sign <span>in 🌐</span></a> <a href=/afterbox>after café</a></p><a id=bordered href=/second style='display:inline-block;padding:4px 8px;border:2px solid red;border-radius:6px;min-width:120px;vertical-align:middle;margin:2px 4px'>Bordered</a>";
    if ([path isEqual:@"/compat"]) html=@"<title>Compatibility</title><style>.nav{display:inline-block}body{font:14px Arial}#wide{display:none}@media(min-width:800px){#wide{display:block}}</style><div><div class=nav>Mail</div><div class=nav>Images</div></div><center><p>Centered search</p><form><input id=query name=q><input id=search type=submit value='A comfortably long search label'><button id=more type=button><svg><title>icon source</title></svg><span>More &amp; options</span></button></form><div style='margin:19px auto;text-align:center'>Advertising links</div><p id=wide>Desktop-only content</p><div style='display:inline-block'>Search field line</div><br><span style='display:inline-block'>Search button line</span><p><a href=/spaced style='margin:0 12px;color:purple'>Spaced 🌐</a><a href=/next>Next link</a></p><span style='background:#aaccee'><input id=painted type=submit value=Painted></span></center>";
    if ([path isEqual:@"/progress"]) html=@"<title>Progress</title><link rel=stylesheet href=assets/delayed.css><p>HTML visible before CSS</p><input id=live name=q value=initial>";
    if ([path isEqual:@"/advanced"]) html=@"<title>Advanced</title><style>.responsive{width:90%;max-width:600px;box-sizing:border-box;padding:12px;border:2px solid #369;margin:10px auto}.responsive > p{color:green}textarea{width:80%;max-width:250px;height:90px}</style><div class=responsive><p>Responsive text that wraps as the browser window changes size and keeps the controls below it intact.</p></div><form action='/posted?keep=1' method=post><input id=flag name=flag type=checkbox checked><input id=unchecked name=skip type=checkbox value=no><input id=radioA type=radio name=choice value=a checked><input id=radioB type=radio name=choice value=b><select id=flavor name=flavor><option disabled>Unavailable</option><option value=vanilla>Vanilla</option><option value=chocolate selected>Chocolate</option></select><select id=colors name=color multiple><option value=red selected>Red</option><option value=green>Green</option><option value=blue selected>Blue</option></select><textarea id=notes name=notes>line one\nline &amp; café</textarea><input id=edit name=edit value=initial><input name=disabled type=checkbox checked disabled><button id=send name=action value=commit>Send</button></form><form><input id=outside name=choice type=radio value=outside checked></form>";
    if ([path isEqual:@"/posted"]) {
        postedMethod=self.request.HTTPMethod; postedType=[self.request valueForHTTPHeaderField:@"Content-Type"]; postedQuery=self.request.URL.query;
        NSData *body=self.request.HTTPBody;
        if(!body && self.request.HTTPBodyStream) { NSInputStream *stream=self.request.HTTPBodyStream; [stream open]; NSMutableData *d=[NSMutableData new]; uint8_t bytes[4096]; NSInteger n; while((n=[stream read:bytes maxLength:sizeof(bytes)])>0) [d appendBytes:bytes length:(NSUInteger)n]; [stream close]; body=d; }
        postedBody=[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        html=@"<title>Posted</title><p>POST accepted</p>";
    }
    if ([path isEqual:@"/features"]) html=@"<title>Features</title><style>.box{color:red}</style><link rel=stylesheet href='assets/first.css'><style>body{line-height:1.4}.box{color:green;font-size:19px}</style><link rel=stylesheet href='assets/huge.css'><link rel=stylesheet href='assets/not-css'><link rel=stylesheet href='assets/last.css'><link rel=stylesheet href='assets/missing.css'><h1>Four features</h1><div class=box><p>Box content with wrapping text to measure inside a fixed width and padding.</p><div style='width:120px;padding:4px;border-width:1px'><p>Nested box</p></div></div><p>Before image <img src='assets/image.png' width=120 alt='Blue rectangle'> after image.</p><p><img src='assets/missing.png' alt='Missing image fallback'></p><form action='/submitted?old=discard' method=get><input name=q value=initial><input type=hidden name=token value='a+b &amp; café'><input name=dup value=one><input name=dup value=two><input style=display:none name=csshidden value=include><input name=skip value=no disabled><input type=submit name=go value=Search><input type=submit name=other value=Other></form><form method=patch action=/must-not-submit><input name=post value=secret><button value=Unsupported>Unsupported</button></form>";
    if ([path isEqual:@"/assets/first.css"]) { html=@".box{color:purple;font-size:18px;width:300px;padding:12px 16px;margin:8px 10px;border-width:2px;border-color:#2460ad;background:#fff4dc}"; headers=@{@"Content-Type":@"text/css; charset=utf-8"}; }
    if ([path isEqual:@"/slow"]) html=@"<title>Slow</title><link rel=stylesheet href='assets/slow.css'><p>Must never commit after cancellation</p>";
    if ([path isEqual:@"/assets/huge.css"]) headers=@{@"Content-Type":@"text/css"};
    if ([path isEqual:@"/assets/last.css"]) { html=[[@"/*" stringByPaddingToLength:70000 withString:@" " startingAtIndex:0] stringByAppendingString:@"*/.box{color:#123456}"]; headers=@{@"Content-Type":@"text/css; charset=utf-8"}; }
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
    if ([path isEqual:@"/assets/huge.css"]) data=[NSMutableData dataWithLength:1048577];
    if ([path isEqual:@"/stream"]) data=[NSMutableData dataWithLength:1048577];
    if ([path isEqual:@"/encoding"]) { unsigned char bad[]={0xff,0xfe,0xff}; data=[NSData dataWithBytes:bad length:sizeof(bad)]; }
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading { self.stopped=YES; }
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
static uint64_t *metadata(NSString *identifier) {
    uint64_t *doc=engine_document; unsigned char *meta=(void *)(uintptr_t)doc[9];
    for(uint64_t i=0;i<doc[3];i++) { char *name=*(char **)(meta+i*2048); if(name && [identifier isEqualToString:[NSString stringWithUTF8String:name]]) return (uint64_t *)(meta+i*2048); }
    abort();
}
static id control(NSString *identifier) {
    uint64_t *doc=engine_document; unsigned char *meta=(void *)(uintptr_t)doc[9];
    for(uint64_t i=0;i<doc[3];i++) { char *name=*(char **)(meta+i*2048); if(name && [identifier isEqualToString:[NSString stringWithUTF8String:name]]) return engine_controls[@(i)]; }
    return nil;
}
// TextKit can report one containing line fragment for an entire table row.
// Query the actual cell's allocated content rectangle instead of that fragment
// or font-dependent glyph ink. NSLayoutManager APIs take glyph indices.
static NSRect blockRect(NSTextView *text,NSRange characters) {
    assert(characters.location!=NSNotFound && characters.length);
    NSLayoutManager *manager=text.layoutManager;
    [manager ensureLayoutForTextContainer:text.textContainer];
    NSParagraphStyle *style=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:characters.location effectiveRange:NULL];
    assert(style.textBlocks.count);
    NSUInteger tableCells=0;
    for(NSTextBlock *block in style.textBlocks) if([block isKindOfClass:NSTextTableBlock.class]) tableCells++;
    assert(tableCells==1); // flex fixture has one real cell, no artificial outer table
    NSRange glyphs=[manager glyphRangeForCharacterRange:characters actualCharacterRange:NULL];
    assert(glyphs.length);
    NSRect rect=[manager layoutRectForTextBlock:style.textBlocks.lastObject atIndex:glyphs.location effectiveRange:NULL];
    if(NSIsEmptyRect(rect)) NSLog(@"Missing cell layout for %@: characters %@, glyphs %@, block %@",[text.string substringWithRange:characters],NSStringFromRange(characters),NSStringFromRange(glyphs),style.textBlocks.lastObject);
    assert(!NSIsEmptyRect(rect));
    return rect;
}
static int denyInsert(void *ctx,int action,const char *a,const char *b,const char *c,const char *d) { (void)ctx;(void)a;(void)b;(void)c;(void)d;return action==SQLITE_INSERT ? SQLITE_DENY : SQLITE_OK; }
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
        assert([text.linkTextAttributes[NSCursorAttributeName] isEqual:NSCursor.pointingHandCursor]);
        assert(!text.linkTextAttributes[NSForegroundColorAttributeName]); // CSS stays authoritative
        NSColor *unvisited=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:link.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(fabs(unvisited.blueComponent-214.0/255)<.001 && fabs(unvisited.redComponent-26.0/255)<.001);
        assert(history_add(mac_db,target.absoluteString.UTF8String,"Visited target")==SQLITE_OK);
        mac_engine_refresh();
        NSColor *visited=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:link.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(fabs(visited.redComponent-128.0/255)<.001 && fabs(visited.blueComponent-128.0/255)<.001);
        assert(sqlite3_exec(mac_db,"DELETE FROM visits WHERE title='Visited target'",NULL,NULL,NULL)==SQLITE_OK);
        mac_engine_refresh();
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
        navigate(@"/css"); waitFor(^BOOL { return [window.title hasPrefix:@"CSS — Assembly"] && [status.stringValue containsString:@"ready."]; });
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
        assert(ps.alignment==NSTextAlignmentCenter && ps.textBlocks.count==1 && ps.headIndent==0 && ps.tailIndent==0);
        NSTextBlock *noticeBox=ps.textBlocks.lastObject;
        assert([noticeBox widthForLayer:NSTextBlockMargin edge:NSMinXEdge]==18 && [noticeBox widthForLayer:NSTextBlockMargin edge:NSMaxXEdge]==14 && [noticeBox widthForLayer:NSTextBlockMargin edge:NSMinYEdge]==12 && [noticeBox widthForLayer:NSTextBlockMargin edge:NSMaxYEdge]==16);
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert([text.backgroundColor isEqual:NSColor.textBackgroundColor]);
        NSFont *reset=[text.textStorage attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
        assert(reset.pointSize==14);
        // All four features together, using in-process HTTP and no WebKit view.
        navigate(@"/features"); waitFor(^BOOL { return [window.title hasPrefix:@"Features — Assembly"] && [status.stringValue containsString:@"ready."]; });
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
        assert(text.subviews.count==0 && !window.undoManager.canUndo); // no stale form actions
        navigate(@"/features"); waitFor(^BOOL { return [window.title hasPrefix:@"Features — Assembly"] && [status.stringValue containsString:@"ready."]; });
        NSTextField *returnField=nil;
        for(NSView *view in text.subviews) if ([view isKindOfClass:NSTextField.class] && [[(NSTextField *)view stringValue] isEqual:@"initial"]) returnField=(NSTextField *)view;
        assert(returnField);
        returnField.stringValue=@"return works";
        assert([NSApp sendAction:returnField.action to:returnField.target from:returnField]);
        waitFor(^BOOL { return [window.title hasPrefix:@"Submitted — Assembly"]; });
        assert([address.stringValue containsString:@"q=return+works"] && ![address.stringValue containsString:@"&go="]);
        int progressiveCount=count();
        navigate(@"/progress"); waitFor(^BOOL { return [window.title hasPrefix:@"Progress — Assembly"]; });
        assert([text.string containsString:@"HTML visible before CSS"] && [status.stringValue containsString:@"loading styles"]);
        NSTextField *live=control(@"live"); assert(live); live.stringValue=@"keep my edit";
        waitFor(^BOOL { return [status.stringValue containsString:@"ready."]; });
        assert(control(@"live")==live && [live.stringValue isEqual:@"keep my edit"] && count()==progressiveCount+1);
        assert(engine_session.configuration.URLCache.memoryCapacity==16777216 && engine_session.configuration.URLCache.diskCapacity==0);
        navigate(@"/advanced"); waitFor(^BOOL { return [window.title hasPrefix:@"Advanced — Assembly"] && [status.stringValue containsString:@"ready."]; });
        NSButton *flag=control(@"flag"),*radioA=control(@"radioA"),*radioB=control(@"radioB"),*outside=control(@"outside"),*send=control(@"send");
        NSPopUpButton *flavor=control(@"flavor"),*colors=control(@"colors"); NSScrollView *notes=control(@"notes"); NSTextField *edit=control(@"edit");
        assert([scroll.accessibilityChildren containsObject:text]);
        // Native controls share the actual line baseline, including those whose
        // attachment glyph location already incorporates a descent offset.
        TestLayout *mapped=engine_layout(engine_document,0); assert(mapped);
        for(NSControl *v in @[edit,flag,radioA,radioB,flavor,send]) {
            uint64_t *doc=engine_document,*nodes=(void *)(uintptr_t)doc[2];
            NSUInteger start=(NSUInteger)nodes[(NSUInteger)v.tag*5+2];
            NSUInteger glyph=[text.layoutManager glyphIndexForCharacterAtIndex:mapped->map[start]];
            NSRect line=[text.layoutManager lineFragmentRectForGlyphAtIndex:glyph effectiveRange:NULL];
            CGFloat baseline=NSMaxY(line)-[text.layoutManager.typesetter baselineOffsetInLayoutManager:text.layoutManager glyphIndex:glyph]+text.textContainerInset.height;
            NSRect frame=[text convertRect:v.bounds fromView:v];
            CGFloat offset=v.firstBaselineOffsetFromTop+(frame.size.height-v.intrinsicContentSize.height)/2;
            assert(fabs(NSMinY(frame)+offset-baseline)<.01);
            assert(v.font.pointSize==14);
        }
        engine_layout_free(mapped);
        assert([edit.cell usesSingleLineMode]);
        assert(flag.frame.size.width==ceil(flag.intrinsicContentSize.width) && flag.frame.size.width<24);
        assert(radioB.frame.size.width==ceil(radioB.intrinsicContentSize.width) && radioB.frame.size.width<24);
        assert(flag && radioA && radioB && outside && send && flavor && colors && notes && edit);
        assert(flag.state==NSControlStateValueOn && radioA.state==NSControlStateValueOn && outside.state==NSControlStateValueOn);
        assert(notes.frame.size.width<=251 && [(NSTextView *)notes.documentView allowsUndo]);
        NSTextView *editor=(NSTextView *)notes.documentView;
        assert([window makeFirstResponder:editor]);
        NSString *originalNotes=[editor.string copy];
        [editor insertText:@"undo and redo" replacementRange:NSMakeRange(0,editor.string.length)];
        [editor breakUndoCoalescing];
        NSUndoManager *undo=editor.undoManager; assert(undo && undo.canUndo);
        [undo undo]; assert([editor.string isEqual:originalNotes] && undo.canRedo);
        [undo redo]; assert([editor.string isEqual:@"undo and redo"]);
        assert([flavor.selectedItem.representedObject isEqual:@"chocolate"] && !flavor.itemArray[0].enabled);
        [radioB performClick:nil]; assert(radioB.state==NSControlStateValueOn && radioA.state==NSControlStateValueOff && outside.state==NSControlStateValueOn);
        NSMenuItem *green=colors.itemArray[1]; assert([NSApp sendAction:green.action to:green.target from:green]);
        [(NSTextView *)notes.documentView setString:@"edited\ntext + 🌐"];
        edit.stringValue=@"survives resize";
        [window setContentSize:NSMakeSize(450,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"edit")==edit && [edit.stringValue isEqual:@"survives resize"] && radioB.state==NSControlStateValueOn);
        NSRange responsive=[text.string rangeOfString:@"Responsive text"];
        NSParagraphStyle *responsiveStyle=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:responsive.location effectiveRange:NULL];
        assert(text.textContainer.size.width<450 && responsiveStyle.textBlocks.count && responsiveStyle.textBlocks.lastObject.contentWidth<400);
        [window setContentSize:NSMakeSize(1160,780)]; mac_engine_resize(nil,NULL,nil);
        [send performClick:nil]; waitFor(^BOOL { return [window.title hasPrefix:@"Posted — Assembly"]; });
        assert([postedMethod isEqual:@"POST"] && [postedType isEqual:@"application/x-www-form-urlencoded"] && [postedQuery isEqual:@"keep=1"]);
        assert([postedBody isEqual:@"flag=on&choice=b&flavor=chocolate&color=red&color=green&color=blue&notes=edited%0D%0Atext+%2B+%F0%9F%8C%90&edit=survives+resize&action=commit"]);
        navigate(@"/compat"); waitFor(^BOOL { return [window.title hasPrefix:@"Compatibility — Assembly"] && [status.stringValue containsString:@"ready."]; });
        assert([text.string containsString:@"Mail Images"] && ![text.string containsString:@"icon source"]);
        NSButton *longSearch=control(@"search"),*more=control(@"more");
        assert([more isKindOfClass:NSButton.class] && [more.title isEqual:@"More & options"] && !more.enabled && more.action==NULL);
        assert(longSearch.frame.size.width>=longSearch.intrinsicContentSize.width && longSearch.frame.size.width>100);
        NSRange centered=[text.string rangeOfString:@"Centered search"],footer=[text.string rangeOfString:@"Advertising links"];
        NSParagraphStyle *centerStyle=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:centered.location effectiveRange:NULL];
        NSParagraphStyle *footerStyle=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:footer.location effectiveRange:NULL];
        assert(centerStyle.alignment==NSTextAlignmentCenter && footerStyle.alignment==NSTextAlignmentCenter && footerStyle.tailIndent==0 && footerStyle.headIndent==0);
        NSRect footerRect=[text.layoutManager boundingRectForGlyphRange:footer inTextContainer:text.textContainer];
        assert(footerRect.size.width>80 && footerRect.size.height<40);
        assert([text.string containsString:@"Search field line"] && [text.string containsString:@"\nSearch button line"]);
        NSRange spaced=[text.string rangeOfString:@"Spaced 🌐"];
        assert([[text.textStorage attribute:NSKernAttributeName atIndex:NSMaxRange(spaced)-1 effectiveRange:NULL] integerValue]==24);
        NSColor *authored=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:spaced.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(fabs(authored.redComponent-128.0/255)<.001 && authored.greenComponent<.001 && fabs(authored.blueComponent-128.0/255)<.001);
        NSRange fieldLine=[text.string rangeOfString:@"Search field line"],buttonLine=[text.string rangeOfString:@"Search button line"];
        NSRect fieldLineRect=[text.layoutManager boundingRectForGlyphRange:fieldLine inTextContainer:text.textContainer];
        NSRect buttonLineRect=[text.layoutManager boundingRectForGlyphRange:buttonLine inTextContainer:text.textContainer];
        assert(buttonLineRect.origin.y>fieldLineRect.origin.y);
        for(NSUInteger i=0;i<text.string.length;i++) if([text.textStorage attribute:NSAttachmentAttributeName atIndex:i effectiveRange:NULL]) assert(![text.textStorage attribute:NSBackgroundColorAttributeName atIndex:i effectiveRange:NULL]);
        assert([text.string containsString:@"Desktop-only content"]);
        [window setContentSize:NSMakeSize(450,780)]; mac_engine_resize(nil,NULL,nil);
        assert(![text.string containsString:@"Desktop-only content"]);
        [window setContentSize:NSMakeSize(1160,780)]; mac_engine_resize(nil,NULL,nil);
        assert([text.string containsString:@"Desktop-only content"]);
        navigate(@"/inline-box"); waitFor(^BOOL { return [window.title hasPrefix:@"Inline boxes — Assembly"] && [status.stringValue containsString:@"ready."]; });
        NSButton *signin=control(@"signin"),*bordered=control(@"bordered");
        assert(signin && [signin.title isEqual:@"Sign in 🌐"] && signin.frame.size.height==40);
        NSRange boxGlyph=[text.string rangeOfString:@"\ufffc"];
        NSRect boxGlyphRect=[text.layoutManager boundingRectForGlyphRange:boxGlyph inTextContainer:text.textContainer];
        assert(fabs(signin.frame.origin.x-(boxGlyphRect.origin.x+text.textContainerInset.width))<1);
        NSSize titleSize=[signin.attributedTitle size]; assert(signin.frame.size.width>=titleSize.width+48 && signin.frame.size.width<titleSize.width+50);
        assert(signin.wantsLayer && signin.layer.cornerRadius==20 && [signin.accessibilityRole isEqual:NSAccessibilityLinkRole]);
        NSColor *boxBackground=[NSColor colorWithCGColor:signin.layer.backgroundColor];
        assert(fabs(boxBackground.blueComponent-208.0/255)<.001);
        NSColor *boxText=[signin.attributedTitle attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL]; assert(boxText.redComponent>.99 && boxText.greenComponent>.99 && boxText.blueComponent>.99);
        assert(bordered.layer.borderWidth==2 && bordered.layer.cornerRadius==6 && bordered.frame.size.width>=140);
        NSRange borderedRange=[text.string rangeOfString:@"\ufffc" options:NSBackwardsSearch];
        NSTextAttachment *borderedAttachment=[text.textStorage attribute:NSAttachmentAttributeName atIndex:borderedRange.location effectiveRange:NULL];
        assert(fabs(borderedAttachment.attachmentCell.cellSize.width-(bordered.frame.size.width+8))<1);
        NSRect borderedGlyphRect=[text.layoutManager boundingRectForGlyphRange:borderedRange inTextContainer:text.textContainer];
        assert(fabs(bordered.frame.origin.x-(borderedGlyphRect.origin.x+text.textContainerInset.width+4))<1);
        NSRange following=[text.string rangeOfString:@"after café"]; assert(following.location!=NSNotFound && [[text.textStorage attribute:NSLinkAttributeName atIndex:following.location effectiveRange:NULL] isEqual:[NSURL URLWithString:@"https://engine.test/afterbox"]]);
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"signin")==signin && signin.frame.size.height==40);
        [window setContentSize:NSMakeSize(450,780)]; mac_engine_resize(nil,NULL,nil);
        assert(signin.hidden && [text.string containsString:@"Sign in 🌐"]);
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"signin")==signin && !signin.hidden && signin.frame.size.height==40);
        [signin performClick:nil]; waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert([address.stringValue isEqual:@"https://engine.test/second"]);
        // Compatibility defaults vary with the linked AppKit version. Rendering
        // must restore table-capable layout instead of relying on that default.
        text.layoutManager.typesetterBehavior=NSTypesetterOriginalBehavior;
        assert(text.layoutManager.typesetterBehavior==NSTypesetterOriginalBehavior);
        navigate(@"/flow"); waitFor(^BOOL { return [window.title hasPrefix:@"Flow layout — Assembly"] && [status.stringValue containsString:@"ready."]; });
        assert(text.layoutManager.typesetterBehavior==NSTypesetterBehavior_10_4);
        NSRange fl=[text.string rangeOfString:@"Flex left"],fm=[text.string rangeOfString:@"Flex middle"],fr=[text.string rangeOfString:@"Flex right"];
        NSRect flr=blockRect(text,fl),fmr=blockRect(text,fm),frr=blockRect(text,fr);
        if(!(fabs(flr.origin.y-fmr.origin.y)<1 && fabs(flr.origin.y-frr.origin.y)<1 && fmr.origin.x>=NSMaxX(flr)+19 && frr.origin.x>=NSMaxX(fmr)+19)) {
            NSLog(@"Flex cell boxes: %@ / %@ / %@; typesetter %@, behavior %ld, glyphs %lu",NSStringFromRect(flr),NSStringFromRect(fmr),NSStringFromRect(frr),text.layoutManager.typesetter,(long)text.layoutManager.typesetterBehavior,(unsigned long)text.layoutManager.numberOfGlyphs);
            for(NSValue *range in @[[NSValue valueWithRange:fl],[NSValue valueWithRange:fm],[NSValue valueWithRange:fr]]) {
                NSParagraphStyle *style=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:range.rangeValue.location effectiveRange:NULL];
                for(NSTextTableBlock *block in style.textBlocks) NSLog(@"Cell %@ width %.2f row %ld col %ld columns %ld table %@",block,block.contentWidth,(long)block.startingRow,(long)block.startingColumn,(long)block.table.numberOfColumns,block.table);
            }
        }
        assert(fabs(flr.origin.y-fmr.origin.y)<1 && fabs(flr.origin.y-frr.origin.y)<1 && fmr.origin.x>=NSMaxX(flr)+19 && frr.origin.x>=NSMaxX(fmr)+19);
        NSParagraphStyle *flowStyle=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:fm.location effectiveRange:NULL];
        assert(flowStyle.textBlocks.count && fabs(flowStyle.textBlocks.lastObject.contentWidth-360)<1);
        NSRange wrapOne=[text.string rangeOfString:@"Wrap one"],wrapThree=[text.string rangeOfString:@"Wrap three"];
        NSRect wor=blockRect(text,wrapOne),wtr=blockRect(text,wrapThree); assert(wtr.origin.y>wor.origin.y);
        NSTextField *flexQuery=control(@"flexq"); NSButton *flexSend=control(@"flexsend");
        assert(flexQuery && flexSend && fabs(flexQuery.frame.size.width-390)<1 && fabs(flexSend.frame.size.width-100)<1);
        assert(fabs(flexQuery.frame.origin.y-flexSend.frame.origin.y)<5);
        flexQuery.stringValue=@"kept after flex resize";
        [window setContentSize:NSMakeSize(500,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"flexq")==flexQuery && [flexQuery.stringValue isEqual:@"kept after flex resize"] && flexQuery.frame.size.width<390);
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        NSRange upper=[text.string rangeOfString:@"Upper"],lower=[text.string rangeOfString:@"Lower"],wide=[text.string rangeOfString:@"Wide footer"];
        NSTextTableBlock *ub=(id)((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:upper.location effectiveRange:NULL]).textBlocks.lastObject;
        NSTextTableBlock *lb=(id)((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:lower.location effectiveRange:NULL]).textBlocks.lastObject;
        NSTextTableBlock *wb=(id)((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:wide.location effectiveRange:NULL]).textBlocks.lastObject;
        assert(ub.table==lb.table && lb.table==wb.table && ub.startingColumn==1 && lb.startingRow==1 && wb.columnSpan==2);
        navigate(@"/vectors"); waitFor(^BOOL { return [window.title hasPrefix:@"SVG integration — Assembly"] && [status.stringValue containsString:@"ready."]; });
        NSMutableArray<NSTextAttachment *> *vectors=[NSMutableArray new];
        [text.textStorage enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0,text.string.length) options:0 usingBlock:^(id a,NSRange r,BOOL *stop){(void)r;(void)stop;if(a)[vectors addObject:a];}];
        assert(vectors.count==2 && NSEqualSizes(vectors[0].image.size,NSMakeSize(48,48)) && NSEqualSizes(vectors[1].image.size,NSMakeSize(80,40)));
        assert([text.string containsString:@"after vector"]);
        NSRange svgLink=[text.string rangeOfString:@"\ufffc"]; assert([text.textStorage attribute:NSLinkAttributeName atIndex:svgLink.location effectiveRange:NULL]);
        navigate(@"/floats"); waitFor(^BOOL { return [window.title hasPrefix:@"Float exclusions — Assembly"] && [status.stringValue containsString:@"ready."]; });
        NSRange wrapped=[text.string rangeOfString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
        NSRect wrappedStart=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:NSMakeRange(wrapped.location,1) actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSUInteger wrappedGlyph=[text.layoutManager glyphIndexForCharacterAtIndex:wrapped.location];
        NSRect wrappedLine=[text.layoutManager lineFragmentRectForGlyphAtIndex:wrappedGlyph effectiveRange:NULL];
        assert(wrappedLine.origin.x>=60 && wrappedStart.origin.x>=55); // glyph ink can overhang
        BOOL recoveredWidth=NO;
        for(NSUInteger k=wrapped.location;k<text.string.length;k++) {
            NSRect r=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:NSMakeRange(k,1) actualCharacterRange:NULL] inTextContainer:text.textContainer];
            if(r.origin.y>=80 && r.origin.x<1) recoveredWidth=YES;
        }
        assert(recoveredWidth);
        navigate(@"/paint-order"); waitFor(^BOOL { return [window.title hasPrefix:@"Paint order — Assembly"] && [status.stringValue containsString:@"ready."]; });
        NSRect paintCapture=NSMakeRect(0,0,300,180); NSBitmapImageRep *paintBitmap=[text bitmapImageRepForCachingDisplayInRect:paintCapture]; [text cacheDisplayInRect:paintCapture toBitmapImageRep:paintBitmap];
        NSColor *childColor=[[paintBitmap colorAtX:30*paintBitmap.pixelsWide/300 y:35*paintBitmap.pixelsHigh/180] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(childColor.redComponent>.8 && childColor.greenComponent>.6 && childColor.blueComponent<.2);
        extern uint64_t *mac_display_list; extern uint64_t *engine_display_hit(void *,double,double);
        extern void mac_display_replay(void *,NSRect); extern uint64_t mac_display_painted,mac_display_culled;
        NSRange hitText=[text.string rangeOfString:@"Hit target"]; NSRect hitRect=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:hitText actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSPoint inset=text.textContainerOrigin; uint64_t *hit=engine_display_hit(mac_display_list,NSMidX(hitRect)+inset.x,NSMidY(hitRect)+inset.y);
        assert(hit && hit[0]==4 && hit[120/8]==hitText.location);
        NSUInteger typeCounts[5]={0}; for(uint64_t i=0;i<mac_display_list[0];i++){uint64_t *c=(uint64_t *)(uintptr_t)mac_display_list[2]+i*16;if(c[0]<5)typeCounts[c[0]]++;} assert(typeCounts[1]>=2 && typeCounts[2]>=2 && typeCounts[4]);
        [NSGraphicsContext saveGraphicsState]; NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:paintBitmap];
        mac_display_replay(mac_display_list,NSMakeRect(200,150,5,5)); assert(mac_display_culled>=2 && mac_display_painted<typeCounts[1]);
        [NSGraphicsContext restoreGraphicsState];
        navigate(@"/float-hardening"); waitFor(^BOOL { return [window.title hasPrefix:@"Float hardening — Assembly"] && [status.stringValue containsString:@"ready."]; });
        uint64_t *emptyMeta=metadata(@"empty"),*autoMeta=metadata(@"autofloat"),*afterMeta=metadata(@"afterauto"),*innerMeta=metadata(@"innerfloat");
        const double *emptyRect=(const double *)(uintptr_t)emptyMeta[1752/8], *autoRect=(const double *)(uintptr_t)autoMeta[1752/8],*afterRect=(const double *)(uintptr_t)afterMeta[1752/8],*innerRect=(const double *)(uintptr_t)innerMeta[1752/8];
        assert(emptyRect && emptyRect[3]>=10 && emptyRect[5]==40);
        assert(autoRect && autoRect[3]>emptyRect[3] && autoRect[5]>40);
        assert(afterRect && afterRect[3]>=autoRect[3]+autoRect[5]);
        assert(innerRect && innerRect[2]>=20 && innerRect[2]+innerRect[4]<=220);
        const double *percentRect=(const double *)(uintptr_t)metadata(@"percentfloat")[1752/8],*widthAuto=(const double *)(uintptr_t)metadata(@"widthauto")[1752/8];
        assert(percentRect && fabs(percentRect[4]-100)<.01 && widthAuto && widthAuto[4]<=200);
        const double *nestedRect=(const double *)(uintptr_t)metadata(@"nestedauto")[1752/8],*afterNested=(const double *)(uintptr_t)metadata(@"afternested")[1752/8];
        assert(nestedRect && nestedRect[5]>=88 && afterNested[3]>=nestedRect[3]+nestedRect[5]);
        const double *nextRow=(const double *)(uintptr_t)metadata(@"nextrow")[1752/8],*lastRow=(const double *)(uintptr_t)metadata(@"lastrow")[1752/8];
        assert(nextRow && lastRow && lastRow[3]>=nextRow[3]);
        navigate(@"/tallfloat"); waitFor(^BOOL { return [window.title hasPrefix:@"Tall float — Assembly"] && [status.stringValue containsString:@"ready."]; });
        assert(text.frame.size.height>=1000);
        navigate(@"/acid1"); waitFor(^BOOL { return [window.title hasPrefix:@"CSS Test: display/box/float/clear test — Assembly"] && [status.stringValue containsString:@"ready."]; });
        assert(![text.string containsString:@"•"]);
        NSRange toggle=[text.string rangeOfString:@"toggle"], acidFooter=[text.string rangeOfString:@"This is"];
        NSFont *acidFont=[text.textStorage attribute:NSFontAttributeName atIndex:toggle.location effectiveRange:NULL];
        assert([acidFont.fontName hasPrefix:@"Verdana"]);
        NSRect tg=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:toggle actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSRect fg=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:acidFooter actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSUInteger footerGlyph=[text.layoutManager glyphIndexForCharacterAtIndex:acidFooter.location];
        NSRect footerLine=[text.layoutManager lineFragmentRectForGlyphAtIndex:footerGlyph effectiveRange:NULL];
        NSUInteger toggleGlyph=[text.layoutManager glyphIndexForCharacterAtIndex:toggle.location];
        NSRect toggleLine=[text.layoutManager lineFragmentRectForGlyphAtIndex:toggleGlyph effectiveRange:NULL];
        assert(fabs(toggleLine.origin.x-40)<.01 && fabs(toggleLine.size.height-10)<.01 && fabs(footerLine.origin.y-335)<.01 && fabs(fg.origin.y-335)<3 && tg.size.width>0);
        NSRect capture=NSMakeRect(0,0,600,500);
        NSBitmapImageRep *acidBitmap=[text bitmapImageRepForCachingDisplayInRect:capture];
        [text cacheDisplayInRect:capture toBitmapImageRep:acidBitmap];
        // Display-profile conversion can alter saturated channel values; the
        // tolerance still distinguishes all five test colors and white gaps.
        const int samples[][5]={{1,1,0,0,255},{10,10,0,0,255},{16,16,0,0,0},{45,60,204,0,0},{108,80,255,255,255},{145,80,255,204,0},{405,80,255,204,0},{250,80,0,0,0},{155,260,0,0,0},{290,280,255,204,0}};
        for(size_t i=0;i<sizeof(samples)/sizeof(*samples);i++) {
            const int *p=samples[i]; NSColor *c=[[acidBitmap colorAtX:p[0]*acidBitmap.pixelsWide/600 y:p[1]*acidBitmap.pixelsHigh/500] colorUsingColorSpace:acidBitmap.colorSpace];
            assert(fabs(c.redComponent-p[2]/255.0)<.23 && fabs(c.greenComponent-p[3]/255.0)<.23 && fabs(c.blueComponent-p[4]/255.0)<.23);
        }
        int beforeDenied=count();
        sqlite3_set_authorizer(mac_db,denyInsert,NULL);
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"] && [status.stringValue containsString:@"history could not be saved"]; });
        sqlite3_set_authorizer(mac_db,NULL,NULL); assert(count()==beforeDenied);
        int beforeSlow=count();
        navigate(@"/slow"); waitFor(^BOOL { return slowStarted; });
        navigate(@"/second"); waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert(count()==beforeSlow+2 && ![text.string containsString:@"Must never commit"]);
        // Switching engines cancels in-flight work and hides the native renderer.
        address.stringValue=@"";
        mac_engine_toggle(nil,NULL,nil);
        assert(!mac_engine_enabled && !web.hidden && scroll.hidden);
        method_setImplementation(method,original);
        sqlite3_close(mac_db);mac_db=NULL;
        puts("PASS: assembly renderer transport, native links/Unicode ranges, back/forward, scrolling, history, responsive CSS/box sizing/child selectors, progressive resources, images, native GET/POST forms and reflow preservation, response limits, stale callbacks, and WebKit switching");
    }
    return 0;
}
