// Whole-application smoke: the default native engine, fallback toggle and chrome.
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <libsoup/soup.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern int browser_main(int,char **);
extern void __real_gtk_main(void);
typedef struct {char *text;uint64_t length;void *nodes;uint64_t count;char *title;} Doc;
extern Doc *gtk_doc;
extern GtkWidget *gtk_view;
static GtkWidget *window,*address,*back,*forward,*history,*status;
static WebKitWebView *web;
static char *base;
static int phase,ticks;
static Doc *before;
static void walk(GtkWidget *w,gpointer unused){
    (void)unused;
    if(GTK_IS_ENTRY(w)&&!address)address=w;
    if(WEBKIT_IS_WEB_VIEW(w))web=WEBKIT_WEB_VIEW(w);
    if(GTK_IS_LABEL(w)&&gtk_widget_get_parent(w)==gtk_bin_get_child(GTK_BIN(window)))status=w;
    if(GTK_IS_BUTTON(w)){const char *s=gtk_button_get_label(GTK_BUTTON(w));if(!g_strcmp0(s,"←"))back=w;if(!g_strcmp0(s,"→"))forward=w;if(!g_strcmp0(s,"History"))history=w;}
    if(GTK_IS_CONTAINER(w))gtk_container_foreach(GTK_CONTAINER(w),walk,NULL);
}
static void serve(SoupServer *s,SoupServerMessage *m,const char *path,GHashTable *q,gpointer u){
    (void)s;(void)q;(void)u;const char *body=!strcmp(path,"/second")?"<title>Second native page</title><p>Second page</p>":"<title>Assembly browser smoke</title><p>Default assembly path: café 🌐</p><input name=q value=editing><button>Send</button>";
    soup_server_message_set_status(m,200,NULL);soup_server_message_set_response(m,"text/html; charset=UTF-8",SOUP_MEMORY_COPY,body,strlen(body));
}
static gboolean poll(gpointer unused){
    (void)unused;assert(++ticks<9000);
    if(!gtk_doc||!status)return G_SOURCE_CONTINUE;
    const char *text=gtk_label_get_text(GTK_LABEL(status));
    if(phase==0&&strstr(text,"Assembly engine: ready")){
        assert(gtk_widget_get_visible(gtk_view)&&!gtk_widget_get_visible(GTK_WIDGET(web)));assert(strstr(gtk_window_get_title(GTK_WINDOW(window)),"Assembly · Oogabooga "));
        assert(gtk_accel_groups_activate(G_OBJECT(window),GDK_KEY_e,GDK_CONTROL_MASK));phase=1;
    }else if(phase==1&&!webkit_web_view_is_loading(web)&&!g_strcmp0(webkit_web_view_get_title(web),"Assembly browser smoke")){
        assert(!gtk_widget_get_visible(gtk_view)&&gtk_widget_get_visible(GTK_WIDGET(web)));before=gtk_doc;
        assert(gtk_accel_groups_activate(G_OBJECT(window),GDK_KEY_e,GDK_CONTROL_MASK));phase=2;
    }else if(phase==2&&gtk_doc!=before&&strstr(text,"Assembly engine: ready")){
        before=gtk_doc;char *url=g_strconcat(base,"/second",NULL);gtk_entry_set_text(GTK_ENTRY(address),url);g_free(url);g_signal_emit_by_name(address,"activate");phase=3;
    }else if(phase==3&&gtk_doc!=before&&!strcmp(gtk_doc->title,"Second native page")){
        assert(gtk_widget_get_sensitive(back));before=gtk_doc;gtk_button_clicked(GTK_BUTTON(back));phase=4;
    }else if(phase==4&&gtk_doc!=before&&!strcmp(gtk_doc->title,"Assembly browser smoke")){
        assert(gtk_widget_get_sensitive(forward));before=gtk_doc;gtk_button_clicked(GTK_BUTTON(forward));phase=5;
    }else if(phase==5&&gtk_doc!=before&&!strcmp(gtk_doc->title,"Second native page")){
        assert(gtk_accel_groups_activate(G_OBJECT(window),GDK_KEY_l,GDK_CONTROL_MASK));int start,end;assert(gtk_editable_get_selection_bounds(GTK_EDITABLE(address),&start,&end)&&start==0&&end==(int)strlen(gtk_entry_get_text(GTK_ENTRY(address))));
        assert(history);gtk_button_clicked(GTK_BUTTON(history));assert(gtk_accel_groups_activate(G_OBJECT(window),GDK_KEY_q,GDK_CONTROL_MASK));phase=6;return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}
void __wrap_gtk_main(void){
    GList *windows=gtk_window_list_toplevels();for(GList *n=windows;n;n=n->next)if(gtk_widget_get_visible(n->data)){window=n->data;break;}g_list_free(windows);assert(window);walk(window,NULL);assert(address&&web&&back&&forward&&history&&status);
    g_timeout_add(10,poll,NULL);__real_gtk_main();assert(phase==6);
}
int main(int argc,char **argv){
    gtk_init(&argc,&argv);SoupServer *server=soup_server_new(NULL,NULL);soup_server_add_handler(server,NULL,serve,NULL,NULL);assert(soup_server_listen_local(server,0,0,NULL));GSList *uris=soup_server_get_uris(server);base=g_uri_to_string(uris->data);base[strlen(base)-1]=0;
    char *args[]={"oogabooga",base,NULL};assert(browser_main(2,args)==0);soup_server_disconnect(server);g_object_unref(server);g_slist_free_full(uris,(GDestroyNotify)g_uri_unref);g_free(base);
    puts("PASS: Linux defaults to assembly, Ctrl+E fallback/return, versioned titles, address navigation, back/forward buttons, history UI and Ctrl+L/Q");
}
