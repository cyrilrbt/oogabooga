// Test-only in-process transport and native-view integration for the assembly engine.
#import <Cocoa/Cocoa.h>
#import <AppKit/NSTypesetter.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sqlite3.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
#include <stdatomic.h>
typedef struct { uint64_t type,parent,first,last,previous,next; char *name,*value; void *attributes; uint64_t height,source_offset,snapshot_version; } MutableNode;
extern MutableNode *engine_dom_node(void *,uint64_t);
extern uint64_t engine_dom_get_element_by_id(void *,const char *);
extern uint64_t engine_dom_create_element(void *,const char *,size_t);
extern uint64_t engine_dom_create_text(void *,const char *,size_t);
extern int engine_dom_insert_before(void *,uint64_t,uint64_t,uint64_t);
extern int engine_dom_remove(void *,uint64_t);
extern int engine_dom_set_text(void *,uint64_t,const char *,size_t);
extern int engine_dom_set_attribute(void *,uint64_t,const char *,const char *,size_t);
static atomic_uint mutationCSSRequests,imageRequests,importRequests,fontRequests;
static atomic_bool fontStarted;
extern Class mac_register_class(void);
extern void mac_engine_toggle(id,SEL,id);
extern void mac_engine_navigate(void);
extern void mac_engine_resize(id,SEL,id);
extern void mac_engine_reload(void);
extern __unsafe_unretained NSDictionary *engine_controls;
extern id mac_control_key(uint64_t);
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
extern NSURL *mac_scene_link_at_point(double,double);
extern NSRect mac_atomic_text_rect(NSUInteger,NSUInteger);
extern double mac_atomic_text_baseline(NSUInteger);
extern int mac_scene_scroll_at_point(double,double,double,double);
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
    if([path hasPrefix:@"/styles/"]||[path isEqual:@"/assets/two.css"]||[path isEqual:@"/assets/embedded.css"]) atomic_fetch_add(&importRequests,1);
    if([path isEqual:@"/assets/mutation.css"]) atomic_fetch_add(&mutationCSSRequests,1);
    if([path isEqual:@"/assets/image.png"]) atomic_fetch_add(&imageRequests,1);
    if([path isEqual:@"/assets/ooga-test.ttf"]) {
        atomic_fetch_add(&fontRequests,1);atomic_store(&fontStarted,true);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            if(self.stopped)return;
            NSHTTPURLResponse *r=[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"font/ttf"}];
            [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [self.client URLProtocol:self didLoadData:[NSData dataWithContentsOfFile:@"tests/fixtures/ooga-test.ttf"]];
            [self.client URLProtocolDidFinishLoading:self];
        });return;
    }
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
    if([path isEqual:@"/atomic"]) html=[NSString stringWithContentsOfFile:@"tests/fixtures/compat-inline-boxes.html" encoding:NSUTF8StringEncoding error:NULL];
    if([path isEqual:@"/backgrounds"]) html=@"<title>Background images</title><link rel=stylesheet media='handheld, all' href='/bg-assets/sheet.css'><link rel=stylesheet media='screen and (min-width:900px)' href='/bg-assets/wide.css'><link rel=stylesheet media='print, speech' href='/must-not-load.css'><div id=bgpaint></div><div id=bgtile></div><div id=bgmissing></div><input type=submit id=bgsubmit value='' style='width:60px;height:30px'>";
    if([path isEqual:@"/bg-assets/sheet.css"]) {html=@"body{margin:0;background:white}#bgpaint{width:100px;height:60px;background-image:url(tile.svg);background-size:20px 10px;background-position:center;background-repeat:no-repeat}#bgtile{width:100px;height:60px;background:url(tile.svg);background-size:20px 10px;background-repeat:repeat}#bgmissing{width:100px;height:30px;background:green;background-image:url(missing.png)}#bgsubmit{background-image:url(tile.svg);background-size:20px 10px;background-position:center;background-repeat:no-repeat;border:none}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/bg-assets/tile.svg"]) {html=@"<svg width='40' height='20'><rect width='40' height='20' fill='blue'/></svg>";headers=@{@"Content-Type":@"image/svg+xml"};}
    if([path isEqual:@"/bg-assets/wide.css"]) {html=@"#bgpaint{color:red}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/bg-assets/missing.png"]) status=404;
    assert(![path isEqual:@"/must-not-load.css"]);
    if([path isEqual:@"/button-styles"]) html=@"<title>Button styles</title><form action='/form-result' method=get><input name=query value='CSS button'><input id=plainbutton type=submit value='Plain'><input id=flatbutton type=submit name=go value='Styled' style='background:#123456;color:white;border:2px solid red;border-radius:8px;padding:8px 20px;width:200px;height:50px'><input id=clearbutton type=submit value='Clear' style='border:none;background:transparent;padding:0'></form>";
    if([path isEqual:@"/input-borders"]) html=@"<title>Input borders</title><style>body{background:white}input{width:300px;height:30px}</style><input id=defaultborder value='Editable café'><input id=noborder style='border:none' value='No outline'><input id=customborder style='border:2px solid red;border-radius:0' value='Red outline'><input id=roundborder style='border:1px solid blue;border-radius:50%' value='Rounded'>";
    if([path isEqual:@"/typography"]) html=@"<title>Typography</title><style>body{margin:0;font:16px monospace}.track{letter-spacing:2px;word-spacing:5px}.pre{white-space:pre}.nowrap{white-space:nowrap;width:100px}#image{min-width:120px;max-width:160px;max-height:80px}</style><p class=track>A café 🌐 B</p><p>base <span style='vertical-align:super'>raised</span> <span style='vertical-align:-3px'>lowered</span></p><div class=pre> a  b\n c </div><div class=nowrap>Long unbroken text stays on a single line beyond the box</div><img id=image src=/assets/image.png>";
    if([path isEqual:@"/mutation"]) html=@"<title>Mutable tree</title><link rel=stylesheet href='/assets/mutation.css'><style>.hot{font-weight:700}</style><div id=container><p id=message>Before mutation</p><p id=proof>External CSS survives</p><form action=/posted method=post><input id=keep name=q value=start><input id=remove name=removed value=old><input id=mutatesend type=submit value=Submit></form><img id=photo src=/assets/image.png width=80></div>";
    if([path isEqual:@"/assets/mutation.css"]) { html=@"#message{color:red}#proof{color:green}";headers=@{@"Content-Type":@"text/css"}; }
    if([path isEqual:@"/imports"]) html=@"<title>Imported styles</title><link rel=stylesheet id=importroot href=/styles/root.css><style>@import '/assets/embedded.css';#importtarget{color:green}</style><p id=importtarget>Import cascade</p><p id=importnested>Nested import</p><p id=importcondition>Conditional import</p>";
    if([path isEqual:@"/styles/root.css"]) {html=@"@import 'nested/one.css' screen;@import '../assets/two.css' screen and (min-width:900px);#importtarget{color:red}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/styles/nested/one.css"]) {html=@"@import '../root.css';#importtarget{font-weight:700}#importnested{color:blue}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/assets/two.css"]) {html=@"#importcondition{color:purple}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/assets/embedded.css"]) {html=@"#importnested{font-style:italic}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/scene"]) html=@"<title>Scene interaction</title><style>body{margin:0;font:16px/1 monospace}#moving{position:relative;left:120px;top:20px;width:200px;height:40px;background:#eef}#selecting{position:relative;left:120px;top:20px;width:250px}#overlay{position:absolute;left:120px;top:20px;width:30px;height:20px;background:red;z-index:5}</style><div id=moving><a href=/second>Moved link</a></div><p id=selecting>Selectable text</p><div id=overlay></div>";
    if([path isEqual:@"/scene-controls"]) html=@"<title>Scene controls</title><style>body{margin:0;font:16px/1 monospace}#clipper{position:relative;left:50px;top:10px;width:100px;height:40px;overflow:hidden}</style><div id=clipper><input id=clipped style='width:150px;height:24px' value=original></div>";
    if([path isEqual:@"/scene-scroll"]) html=@"<title>Scene scrolling</title><style>body{margin:0;font:16px/1 monospace}div,p{margin:0}#port{overflow:auto;width:200px;height:40px}#inside{height:200px;width:200px;background:#eef}</style><div id=port><div id=inside><p>Scroll top</p><div style='height:120px'></div><a href=/second>Scroll link</a></div></div><p>After container</p>";
    if([path isEqual:@"/webfont"]) html=@"<title>Web fonts</title><link rel=stylesheet href=/font-css/root.css><p id=fonttarget style=\"font:20px 'Ooga Web',monospace\">WWWW</p><input id=fontedit value=original>";
    if([path isEqual:@"/font-css/root.css"]) {html=@"@font-face{font-family:'Ooga Web';src:url(skip.woff2) format('woff2'),url(missing.ttf) format('truetype'),url('../assets/ooga-test.ttf') format('truetype');font-weight:400;font-style:normal}";headers=@{@"Content-Type":@"text/css"};}
    if([path isEqual:@"/font-css/missing.ttf"]) {atomic_fetch_add(&fontRequests,1);status=404;}
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
static NSColor *inputEdge(NSView *view) {
    NSInteger width=(NSInteger)view.bounds.size.width,height=(NSInteger)view.bounds.size.height;
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    CGContextSetRGBFillColor(context.CGContext,1,1,1,1);CGContextFillRect(context.CGContext,CGRectMake(0,0,width,height));
    [view.layer renderInContext:context.CGContext];
    return [[bitmap colorAtX:0 y:height/2] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
}
static NSRect paintRect(NSString *identifier) {
    uint64_t *command=(void *)(uintptr_t)metadata(identifier)[1816/8];assert(command&&command[0]==1);
    return *(NSRect *)(command+2);
}
static id control(NSString *identifier) {
    uint64_t *doc=engine_document; unsigned char *meta=(void *)(uintptr_t)doc[9];
    for(uint64_t i=0;i<doc[3];i++) { char *name=*(char **)(meta+i*2048); if(name && [identifier isEqualToString:[NSString stringWithUTF8String:name]]) return engine_controls[mac_control_key(i)]; }
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
static NSEvent *sceneMouse(NSTextView *text,NSEventType type,NSPoint viewPoint) {
    return [NSEvent mouseEventWithType:type location:[text convertPoint:viewPoint toView:nil] modifierFlags:0 timestamp:0 windowNumber:text.window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
}
static NSEvent *sceneKey(NSTextView *text,unsigned short code,NSEventModifierFlags flags) {
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0 windowNumber:text.window.windowNumber context:nil characters:@"\uf701" charactersIgnoringModifiers:@"\uf701" isARepeat:NO keyCode:code];
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
        // Match CI's width-consuming scrollbars even on machines configured
        // for overlays, so responsive fixture breakpoints are reproducible.
        scroll.scrollerStyle=NSScrollerStyleLegacy;
        mac_engine_resize(nil,NULL,nil);
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
        assert(ps.alignment==NSTextAlignmentCenter && ps.textBlocks.count>=1 && ps.headIndent==0 && ps.tailIndent==0);
        NSTextBlock *noticeBox=ps.textBlocks.lastObject;
        CGFloat noticeTop=[noticeBox widthForLayer:NSTextBlockMargin edge:NSMinYEdge],noticeBottom=0;
        for(NSTextBlock *box in ps.textBlocks) noticeBottom+=[box widthForLayer:NSTextBlockMargin edge:NSMaxYEdge];
        // Vertical margins can escape into a borderless containing block.
        if(noticeTop!=12 || noticeBottom!=16) for(NSTextBlock *box in ps.textBlocks) NSLog(@"Notice margin box %@: %.2f %.2f %.2f %.2f",box,[box widthForLayer:NSTextBlockMargin edge:NSMinXEdge],[box widthForLayer:NSTextBlockMargin edge:NSMinYEdge],[box widthForLayer:NSTextBlockMargin edge:NSMaxXEdge],[box widthForLayer:NSTextBlockMargin edge:NSMaxYEdge]);
        assert([noticeBox widthForLayer:NSTextBlockMargin edge:NSMinXEdge]==18 && [noticeBox widthForLayer:NSTextBlockMargin edge:NSMaxXEdge]==14 && noticeTop==12 && noticeBottom==16);
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
        assert(boxStyle.textBlocks.count>=1); // collapsed ancestor margins may add a containing block
        assert(((NSFont *)[text.textStorage attribute:NSFontAttributeName atIndex:boxRange.location effectiveRange:NULL]).pointSize==19);
        assert([text.effectiveAppearance.name isEqual:NSAppearanceNameAqua]);
        NSRange measured=[text.string rangeOfString:@"Box content with wrapping text to measure inside a fixed width and padding."];
        NSRect measuredRect=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:measured actualCharacterRange:NULL] inTextContainer:text.textContainer];
        assert(measuredRect.size.width<=301 && measuredRect.origin.x>=25 && measuredRect.size.height>20);
        NSTextBlock *box=boxStyle.textBlocks.lastObject;
        assert(box.contentWidth==300 && [box widthForLayer:NSTextBlockPadding edge:NSMinXEdge]==16 && [box widthForLayer:NSTextBlockPadding edge:NSMinYEdge]==12);
        assert([box widthForLayer:NSTextBlockBorder edge:NSMinXEdge]==2 && [box widthForLayer:NSTextBlockMargin edge:NSMinXEdge]==10);
        NSRange nestedBoxRange=[text.string rangeOfString:@"Nested box"];
        NSArray<NSTextBlock *> *nestedBoxes=((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:nestedBoxRange.location effectiveRange:NULL]).textBlocks;
        assert(nestedBoxes.count==boxStyle.textBlocks.count+1 && nestedBoxes.lastObject.contentWidth==120 && [nestedBoxes.lastObject widthForLayer:NSTextBlockPadding edge:NSMinXEdge]==4);
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
        assert(fabs([signin.superview convertRect:signin.frame toView:text].origin.x-(boxGlyphRect.origin.x+text.textContainerInset.width))<1);
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
        assert(fabs([bordered.superview convertRect:bordered.frame toView:text].origin.x-(borderedGlyphRect.origin.x+text.textContainerInset.width+4))<1);
        NSRange following=[text.string rangeOfString:@"after café"]; assert(following.location!=NSNotFound && [[text.textStorage attribute:NSLinkAttributeName atIndex:following.location effectiveRange:NULL] isEqual:[NSURL URLWithString:@"https://engine.test/afterbox"]]);
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"signin")==signin && signin.frame.size.height==40);
        [window setContentSize:NSMakeSize(450,780)]; mac_engine_resize(nil,NULL,nil);
        assert(signin.hidden && [text.string containsString:@"Sign in 🌐"]);
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"signin")==signin && !signin.hidden && signin.frame.size.height==40);
        [signin performClick:nil]; waitFor(^BOOL { return [window.title hasPrefix:@"Second — Assembly"]; });
        assert([address.stringValue isEqual:@"https://engine.test/second"]);
        // Legacy scrollbars consume viewport width. A 650pt window can yield
        // only 595pt of page space, activating this fixture's 600px breakpoint.
        // Force that mode, and start wide enough to test the fixed-width form.
        NSScrollerStyle previousScrollerStyle=scroll.scrollerStyle;
        scroll.scrollerStyle=NSScrollerStyleLegacy;
        [window setContentSize:NSMakeSize(700,780)]; mac_engine_resize(nil,NULL,nil);
        // Compatibility defaults vary with the linked AppKit version. Rendering
        // must restore table-capable layout instead of relying on that default.
        text.layoutManager.typesetterBehavior=NSTypesetterOriginalBehavior;
        assert(text.layoutManager.typesetterBehavior==NSTypesetterOriginalBehavior);
        navigate(@"/flow"); waitFor(^BOOL { return [window.title hasPrefix:@"Flow layout — Assembly"] && [status.stringValue containsString:@"ready."]; });
        assert(text.layoutManager.typesetterBehavior==NSTypesetterBehavior_10_4);
        assert(text.textContainer.size.width>600);
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
        if(!(flexQuery && flexSend && fabs(flexQuery.frame.size.width-390)<1 && fabs(flexSend.frame.size.width-100)<1)) NSLog(@"Flex controls at viewport %.2f: query %@, send %@",text.textContainer.size.width,NSStringFromRect(flexQuery.frame),NSStringFromRect(flexSend.frame));
        assert(flexQuery && flexSend && fabs(flexQuery.frame.size.width-390)<1 && fabs(flexSend.frame.size.width-100)<1);
        assert(fabs(flexQuery.frame.origin.y-flexSend.frame.origin.y)<5);
        flexQuery.stringValue=@"kept after flex resize";
        // Reproduce CI's formerly failing size: the media rule expands the
        // form to the page width, leaving 100px for submit and a 10px gap.
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        assert(text.textContainer.size.width<=600);
        assert(control(@"flexq")==flexQuery && fabs(flexQuery.frame.size.width-(text.textContainer.size.width-110))<1 && fabs(flexSend.frame.size.width-100)<1);
        [window setContentSize:NSMakeSize(500,780)]; mac_engine_resize(nil,NULL,nil);
        assert(control(@"flexq")==flexQuery && [flexQuery.stringValue isEqual:@"kept after flex resize"] && flexQuery.frame.size.width<390);
        scroll.scrollerStyle=previousScrollerStyle;
        [window setContentSize:NSMakeSize(650,780)]; mac_engine_resize(nil,NULL,nil);
        NSRange upper=[text.string rangeOfString:@"Upper"],lower=[text.string rangeOfString:@"Lower"],wide=[text.string rangeOfString:@"Wide footer"];
        NSTextTableBlock *ub=(id)((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:upper.location effectiveRange:NULL]).textBlocks.lastObject;
        NSTextTableBlock *lb=(id)((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:lower.location effectiveRange:NULL]).textBlocks.lastObject;
        NSTextTableBlock *wb=(id)((NSParagraphStyle *)[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:wide.location effectiveRange:NULL]).textBlocks.lastObject;
        assert(ub.table==lb.table && lb.table==wb.table && ub.startingColumn==1 && lb.startingRow==1 && wb.columnSpan==2);
        navigate(@"/atomic");waitFor(^BOOL{return [window.title hasPrefix:@"Inline formatting contexts — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSControl *atomicOne=control(@"one"),*atomicTwo=control(@"two");
        assert(atomicOne && atomicTwo);
        NSRect atomicOneRect=[atomicOne.superview convertRect:atomicOne.frame toView:text],atomicTwoRect=[atomicTwo.superview convertRect:atomicTwo.frame toView:text];
        NSLog(@"Atomic controls: %@ / %@",NSStringFromRect(atomicOneRect),NSStringFromRect(atomicTwoRect));
        assert(fabs(atomicOneRect.origin.y-atomicTwoRect.origin.y)<1 && atomicTwoRect.origin.x>=NSMaxX(atomicOneRect)+7);
        assert([text.string containsString:@"Inside top"] && [text.string containsString:@"Inside bottom"]);
        NSRect atomicFrame=paintRect(@"frameone");
        assert(fabs(atomicOneRect.origin.x-atomicFrame.origin.x-1)<1 && fabs(atomicOneRect.size.width-(atomicFrame.size.width-2))<1);
        assert(fabs(atomicOneRect.origin.y-atomicFrame.origin.y-1)<1 && fabs(atomicOneRect.size.height-(atomicFrame.size.height-2))<1);
        NSRect emptyInline=paintRect(@"empty"),topInline=paintRect(@"aligntop"),bottomInline=paintRect(@"alignbottom");
        assert(fabs(emptyInline.size.width-24)<1 && fabs(emptyInline.size.height-30)<1);
        assert(fabs(NSMaxY(topInline)-NSMaxY(bottomInline))<1);
        NSRange innerLink=[text.string rangeOfString:@"Inner link"],insideTop=[text.string rangeOfString:@"Inside top"];
        NSRect innerLinkRect=mac_atomic_text_rect(innerLink.location,innerLink.length);
        assert([mac_scene_link_at_point(NSMidX(innerLinkRect),NSMidY(innerLinkRect)).path isEqual:@"/second"]);
        text.selectedRange=NSMakeRange(insideTop.location,innerLink.location+innerLink.length-insideTop.location);
        assert([[text.string substringWithRange:text.selectedRange] containsString:@"Inside bottom"]);
        assert([[text.string substringWithRange:text.selectedRange] containsString:@"Inner link"]);
        NSRect selectionRect=mac_atomic_text_rect(insideTop.location,insideTop.length);
        NSRect selectionCapture=NSMakeRect(0,0,300,120);
        NSBitmapImageRep *selectionBitmap=[text bitmapImageRepForCachingDisplayInRect:selectionCapture];[text cacheDisplayInRect:selectionCapture toBitmapImageRep:selectionBitmap];
        __block NSColor *selectionColor;
        [text.effectiveAppearance performAsCurrentDrawingAppearance:^{selectionColor=[NSColor.selectedTextBackgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];}];
        NSUInteger selectedPixels=0;
        for(NSInteger y=MAX(0,(NSInteger)selectionRect.origin.y);y<MIN(120,(NSInteger)NSMaxY(selectionRect));y++)for(NSInteger x=MAX(0,(NSInteger)selectionRect.origin.x);x<MIN(300,(NSInteger)NSMaxX(selectionRect));x++) {
            NSColor *pixel=[[selectionBitmap colorAtX:x*selectionBitmap.pixelsWide/300 y:y*selectionBitmap.pixelsHigh/120] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            selectedPixels += fabs(pixel.redComponent-selectionColor.redComponent)<.08 && fabs(pixel.greenComponent-selectionColor.greenComponent)<.08 && fabs(pixel.blueComponent-selectionColor.blueComponent)<.08;
        }
        assert(selectedPixels>5);
        [window setContentSize:NSMakeSize(350,780)];mac_engine_resize(nil,NULL,nil);
        assert(control(@"one")==atomicOne && control(@"two")==atomicTwo);
        innerLink=[text.string rangeOfString:@"Inner link"];innerLinkRect=mac_atomic_text_rect(innerLink.location,innerLink.length);
        assert([mac_scene_link_at_point(NSMidX(innerLinkRect),NSMidY(innerLinkRect)).path isEqual:@"/second"]);
        [window setContentSize:NSMakeSize(200,780)];mac_engine_resize(nil,NULL,nil);
        atomicOneRect=[atomicOne.superview convertRect:atomicOne.frame toView:text];atomicTwoRect=[atomicTwo.superview convertRect:atomicTwo.frame toView:text];
        assert(atomicTwoRect.origin.y>=NSMaxY(atomicOneRect));
        atomicFrame=paintRect(@"frametwo");assert(fabs(atomicTwoRect.origin.x-atomicFrame.origin.x-1)<1 && fabs(atomicTwoRect.origin.y-atomicFrame.origin.y-1)<1);
        [window setContentSize:NSMakeSize(720,780)];mac_engine_resize(nil,NULL,nil);
        navigate(@"/input-borders");waitFor(^BOOL{return [window.title hasPrefix:@"Input borders — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSTextField *defaultBorder=control(@"defaultborder"),*noBorder=control(@"noborder"),*customBorder=control(@"customborder");
        assert(defaultBorder.bezeled && defaultBorder.layer.borderWidth==1 && defaultBorder.frame.size.height==30);
        assert(!noBorder.bezeled && !noBorder.bordered && noBorder.layer.borderWidth==0);
        NSColor *defaultEdge=inputEdge(defaultBorder),*noneEdge=inputEdge(noBorder);
        assert(defaultEdge.redComponent<.8 && fabs(defaultEdge.redComponent-defaultEdge.greenComponent)<.02);
        assert(noneEdge.redComponent>.95 && noneEdge.greenComponent>.95 && noneEdge.blueComponent>.95);
        assert(((NSTextField *)control(@"roundborder")).layer.cornerRadius==15);
        NSColor *customBorderColor=[NSColor colorWithCGColor:customBorder.layer.borderColor];
        assert(customBorder.layer.borderWidth==2 && customBorder.layer.cornerRadius==0 && customBorderColor.redComponent>.99 && customBorderColor.greenComponent<.01);
        assert([window makeFirstResponder:defaultBorder]);NSText *borderEditor=defaultBorder.currentEditor;assert(borderEditor);borderEditor.string=@"Still editable 🌐";borderEditor.selectedRange=NSMakeRange(2,3);
        [window setContentSize:NSMakeSize(600,780)];mac_engine_resize(nil,NULL,nil);
        assert(control(@"defaultborder")==defaultBorder && defaultBorder.currentEditor==borderEditor && NSEqualRanges(borderEditor.selectedRange,NSMakeRange(2,3)) && [borderEditor.string isEqual:@"Still editable 🌐"]);
        assert(defaultBorder.layer.borderWidth==1 && noBorder.layer.borderWidth==0 && customBorder.layer.borderWidth==2);
        navigate(@"/backgrounds");waitFor(^BOOL{return [window.title hasPrefix:@"Background images — Assembly"]&&[status.stringValue containsString:@"ready."];});
        assert(!strcmp((char *)(uintptr_t)metadata(@"bgpaint")[30],"https://engine.test/bg-assets/tile.svg"));
        NSRect bgCapture=NSMakeRect(0,0,200,200);NSBitmapImageRep *bgBitmap=[text bitmapImageRepForCachingDisplayInRect:bgCapture];[text cacheDisplayInRect:bgCapture toBitmapImageRep:bgBitmap];
        NSRect bgPaint=paintRect(@"bgpaint"),bgTile=paintRect(@"bgtile");
        NSColor *centerPixel=[[bgBitmap colorAtX:NSMidX(bgPaint) y:NSMidY(bgPaint)] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        NSColor *edgePixel=[[bgBitmap colorAtX:NSMinX(bgPaint)+2 y:NSMinY(bgPaint)+2] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        NSColor *tilePixel=[[bgBitmap colorAtX:NSMinX(bgTile)+25 y:NSMinY(bgTile)+15] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(centerPixel.blueComponent>.9 && centerPixel.redComponent<.1 && edgePixel.redComponent>.9);
        assert(tilePixel.blueComponent>.9 && tilePixel.redComponent<.1);
        assert(metadata(@"bgpaint")[4]!=0xff0000);
        [window setContentSize:NSMakeSize(1000,780)];mac_engine_resize(nil,NULL,nil);assert(metadata(@"bgpaint")[4]==0xff0000);
        [window setContentSize:NSMakeSize(650,780)];mac_engine_resize(nil,NULL,nil);assert(metadata(@"bgpaint")[4]!=0xff0000);
        NSButton *bgSubmit=control(@"bgsubmit");assert(bgSubmit && !bgSubmit.bordered);
        NSBitmapImageRep *buttonPixels=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:60 pixelsHigh:30 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState];[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:buttonPixels]];
        [bgSubmit.cell drawWithFrame:NSMakeRect(0,0,60,30) inView:bgSubmit];[NSGraphicsContext restoreGraphicsState];
        NSColor *buttonImagePixel=[[buttonPixels colorAtX:30 y:15] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];assert(buttonImagePixel.blueComponent>.9 && buttonImagePixel.redComponent<.1);

        navigate(@"/button-styles");waitFor(^BOOL{return [window.title hasPrefix:@"Button styles — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSButton *plainButton=control(@"plainbutton"),*flatButton=control(@"flatbutton"),*clearButton=control(@"clearbutton");
        assert(plainButton.bordered && !flatButton.bordered && !clearButton.bordered);
        assert(flatButton.layer.borderWidth==2 && flatButton.layer.cornerRadius==8 && clearButton.layer.borderWidth==0);
        NSColor *buttonBackground=[NSColor colorWithCGColor:flatButton.layer.backgroundColor];
        assert(fabs(buttonBackground.redComponent-18./255)<.01 && fabs(buttonBackground.blueComponent-86./255)<.01);
        NSColor *buttonForeground=[flatButton.attributedTitle attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
        assert(buttonForeground.redComponent>.99 && buttonForeground.greenComponent>.99);
        NSRect buttonTitle=[flatButton.cell titleRectForBounds:flatButton.bounds];
        assert(buttonTitle.origin.x>=22 && buttonTitle.origin.y>=10 && NSMaxX(buttonTitle)<=flatButton.bounds.size.width-22 && NSMaxY(buttonTitle)<=flatButton.bounds.size.height-10);
        assert(flatButton.enabled && flatButton.target==mac_delegate && flatButton.action);
        [window setContentSize:NSMakeSize(650,780)];mac_engine_resize(nil,NULL,nil);
        assert(control(@"flatbutton")==flatButton && !flatButton.bordered && flatButton.layer.borderWidth==2);
        [flatButton performClick:nil];
        waitFor(^BOOL{return [address.stringValue containsString:@"query=CSS+button"] && [address.stringValue containsString:@"go=Styled"];});
        navigate(@"/typography");waitFor(^BOOL{return [window.title hasPrefix:@"Typography — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSRange tracked=[text.string rangeOfString:@"A café 🌐 B"];
        assert(tracked.location!=NSNotFound);
        assert([[text.textStorage attribute:NSKernAttributeName atIndex:tracked.location effectiveRange:NULL] integerValue]==2);
        assert([[text.textStorage attribute:NSKernAttributeName atIndex:tracked.location+1 effectiveRange:NULL] integerValue]==7);
        assert([text.string containsString:@" a  b\n c "]);
        NSRange raised=[text.string rangeOfString:@"raised"],lowered=[text.string rangeOfString:@"lowered"];
        assert([[text.textStorage attribute:NSBaselineOffsetAttributeName atIndex:raised.location effectiveRange:NULL] doubleValue]>4);
        assert([[text.textStorage attribute:NSBaselineOffsetAttributeName atIndex:lowered.location effectiveRange:NULL] doubleValue]==-3);
        NSRange nowrap=[text.string rangeOfString:@"Long unbroken text"];
        NSParagraphStyle *nowrapStyle=[text.textStorage attribute:NSParagraphStyleAttributeName atIndex:nowrap.location effectiveRange:NULL];
        assert(nowrapStyle.lineBreakMode==NSLineBreakByClipping);
        navigate(@"/imports");waitFor(^BOOL{return [window.title hasPrefix:@"Imported styles — Assembly"]&&[status.stringValue containsString:@"ready."];});
        assert(atomic_load(&importRequests)==4); // ancestor cycle never makes a request
        NSRange importTarget=[text.string rangeOfString:@"Import cascade"],importNested=[text.string rangeOfString:@"Nested import"],importCondition=[text.string rangeOfString:@"Conditional import"];
        NSColor *importColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:importTarget.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        NSColor *nestedImportColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:importNested.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        NSFont *importFont=[text.textStorage attribute:NSFontAttributeName atIndex:importTarget.location effectiveRange:NULL],*importNestedFont=[text.textStorage attribute:NSFontAttributeName atIndex:importNested.location effectiveRange:NULL];
        assert(importColor.greenComponent>.49&&importColor.redComponent<.01&&nestedImportColor.blueComponent>.99);
        assert((importFont.fontDescriptor.symbolicTraits&NSFontBoldTrait)&&(importNestedFont.fontDescriptor.symbolicTraits&NSFontItalicTrait));
        assert(![[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:importCondition.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace] isEqual:NSColor.purpleColor]);
        [window setContentSize:NSMakeSize(1100,780)];mac_engine_resize(nil,NULL,nil);
        importCondition=[text.string rangeOfString:@"Conditional import"];
        NSColor *conditionColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:importCondition.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(conditionColor.redComponent>.49&&conditionColor.blueComponent>.49&&conditionColor.greenComponent<.01&&atomic_load(&importRequests)==4);
        [window setContentSize:NSMakeSize(650,780)];mac_engine_resize(nil,NULL,nil);
        void *importModel=(void *)(uintptr_t)((uint64_t *)engine_document)[12];
        uint64_t importRootNode=engine_dom_get_element_by_id(importModel,"importroot"),insertedMeta=engine_dom_create_element(importModel,"meta",4);
        assert(importRootNode&&insertedMeta&&!engine_dom_insert_before(importModel,engine_dom_node(importModel,importRootNode)->parent,insertedMeta,importRootNode));
        mac_engine_refresh();waitFor(^BOOL{return [status.stringValue containsString:@"ready."];});
        importNested=[text.string rangeOfString:@"Nested import"];
        nestedImportColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:importNested.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(nestedImportColor.blueComponent>.99&&atomic_load(&importRequests)==4);
        navigate(@"/scene");waitFor(^BOOL{return [window.title hasPrefix:@"Scene interaction — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSRange sceneLink=[text.string rangeOfString:@"Moved link"],sceneSelect=[text.string rangeOfString:@"Selectable text"];
        NSRect sceneLinkGlyph=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:NSMakeRange(sceneLink.location+7,1) actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSPoint sceneLinkPoint=NSMakePoint(NSMidX(sceneLinkGlyph)+120,NSMidY(sceneLinkGlyph)+20);
        assert([mac_scene_link_at_point(sceneLinkPoint.x,sceneLinkPoint.y).path isEqual:@"/second"]);
        assert(!mac_scene_link_at_point(125,25)); // opaque overlay blocks the link
        assert(!mac_scene_link_at_point(NSMidX(sceneLinkGlyph),NSMidY(sceneLinkGlyph))); // old visual location is inactive
        NSRect sceneStartGlyph=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:NSMakeRange(sceneSelect.location,1) actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSRect sceneEndGlyph=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:NSMakeRange(sceneSelect.location+6,1) actualCharacterRange:NULL] inTextContainer:text.textContainer];
        NSPoint sceneStart=NSMakePoint(NSMinX(sceneStartGlyph)+120,NSMidY(sceneStartGlyph)+20),sceneEnd=NSMakePoint(NSMaxX(sceneEndGlyph)+120,NSMidY(sceneEndGlyph)+20);
        [text mouseDown:sceneMouse(text,NSEventTypeLeftMouseDown,sceneStart)];
        [text mouseDragged:sceneMouse(text,NSEventTypeLeftMouseDragged,sceneEnd)];
        [text mouseUp:sceneMouse(text,NSEventTypeLeftMouseUp,sceneEnd)];
        assert(text.selectedRange.length>=5&&text.selectedRange.location>=sceneSelect.location&&NSMaxRange(text.selectedRange)<=NSMaxRange(sceneSelect));
        [text cursorUpdate:sceneMouse(text,NSEventTypeMouseMoved,sceneLinkPoint)];assert(NSCursor.currentCursor==NSCursor.pointingHandCursor);
        [text cursorUpdate:sceneMouse(text,NSEventTypeMouseMoved,NSMakePoint(125,25))];assert(NSCursor.currentCursor==NSCursor.arrowCursor);
        [text mouseDown:sceneMouse(text,NSEventTypeLeftMouseDown,sceneLinkPoint)];waitFor(^BOOL{return [window.title hasPrefix:@"Second — Assembly"];});
        navigate(@"/scene-controls");waitFor(^BOOL{return [window.title hasPrefix:@"Scene controls — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSTextField *sceneField=control(@"clipped");NSView *sceneHost=sceneField.superview;
        assert(sceneField&&sceneHost!=text&&sceneHost.isFlipped&&fabs(sceneField.frame.size.width-150)<1&&sceneHost.frame.size.width<=101);
        sceneField.stringValue=@"kept editor value";
        assert([window makeFirstResponder:sceneField]);NSText *sceneEditor=sceneField.currentEditor;assert(sceneEditor);sceneEditor.selectedRange=NSMakeRange(2,3);
        [window setContentSize:NSMakeSize(700,780)];mac_engine_resize(nil,NULL,nil);
        assert(control(@"clipped")==sceneField&&sceneField.superview==sceneHost&&sceneField.currentEditor==sceneEditor&&NSEqualRanges(sceneEditor.selectedRange,NSMakeRange(2,3)));
        void *controlModel=(void *)(uintptr_t)((uint64_t *)engine_document)[12];uint64_t clipperNode=engine_dom_get_element_by_id(controlModel,"clipper");
        const char *movedClip="position:relative;left:80px;top:10px;width:100px;height:40px;overflow:hidden";
        assert(!engine_dom_set_attribute(controlModel,clipperNode,"style",movedClip,strlen(movedClip)));mac_engine_refresh();
        assert(sceneField.superview==sceneHost&&sceneField.currentEditor==sceneEditor&&NSEqualRanges(sceneEditor.selectedRange,NSMakeRange(2,3))&&[sceneField.stringValue isEqual:@"kept editor value"]);
        assert(fabs(sceneHost.frame.origin.x-80)<1&&fabs(sceneField.frame.size.width-150)<1&&sceneHost.frame.size.width<=101);
        navigate(@"/scene-scroll");waitFor(^BOOL{return [window.title hasPrefix:@"Scene scrolling — Assembly"]&&[status.stringValue containsString:@"ready."];});
        NSRange scrollLink=[text.string rangeOfString:@"Scroll link"];NSRect scrollGlyph=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:scrollLink actualCharacterRange:NULL] inTextContainer:text.textContainer];
        assert(!mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)));
        assert(mac_scene_scroll_at_point(5,5,0,120));
        assert([mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)-120).path isEqual:@"/second"]);
        [window setContentSize:NSMakeSize(720,780)];mac_engine_resize(nil,NULL,nil);
        scrollLink=[text.string rangeOfString:@"Scroll link"];scrollGlyph=[text.layoutManager boundingRectForGlyphRange:[text.layoutManager glyphRangeForCharacterRange:scrollLink actualCharacterRange:NULL] inTextContainer:text.textContainer];
        assert([mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)-120).path isEqual:@"/second"]); // contained scroll survives reflow
        assert(mac_scene_scroll_at_point(5,5,0,-120));
        assert(!mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)-120));
        NSRange scrollTop=[text.string rangeOfString:@"Scroll top"];
        text.selectedRange=NSMakeRange(scrollTop.location,0);
        [text keyDown:sceneKey(text,125,0)];
        [text keyDown:sceneKey(text,125,0)];
        [text keyDown:sceneKey(text,125,0)];
        assert([mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)-120).path isEqual:@"/second"]);
        assert(text.selectedRange.location==scrollTop.location && !text.selectedRange.length);
        [text keyDown:sceneKey(text,115,0)]; // Home returns the focused scroll port to its start.
        assert(!mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)-120));
        [text keyDown:sceneKey(text,121,0)]; // Page movement uses the port height, not the window height.
        assert(mac_scene_scroll_at_point(5,5,0,100));
        assert([mac_scene_link_at_point(NSMidX(scrollGlyph),NSMidY(scrollGlyph)-120).path isEqual:@"/second"]);
        [text keyDown:sceneKey(text,115,0)];
        navigate(@"/webfont");waitFor(^BOOL{return [window.title hasPrefix:@"Web fonts — Assembly"]&&atomic_load(&fontStarted);});
        NSRange fontText=[text.string rangeOfString:@"WWWW"];NSFont *fallbackFont=[text.textStorage attribute:NSFontAttributeName atIndex:fontText.location effectiveRange:NULL];
        assert(![fallbackFont.fontName isEqual:@"OogaFixture-Regular"]);
        NSTextField *fontEditor=control(@"fontedit");assert(fontEditor);fontEditor.stringValue=@"kept during font load";
        waitFor(^BOOL{return [status.stringValue containsString:@"ready."];});
        fontText=[text.string rangeOfString:@"WWWW"];NSFont *loadedFont=[text.textStorage attribute:NSFontAttributeName atIndex:fontText.location effectiveRange:NULL];
        assert([loadedFont.fontName isEqual:@"OogaFixture-Regular"]&&loadedFont.pointSize==20&&atomic_load(&fontRequests)==2);
        assert(fabs([@"WWWW" sizeWithAttributes:@{NSFontAttributeName:loadedFont}].width-33.6)<1);
        assert(control(@"fontedit")==fontEditor&&[fontEditor.stringValue isEqual:@"kept during font load"]);
        [window setContentSize:NSMakeSize(700,780)];mac_engine_resize(nil,NULL,nil);
        fontText=[text.string rangeOfString:@"WWWW"];loadedFont=[text.textStorage attribute:NSFontAttributeName atIndex:fontText.location effectiveRange:NULL];assert([loadedFont.fontName isEqual:@"OogaFixture-Regular"]&&atomic_load(&fontRequests)==2);
        navigate(@"/mutation"); waitFor(^BOOL { return [window.title hasPrefix:@"Mutable tree — Assembly"] && [status.stringValue containsString:@"ready."]; });
        int mutationVisits=count(); unsigned cssRequests=atomic_load(&mutationCSSRequests),pictureRequests=atomic_load(&imageRequests);
        NSTextField *keptField=control(@"keep"),*removedField=control(@"remove"); NSButton *mutationSend=control(@"mutatesend");
        assert(keptField && removedField && mutationSend);
        keptField.stringValue=@"kept live value 🌐";
        uint64_t *oldFlow=engine_document; void *model=(void *)(uintptr_t)oldFlow[12]; assert(model);
        uint64_t containerNode=engine_dom_get_element_by_id(model,"container"),messageNode=engine_dom_get_element_by_id(model,"message"),removeNode=engine_dom_get_element_by_id(model,"remove");
        uint64_t inserted=engine_dom_create_element(model,"p",1),insertedText=engine_dom_create_text(model,"Inserted 🌐",strlen("Inserted 🌐"));
        assert(inserted && insertedText && !engine_dom_insert_before(model,inserted,insertedText,0) && !engine_dom_insert_before(model,containerNode,inserted,messageNode));
        assert(!engine_dom_set_text(model,engine_dom_node(model,messageNode)->first,"After mutation",14));
        assert(!engine_dom_set_attribute(model,messageNode,"class","hot",3) && !engine_dom_set_attribute(model,messageNode,"style","color:blue",10));
        assert(!engine_dom_remove(model,removeNode));
        mac_engine_refresh();
        waitFor(^BOOL { return [text.string containsString:@"After mutation"] && [status.stringValue containsString:@"ready."]; });
        assert(engine_document!=oldFlow && ((uint64_t *)engine_document)[12]==(uintptr_t)model && engine_dom_get_element_by_id(model,"message")==messageNode);
        assert([text.string containsString:@"Inserted 🌐"] && control(@"keep")==keptField && control(@"mutatesend")==mutationSend && [keptField.stringValue isEqual:@"kept live value 🌐"]);
        assert(removedField.hidden && !control(@"remove") && count()==mutationVisits);
        assert(atomic_load(&mutationCSSRequests)==cssRequests && atomic_load(&imageRequests)==pictureRequests);
        NSRange mutatedRange=[text.string rangeOfString:@"After mutation"],proofRange=[text.string rangeOfString:@"External CSS survives"];
        NSColor *mutatedColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:mutatedRange.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        NSColor *proofColor=[[text.textStorage attribute:NSForegroundColorAttributeName atIndex:proofRange.location effectiveRange:NULL] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        assert(mutatedColor.blueComponent>.99 && proofColor.greenComponent>.49 && proofColor.redComponent<.01);
        [mutationSend performClick:nil]; waitFor(^BOOL { return [window.title hasPrefix:@"Posted — Assembly"]; });
        assert([postedBody containsString:@"q=kept+live+value+%F0%9F%8C%90"] && ![postedBody containsString:@"removed="]);
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
        if(!(fabs(toggleLine.origin.x-40)<.01 && fabs(toggleLine.size.height-10)<.01 && fabs(footerLine.origin.y-335)<.01 && fabs(fg.origin.y-335)<3 && tg.size.width>0)) NSLog(@"Acid1 toggle %@ footer %@ glyph %@ text %@",NSStringFromRect(toggleLine),NSStringFromRect(footerLine),NSStringFromRect(fg),text.string);
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
