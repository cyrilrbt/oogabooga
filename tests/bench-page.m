// Offline harness: application and engine code remain assembly. No network IO.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <assert.h>
#include <sqlite3.h>
#include <time.h>
extern Class mac_register_class(void);
extern void *engine_parse(const char *,size_t);
extern void engine_document_free(void *);
extern int mac_engine_display(void *,NSURL *);
extern NSLayoutManager *mac_display_manager_create(void) __attribute__((ns_returns_retained));
extern void mac_resources_reset(void);
extern uint64_t engine_profile_enabled,engine_profile_totals[8],engine_profile_counts[8];
extern void engine_profile_reset(void);
extern int history_open(const char *,sqlite3 **);
extern __unsafe_unretained id mac_delegate;
extern __unsafe_unretained NSTextView *engine_text;
extern __unsafe_unretained NSScrollView *engine_scroll;
extern __unsafe_unretained NSMutableDictionary *engine_images;
extern sqlite3 *mac_db;
extern NSImage *mac_svg_image(const char *,size_t,void *) __attribute__((ns_returns_retained));
static double now(void) { struct timespec t;clock_gettime(CLOCK_MONOTONIC_RAW,&t);return t.tv_sec+t.tv_nsec/1e9; }
static NSBitmapImageRep *capture(NSRect rect) {
    NSBitmapImageRep *r=[engine_text bitmapImageRepForCachingDisplayInRect:rect];assert(r);
    [engine_text cacheDisplayInRect:rect toBitmapImageRep:r];return r;
}
static int palette(NSColor *color) {
    NSColor *c=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    const double p[][3]={{0,0,1},{1,1,1},{0,0,0},{.8,0,0},{1,.8,0}};
    double best=100;int result=0;
    for(int i=0;i<5;i++){double d=pow(c.redComponent-p[i][0],2)+pow(c.greenComponent-p[i][1],2)+pow(c.blueComponent-p[i][2],2);if(d<best){best=d;result=i;}}
    return result;
}
static int pixel(NSBitmapImageRep *r,int x,int y,int w,int h) {return palette([r colorAtX:x*r.pixelsWide/w y:y*r.pixelsHigh/h]);}
static void referenceCheck(NSBitmapImageRep *actual) {
    NSBitmapImageRep *reference=[[NSBitmapImageRep alloc] initWithData:[NSData dataWithContentsOfFile:@"tests/fixtures/acid1-reference.png"]];assert(reference);
    // Original reference includes obsolete browser chrome; body border starts
    // at (21,87), corresponding to CSS (15,15), so viewport origin is (6,72).
    const NSRect masks[]={{{37,35},{57,25}},{{147,55},{57,30}},{{232,50},{146,88}},{{407,55},{57,50}},{{142,180},{106,25}},{{277,190},{56,43}},{{362,180},{106,47}}};
    size_t checked=0,mismatch=0;
    for(int y=0;y<335;y++)for(int x=0;x<505;x++) {
        BOOL masked=NO;for(size_t k=0;k<sizeof(masks)/sizeof(*masks);k++)if(NSPointInRect(NSMakePoint(x,y),masks[k])){masked=YES;break;}if(masked)continue;
        int a=pixel(actual,x,y,600,500),b=pixel(reference,x+6,y+72,(int)reference.pixelsWide,(int)reference.pixelsHigh);checked++;
        if(a!=b){BOOL edge=NO;for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++)if(x+6+dx>=0&&y+72+dy>=0&&pixel(reference,x+6+dx,y+72+dy,(int)reference.pixelsWide,(int)reference.pixelsHigh)==a)edge=YES;if(!edge)mismatch++;}
    }
    printf("Acid1 full-canvas geometry: %zu / %zu mismatched pixels (%.4f%%); glyph/widget regions excluded, 1px edge tolerance\n",mismatch,checked,100.0*mismatch/checked);
    NSData *png=[actual representationUsingType:NSBitmapImageFileTypePNG properties:@{}];[png writeToFile:@"build/acid1-assembly.png" atomically:YES];
    assert(mismatch<checked/500); // <0.2% outside allowed font/control regions
}
static void bench(NSString *name,NSString *html,int rounds,BOOL reference) {
    NSData *source=[html dataUsingEncoding:NSUTF8StringEncoding];NSURL *base=[NSURL URLWithString:@"https://benchmark.test/"];
    NSData *svg=[NSData dataWithContentsOfFile:@"tests/fixtures/engine-vector.svg"];
    NSImage *vector=mac_svg_image(svg.bytes,svg.length,NULL);
    int warmups=reference?0:3; double start=0;
    for(int i=-warmups;i<rounds;i++){@autoreleasepool{
        if(i==0){engine_profile_reset();engine_profile_enabled=1;start=now();}
        void *d=engine_parse(source.bytes,source.length);assert(d);mac_resources_reset();
        // Prefetched local SVG: its XML parser is still the assembly implementation.
        uint64_t *doc=d;uint64_t *nodes=(void *)(uintptr_t)doc[2];for(uint64_t n=0;n<doc[3];n++)if(nodes[n*5]==32)engine_images[@(n)]=vector;
        assert(mac_engine_display(d,base));NSBitmapImageRep *image=capture(NSMakeRect(0,0,600,500));
        if(reference){double beforeCheck=now();referenceCheck(image);start+=now()-beforeCheck;}
        engine_document_free(d);
    }}
    double wall=(now()-start)*1000/rounds;engine_profile_enabled=0;
    const char *stages[]={"HTML parse (excludes CSS)","CSS matching/cascade","box/flex/table/float geometry","intrinsic glyph measurement","native attributes/text layout","display-list compilation","paint callbacks","display total (inclusive)"};
    printf("\n%s: %.3f ms/page (%d offline iterations; 600x500 painted viewport)\n",name.UTF8String,wall,rounds);
    for(int i=0;i<8;i++)printf("  %-32s %8.3f ms/page  [%llu calls]\n",stages[i],engine_profile_totals[i]/1e6/rounds,engine_profile_counts[i]);
}
int main(int argc,const char **argv) {@autoreleasepool{
    [NSApplication sharedApplication];id delegate=[[mac_register_class() alloc]init];mac_delegate=delegate;
    NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,0,1000,700)];
    NSTextView *text=[[NSTextView alloc]initWithFrame:NSMakeRect(0,0,1000,700)];text.editable=NO;text.richText=YES;text.verticallyResizable=YES;text.horizontallyResizable=YES;scroll.documentView=text;
    [text.textContainer replaceLayoutManager:mac_display_manager_create()];
    engine_text=text;engine_scroll=scroll;assert(history_open(":memory:",&mac_db)==SQLITE_OK);
    NSString *acid=[NSString stringWithContentsOfFile:@"tests/fixtures/acid1.html" encoding:NSUTF8StringEncoding error:NULL];assert(acid);
    if(argc>1&&!strcmp(argv[1],"--reference")){bench(@"Acid1",acid,1,YES);return 0;}
    bench(@"Acid1",acid,30,NO);
    NSString *lab=[NSString stringWithContentsOfFile:@"tests/fixtures/engine-layout.html" encoding:NSUTF8StringEncoding error:NULL];NSString *css=[NSString stringWithContentsOfFile:@"tests/fixtures/engine-layout.css" encoding:NSUTF8StringEncoding error:NULL];lab=[lab stringByReplacingOccurrencesOfString:@"</head>" withString:[NSString stringWithFormat:@"<style>%@</style></head>",css]];
    bench(@"Flex/table/SVG lab (prefetched CSS/images)",lab,30,NO);
    sqlite3_close(mac_db);mac_db=NULL;
    return 0;
}}
