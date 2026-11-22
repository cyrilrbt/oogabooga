.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
// doc, normalized layout -> per-line ordinary inline backgrounds and borders.
.globl _mac_inline_fragments
_mac_inline_fragments:
    ENTER
    sub sp, sp, #64
    mov x19, x0
    mov x20, x1
    mov x21, #1
Lmac_fragment_node:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lmac_fragments_done
    ldr x22, [x19, #72]
    add x22, x22, x21, lsl #11
    ldr x9, [x22, #88]
    cmp x9, #2
    b.ne Lmac_fragment_next
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x21, x10, x9
    ldr x10, [x9]
    cmp x10, #1
    b.eq Lmac_fragment_next
    ldr x10, [x22, #192]
    ldr x11, [x22, #40]
    cmn x11, #1
    b.ne Lmac_fragment_measure
    cbz x10, Lmac_fragment_next
Lmac_fragment_measure:
    ldr x10, [x20, #16]
    ldp x11, x12, [x9, #16]
    ldr x23, [x10, x11, lsl #3]
    ldr x24, [x10, x12, lsl #3]
    cmp x23, x24
    b.hs Lmac_fragment_next
    mov x0, x19
    mov x1, x21
    mov x2, x23
    bl _mac_atomic_node_target
    mov x25, x0
    mov x26, x1
    sub x3, x24, x23
    mov x23, x2
    stp d0, d1, [sp, #32]
    mov x0, x25
    mov x4, #0
    MSG glyphRange
    mov x23, x0
    add x24, x0, x1
    str x23, [sp, #48]
Lmac_fragment_line:
    cmp x23, x24
    b.hs Lmac_fragment_next
    mov x0, x25
    mov x2, x23
    add x3, sp, #0
    MSG lineFragment
    ldp x9, x10, [sp, #0]
    add x9, x9, x10
    cmp x9, x24
    csel x27, x9, x24, lo
    cmp x27, x23
    b.ls Lmac_fragment_next
    LOAD x0, _mac_display_list
    bl _engine_display_append
    cbz x0, Lmac_fragments_done
    mov x28, x0
    mov x9, #1
    str x9, [x28]
    str x21, [x28, #8]
    ldr x9, [x22, #40]
    str x9, [x28, #72]
    ldr x9, [x22, #200]
    tbnz x9, #63, Lmac_fragment_border_default
    b Lmac_fragment_border_color
Lmac_fragment_border_default:
    ldr x9, [x22, #32]
Lmac_fragment_border_color:
    str x9, [x28, #80]
    mov x0, x22
    ldr x9, [sp, #48]
    cmp x23, x9
    cset x1, eq
    cmp x27, x24
    cset x2, eq
    add x3, x28, #88
    bl _engine_inline_edges
    mov x0, x25
    mov x2, x23
    sub x3, x27, x23
    mov x4, x26
    MSG glyphRect
    ldp d4, d5, [sp, #32]
    fadd d0, d0, d4
    fadd d1, d1, d5
    stp d0, d1, [x28, #16]
    stp d2, d3, [x28, #32]
    mov x23, x27
    b Lmac_fragment_line
Lmac_fragment_next:
    add x21, x21, #1
    b Lmac_fragment_node
Lmac_fragments_done:
    add sp, sp, #64
    LEAVE
