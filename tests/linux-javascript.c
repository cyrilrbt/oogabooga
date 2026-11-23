// Native bridge regression: real GLib callbacks, editors, and streaming HTTP.
#include <gtk/gtk.h>
#include <libsoup/soup.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef struct {char *text;uint64_t length,*nodes,count;char *title;uint64_t capacity,title_length;char *css;uint64_t css_length;unsigned char *meta;} Doc;
extern Doc *gtk_doc;
extern unsigned char *gtk_nodes;
extern void *gtk_js_vm;
extern GtkWidget *gtk_engine_view_new(void);
extern int gtk_engine_load_uri(const char *),gtk_js_event_node(uint64_t,const char *);
extern void gtk_engine_shutdown(void);
extern uintptr_t engine_js_global(void *,const char *);
static unsigned external,data,redirectTarget;
static void serve(SoupServer *s,SoupServerMessage *m,const char *path,GHashTable *q,gpointer u){
    (void)s;(void)q;(void)u;
    const char *type="text/html",*body="<title>Fresh</title>";
    if(!strcmp(path,"/page"))body="<title>JS initial</title><p id=out>before</p><input id=field value=initial><button id=button type=button>Click</button><form id=form><button>Send</button></form><script>var order='I';var clicks=0;var blocked=0;fetch('https://other.invalid/data').catch(()=>{blocked++;});fetch('/redirect').catch(()=>{blocked++;});document.getElementById('button').addEventListener('click',()=>{clicks++;document.getElementById('out').textContent='clicked';});document.getElementById('field').addEventListener('input',()=>{document.getElementById('out').textContent=document.getElementById('field').value;});document.getElementById('form').addEventListener('submit',event=>{event.preventDefault();});</script><script src='/code.js'></script><script>order+='F';fetch('/data.json').then(r=>r.json()).then(data=>{document.title=data.title;});setTimeout(()=>{document.getElementById('field').value='timer';},30);</script>";
    if(!strcmp(path,"/redirect")){soup_server_message_set_redirect(m,302,"/redirect-target");return;}
    if(!strcmp(path,"/redirect-target"))redirectTarget++;
    if(!strcmp(path,"/code.js")){external++;type="application/javascript";body="order+='E';";}
    if(!strcmp(path,"/data.json")){data++;type="application/json";body="{\"title\":\"JS fetched\"}";}
    if(!strcmp(path,"/csp")){soup_message_headers_append(soup_server_message_get_response_headers(m),"Content-Security-Policy","script-src 'none'");body="<title>CSP</title><script>document.title='escaped';</script>";}
    soup_server_message_set_status(m,200,NULL);soup_server_message_set_response(m,type,SOUP_MEMORY_COPY,body,strlen(body));
}
static void pump(void){while(g_main_context_pending(NULL))g_main_context_iteration(NULL,FALSE);g_usleep(1000);}
static void title(const char *v){gint64 end=g_get_monotonic_time()+15*G_TIME_SPAN_SECOND;while((!gtk_doc||strcmp(gtk_doc->title,v))&&g_get_monotonic_time()<end)pump();if(!gtk_doc||strcmp(gtk_doc->title,v))fprintf(stderr,"Expected %s actual %s\n",v,gtk_doc?gtk_doc->title:"nil");assert(gtk_doc&&!strcmp(gtk_doc->title,v));}
static size_t id(const char *v){for(size_t i=0;i<gtk_doc->count;i++){char *s=*(char **)(gtk_doc->meta+i*2048);if(s&&!strcmp(s,v))return i;}assert(0);return 0;}
int main(int argc,char **argv){gtk_init(&argc,&argv);SoupServer *server=soup_server_new(NULL,NULL);soup_server_add_handler(server,NULL,serve,NULL,NULL);assert(soup_server_listen_local(server,0,0,NULL));GSList *uris=soup_server_get_uris(server);char *base=g_uri_to_string(uris->data);GtkWidget *window=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_container_add(GTK_CONTAINER(window),gtk_engine_view_new());gtk_widget_show_all(window);char *url=g_strconcat(base,"page",NULL);assert(gtk_engine_load_uri(url));title("JS fetched");assert(external==1&&data==1&&gtk_js_vm);uintptr_t v=engine_js_global(gtk_js_vm,"order");assert(v>3&&!strcmp(*(char **)(v+8),"IEF"));
    gint64 policyEnd=g_get_monotonic_time()+G_TIME_SPAN_SECOND;while(*(double *)(engine_js_global(gtk_js_vm,"blocked")+8)!=2&&g_get_monotonic_time()<policyEnd)pump();assert(*(double *)(engine_js_global(gtk_js_vm,"blocked")+8)==2&&!redirectTarget);
    GtkWidget *entry=*(GtkWidget **)(gtk_nodes+id("field")*256+88);gint64 end=g_get_monotonic_time()+G_TIME_SPAN_SECOND;while(strcmp(gtk_entry_get_text(GTK_ENTRY(entry)),"timer")&&g_get_monotonic_time()<end)pump();assert(!strcmp(gtk_entry_get_text(GTK_ENTRY(entry)),"timer"));gtk_entry_set_text(GTK_ENTRY(entry),"typed café");assert(strstr(gtk_doc->text,"typed café"));GtkWidget *button=*(GtkWidget **)(gtk_nodes+id("button")*256+88);assert(gtk_widget_get_sensitive(button));gtk_button_clicked(GTK_BUTTON(button));assert(strstr(gtk_doc->text,"clicked"));assert(gtk_js_event_node(id("form"),"submit"));
    g_free(url);url=g_strconcat(base,"csp",NULL);assert(gtk_engine_load_uri(url));title("CSP");assert(!gtk_js_vm);g_free(url);url=g_strconcat(base,"fresh",NULL);assert(gtk_engine_load_uri(url));title("Fresh");gtk_engine_shutdown();gtk_widget_destroy(window);g_free(url);g_free(base);g_slist_free_full(uris,(GDestroyNotify)g_uri_unref);g_object_unref(server);puts("PASS: Linux assembly JavaScript DOM rebuilds, live input, cancellation, timers, ordered external scripts, same-origin fetch/JSON and HTTP CSP");}
