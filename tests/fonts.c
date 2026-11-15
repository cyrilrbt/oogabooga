#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
typedef struct {char *family,*source;uint64_t weight,italic,next;} Face;
typedef struct {char *url;uint64_t next;} Source;
extern int engine_css_font_face_next(const char *,size_t,size_t,Face *);
extern int engine_css_font_source_next(const char *,size_t,size_t,Source *);
extern uint64_t engine_font_family_register(const char *,size_t);
extern uint64_t engine_font_family_lookup(const char *,const char *);
extern void engine_font_family_reset(void);
extern int engine_font_validate(const void *,size_t);
extern void *engine_parse(const char *,size_t);
extern void engine_document_free(void *);
int main(void){
    FILE *fontFile=fopen("tests/fixtures/ooga-test.ttf","rb");assert(fontFile);
    unsigned char fontData[8192];size_t fontLength=fread(fontData,1,sizeof(fontData),fontFile);fclose(fontFile);
    assert(fontLength>1000&&engine_font_validate(fontData,fontLength));
    for(size_t n=0;n<fontLength;n++)assert(!engine_font_validate(fontData,n));
    unsigned char saved=fontData[20];fontData[20]=0xff;assert(!engine_font_validate(fontData,fontLength));fontData[20]=saved;
    engine_font_family_reset();
    uint64_t family=engine_font_family_register("Ooga Web",8);assert(family>=256&&engine_font_family_register("ooga web",8)==family);
    assert(engine_font_family_lookup("OOGA WEB",&"OOGA WEB"[8])==family);
    assert(!engine_font_family_register("bad\nname",8));
    const char *html="<p id=x style=\"font-family:'Missing', 'Ooga Web', sans-serif\">font</p>";
    uint64_t *doc=engine_parse(html,strlen(html));assert(doc);unsigned char *meta=(void *)(uintptr_t)doc[9];int found=0;
    for(uint64_t i=0;i<doc[3];i++){char *name=*(char **)(meta+i*2048);if(name&&!strcmp(name,"x")){assert(*(uint64_t *)(meta+i*2048+120)==family);found=1;}}
    assert(found);engine_document_free(doc);engine_font_family_reset();
    assert(!engine_font_family_lookup("Ooga Web",&"Ooga Web"[8]));
    const char *css="@import 'a.css';p{content:'@font-face{}'}@font-face{font-family:'Ooga Web';src:local('none'),url(a.woff2) format('woff2'),url('a.ttf') format('truetype');font-weight:700;font-style:italic}@font-face{font-family:Second;src:url(second.otf)}";
    Face face;assert(engine_css_font_face_next(css,strlen(css),0,&face));assert(!strcmp(face.family,"Ooga Web")&&face.weight==700&&face.italic==1);
    Source source;assert(engine_css_font_source_next(face.source,strlen(face.source),0,&source));assert(!strcmp(source.url,"a.ttf"));
    size_t offset=source.next;free(source.url);assert(!engine_css_font_source_next(face.source,strlen(face.source),offset,&source));
    offset=face.next;free(face.family);free(face.source);
    assert(engine_css_font_face_next(css,strlen(css),offset,&face)&&!strcmp(face.family,"Second")&&face.weight==400&&!face.italic);
    assert(engine_css_font_source_next(face.source,strlen(face.source),0,&source)&&!strcmp(source.url,"second.otf"));free(source.url);
    offset=face.next;free(face.family);free(face.source);assert(!engine_css_font_face_next(css,strlen(css),offset,&face));
    const char *commented="@font-face{font-family:/* semicolon ; */'Commented';src:/* also ; */url('semi;colon.ttf') format('truetype');}";
    assert(engine_css_font_face_next(commented,strlen(commented),0,&face)&&!strcmp(face.family,"Commented"));
    assert(engine_css_font_source_next(face.source,strlen(face.source),0,&source)&&!strcmp(source.url,"semi;colon.ttf"));free(source.url);free(face.family);free(face.source);
    const char *bad[]={"url(bad name.ttf)","url('x.ttf'", "url(x.ttf) garbage", "url(x.woff) format('woff')", "local('system')", "url('x\\\\y.ttf')"};
    for(size_t i=0;i<sizeof(bad)/sizeof(*bad);i++)assert(!engine_css_font_source_next(bad[i],strlen(bad[i]),0,&source));
    size_t page=(size_t)sysconf(_SC_PAGESIZE);char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(guard!=MAP_FAILED&&!mprotect(guard+page,page,PROT_NONE));
    for(size_t k=0;k<=strlen(css);k++){char *p=guard+page-k;memcpy(p,css,k);if(engine_css_font_face_next(p,k,0,&face)){free(face.family);free(face.source);}}
    const char *urls="local('x'),url('font.ttf') format('truetype'),url(next.otf)";
    for(size_t k=0;k<=strlen(urls);k++){char *p=guard+page-k;memcpy(p,urls,k);if(engine_css_font_source_next(p,k,0,&source))free(source.url);}
    munmap(guard,page*2);
    puts("PASS: assembly font-family aliases, font-face descriptors, source fallback/format policy and guarded truncation");
}
