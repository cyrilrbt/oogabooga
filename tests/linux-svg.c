// Cross-platform SVG drawing checks. Scanner and geometry share macOS assembly.
#include <gtk/gtk.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
extern GdkPixbuf *mac_svg_image(const char *,size_t,void *);
static GdkPixbuf *render(const char *s) {GdkPixbuf *p=mac_svg_image(s,strlen(s),NULL);assert(p);return p;}
static unsigned char *pixel(GdkPixbuf *p,int x,int y) {return gdk_pixbuf_get_pixels(p)+y*gdk_pixbuf_get_rowstride(p)+x*gdk_pixbuf_get_n_channels(p);}
int main(int argc,char **argv) {
    gtk_init(&argc,&argv);
    GdkPixbuf *p=render("<svg width='64' height='64' viewBox='0 0 32 32'><rect width='32' height='32' fill='white'/><g transform='translate(4 4)' fill='rgb(11 87 208)'><rect width='24' height='24' rx='3'/><circle cx='12' cy='12' r='5' fill='red'/></g></svg>");
    assert(gdk_pixbuf_get_width(p)==64 && gdk_pixbuf_get_height(p)==64);
    unsigned char *c=pixel(p,32,32);assert(c[0]>240 && c[2]<15);
    c=pixel(p,12,12);assert(c[2]>190 && c[0]<30);
    c=pixel(p,1,1);assert(c[0]>240 && c[1]>240);g_object_unref(p);
    p=render("<svg width='32' height='32'><rect width='32' height='32' fill='white'/><path d='M8 16a8 8 0 1 0 16 0a8 8 0 1 0-16 0Z' fill='green'/></svg>");
    c=pixel(p,16,16);assert(c[1]>100 && c[0]<30);g_object_unref(p);
    p=render("<svg width='32' height='32'><rect width='32' height='32' fill='white'/><path fill='blue' fill-rule='evenodd' d='M2 2H30V30H2Z M10 10h12v12h-12z'/></svg>");
    c=pixel(p,5,5);assert(c[2]>240 && c[0]<15);c=pixel(p,16,16);assert(c[0]>240 && c[1]>240);g_object_unref(p);
    p=render("<svg width='32' height='32'><rect width='32' height='32' fill='white'/><g transform='matrix(1 0 0 1 10 0)'><rect width='5' height='5' fill='blue'/></g></svg>");
    c=pixel(p,12,2);assert(c[2]>240 && c[0]<15);c=pixel(p,2,2);assert(c[0]>240);g_object_unref(p);
    p=render("<svg width='32' height='32'><rect width='32' height='32' fill='blue' fill-opacity='.5'/></svg>");
    c=pixel(p,16,16);assert(c[3]>120 && c[3]<135);g_object_unref(p);
    p=render("<svg width='32' height='32'><path d='M2 16 C2 2 8 2 10 16 S18 30 20 16 Q24 4 28 16 T30 16' fill='none' stroke='red' stroke-width='2'/><ellipse cx='16' cy='16' rx='3' ry='5'/><polyline points='1,1 3,1 3,3' stroke='blue' fill='none'/><polygon points='20,20 25,20 25,25' fill='green'/></svg>");g_object_unref(p);
    p=render("<svg width='24' height='24'><g display='none'><rect width='24' height='24' fill='red'/></g><g style='display:none'><circle cx='12' cy='12' r='10'/></g></svg>");c=pixel(p,12,12);assert(c[3]==0);g_object_unref(p);
    assert(!mac_svg_image("not SVG",7,NULL));
    const char *bad="<svg width='9000' height='1'/>";assert(!mac_svg_image(bad,strlen(bad),NULL));
    size_t page=(size_t)sysconf(_SC_PAGESIZE);char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);assert(guard!=MAP_FAILED);assert(!mprotect(guard+page,page,PROT_NONE));
    const char *xml="<svg width='24' height='24'><g transform='translate(1 2)'><path d='M1 1L8 8Z'/></g></svg>";
    for(size_t n=0;n<=strlen(xml);n++){memcpy(guard+page-n,xml,n);p=mac_svg_image(guard+page-n,n,NULL);if(p)g_object_unref(p);}munmap(guard,page*2);
    puts("PASS: shared assembly SVG shapes, paths, curves, arcs, transforms, opacity, fill rules and guarded truncation on Cairo");
}
