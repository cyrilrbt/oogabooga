// Generic geometry cases beyond the saved-page dashboard.
#include <gtk/gtk.h>
#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct {char *text;uint64_t length;uint64_t *nodes;uint64_t count;char *title;uint64_t capacity,title_length;char *css;uint64_t css_length;unsigned char *meta;} Doc;
extern Doc *engine_parse(const char *,size_t);
extern void engine_document_free(Doc *),gtk_engine_clear_layout(void);
extern int gtk_engine_prepare(Doc *,uint64_t);
extern unsigned char *gtk_nodes;
extern GHashTable *gtk_controls;
static size_t id(Doc *d,const char *s){for(size_t i=0;i<d->count;i++){char *v=*(char **)(d->meta+i*2048);if(v&&!strcmp(v,s))return i;}assert(0);return 0;}
static int64_t at(Doc *d,const char *s,int offset){return *(int64_t *)(gtk_nodes+id(d,s)*256+offset);}
static Doc *load(const char *s){Doc *d=engine_parse(s,strlen(s));assert(d&&gtk_engine_prepare(d,600));return d;}
static void close_doc(Doc *d){gtk_engine_clear_layout();if(gtk_controls)g_hash_table_remove_all(gtk_controls);engine_document_free(d);}
int main(int argc,char **argv){gtk_init(&argc,&argv);
    Doc *d=load("<body style='margin:0'><div style='display:grid;width:320px;grid-template-columns:100px 100px 100px;grid-auto-rows:40px;gap:10px'><div id=a style='grid-column:3'>A</div><div id=b style='grid-row:2;grid-column:2 / span 2'>B</div><div id=c style='grid-row:3 / span 2'>C</div></div></body>");
    assert(at(d,"a",24)==220 && at(d,"b",24)==110 && at(d,"b",32)==50 && at(d,"b",40)==210 && at(d,"c",48)==90);close_doc(d);
    d=load("<body style='margin:0'><table style='width:300px' cellspacing=0 cellpadding=0><tr><td id=a rowspan=2 style='width:100px;height:60px'>A</td><td id=b style='height:20px'>B</td></tr><tr><td id=c style='height:40px'>C</td></tr></table></body>");
    assert(at(d,"a",24)==0&&at(d,"a",48)==60&&at(d,"b",24)==100&&at(d,"c",24)==100&&at(d,"c",32)==20);close_doc(d);
    d=load("<body style='margin:0'><div style='display:flex;flex-direction:row-reverse;width:110px;gap:10px'><div id=a style='width:30px;height:20px'>A</div><div id=b style='width:30px;height:20px'>B</div><div id=c style='width:30px;height:20px'>C</div></div></body>");
    assert(at(d,"a",24)==80&&at(d,"b",24)==40&&at(d,"c",24)==0);close_doc(d);
    d=load("<body style='margin:0'><div style='display:flex;flex-direction:column;width:100px;gap:10px'><div id=a style='height:20px'>A</div><div id=b style='height:30px'>B</div></div></body>");
    assert(at(d,"a",32)==0&&at(d,"b",32)==30);close_doc(d);
    d=load("<body><form><input id=a type=radio name=group><span><input id=b type=radio name=group checked></span><input id=c type=radio name=other></form><form><input id=d type=radio name=group checked></form><div style='display:none'><input id=hidden value=kept></div><input id=password type=password value=secret><input id=file type=file></body>");
    GtkToggleButton *a=(void *)(uintptr_t)at(d,"a",88),*b=(void *)(uintptr_t)at(d,"b",88),*c=(void *)(uintptr_t)at(d,"c",88),*other=(void *)(uintptr_t)at(d,"d",88);
    assert(!gtk_toggle_button_get_active(a)&&gtk_toggle_button_get_active(b)&&!gtk_toggle_button_get_active(c)&&gtk_toggle_button_get_active(other));
    gtk_toggle_button_set_active(a,TRUE);assert(!gtk_toggle_button_get_active(b)&&gtk_toggle_button_get_active(other));
    assert(!gtk_widget_get_sensitive((void *)(uintptr_t)at(d,"password",88))&&!gtk_widget_get_sensitive((void *)(uintptr_t)at(d,"file",88)));close_doc(d);
    puts("PASS: Linux sparse/spanning Grid, HTML table rowspans, reverse/column flex, form-scoped radios and unsupported control policy");
}
