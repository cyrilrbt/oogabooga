// Out-of-flow box sizing for absolute/fixed elements. The scene later applies
// inset translations to measured border boxes; these records do not exclude
// text lines and must never participate in float collision/clearance lists.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _engine_position_tree
.globl _engine_position_tree_impl
_engine_position_tree_impl:
    ENTER
    mov x19, x0
    ldr x20, [x19, #72]
    ldr x21, [x19, #24]
    ldr x24, [x19, #16]
    mov x22, #1
Lposition_next:
    cmp x22, x21
    b.hs Lposition_done
    add x23, x20, x22, lsl #11
    ldr x9, [x23, #88]
    cmp x9, #1
    b.eq Lposition_advance
    ldr x9, [x23, #696]
    cbnz x9, Lposition_advance
    ldr x9, [x23, #(1840+(CSS_POSITION-48)*8)]
    cmp x9, #2
    b.lo Lposition_advance
    mov x10, #40
    madd x10, x22, x10, x24
    ldr x11, [x10]
    cmp x11, #NODE_TEXT
    b.eq Lposition_advance
    cmp x11, #NODE_SHEET
    b.eq Lposition_advance
    cmp x11, #NODE_LINK
    b.eq Lposition_advance
    cmp x11, #NODE_HTML
    b.eq Lposition_advance
    cmp x11, #NODE_BODY
    b.eq Lposition_advance
    ldr x25, [x10, #8]
    add x10, x25, #1
    str x10, [x23, #FLOW_OWNER]
    cmp x9, #3
    b.ne Lposition_containing
    mov x25, #0
Lposition_containing:
    add x28, x20, x25, lsl #11
    cbz x25, Lposition_container_ready
    ldr x9, [x28, #(1840+(CSS_POSITION-48)*8)]
    cbnz x9, Lposition_container_ready
    mov x9, #40
    madd x9, x25, x9, x24
    ldr x25, [x9, #8]
    b Lposition_containing
Lposition_container_ready:
    add x9, x25, #1
    str x9, [x23, #FLOAT_CONTEXT]
    ldr x26, [x28, #768]
    cbz x25, Lposition_width_ready
    ldr x9, [x28, #808]
    add x26, x26, x9
    ldr x9, [x28, #816]
    add x26, x26, x9
Lposition_width_ready:
    mov x0, x23
    mov x1, x26
    bl _engine_box_metrics
    mov x0, x23
    ldr x1, [x28, #BOX_HEIGHT]
    tbnz x1, #63, Lposition_height_reference
    cbz x25, Lposition_height_reference
    ldr x9, [x28, #824]
    add x1, x1, x9
    ldr x9, [x28, #832]
    add x1, x1, x9
Lposition_height_reference:
    bl _engine_box_height
    ldr x27, [x23, #BOX_HEIGHT]
    tbz x27, #63, Lposition_height_ready
    ldr x27, [x23, #FLOW_INTRINSIC_H]
    ldr x9, [x28, #BOX_HEIGHT]
    tbnz x9, #63, Lposition_height_limits
    // Auto height stretches only in a definite containing block with both
    // vertical insets specified. Account for the child's complete outer box.
    cbz x25, Lposition_height_padding_ready
    ldr x10, [x28, #824]
    add x9, x9, x10
    ldr x10, [x28, #832]
    add x9, x9, x10
Lposition_height_padding_ready:
    str x9, [sp, #152]
    ldr x0, [x23, #(1840+(CSS_INSET_TOP-48)*8)]
    cmn x0, #1
    b.eq Lposition_height_limits
    ldr x10, [x23, #(1840+(CSS_INSET_BOTTOM-48)*8)]
    cmn x10, #1
    b.eq Lposition_height_limits
    mov x1, x9
    bl _engine_box_signed_length
    str x0, [sp, #160]
    ldr x0, [x23, #(1840+(CSS_INSET_BOTTOM-48)*8)]
    ldr x1, [sp, #152]
    bl _engine_box_signed_length
    ldr x27, [sp, #152]
    ldr x9, [sp, #160]
    sub x27, x27, x9
    sub x27, x27, x0
    ldr x9, [x23, #792]
    sub x27, x27, x9
    ldr x9, [x23, #800]
    sub x27, x27, x9
    ldr x9, [x23, #824]
    sub x27, x27, x9
    ldr x9, [x23, #832]
    sub x27, x27, x9
    ldr x9, [x23, #BOX_BORDER_TOP]
    sub x27, x27, x9
    ldr x9, [x23, #BOX_BORDER_BOTTOM]
    sub x27, x27, x9
Lposition_height_limits:
    ldr x9, [x23, #BOX_MAX_HEIGHT]
    tbnz x9, #63, Lposition_height_minimum
    cmp x27, x9
    csel x27, x9, x27, gt
Lposition_height_minimum:
    ldr x9, [x23, #BOX_MIN_HEIGHT]
    cmp x27, x9
    csel x27, x9, x27, lt
Lposition_height_ready:
    str x27, [x23, #FLOW_HEIGHT]
    ldr x9, [x23, #144]
    tbz x9, #63, Lposition_explicit_width
    ldr x0, [x23, #(1840+(CSS_INSET_LEFT-48)*8)]
    tbnz x0, #63, Lposition_shrink
    ldr x9, [x23, #(1840+(CSS_INSET_RIGHT-48)*8)]
    tbnz x9, #63, Lposition_shrink
    mov x1, x26
    bl _engine_box_signed_length
    str x0, [sp, #144]
    ldr x0, [x23, #(1840+(CSS_INSET_RIGHT-48)*8)]
    mov x1, x26
    bl _engine_box_signed_length
    ldr x9, [sp, #144]
    sub x26, x26, x9
    sub x26, x26, x0
    ldr x9, [x23, #776]
    sub x26, x26, x9
    ldr x9, [x23, #784]
    sub x26, x26, x9
    ldr x9, [x23, #808]
    sub x26, x26, x9
    ldr x9, [x23, #816]
    sub x26, x26, x9
    ldr x9, [x23, #BOX_BORDER_LEFT]
    sub x26, x26, x9
    ldr x9, [x23, #BOX_BORDER_RIGHT]
    sub x26, x26, x9
    b Lposition_content_width
Lposition_shrink:
    mov x0, x23
    ldr x1, [x23, #FLOW_MIN_CONTENT]
    ldr x2, [x23, #FLOW_INTRINSIC_W]
    mov x3, x26
    bl _engine_shrink_to_fit
    mov x26, x0
    b Lposition_content_width
Lposition_explicit_width:
    ldr x26, [x23, #768]
Lposition_content_width:
    mov x0, x23
    ldr x1, [x23, #848]
    mov x2, x26
    bl _engine_width_clamp
    mov x26, x0
    cmp x26, #0
    csel x26, xzr, x26, lt
    str x26, [x23, #FLOW_WIDTH]
    str x26, [x23, #768]
    ldr x9, [x23, #776]
    add x26, x26, x9
    ldr x9, [x23, #784]
    add x26, x26, x9
    ldr x9, [x23, #808]
    add x26, x26, x9
    ldr x9, [x23, #816]
    add x26, x26, x9
    ldr x9, [x23, #BOX_BORDER_LEFT]
    add x26, x26, x9
    ldr x9, [x23, #BOX_BORDER_RIGHT]
    add x26, x26, x9
    str x26, [x23, #FLOAT_W]
    ldr x9, [x23, #792]
    add x27, x27, x9
    ldr x9, [x23, #800]
    add x27, x27, x9
    ldr x9, [x23, #824]
    add x27, x27, x9
    ldr x9, [x23, #832]
    add x27, x27, x9
    ldr x9, [x23, #BOX_BORDER_TOP]
    add x27, x27, x9
    ldr x9, [x23, #BOX_BORDER_BOTTOM]
    add x27, x27, x9
    str x27, [x23, #FLOAT_H]
    mov x9, #1
    str x9, [x23, #FLOAT_ACTIVE]
    mov x9, #2
    str x9, [x20, #FLOAT_ACTIVE]
Lposition_advance:
    add x22, x22, #1
    b Lposition_next
Lposition_done:
    LEAVE
