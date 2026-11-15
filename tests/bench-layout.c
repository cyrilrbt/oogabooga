// Benchmarks engine geometry only: no network, native drawing, or glyph shaping.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
extern void *engine_parse(const char *,size_t);
extern void engine_document_free(void *);
extern void engine_box_tree(void *,uint64_t);
extern void engine_flow_tree(void *);
extern void engine_float_tree(void *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
static void bench(const char *name,const char *html,size_t length) {
    void *doc=engine_parse(html,length); assert(doc);
    const int rounds=10000;
    for(int i=0;i<100;i++) {engine_box_tree(doc,1000);engine_flow_tree(doc);engine_float_tree(doc);}
    double start=now();
    for(int i=0;i<rounds;i++) {engine_box_tree(doc,1000);engine_flow_tree(doc);engine_float_tree(doc);}
    printf("%s: %.2f us/layout (%d iterations; geometry only)\n",name,(now()-start)*1e6/rounds,rounds);
    engine_document_free(doc);
}
int main(void) {
    FILE *f=fopen("tests/fixtures/acid1.html","rb"); assert(f);
    assert(!fseek(f,0,SEEK_END)); long n=ftell(f); assert(n>0); rewind(f);
    char *html=malloc((size_t)n+1); assert(html); assert(fread(html,1,(size_t)n,f)==(size_t)n); fclose(f);
    bench("Acid1",html,(size_t)n); free(html);
    char stress[20000]="<style>body{width:900px}.f{float:left;width:45px;height:25px;padding:2px;border:1px solid;margin:2px}</style>";
    for(int i=0;i<128;i++) strcat(stress,"<div class=f>box</div>");
    bench("128 floats",stress,strlen(stress));
    return 0;
}
