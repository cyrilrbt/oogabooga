// Verify the assembly backend against native ARM instruction/ABI behavior.
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <limits.h>
typedef struct { uint64_t sum, difference; } Pair;
extern uint64_t backend_eight(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern Pair backend_pair(uint64_t,uint64_t);
extern uint64_t backend_flags(uint64_t,uint64_t,uint64_t);
extern uint64_t backend_carry(uint64_t,uint64_t);
extern uint64_t backend_cmn(uint64_t);
extern uint64_t backend_word(void);
extern uint64_t backend_shift(uint64_t,uint64_t,uint64_t,uint64_t);
extern int64_t backend_div(int64_t,int64_t);
extern uint64_t backend_udiv(uint64_t,uint64_t);
extern uint64_t backend_rev16(uint64_t);
extern uint64_t backend_reverse(uint64_t);
extern int64_t backend_convert(double);
extern double backend_max(double,double),backend_min(double,double);
extern int backend_unordered(double,double);
extern uint64_t backend_saved(uint64_t,uint64_t,uint64_t);
extern uint64_t backend_native(const char *,uint64_t),backend_tail(const char *);
extern double backend_fused(double,double,double),backend_sqrt(double),backend_floor(double);
extern uint64_t backend_insert(uint64_t,uint64_t);
int main(void) {
    assert(backend_fused(1+0x1p-27,1-0x1p-27,-1)==-0x1p-54);
    assert(backend_sqrt(81)==9 && isnan(backend_sqrt(-1)));
    assert(backend_floor(-1.2)==-2 && backend_floor(1.9)==1 && signbit(backend_floor(-0.0)));
    assert(backend_insert(0xffffffffffffffffULL,0x1234)==0xffffffffff1234ffULL);
    assert(backend_eight(1,2,3,4,5,6,7,8)==36);
    Pair pair=backend_pair(40,7);assert(pair.sum==47&&pair.difference==33);
    assert(backend_flags(1,2,0)==1&&backend_flags(2,1,UINT64_MAX)==0);
    assert(backend_carry(UINT64_MAX,1)==1&&backend_carry(1,2)==0);
    assert(backend_cmn(UINT64_MAX)==1&&backend_cmn(10)==0);
    assert(backend_word()==0&&backend_shift(3,4,0,17)==65);
    assert(backend_div(-13,3)==-4&&backend_div(INT64_MIN,-1)==INT64_MIN&&backend_div(15,0)==0);
    assert(backend_udiv(UINT64_MAX,3)==UINT64_MAX/3&&backend_udiv(15,0)==0);
    assert(backend_rev16(0x0102030405060708ULL)==0x0201040306050807ULL);
    assert(backend_reverse(0x0102030405060708ULL)==0x0807060504030201ULL);
    assert(backend_convert(13.8)==13&&backend_convert(-13.8)==-13);
    assert(backend_convert(NAN)==0&&backend_convert(INFINITY)==INT64_MAX&&backend_convert(-INFINITY)==INT64_MIN);
    assert(backend_max(10,20)==20&&backend_min(10,20)==10);
    assert(isnan(backend_max(NAN,1))&&isnan(backend_min(1,NAN)));
    assert(!signbit(backend_max(-0.0,0.0))&&signbit(backend_min(0.0,-0.0)));
    assert(backend_unordered(NAN,1)&&!backend_unordered(1,2));
    assert(backend_saved(1,2,3)==6&&backend_native("café",100)==105&&backend_tail("café")==5);
    puts("PASS: native assembly ABI, stack arguments, integer pairs, saved registers, flags, division, shifts, bytes, floating-point edges and libc calls");
}
