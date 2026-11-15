// Per-axis padding-box clips. Paint and hit testing consume the same result.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
.globl _engine_scene_clip
_engine_scene_clip:
    ldr x2, [x0, #8]
    add x3, x2, x1, lsl #9
    mov x4, #0
    fmov d0, xzr
    fmov d1, xzr
    fmov d2, xzr
    fmov d3, xzr
    cbz x1, Lclip_own
    ldr x5, [x3, #SC_POSITION]
    cmp x5, #3
    b.eq Lclip_own                  // fixed viewport children escape ancestor clips
    cmp x5, #2
    b.ne Lclip_parent
    ldr x5, [x3, #SC_CONTAINING]
    cbz x5, Lclip_own
    sub x5, x5, #1
    b Lclip_parent_ready
Lclip_parent:
    ldr x5, [x3, #SC_PARENT]
Lclip_parent_ready:
    add x5, x2, x5, lsl #9
    ldr x4, [x5, #SC_CLIP_AXES]
    ldp d0, d1, [x5, #SC_CLIP_X]
    ldp d2, d3, [x5, #SC_CLIP_W]
Lclip_own:
    ldr x5, [x3, #SC_FLAGS]
    tbz x5, #1, Lclip_store
    ldp d4, d5, [x3, #SC_X]
    ldp d6, d7, [x3, #SC_W]
    ldp d16, d17, [x3, #SC_TX]
    fadd d4, d4, d16
    fadd d5, d5, d17
    ldr x5, [x3, #SC_BORDER]
    and x6, x5, #0xffff
    scvtf d16, x6
    fadd d4, d4, d16
    fsub d6, d6, d16
    ubfx x6, x5, #16, #16
    scvtf d16, x6
    fadd d5, d5, d16
    fsub d7, d7, d16
    ubfx x6, x5, #32, #16
    scvtf d16, x6
    fsub d6, d6, d16
    ubfx x6, x5, #48, #16
    scvtf d16, x6
    fsub d7, d7, d16
    fmov d18, xzr
    fmax d6, d6, d18
    fmax d7, d7, d18
    ldr x5, [x3, #SC_OVERFLOW_X]
    cbz x5, Lclip_y
    tbz x4, #0, Lclip_x_replace
    fadd d16, d0, d2
    fadd d17, d4, d6
    fmin d16, d16, d17
    fmax d0, d0, d4
    fsub d2, d16, d0
    fmax d2, d2, d18
    b Lclip_y
Lclip_x_replace:
    fmov d0, d4
    fmov d2, d6
    orr x4, x4, #1
Lclip_y:
    ldr x5, [x3, #SC_OVERFLOW_Y]
    cbz x5, Lclip_store
    tbz x4, #1, Lclip_y_replace
    fadd d16, d1, d3
    fadd d17, d5, d7
    fmin d16, d16, d17
    fmax d1, d1, d5
    fsub d3, d16, d1
    fmax d3, d3, d18
    b Lclip_store
Lclip_y_replace:
    fmov d1, d5
    fmov d3, d7
    orr x4, x4, #2
Lclip_store:
    stp d0, d1, [x3, #SC_CLIP_X]
    stp d2, d3, [x3, #SC_CLIP_W]
    str x4, [x3, #SC_CLIP_AXES]
    ret

// scene,node,outRect*,border BOOL,rect d0..d3 -> BOOL, writes four doubles.
// Border/background uses only ancestor clips; content also uses its own clip.
.globl _engine_scene_rect
_engine_scene_rect:
    cbz x0, Lrect_bad
    cbz x2, Lrect_bad
    fmov x6, d0
    ubfx x6, x6, #52, #11
    cmp x6, #2047
    b.eq Lrect_bad
    fmov x6, d1
    ubfx x6, x6, #52, #11
    cmp x6, #2047
    b.eq Lrect_bad
    fmov x6, d2
    ubfx x6, x6, #52, #11
    cmp x6, #2047
    b.eq Lrect_bad
    fmov x6, d3
    ubfx x6, x6, #52, #11
    cmp x6, #2047
    b.eq Lrect_bad
    ldr x4, [x0]
    cmp x1, x4
    b.hs Lrect_bad
    ldr x4, [x0, #8]
    add x4, x4, x1, lsl #9
    ldp d4, d5, [x4, #SC_TX]
    fadd d0, d0, d4
    fadd d1, d1, d5
    cbz x3, Lrect_clip_ready
    cbz x1, Lrect_validate
    ldr x5, [x4, #SC_POSITION]
    cmp x5, #3
    b.eq Lrect_validate
    cmp x5, #2
    b.ne Lrect_parent
    ldr x5, [x4, #SC_CONTAINING]
    cbz x5, Lrect_validate
    sub x5, x5, #1
    b Lrect_parent_ready
Lrect_parent:
    ldr x5, [x4, #SC_PARENT]
Lrect_parent_ready:
    ldr x4, [x0, #8]
    add x4, x4, x5, lsl #9
Lrect_clip_ready:
    ldr x5, [x4, #SC_CLIP_AXES]
    tbz x5, #0, Lrect_y
    ldp d4, d5, [x4, #SC_CLIP_X]
    ldr d6, [x4, #SC_CLIP_W]
    fadd d6, d6, d4
    fadd d7, d0, d2
    fmin d6, d6, d7
    fmax d0, d0, d4
    fsub d2, d6, d0
Lrect_y:
    tbz x5, #1, Lrect_validate
    ldr d4, [x4, #SC_CLIP_Y]
    ldr d6, [x4, #SC_CLIP_H]
    fadd d6, d6, d4
    fadd d7, d1, d3
    fmin d6, d6, d7
    fmax d1, d1, d4
    fsub d3, d6, d1
Lrect_validate:
    fcmp d2, #0.0
    b.le Lrect_bad
    b.vs Lrect_bad
    fcmp d3, #0.0
    b.le Lrect_bad
    b.vs Lrect_bad
    stp d0, d1, [x2]
    stp d2, d3, [x2, #16]
    mov x0, #1
    ret
Lrect_bad:
    fmov d2, xzr
    fmov d3, xzr
    cbz x2, Lrect_bad_return
    stp d0, d1, [x2]
    stp d2, d3, [x2, #16]
Lrect_bad_return:
    mov x0, #0
    ret
