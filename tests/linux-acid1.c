// The same historical reference crop, palette and glyph/widget exclusions as macOS.
#include <gtk/gtk.h>
#include <stdint.h>
#include <assert.h>
#include <stdio.h>
extern void *engine_parse(const char *,size_t);
extern int gtk_engine_prepare(void *,uint64_t);
extern void gtk_engine_paint(cairo_t *);
extern int64_t gtk_viewport_height;
static int palette(unsigned char *p,int bgr) {
    const int colors[5][3]={{0,0,255},{255,255,255},{0,0,0},{204,0,0},{255,204,0}};
    int best=0,distance=999999;
    for(int i=0;i<5;i++){int r=p[bgr?2:0]-colors[i][0],g=p[1]-colors[i][1],b=p[bgr?0:2]-colors[i][2],d=r*r+g*g+b*b;if(d<distance){distance=d;best=i;}}
    return best;
}
int main(int argc,char **argv) {
    gtk_init(&argc,&argv);char *html;gsize length;assert(g_file_get_contents("tests/fixtures/acid1.html",&html,&length,NULL));
    void *doc=engine_parse(html,length);assert(doc);g_free(html);gtk_viewport_height=500;assert(gtk_engine_prepare(doc,600));
    cairo_surface_t *surface=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,600,500);cairo_t *cr=cairo_create(surface);gtk_engine_paint(cr);cairo_destroy(cr);cairo_surface_flush(surface);
    GdkPixbuf *ref=gdk_pixbuf_new_from_file("tests/fixtures/acid1-reference.png",NULL);assert(ref);
    unsigned char *actual=cairo_image_surface_get_data(surface),*expected=gdk_pixbuf_get_pixels(ref);int stride=cairo_image_surface_get_stride(surface),rs=gdk_pixbuf_get_rowstride(ref),channels=gdk_pixbuf_get_n_channels(ref);
    const int masks[][4]={{37,35,57,25},{147,55,57,30},{232,50,146,88},{407,55,57,50},{142,180,106,25},{277,190,56,43},{362,180,106,47}};
    int bad=0,total=0;for(int y=0;y<335;y++)for(int x=0;x<505;x++) {
        int skip=0;for(size_t k=0;k<sizeof(masks)/sizeof(*masks);k++)if(x>=masks[k][0]&&x<masks[k][0]+masks[k][2]&&y>=masks[k][1]&&y<masks[k][1]+masks[k][3])skip=1;if(skip)continue;
        int a=palette(actual+y*stride+x*4,1),b=palette(expected+(y+72)*rs+(x+6)*channels,0);total++;
        if(a!=b){int edge=0;for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++)if(palette(expected+(y+72+dy)*rs+(x+6+dx)*channels,0)==a)edge=1;if(!edge)bad++;}
    }
    printf("Linux Acid1: %d/%d geometry mismatches; glyph/widget regions excluded, 1px edge tolerance\n",bad,total);
    cairo_surface_write_to_png(surface,"build/linux/engine/acid1.png");return bad>=total/500;
}
