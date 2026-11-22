// Real GTK widgets and events exercise shared source/scene coordinates.
#include <gtk/gtk.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
typedef struct {char *text;uint64_t length;uint64_t *nodes;uint64_t count;char *title;uint64_t capacity,title_length;char *css;uint64_t css_length;unsigned char *meta;} Doc;
extern Doc *engine_parse(const char *,size_t);
extern GtkWidget *gtk_engine_view_new(void);
extern void gtk_engine_show_document(Doc *),gtk_engine_controls_place(void),gtk_selection_copy(void);
extern int gtk_engine_key(GtkWidget *,GdkEvent *,void *),gtk_engine_scroll_key(GdkEvent *);
extern int gtk_engine_prepare(Doc *,uint64_t),gtk_engine_scroll_at(int64_t,int64_t,double,double);
extern const char *gtk_engine_link_at(int64_t,int64_t);
extern unsigned char *gtk_nodes,*gtk_scene,*gtk_groups;
extern GtkWidget *gtk_view,*gtk_drawing;
extern uint64_t gtk_selection_anchor,gtk_selection_focus;
static size_t id(Doc *d,const char *s){for(size_t i=0;i<d->count;i++){char *v=*(char **)(d->meta+i*2048);if(v&&!strcmp(v,s))return i;}assert(0);return 0;}
static int64_t n(size_t i,int offset){return *(int64_t *)(gtk_nodes+i*256+offset);}
static double sc(size_t i,int offset){unsigned char *r=*(unsigned char **)(gtk_scene+8);return *(double *)(r+i*512+offset);}
static void flush(void){for(int i=0;i<30;i++){while(gtk_events_pending())gtk_main_iteration();g_usleep(1000);}}
int main(int argc,char **argv){
    gtk_init(&argc,&argv);GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_window_set_default_size(GTK_WINDOW(window),800,600);gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());gtk_widget_show_all(window);flush();
    const char *html="<body style='margin:0;font:16px Arial'><p><a href=/next>café 🌐 link</a></p><div id=clip style='position:relative;width:100px;height:30px;overflow:hidden'><input id=field style='width:160px;height:30px' value=original></div><div id=scroll style='width:150px;height:40px;overflow:auto'><p style='height:140px;margin:0'>Scroll text and <a href=/deep>deep</a></p></div><div id=fixed style='position:fixed;left:500px;top:5px;width:60px;height:20px'>Fixed</div><div style='height:1200px'></div></body>";
    Doc *d=engine_parse(html,strlen(html));assert(d);gtk_engine_show_document(d);flush();
    size_t field=id(d,"field"),scroll=id(d,"scroll"),fixed=id(d,"fixed");GtkWidget *entry=(void *)(uintptr_t)n(field,88),*host=(void *)(uintptr_t)n(field,192);assert(entry&&host);
    GtkAllocation allocation;gtk_widget_get_allocation(host,&allocation);assert(allocation.width==100 && allocation.height==30);
    gtk_entry_set_text(GTK_ENTRY(entry),"edited café");gtk_widget_grab_focus(entry);gtk_editable_select_region(GTK_EDITABLE(entry),2,5);
    assert(gtk_engine_prepare(d,700));gtk_engine_controls_place();flush();
    assert((void *)(uintptr_t)n(field,88)==entry && !strcmp(gtk_entry_get_text(GTK_ENTRY(entry)),"edited café"));
    assert(gtk_window_get_focus(GTK_WINDOW(window))==entry);int start,end;assert(gtk_editable_get_selection_bounds(GTK_EDITABLE(entry),&start,&end)&&start==2&&end==5);
    int link=0;
    for(unsigned char *g=gtk_groups;g;g=*(unsigned char **)g){PangoLayout *layout=*(PangoLayout **)(g+16);const char *text=pango_layout_get_text(layout);const char *p=strstr(text,"link");if(!p)continue;PangoRectangle r;pango_layout_index_to_pos(layout,(int)(p-text),&r);const char *href=gtk_engine_link_at(*(int64_t *)(g+40)+r.x/PANGO_SCALE+2,*(int64_t *)(g+48)+r.y/PANGO_SCALE+2);assert(href&&!strcmp(href,"/next"));link++;}assert(link==1);
    GdkEvent *event=gdk_event_new(GDK_KEY_PRESS);event->key.state=GDK_CONTROL_MASK;event->key.keyval=GDK_KEY_a;assert(gtk_engine_key(gtk_drawing,event,NULL));assert(gtk_selection_focus>gtk_selection_anchor);
    event->key.keyval=GDK_KEY_c;assert(gtk_engine_key(gtk_drawing,event,NULL));char *copied=gtk_clipboard_wait_for_text(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD));assert(copied&&strstr(copied,"café 🌐 link"));g_free(copied);gdk_event_free(event);
    assert(sc(scroll,256)>=100);assert(gtk_engine_scroll_at(n(scroll,24)+5,n(scroll,32)+20,0,25));assert(fabs(sc(scroll,240)-25)<.1);
    assert(gtk_engine_prepare(d,700));gtk_engine_controls_place();assert(fabs(sc(scroll,240)-25)<.1);
    GtkAdjustment *adjustment=gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(gtk_view));gtk_adjustment_set_value(adjustment,100);flush();
    double visible=sc(fixed,104)+sc(fixed,136)-gtk_adjustment_get_value(adjustment);assert(fabs(visible-5)<1);
    gtk_widget_destroy(window);puts("PASS: Linux clipped editor geometry, focus/value preservation, Unicode links, select-all/copy, contained scrolling, reflow offsets and fixed viewport positioning");
}
