// Float margin-box placement in bounded formatting contexts. Native rendering
// consumes the resulting geometry; it does not decide float positions.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,index -> nearest enclosing float or body (formatting-context root).
float_context:
    ldr x2, [x0, #16]
    ldr x3, [x0, #72]
    mov x4, #40
    madd x5, x1, x4, x2
    ldr x1, [x5, #8]
Lfloat_context_parent:
    cbz x1, Lfloat_context_done
    madd x5, x1, x4, x2
    ldr x6, [x5]
    cmp x6, #NODE_BODY
    b.eq Lfloat_context_done
    add x6, x3, x1, lsl #11
    ldr x7, [x6, #(32+CSS_FLOAT*8)]
    cbnz x7, Lfloat_context_done
    ldr x7, [x6, #FLOW_OWNER]
    cbnz x7, Lfloat_context_done
    ldr x7, [x6, #88]
    cmp x7, #3
    b.hs Lfloat_context_done
    ldr x7, [x6, #(1840+(CSS_POSITION-48)*8)]
    cmp x7, #2
    b.hs Lfloat_context_done
    ldr x7, [x6, #(1840+(CSS_OVERFLOW_X-48)*8)]
    cmp x7, #1
    b.eq Lfloat_context_done
    cmp x7, #2
    b.eq Lfloat_context_done
    ldr x7, [x6, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    cmp x7, #1
    b.eq Lfloat_context_done
    cmp x7, #2
    b.eq Lfloat_context_done
    ldr x1, [x5, #8]
    b Lfloat_context_parent
Lfloat_context_done:
    mov x0, x1
    ret

.globl _engine_float_tree
.globl _engine_float_tree_impl
_engine_float_tree_impl:
    ENTER
    mov x19, x0
    ldr x20, [x19, #72]
    ldr x21, [x19, #24]
    mov x22, #0
Lfloat_reset:
    cmp x22, x21
    b.hs Lfloat_find_begin
    add x0, x20, x22, lsl #11
    str xzr, [x0, #NATIVE_HAS_FLOATS]
    add x0, x0, #FLOAT_CONTEXT
    mov x1, #0
    mov x2, #96
    bl _memset
    add x22, x22, #1
    b Lfloat_reset
Lfloat_find_begin:
    mov x22, #1
Lfloat_find:
    cmp x22, x21
    b.hs Lfloat_groups_begin
    add x23, x20, x22, lsl #11
    ldr x9, [x23, #88]
    cmp x9, #1
    b.eq Lfloat_find_next
    ldr x9, [x23, #(1840+(CSS_POSITION-48)*8)]
    cmp x9, #2
    b.hs Lfloat_find_next
    ldr x9, [x23, #(32+CSS_FLOAT*8)]
    cbz x9, Lfloat_find_next
    // Flex/grid items do not float.
    ldr x9, [x23, #FLOW_OWNER]
    cbnz x9, Lfloat_find_next
    mov x9, #2
    str x9, [x20, #FLOAT_ACTIVE]
    mov x0, x19
    mov x1, x22
    bl float_context
    add x24, x20, x0, lsl #11
    add x9, x0, #1
    str x9, [x23, #FLOAT_CONTEXT]
    ldr x10, [x24, #FLOAT_LAST]
    cbz x10, Lfloat_link_first
    add x10, x20, x10, lsl #11
    str x22, [x10, #FLOAT_NEXT]
    b Lfloat_link_last
Lfloat_link_first:
    str x22, [x24, #FLOAT_FIRST]
Lfloat_link_last:
    str x22, [x24, #FLOAT_LAST]
    ldr x9, [x19, #16]
    mov x10, #40
    madd x11, x22, x10, x9
    ldr x11, [x11, #8]
Lfloat_mark_ancestors:
    add x12, x20, x11, lsl #11
    mov x13, #1
    str x13, [x12, #NATIVE_HAS_FLOATS]
    cmp x12, x24
    b.eq Lfloat_mark_done
    madd x12, x11, x10, x9
    ldr x11, [x12, #8]
    tbnz x11, #63, Lfloat_mark_done
    b Lfloat_mark_ancestors
Lfloat_mark_done:
    ldr x9, [x19, #16]
    mov x10, #40
    madd x11, x22, x10, x9
    ldr x11, [x11, #8]
    ldr x12, [x24, #FLOAT_GROUP]
    cbz x12, Lfloat_group_store
    sub x12, x12, #1
    // Lowest common ancestor: parent indices precede child indices.
Lfloat_lca:
    cmp x11, x12
    b.eq Lfloat_group_store
    b.lo Lfloat_lca_right
    madd x13, x11, x10, x9
    ldr x11, [x13, #8]
    b Lfloat_lca
Lfloat_lca_right:
    madd x13, x12, x10, x9
    ldr x12, [x13, #8]
    b Lfloat_lca
Lfloat_group_store:
    add x11, x11, #1
    str x11, [x24, #FLOAT_GROUP]
Lfloat_find_next:
    add x22, x22, #1
    b Lfloat_find
Lfloat_groups_begin:
    mov x22, #1
Lfloat_groups:
    cmp x22, x21
    b.hs Lfloat_tree_done
    add x23, x20, x22, lsl #11
    ldr x9, [x23, #FLOAT_GROUP]
    cbz x9, Lfloat_group_next
    mov x0, x19
    mov x1, x22
    bl float_group
    mov x0, x19
    ldr x1, [x23, #FLOAT_GROUP]
    sub x1, x1, #1
    bl float_container_hint
Lfloat_group_next:
    add x22, x22, #1
    b Lfloat_groups
Lfloat_tree_done:
    // Non-floating clearance boxes refer to the same formatting-context anchor.
    mov x22, #1
Lfloat_clear_node:
    cmp x22, x21
    b.hs Lfloat_clear_done
    add x23, x20, x22, lsl #11
    ldr x9, [x23, #NATIVE_HAS_FLOATS]
    cbz x9, Lfloat_hint_ready
    mov x0, x19
    mov x1, x22
    bl float_container_hint
Lfloat_hint_ready:
    ldr x9, [x23, #(32+CSS_CLEAR*8)]
    ldr x10, [x23, #(32+CSS_FLOAT*8)]
    cbnz x10, Lfloat_clear_node_next
    mov x0, x19
    mov x1, x22
    bl float_context
    add x24, x0, #1
    str x24, [x23, #FLOAT_CONTEXT]
    add x9, x20, x0, lsl #11
    ldr x9, [x9, #FLOAT_GROUP]
    cbz x9, Lfloat_clear_node_next
    ldr x10, [x23, #FLOAT_FIRST]
    cbnz x10, Lfloat_clear_group_ready
    str x9, [x23, #FLOAT_GROUP]
Lfloat_clear_group_ready:
    ldr x10, [x23, #(32+CSS_CLEAR*8)]
    cbz x10, Lfloat_clear_node_next
    mov x25, #0
    sub x9, x24, #1
    add x9, x20, x9, lsl #11
    ldr x26, [x9, #FLOAT_FIRST]
Lfloat_clear_previous:
    cbz x26, Lfloat_clear_store
    cmp x26, x22
    b.hs Lfloat_clear_store
    add x9, x20, x26, lsl #11
    ldr x10, [x9, #FLOAT_CONTEXT]
    cmp x10, x24
    b.ne Lfloat_clear_previous_next
    ldr x10, [x9, #(32+CSS_FLOAT*8)]
    ldr x11, [x23, #(32+CSS_CLEAR*8)]
    tst x10, x11
    b.eq Lfloat_clear_previous_next
    ldr x10, [x9, #FLOAT_Y]
    ldr x11, [x9, #FLOAT_H]
    add x10, x10, x11
    cmp x25, x10
    csel x25, x10, x25, lt
Lfloat_clear_previous_next:
    add x9, x20, x26, lsl #11
    ldr x26, [x9, #FLOAT_NEXT]
    b Lfloat_clear_previous
Lfloat_clear_store:
    str x25, [x23, #FLOAT_H]
Lfloat_clear_node_next:
    add x22, x22, #1
    b Lfloat_clear_node
Lfloat_clear_done:
    LEAVE

// doc,context. Scratch: 128 float indices and the current band top.
float_group:
    ENTER
    sub sp, sp, #1040
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    add x9, x21, x20, lsl #11
    ldr x22, [x9, #FLOAT_GROUP]
    sub x22, x22, #1
    add x23, x21, x22, lsl #11
    ldr x24, [x23, #768]
    mov x25, #0                    // item count
    add x9, x21, x20, lsl #11
    ldr x26, [x9, #FLOAT_FIRST]
    str xzr, [sp, #1024]           // previous float top
Lfloat_collect:
    cbz x26, Lfloat_group_done
    cmp x25, #128
    b.hs Lfloat_group_done
    add x27, x21, x26, lsl #11
    ldr x9, [x27, #FLOAT_CONTEXT]
    add x10, x20, #1
    cmp x9, x10
    b.ne Lfloat_collect_next
    // The common containing block supplies widths. Intervening ordinary blocks
    // do not establish a new float formatting context.
    mov x0, x27
    mov x1, x24
    bl _engine_box_metrics
    ldr x28, [x27, #768]
    ldr x9, [x27, #144]
    tbz x9, #63, Lfloat_size_height
    ldr x28, [x27, #FLOW_INTRINSIC_W]
    mov x9, #1
    cmp x28, #1
    csel x28, x9, x28, lt
    cmp x28, x24
    csel x28, x24, x28, gt
Lfloat_size_height:
    str x28, [x27, #FLOW_WIDTH]
    str x28, [x27, #768]
    ldr x0, [x27, #BOX_HEIGHT]
    tbnz x0, #63, Lfloat_auto_height
    b Lfloat_height_ready
Lfloat_auto_height:
    ldr x0, [x27, #FLOW_INTRINSIC_H]
    ldr x9, [x27, #FLOW_INTRINSIC_W]
    add x9, x9, x28
    sub x9, x9, #1
    udiv x9, x9, x28
    mov x10, #1
    cmp x9, #1
    csel x9, x10, x9, lt
    mul x0, x0, x9
Lfloat_height_ready:
    str x0, [x27, #FLOW_HEIGHT]
    ldr x9, [x27, #776]
    add x28, x28, x9
    ldr x9, [x27, #784]
    add x28, x28, x9
    ldr x9, [x27, #808]
    add x28, x28, x9
    ldr x9, [x27, #816]
    add x28, x28, x9
    ldr x9, [x27, #BOX_BORDER_LEFT]
    add x28, x28, x9
    ldr x9, [x27, #BOX_BORDER_RIGHT]
    add x28, x28, x9
    str x28, [x27, #FLOAT_W]
    ldr x9, [x27, #792]
    add x0, x0, x9
    ldr x9, [x27, #800]
    add x0, x0, x9
    ldr x9, [x27, #824]
    add x0, x0, x9
    ldr x9, [x27, #832]
    add x0, x0, x9
    ldr x9, [x27, #BOX_BORDER_TOP]
    add x0, x0, x9
    ldr x9, [x27, #BOX_BORDER_BOTTOM]
    add x0, x0, x9
    str x0, [x27, #FLOAT_H]
    ldr x9, [sp, #1024]
    str x9, [sp, #1032]            // candidate y
    // Clearance is relative to preceding floats on the specified side(s).
    ldr x10, [x27, #(32+CSS_CLEAR*8)]
    mov x11, #0
Lfloat_clear_scan:
    cmp x11, x25
    b.hs Lfloat_fit
    ldr x12, [sp, x11, lsl #3]
    add x12, x21, x12, lsl #11
    ldr x13, [x12, #(32+CSS_FLOAT*8)]
    tst x10, x13
    b.eq Lfloat_clear_next
    ldr x13, [x12, #FLOAT_Y]
    ldr x14, [x12, #FLOAT_H]
    add x13, x13, x14
    cmp x9, x13
    csel x9, x13, x9, lt
Lfloat_clear_next:
    add x11, x11, #1
    b Lfloat_clear_scan
Lfloat_fit:
    str x9, [sp, #1032]
    mov x10, #0                    // available left
    mov x11, x24                   // available right
    mov x12, #-1                   // next bottom edge
    mov x13, #0
Lfloat_obstacles:
    cmp x13, x25
    b.hs Lfloat_fit_width
    ldr x14, [sp, x13, lsl #3]
    add x14, x21, x14, lsl #11
    ldr x15, [x14, #FLOAT_Y]
    cmp x15, x9
    b.gt Lfloat_obstacle_next
    ldr x16, [x14, #FLOAT_H]
    add x16, x16, x15
    cmp x16, x9
    b.le Lfloat_obstacle_next
    cmp x12, #-1
    b.eq Lfloat_next_bottom
    cmp x16, x12
    b.ge Lfloat_obstacle_side
Lfloat_next_bottom:
    mov x12, x16
Lfloat_obstacle_side:
    ldr x15, [x14, #FLOAT_X]
    ldr x16, [x14, #(32+CSS_FLOAT*8)]
    cmp x16, #1
    b.ne Lfloat_obstacle_right
    ldr x16, [x14, #FLOAT_W]
    add x15, x15, x16
    cmp x10, x15
    csel x10, x15, x10, lt
    b Lfloat_obstacle_next
Lfloat_obstacle_right:
    cmp x11, x15
    csel x11, x15, x11, gt
Lfloat_obstacle_next:
    add x13, x13, #1
    b Lfloat_obstacles
Lfloat_fit_width:
    sub x13, x11, x10
    cmp x28, x13
    b.le Lfloat_place
    cmn x12, #1
    b.eq Lfloat_place              // oversized float overflows an empty band
    mov x9, x12
    b Lfloat_fit
Lfloat_place:
    ldr x12, [x27, #(32+CSS_FLOAT*8)]
    cmp x12, #2
    b.ne Lfloat_place_left
    sub x10, x11, x28
Lfloat_place_left:
    str x10, [x27, #FLOAT_X]
    str x9, [x27, #FLOAT_Y]
    str x9, [sp, #1024]
    add x10, x22, #1
    str x10, [x27, #FLOW_OWNER]
    mov x10, #1
    str x10, [x27, #FLOAT_ACTIVE]
    str x26, [sp, x25, lsl #3]
    add x25, x25, #1
Lfloat_collect_next:
    add x9, x21, x26, lsl #11
    ldr x26, [x9, #FLOAT_NEXT]
    b Lfloat_collect
Lfloat_group_done:
    add sp, sp, #1040
    LEAVE

// A normal container whose entire visible content floats has zero flow height.
float_container_hint:
    ldr x2, [x0, #72]
    add x3, x2, x1, lsl #11
    ldr x4, [x3, #(32+CSS_FLOAT*8)]
    cbnz x4, Lcontainer_hint_done
    ldr x4, [x3, #FLOW_OWNER]
    cbnz x4, Lcontainer_hint_done
    ldr x4, [x3, #88]
    cmp x4, #3
    b.hs Lcontainer_hint_done
    ldr x4, [x3, #(1840+(CSS_POSITION-48)*8)]
    cmp x4, #2
    b.hs Lcontainer_hint_done
    ldr x4, [x3, #(1840+(CSS_OVERFLOW_X-48)*8)]
    cmp x4, #1
    b.eq Lcontainer_hint_done
    cmp x4, #2
    b.eq Lcontainer_hint_done
    ldr x4, [x3, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    cmp x4, #1
    b.eq Lcontainer_hint_done
    cmp x4, #2
    b.eq Lcontainer_hint_done
    mov x4, #1
    str x4, [x3, #FLOAT_CONTAINER_ONLY]
    ldr x4, [x0, #16]
    ldr x5, [x0, #24]
    ldr x6, [x0]
    add x7, x1, #1
Lcontainer_hint_node:
    cmp x7, x5
    b.hs Lcontainer_hint_done
    mov x8, #40
    madd x9, x7, x8, x4
    ldr x10, [x9, #8]
    cmp x10, x1
    b.lo Lcontainer_hint_done
    ldr x11, [x9]
    cmp x11, #NODE_TEXT
    b.ne Lcontainer_hint_next
    add x11, x2, x7, lsl #11
    ldr x11, [x11, #88]
    cmp x11, #1
    b.eq Lcontainer_hint_next
    ldp x11, x12, [x9, #16]
Lcontainer_hint_text:
    cmp x11, x12
    b.hs Lcontainer_hint_next
    ldrb w13, [x6, x11]
    add x11, x11, #1
    cmp w13, #32
    b.ls Lcontainer_hint_text
Lcontainer_hint_parent:
    cmp x10, x1
    b.eq Lcontainer_hint_normal
    add x11, x2, x10, lsl #11
    ldr x11, [x11, #(32+CSS_FLOAT*8)]
    cbnz x11, Lcontainer_hint_next
    madd x11, x10, x8, x4
    ldr x10, [x11, #8]
    b Lcontainer_hint_parent
Lcontainer_hint_next:
    add x7, x7, #1
    b Lcontainer_hint_node
Lcontainer_hint_normal:
    str xzr, [x3, #FLOAT_CONTAINER_ONLY]
Lcontainer_hint_done:
    ret
