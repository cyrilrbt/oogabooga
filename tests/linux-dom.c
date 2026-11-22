// Persistent DOM rebuilds retain native editing state and do not add visits.
#include <gtk/gtk.h>
#include <sqlite3.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef struct {char *text;uint64_t length;uint64_t *nodes;uint64_t count;char *title;uint64_t capacity,title_length;char *css;uint64_t css_length;unsigned char *meta;void *hidden;uint64_t work;void *dom;} Doc;
extern Doc *engine_parse(const char *,size_t),*gtk_doc;
extern GtkWidget *gtk_engine_view_new(void);
extern void gtk_engine_bind(void *,void *,void *,void *,void *,void *),gtk_engine_show_document(Doc *),gtk_engine_committed(void),gtk_resources_styles(void);
extern int gtk_dom_rebuild(Doc *),history_open(const char *,sqlite3 **),history_add(sqlite3 *,const char *,const char *);
extern uint64_t engine_dom_get_element_by_id(void *,const char *),engine_dom_create_element(void *,const char *,size_t);
extern int engine_dom_set_text_content(void *,uint64_t,const char *,size_t),engine_dom_set_attribute(void *,uint64_t,const char *,const char *,size_t),engine_dom_insert_before(void *,uint64_t,uint64_t,uint64_t);
extern char *gtk_uri;
extern unsigned char *gtk_nodes;
static size_t id(Doc *d,const char *s){for(size_t i=0;i<d->count;i++){char *v=*(char **)(d->meta+i*2048);if(v&&!strcmp(v,s))return i;}assert(0);return 0;}
static void flush(void){for(int i=0;i<20;i++){while(gtk_events_pending())gtk_main_iteration();g_usleep(1000);}}
int main(int argc,char **argv){
    gtk_init(&argc,&argv);sqlite3 *db=NULL;assert(!history_open(":memory:",&db));assert(!history_add(db,"http://fixture.local/visited","Visited"));
    GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_window_set_default_size(GTK_WINDOW(window),800,600);gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());gtk_widget_show_all(window);flush();
    gtk_engine_bind(window,NULL,NULL,db,NULL,NULL);gtk_uri=g_strdup("http://fixture.local/page");
    const char *html="<title id=title>Original</title><style>body{margin:0}a{color:blue}a:visited{color:purple}</style><link id=sheet rel=stylesheet href=/sheet.css><form id=form><span id=label>Original label</span><input id=field name=q value=original><button>Send</button></form><a id=old href=/visited>Visited</a><a id=new href=/new>New</a>";
    Doc *d=engine_parse(html,strlen(html));assert(d);gtk_doc=d;
    *(char **)(d->meta+id(d,"sheet")*2048+680)=g_strdup("#label {font-weight:700;color:#123456}");gtk_resources_styles();gtk_engine_show_document(d);gtk_engine_committed();flush();
    assert(*(uint64_t *)(d->meta+id(d,"old")*2048+864)==1 && *(uint64_t *)(d->meta+id(d,"new")*2048+864)==0);
    assert(*(uint64_t *)(d->meta+id(d,"old")*2048+32)==0x800080 && *(uint64_t *)(d->meta+id(d,"new")*2048+32)==0x0000ff);
    GtkWidget *entry=*(GtkWidget **)(gtk_nodes+id(d,"field")*256+88);gtk_entry_set_text(GTK_ENTRY(entry),"kept café");gtk_widget_grab_focus(entry);gtk_editable_select_region(GTK_EDITABLE(entry),2,4);
    uint64_t label=engine_dom_get_element_by_id(d->dom,"label"),title=engine_dom_get_element_by_id(d->dom,"title"),form=engine_dom_get_element_by_id(d->dom,"form");assert(label&&title&&form);
    assert(!engine_dom_set_text_content(d->dom,label,"Changed 🌐",strlen("Changed 🌐")));assert(!engine_dom_set_text_content(d->dom,title,"Mutated",7));assert(!engine_dom_set_attribute(d->dom,label,"style","color:red",9));
    uint64_t extra=engine_dom_create_element(d->dom,"p",1);assert(extra&&!engine_dom_set_text_content(d->dom,extra,"Inserted",8)&&!engine_dom_insert_before(d->dom,form,extra,label));
    assert(gtk_dom_rebuild(d));d=gtk_doc;flush();
    assert(strstr(d->text,"Changed 🌐") && !strcmp(d->title,"Mutated"));assert(*(uint64_t *)(d->meta+id(d,"label")*2048+32)==0xff0000);
    assert(*(char **)(d->meta+id(d,"sheet")*2048+680) && strstr(*(char **)(d->meta+id(d,"sheet")*2048+680),"font-weight"));
    assert(*(GtkWidget **)(gtk_nodes+id(d,"field")*256+88)==entry&&!strcmp(gtk_entry_get_text(GTK_ENTRY(entry)),"kept café"));int start,end;assert(gtk_editable_get_selection_bounds(GTK_EDITABLE(entry),&start,&end)&&start==2&&end==4);
    sqlite3_stmt *stmt=NULL;assert(sqlite3_prepare_v2(db,"SELECT count(*),max(CASE WHEN id=2 THEN title END) FROM visits",-1,&stmt,NULL)==SQLITE_OK&&sqlite3_step(stmt)==SQLITE_ROW);assert(sqlite3_column_int(stmt,0)==2&&!strcmp((const char *)sqlite3_column_text(stmt,1),"Mutated"));sqlite3_finalize(stmt);
    gtk_widget_destroy(window);sqlite3_close(db);puts("PASS: Linux DOM mutation, resource transfer, stable native editors/selections, indexed visited-link CSS and title-only history updates");
}
