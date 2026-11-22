// Native box placement consumes the platform-independent intrinsic/flow plan.
.include "src/gtk/gtk.inc"
.text
// node,x,y,available content width -> outer height
.globl _gtk_layout_node
_gtk_layout_node:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _gtk_engine_node
    mov x23, x0
    mov x24, x1
    ldp x9, x10, [x23, #776]
    stp x9, x10, [sp, #192]
    ldp x9, x10, [x23, #792]
    stp x9, x10, [sp, #208]
    mov x0, x23
    mov x1, x22
    bl _engine_box_metrics
    ldp x9, x10, [sp, #192]
    stp x9, x10, [x23, #776]
    ldp x9, x10, [sp, #208]
    stp x9, x10, [x23, #792]
    ldr x9, [x23, #88]
    cmp x9, #1
    b.eq Llayout_hidden
    ldr x9, [x23, #776]
    add x20, x20, x9
    ldr x9, [x23, #792]
    add x21, x21, x9
    str x20, [x24, #GN_X]
    str x21, [x24, #GN_Y]
    ldr x25, [x23, #768]
    cmp x25, #0
    b.ge Llayout_width
    mov x25, x22
Llayout_width:
    ldr x9, [x23, #88]
    cmp x9, #5
    b.ne Llayout_auto_ready
    ldr x9, [x23, #144]
    tbz x9, #63, Llayout_auto_ready
    mov x0, x23
    ldr x1, [x23, #FLOW_MIN_CONTENT]
    ldr x2, [x23, #FLOW_MAX_CONTENT]
    mov x3, x22
    bl _engine_shrink_to_fit
    mov x25, x0
Llayout_auto_ready:
    ldr x9, [x23, #FLOW_OWNER]
    cbz x9, Llayout_width_ready
    ldr x9, [x23, #FLOW_WIDTH]
    cmp x9, #0
    csel x25, x9, x25, gt
Llayout_width_ready:
    str x25, [x23, #768]
    ldr x9, [x23, #88]
    cmp x9, #5
    b.ne Llayout_context_ready
    LOAD x0, _gtk_doc
    add x1, x19, #1
    bl _engine_context_reflow
Llayout_context_ready:
    ldr x9, [x23, #808]
    ldr x10, [x23, #BOX_BORDER_LEFT]
    add x9, x9, x10
    add x20, x20, x9
    str x20, [x24, #GN_CX]
    ldr x9, [x23, #824]
    ldr x10, [x23, #BOX_BORDER_TOP]
    add x9, x9, x10
    add x21, x21, x9
    str x21, [x24, #GN_CY]
    str x25, [x24, #GN_CW]
    mov x26, x21
    mov x27, #0 // current inline group
    str xzr, [sp, #168]
    mov x0, x19
    bl _gtk_engine_node
    mov x4, #0
    ldr x9, [x23, #88]
    cmp x9, #4
    b.eq Llayout_tracks_context
    ldr x9, [x2]
    cmp x9, #NODE_TABLE
    b.ne Llayout_prose_context
    mov x4, #1
Llayout_tracks_context:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x25
    bl _gtk_layout_tracks
    add x26, x21, x0
    b Llayout_no_group
Llayout_prose_context:
    mov x0, x19
    bl _gtk_engine_node
    ldr x9, [x2]
    cmp x9, #NODE_TEXT
    b.ne Llayout_children_begin
    mov x0, x19
    bl _gtk_group_new
    mov x27, x0
    mov x1, x19
    bl _gtk_group_append
Llayout_children_begin:
    ldr x9, [x23, #88]
    cmp x9, #3
    b.ne Llayout_children_ordered
    mov x0, x19
    bl _gtk_flex_children
Llayout_children_ordered:
    ldr x28, [x24, #GN_FIRST]
    mov x9, x20
    ldr x10, [x23, #(32+CSS_DIRECTION*8)]
    cmp x10, #2
    b.ne Llayout_row_cursor_ready
    add x9, x20, x25
Llayout_row_cursor_ready:
    str x9, [sp, #160] // row cursor
    str xzr, [sp, #168] // row height
    str xzr, [sp, #176] // row index
Llayout_child:
    cbz x28, Llayout_children_done
    mov x0, x28
    bl _gtk_engine_node
    ldr x9, [x0, #88]
    cmp x9, #1
    b.eq Llayout_next
    cmp x9, #2
    b.eq Llayout_inline
    cmp x9, #5
    b.eq Llayout_inline
    ldr x10, [x2]
    cmp x10, #NODE_TEXT
    b.eq Llayout_inline
    cmp x10, #NODE_BR
    b.eq Llayout_inline
    ldr x10, [x1, #GN_WIDGET]
    cbnz x10, Llayout_inline
    ldr x10, [x2]
    cmp x10, #NODE_IMG
    b.eq Llayout_inline
    cmp x10, #NODE_SVG
    b.eq Llayout_inline
    // Flex/grid direct items bypass inline flattening.
Llayout_block:
    str x0, [sp, #184]
    cbz x27, Llayout_block_place
    mov x0, x27
    mov x1, x20
    mov x2, x26
    mov x3, x25
    bl _gtk_group_finish
    add x26, x26, x0
    mov x27, #0
Llayout_block_place:
    ldr x10, [sp, #184]
    ldr x9, [x10, #FLOAT_ACTIVE]
    cmp x9, #1
    b.eq Llayout_float_item
    ldr x9, [x10, #(1840+(CSS_POSITION-48)*8)]
    cmp x9, #2
    b.hs Llayout_outflow_item
    ldr x9, [x10, #(32+CSS_CLEAR*8)]
    cbz x9, Llayout_no_clearance
    ldr x9, [x10, #FLOAT_GROUP]
    cbz x9, Llayout_no_clearance
    sub x9, x9, #1
    LOAD x11, _gtk_nodes
    add x11, x11, x9, lsl #8
    ldr x9, [x11, #GN_CY]
    ldr x11, [x10, #FLOAT_H]
    add x9, x9, x11
    cmp x26, x9
    csel x26, x9, x26, lt
Llayout_no_clearance:
    ldr x9, [x23, #88]
    cmp x9, #3
    b.eq Llayout_row_item
    cmp x9, #4
    b.eq Llayout_row_item
    mov x0, x28
    mov x1, x20
    mov x2, x26
    mov x3, x25
    bl _gtk_layout_node
    LOAD x9, _gtk_nodes
    add x9, x9, x28, lsl #8
    ldr x10, [x9, #GN_BASELINE]
    cbz x10, Llayout_child_baseline_ready
    ldr x11, [x9, #GN_Y]
    add x10, x10, x11
    ldr x11, [x24, #GN_Y]
    sub x10, x10, x11
    str x10, [x24, #GN_BASELINE]
Llayout_child_baseline_ready:
    add x26, x26, x0
    b Llayout_next
Llayout_float_item:
    ldr x9, [x10, #FLOW_OWNER]
    cbz x9, Llayout_next
    sub x9, x9, #1
    LOAD x11, _gtk_nodes
    add x11, x11, x9, lsl #8
    ldr x1, [x11, #GN_CX]
    ldr x2, [x11, #GN_CY]
    ldr x9, [x10, #FLOAT_X]
    add x1, x1, x9
    ldr x9, [x10, #FLOAT_Y]
    add x2, x2, x9
    mov x0, x28
    mov x3, x25
    bl _gtk_layout_node
    b Llayout_next
Llayout_outflow_item:
    mov x0, x28
    mov x1, x20
    mov x2, x26
    mov x3, x25
    bl _gtk_layout_node
    b Llayout_next
Llayout_row_item:
    ldr x10, [sp, #184]
    ldr x9, [x10, #FLOW_ROW]
    ldr x11, [sp, #176]
    cmp x9, x11
    b.eq Llayout_same_row
    str x9, [sp, #176]
    ldr x9, [sp, #168]
    add x26, x26, x9
    ldr x9, [x23, #(32+CSS_ROW_GAP*8)]
    cmp x9, #0
    b.ge Llayout_row_gap_ready
    ldr x9, [x23, #(32+CSS_GAP*8)]
Llayout_row_gap_ready:
    add x26, x26, x9
    str xzr, [sp, #168]
    mov x9, x20
    ldr x10, [x23, #(32+CSS_DIRECTION*8)]
    cmp x10, #2
    b.ne Llayout_next_row_cursor_ready
    add x9, x20, x25
Llayout_next_row_cursor_ready:
    str x9, [sp, #160]
Llayout_same_row:
    ldr x10, [sp, #184]
    ldr x1, [sp, #160]
    ldr x9, [x10, #FLOW_LEAD]
    ldr x11, [x23, #(32+CSS_DIRECTION*8)]
    cmp x11, #2
    b.eq Llayout_reverse_row_x
    add x1, x1, x9
    b Llayout_row_x_ready
Llayout_reverse_row_x:
    sub x1, x1, x9
    ldr x9, [x10, #FLOW_WIDTH]
    sub x1, x1, x9
    ldr x9, [x10, #808]
    sub x1, x1, x9
    ldr x9, [x10, #816]
    sub x1, x1, x9
    ldr x9, [x10, #BOX_BORDER_LEFT]
    sub x1, x1, x9
    ldr x9, [x10, #BOX_BORDER_RIGHT]
    sub x1, x1, x9
    ldr x9, [x10, #776]
    sub x1, x1, x9
    ldr x9, [x10, #784]
    sub x1, x1, x9
Llayout_row_x_ready:
    str x1, [sp, #160]
    mov x0, x28
    mov x2, x26
    ldr x9, [x23, #(32+CSS_DIRECTION*8)]
    tbz x9, #0, Llayout_row_y_ready
    ldr x9, [x10, #FLOW_BEFORE]
    add x2, x2, x9
Llayout_row_y_ready:
    mov x3, x25
    bl _gtk_layout_node
    ldr x9, [sp, #168]
    cmp x0, x9
    csel x9, x0, x9, gt
    str x9, [sp, #168]
    LOAD x9, _gtk_nodes
    add x9, x9, x28, lsl #8
    ldr x11, [x9, #GN_W]
    ldr x10, [sp, #184]
    ldr x12, [x10, #FLOW_TRAIL]
    ldr x9, [sp, #160]
    ldr x13, [x23, #(32+CSS_DIRECTION*8)]
    cmp x13, #2
    b.eq Llayout_reverse_row_advance
    add x9, x9, x11
    ldr x13, [x10, #776]
    add x9, x9, x13
    ldr x13, [x10, #784]
    add x9, x9, x13
    add x9, x9, x12
    b Llayout_row_advance_ready
Llayout_reverse_row_advance:
    sub x9, x9, x12
Llayout_row_advance_ready:
    str x9, [sp, #160]
    b Llayout_next
Llayout_inline:
    cbnz x27, Llayout_inline_ready
    ldr x9, [x2]
    cmp x9, #NODE_TEXT
    b.ne Llayout_inline_ready
    LOAD x0, _gtk_doc
    mov x1, x28
    bl _engine_flow_item
    cbz x0, Llayout_next
    mov x0, x28
    bl _gtk_engine_node
Llayout_inline_ready:
    ldr x9, [x23, #88]
    cmp x9, #3
    b.eq Llayout_block
    cmp x9, #4
    b.eq Llayout_block
    cbnz x27, Llayout_have_group
    mov x0, x19
    bl _gtk_group_new
    mov x27, x0
Llayout_have_group:
    mov x0, x27
    mov x1, x28
    bl _gtk_group_append
Llayout_next:
    LOAD x9, _gtk_nodes
    add x9, x9, x28, lsl #8
    ldr x28, [x9, #GN_NEXT]
    b Llayout_child
Llayout_children_done:
    cbz x27, Llayout_no_group
    mov x0, x27
    mov x1, x20
    mov x2, x26
    mov x3, x25
    bl _gtk_group_finish
    add x26, x26, x0
Llayout_no_group:
    ldr x9, [sp, #168]
    add x26, x26, x9
    sub x26, x26, x21
    ldr x9, [x23, #BOX_HEIGHT]
    cmp x9, #0
    csel x26, x9, x26, ge
    ldr x9, [x23, #BOX_MIN_HEIGHT]
    cmp x26, x9
    csel x26, x9, x26, lt
    str x26, [x24, #GN_CH]
    ldr x9, [x23, #808]
    ldr x10, [x23, #816]
    add x9, x9, x10
    add x25, x25, x9
    ldr x9, [x23, #BOX_BORDER_LEFT]
    ldr x10, [x23, #BOX_BORDER_RIGHT]
    add x9, x9, x10
    add x25, x25, x9
    str x25, [x24, #GN_W]
    ldr x9, [x23, #824]
    ldr x10, [x23, #832]
    add x9, x9, x10
    add x26, x26, x9
    ldr x9, [x23, #BOX_BORDER_TOP]
    ldr x10, [x23, #BOX_BORDER_BOTTOM]
    add x9, x9, x10
    add x26, x26, x9
    str x26, [x24, #GN_H]
    ldr x9, [x23, #792]
    ldr x10, [x23, #800]
    add x9, x9, x10
    add x0, x26, x9
    LEAVE
Llayout_hidden:
    mov x0, #0
    LEAVE
