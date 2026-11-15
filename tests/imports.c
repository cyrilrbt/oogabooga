#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct {char *url,*media;uint64_t start,end,next;} Import;
typedef struct {uint64_t q[16];} Sheet;
extern int engine_css_import_next(const char *,size_t,size_t,Import *);
extern char *engine_css_import_expand(Sheet *,size_t,size_t,size_t *);
static void source(Sheet *s,const char *text){s->q[2]=(uintptr_t)text;s->q[12]=strlen(text);}
int main(void){
    Sheet tree[3]={0};
    source(&tree[0],"@import 'one.css';p{color:red}");
    source(&tree[1],"@import 'two.css' screen;p{font-weight:700}");
    source(&tree[2],"p{color:blue}");
    Import a,b;assert(engine_css_import_next((char *)(uintptr_t)tree[0].q[2],tree[0].q[12],0,&a));
    assert(engine_css_import_next((char *)(uintptr_t)tree[1].q[2],tree[1].q[12],0,&b));
    tree[0].q[6]=2;tree[1].q[1]=1;tree[1].q[8]=a.start;tree[1].q[9]=a.end;tree[1].q[10]=(uintptr_t)a.media;
    tree[1].q[6]=3;tree[2].q[1]=2;tree[2].q[8]=b.start;tree[2].q[9]=b.end;tree[2].q[10]=(uintptr_t)b.media;
    size_t length;char *css=engine_css_import_expand(tree,3,0,&length);assert(css&&length==strlen(css));
    assert(strstr(css,"@media screen{\np{color:blue}}\n\np{font-weight:700}\np{color:red}"));free(css);
    tree[2].q[2]=0;css=engine_css_import_expand(tree,3,0,&length);assert(css&&!strstr(css,"color:blue")&&strstr(css,"color:red"));free(css);
    tree[2].q[9]=UINT64_MAX;assert(!engine_css_import_expand(tree,3,0,&length)&&length==0);
    tree[2].q[9]=b.end;tree[1].q[7]=2;assert(!engine_css_import_expand(tree,3,0,&length));
    tree[1].q[7]=0;tree[2].q[1]=1;assert(!engine_css_import_expand(tree,3,0,&length));
    assert(!engine_css_import_expand(tree,65,0,&length)&&!engine_css_import_expand(tree,3,3,&length));
    free(a.url);free(a.media);free(b.url);free(b.media);
    puts("PASS: assembly stylesheet import expansion, cascade order, media wrappers, missing children and malformed trees");
}
