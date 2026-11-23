// Dense UTF-16 ownership map for native line layout. Source leaves are disjoint;
// separator slots inherit the following leaf's context. Construction is linear
// in document nodes plus mapped characters, with no per-line tree traversal.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.globl _mac_float_context_prepare
_mac_float_context_prepare:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x19, #8]
    ldr x10, [x20, #16]
    ldr x22, [x10, x9, lsl #3]
    CLASS NSMutableData
    MSG new
    mov x23, x0
    add x2, x22, #1
    lsl x2, x2, #3
    MSG setLength
    mov x0, x23
    MSG mutableBytes
    mov x24, x0
    mov x25, #0
Lcontext_map_node:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Lcontext_map_separators
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x25, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_TEXT
    b.eq Lcontext_map_leaf
    cmp x10, #NODE_IMG
    b.eq Lcontext_map_leaf
    cmp x10, #NODE_INPUT
    b.eq Lcontext_map_leaf
    cmp x10, #NODE_BR
    b.ne Lcontext_map_next
Lcontext_map_leaf:
    ldp x10, x11, [x9, #16]
    ldr x9, [x20, #16]
    ldr x10, [x9, x10, lsl #3]
    ldr x11, [x9, x11, lsl #3]
    cmp x11, x22
    csel x11, x22, x11, hi
    ldr x9, [x19, #72]
    add x9, x9, x25, lsl #11
    ldr x12, [x9, #FLOAT_CONTEXT]
Lcontext_map_fill:
    cmp x10, x11
    b.hs Lcontext_map_next
    str x12, [x24, x10, lsl #3]
    add x10, x10, #1
    b Lcontext_map_fill
Lcontext_map_next:
    add x25, x25, #1
    b Lcontext_map_node
Lcontext_map_separators:
    mov x25, x22
    mov x26, #0
Lcontext_map_reverse:
    cbz x25, Lcontext_map_install
    sub x25, x25, #1
    ldr x9, [x24, x25, lsl #3]
    cmp x9, #0
    csel x26, x26, x9, eq
    str x26, [x24, x25, lsl #3]
    b Lcontext_map_reverse
Lcontext_map_install:
    mov x0, x21
    ADDR x1, context_map_key
    mov x2, x23
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x23
    MSG release
    LEAVE

// container,local UTF-16 character index -> enclosing float context + 1 or 0.
.globl _mac_float_context_at
_mac_float_context_at:
    ENTER
    mov x19, x1
    ADDR x1, context_map_key
    bl _objc_getAssociatedObject
    cbz x0, Lcontext_at_none
    mov x20, x0
    MSG length
    lsr x0, x0, #3
    cmp x19, x0
    b.hs Lcontext_at_none
    mov x0, x20
    MSG bytes
    ldr x0, [x0, x19, lsl #3]
    LEAVE
Lcontext_at_none:
    mov x0, #0
    LEAVE
// Release a preceding document's map when the new document has no floats.
.globl _mac_float_context_clear
_mac_float_context_clear:
    ENTER
    ADDR x1, context_map_key
    mov x2, #0
    mov x3, #1
    bl _objc_setAssociatedObject
    LEAVE
.section __TEXT,__cstring,cstring_literals
context_map_key: .asciz "assemblyFloatContextMap"
