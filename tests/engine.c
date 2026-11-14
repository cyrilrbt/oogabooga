// Test harness only; parser, tree building, entity decoding, and wrapping are assembly.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
typedef struct { uint64_t type,parent,start,end; char *href; } Node;
typedef struct { char *text; uint64_t length; Node *nodes; uint64_t count; char *title; uint64_t capacity,title_length,reserved[3]; } Document;
typedef struct { char *text; uint64_t length; uint64_t *map; uint64_t lines; } Layout;
extern Document *engine_parse(const char *,size_t);
extern void engine_document_free(Document *);
extern Layout *engine_layout(Document *,size_t);
extern void engine_layout_free(Layout *);
static Document *parse(const char *html) { Document *d=engine_parse(html,strlen(html)); assert(d); return d; }
static void check(Document *d) {
    assert(d->count>=1 && d->count<=4096 && strlen(d->text)==d->length);
    assert(strlen(d->title)==d->title_length && d->title_length<=1024);
    for (uint64_t i=0;i<d->count;i++) {
        Node *n=&d->nodes[i]; assert(n->start<=n->end && n->end<=d->length);
        assert(i==0 || n->parent<i);
    }
}
int main(void) {
    Document *d=parse("<!doctype html><title>A &amp; B</title><style>secret</style><h1>Hello</h1><p>A &lt; B &amp; caf&#233; &#x1F310;.</p><!--hidden--><script>if(a<b)fake()</script><a data-note='fake href=bad >' HREF='../next?a=1&amp;b=2'>Next</a><pre>  a\n b</pre>");
    check(d); assert(strcmp(d->title,"A & B")==0);
    assert(strstr(d->text,"Hello") && strstr(d->text,"A < B & café 🌐."));
    assert(!strstr(d->text,"doctype") && !strstr(d->text,"secret") && !strstr(d->text,"fake") && !strstr(d->text,"hidden"));
    assert(strstr(d->text,"  a\n b"));
    int links=0;
    for(uint64_t i=0;i<d->count;i++) if(d->nodes[i].type==6) { assert(strcmp(d->nodes[i].href,"../next?a=1&b=2")==0); assert(d->nodes[i].end-d->nodes[i].start==4); links++; }
    assert(links==1);
    Layout *l=engine_layout(d,20); assert(l && l->lines>1); assert(strlen(l->text)==l->length);
    for(uint64_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<p>one two three four five</p>"); l=engine_layout(d,8);
    assert(l && strstr(l->text,"one two\nthree\nfour") && l->lines>=3);
    engine_layout_free(l); engine_document_free(d);
    d=parse("abcdefghijk🌐z"); l=engine_layout(d,8); assert(l);
    assert(l->map[d->length]==15); // 12 ASCII + one hard-wrap newline + emoji's second UTF-16 unit
    engine_layout_free(l); engine_document_free(d);
    d=parse("<script>not </scriptx> visible</script>safe<style>hide</style>tail"); assert(strcmp(d->text,"safetail")==0); engine_document_free(d);
    d=parse("<A title=other href=/x>ok</A><a href='javascript:bad()'>not executed</a>"); check(d); engine_document_free(d);
    d=parse("&#0;&#xD800;&#1114112;&bogus;1<2"); assert(strstr(d->text,"�") && strstr(d->text,"&bogus;") && strstr(d->text,"1<2")); engine_document_free(d);
    d=parse("<pre>a\r\nb</pre>"); l=engine_layout(d,20); assert(l && strstr(l->text,"a\nb")); engine_layout_free(l); engine_document_free(d);
    char title[2048]="<title>";
    for(int i=0;i<400;i++) strcat(title,"🌐");
    strcat(title,"</title>body");
    d=parse(title); check(d); assert(d->title_length==1024); engine_document_free(d);
    strcpy(title,"<title>x");
    for(int i=0;i<399;i++) strcat(title,"🌐");
    strcat(title,"</title>body");
    d=parse(title); check(d); assert(d->title_length==1021); engine_document_free(d);
    assert(!engine_parse(NULL,0)); assert(!engine_parse("",1048577));
    char deep[1024]=""; for(int i=0;i<70;i++) strcat(deep,"<div>"); assert(!engine_parse(deep,strlen(deep)));
    d=parse("bad\xff"); assert(!engine_layout(d,20)); assert(!engine_layout(d,0)); engine_document_free(d);
    // Every prefix ends at a protected page: catches assembly reads past truncated input.
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(guard!=MAP_FAILED);
    assert(mprotect(guard+page,page,PROT_NONE)==0);
    const char *sample="<!--unfinished--><a q='>' href='x&amp;y'><title>&#x1f310;</title><script>x<y</script><p>text &amp; 🌐</p>";
    for(size_t n=0;n<=strlen(sample);n++) {
        char *start=guard+page-n; memcpy(start,sample,n);
        d=engine_parse(start,n);
        if(d) { check(d); l=engine_layout(d,12); engine_layout_free(l); engine_document_free(d); }
    }
    munmap(guard,page*2);
    // Deterministic malformed-byte corpus; no C parser is involved.
    uint32_t state=12345;
    for(int round=0;round<1000;round++) {
        char input[256]; size_t n=(size_t)round%sizeof(input);
        for(size_t i=0;i<n;i++) { state=state*1664525u+1013904223u; input[i]=(char)(state>>24); }
        d=engine_parse(input,n);
        if(d) { check(d); l=engine_layout(d,16); engine_layout_free(l); engine_document_free(d); }
    }
    puts("PASS: assembly HTML tree, entities, links, hidden content, UTF-8 layout/maps, limits, guarded truncation, and malformed corpus");
    return 0;
}
