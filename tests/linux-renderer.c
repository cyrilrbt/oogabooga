// Native integration harness only. Production rendering is assembly + GTK APIs.
#include <gtk/gtk.h>
#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct { char *text; uint64_t length; void *nodes; uint64_t count; char *title; uint64_t capacity,title_length; char *css; uint64_t css_length; void *meta; } Doc;
extern Doc *engine_parse(const char *,size_t);
extern void engine_document_free(Doc *);
extern int gtk_engine_prepare(Doc *,uint64_t);
extern void gtk_engine_clear_layout(void);
extern GtkWidget *gtk_engine_view_new(void);
extern void gtk_engine_show_document(Doc *);
extern void gtk_engine_paint(cairo_t *);
extern uint64_t gtk_height;
extern unsigned char *gtk_nodes;
extern unsigned char *gtk_groups;
extern const char *gtk_engine_link_at(int64_t,int64_t);
static int64_t metric(size_t node,size_t offset) { return *(int64_t *)(gtk_nodes+node*256+offset); }
int main(int argc,char **argv) {
    gtk_init(&argc,&argv);
    GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_default_size(GTK_WINDOW(window),800,600);
    gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());
    gtk_widget_show_all(window);
    while(gtk_events_pending()) gtk_main_iteration();
    const char *html="<body style='font-family:Arial;background:white'><div id=box style='width:200px;padding:10px;border:2px solid red'><p>Hello <b>café 🌐</b> <a href=/next>world</a></p><input value=test><button>Send</button></div><div style='display:flex;width:400px;gap:20px'><div style='width:100px'>Left</div><div style='width:100px'>Right</div></div></body>";
    Doc *doc=engine_parse(html,strlen(html)); assert(doc);
    gtk_engine_show_document(doc);
    assert(gtk_height>0 && gtk_height<2000 && gtk_groups);
    int found=0;
    for(unsigned char *g=gtk_groups;g;g=*(unsigned char **)g) {
        PangoLayout *layout=*(PangoLayout **)(g+16);
        const char *text=pango_layout_get_text(layout),*link=strstr(text,"world");
        if(!link)continue;
        PangoRectangle r;pango_layout_index_to_pos(layout,(int)(link-text),&r);
        const char *href=gtk_engine_link_at(*(int64_t *)(g+40)+r.x/PANGO_SCALE+2,*(int64_t *)(g+48)+r.y/PANGO_SCALE+2);
        assert(href && !strcmp(href,"/next"));found++;
    }
    assert(found==1);
    for(size_t i=0;i<doc->count;i++) if(((uint64_t *)doc->nodes)[i*5]==31) {
        assert(metric(i,40)>20 && metric(i,48)>10);
        GtkWidget *entry=*(GtkWidget **)(gtk_nodes+i*256+88);assert(entry);
        gtk_entry_set_text(GTK_ENTRY(entry),"edited café");
        assert(gtk_engine_prepare(doc,640));
        assert(*(GtkWidget **)(gtk_nodes+i*256+88)==entry);
        assert(!strcmp(gtk_entry_get_text(GTK_ENTRY(entry)),"edited café"));
    }
    cairo_surface_t *s=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,800,(int)gtk_height);
    cairo_t *cr=cairo_create(s); gtk_engine_paint(cr);
    assert(cairo_status(cr)==CAIRO_STATUS_SUCCESS);
    assert(cairo_surface_write_to_png(s,"build/linux/engine/renderer.png")==CAIRO_STATUS_SUCCESS);
    cairo_destroy(cr); cairo_surface_destroy(s);
    gtk_engine_clear_layout(); engine_document_free(doc);
    gtk_widget_destroy(window);
    puts("PASS: native assembly GTK shaping, inline object geometry, retained boxes and Cairo rendering");
}
