#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
typedef struct { uint64_t type,node; double x,y,w,h; uint64_t rest[10]; } Command;
typedef struct {uint64_t count,capacity;Command *commands;uint64_t overflow;} List;
extern List *engine_display_new(uint64_t);
extern void engine_display_free(List *);
extern Command *engine_display_append(List *);
extern int engine_display_intersects(Command *,double,double,double,double);
extern Command *engine_display_hit(List *,double,double);
int main(void) {
    _Static_assert(sizeof(Command)==128,"display command ABI");
    assert(!engine_display_new(0) && !engine_display_new(UINT64_MAX));
    List *l=engine_display_new(3);assert(l);
    Command *a=engine_display_append(l);a->type=1;a->x=10;a->y=20;a->w=30;a->h=40;
    assert(engine_display_intersects(a,0,0,11,21));
    assert(!engine_display_intersects(a,NAN,0,20,20));
    assert(!engine_display_intersects(a,40,20,2,2) && !engine_display_intersects(a,0,0,0,30));
    Command *b=engine_display_append(l);*b=*a;b->type=4;
    Command *c=engine_display_append(l);*c=*b;c->node=9;c->w=10;
    assert(engine_display_hit(l,11,21)==c && engine_display_hit(l,25,21)==b);
    assert(!engine_display_hit(l,40,21) && !engine_display_hit(l,25,60));
    assert(!engine_display_append(l) && l->overflow && l->count==3);
    engine_display_free(l);
    puts("PASS: assembly display-list capacity, clipping, paint order and hit regions");
}
