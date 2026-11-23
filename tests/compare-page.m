// Test-only live comparison. Production parsing/layout remain assembly.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <sqlite3.h>
extern Class mac_register_class(void);
extern void mac_engine_toggle(id,SEL,id),mac_js_reset(void);
extern int history_open(const char *,sqlite3 **);
extern id mac_app,mac_delegate;
extern NSWindow *mac_window;
extern WKWebView *mac_web;
extern NSTextField *mac_address,*mac_status;
extern NSButton *mac_back,*mac_forward;
extern sqlite3 *mac_db;
extern NSURLSessionTask *engine_task;
extern NSTextView *engine_text;
@interface ComparisonStub : NSView
- (void)stopLoading;
@end
@implementation ComparisonStub
- (void)stopLoading {}
@end
static void pump(void) {
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
}
int main(int argc,const char **argv) {@autoreleasepool {
    if(argc!=3) {fprintf(stderr,"Usage: compare-page URL OUTPUT_DIRECTORY\n");return 2;}
    NSString *directory=[NSString stringWithUTF8String:argv[2]];
    NSError *error=nil;
    if(![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {NSLog(@"%@",error);return 2;}
    mac_app=NSApplication.sharedApplication;
    mac_delegate=[[mac_register_class() alloc] init];
    mac_window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1160,780) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    mac_window.releasedWhenClosed=NO;
    mac_address=[NSTextField new];mac_status=[NSTextField new];
    mac_back=[NSButton new];mac_forward=[NSButton new];
    mac_web=(id)[[ComparisonStub alloc] initWithFrame:NSZeroRect];
    if(history_open(":memory:",&mac_db))return 2;
    mac_address.stringValue=[NSString stringWithUTF8String:argv[1]];
    mac_engine_toggle(nil,NULL,nil);
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:50];
    while(engine_task&&deadline.timeIntervalSinceNow>0)pump();
    if(engine_task||!engine_text.string.length){NSLog(@"Assembly load failed: %@",mac_status.stringValue);return 1;}
    NSRect rect=NSMakeRect(0,0,1160,700);
    NSBitmapImageRep *bitmap=[engine_text bitmapImageRepForCachingDisplayInRect:rect];
    [engine_text cacheDisplayInRect:rect toBitmapImageRep:bitmap];
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[directory stringByAppendingPathComponent:@"assembly.png"] atomically:YES];
    NSString *assemblyStatus=mac_status.stringValue;
    NSURL *url=[NSURL URLWithString:mac_address.stringValue];
    mac_js_reset();
    WKWebViewConfiguration *configuration=[WKWebViewConfiguration new];
    configuration.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;
    configuration.defaultWebpagePreferences.allowsContentJavaScript=NO;
    WKWebView *reference=[[WKWebView alloc] initWithFrame:rect configuration:configuration];
    [mac_window.contentView addSubview:reference];
    [reference loadRequest:[NSURLRequest requestWithURL:url]];
    deadline=[NSDate dateWithTimeIntervalSinceNow:45];
    while(reference.loading&&deadline.timeIntervalSinceNow>0)pump();
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    __block BOOL captured=NO,failed=NO;
    [reference takeSnapshotWithConfiguration:nil completionHandler:^(NSImage *image,NSError *failure) {
        if(failure||!image){NSLog(@"WebKit snapshot failed: %@",failure);failed=YES;}
        else {
            NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
            [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[directory stringByAppendingPathComponent:@"webkit.png"] atomically:YES];
        }
        captured=YES;
    }];
    while(!captured&&deadline.timeIntervalSinceNow>0)pump();
    NSDictionary *result=@{@"url":url.absoluteString,@"assembly_status":assemblyStatus,@"webkit_title":reference.title?:@"",@"reference_javascript":@NO,@"width":@1160,@"height":@700};
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:[directory stringByAppendingPathComponent:@"comparison.json"] atomically:YES];
    sqlite3_close(mac_db);
    return (!captured||failed)?1:0;
}}
