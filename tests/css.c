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
extern char *engine_base_href(Doc *);
extern int engine_same_document(const char *,const char *);
extern int64_t engine_fragment_node(Doc *,const char *);
extern Doc *engine_dom_snapshot(void *);
extern void engine_interaction_transfer(Doc *,Doc *);
extern int engine_interaction_set(Doc *,uint64_t,uint64_t,uint64_t);
extern void engine_inline_boxes(Doc *);
extern void engine_flow_tree(Doc *);
extern void engine_float_tree(Doc *);
extern void engine_margin_reset(Doc *);
extern void engine_margin_tree(Doc *);
extern void engine_box_tree(Doc *,uint64_t);
extern void engine_position_tree(Doc *);
extern uint64_t engine_table_tracks(Doc *,uint64_t,uint64_t *);
extern uint64_t engine_grid_geometry(Doc *,uint64_t,uint64_t *);
typedef struct { int64_t width,height; } ReplacedSize;
extern ReplacedSize engine_replaced_size(Meta *,int64_t,int64_t,int64_t,int64_t);
extern uint64_t engine_box_metrics(Meta *,uint64_t);
extern char *engine_form_encode(const char *);
extern int css_media_match(const char *,const char *,uint64_t);
typedef struct {char *url,*media;uint64_t start,end,next;} Import;
extern int engine_css_import_next(const char *,size_t,size_t,Import *);
extern int css_nth_formula(const char *,const char *,int64_t);
extern uint64_t css_match(Doc *,uint64_t,const char *,const char *);
static Doc *parse(const char *s) { Doc *d=engine_parse(s,strlen(s)); assert(d); return d; }
static size_t id(Doc *d,const char *name) { for(size_t i=0;i<d->count;i++) if(d->meta[i].id && strcmp(d->meta[i].id,name)==0) return i; abort(); }
static uint64_t match(Doc *d,size_t i,const char *selector) { return css_match(d,i,selector,selector+strlen(selector)); }
static void margins(Doc *d) { engine_margin_reset(d); engine_box_tree(d,400); engine_flow_tree(d); engine_float_tree(d); engine_margin_tree(d); }
static int64_t top(Doc *d,const char *name) { return ((int64_t *)&d->meta[id(d,name)])[792/8]; }
static int64_t bottom(Doc *d,const char *name) { return ((int64_t *)&d->meta[id(d,name)])[800/8]; }
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
    // Extended declaration masks must cascade independently of the first 64 slots.
    d=parse("<style>div{white-space:pre;word-spacing:3px;letter-spacing:2px;vertical-align:top}#extended{white-space:nowrap!important;letter-spacing:4px}span{white-space:inherit;word-spacing:unset;letter-spacing:initial}</style><div id=extended style='white-space:normal;word-spacing:5px'><span id=extendedchild>x</span></div>");
    s=&d->meta[id(d,"extended")];
    assert(((int64_t *)s)[880/8]==-17 && ((int64_t *)s)[888/8]==2);
    assert(((int64_t *)s)[896/8]==5 && ((int64_t *)s)[904/8]==4);
    s=&d->meta[id(d,"extendedchild")];
    assert(((int64_t *)s)[880/8]==-16 && ((int64_t *)s)[888/8]==2);
    assert(((int64_t *)s)[896/8]==5 && ((int64_t *)s)[904/8]==0);
    engine_css_apply(d); assert(((int64_t *)s)[888/8]==2); engine_document_free(d);
    d=parse("<div id=constrained style='width:10px;min-width:120px;max-width:80px;height:500px;min-height:120px;max-height:80px;padding:10px;border:2px solid;box-sizing:border-box'>x</div><div id=autoheight style='max-height:50%'>x</div><div style='height:200px'><div id=percentlimit style='height:300px;max-height:50%'>x</div></div>");
    engine_box_tree(d,400); s=&d->meta[id(d,"constrained")];
    assert(((int64_t *)s)[768/8]==96 && ((int64_t *)s)[1776/8]==96);
    assert(((int64_t *)s)[1784/8]==96 && ((int64_t *)s)[1808/8]==56);
    assert(((int64_t *)&d->meta[id(d,"autoheight")])[1808/8]==-1);
    assert(((int64_t *)&d->meta[id(d,"percentlimit")])[1776/8]==100);
    engine_document_free(d);
    d=parse("<style>.preserve{white-space:pre}.nowrap{white-space:nowrap}.preline{white-space:pre-line}</style><div> normal   café 🌐 </div><div class=preserve> a  b\n c </div><div class=nowrap>long   unbroken</div><div class=preline>one   two\nthree  four</div>");
    l=engine_layout(d,0); assert(l && strstr(l->text,"normal café 🌐") && strstr(l->text," a  b\n c ") && strstr(l->text,"long unbroken") && strstr(l->text,"one two\nthree four"));
    for(size_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<div style='white-space:nowrap'>abcdefghijk</div><pre>lmnopqrstuv</pre>");
    l=engine_layout(d,8); assert(l && strstr(l->text,"abcdefghijk") && strstr(l->text,"lmnopqrstuv"));
    engine_layout_free(l); engine_document_free(d);
    d=parse("<img id=ratio style='min-width:120px;max-width:240px;max-height:80px'><img id=conflict style='min-width:200px;max-height:50px'>");
    engine_box_tree(d,400); s=&d->meta[id(d,"ratio")];
    ReplacedSize r=engine_replaced_size(s,400,200,-1,-1); assert(r.width==160 && r.height==80);
    r=engine_replaced_size(s,400,200,200,-1); assert(r.width==200 && r.height==80);
    r=engine_replaced_size(s,400,200,-1,30); assert(r.width==120 && r.height==30);
    r=engine_replaced_size(&d->meta[id(d,"conflict")],400,200,-1,-1); assert(r.width==200 && r.height==50);
    engine_document_free(d);
    d=parse("<div style='position:relative;height:300px;padding:10px'><div id=stretch style='position:absolute;top:10%;bottom:20px;padding:5px;border:2px solid;max-height:200px'>x</div></div>");
    engine_box_tree(d,400); engine_flow_tree(d); engine_position_tree(d);
    assert(((int64_t *)&d->meta[id(d,"stretch")])[1472/8]==200);
    engine_document_free(d);
    // Upstream WPT invalid negative max-width must not create a 1px box.
    FILE *wpt=fopen("tests/fixtures/wpt/max-width-001.xht","rb"); assert(wpt);
    char wptSource[8192];size_t wptLength=fread(wptSource,1,sizeof(wptSource)-1,wpt);assert(!ferror(wpt));fclose(wpt);wptSource[wptLength]=0;
    d=parse(wptSource);engine_box_tree(d,400);
    int wptBoxes=0;for(size_t k=0;k<d->count;k++)if(d->meta[k].tag&&!strcmp(d->meta[k].tag,"div")){assert(d->meta[k].value[22]==-1&&((int64_t *)&d->meta[k])[768/8]==0);wptBoxes++;}
    assert(wptBoxes==1);engine_document_free(d);
    d=parse("<div style='display:flex;width:400px;gap:20px'><div id=growcapped style='width:100px;max-width:120px;flex-grow:1'>a</div><div id=growrest style='width:100px;flex-grow:1'>b</div></div><div style='display:flex;width:200px'><div id=shrinkmin style='width:180px;min-width:140px'>a</div><div id=shrinkrest style='width:180px'>b</div></div><div style='display:flex;flex-direction:column;height:300px'><div id=heightcap style='height:50px;max-height:80px;flex-grow:1'>a</div><div id=heightrest style='height:50px;flex-grow:1'>b</div></div>");
    engine_box_tree(d,600);engine_flow_tree(d);
    assert(((int64_t *)&d->meta[id(d,"growcapped")])[1464/8]==120);
    assert(((int64_t *)&d->meta[id(d,"growrest")])[1464/8]==260);
    assert(((int64_t *)&d->meta[id(d,"shrinkmin")])[1464/8]==140);
    assert(((int64_t *)&d->meta[id(d,"shrinkrest")])[1464/8]==60);
    assert(((int64_t *)&d->meta[id(d,"heightcap")])[1472/8]==80);
    assert(((int64_t *)&d->meta[id(d,"heightrest")])[1472/8]==220);
    engine_document_free(d);
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
    assert(d->meta[link].value[0]==0x800080 && d->meta[link].value[7]==2 && d->meta[link].value[14]==-1);
    engine_document_free(d);
    d=parse("<style>.inline{display:inline-block}</style><center><div class=inline>Search field</div><br><span class=inline>Search buttons</span><br><br>Footer</center>");
    l=engine_layout(d,0); assert(l && strstr(l->text,"Search field") && strstr(l->text,"\nSearch buttons\n\nFooter"));
    for(size_t i=0;i<d->length;i++) assert(l->map[i]<=l->map[i+1]);
    engine_layout_free(l); engine_document_free(d);
    d=parse("<a id=button href=/signin style='display:inline-block;padding:10px 24px;background:blue;border-radius:100px;min-height:40px;min-width:80px;vertical-align:middle'>Sign <span>in 🌐</span></a><a id=afterbox href=/after>after café</a><a id=complex href=/complex style='background:red'><input></a>");
    s=&d->meta[id(d,"button")]; assert(s->value[24]==100 && s->value[25]==40 && ((int64_t *)s)[880/8]==-18 && s->value[27]==80);
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
    uint64_t tableTracks[64];memset(tableTracks,0xa5,sizeof(tableTracks));
    assert(engine_table_tracks(d,id(d,"table"),tableTracks)==2 && tableTracks[0]>0 && tableTracks[1]>0 && tableTracks[0]+tableTracks[1]<=500);
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
    d=parse("<style>p + p{color:red}p ~ a[data-kind^=news]{color:blue}p:not(.skip){font-weight:700}[data-label='a, b']{font-style:italic}</style><div><p id=sfirst data-label='a, b'>first</p><p id=snext class=skip>next</p><span>gap</span><a id=slink href=/x data-kind=newspaper>news</a></div><input id=scheck checked><input id=sdisabled disabled><div id=sempty></div>");
    assert(d->meta[id(d,"snext")].value[0]==0xff0000 && d->meta[id(d,"slink")].value[0]==255);
    assert(d->meta[id(d,"sfirst")].value[3]==700 && d->meta[id(d,"sfirst")].value[4]==1 && d->meta[id(d,"snext")].value[3]==400);
    assert(match(d,id(d,"sfirst"),"p:first-child") && match(d,id(d,"slink"),"a:last-child") && match(d,id(d,"scheck"),":checked") && match(d,id(d,"sdisabled"),":disabled") && match(d,id(d,"sempty"),":empty"));
    assert(match(d,id(d,"slink"),"[data-kind$=paper]") && match(d,id(d,"slink"),"[data-kind*=wsp]") && match(d,id(d,"sfirst"),"[data-label='A, B' i]"));
    engine_document_free(d);
    d=parse("<div id=grid style='display:grid;width:600px;grid-template-columns:100px 1fr 2fr;gap:10px;grid-auto-rows:50px'><div id=g1>a</div><div id=g2 style='grid-column:2 / span 2'>b</div><div id=g3 style='grid-row:2 / span 2'>c</div><div id=g4>d</div></div>");
    engine_box_tree(d,800); engine_flow_tree(d);
    assert(d->meta[id(d,"grid")].value[7]==4);
    uint64_t gridGeometry[82];memset(gridGeometry,0xa5,sizeof(gridGeometry));
    assert(engine_grid_geometry(d,id(d,"grid"),gridGeometry)==3);
    assert(gridGeometry[0]==3 && gridGeometry[1]>=2 && gridGeometry[2]==100 && gridGeometry[3]>100 && gridGeometry[4]>gridGeometry[3] && gridGeometry[18]>=50);
    uint64_t *gg1=(uint64_t *)&d->meta[id(d,"g1")],*gg2=(uint64_t *)&d->meta[id(d,"g2")],*gg3=(uint64_t *)&d->meta[id(d,"g3")];
    assert(gg1[1464/8]==100 && gg2[1464/8]==490 && gg2[1448/8]==2 && gg3[1456/8]==2 && gg3[1432/8]==1 && gg3[1472/8]>=110);
    engine_document_free(d);
    d=parse("<div style='display:grid;grid-template-columns:repeat(3,100px)'><div id=wide style='grid-column:span 2'>w</div><div id=next style='grid-column:span 2'>n</div><div id=last>l</div><div id=reserved style='grid-row:1;grid-column:3'>r</div></div>");
    engine_box_tree(d,400);engine_flow_tree(d);
    uint64_t *wide=(uint64_t *)&d->meta[id(d,"wide")],*next=(uint64_t *)&d->meta[id(d,"next")],*last=(uint64_t *)&d->meta[id(d,"last")],*reserved=(uint64_t *)&d->meta[id(d,"reserved")];
    assert(wide[1432/8]==0&&wide[1440/8]==0&&wide[1448/8]==2);
    assert(reserved[1432/8]==0&&reserved[1440/8]==2);
    assert(next[1432/8]==1&&next[1440/8]==0&&next[1448/8]==2);
    assert(last[1432/8]==1&&last[1440/8]==2);
    engine_document_free(d);
    d=parse("<div style='display:grid;grid-template-columns:repeat(3,100px)'><div id=wide style='grid-column:span 2'>w</div><div id=next style='grid-column:span 2'>n</div><div id=last>l</div></div>");
    engine_box_tree(d,400);engine_flow_tree(d);
    last=(uint64_t *)&d->meta[id(d,"last")];
    assert(last[1432/8]==1&&last[1440/8]==2); // do not backfill the hole in row 0
    engine_document_free(d);
    const char *formulas[]={"odd","even","2n+1","-n + 3","n","0n+2","+3","-2n+6","2 n+1","n+-1","n+","999999999999n","2n + 1 garbage"};
    for(size_t f=0;f<sizeof(formulas)/sizeof(*formulas);f++) for(int k=1;k<=8;k++) {
        int expected=f==0?k%2:f==1?!(k%2):f==2?k%2:f==3?k<=3:f==4?1:f==5?k==2:f==6?k==3:f==7?(k<=6&&!(k%2)):0;
        assert(css_nth_formula(formulas[f],formulas[f]+strlen(formulas[f]),k)==expected);
    }
    d=parse("<style>#nth > p:nth-child(2n+1){color:red}#nth > p:nth-of-type(2){font-weight:700}</style><div id=nth><!--comment--><p id=n1>1</p><x-unknown id=n2 hidden></x-unknown><p id=n3>3</p><p id=n4>4</p></div>");
    assert(match(d,id(d,"n1"),"p:nth-child(odd)")&&match(d,id(d,"n3"),"p:nth-child(3)"));
    assert(!match(d,id(d,"n3"),"p:nth-child(2)")&&match(d,id(d,"n3"),"p:nth-of-type(2)"));
    assert(match(d,id(d,"n3"),"p:nth-last-child(2)")&&match(d,id(d,"n3"),"p:nth-last-of-type(2)"));
    assert(match(d,id(d,"n2"),"x-unknown:nth-child(2)")&&!match(d,id(d,"n1"),"p:nth-child(2n+)"));
    assert(d->meta[id(d,"n1")].value[0]==0xff0000&&d->meta[id(d,"n3")].value[0]==0xff0000&&d->meta[id(d,"n3")].value[3]==700);
    engine_document_free(d);
    d=parse("<div><style>p{color:red}</style><!--ignored--><p id=afterstyle>x</p><p id=beforestyle>y</p><style></style></div><div id=white> </div><div id=comment><!--ignored--></div><div id=hiddenchild><x-hidden hidden></x-hidden></div>");
    assert(!match(d,id(d,"afterstyle"),":first-child")&&match(d,id(d,"afterstyle"),":nth-child(2)"));
    assert(!match(d,id(d,"beforestyle"),":last-child")&&!match(d,id(d,"white"),":empty"));
    assert(match(d,id(d,"comment"),":empty")&&!match(d,id(d,"hiddenchild"),":empty"));
    engine_document_free(d);
    d=parse("<div style='position:relative;width:300px;height:200px;padding:10px;border:5px solid'><div id=abs style='position:absolute;left:10px;right:20px;height:50%;padding:5px;border:2px solid'>x</div><div id=fixedsize style='position:fixed;width:50%;height:20px'>f</div><div id=hiddenabs style='display:none;position:absolute;width:100px'>h</div></div>");
    engine_box_tree(d,800);engine_flow_tree(d);engine_float_tree(d);engine_position_tree(d);
    uint64_t *absbox=(uint64_t *)&d->meta[id(d,"abs")],*fixedbox=(uint64_t *)&d->meta[id(d,"fixedsize")];
    assert(absbox[1472/8]==110&&absbox[1464/8]==276&&absbox[1704/8]==290&&absbox[1720/8]==1);
    assert(fixedbox[1464/8]==400&&fixedbox[1472/8]==20&&fixedbox[1720/8]==1);
    assert(!((uint64_t *)&d->meta[id(d,"hiddenabs")])[1720/8]);
    engine_document_free(d);
    d=parse("<style>#bg{background-image:url('photo.png');background-size:50% auto;background-position:center;background-repeat:no-repeat}#bg{background-image:none}#yes{background:no-repeat center url('logo.png');background-size:contain}</style><div id=bg>empty</div><div id=yes>image</div>");
    Meta *bg=&d->meta[id(d,"bg")],*yes=&d->meta[id(d,"yes")];
    assert(bg->value[26]==0 && !strcmp((char *)(uintptr_t)yes->value[26],"logo.png"));
    int64_t *background=(int64_t *)(uintptr_t)((uint64_t *)yes)[720/8];
    assert(background && background[0]==-11 && background[1]==-1 && background[2]==0x10000c350 && background[3]==0x10000c350 && background[4]==1);
    engine_css_apply(d); assert(!strcmp((char *)(uintptr_t)yes->value[26],"logo.png")); engine_document_free(d);
    // Every declaration prefix ends at a protected boundary.
    d=parse("<div style='border:1px solid black'><p id=ma style='height:10px;margin:0 0 30px'>A</p><p id=mb style='height:10px;margin:20px 0 0'>B</p></div>");
    margins(d); assert(bottom(d,"ma")==0 && top(d,"mb")==30);
    engine_box_metrics(&d->meta[id(d,"mb")],398); assert(top(d,"mb")==30);
    margins(d); assert(bottom(d,"ma")==0 && top(d,"mb")==30); engine_document_free(d);
    d=parse("<div style='border:1px solid black'><p id=ma style='height:10px;margin:0 0 30px'>A</p><p id=mb style='height:10px;margin:-10px 0 0'>B</p></div>");
    margins(d); assert(bottom(d,"ma")==0 && top(d,"mb")==20); engine_document_free(d);
    d=parse("<div style='border:1px solid black'><p id=ma style='height:10px;margin:0 0 -30px'>A</p><p id=mb style='height:10px;margin:-10px 0 0'>B</p></div>");
    margins(d); assert(bottom(d,"ma")==0 && top(d,"mb")==-30); engine_document_free(d);
    d=parse("<div style='border:1px solid black'><p id=ma style='height:10px;margin:0 0 30px'>A</p><div id=empty style='margin:10px 0 20px'></div><p id=mb style='height:10px;margin:15px 0 0'>B</p></div>");
    margins(d); assert(bottom(d,"ma")+top(d,"empty")+bottom(d,"empty")+top(d,"mb")==30 && ((uint64_t *)&d->meta[id(d,"empty")])[2040/8]); engine_document_free(d);
    d=parse("<div style='border:1px solid black'><div id=parent style='margin:20px 0 30px'><p id=inner style='height:10px;margin:40px 0 50px'>inside</p></div></div>");
    margins(d); assert(top(d,"parent")==40 && bottom(d,"parent")==50 && top(d,"inner")==0 && bottom(d,"inner")==0); engine_document_free(d);
    d=parse("<div style='border:1px solid black'><div id=parent style='padding:1px;margin:20px 0 30px'><p id=inner style='height:10px;margin:40px 0 50px'>inside</p></div></div>");
    margins(d); assert(top(d,"parent")==20 && bottom(d,"parent")==30 && top(d,"inner")==40 && bottom(d,"inner")==50); engine_document_free(d);
    d=parse("<div style='display:flex'><p id=ma style='height:10px;margin:0 0 30px'>A</p><p id=mb style='height:10px;margin:20px 0 0'>B</p></div>");
    margins(d); assert(bottom(d,"ma")==30 && top(d,"mb")==20); engine_document_free(d);
    // Every declaration prefix ends at a protected boundary.
    size_t page=(size_t)sysconf(_SC_PAGESIZE);
    char *guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(guard!=MAP_FAILED); assert(!mprotect(guard+page,page,PROT_NONE));
    const char *css="/*c*/color:#abc!important; font-family:'Times New Roman',serif; margin:1.5em 0 2px 3px; broken:url('x;z}');font-size:120%";
    for(size_t k=0;k<=strlen(css);k++) { char *p=guard+page-k; memcpy(p,css,k); uint64_t decl[78]={0}; css_declarations(p,p+k,decl); }
    const char *mediaLists[]={"handheld, all","print, screen","print, screen and (min-width:800px)","print, (min-width:800px)"};
    for(size_t i=0;i<4;i++) assert(css_media_match(mediaLists[i],mediaLists[i]+strlen(mediaLists[i]),900));
    const char *inactive="print, screen and (min-width:1000px)";
    assert(!css_media_match(inactive,inactive+strlen(inactive),900));
    const char *media="only screen and (min-width:767.95px) and (max-width:1200px)";
    for(size_t k=0;k<=strlen(media);k++) { char *p=guard+page-k; memcpy(p,media,k); (void)css_media_match(p,p+k,900); }
    const char *sides="border-width:1em 1.5em 2em .5em;border-style:solid;float:right;clear:both";
    for(size_t k=0;k<=strlen(sides);k++) { char *p=guard+page-k; memcpy(p,sides,k); uint64_t decl[78]={0}; css_declarations(p,p+k,decl); }
    const char *font="font:italic 700 18px/1.5 'Arial',sans-serif";
    for(size_t k=0;k<=strlen(font);k++) { char *p=guard+page-k; memcpy(p,font,k); uint64_t decl[78]={0}; css_declarations(p,p+k,decl); }
    const char *extendedDecl="white-space:pre-wrap!important;letter-spacing:-2px;word-spacing:3px;vertical-align:25%;max-height:80px";
    for(size_t k=0;k<=strlen(extendedDecl);k++) { char *p=guard+page-k;memcpy(p,extendedDecl,k);uint64_t decl[78]={0};css_declarations(p,p+k,decl); }
    const char *backgroundDecl="background:no-repeat center url('tile.png');background-size:50% auto;background-position:right bottom;background-repeat:repeat-x";
    for(size_t k=0;k<=strlen(backgroundDecl);k++){char *p=guard+page-k;memcpy(p,backgroundDecl,k);uint64_t decl[78]={0};css_declarations(p,p+k,decl);}
    // Guard the output ABI as well as input truncation: 624 bytes exactly.
    char *outputGuard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(outputGuard!=MAP_FAILED&&!mprotect(outputGuard+page,page,PROT_NONE));
    uint64_t *boundedDecl=(void *)(outputGuard+page-624);memset(boundedDecl,0,624);
    css_declarations(extendedDecl,extendedDecl+strlen(extendedDecl),boundedDecl);
    assert(boundedDecl[66]==15 && boundedDecl[67]==2);
    munmap(outputGuard,page*2);
    munmap(guard,page*2);
    char *encoded=engine_form_encode("café +&=🌐"); assert(encoded && !strcmp(encoded,"caf%C3%A9+%2B%26%3D%F0%9F%8C%90")); free(encoded);
    d=parse("<div id=ov1 style='overflow:hidden auto;overflow-x:clip'>a</div><div id=ov2 style='overflow-x:hidden;overflow:visible clip'>b</div><div id=ov3 style='overflow:hidden!important;overflow-y:visible'>c</div><div style='overflow:clip'><div id=ov4 style='overflow:inherit'>d</div></div>");
    uint64_t *ov=(uint64_t *)&d->meta[id(d,"ov1")];assert(ov[1952/8]==1&&ov[1960/8]==2);
    ov=(uint64_t *)&d->meta[id(d,"ov2")];assert(ov[1952/8]==0&&ov[1960/8]==3);
    ov=(uint64_t *)&d->meta[id(d,"ov3")];assert(ov[1952/8]==1&&ov[1960/8]==1);
    ov=(uint64_t *)&d->meta[id(d,"ov4")];assert(ov[1952/8]==3&&ov[1960/8]==3);
    engine_document_free(d);
    const char *imports="/* before */ @charset \"UTF-8\"; @import url(\"nested/a.css\") screen and (min-width: 300px); @import 'b.css'; div{color:red}@import 'too-late.css';";
    Import imp={0};
    assert(engine_css_import_next(imports,strlen(imports),0,&imp));
    assert(!strcmp(imp.url,"nested/a.css")&&!strcmp(imp.media,"screen and (min-width: 300px)"));
    size_t offset=imp.next;assert(imp.start<imp.end&&imp.end==imp.next);free(imp.url);free(imp.media);
    assert(engine_css_import_next(imports,strlen(imports),offset,&imp));
    assert(!strcmp(imp.url,"b.css")&&!strcmp(imp.media,""));offset=imp.next;free(imp.url);free(imp.media);
    assert(!engine_css_import_next(imports,strlen(imports),offset,&imp));
    const char *badimports[]={"@import url(x.css", "@import '' ;", "@import url(x y);", "@import \"x\" screen and (;", "@importurl(x);", "@import 'x' {color:red}","@import 'x\\y';"};
    for(size_t j=0;j<sizeof(badimports)/sizeof(*badimports);j++)assert(!engine_css_import_next(badimports[j],strlen(badimports[j]),0,&imp));
    guard=mmap(NULL,page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(guard!=MAP_FAILED&&!mprotect(guard+page,page,PROT_NONE));
    for(size_t k=0;k<=strlen(imports);k++){char *p=guard+page-k;memcpy(p,imports,k);if(engine_css_import_next(p,k,0,&imp)){free(imp.url);free(imp.media);}}
    munmap(guard,page*2);
    // Percent heights use a definite parent content height, never its width.
    d=parse("<div id=auto style='min-height:200px'><div id=indefinite style='height:50%;min-height:20%'>x</div></div><div id=parent style='height:200px;padding:10px;border:5px solid;box-sizing:border-box'><div id=half style='height:50%'><div id=quarter style='height:50%'>q</div></div><div id=minimum style='height:10px;min-height:30%'>m</div></div>");
    engine_box_tree(d,800);
    assert(((int64_t *)&d->meta[id(d,"auto")])[1776/8]==-1);
    assert(((int64_t *)&d->meta[id(d,"auto")])[1784/8]==200);
    assert(((int64_t *)&d->meta[id(d,"indefinite")])[1776/8]==-1);
    assert(((int64_t *)&d->meta[id(d,"indefinite")])[1784/8]==0);
    assert(((int64_t *)&d->meta[id(d,"parent")])[1776/8]==170);
    assert(((int64_t *)&d->meta[id(d,"half")])[1776/8]==85);
    assert(((int64_t *)&d->meta[id(d,"quarter")])[1776/8]==43);
    assert(((int64_t *)&d->meta[id(d,"minimum")])[1776/8]==51);
    engine_box_tree(d,300); // resizing width cannot change these heights
    assert(((int64_t *)&d->meta[id(d,"half")])[1776/8]==85);
    engine_document_free(d);
    d=parse("<div id=small style='height:10px;min-height:12px;box-sizing:border-box;padding:20px'>x</div>");
    engine_box_tree(d,400);
    assert(((int64_t *)&d->meta[id(d,"small")])[1776/8]==0);
    engine_document_free(d);
    d=parse("<style>#parent:hover{color:red}#child:active{color:green}#child:focus-visible{background:blue}input:checked{color:red}</style><div id=parent><span id=child>state</span></div><input id=check type=checkbox checked>");
    size_t state_parent=id(d,"parent"),state_child=id(d,"child"),check=id(d,"check");
    assert(engine_interaction_set(d,state_child,1,1));engine_css_apply(d);
    assert(d->meta[state_parent].value[0]==0xff0000);
    assert(!engine_interaction_set(d,state_child,1,1));
    Doc *state_snapshot=engine_dom_snapshot(*(void **)((char *)d+96));assert(state_snapshot);
    engine_interaction_transfer(d,state_snapshot);engine_css_apply(state_snapshot);
    assert(state_snapshot->meta[id(state_snapshot,"parent")].value[0]==0xff0000);
    engine_document_free(state_snapshot);
    assert(engine_interaction_set(d,state_child,14,14));engine_css_apply(d);
    assert(d->meta[state_child].value[0]==0x008000&&d->meta[state_child].value[1]==0x0000ff);
    assert(engine_interaction_set(d,check,48,16));engine_css_apply(d);
    assert(d->meta[check].value[0]!=0xff0000);
    engine_interaction_set(d,0,15,0);engine_css_apply(d);
    assert(d->meta[state_parent].value[0]!=0xff0000);
    engine_document_free(d);
    d=parse("<base href='/first/'><base href='/ignored/'><p id='café'>Unicode</p><a name=legacy>old anchor</a>");
    assert(!strcmp(engine_base_href(d),"/first/"));
    assert(engine_fragment_node(d,"café")== (int64_t)id(d,"café"));
    assert(engine_fragment_node(d,"legacy")>0&&engine_fragment_node(d,"")==0&&engine_fragment_node(d,"TOP")==0&&engine_fragment_node(d,"absent")==-1);
    assert(engine_same_document("https://host/path?q=1#old","https://host/path?q=1#new"));
    assert(!engine_same_document("https://host/path?q=1","https://host/path?q=2#new"));
    assert(!engine_same_document("https://host/path","https://host/path"));
    assert(engine_same_document("https://host/path#old","https://host/path"));
    engine_document_free(d);
    // CSS arithmetic retains containing-block percentages through reflow.
    d=parse("<div id=math style='width:calc(100% - 32px);min-width:min(200px, 50%);max-width:clamp(100px, 80%, 600px)'>math</div><div id=nest style='font-size:16px;width:calc(2 * (3em + 4px))'>nested</div><div id=invalid style='width:123px;width:calc(1px + 1);width:calc(10px / 0)'>invalid</div>");
    assert(engine_box_metrics(&d->meta[id(d,"math")],500)==400);
    assert(engine_box_metrics(&d->meta[id(d,"math")],1000)==600);
    assert(engine_box_metrics(&d->meta[id(d,"nest")],500)==104);
    assert(engine_box_metrics(&d->meta[id(d,"invalid")],500)==123);
    engine_document_free(d);
    d=parse("<div id=viewport style='width:50vw;height:25vh;min-width:10vmin;max-width:90vmax'></div><div id=pixelheight style='height:calc(10px + 20px)'></div><div id=percentheight style='height:calc(50% - 10px)'></div>");
    *(int64_t *)((char *)d->meta+856)=800;
    *(int64_t *)((char *)d->meta+1776)=600;
    engine_css_apply(d);engine_box_tree(d,500);
    assert(engine_box_metrics(&d->meta[id(d,"viewport")],500)==400);
    assert(*(int64_t *)((char *)&d->meta[id(d,"viewport")]+1776)==150);
    assert(*(int64_t *)((char *)&d->meta[id(d,"pixelheight")]+1776)==30);
    assert(*(int64_t *)((char *)&d->meta[id(d,"percentheight")]+1776)==-1);
    engine_document_free(d);
    d=parse("<div id=rounded style='width:calc(50% - 1px)'>fractional</div>");
    assert(engine_box_metrics(&d->meta[id(d,"rounded")],333)==166);
    engine_document_free(d);
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
