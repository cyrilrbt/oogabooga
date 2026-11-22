// Independent custom-engine transport integration; no WebKit objects involved.
#include <gtk/gtk.h>
#include <libsoup/soup.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern GtkWidget *gtk_engine_view_new(void);
extern int gtk_engine_load_uri(const char *);
extern char *gtk_uri;
extern void *gtk_doc,*gtk_images;
extern void gtk_form_submit(uint64_t);
extern void gtk_engine_back(void);
typedef struct {char *text;uint64_t length;uint64_t *nodes;uint64_t count;char *title;} Doc;
static guint requests,forms;
static int64_t deadline;
static void wait_title(const char *title) {
    deadline=g_get_monotonic_time()+20*G_TIME_SPAN_SECOND;
    do {while(g_main_context_pending(NULL))g_main_context_iteration(NULL,FALSE);g_usleep(1000);}
    while((!gtk_doc || strcmp(((Doc *)gtk_doc)->title,title)) && g_get_monotonic_time()<deadline);
    assert(gtk_doc && !strcmp(((Doc *)gtk_doc)->title,title));
}
static uint64_t submitter(void) {Doc *d=gtk_doc;for(uint64_t i=0;i<d->count;i++)if(d->nodes[i*5]==34)return i;assert(0);return 0;}
static void serve(SoupServer *s,SoupServerMessage *m,const char *path,GHashTable *q,gpointer u) {
    (void)s;(void)q;(void)u; requests++;
    const char *body="<title>Linux assembly fixture</title><base href=/base/><base href=/ignored/><link rel=stylesheet href=style.css><body><p id=message>café 🌐</p><form action=result><input name=q value='café + 🌐'><input type=checkbox name=check checked><input type=checkbox name=omit><select name=flavor><option value=vanilla>Vanilla</option><option selected value=chocolate>Chocolate</option></select><button name=send value=yes>Send</button></form></body>";
    const char *type="text/html; charset=UTF-8";
    if(!strcmp(path,"/base/style.css")) { body="@import 'relative/child.css' screen; body {background:#fafafa;font-family:Arial}";type="text/css"; }
    if(!strcmp(path,"/base/relative/child.css")){body="@font-face {font-family:'Ooga Web';src:url(../ooga.ttf) format('truetype')} #message {font-family:'Ooga Web',Arial;color:#123456;background:url(../pixel.svg) no-repeat}";type="text/css";}
    if(!strcmp(path,"/base/ooga.ttf")){char *font=NULL;gsize size=0;assert(g_file_get_contents("tests/fixtures/ooga-test.ttf",&font,&size,NULL));soup_server_message_set_status(m,200,NULL);soup_server_message_set_response(m,"font/ttf",SOUP_MEMORY_TAKE,font,size);return;}
    if(!strcmp(path,"/base/pixel.svg")){body="<svg width='8' height='8'><rect width='8' height='8' fill='green'/></svg>";type="image/svg+xml";}
    if(!strcmp(path,"/base/result")) {
        assert(q && !strcmp(g_hash_table_lookup(q,"q"),"café + 🌐"));
        assert(!strcmp(g_hash_table_lookup(q,"check"),"on"));
        assert(!g_hash_table_contains(q,"omit"));
        assert(!strcmp(g_hash_table_lookup(q,"flavor"),"chocolate"));
        assert(!strcmp(g_hash_table_lookup(q,"send"),"yes"));
        forms++;body="<title>GET submitted</title><form action=/post method=post><input name=q value='post + café'><button>POST</button></form>";
    }
    if(!strcmp(path,"/post")) {
        SoupMessageBody *request=soup_server_message_get_request_body(m);
        assert(!strcmp(soup_server_message_get_method(m),"POST"));
        assert(request->length==strlen("q=post+%2B+caf%C3%A9"));
        assert(!memcmp(request->data,"q=post+%2B+caf%C3%A9",request->length));
        forms++;body="<title>POST submitted</title><p>done</p>";
    }
    soup_server_message_set_status(m,SOUP_STATUS_OK,NULL);
    soup_server_message_set_response(m,type,SOUP_MEMORY_COPY,body,strlen(body));
}
int main(int argc,char **argv) {
    gtk_init(&argc,&argv);
    SoupServer *server=soup_server_new(NULL,NULL);
    soup_server_add_handler(server,NULL,serve,NULL,NULL);
    GError *error=NULL;assert(soup_server_listen_local(server,0,0,&error));assert(!error);
    GSList *uris=soup_server_get_uris(server);assert(uris);
    char *url=g_uri_to_string(uris->data);
    GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_default_size(GTK_WINDOW(window),800,600);
    gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());gtk_widget_show_all(window);
    assert(!gtk_engine_load_uri("file:///etc/passwd"));
    assert(!gtk_engine_load_uri("javascript:alert(1)"));
    assert(gtk_engine_load_uri(url));
    gint64 deadline=g_get_monotonic_time()+20*G_TIME_SPAN_SECOND;
    while((!gtk_uri || requests<5) && g_get_monotonic_time()<deadline){while(g_main_context_pending(NULL))g_main_context_iteration(NULL,FALSE);g_usleep(1000);}
    for(int i=0;i<50;i++) {while(g_main_context_pending(NULL))g_main_context_iteration(NULL,FALSE);g_usleep(1000);}
    assert(gtk_uri && !strcmp(gtk_uri,url) && gtk_doc && requests==5);
    assert(gtk_images && g_hash_table_size(gtk_images)==1);
    uint64_t *d=gtk_doc;unsigned char *meta=(void *)(uintptr_t)d[9];int webfont=0;
    for(uint64_t i=0;i<d[3];i++){char *id=*(char **)(meta+i*2048);if(id&&!strcmp(id,"message")){assert(*(uint64_t *)(meta+i*2048+120)>=256);webfont++;}}assert(webfont==1);
    gtk_form_submit(submitter());wait_title("GET submitted");assert(forms==1);
    gtk_form_submit(submitter());wait_title("POST submitted");assert(forms==2);
    gtk_engine_back();wait_title("GET submitted");
    guint before=requests;
    assert(gtk_engine_load_uri(url)); // immediately supersede this request
    assert(gtk_engine_load_uri(url));
    deadline=g_get_monotonic_time()+20*G_TIME_SPAN_SECOND;
    while(requests<before+2 && g_get_monotonic_time()<deadline){while(g_main_context_pending(NULL))g_main_context_iteration(NULL,FALSE);g_usleep(1000);}
    assert(gtk_doc);
    gtk_widget_destroy(window);soup_server_disconnect(server);g_object_unref(server);
    g_slist_free_full(uris,(GDestroyNotify)g_uri_unref);g_free(url);
    puts("PASS: independent Linux HTTP, UTF-8 navigation, linked/imported CSS, stylesheet-relative SVG backgrounds, native web fonts, GET/POST forms, selects, back navigation, scheme rejection and cancellation");
}
