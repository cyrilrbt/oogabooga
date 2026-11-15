// Scene transforms are separate from flow geometry. Relative offsets never
// move following siblings; fixed offsets track the visible viewport origin.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
// encoded inset, positive reference double -> signed pixel double.
scene_length:
    fcvtzs x1, d0
    ENTER
    bl _engine_box_signed_length
    scvtf d0, x0
    LEAVE

// scene, visible origin d0/d1. Parent records precede descendants.
.globl _engine_scene_update
_engine_scene_update:
    ENTER
    mov x19, x0
    cbz x19, Lgeometry_done
    stp d0, d1, [x19, #48]
    ldr x20, [x19, #8]
    mov x21, #0
Lgeometry_next:
    ldr x9, [x19]
    cmp x21, x9
    b.hs Lgeometry_done
    add x22, x20, x21, lsl #9
    fmov d0, xzr
    fmov d1, xzr
    cbz x21, Lgeometry_base_store
    ldr x9, [x22, #SC_PARENT]
    add x23, x20, x9, lsl #9
    ldp d0, d1, [x23, #SC_TX]
    ldp d2, d3, [x23, #SC_SCROLL_X]
    fsub d0, d0, d2
    fsub d1, d1, d3
Lgeometry_base_store:
    stp d0, d1, [x22, #SC_TX]
    ldr x24, [x22, #SC_POSITION]
    cbz x24, Lgeometry_advance
    cmp x24, #1
    b.eq Lgeometry_relative
    // Padding box of nearest positioned ancestor, or initial viewport.
    ldr x9, [x19, #32]
    scvtf d2, x9
    ldr x9, [x19, #40]
    scvtf d3, x9
    fmov d0, xzr
    fmov d1, xzr
    cmp x24, #3
    b.ne Lgeometry_absolute
    ldp d0, d1, [x19, #48]
    b Lgeometry_container_ready
Lgeometry_absolute:
    ldr x9, [x22, #SC_CONTAINING]
    cbz x9, Lgeometry_container_ready
    sub x9, x9, #1
    add x23, x20, x9, lsl #9
    ldr x9, [x23, #SC_FLAGS]
    tbz x9, #1, Lgeometry_container_ready
    ldp d0, d1, [x23, #SC_X]
    ldp d2, d3, [x23, #SC_W]
    ldp d4, d5, [x23, #SC_TX]
    fadd d0, d0, d4
    fadd d1, d1, d5
    ldr x9, [x23, #SC_BORDER]
    and x10, x9, #0xffff
    scvtf d4, x10
    fadd d0, d0, d4
    fsub d2, d2, d4
    ubfx x10, x9, #16, #16
    scvtf d4, x10
    fadd d1, d1, d4
    fsub d3, d3, d4
    ubfx x10, x9, #32, #16
    scvtf d4, x10
    fsub d2, d2, d4
    ubfx x10, x9, #48, #16
    scvtf d4, x10
    fsub d3, d3, d4
Lgeometry_container_ready:
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x25, #0
Lgeometry_axis:
    add x26, x22, x25, lsl #3
    ldr x0, [x26, #SC_LEFT]
    tbnz x0, #63, Lgeometry_trailing
    add x9, sp, #160
    ldr d0, [x9, x25, lsl #3]
    bl scene_length
    add x9, sp, #144
    ldr d1, [x9, x25, lsl #3]
    fadd d0, d0, d1
    b Lgeometry_target
Lgeometry_trailing:
    ldr x0, [x26, #SC_RIGHT]
    tbnz x0, #63, Lgeometry_axis_next // both auto: preserve static position
    add x9, sp, #160
    ldr d0, [x9, x25, lsl #3]
    bl scene_length
    add x9, sp, #144
    ldr d1, [x9, x25, lsl #3]
    add x9, sp, #160
    ldr d2, [x9, x25, lsl #3]
    fadd d1, d1, d2
    fsub d0, d1, d0
    ldr d1, [x26, #SC_W]
    fsub d0, d0, d1
Lgeometry_target:
    ldr d1, [x26, #SC_X]
    fsub d0, d0, d1
    str d0, [x26, #SC_TX]
Lgeometry_axis_next:
    add x25, x25, #1
    cmp x25, #2
    b.lo Lgeometry_axis
    b Lgeometry_advance
Lgeometry_relative:
    mov x25, #0
Lgeometry_relative_axis:
    add x26, x22, x25, lsl #3
    ldr x9, [x22, #SC_PARENT]
    add x23, x20, x9, lsl #9
    add x23, x23, x25, lsl #3
    ldr d0, [x23, #SC_W]
    ldr x0, [x26, #SC_LEFT]
    tbnz x0, #63, Lgeometry_relative_trailing
    bl scene_length
    b Lgeometry_relative_store
Lgeometry_relative_trailing:
    ldr x0, [x26, #SC_RIGHT]
    tbnz x0, #63, Lgeometry_relative_next
    bl scene_length
    fneg d0, d0
Lgeometry_relative_store:
    ldr d1, [x26, #SC_TX]
    fadd d0, d0, d1
    str d0, [x26, #SC_TX]
Lgeometry_relative_next:
    add x25, x25, #1
    cmp x25, #2
    b.lo Lgeometry_relative_axis
Lgeometry_advance:
    mov x0, x19
    mov x1, x21
    bl _engine_scene_clip
    add x21, x21, #1
    b Lgeometry_next
Lgeometry_done:
    LEAVE
