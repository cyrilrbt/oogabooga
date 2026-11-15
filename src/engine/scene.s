.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
// doc, viewport width,height -> owned scene or nil.
.globl _engine_scene_new
_engine_scene_new:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    cbz x0, Lscene_new_fail
    cmp x20, #0
    b.le Lscene_new_fail
    cmp x21, #0
    b.le Lscene_new_fail
    mov x9, #16384
    cmp x20, x9
    b.hi Lscene_new_fail
    cmp x21, x9
    b.hi Lscene_new_fail
    ldr x22, [x19, #24]
    cbz x22, Lscene_new_fail
    cmp x22, #ENGINE_MAX_NODES
    b.hi Lscene_new_fail
    mov x9, #528                   // records + two per-node bucket arrays
    mul x1, x22, x9
    mov x9, #589824                // 40960 order + 32768 scratch indices
    add x1, x1, x9
    add x1, x1, #96
    mov x0, #1
    bl _calloc
    cbz x0, Lscene_new_fail
    mov x23, x0
    str x22, [x23]
    add x24, x23, #96
    str x24, [x23, #8]
    add x9, x24, x22, lsl #9
    str x9, [x23, #16]
    mov x10, #327680
    add x9, x9, x10
    str x9, [x23, #88]             // command sort scratch
    mov x10, #262144
    add x9, x9, x10
    str x9, [x23, #72]             // bucket counts/prefixes
    add x9, x9, x22, lsl #3
    str x9, [x23, #80]             // rank -> node
    stp x20, x21, [x23, #32]
    mov x25, #0
Lscene_new_node:
    cmp x25, x22
    b.hs Lscene_new_rank
    add x26, x24, x25, lsl #9
    ldr x27, [x19, #72]
    add x27, x27, x25, lsl #11
    str x26, [x27, #2032]          // native adapter snapshot owns scene lifetime
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x25, x10, x9
    ldr x10, [x9, #8]
    str x10, [x26, #SC_PARENT]
    ldr x9, [x9]
    str x9, [x26, #SC_KIND]
    ldr x9, [x27, #DOM_HANDLE]
    str x9, [x26, #SC_DOM]
    ldr x9, [x27, #(1840+(CSS_POSITION-48)*8)]
    str x9, [x26, #SC_POSITION]
    ldr x10, [x27, #(1840+(CSS_Z_INDEX-48)*8)]
    mov x11, #32768
    cmp x10, #0
    csel x11, x11, x10, lt
    str x11, [x26, #SC_Z]
    ldr x11, [x27, #(32+CSS_OPACITY*8)]
    ldr x12, [x26, #SC_KIND]
    cmp x12, #NODE_SVG
    mov x13, #1000
    csel x11, x13, x11, eq          // SVG adapter already composites its own alpha
    str x11, [x26, #SC_OPACITY]
    mov x28, #0
    cbz x25, Lscene_new_context
    cmp x11, #1000
    b.lo Lscene_new_context
    cmp x9, #3
    b.eq Lscene_new_context
    cbz x9, Lscene_new_flags
    cmp x10, #0
    b.lt Lscene_new_flags
Lscene_new_context:
    orr x28, x28, #SC_IS_CONTEXT
Lscene_new_flags:
    ldr x9, [x27, #216]
    cbz x9, Lscene_new_flags_store
    orr x28, x28, #SC_BORDER_BOX
Lscene_new_flags_store:
    str x28, [x26, #SC_FLAGS]
    ldr x9, [x27, #(1840+(CSS_INSET_LEFT-48)*8)]
    ldr x10, [x27, #(1840+(CSS_INSET_TOP-48)*8)]
    stp x9, x10, [x26, #SC_LEFT]
    ldr x9, [x27, #(1840+(CSS_INSET_RIGHT-48)*8)]
    ldr x10, [x27, #(1840+(CSS_INSET_BOTTOM-48)*8)]
    stp x9, x10, [x26, #SC_RIGHT]
    ldr x10, [x27, #(1840+(CSS_OVERFLOW_X-48)*8)]
    ldr x11, [x27, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    stp x10, x11, [x26, #SC_OVERFLOW_X]
    ldr x9, [x27, #808]
    ldr x10, [x27, #824]
    orr x9, x9, x10, lsl #16
    ldr x10, [x27, #816]
    orr x9, x9, x10, lsl #32
    ldr x10, [x27, #832]
    orr x9, x9, x10, lsl #48
    str x9, [x26, #SC_PADDING]
    ldr x9, [x27, #BOX_BORDER_LEFT]
    ldr x10, [x27, #BOX_BORDER_TOP]
    orr x9, x9, x10, lsl #16
    ldr x10, [x27, #BOX_BORDER_RIGHT]
    orr x9, x9, x10, lsl #32
    ldr x10, [x27, #BOX_BORDER_BOTTOM]
    orr x9, x9, x10, lsl #48
    str x9, [x26, #SC_BORDER]
    ldr x9, [x27, #152]
    str x9, [x26, #SC_HEIGHT]
    ldr x9, [x27, #144]
    str x9, [x26, #SC_WIDTH]
    cbz x25, Lscene_new_next
    mov x0, x23
    mov x1, x25
    bl _engine_scene_context_link
Lscene_new_next:
    add x25, x25, #1
    b Lscene_new_node
Lscene_new_rank:
    mov x0, x23
    mov x1, #0
    bl _engine_scene_rank_context
    ldr x9, [x19, #96]
    str x9, [x24, #SC_MODEL]
    mov x0, x23
    LEAVE
Lscene_new_fail:
    mov x0, #0
    LEAVE

.globl _engine_scene_free
_engine_scene_free:
    b _free

// scene,node,view-coordinate border box d0..d3 -> BOOL.
.globl _engine_scene_set_box
_engine_scene_set_box:
    cbz x0, Lscene_box_bad
    ldr x9, [x0]
    cmp x1, x9
    b.hs Lscene_box_bad
    // Reject infinities as well as NaNs, without changing existing geometry.
    fmov x10, d0
    ubfx x10, x10, #52, #11
    cmp x10, #2047
    b.eq Lscene_box_bad
    fmov x10, d1
    ubfx x10, x10, #52, #11
    cmp x10, #2047
    b.eq Lscene_box_bad
    fmov x10, d2
    ubfx x10, x10, #52, #11
    cmp x10, #2047
    b.eq Lscene_box_bad
    fmov x10, d3
    ubfx x10, x10, #52, #11
    cmp x10, #2047
    b.eq Lscene_box_bad
    fcmp d0, d0
    b.vs Lscene_box_bad
    fcmp d1, d1
    b.vs Lscene_box_bad
    fcmp d2, #0.0
    b.lt Lscene_box_bad
    b.vs Lscene_box_bad
    fcmp d3, #0.0
    b.lt Lscene_box_bad
    b.vs Lscene_box_bad
    ldr x9, [x0, #8]
    add x9, x9, x1, lsl #9
    stp d0, d1, [x9, #SC_X]
    stp d2, d3, [x9, #SC_W]
    ldr x10, [x9, #SC_FLAGS]
    orr x10, x10, #SC_HAS_BOX
    str x10, [x9, #SC_FLAGS]
    mov x0, #1
    ret
Lscene_box_bad:
    mov x0, #0
    ret
