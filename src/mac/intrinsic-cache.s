// Bounded document-session cache of native text advances. Exact attributed
// string keys include the resolved font, so CSS/font changes cannot reuse stale
// geometry. Cache the breakable minimum; nowrap selects the maximum separately.
.include "src/mac/mac.inc"
.text
.globl _mac_intrinsic_cache_reset
_mac_intrinsic_cache_reset:
    ENTER
    LOAD x0, intrinsic_cache
    MSG release
    STORE xzr, intrinsic_cache
    LEAVE
.globl _mac_intrinsic_cache_get
_mac_intrinsic_cache_get:
    mov x2, x0
    LOAD x0, intrinsic_cache
    SELECT x1, objectKey
    b _objc_msgSend
// key,width,height,minimum.
.globl _mac_intrinsic_cache_put
_mac_intrinsic_cache_put:
    ENTER
    mov x19, x0
    stp x1, x2, [sp, #144]
    str x3, [sp, #160]
    LOAD x0, intrinsic_cache
    cbnz x0, Lintrinsic_cache_ready
    CLASS NSMutableDictionary
    MSG new
    STORE x0, intrinsic_cache
Lintrinsic_cache_ready:
    mov x20, x0
    MSG count
    cmp x0, #8192
    b.hs Lintrinsic_cache_done
    CLASS NSData
    add x2, sp, #144
    mov x3, #24
    MSG dataBytesLength
    mov x2, x0
    mov x3, x19
    mov x0, x20
    MSG setObjectKey
Lintrinsic_cache_done:
    LEAVE
.section __DATA,__bss
.p2align 3
intrinsic_cache: .space 8
