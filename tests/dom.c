#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
typedef struct Node { uint64_t type,parent,first,last,previous,next; char *name,*value; void *attributes; uint64_t height,source_offset,snapshot_version; } Node;
typedef struct Document { Node *nodes; uint64_t allocated,live,version,bytes,root,reserved[2]; } Document;
extern Document *engine_dom_new(void);
extern void engine_dom_free(Document *);
extern Node *engine_dom_node(Document *,uint64_t);
extern uint64_t engine_dom_create_element(Document *,const char *,size_t);
extern uint64_t engine_dom_create_text(Document *,const char *,size_t);
extern uint64_t engine_dom_create_comment(Document *,const char *,size_t);
extern int engine_dom_insert_before(Document *,uint64_t,uint64_t,uint64_t);
extern int engine_dom_detach(Document *,uint64_t);
extern int engine_dom_remove(Document *,uint64_t);
extern int engine_dom_set_text(Document *,uint64_t,const char *,size_t);
extern int engine_dom_set_text_content(Document *,uint64_t,const char *,size_t);
extern int engine_dom_set_attribute(Document *,uint64_t,const char *,const char *,size_t);
extern const char *engine_dom_get_attribute(Document *,uint64_t,const char *);
extern int engine_dom_remove_attribute(Document *,uint64_t,const char *);
extern char *engine_dom_serialize(Document *,size_t *);
extern void *engine_dom_snapshot(Document *);
extern void engine_document_free(void *);
extern uint64_t engine_dom_get_element_by_id(Document *,const char *);
extern Document *engine_dom_parse(const char *,size_t);
static uint64_t element(Document *d,const char *name) { return engine_dom_create_element(d,name,strlen(name)); }
int main(void) {
    assert(sizeof(Node)==96 && sizeof(Document)==64);
    Document *d=engine_dom_new(); assert(d && d->root==1 && d->live==1);
    uint64_t custom=element(d,"MY-WIDGET"),span=element(d,"span"),text=engine_dom_create_text(d,"café 🌐",strlen("café 🌐")),comment=engine_dom_create_comment(d,"inert comment",13);
    assert(custom && span && text && comment && !strcmp(engine_dom_node(d,custom)->name,"my-widget"));
    assert(!engine_dom_insert_before(d,1,custom,0) && !engine_dom_insert_before(d,custom,text,0) && !engine_dom_insert_before(d,custom,comment,0) && !engine_dom_insert_before(d,custom,span,comment));
    Node *parent=engine_dom_node(d,custom);
    assert(parent->first==text && parent->last==comment && engine_dom_node(d,text)->next==span && engine_dom_node(d,span)->next==comment && engine_dom_node(d,comment)->previous==span);
    assert(!engine_dom_set_attribute(d,custom,"DATA-unknown","<&\" café",strlen("<&\" café")));
    assert(!engine_dom_set_attribute(d,custom,"hidden","",0));
    assert(!strcmp(engine_dom_get_attribute(d,custom,"data-UNKNOWN"),"<&\" café") && !strcmp(engine_dom_node(d,text)->value,"café 🌐"));
    assert(!engine_dom_set_attribute(d,custom,"data-unknown","changed",7) && !strcmp(engine_dom_get_attribute(d,custom,"DATA-unknown"),"changed"));
    assert(!engine_dom_remove_attribute(d,custom,"HIDDEN") && !engine_dom_get_attribute(d,custom,"hidden"));
    uint64_t version=d->version;
    assert(engine_dom_insert_before(d,span,custom,0)==-1 && d->version==version && parent->parent==1);
    assert(engine_dom_insert_before(d,custom,text,1)==-1 && d->version==version);
    assert(engine_dom_detach(d,1)==-1 && engine_dom_remove(d,1)==-1);
    assert(!engine_dom_detach(d,span) && engine_dom_node(d,span)->parent==0 && parent->first==text && engine_dom_node(d,text)->next==comment);
    assert(!engine_dom_insert_before(d,custom,span,text) && parent->first==span);
    assert(!engine_dom_set_text(d,text,"new + text",10) && !strcmp(engine_dom_node(d,text)->value,"new + text"));
    const char malformed[]={ (char)0xc0,(char)0x80 };
    assert(engine_dom_set_text(d,text,malformed,2)==-1 && !strcmp(engine_dom_node(d,text)->value,"new + text"));
    assert(!engine_dom_create_text(d,"a\0b",3) && !element(d,"bad name"));
    assert(!engine_dom_set_attribute(d,span,"id","target",6) && engine_dom_get_element_by_id(d,"target")==span);
    size_t length=0; char *snapshot=engine_dom_serialize(d,&length);
    assert(snapshot && length==strlen(snapshot) && strstr(snapshot,"<my-widget data-unknown=\"changed\"><span id=\"target\"></span>new + text<!--inert comment--></my-widget>")); free(snapshot);
    assert(!engine_dom_set_text(d,text,"<&\" café",strlen("<&\" café")));
    snapshot=engine_dom_serialize(d,&length); assert(snapshot && strstr(snapshot,"&lt;&amp;&quot; café")); free(snapshot);
    void *flow=engine_dom_snapshot(d); assert(flow && strstr(*(char **)flow,"<&\" café")); engine_document_free(flow);
    uint64_t image=element(d,"img"),detached=engine_dom_create_text(d,"detached",8);
    assert(image && detached && engine_dom_insert_before(d,image,detached,0)==-1 && !engine_dom_node(d,detached)->parent);
    assert(!engine_dom_remove(d,image) && !engine_dom_remove(d,detached));
    uint64_t last=d->allocated;
    assert(!engine_dom_remove(d,custom) && d->live==1 && d->bytes==0);
    assert(!engine_dom_node(d,custom) && !engine_dom_node(d,text) && !engine_dom_node(d,comment));
    assert(!engine_dom_get_element_by_id(d,"target"));
    assert(element(d,"new")>last); // tombstones are never reused
    engine_dom_free(d);
    d=engine_dom_new(); uint64_t owner=1;
    for(unsigned i=1;i<64;i++) { uint64_t child=element(d,"div"); assert(child && !engine_dom_insert_before(d,owner,child,0)); owner=child; }
    uint64_t overflow=element(d,"div"); version=d->version;
    assert(engine_dom_insert_before(d,owner,overflow,0)==-1 && d->version==version && engine_dom_node(d,overflow)->parent==0);
    assert(engine_dom_node(d,1)->height==64);
    engine_dom_free(d);
    d=engine_dom_new(); owner=element(d,"p");
    char *large=malloc(1048576); assert(large); memset(large,'x',1048576);
    assert(!engine_dom_set_attribute(d,owner,"a",large,1048576));
    assert(!engine_dom_set_attribute(d,owner,"b",large,1048576));
    assert(!engine_dom_set_attribute(d,owner,"c",large,1048576));
    assert(engine_dom_set_attribute(d,owner,"d",large,1048576)==-1 && !engine_dom_get_attribute(d,owner,"d"));
    assert(engine_dom_set_attribute(d,owner,"a",large,1048576)==-1 && strlen(engine_dom_get_attribute(d,owner,"a"))==1048576);
    free(large); engine_dom_free(d);
    const char *html="<!doctype html><html lang=EN><head><style>.hot{color:red}</style><script>if(a < 3) x = '&';</script></head><body><my-widget id=card data-x='a > b &amp; c' DATA-X=ignored><span id=label class=hot>café &lt; 🌐</span><!-- --></my-widget><textarea id=raw>A &amp; B <b>literal</b></textarea></body></html>";
    d=engine_dom_parse(html,strlen(html)); assert(d);
    uint64_t card=engine_dom_get_element_by_id(d,"card"),label=engine_dom_get_element_by_id(d,"label"),raw=engine_dom_get_element_by_id(d,"raw");
    assert(card && label && raw && !strcmp(engine_dom_node(d,card)->name,"my-widget"));
    assert(!strcmp(engine_dom_get_attribute(d,card,"DATA-X"),"a > b & c"));
    assert(!strcmp(engine_dom_node(d,engine_dom_node(d,label)->first)->value,"café < 🌐"));
    assert(!strcmp(engine_dom_node(d,engine_dom_node(d,raw)->first)->value,"A & B <b>literal</b>"));
    snapshot=engine_dom_serialize(d,&length); assert(snapshot && strstr(snapshot,"if(a < 3) x = '&';") && strstr(snapshot,"data-x=\"a &gt; b &amp; c\"")); free(snapshot);
    assert(!engine_dom_set_text(d,engine_dom_node(d,label)->first,"mutated 🌐",strlen("mutated 🌐")));
    flow=engine_dom_snapshot(d); assert(flow && strstr(*(char **)flow,"mutated 🌐") && !strstr(*(char **)flow,"if(a < 3)")); engine_document_free(flow);
    assert(engine_dom_get_element_by_id(d,"label")==label);
    engine_dom_free(d);
    d=engine_dom_parse("<div id=owner><b>old</b><!--comment--></div>",strlen("<div id=owner><b>old</b><!--comment--></div>"));assert(d);
    owner=engine_dom_get_element_by_id(d,"owner");uint64_t oldchild=engine_dom_node(d,owner)->first;
    version=d->version;
    assert(engine_dom_set_text_content(d,owner,malformed,2)==-1&&d->version==version&&engine_dom_node(d,oldchild));
    assert(!engine_dom_set_text_content(d,owner,"plain < café",strlen("plain < café")));
    assert(!engine_dom_node(d,oldchild));
    Node *replacement=engine_dom_node(d,engine_dom_node(d,owner)->first);
    assert(replacement&&replacement->type==2&&!replacement->next&&!strcmp(replacement->value,"plain < café"));
    assert(engine_dom_node(d,owner)->first==engine_dom_node(d,owner)->last);
    assert(!engine_dom_set_text_content(d,owner,"",0)&&!engine_dom_node(d,owner)->first);
    assert(engine_dom_set_text_content(d,1,"bad",3)==-1);
    engine_dom_free(d);
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(guard!=MAP_FAILED && !mprotect(guard+page,page,PROT_NONE));
    for(size_t k=0;k<=strlen(html);k++) { char *p=guard+page-k; memcpy(p,html,k); d=engine_dom_parse(p,k); if(d) { snapshot=engine_dom_serialize(d,&length); free(snapshot); engine_dom_free(d); } }
    munmap(guard,page*2);
    puts("PASS: assembly persistent nodes, stable handles, mutation, siblings, cycles, depth, UTF-8, attributes, removal and allocation budgets");
    return 0;
}
