// Test-only harness for the handwritten CSS parser, selector matcher and cascade.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
typedef struct { uint64_t type,parent,start,end; char *href; } Node;
typedef struct { char *id,*classes,*inline_style,*tag; int64_t value[24]; uint64_t priority[24]; char reserved[96]; char *attrs[22]; char tail[336]; } Meta;
typedef struct { char *text; uint64_t length; Node *nodes; uint64_t count; char *title; uint64_t capacity,title_length; char *css; uint64_t css_length; Meta *meta; unsigned char *hidden; uint64_t work; } Doc;
typedef struct { char *text; uint64_t length,*map,lines; } Layout;
extern Doc *engine_parse(const char *,size_t);
extern void engine_document_free(Doc *);
extern Layout *engine_layout(Doc *,size_t);
extern void engine_layout_free(Layout *);
extern void css_declarations(const char *,const char *,void *);
extern uint64_t engine_box_metrics(Meta *,uint64_t);
extern char *engine_form_encode(const char *);
extern uint64_t css_match(Doc *,uint64_t,const char *,const char *);
static Doc *parse(const char *s) { Doc *d=engine_parse(s,strlen(s)); assert(d); return d; }
static size_t id(Doc *d,const char *name) { for(size_t i=0;i<d->count;i++) if(d->meta[i].id && strcmp(d->meta[i].id,name)==0) return i; abort(); }
static uint64_t match(Doc *d,size_t i,const char *selector) { return css_match(d,i,selector,selector+strlen(selector)); }
int main(void) {
    _Static_assert(sizeof(Meta)==1024,"CSS ABI");
    Doc *d=parse("<html><body class='page'><p id='target' class='note loud' style='color:purple; margin: 1px 2px 3px 4px'>Hello <span id=child>child</span></p><p id=other>Other</p><style>/* comment */p {color:red;font-size:20px} .note{color:blue} #target{color:green} body.page p.note {font-weight:700} #other{color:#abc} @media print {p{display:none}}</style></body></html>");
    size_t a=id(d,"target"),b=id(d,"other"),child=id(d,"child");
    assert(d->meta[a].value[0]==0x800080); // inline beats id/class/type
    assert(d->meta[a].value[2]==20 && d->meta[a].value[3]==700);
    assert(d->meta[a].value[8]==1 && d->meta[a].value[13]==2 && d->meta[a].value[9]==3 && d->meta[a].value[12]==4);
    assert(d->meta[b].value[0]==0xaabbcc && d->meta[child].value[0]==0x800080);
    assert(match(d,a,"p.note#target")>match(d,a,"p.note"));
    assert(match(d,a,"body.page .loud") && match(d,a,".missing, #target"));
    assert(!match(d,a,".not-note") && !match(d,a,"p:hover") && match(d,a,"body > p"));
    engine_document_free(d);
    d=parse("<style>p{color:red!important;color:blue}#x{color:green} .x{color:yellow!important} #x{color:teal! important}</style><p id=x class=x style='color:purple'>x</p><p id=y style='color:orange!important'>y</p>");
    assert(d->meta[id(d,"x")].value[0]==0x008080);
    assert(d->meta[id(d,"y")].value[0]==0xffa500);
    engine_document_free(d);
    d=parse("<style>.a{color:red}.a{color:blue}*{font-style:italic}p{font-size:200px}</style><p id=x class=a>x</p>");
    assert(d->meta[id(d,"x")].value[0]==0x0000ff && d->meta[id(d,"x")].value[2]==72 && d->meta[id(d,"x")].value[4]==1);
    engine_document_free(d);
    d=parse("<style>html{font-size:20px}body{font-size:80%;line-height:1.5;color:green}p{font-size:1.5em}span{font-size:1rem;color:initial}#inherit{color:inherit}</style><html><body><p id=x>text<span id=initial>initial</span><span id=inherit>inherited</span></p></body></html>");
    Meta *s=&d->meta[id(d,"x")];
    assert(s->value[2]==24 && (uint32_t)s->value[10]==36 && s->value[0]==0x008000);
    assert(d->meta[id(d,"initial")].value[2]==20 && d->meta[id(d,"initial")].value[0]==-1);
    assert(d->meta[id(d,"inherit")].value[0]==0x008000);
    engine_document_free(d);
    d=parse("<style>.hide{display:none}.hide span{display:block}</style><p>before <span class=hide>SECRET 🌐<span>ALSO SECRET</span><a href=/bad>bad</a></span><a id=ok href=/ok>after café</a></p>");
    Layout *l=engine_layout(d,90); assert(l && !strstr(l->text,"SECRET") && !strstr(l->text,"bad"));
    assert(strstr(l->text,"after café"));
    Node *n=&d->nodes[id(d,"ok")]; assert(l->map[n->end]-l->map[n->start]==10);
    for(size_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<p id=x style='font-family: unknown, Arial, serif; color: bogus; font-size:-20px; line-height:normal; background:#123456; text-align:center; text-decoration:underline'>x</p>");
    s=&d->meta[id(d,"x")]; assert(s->value[11]==1 && s->value[1]==0x123456 && s->value[6]==2 && s->value[5]==1 && s->value[2]==14);
    engine_document_free(d);
    d=parse("<p id=x style='color:rgb(100%,0%,50%);background:rgb(10, 20, 300)'>x</p>");
    assert(d->meta[id(d,"x")].value[0]==0xff0080 && d->meta[id(d,"x")].value[1]==0x0a14ff);
    engine_document_free(d);
    d=parse("<style>body{color:red;background:#fff}html body p{font-size:20px}.hide{display:none}</style><p id=x>before</p><p class=hide>hidden</p><p>after</p>");
    assert(d->meta[id(d,"x")].value[0]==0xff0000 && d->meta[id(d,"x")].value[2]==20);
    l=engine_layout(d,90); assert(l && !strstr(l->text,"hidden") && !strstr(l->text,"\n\n\n"));
    engine_layout_free(l); engine_document_free(d);
    d=parse("<style>body{font-family:sans-serif}</style><pre id=pre> fixed </pre>");
    assert(d->meta[id(d,"pre")].value[11]==0); engine_document_free(d);
    char high_specificity[512]="<style>";
    for(int i=0;i<128;i++) strcat(high_specificity,"#x");
    strcat(high_specificity,"{color:red}</style><p id=x style='color:blue'>x</p>");
    d=parse(high_specificity); assert(d->meta[id(d,"x")].value[0]==0x0000ff); engine_document_free(d);
    d=parse("<div id=box style='width:320px;height:auto;padding:2px 3px 4px 5px;border-width:2px;border-color:blue'>x</div><input type=hidden name=token value=secret>");
    s=&d->meta[id(d,"box")]; assert(s->value[14]==320 && s->value[15]==-1 && s->value[16]==2 && s->value[17]==3 && s->value[18]==4 && s->value[19]==5 && s->value[20]==2 && s->value[21]==255);
    l=engine_layout(d,0); assert(l && !strstr(l->text,"￼")); engine_layout_free(l); engine_document_free(d);
    d=parse("<style>.box{width:80%;max-width:600px;box-sizing:border-box;padding:10px;border:2px solid #123456;margin:12px auto}.box>p{color:red}.box > p > span{font-weight:bold}</style><div class=box id=responsive><p id=direct>direct<span id=deep>deep</span></p><section><p id=indirect>nested</p></section></div>");
    s=&d->meta[id(d,"responsive")];
    assert(s->value[14]==(int64_t)(UINT64_C(1)<<32|80000) && s->value[22]==600 && s->value[23]==1 && s->value[20]==2 && s->value[21]==0x123456 && s->value[12]==-5);
    assert(engine_box_metrics(s,1000)==576 && ((uint64_t *)s)[97]==200 && ((uint64_t *)s)[98]==200);
    assert(engine_box_metrics(s,400)==296 && ((uint64_t *)s)[97]==40);
    assert(d->meta[id(d,"direct")].value[0]==0xff0000 && d->meta[id(d,"indirect")].value[0]==-1 && d->meta[id(d,"deep")].value[3]==700);
    assert(!match(d,id(d,"direct"),".box >> p") && !match(d,id(d,"direct"),">p") && !match(d,id(d,"direct"),".box >"));
    engine_document_free(d);
    d=parse("<p id=p style='width:50%;padding:5%;margin:10% 0;border:none'>percent</p>"); s=&d->meta[id(d,"p")];
    assert(engine_box_metrics(s,400)==200 && ((uint64_t *)s)[99]==40 && ((uint64_t *)s)[101]==20 && s->value[20]==0); engine_document_free(d);
    char *newline=engine_form_encode("a\nb\rc\r\nd"); assert(newline && !strcmp(newline,"a%0D%0Ab%0D%0Ac%0D%0Ad")); free(newline);
    // Every declaration prefix ends at a protected boundary.
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(guard!=MAP_FAILED); assert(!mprotect(guard+page,page,PROT_NONE));
    const char *css="/*c*/color:#abc!important; font-family:'Times New Roman',serif; margin:1.5em 0 2px 3px; broken:url('x;z}');font-size:120%";
    for(size_t k=0;k<=strlen(css);k++) { char *p=guard+page-k; memcpy(p,css,k); uint64_t decl[26]={0}; css_declarations(p,p+k,decl); }
    munmap(guard,page*2);
    char *encoded=engine_form_encode("café +&=🌐"); assert(encoded && !strcmp(encoded,"caf%C3%A9+%2B%26%3D%F0%9F%8C%90")); free(encoded);
    // Malformed sheets, unsupported at-rules and declaration data must remain bounded.
    const char *bad[]={"<style>p{color:red", "<style>/*", "<style>@import url('x;y');p{color:blue}", "<style>@media screen{{\"}\"}}p{color:green}", "<style>p{background:url('x}');color:red}</style><p>x</p>"};
    for(size_t i=0;i<sizeof(bad)/sizeof(*bad);i++) { d=parse(bad[i]); engine_document_free(d); }
    uint32_t seed=23;
    for(size_t round=0;round<300;round++) {
        char html[600]; memcpy(html,"<style>",7);
        size_t n=round%512;
        for(size_t j=0;j<n;j++) { seed=seed*1664525u+1013904223u; html[7+j]=(char)(seed>>24); }
        const char *tail="</style><p id=x>safe</p>";
        memcpy(html+7+n,tail,strlen(tail));
        d=engine_parse(html,7+n+strlen(tail));
        if(d) { l=engine_layout(d,40); engine_layout_free(l); engine_document_free(d); }
    }
    puts("PASS: assembly CSS selectors, cascade/important, inheritance, relative typography, margins, hidden Unicode/link ranges, and guarded malformed declarations");
    return 0;
}
