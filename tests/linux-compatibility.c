// Independent saved-page geometry references shared with the macOS suite.
#include <gtk/gtk.h>
#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
extern void *engine_parse(const char *,size_t);
extern void engine_document_free(void *);
extern int gtk_engine_prepare(void *,uint64_t);
extern void gtk_engine_paint(cairo_t *);
extern void gtk_engine_clear_layout(void);
extern int64_t gtk_viewport_height;
extern unsigned char *gtk_groups;
extern GHashTable *gtk_controls,*gtk_images;
typedef struct {size_t index;const char *text,*other;double x,center,right;int baseline;} Check;
typedef struct {size_t index;const char *text;} Text;
static int geometry(const char *text,double *box) {
    for(unsigned char *g=gtk_groups;g;g=*(unsigned char **)g) {
        PangoLayout *layout=*(PangoLayout **)(g+16);const char *s=pango_layout_get_text(layout),*p=strstr(s,text);if(!p)continue;
        int index=(int)(p-s);PangoRectangle a,b;pango_layout_index_to_pos(layout,index,&a);pango_layout_index_to_pos(layout,index+(int)strlen(text)-1,&b);
        box[0]=*(int64_t *)(g+40)+(double)a.x/PANGO_SCALE;box[1]=*(int64_t *)(g+48)+(double)a.y/PANGO_SCALE;
        box[2]=*(int64_t *)(g+40)+(double)(b.x+b.width)/PANGO_SCALE;
        PangoLayoutIter *iter=pango_layout_get_iter(layout);
        do {PangoLayoutLine *line=pango_layout_iter_get_line_readonly(iter);if(index>=line->start_index && index<=line->start_index+line->length){box[3]=*(int64_t *)(g+48)+(double)pango_layout_iter_get_baseline(iter)/PANGO_SCALE;break;}} while(pango_layout_iter_next_line(iter));
        pango_layout_iter_free(iter);return 1;
    } return 0;
}
typedef struct {int x,y,w,h,r,g,b;} Rect;
typedef struct {const char *name,*file;int w,h,count;Rect rect[12];int forbidden_count;int forbidden[8][3];} Case;
#include "compat-cases.inc"
int main(int argc,char **argv) {
    gtk_init(&argc,&argv);int failures=0;
    for(size_t i=0;i<sizeof(cases)/sizeof(*cases);i++) {
        Case *c=&cases[i];char *html=NULL;gsize length=0;assert(g_file_get_contents(c->file,&html,&length,NULL));
        void *doc=engine_parse(html,length);g_free(html);assert(doc);gtk_viewport_height=c->h;
        assert(gtk_engine_prepare(doc,c->w));
        cairo_surface_t *s=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,c->w,c->h);cairo_t *cr=cairo_create(s);gtk_engine_paint(cr);cairo_destroy(cr);cairo_surface_flush(s);
        unsigned char *data=cairo_image_surface_get_data(s);int stride=cairo_image_surface_get_stride(s),bad=0,total=0;
        for(int y=0;y<c->h && (c->count>=0 || c->forbidden_count);y++)for(int x=0;x<c->w;x++) {
            int r=255,g=255,b=255,edge=0;
            for(int j=0;j<c->count;j++) {Rect *a=&c->rect[j];if(x>=a->x&&x<a->x+a->w&&y>=a->y&&y<a->y+a->h){r=a->r;g=a->g;b=a->b;}
                if((abs(x-a->x)<=1||abs(x-(a->x+a->w))<=1)&&y>=a->y-1&&y<=a->y+a->h+1)edge=1;
                if((abs(y-a->y)<=1||abs(y-(a->y+a->h))<=1)&&x>=a->x-1&&x<=a->x+a->w+1)edge=1;
            }
            if(edge)continue;unsigned char *p=data+y*stride+x*4;total++;
            if(c->count>=0 && (abs(p[2]-r)>2||abs(p[1]-g)>2||abs(p[0]-b)>2))bad++;
            for(int j=0;j<c->forbidden_count;j++)if(abs(p[2]-c->forbidden[j][0])<=2&&abs(p[1]-c->forbidden[j][1])<=2&&abs(p[0]-c->forbidden[j][2])<=2)bad++;
        }
        for(size_t j=0;j<sizeof(texts)/sizeof(*texts);j++)if(texts[j].index==i){double a[4];if(!geometry(texts[j].text,a)){fprintf(stderr,"Missing %s text: %s\n",c->name,texts[j].text);bad++;}}
        for(size_t j=0;j<sizeof(checks)/sizeof(*checks);j++)if(checks[j].index==i){Check *q=&checks[j];double a[4],b[4];int ok=geometry(q->text,a);
            if(ok && q->x!=-99999)ok=fabs(a[0]-q->x)<=2;
            if(ok && q->center!=-99999)ok=fabs((a[0]+a[2])/2-q->center)<=2;
            if(ok && q->right!=-99999)ok=a[2]<=q->right+2;
            if(ok && *q->other)ok=geometry(q->other,b)&&fabs(a[q->baseline?3:1]-b[q->baseline?3:1])<=2;
            if(!ok){fprintf(stderr,"Text geometry %s: %s at %.2f %.2f right %.2f baseline %.2f\n",c->name,q->text,a[0],a[1],a[2],a[3]);bad++;}}
        if(c->count>=0)printf("%s: Linux %s geometry %d/%d mismatches\n",bad?"FAIL":"PASS",c->name,bad,total);
        else printf("%s: Linux %s text/geometry/color assertions\n",bad?"FAIL":"PASS",c->name);
        if(bad){char path[256];snprintf(path,sizeof(path),"build/linux/engine/compat-%s.png",c->name);cairo_surface_write_to_png(s,path);failures++;}
        cairo_surface_destroy(s);gtk_engine_clear_layout();if(gtk_controls)g_hash_table_remove_all(gtk_controls);if(gtk_images)g_hash_table_remove_all(gtk_images);engine_document_free(doc);
    }
    return failures?1:0;
}
