// Reserve one native attachment for a short, single-line styled anchor. Keeping
// source-byte -> UTF-16 maps here preserves all following links/form positions.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _engine_inline_boxes
_engine_inline_boxes:
    ldr x1, [x0, #16]
    ldr x2, [x0, #24]
    ldr x3, [x0, #72]
    ldr x4, [x0]
    ldr x5, [x0, #80]
    ldr x6, [x0, #8]
    mov x7, #0
Lbox_unmark:
    cmp x7, x6
    b.hs Lbox_nodes
    ldrb w8, [x5, x7]
    cmp w8, #4
    b.lo Lbox_unmark_next
    strb wzr, [x5, x7]
Lbox_unmark_next:
    add x7, x7, #1
    b Lbox_unmark
Lbox_nodes:
    mov x6, #0
Linline_box_next:
    cmp x6, x2
    b.hs Linline_box_done
    add x7, x3, x6, lsl #10
    str xzr, [x7, #872]
    mov x8, #40
    madd x8, x6, x8, x1
    ldr x9, [x8]
    cmp x9, #6                      // anchors only; nested controls stay in flow
    b.ne Linline_box_advance
    ldr x9, [x8, #32]
    cbz x9, Linline_box_advance
    ldr x9, [x7, #88]
    cmp x9, #1
    b.eq Linline_box_advance
    ldr x9, [x7, #40]
    cmn x9, #1
    b.ne Linline_box_candidate
    ldr x9, [x7, #192]
    ldr x10, [x7, #160]
    orr x9, x9, x10
    ldr x10, [x7, #168]
    orr x9, x9, x10
    ldr x10, [x7, #176]
    orr x9, x9, x10
    ldr x10, [x7, #184]
    orr x9, x9, x10
    ldr x10, [x7, #232]
    orr x9, x9, x10
    cbz x9, Linline_box_advance
Linline_box_candidate:
    ldr x9, [x8, #16]
    ldr x10, [x8, #24]
    sub x11, x10, x9
    cbz x11, Linline_box_advance
    cmp x11, #2048
    b.hi Linline_box_advance
    mov x11, x9
Linline_box_check:
    cmp x11, x10
    b.hs Linline_box_mark
    ldrb w12, [x5, x11]
    cmp w12, #1
    b.eq Linline_box_advance
    cmp w12, #4
    b.hs Linline_box_advance         // already inside another anchor
    ldrb w12, [x4, x11]
    cmp w12, #10
    b.eq Linline_box_advance
    cmp w12, #13
    b.eq Linline_box_advance
    cmp w12, #0xef
    b.ne Linline_box_check_next
    add x12, x11, #2
    cmp x12, x10
    b.hs Linline_box_check_next
    add x12, x4, x11
    ldrb w13, [x12, #1]
    cmp w13, #0xbf
    b.ne Linline_box_check_next
    ldrb w13, [x12, #2]
    cmp w13, #0xbc
    b.eq Linline_box_advance         // image/form attachment inside link
Linline_box_check_next:
    add x11, x11, #1
    b Linline_box_check
Linline_box_mark:
    mov x11, #1
    str x11, [x7, #872]
    mov w12, #4
    strb w12, [x5, x9]
    add x9, x9, #1
    mov w12, #5
Linline_box_hide_source:
    cmp x9, x10
    b.hs Linline_box_advance
    strb w12, [x5, x9]
    add x9, x9, #1
    b Linline_box_hide_source
Linline_box_advance:
    add x6, x6, #1
    b Linline_box_next
Linline_box_done:
    ret
