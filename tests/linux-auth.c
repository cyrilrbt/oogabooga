// Real libsoup/GTK integration for cookies, HTTP credentials and decoding.
#include <gtk/gtk.h>
#include <libsoup/soup.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern GtkWidget *gtk_engine_view_new(void);
extern int gtk_engine_load_uri(const char *);
typedef struct {char *text;uint64_t length;void *nodes;uint64_t count;char *title;} Doc;
extern Doc *gtk_doc;
static int mode=1,dialogs,cookie_seen;
static void serve(SoupServer *s,SoupServerMessage *m,const char *path,GHashTable *query,gpointer u) {
    (void)s;(void)query;(void)u;
    const char *body="<title>Cookie set</title>",*type="text/html; charset=UTF-8";
    soup_server_message_set_status(m,200,NULL);
    if(!strcmp(path,"/cookie"))soup_message_headers_append(soup_server_message_get_response_headers(m),"Set-Cookie","assembly=present; Path=/");
    if(!strcmp(path,"/auth")||!strcmp(path,"/cancel")||!strcmp(path,"/retry")) {
        const char *cookie=soup_message_headers_get_one(soup_server_message_get_request_headers(m),"Cookie");
        if(cookie && strstr(cookie,"assembly=present"))cookie_seen++;
        const char *value=soup_message_headers_get_one(soup_server_message_get_request_headers(m),"Authorization");
        if(value && !strcmp(value,"Basic dXNlcjpwYXNz") && !strcmp(path,"/auth"))body="<title>Authenticated</title>";
        else {soup_server_message_set_status(m,401,NULL);soup_message_headers_append(soup_server_message_get_response_headers(m),"WWW-Authenticate",!strcmp(path,"/auth")?"Basic realm=valid":!strcmp(path,"/cancel")?"Basic realm=cancel":"Basic realm=retry");body="<title>Denied</title>";}
    }
    if(!strcmp(path,"/latin")){body="<title>Latin caf\xe9</title>";type="text/html; charset=ISO-8859-1";}
    if(!strcmp(path,"/utf16")) {
        gsize length=0;char *bytes=g_convert("<title>UTF16 café 🌐</title>",-1,"UTF-16LE","UTF-8",NULL,&length,NULL);assert(bytes);
        soup_server_message_set_response(m,"text/html; charset=UTF-16LE",SOUP_MEMORY_TAKE,bytes,length);return;
    }
    soup_server_message_set_response(m,type,SOUP_MEMORY_COPY,body,strlen(body));
}
static gboolean respond(gpointer u) {
    (void)u;GList *windows=gtk_window_list_toplevels();
    for(GList *w=windows;w;w=w->next)if(GTK_IS_DIALOG(w->data)&&gtk_widget_get_visible(w->data)) {
        GtkWidget *dialog=w->data;GList *children=gtk_container_get_children(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))));int index=0;
        for(GList *c=children;c;c=c->next)if(GTK_IS_ENTRY(c->data))gtk_entry_set_text(GTK_ENTRY(c->data),index++?(mode==3?"bad":"pass"):"user");
        g_list_free(children);dialogs++;gtk_dialog_response(GTK_DIALOG(dialog),mode==2?GTK_RESPONSE_CANCEL:GTK_RESPONSE_OK);
    }
    g_list_free(windows);return G_SOURCE_CONTINUE;
}
static void load(const char *base,const char *path,const char *title) {
    char *url=g_strconcat(base,path,NULL);Doc *before=gtk_doc;assert(gtk_engine_load_uri(url));g_free(url);
    gint64 deadline=g_get_monotonic_time()+20*G_TIME_SPAN_SECOND;
    do {while(g_main_context_pending(NULL))g_main_context_iteration(NULL,FALSE);g_usleep(1000);}
    while((gtk_doc==before||!gtk_doc||strcmp(gtk_doc->title,title))&&g_get_monotonic_time()<deadline);
    if(!gtk_doc || strcmp(gtk_doc->title,title))fprintf(stderr,"Auth fixture %s wanted %s got %s; dialogs %d\n",path,title,gtk_doc?gtk_doc->title:"none",dialogs);
    assert(gtk_doc && !strcmp(gtk_doc->title,title));
}
int main(int argc,char **argv) {
    gtk_init(&argc,&argv);SoupServer *server=soup_server_new(NULL,NULL);soup_server_add_handler(server,NULL,serve,NULL,NULL);assert(soup_server_listen_local(server,0,0,NULL));
    GSList *uris=soup_server_get_uris(server);char *base=g_uri_to_string(uris->data);base[strlen(base)-1]=0;
    GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_window_set_default_size(GTK_WINDOW(window),800,600);gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());gtk_widget_show_all(window);
    guint timer=g_timeout_add(10,respond,NULL);
    load(base,"/cookie","Cookie set");load(base,"/auth","Authenticated");assert(dialogs==1&&cookie_seen);
    mode=2;load(base,"/cancel","Denied");assert(dialogs==2);
    mode=3;load(base,"/retry","Denied");assert(dialogs==5);
    load(base,"/latin","Latin café");load(base,"/utf16","UTF16 café 🌐");
    g_source_remove(timer);gtk_widget_destroy(window);soup_server_disconnect(server);g_object_unref(server);g_slist_free_full(uris,(GDestroyNotify)g_uri_unref);g_free(base);
    puts("PASS: Linux assembly session cookies, native HTTP auth, cancellation, retry cap, Latin-1 and UTF-16 decoding");
}
