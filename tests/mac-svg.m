// Native drawing harness only. XML, geometry and path interpretation are assembly.
#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <sys/mman.h>
#include <unistd.h>
extern Class mac_register_class(void);
extern NSImage *mac_svg_image(const char *,size_t,void *) __attribute__((ns_returns_retained));
static NSImage *render(const char *s) { NSImage *i=mac_svg_image(s,strlen(s),NULL); assert(i); return i; }
static NSColor *pixel(NSImage *i,NSInteger x,NSInteger y) {
    NSBitmapImageRep *r=[[NSBitmapImageRep alloc] initWithData:i.TIFFRepresentation]; assert(r);
    return [[r colorAtX:x*r.pixelsWide/(NSInteger)i.size.width y:y*r.pixelsHigh/(NSInteger)i.size.height] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication]; mac_register_class();
        NSImage *shapes=render("<svg width='64' height='64' viewBox='0 0 32 32'><rect width='32' height='32' fill='white'/><g transform='translate(4 4)' fill='rgb(11 87 208)'><rect width='24' height='24' rx='3'/><circle cx='12' cy='12' r='5' fill='red'/></g></svg>");
        assert(NSEqualSizes(shapes.size,NSMakeSize(64,64)));
        NSColor *c=pixel(shapes,32,32); assert(c.redComponent>.95 && c.blueComponent<.05);
        c=pixel(shapes,12,12); assert(c.blueComponent>.75 && c.redComponent<.1);
        c=pixel(shapes,1,1); assert(c.redComponent>.95 && c.greenComponent>.95);
        NSImage *arcs=render("<svg width='32' height='32'><rect width='32' height='32' fill='white'/><path d='M8 16a8 8 0 1 0 16 0a8 8 0 1 0-16 0Z' fill='green'/></svg>");
        c=pixel(arcs,16,16); assert(c.greenComponent>.4 && c.redComponent<.1);
        NSImage *hole=render("<svg width='32' height='32'><rect width='32' height='32' fill='white'/><path fill='blue' fill-rule='evenodd' d='M2 2H30V30H2Z M10 10h12v12h-12z'/></svg>");
        c=pixel(hole,5,5); assert(c.blueComponent>.95 && c.redComponent<.05);
        c=pixel(hole,16,16); assert(c.redComponent>.95 && c.greenComponent>.95);
        NSImage *matrix=render("<svg width='32' height='32'><rect width='32' height='32' fill='white'/><g transform='matrix(1 0 0 1 10 0)'><rect width='5' height='5' fill='blue'/></g></svg>");
        c=pixel(matrix,12,2); assert(c.blueComponent>.95 && c.redComponent<.05);
        c=pixel(matrix,2,2); assert(c.redComponent>.95);
        NSImage *alpha=render("<svg width='32' height='32'><rect width='32' height='32' fill='blue' fill-opacity='.5'/></svg>");
        c=pixel(alpha,16,16); assert(fabs(c.alphaComponent-.5)<.02);
        (void)render("<svg width='32' height='32'><path d='M2 16 C2 2 8 2 10 16 S18 30 20 16 Q24 4 28 16 T30 16' fill='none' stroke='red' stroke-width='2'/><ellipse cx='16' cy='16' rx='3' ry='5'/><polyline points='1,1 3,1 3,3' stroke='blue' fill='none'/><polygon points='20,20 25,20 25,25' fill='green'/></svg>");
        NSImage *hidden=render("<svg width='24' height='24'><g display='none'><rect width='24' height='24' fill='red'/></g><g style='display:none'><circle cx='12' cy='12' r='10'/></g></svg>");
        c=pixel(hidden,12,12); assert(c.alphaComponent<.01);
        (void)render("<svg width='24' height='24'><path d='M1 1A1e-200 1e-200 0 0 1 20 20' stroke='blue' fill='none'/></svg>");
        assert(!mac_svg_image("not SVG",7,NULL));
        assert(!mac_svg_image("<svg width='9000' height='1'/>",29,NULL));
        // Every prefix abuts an inaccessible page, exercising bounded XML scans.
        size_t page=(size_t)sysconf(_SC_PAGESIZE);
        char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(guard!=MAP_FAILED);
        assert(!mprotect(guard+page,page,PROT_NONE));
        const char *sample="<svg viewBox='0 0 24 24'><!--<rect/>--><g transform='scale(1)'><path d='M1 1L20 1L1 20z'/></g></svg>";
        for(size_t n=0;n<=strlen(sample);n++) { @autoreleasepool { char *s=guard+page-n;memcpy(s,sample,n);(void)mac_svg_image(s,n,NULL); } }
        munmap(guard,page*2);
        puts("PASS: assembly SVG shapes, paths/arcs, inherited paint, viewBox, transforms, alpha, and guarded XML truncation");
    }
    return 0;
}
