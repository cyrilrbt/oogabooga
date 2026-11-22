// Cross-feature regressions for the next shared engine milestone.
#include <gtk/gtk.h>
#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
typedef struct {char *text;uint64_t length;uint64_t *nodes;uint64_t count;char *title;uint64_t capacity,title_length;char *css;uint64_t css_length;unsigned char *meta;} Doc;
extern Doc *engine_parse(const char *,size_t),*gtk_doc;
extern GtkWidget *gtk_engine_view_new(void),*gtk_view;
extern void gtk_engine_show_document(Doc *),gtk_engine_paint(cairo_t *),gtk_engine_back(void),gtk_navigation_commit(void);
extern void gtk_state_point(int64_t,int64_t,uint64_t,uint64_t);
extern int gtk_fragment_navigate(const char *);
extern unsigned char *gtk_nodes,*gtk_groups;
extern char *gtk_uri,*gtk_base;
static size_t id(Doc *d,const char *s){for(size_t i=0;i<d->count;i++){char *v=*(char **)(d->meta+i*2048);if(v&&!strcmp(v,s))return i;}assert(0);return 0;}
static int64_t n(size_t i,int offset){return *(int64_t *)(gtk_nodes+i*256+offset);}
static void flush(void){for(int i=0;i<30;i++){while(gtk_events_pending())gtk_main_iteration();g_usleep(1000);}}
int main(int argc,char **argv){
    gtk_init(&argc,&argv);GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_window_set_default_size(GTK_WINDOW(window),800,600);gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());gtk_widget_show_all(window);flush();
    char *html;gsize length;assert(g_file_get_contents("tests/fixtures/engine-foundations.html",&html,&length,NULL));Doc *d=engine_parse(html,length);g_free(html);assert(d);
    gtk_uri=g_strdup("https://engine.test/engine/foundations");gtk_engine_show_document(d);flush();
    assert(!strcmp(gtk_base,"https://engine.test/engine/"));
    size_t editor=id(d,"editor"),check=id(d,"check"),wrapped=id(d,"wrapped");
    int wrappedLines=0;for(unsigned char *g=gtk_groups;g;g=*(unsigned char **)g){PangoLayout *layout=*(PangoLayout **)(g+16);const char *text=pango_layout_get_text(layout);if(strstr(text,"a long styled"))wrappedLines=pango_layout_get_line_count(layout);}assert(wrappedLines>=3);
    cairo_surface_t *surface=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,800,600);cairo_t *cr=cairo_create(surface);gtk_engine_paint(cr);cairo_destroy(cr);cairo_surface_flush(surface);
    unsigned char *pixels=cairo_image_surface_get_data(surface);int red=0,stride=cairo_image_surface_get_stride(surface);for(int y=0;y<600;y++)for(int x=0;x<800;x++){unsigned char *p=pixels+y*stride+x*4;if(p[2]>150&&p[1]<50&&p[0]<50)red++;}assert(red>100);assert(cairo_surface_write_to_png(surface,"build/linux/engine/foundations.png")==CAIRO_STATUS_SUCCESS);cairo_surface_destroy(surface);
    GtkWidget *entry=(void *)(uintptr_t)n(editor,88);gtk_entry_set_text(GTK_ENTRY(entry),"preserved café");gtk_widget_grab_focus(entry);gtk_editable_select_region(GTK_EDITABLE(entry),1,5);flush();
    assert(*(uint64_t *)(d->meta+editor*2048+40)==0xfff2cc);
    assert((void *)(uintptr_t)n(editor,88)==entry&&!strcmp(gtk_entry_get_text(GTK_ENTRY(entry)),"preserved café"));int start,end;assert(gtk_editable_get_selection_bounds(GTK_EDITABLE(entry),&start,&end)&&start==1&&end==5);
    gtk_toggle_button_set_active((void *)(uintptr_t)n(check,88),TRUE);flush();assert(*(uint64_t *)(d->meta+check*2048+40)==0x00ff00);
    (void)wrapped;
    gtk_navigation_commit();GtkAdjustment *adjustment=gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(gtk_view));gtk_adjustment_set_value(adjustment,75);flush();double before=gtk_adjustment_get_value(adjustment);
    assert(gtk_fragment_navigate("https://engine.test/engine/foundations#caf%C3%A9"));flush();assert(gtk_doc==d&&gtk_adjustment_get_value(adjustment)>300);
    gtk_engine_back();flush();assert(gtk_doc==d&&fabs(gtk_adjustment_get_value(adjustment)-before)<1);
    gtk_widget_destroy(window);puts("PASS: Linux wrapped inline decorations, CSS math, live focus/checked styles, retained editor selection, document base, Unicode same-document fragments and history scroll restoration");
}
