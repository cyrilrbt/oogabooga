// Test-only harness for the handwritten CSS parser, selector matcher and cascade.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
typedef struct { uint64_t type,parent,start,end; char *href; } Node;
typedef struct { char *id,*classes,*inline_style,*tag; int64_t value[48]; char reserved[96]; char *attrs[22]; char tail[336]; uint64_t priority[48]; char extra[640]; } Meta;
typedef struct { char *text; uint64_t length; Node *nodes; uint64_t count; char *title; uint64_t capacity,title_length; char *css; uint64_t css_length; Meta *meta; unsigned char *hidden; uint64_t work; } Doc;
typedef struct { char *text; uint64_t length,*map,lines; } Layout;
extern Doc *engine_parse(const char *,size_t);
extern void engine_document_free(Doc *);
extern Layout *engine_layout(Doc *,size_t);
extern void engine_layout_free(Layout *);
extern void css_declarations(const char *,const char *,void *);
extern void engine_css_apply(Doc *);
extern void engine_inline_boxes(Doc *);
extern void engine_flow_tree(Doc *);
extern void engine_float_tree(Doc *);
extern void engine_box_tree(Doc *,uint64_t);
extern uint64_t engine_box_metrics(Meta *,uint64_t);
extern char *engine_form_encode(const char *);
extern int css_media_match(const char *,const char *,uint64_t);
extern uint64_t css_match(Doc *,uint64_t,const char *,const char *);
static Doc *parse(const char *s) { Doc *d=engine_parse(s,strlen(s)); assert(d); return d; }
static size_t id(Doc *d,const char *name) { for(size_t i=0;i<d->count;i++) if(d->meta[i].id && strcmp(d->meta[i].id,name)==0) return i; abort(); }
static uint64_t match(Doc *d,size_t i,const char *selector) { return css_match(d,i,selector,selector+strlen(selector)); }
int main(void) {
    _Static_assert(sizeof(Meta)==2048,"CSS ABI");
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
    d=parse("<center id=center><p id=inside>centered</p></center><p id=after>after</p><p hidden id=hidden>SECRET</p><p id=font style='font:italic 700 18px/1.5 Arial,sans-serif'>font</p><p id=reset style='font-weight:bold;font-style:italic;font:14px Arial'>reset</p>");
    assert(d->meta[id(d,"center")].value[6]==2 && d->meta[id(d,"inside")].value[6]==2 && d->meta[id(d,"after")].value[6]==0);
    s=&d->meta[id(d,"font")]; assert(s->value[2]==18 && s->value[3]==700 && s->value[4]==1 && (uint32_t)s->value[10]==27 && s->value[11]==1);
    s=&d->meta[id(d,"reset")]; assert(s->value[3]==400 && s->value[4]==0);
    l=engine_layout(d,0); assert(l && !strstr(l->text,"SECRET")); engine_layout_free(l); engine_document_free(d);
    // A utility sheet larger than 64 KiB and 256 supported rules must reach its final rule.
    char *large=calloc(1,200000); assert(large); strcpy(large,"<style>");
    for(int i=0;i<800;i++) { char rule[180]; snprintf(rule,sizeof(rule),".utility%d{color:red}/* padding to exercise realistic stylesheet size ........................................................ */",i); strcat(large,rule); }
    strcat(large,"#last{color:blue}</style><p id=last>styled</p>");
    d=parse(large); assert(d->css_length>65536 && d->meta[id(d,"last")].value[0]==255); engine_document_free(d); free(large);
    d=parse("<style>.item{display:inline-block}</style><div><div class=item>Gmail</div><div class=item>Images</div></div><p>Footer</p><div class=item style='display:none'>HIDDEN</div>");
    l=engine_layout(d,0); assert(l && strstr(l->text,"Gmail Images") && !strstr(l->text,"HIDDEN") && strstr(l->text,"\nFooter"));
    for(size_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<style>#desktop{display:none}@media screen and (min-width:768px) and (max-width:1200px){#desktop{display:flex;color:red}@media(min-width:1000px){#desktop{color:blue}}}#after{color:green}@media print{#after{color:red}}.md\\:block{display:block}.w-1\\/2{width:50%}</style><p id=desktop>desktop</p><p id=after>after</p><p id=escaped class='md:block w-1/2'>escaped</p>");
    assert(d->meta[id(d,"desktop")].value[7]==3 && d->meta[id(d,"desktop")].value[0]==255 && d->meta[id(d,"after")].value[0]==0x008000);
    assert(d->meta[id(d,"escaped")].value[14]==(int64_t)(UINT64_C(1)<<32|50000));
    ((uint64_t *)d->meta)[107]=600; engine_css_apply(d);
    assert(d->meta[id(d,"desktop")].value[7]==1 && d->meta[id(d,"after")].value[0]==0x008000);
    ((uint64_t *)d->meta)[107]=900; engine_css_apply(d);
    assert(d->meta[id(d,"desktop")].value[7]==3 && d->meta[id(d,"desktop")].value[0]==0xff0000);
    engine_document_free(d);
    d=parse("<style>a:link{color:blue}a:visited{color:purple;width:1px;display:none}</style><a id=link href=/target>target</a><a id=plain>not a link</a>");
    size_t link=id(d,"link"),plain=id(d,"plain");
    assert(match(d,link,"a:link") && !match(d,link,"a:visited") && !match(d,plain,"a:link") && !match(d,plain,"a:visited"));
    assert(d->meta[link].value[0]==255);
    ((uint64_t *)&d->meta[link])[108]=1; engine_css_apply(d);
    assert(!match(d,link,"a:link") && match(d,link,"a:visited"));
    assert(d->meta[link].value[0]==0x800080 && d->meta[link].value[7]==0 && d->meta[link].value[14]==-1);
    engine_document_free(d);
    d=parse("<style>.inline{display:inline-block}</style><center><div class=inline>Search field</div><br><span class=inline>Search buttons</span><br><br>Footer</center>");
    l=engine_layout(d,0); assert(l && strstr(l->text,"Search field") && strstr(l->text,"\nSearch buttons\n\nFooter"));
    for(size_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<a id=button href=/signin style='display:inline-block;padding:10px 24px;background:blue;border-radius:100px;min-height:40px;min-width:80px;vertical-align:middle'>Sign <span>in 🌐</span></a><a id=afterbox href=/after>after café</a><a id=complex href=/complex style='background:red'><input></a>");
    s=&d->meta[id(d,"button")]; assert(s->value[24]==100 && s->value[25]==40 && s->value[26]==1 && s->value[27]==80);
    engine_inline_boxes(d); l=engine_layout(d,0); assert(l && strstr(l->text,"after café"));
    Node *button=&d->nodes[id(d,"button")],*afterbox=&d->nodes[id(d,"afterbox")];
    assert(l->map[button->end]-l->map[button->start]==1 && l->map[afterbox->end]-l->map[afterbox->start]==10);
    assert(((uint64_t *)&d->meta[id(d,"complex")])[109]==0);
    for(size_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<style>:root{--brand:#2468ac;--size:18px;--cycle:var(--cycle)} .card{--brand:purple;color:var(--brand);font-size:var(--size);padding:var(--space, 12px)} .child{--brand:green!important;--brand:red;color:var(--brand)}#fallback{color:var(--missing,var(--brand));width:var(--bad);font-weight:700}#cycle{color:var(--cycle,blue)}</style><div class=card id=card>card<span class=child id=vchild>child</span></div><p id=fallback>fallback</p><p id=cycle>cycle</p>");
    assert(d->meta[id(d,"card")].value[0]==0x800080 && d->meta[id(d,"card")].value[2]==18 && d->meta[id(d,"card")].value[16]==12);
    assert(d->meta[id(d,"vchild")].value[0]==0x008000 && d->meta[id(d,"fallback")].value[0]==0x2468ac && d->meta[id(d,"fallback")].value[3]==700);
    assert(d->meta[id(d,"cycle")].value[0]==255);
    engine_css_apply(d); assert(d->meta[id(d,"card")].value[0]==0x800080); engine_document_free(d);
    d=parse("<style>:root{--rgb:11 87 208;--alpha:.5}.modern{color:rgb(var(--rgb)/var(--alpha));background:#abcd;display:flex;flex-direction:column;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;flex:2 1 30%;fill:currentColor;stroke:none}</style><div id=modern class=modern>modern</div>");
    s=&d->meta[id(d,"modern")]; assert(s->value[0]==(int64_t)(UINT64_C(1)<<40 | UINT64_C(128)<<32 | 0x0b57d0));
    assert(s->value[1]==(int64_t)(UINT64_C(1)<<40 | UINT64_C(221)<<32 | 0xaabbcc));
    assert(s->value[7]==3 && s->value[28]==1 && s->value[29]==3 && s->value[30]==2 && s->value[31]==12 && s->value[32]==1);
    assert(s->value[33]==2000 && s->value[34]==1000 && s->value[35]==(int64_t)(UINT64_C(1)<<32 | 30000));
    engine_document_free(d);
    d=parse("<div id=flex style='display:flex;width:600px;gap:20px'><div id=fleft style='width:100px'>Left</div><div id=fgrow style='flex:1'>Middle</div><div id=fright style='width:100px'>Right</div></div><table id=table width=500 border=1 cellpadding=4><tr><td id=span rowspan=2>Spanning<td id=tright>Upper<tr><td id=bottom>Lower<tr><th id=wide colspan=2>Footer</table>");
    engine_box_tree(d,800); engine_flow_tree(d);
    assert(((uint64_t *)&d->meta[id(d,"fleft")])[1464/8]==100 && ((uint64_t *)&d->meta[id(d,"fgrow")])[1464/8]==360);
    assert(((uint64_t *)&d->meta[id(d,"fright")])[1440/8]==2);
    assert(((uint64_t *)&d->meta[id(d,"table")])[1496/8]==2);
    assert(((uint64_t *)&d->meta[id(d,"span")])[1456/8]==2 && ((uint64_t *)&d->meta[id(d,"bottom")])[1432/8]==1 && ((uint64_t *)&d->meta[id(d,"bottom")])[1440/8]==1);
    assert(((uint64_t *)&d->meta[id(d,"wide")])[1448/8]==2);
    l=engine_layout(d,0); assert(l && strstr(l->text,"Left\n") && strstr(l->text,"Middle\n")); engine_layout_free(l); engine_document_free(d);
    d=parse("<div id=wrap style='display:flex;width:220px;gap:10px;flex-wrap:wrap'><div id=w1 style=width:100px>one</div><div id=w2 style=width:100px>two</div><div id=w3 style=width:100px>three</div></div>");
    engine_box_tree(d,800); engine_flow_tree(d); assert(((uint64_t *)&d->meta[id(d,"w2")])[1432/8]==0 && ((uint64_t *)&d->meta[id(d,"w3")])[1432/8]==1); engine_document_free(d);
    d=parse("<div id=shrink style='display:flex;width:350px;gap:8px 10px'><div id=s1 style='width:220px'>one</div><div id=s2 style='width:220px'>two</div></div><div id=column style='display:flex;flex-direction:column;width:300px;height:200px;justify-content:space-between;align-items:center;gap:10px'><div id=c1 style='width:100px;height:40px'>one</div><div id=c2 style='width:100px;height:40px'>two</div></div>");
    engine_box_tree(d,800); engine_flow_tree(d);
    assert(d->meta[id(d,"shrink")].value[36]==8 && d->meta[id(d,"shrink")].value[37]==10);
    assert(((uint64_t *)&d->meta[id(d,"s1")])[1464/8]==170 && ((uint64_t *)&d->meta[id(d,"s2")])[1464/8]==170);
    assert(((uint64_t *)&d->meta[id(d,"c1")])[1480/8]==100 && ((uint64_t *)&d->meta[id(d,"c1")])[1584/8]==120);
    engine_document_free(d);
    d=parse("<style>a:visited{--private:1px;color:var(--brand,purple);padding:var(--private,40px)}a{width:200px}</style><a id=private href=/target>target</a>");
    ((uint64_t *)&d->meta[id(d,"private")])[108]=1; engine_css_apply(d);
    assert(d->meta[id(d,"private")].value[0]==0x800080 && d->meta[id(d,"private")].value[16]==0 && d->meta[id(d,"private")].value[14]==200);
    assert(((uint64_t *)&d->meta[id(d,"private")])[952/8]==0); engine_document_free(d);
    // Float placement is based on margin boxes, shared contexts and clearance.
    d=parse("<style>body{width:470px;font:10px Verdana}dt{float:left;width:50px;height:280px;padding:10px;border:5px solid}dd{float:right;width:340px;height:270px;padding:10px;border:10px solid;margin-left:10px}li{display:block;float:left;width:50px;height:90px;padding:10px;border:5px solid}#middle{width:140px;border:0;margin:0 10px}#second{width:100px;height:100px;border:0;margin:10px 0}blockquote{float:left;width:50px;height:90px;padding:10px 0;margin:10px 10px 10px 20px;border-width:10px 15px 20px 5px;border-style:solid}h1{float:left;width:100px;height:100px;margin:10px 0;padding:10px;font-size:10px}</style><dl><dt id=left>left</dt><dd id=right><ul><li id=first>one</li><li id=middle>two</li><li id=third>three</li><li id=second>four</li></ul><blockquote id=quote>quote</blockquote><h1 id=last>last</h1></dd></dl>");
    engine_box_tree(d,800); engine_flow_tree(d); engine_float_tree(d);
    uint64_t *fl=(uint64_t *)&d->meta[id(d,"left")], *fr=(uint64_t *)&d->meta[id(d,"right")];
    assert(fl[1688/8]==0 && fl[1696/8]==0 && fl[1704/8]==80 && fl[1712/8]==310);
    assert(fr[1688/8]==80 && fr[1696/8]==0 && fr[1704/8]==390 && fr[1712/8]==310);
    uint64_t *f1=(uint64_t *)&d->meta[id(d,"first")], *f2=(uint64_t *)&d->meta[id(d,"middle")], *f3=(uint64_t *)&d->meta[id(d,"third")], *f4=(uint64_t *)&d->meta[id(d,"second")];
    assert(f1[1688/8]==0 && f2[1688/8]==80 && f3[1688/8]==260);
    assert(f4[1688/8]==0 && f4[1696/8]==120);
    s=&d->meta[id(d,"quote")]; assert(s->value[20]==10 && s->value[45]==15 && s->value[46]==20 && s->value[47]==5);
    assert(((uint64_t *)s)[1688/8]==120 && ((uint64_t *)s)[1696/8]==120);
    l=engine_layout(d,0); assert(l && !strstr(l->text,"•")); engine_layout_free(l); engine_document_free(d);
    d=parse("<div style='width:200px'><p id=a style='float:left;width:60px;height:50px'>a</p><p id=b style='float:right;width:60px;height:80px'>b</p><p id=c style='float:left;clear:left;width:60px;height:10px'>c</p><p id=d style='float:right;clear:both;width:60px;height:10px'>d</p></div>");
    engine_box_tree(d,800); engine_flow_tree(d); engine_float_tree(d);
    assert(((uint64_t *)&d->meta[id(d,"c")])[1696/8]==50 && ((uint64_t *)&d->meta[id(d,"d")])[1696/8]==80);
    engine_document_free(d);
    d=parse("<style>html{background:blue}body{background:white}p{margin:0}form{display:inline}</style><dl><dt id=t>term<dd id=def>definition</dl><p>before</p><form><p>inside</p><p>after</p></form>");
    assert(d->nodes[id(d,"t")].parent==d->nodes[id(d,"def")].parent && d->meta[0].value[1]==255);
    l=engine_layout(d,0); assert(l && strstr(l->text,"before\ninside\nafter")); engine_layout_free(l); engine_document_free(d);
    char *newline=engine_form_encode("a\nb\rc\r\nd"); assert(newline && !strcmp(newline,"a%0D%0Ab%0D%0Ac%0D%0Ad")); free(newline);
    // Every declaration prefix ends at a protected boundary.
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(guard!=MAP_FAILED); assert(!mprotect(guard+page,page,PROT_NONE));
    const char *css="/*c*/color:#abc!important; font-family:'Times New Roman',serif; margin:1.5em 0 2px 3px; broken:url('x;z}');font-size:120%";
    for(size_t k=0;k<=strlen(css);k++) { char *p=guard+page-k; memcpy(p,css,k); uint64_t decl[50]={0}; css_declarations(p,p+k,decl); }
    const char *media="only screen and (min-width:767.95px) and (max-width:1200px)";
    for(size_t k=0;k<=strlen(media);k++) { char *p=guard+page-k; memcpy(p,media,k); (void)css_media_match(p,p+k,900); }
    const char *sides="border-width:1em 1.5em 2em .5em;border-style:solid;float:right;clear:both";
    for(size_t k=0;k<=strlen(sides);k++) { char *p=guard+page-k; memcpy(p,sides,k); uint64_t decl[50]={0}; css_declarations(p,p+k,decl); }
    const char *font="font:italic 700 18px/1.5 'Arial',sans-serif";
    for(size_t k=0;k<=strlen(font);k++) { char *p=guard+page-k; memcpy(p,font,k); uint64_t decl[50]={0}; css_declarations(p,p+k,decl); }
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
