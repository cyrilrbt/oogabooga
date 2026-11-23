// Offline harness: application and engine code remain assembly. No network IO.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <assert.h>
#include <sqlite3.h>
#include <time.h>
extern Class mac_register_class(void);
extern void *engine_parse(const char *,size_t);
extern void engine_document_free(void *);
extern NSRect mac_atomic_text_rect(NSUInteger,NSUInteger);
extern double mac_atomic_text_baseline(NSUInteger);
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
    // Explicit sRGB avoids display-profile-dependent color values in snapshots.
    NSBitmapImageRep *r=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)rect.size.width pixelsHigh:(NSInteger)rect.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    r=[r bitmapImageRepByRetaggingWithColorSpace:NSColorSpace.sRGBColorSpace];assert(r);
    NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:r];assert(context);
    [engine_text displayRectIgnoringOpacity:rect inContext:context];return r;
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
static int report(NSString *directory,NSString *manifest) {
    NSError *error=nil;
    NSArray *cases=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:manifest] options:0 error:&error];
    if(![cases isKindOfClass:NSArray.class]) { NSLog(@"Invalid compatibility manifest: %@",error); return 1; }
    if(![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) return 1;
    NSMutableArray *results=[NSMutableArray new];
    BOOL failed=NO;
    for(NSDictionary *test in cases) { @autoreleasepool {
        NSString *name=test[@"name"],*file=test[@"file"];
        NSString *html=[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:&error];
        if(!html || !name.length || [name rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"] invertedSet]].location!=NSNotFound) { NSLog(@"Invalid fixture %@",test); return 1; }
        NSInteger width=[test[@"width"] integerValue],height=[test[@"height"] integerValue];
        if(width<100 || width>2000 || height<100 || height>2000) return 1;
        [engine_scroll setFrameSize:NSMakeSize(width,height)];
        engine_scroll.scrollerStyle=NSScrollerStyleOverlay;
        NSData *source=[html dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableArray *times=[NSMutableArray new],*checks=[NSMutableArray new];
        NSBitmapImageRep *image=nil;
        engine_profile_reset();
        for(int round=-2;round<5;round++) {
            engine_profile_enabled=round>=0;
            double start=now();
            void *document=engine_parse(source.bytes,source.length);
            if(!document) return 1;
            mac_resources_reset();
            if(!mac_engine_display(document,[NSURL URLWithString:@"https://fixture.invalid/"])) { engine_document_free(document); return 1; }
            image=capture(NSMakeRect(0,0,width,height));
            if(round>=0) [times addObject:@((now()-start)*1000)];
            engine_document_free(document);
        }
        engine_profile_enabled=0;
        NSArray *sorted=[times sortedArrayUsingSelector:@selector(compare:)];
        double median=[sorted[sorted.count/2] doubleValue],budget=[test[@"budget_ms"] doubleValue];
        BOOL passed=budget<=0 || median<=budget;
        for(NSDictionary *sample in test[@"pixels"]) {
            NSInteger x=[sample[@"x"] integerValue],y=[sample[@"y"] integerValue];
            if(x<0 || y<0 || x>=width || y>=height) return 1;
            NSUInteger pixel[4]={0}; [image getPixel:pixel atX:x*image.pixelsWide/width y:y*image.pixelsHigh/height];
            NSArray *rgb=sample[@"rgb"];
            BOOL match=rgb.count==3 && fabs((double)pixel[0]-[rgb[0] doubleValue])<6 && fabs((double)pixel[1]-[rgb[1] doubleValue])<6 && fabs((double)pixel[2]-[rgb[2] doubleValue])<6;
            [checks addObject:@{@"name":sample[@"name"]?:@"pixel",@"pass":@(match),@"x":@(x),@"y":@(y),@"actual":@[@(pixel[0]),@(pixel[1]),@(pixel[2])]}];
            passed &= match;
        }
        for(NSString *expected in test[@"text"]) {
            BOOL match=[engine_text.string containsString:expected];
            [checks addObject:@{@"name":[@"visible text: " stringByAppendingString:expected],@"pass":@(match)}];
            passed &= match;
        }
        for(NSArray *forbidden in test[@"forbidden_colors"]) {
            if(forbidden.count!=3) return 1;
            NSUInteger found=0;
            for(NSInteger y=0;y<height;y++)for(NSInteger x=0;x<width;x++) {
                NSUInteger pixel[4]={0};[image getPixel:pixel atX:x*image.pixelsWide/width y:y*image.pixelsHigh/height];
                found += labs((long)pixel[0]-[forbidden[0] integerValue])<6 && labs((long)pixel[1]-[forbidden[1] integerValue])<6 && labs((long)pixel[2]-[forbidden[2] integerValue])<6;
            }
            BOOL match=found==0;
            [checks addObject:@{@"name":[NSString stringWithFormat:@"forbidden color %@ absent",forbidden],@"pass":@(match),@"matching_pixels":@(found)}];
            passed &= match;
        }
        for(NSDictionary *geometry in test[@"text_geometry"]) {
            NSRange range=[engine_text.string rangeOfString:geometry[@"text"]];
            NSRect actual=NSZeroRect;BOOL match=range.location!=NSNotFound;
            if(match) actual=mac_atomic_text_rect(range.location,range.length);
            double tolerance=geometry[@"tolerance"]?[geometry[@"tolerance"] doubleValue]:2;
            if(geometry[@"x"]) match &= fabs(actual.origin.x-[geometry[@"x"] doubleValue])<=tolerance;
            if(geometry[@"right_max"]) match &= NSMaxX(actual)<=[geometry[@"right_max"] doubleValue]+tolerance;
            if(geometry[@"center_x"]) match &= fabs(NSMidX(actual)-[geometry[@"center_x"] doubleValue])<=tolerance;
            if(geometry[@"same_y_as"]) {
                NSRange other=[engine_text.string rangeOfString:geometry[@"same_y_as"]];
                if(other.location==NSNotFound) match=NO;
                else {NSRect otherRect=[engine_text.layoutManager boundingRectForGlyphRange:[engine_text.layoutManager glyphRangeForCharacterRange:other actualCharacterRange:NULL] inTextContainer:engine_text.textContainer];match &= fabs(otherRect.origin.y-actual.origin.y)<=tolerance;}
            }
            if(geometry[@"same_baseline_as"]) {
                NSRange other=[engine_text.string rangeOfString:geometry[@"same_baseline_as"]];
                if(other.location==NSNotFound) match=NO;
                else match &= fabs(mac_atomic_text_baseline(other.location)-mac_atomic_text_baseline(range.location))<=tolerance;
            }
            [checks addObject:@{@"name":[@"text geometry: " stringByAppendingString:geometry[@"text"]],@"pass":@(match),@"actual_rect":NSStringFromRect(actual)}];
            passed &= match;
        }
        NSString *referencePNG=@"";
        if(test[@"reference"]) {
            NSBitmapImageRep *expected=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*4 bitsPerPixel:32];
            expected=[expected bitmapImageRepByRetaggingWithColorSpace:NSColorSpace.sRGBColorSpace];
            memset(expected.bitmapData,255,expected.bytesPerRow*height);
            for(NSDictionary *rectangle in test[@"reference"]) {
                NSArray *rect=rectangle[@"rect"],*rgb=rectangle[@"rgb"];
                if(rect.count!=4 || rgb.count!=3) return 1;
                NSInteger left=[rect[0] integerValue],top=[rect[1] integerValue],right=left+[rect[2] integerValue],bottom=top+[rect[3] integerValue];
                if(left<0 || top<0 || right>width || bottom>height || right<left || bottom<top) return 1;
                for(NSInteger y=top;y<bottom;y++) for(NSInteger x=left;x<right;x++) {
                    unsigned char *p=expected.bitmapData+y*expected.bytesPerRow+x*4;
                    for(int c=0;c<3;c++) p[c]=[rgb[c] unsignedCharValue];
                }
            }
            NSUInteger mismatch=0;
            for(NSInteger y=0;y<height;y++) for(NSInteger x=0;x<width;x++) {
                NSUInteger pixel[4]={0}; [image getPixel:pixel atX:x*image.pixelsWide/width y:y*image.pixelsHigh/height];
                BOOL match=NO;
                for(NSInteger dy=-1;dy<=1 && !match;dy++) for(NSInteger dx=-1;dx<=1;dx++) {
                    NSInteger xx=x+dx,yy=y+dy;
                    if(xx<0 || yy<0 || xx>=width || yy>=height) continue;
                    const unsigned char *p=expected.bitmapData+yy*expected.bytesPerRow+xx*4;
                    if(labs((long)pixel[0]-p[0])<6 && labs((long)pixel[1]-p[1])<6 && labs((long)pixel[2]-p[2])<6) { match=YES; break; }
                }
                mismatch+=!match;
            }
            referencePNG=[name stringByAppendingString:@"-reference.png"];
            if(![[expected representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[directory stringByAppendingPathComponent:referencePNG] atomically:YES]) return 1;
            [checks addObject:@{@"name":@"reference geometry (1px edge tolerance)",@"pass":@(mismatch==0),@"mismatched_pixels":@(mismatch),@"compared_pixels":@(width*height)}];
            passed &= mismatch==0;
        }
        NSString *png=[name stringByAppendingPathExtension:@"png"];
        if(![[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[directory stringByAppendingPathComponent:png] atomically:YES]) return 1;
        NSMutableArray *stages=[NSMutableArray new];
        for(int stage=0;stage<8;stage++) [stages addObject:@(engine_profile_totals[stage]/1e6/5)];
        [results addObject:@{@"name":name,@"file":file,@"screenshot":png,@"reference":referencePNG,@"pass":@(passed),@"median_ms":@(median),@"budget_ms":@(budget),@"stage_ms":stages,@"checks":checks,@"width":@(width),@"height":@(height),@"viewport_width":@(engine_text.textContainer.size.width)}];
        printf("%s: %s (median %.2f ms, budget %.2f ms)\n",passed?"PASS":"FAIL",name.UTF8String,median,budget);
        failed |= !passed;
    }}
    NSString *version=[[NSString stringWithContentsOfFile:@"VERSION" encoding:NSUTF8StringEncoding error:NULL] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSDictionary *result=@{@"version":version?:@"unknown",@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"results":results,@"pass":@(!failed)};
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&error];
    if(![json writeToFile:[directory stringByAppendingPathComponent:@"results.json"] atomically:YES]) return 1;
    return failed?1:0;
}
int main(int argc,const char **argv) {@autoreleasepool{
    [NSApplication sharedApplication];id delegate=[[mac_register_class() alloc]init];mac_delegate=delegate;
    NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,0,1000,700)];
    NSTextView *text=[[NSTextView alloc]initWithFrame:NSMakeRect(0,0,1000,700)];text.editable=NO;text.richText=YES;text.verticallyResizable=YES;text.horizontallyResizable=YES;scroll.documentView=text;
    [text.textContainer replaceLayoutManager:mac_display_manager_create()];
    text.linkTextAttributes=@{};
    engine_text=text;engine_scroll=scroll;assert(history_open(":memory:",&mac_db)==SQLITE_OK);
    if(argc>3&&!strcmp(argv[1],"--report")) return report([NSString stringWithUTF8String:argv[2]],[NSString stringWithUTF8String:argv[3]]);
    NSString *acid=[NSString stringWithContentsOfFile:@"tests/fixtures/acid1.html" encoding:NSUTF8StringEncoding error:NULL];assert(acid);
    if(argc>1&&!strcmp(argv[1],"--reference")){bench(@"Acid1",acid,1,YES);return 0;}
    bench(@"Acid1",acid,30,NO);
    NSString *lab=[NSString stringWithContentsOfFile:@"tests/fixtures/engine-layout.html" encoding:NSUTF8StringEncoding error:NULL];NSString *css=[NSString stringWithContentsOfFile:@"tests/fixtures/engine-layout.css" encoding:NSUTF8StringEncoding error:NULL];lab=[lab stringByReplacingOccurrencesOfString:@"</head>" withString:[NSString stringWithFormat:@"<style>%@</style></head>",css]];
    bench(@"Flex/table/SVG lab (prefetched CSS/images)",lab,30,NO);
    sqlite3_close(mac_db);mac_db=NULL;
    return 0;
}}
