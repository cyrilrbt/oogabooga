// Scroll state and extent calculation use primitive scene boxes only. Negative
// overflow is not scrollable; fixed boxes never enlarge their document/ancestor.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
.globl _engine_scene_copy_scroll
_engine_scene_copy_scroll:
    cbz x0, Lscroll_copy_done
    cbz x1, Lscroll_copy_done
    ldr x2, [x0, #8]
    ldr x3, [x1, #8]
    ldr x2, [x2, #SC_MODEL]
    ldr x3, [x3, #SC_MODEL]
    cbz x2, Lscroll_copy_done
    cmp x2, x3
    b.ne Lscroll_copy_done
    ldr x2, [x1, #88]
    mov x3, #0
    mov x4, #(DOM_MAX_NODES+1)
Lscroll_copy_clear:
    str xzr, [x2, x3, lsl #3]
    add x3, x3, #1
    cmp x3, x4
    b.lo Lscroll_copy_clear
    ldr x3, [x1]
    ldr x4, [x1, #8]
Lscroll_copy_index:
    cbz x3, Lscroll_copy_new
    ldr x5, [x4, #SC_DOM]
    cbz x5, Lscroll_copy_old_next
    cmp x5, #DOM_MAX_NODES
    b.hi Lscroll_copy_old_next
    str x4, [x2, x5, lsl #3]
Lscroll_copy_old_next:
    add x4, x4, #SCENE_NODE_SIZE
    sub x3, x3, #1
    b Lscroll_copy_index
Lscroll_copy_new:
    ldr x3, [x0]
    ldr x4, [x0, #8]
Lscroll_copy_record:
    cbz x3, Lscroll_copy_done
    ldr x5, [x4, #SC_DOM]
    cbz x5, Lscroll_copy_next
    cmp x5, #DOM_MAX_NODES
    b.hi Lscroll_copy_next
    ldr x5, [x2, x5, lsl #3]
    cbz x5, Lscroll_copy_next
    ldp d0, d1, [x5, #SC_SCROLL_X]
    stp d0, d1, [x4, #SC_SCROLL_X]
Lscroll_copy_next:
    add x4, x4, #SCENE_NODE_SIZE
    sub x3, x3, #1
    b Lscroll_copy_record
Lscroll_copy_done:
    ret

// scene -> derive content extents and clamp offsets, after transforms/boxes.
.globl _engine_scene_extents
_engine_scene_extents:
    ldr x1, [x0]
    ldr x2, [x0, #8]
    mov x3, #0
    fmov d16, xzr
Lextent_init:
    cmp x3, x1
    b.hs Lextent_reverse_begin
    add x4, x2, x3, lsl #9
    ldp d0, d1, [x4, #SC_W]
    ldr x5, [x4, #SC_BORDER]
    and x6, x5, #0xffff
    ubfx x7, x5, #32, #16
    add x6, x6, x7
    scvtf d2, x6
    fsub d0, d0, d2
    ubfx x6, x5, #16, #16
    ubfx x7, x5, #48, #16
    add x6, x6, x7
    scvtf d2, x6
    fsub d1, d1, d2
    fmax d0, d0, d16
    fmax d1, d1, d16
    stp d0, d1, [x4, #SC_CONTENT_W]
    add x3, x3, #1
    b Lextent_init
Lextent_reverse_begin:
    mov x3, x1
Lextent_reverse:
    cmp x3, #1
    b.ls Lextent_clamp_begin
    sub x3, x3, #1
    add x4, x2, x3, lsl #9
    ldr x5, [x4, #SC_FLAGS]
    tbz x5, #1, Lextent_reverse
    ldr x5, [x4, #SC_POSITION]
    cmp x5, #3
    b.eq Lextent_reverse
    cmp x5, #2
    b.ne Lextent_parent
    ldr x5, [x4, #SC_CONTAINING]
    cbz x5, Lextent_initial_parent
    sub x5, x5, #1
    b Lextent_parent_ready
Lextent_initial_parent:
    mov x5, #0
    b Lextent_parent_ready
Lextent_parent:
    ldr x5, [x4, #SC_PARENT]
Lextent_parent_ready:
    add x5, x2, x5, lsl #9
    mov x6, #0
Lextent_axis:
    add x7, x4, x6, lsl #3
    add x8, x5, x6, lsl #3
    ldr d0, [x7, #SC_X]
    ldr d1, [x7, #SC_TX]
    fadd d0, d0, d1
    ldr d1, [x8, #SC_X]
    ldr d2, [x8, #SC_TX]
    fadd d1, d1, d2
    fsub d0, d0, d1
    ldr d1, [x8, #SC_SCROLL_X]
    fadd d0, d0, d1
    ldr x9, [x5, #SC_BORDER]
    lsl x10, x6, #4
    lsr x9, x9, x10
    and x9, x9, #0xffff
    scvtf d1, x9
    fsub d0, d0, d1
    ldr d1, [x7, #SC_W]
    ldr x9, [x7, #SC_OVERFLOW_X]
    cbnz x9, Lextent_child_bound
    ldr d2, [x7, #SC_CONTENT_W]
    ldr x9, [x4, #SC_BORDER]
    lsr x9, x9, x10
    and x9, x9, #0xffff
    scvtf d3, x9
    fadd d2, d2, d3
    fmax d1, d1, d2
Lextent_child_bound:
    fadd d0, d0, d1
    ldr d1, [x8, #SC_CONTENT_W]
    fmax d0, d0, d1
    str d0, [x8, #SC_CONTENT_W]
    add x6, x6, #1
    cmp x6, #2
    b.lo Lextent_axis
    b Lextent_reverse
Lextent_clamp_begin:
    mov x3, #0
Lextent_clamp:
    cmp x3, x1
    b.hs Lextent_done
    add x4, x2, x3, lsl #9
    mov x6, #0
Lextent_clamp_axis:
    add x7, x4, x6, lsl #3
    ldr d0, [x7, #SC_W]
    ldr x5, [x4, #SC_BORDER]
    lsl x8, x6, #4
    lsr x5, x5, x8
    and x8, x5, #0xffff
    ubfx x9, x5, #32, #16
    add x8, x8, x9
    scvtf d1, x8
    fsub d0, d0, d1
    ldr d1, [x7, #SC_CONTENT_W]
    fsub d1, d1, d0
    fmax d1, d1, d16
    ldr x5, [x7, #SC_OVERFLOW_X]
    cmp x5, #1
    b.eq Lextent_scrollable
    cmp x5, #2
    b.eq Lextent_scrollable
    fmov d1, xzr
Lextent_scrollable:
    str d1, [x7, #SC_SCROLL_MAX_X]
    ldr d0, [x7, #SC_SCROLL_X]
    fmax d0, d0, d16
    fmin d0, d0, d1
    str d0, [x7, #SC_SCROLL_X]
    add x6, x6, #1
    cmp x6, #2
    b.lo Lextent_clamp_axis
    add x3, x3, #1
    b Lextent_clamp
Lextent_done:
    ret

// scene,node,positive content deltas d0/d1 -> consumed BOOL. Boundary values
// return false so the adapter can chain to a parent scroll container.
.globl _engine_scene_scroll
_engine_scene_scroll:
    cbz x0, Lscroll_no
    ldr x2, [x0]
    cmp x1, x2
    b.hs Lscroll_no
    ldr x2, [x0, #8]
    add x2, x2, x1, lsl #9
    mov x3, #0
    mov x4, #0
    fmov d16, xzr
Lscroll_axis:
    add x5, x2, x3, lsl #3
    ldr x6, [x5, #SC_OVERFLOW_X]
    cmp x6, #2
    b.ne Lscroll_axis_next
    fmov d2, d0
    cbz x3, Lscroll_delta
    fmov d2, d1
Lscroll_delta:
    fcmp d2, d2
    b.vs Lscroll_axis_next
    ldr d3, [x5, #SC_SCROLL_X]
    ldr d4, [x5, #SC_SCROLL_MAX_X]
    fadd d2, d2, d3
    fmax d2, d2, d16
    fmin d2, d2, d4
    fcmp d2, d3
    b.eq Lscroll_axis_next
    str d2, [x5, #SC_SCROLL_X]
    mov x4, #1
Lscroll_axis_next:
    add x3, x3, #1
    cmp x3, #2
    b.lo Lscroll_axis
    mov x0, x4
    ret
Lscroll_no:
    mov x0, #0
    ret
