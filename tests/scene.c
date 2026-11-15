// Test-only ABI views of the assembly scene. No renderer implementation here.
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef struct {uint64_t type,parent,start,end; char *href;} Node;
typedef struct {char *text;uint64_t length;Node *nodes;uint64_t count;void *title;uint64_t capacity,title_length;void *css;uint64_t css_length;unsigned char *meta;} Doc;
typedef struct {uint64_t q[64];} Record;
typedef struct {uint64_t count;Record *records;uint64_t *order,order_count;uint64_t rest[8];} Scene;
typedef struct {uint64_t q[16];} Command;
typedef struct {uint64_t count,capacity;Command *commands;uint64_t overflow;} List;
extern Doc *engine_parse(const char *,size_t);
extern void engine_document_free(Doc *);
extern Scene *engine_scene_new(Doc *,uint64_t,uint64_t);
extern void engine_scene_free(Scene *);
extern void engine_scene_update(Scene *,double,double);
extern void engine_scene_extents(Scene *);
extern int engine_scene_scroll(Scene *,uint64_t,double,double);
extern void engine_scene_copy_scroll(Scene *,Scene *);
extern int engine_scene_rect(Scene *,uint64_t,double *,uint64_t,double,double,double,double);
extern int engine_scene_set_box(Scene *,uint64_t,double,double,double,double);
extern List *engine_display_new(uint64_t);
extern Command *engine_display_append(List *);
extern void engine_display_free(List *);
extern int engine_scene_order(Scene *,List *);
extern Command *engine_scene_hit(Scene *,List *,double,double);
static uint64_t id(Doc *d,const char *name) {for(uint64_t i=0;i<d->count;i++){char *p=*(char **)(d->meta+i*2048);if(p&&!strcmp(p,name))return i;}assert(0);return 0;}
static double scalar(Scene *s,uint64_t i,size_t offset){double v;memcpy(&v,(unsigned char *)&s->records[i]+offset,8);return v;}
static uint64_t rank(Scene *s,uint64_t i){return s->records[i].q[208/8];}
int main(void) {
    const char *html="<div id=normal>n</div><div id=low style='position:relative;z-index:-2'><div id=trapped style='position:relative;z-index:999'>t</div></div><div id=auto style='position:relative'>a</div><div id=zero style='position:relative;z-index:0'>z</div><div id=high style='position:relative;z-index:4'>h</div><div id=opacity style='opacity:.5'>o</div><div id=fixed style='position:fixed'>f</div>";
    Doc *d=engine_parse(html,strlen(html));assert(d);
    assert(!engine_scene_new(NULL,100,100));
    assert(!engine_scene_new(d,0,100));assert(!engine_scene_new(d,100,UINT64_MAX));
    Scene *s=engine_scene_new(d,600,400);assert(s&&s->count==d->count);
    unsigned char seen[4096]={0};
    for(uint64_t i=0;i<s->count;i++){uint64_t r=rank(s,i);assert(r<s->count&&!seen[r]);seen[r]=1;}
    uint64_t normal=id(d,"normal"),low=id(d,"low"),trapped=id(d,"trapped"),automatic=id(d,"auto"),zero=id(d,"zero"),high=id(d,"high");
    assert(rank(s,low)<rank(s,trapped)&&rank(s,trapped)<rank(s,normal));
    assert(rank(s,normal)<rank(s,automatic)&&rank(s,automatic)<rank(s,zero)&&rank(s,zero)<rank(s,high));
    assert(s->records[id(d,"opacity")].q[24/8]&1);
    assert(s->records[id(d,"fixed")].q[24/8]&1);
    assert(!(s->records[automatic].q[24/8]&1)); // z-index:auto does not isolate descendants
    assert(engine_scene_set_box(s,normal,1,2,30,40));
    Record saved=s->records[normal];
    assert(!engine_scene_set_box(s,normal,INFINITY,2,30,40));
    assert(!engine_scene_set_box(s,normal,1,NAN,30,40));
    assert(!engine_scene_set_box(s,normal,1,2,-1,40));
    assert(!engine_scene_set_box(s,normal,1,2,30,INFINITY));
    assert(!memcmp(&saved,&s->records[normal],sizeof(saved)));
    assert(!engine_scene_set_box(s,s->count,1,2,3,4));
    List *l=engine_display_new(8);assert(l);
    uint64_t nodes[]={high,normal,low,automatic,normal,trapped,zero,normal};
    for(size_t i=0;i<8;i++){Command *c=engine_display_append(l);c->q[0]=1;c->q[1]=nodes[i];c->q[15]=i;}
    assert(engine_scene_order(s,l)&&s->order_count==8);
    uint64_t expected[]={2,5,1,4,7,3,6,0};
    for(size_t i=0;i<8;i++)assert(s->order[i]==expected[i]);
    for(size_t i=0;i<8;i++)assert(l->commands[i].q[15]==i); // pointers/records unchanged
    l->commands[0].q[1]=s->count;
    assert(!engine_scene_order(s,l)&&s->order_count==0);
    engine_display_free(l);engine_scene_free(s);engine_document_free(d);
    html="<div id=parent style='position:relative;left:10px;top:20px;border:5px solid'><div id=relative style='position:relative;left:25%;bottom:3px'><div id=leaf>x</div></div><div id=absolute style='position:absolute;right:10px;bottom:20px'>a</div><div id=fixed style='position:fixed;left:12px;top:14px'>f</div></div>";
    d=engine_parse(html,strlen(html));assert(d);s=engine_scene_new(d,600,400);assert(s);
    uint64_t parent=id(d,"parent"),relative=id(d,"relative"),leaf=id(d,"leaf"),absolute=id(d,"absolute"),fixed=id(d,"fixed");
    // Box borders are populated by the geometry pass before scene construction.
    s->records[parent].q[88/8]=5ULL|(5ULL<<16)|(5ULL<<32)|(5ULL<<48);
    assert(engine_scene_set_box(s,0,0,0,600,400));
    assert(engine_scene_set_box(s,parent,30,40,200,100));
    assert(engine_scene_set_box(s,relative,35,45,80,20));
    assert(engine_scene_set_box(s,leaf,35,45,10,10));
    assert(engine_scene_set_box(s,absolute,0,0,40,10));
    assert(engine_scene_set_box(s,fixed,0,0,20,10));
    engine_scene_update(s,0,0);
    assert(scalar(s,parent,128)==10&&scalar(s,parent,136)==20);
    assert(scalar(s,relative,128)==60&&scalar(s,relative,136)==17);
    assert(scalar(s,leaf,128)==60&&scalar(s,leaf,136)==17);
    assert(scalar(s,absolute,128)==185&&scalar(s,absolute,136)==125);
    assert(scalar(s,fixed,128)==12&&scalar(s,fixed,136)==14);
    engine_scene_update(s,100,200);
    assert(scalar(s,fixed,128)==112&&scalar(s,fixed,136)==214);
    assert(scalar(s,relative,128)==60); // updates never accumulate offsets
    // Clip the padding box, retain the border itself, and propagate to descendants.
    s->records[parent].q[64/8]=1;s->records[parent].q[72/8]=1;
    engine_scene_update(s,100,200);
    double rect[4];
    assert(engine_scene_rect(s,parent,rect,0,30,40,200,100));
    assert(rect[0]==45&&rect[1]==65&&rect[2]==190&&rect[3]==90);
    assert(engine_scene_rect(s,parent,rect,1,30,40,200,100));
    assert(rect[0]==40&&rect[1]==60&&rect[2]==200&&rect[3]==100);
    assert(engine_scene_rect(s,leaf,rect,0,0,0,200,200));
    assert(rect[0]==60&&rect[1]==65&&rect[2]==175&&rect[3]==90);
    assert(!engine_scene_rect(s,leaf,rect,0,-500,-500,10,10));
    assert(rect[2]==0&&rect[3]==0);
    assert(engine_scene_rect(s,fixed,rect,0,0,0,20,10));
    assert(rect[0]==112&&rect[1]==214&&rect[2]==20&&rect[3]==10);
    l=engine_display_new(2);assert(l);
    Command *link=engine_display_append(l);link->q[0]=4;link->q[1]=leaf;
    double linkbox[]={0,0,200,200};memcpy(&link->q[2],linkbox,sizeof(linkbox));
    Command *overlay=engine_display_append(l);overlay->q[0]=1;overlay->q[1]=fixed;
    double overlaybox[]={0,-140,20,10};memcpy(&overlay->q[2],overlaybox,sizeof(overlaybox));
    assert(engine_scene_order(s,l));
    assert(engine_scene_hit(s,l,65,70)==link);
    assert(!engine_scene_hit(s,l,42,70)); // outside parent's padding clip
    assert(engine_scene_hit(s,l,115,76)==overlay); // no click-through to lower link
    assert(engine_scene_hit(s,l,132,76)==link); // half-open overlay edge
    assert(!engine_scene_hit(s,l,NAN,70));
    engine_display_free(l);
    engine_scene_free(s);engine_document_free(d);
    html="<div id=scroll style='overflow:auto'><div id=content>content</div><div id=fixed style='position:fixed;left:0;top:0'>fixed</div></div>";
    d=engine_parse(html,strlen(html));assert(d);s=engine_scene_new(d,600,400);assert(s);
    uint64_t scroll=id(d,"scroll"),content=id(d,"content");fixed=id(d,"fixed");
    assert(engine_scene_set_box(s,0,0,0,600,400));
    assert(engine_scene_set_box(s,scroll,0,0,100,40));assert(engine_scene_set_box(s,content,0,0,300,200));assert(engine_scene_set_box(s,fixed,0,0,1000,1000));
    engine_scene_update(s,0,0);engine_scene_extents(s);
    assert(scalar(s,scroll,248)==200&&scalar(s,scroll,256)==160);
    assert(engine_scene_scroll(s,scroll,50,60));engine_scene_update(s,0,0);engine_scene_extents(s);
    assert(scalar(s,scroll,232)==50&&scalar(s,scroll,240)==60&&scalar(s,scroll,256)==160);
    assert(engine_scene_rect(s,content,rect,0,0,0,300,200)&&rect[0]==0&&rect[1]==0&&rect[2]==100&&rect[3]==40);
    Scene *copy=engine_scene_new(d,600,400);assert(copy);engine_scene_copy_scroll(copy,s);assert(scalar(copy,scroll,240)==60);engine_scene_free(copy);
    Doc *other=engine_parse(html,strlen(html));assert(other);copy=engine_scene_new(other,600,400);assert(copy);engine_scene_copy_scroll(copy,s);assert(scalar(copy,scroll,240)==0);engine_scene_free(copy);engine_document_free(other);
    assert(engine_scene_scroll(s,scroll,1000,1000));assert(!engine_scene_scroll(s,scroll,1,1));assert(!engine_scene_scroll(s,scroll,NAN,NAN));
    assert(engine_scene_scroll(s,scroll,-1000,-1000));assert(scalar(s,scroll,232)==0&&scalar(s,scroll,240)==0);
    engine_scene_free(s);engine_document_free(d);
    puts("PASS: assembly stacking contexts, trapped descendants, stable paint ordering, transforms, clips, hit occlusion and finite geometry");
}
