// Combine measured text/replaced runs through formatting boundaries. A private
// first-child/next-sibling index keeps the pass linear in the flow-node count.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _engine_intrinsic_tree
_engine_intrinsic_tree:
    ENTER
    mov x19, x0
    ldr x20, [x19, #24]
    ldr x21, [x19, #72]
    ldr x22, [x19, #16]
    mov x0, x20
    mov x1, #16
    bl _calloc
    cbz x0, Lintrinsic_done
    mov x23, x0
    mov x24, #1
Lintrinsic_index:
    cmp x24, x20
    b.hs Lintrinsic_reverse
    mov x9, #40
    madd x9, x24, x9, x22
    ldr x9, [x9, #8]
    cmp x9, x24
    b.hs Lintrinsic_index_next
    add x10, x23, x9, lsl #4
    ldr x11, [x10]
    str x24, [x10]
    add x10, x23, x24, lsl #4
    str x11, [x10, #8]
Lintrinsic_index_next:
    add x24, x24, #1
    b Lintrinsic_index
Lintrinsic_reverse:
    mov x24, x20
Lintrinsic_parent:
    cbz x24, Lintrinsic_free
    sub x24, x24, #1
    add x25, x21, x24, lsl #11
    mov x9, #40
    madd x9, x24, x9, x22
    ldr x9, [x9]
    cmp x9, #NODE_BUTTON
    b.eq Lintrinsic_parent
    cmp x9, #NODE_SELECT
    b.eq Lintrinsic_parent
    cmp x9, #NODE_TEXTAREA
    b.eq Lintrinsic_parent
    cmp x9, #NODE_SVG
    b.eq Lintrinsic_parent
    add x9, x23, x24, lsl #4
    ldr x26, [x9]
    cbz x26, Lintrinsic_parent
    mov x27, #0                    // current inline-line max-content
    mov x28, #0                    // largest line/block max-content
    str xzr, [sp, #144]            // min-content
    str xzr, [sp, #152]            // row-flex flag
    str xzr, [sp, #192]            // completed block heights
    str xzr, [sp, #200]            // inline line / row maximum height
    str xzr, [sp, #208]            // participating flex items
    ldr x9, [x25, #88]
    cmp x9, #3
    b.ne Lintrinsic_child
    ldr x9, [x25, #(32+CSS_DIRECTION*8)]
    tbnz x9, #0, Lintrinsic_child
    mov x9, #1
    str x9, [sp, #152]
Lintrinsic_child:
    cbz x26, Lintrinsic_store
    add x9, x21, x26, lsl #11
    ldr x10, [x9, #88]
    cmp x10, #1
    b.eq Lintrinsic_next
    ldr x13, [x9, #(1840+(CSS_POSITION-48)*8)]
    cmp x13, #2
    b.hs Lintrinsic_next
    ldr x13, [x25, #88]
    cmp x13, #3
    b.ne Lintrinsic_item_ready
    mov x0, x19
    mov x1, x26
    bl _engine_flow_item
    cbz x0, Lintrinsic_next
    ldr x13, [sp, #208]
    add x13, x13, #1
    str x13, [sp, #208]
    add x9, x21, x26, lsl #11
    ldr x10, [x9, #88]
Lintrinsic_item_ready:
    ldr x11, [x9, #FLOW_MIN_CONTENT]
    ldr x12, [x9, #FLOW_MAX_CONTENT]
    cmp x12, x11
    csel x12, x11, x12, lt
    // Authored widths constrain atomic/block children, not ordinary inline text.
    cmp x10, #2
    b.eq Lintrinsic_edges
    ldr x13, [x9, #144]
    tbnz x13, #63, Lintrinsic_edges
    ldr x11, [x9, #768]
    mov x12, x11
Lintrinsic_edges:
    // Collapsed inter-element whitespace has no independent line height.
    mov x13, #40
    madd x13, x26, x13, x22
    ldr x14, [x13]
    cmp x14, #NODE_TEXT
    b.ne Lintrinsic_height_content
    ldr x14, [x9, #888]
    cbz x14, Lintrinsic_height_whitespace
    cmp x14, #2
    b.ne Lintrinsic_height_content
Lintrinsic_height_whitespace:
    ldp x14, x15, [x13, #16]
    ldr x17, [x19]
Lintrinsic_height_whitespace_next:
    cmp x14, x15
    b.hs Lintrinsic_height_ready
    ldrb w16, [x17, x14]
    cmp w16, #32
    b.hi Lintrinsic_height_content
    add x14, x14, #1
    b Lintrinsic_height_whitespace_next
Lintrinsic_height_content:
    // Measure formatting children, never the aggregate descendant text range.
    // Absolute dropdowns must not inflate a header's natural cross size.
    ldr x13, [x9, #FLOW_INTRINSIC_H]
    ldr x14, [x9, #BOX_HEIGHT]
    cmp x14, #0
    csel x13, x14, x13, ge
    ldr x14, [x9, #824]
    add x13, x13, x14
    ldr x14, [x9, #832]
    add x13, x13, x14
    ldr x14, [x9, #BOX_BORDER_TOP]
    add x13, x13, x14
    ldr x14, [x9, #BOX_BORDER_BOTTOM]
    add x13, x13, x14
    ldr x14, [sp, #152]
    cbnz x14, Lintrinsic_height_inline
    ldr x14, [x25, #88]
    cmp x14, #3
    b.eq Lintrinsic_height_block
    cmp x10, #2
    b.eq Lintrinsic_height_inline
    cmp x10, #5
    b.eq Lintrinsic_height_inline
    mov x14, #40
    madd x14, x26, x14, x22
    ldr x14, [x14]
    cmp x14, #NODE_TEXT
    b.eq Lintrinsic_height_inline
    cmp x14, #NODE_INPUT
    b.eq Lintrinsic_height_inline
    cmp x14, #NODE_IMG
    b.eq Lintrinsic_height_inline
    cmp x14, #NODE_BUTTON
    b.eq Lintrinsic_height_inline
    cmp x14, #NODE_SVG
    b.eq Lintrinsic_height_inline
Lintrinsic_height_block:
    ldr x14, [sp, #192]
    ldr x15, [sp, #200]
    add x14, x14, x15
    add x14, x14, x13
    str x14, [sp, #192]
    str xzr, [sp, #200]
    b Lintrinsic_height_ready
Lintrinsic_height_inline:
    ldr x14, [sp, #200]
    cmp x14, x13
    csel x14, x13, x14, lt
    str x14, [sp, #200]
Lintrinsic_height_ready:
    cmp x10, #2
    b.eq Lintrinsic_unconstrained_inline
    stp x9, x10, [sp, #160]
    stp x11, x12, [sp, #176]
    mov x0, x9
    ldr x1, [x9, #848]
    bl _engine_width_limits
    ldp x9, x10, [sp, #160]
    ldp x11, x12, [sp, #176]
    cmp x11, x0
    csel x11, x0, x11, lt
    cmp x12, x0
    csel x12, x0, x12, lt
    tbnz x1, #63, Lintrinsic_unconstrained_inline
    cmp x11, x1
    csel x11, x1, x11, gt
    cmp x12, x1
    csel x12, x1, x12, gt
Lintrinsic_unconstrained_inline:
    ldr x13, [x9, #808]
    ldr x14, [x9, #816]
    add x13, x13, x14
    ldr x14, [x9, #BOX_BORDER_LEFT]
    add x13, x13, x14
    ldr x14, [x9, #BOX_BORDER_RIGHT]
    add x13, x13, x14
    ldr x14, [x9, #776]
    add x13, x13, x14
    ldr x14, [x9, #784]
    add x13, x13, x14
    add x11, x11, x13
    add x12, x12, x13
    ldr x13, [sp, #144]
    ldr x14, [sp, #152]
    cbnz x14, Lintrinsic_flex_child
    cmp x13, x11
    csel x13, x11, x13, lt
    str x13, [sp, #144]
    ldr x13, [x25, #88]
    cmp x13, #3
    b.eq Lintrinsic_block_width
    cmp x10, #2
    b.eq Lintrinsic_inline
    cmp x10, #5
    b.eq Lintrinsic_inline
    mov x13, #40
    madd x13, x26, x13, x22
    ldr x13, [x13]
    cmp x13, #NODE_TEXT
    b.eq Lintrinsic_inline
    cmp x13, #NODE_INPUT
    b.eq Lintrinsic_inline
    cmp x13, #NODE_IMG
    b.eq Lintrinsic_inline
    cmp x13, #NODE_BUTTON
    b.eq Lintrinsic_inline
    cmp x13, #NODE_SELECT
    b.eq Lintrinsic_inline
    cmp x13, #NODE_TEXTAREA
    b.eq Lintrinsic_inline
    cmp x13, #NODE_SVG
    b.eq Lintrinsic_inline
Lintrinsic_block_width:
    cmp x28, x27
    csel x28, x27, x28, lt
    cmp x28, x12
    csel x28, x12, x28, lt
    mov x27, #0
    b Lintrinsic_next
Lintrinsic_flex_child:
    add x13, x13, x11
    str x13, [sp, #144]
Lintrinsic_inline:
    add x27, x27, x12
Lintrinsic_next:
    add x9, x23, x26, lsl #4
    ldr x26, [x9, #8]
    b Lintrinsic_child
Lintrinsic_store:
    cmp x28, x27
    csel x28, x27, x28, lt
    ldr x9, [sp, #208]
    cmp x9, #2
    b.lo Lintrinsic_gaps_ready
    sub x9, x9, #1
    str x9, [sp, #216]
    ldr x0, [x25, #(32+CSS_GAP*8)]
    ldr x10, [sp, #152]
    cbz x10, Lintrinsic_column_gap
    ldr x9, [x25, #(32+CSS_COLUMN_GAP*8)]
    b Lintrinsic_gap_token
Lintrinsic_column_gap:
    ldr x9, [x25, #(32+CSS_ROW_GAP*8)]
Lintrinsic_gap_token:
    tbnz x9, #63, Lintrinsic_gap_resolve
    mov x0, x9
Lintrinsic_gap_resolve:
    // Percent gaps have no intrinsic contribution in an indefinite axis.
    mov x1, #0
    bl _engine_box_length
    ldr x9, [sp, #216]
    mul x0, x0, x9
    ldr x9, [sp, #152]
    cbz x9, Lintrinsic_gap_height
    ldr x9, [sp, #144]
    add x9, x9, x0
    str x9, [sp, #144]
    add x28, x28, x0
    b Lintrinsic_gaps_ready
Lintrinsic_gap_height:
    ldr x9, [sp, #192]
    add x9, x9, x0
    str x9, [sp, #192]
Lintrinsic_gaps_ready:
    ldr x9, [sp, #144]
    str x9, [x25, #FLOW_MIN_CONTENT]
    str x28, [x25, #FLOW_MAX_CONTENT]
    str x28, [x25, #FLOW_INTRINSIC_W]
    ldr x9, [sp, #192]
    ldr x10, [sp, #200]
    add x9, x9, x10
    str x9, [x25, #FLOW_INTRINSIC_H]
    b Lintrinsic_parent
Lintrinsic_free:
    mov x0, x23
    bl _free
Lintrinsic_done:
    LEAVE
