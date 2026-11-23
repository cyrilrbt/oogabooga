// Parent-only paragraph separators inside an absolute/fixed context must not
// advance in-flow text. Keep UTF-16 indices stable and retain original child
// strings for shaping, selection and accessibility.
.include "src/mac/mac.inc"
.include "src/mac/atomic.inc"
.include "src/engine/css.inc"
.text
.globl _mac_atomic_flatten_parent
_mac_atomic_flatten_parent:
    ENTER
    mov x19, x0
    mov x20, x1
    add x9, x20, #AT_META
    ldr x9, [x9, #(1840+(CSS_POSITION-48)*8)]
    cmp x9, #2
    b.lo Lat_flat_done
    ADDR x0, atomic_mutable_string
    bl _sel_registerName
    mov x1, x0
    mov x0, x19
    bl _objc_msgSend
    mov x21, x0
    CLASS NSString
    ADDR x2, atomic_zero_space
    MSG stringUTF8
    mov x22, x0
    ldp x23, x24, [x20, #AT_START]
    add x24, x24, x23
Lat_flat_next:
    cmp x23, x24
    b.hs Lat_flat_done
    mov x0, x21
    mov x2, x23
    MSG characterAtIndex
    cmp x0, #10
    b.eq Lat_flat_replace
    cmp x0, #13
    b.ne Lat_flat_advance
Lat_flat_replace:
    ADDR x0, atomic_replace_range
    bl _sel_registerName
    mov x1, x0
    mov x0, x21
    mov x2, x23
    mov x3, #1
    mov x4, x22
    bl _objc_msgSend
Lat_flat_advance:
    add x23, x23, #1
    b Lat_flat_next
Lat_flat_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
atomic_mutable_string: .asciz "mutableString"
atomic_replace_range: .asciz "replaceCharactersInRange:withString:"
atomic_zero_space: .asciz "\342\200\213"
