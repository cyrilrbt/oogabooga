// Unified scene replay: box fills, native selection backgrounds and glyphs share
// assembly stacking order, transforms and clips. Native services shape/draw only.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
.globl _mac_scene_draw
_mac_scene_draw:
    ENTER
    sub sp, sp, #768
    mov x19, x0
    mov x20, x1
    add x9, sp, #560
    stp d0, d1, [x9]
    str xzr, [sp, #512]             // context depth
    mov x9, #-1
    str x9, [sp, #520]              // previous paint rank
    LOAD x21, _mac_scene
    LOAD x22, _mac_display_list
    cbz x21, Lscene_draw_done
    cbz x22, Lscene_draw_done
    LOAD x0, _engine_text
    MSG visibleRect
    mov x0, x21
    bl _engine_scene_update
    bl _mac_scene_controls_update
    CLASS NSGraphicsContext
    MSG currentContext
    MSG CGContext
    mov x23, x0
    bl _CGContextGetClipBoundingBox
    add x9, sp, #608
    stp d0, d1, [x9]
    stp d2, d3, [x9, #16]
    STORE xzr, _mac_display_painted
    STORE xzr, _mac_display_culled
    mov x24, #0
Lscene_draw_next:
    ldr x9, [x21, #24]
    cmp x24, x9
    b.hs Lscene_draw_finish
    ldr x9, [x21, #16]
    ldr x9, [x9, x24, lsl #3]
    ldr x10, [x22, #16]
    add x25, x10, x9, lsl #7
    ldr x9, [x25, #8]
    ldr x10, [x21, #8]
    add x26, x10, x9, lsl #9
    ldr x27, [x26, #SC_RANK]
    ldr x9, [sp, #520]
    cmp x9, x27
    b.eq Lscene_draw_command
Lscene_draw_close:
    ldr x9, [sp, #512]
    cbz x9, Lscene_draw_enter
    sub x9, x9, #1
    ldr x10, [sp, x9, lsl #3]
    ldr x11, [x21, #8]
    add x28, x11, x10, lsl #9
    ldr x10, [x28, #SC_END_RANK]
    cmp x10, x27
    b.hs Lscene_draw_enter
    str x9, [sp, #512]
    ldr x10, [x28, #SC_OPACITY]
    cmp x10, #1000
    b.hs Lscene_draw_close
    mov x0, x23
    bl _CGContextEndTransparencyLayer
    mov x0, x23
    bl _CGContextRestoreGState
    b Lscene_draw_close
Lscene_draw_enter:
    str x27, [sp, #520]
    ldr x9, [x26, #SC_FLAGS]
    tbz x9, #0, Lscene_draw_command
    ldr x9, [sp, #512]
    cmp x9, #64
    b.hs Lscene_draw_command
    ldr x10, [x25, #8]
    str x10, [sp, x9, lsl #3]
    add x9, x9, #1
    str x9, [sp, #512]
    ldr x9, [x26, #SC_OPACITY]
    cmp x9, #1000
    b.hs Lscene_draw_command
    mov x0, x23
    bl _CGContextSaveGState
    ldr x9, [x26, #SC_OPACITY]
    scvtf d0, x9
    mov x9, #1000
    scvtf d1, x9
    fdiv d0, d0, d1
    mov x0, x23
    bl _CGContextSetAlpha
    mov x0, x23
    mov x1, #0
    bl _CGContextBeginTransparencyLayer
Lscene_draw_command:
    ldr x9, [x25]
    cmp x9, #1
    b.lo Lscene_draw_advance
    cmp x9, #3
    b.hi Lscene_draw_advance
    mov x0, x21
    ldr x1, [x25, #8]
    add x2, sp, #576
    cmp x9, #1
    cset x3, eq
    ldp d0, d1, [x25, #16]
    ldp d2, d3, [x25, #32]
    bl _engine_scene_rect
    cbz x0, Lscene_draw_advance
    add x9, sp, #608
    ldp d4, d5, [x9]
    ldp d6, d7, [x9, #16]
    fadd d16, d0, d2
    fcmp d16, d4
    b.le Lscene_draw_advance
    fadd d16, d1, d3
    fcmp d16, d5
    b.le Lscene_draw_advance
    fadd d6, d4, d6
    fcmp d0, d6
    b.ge Lscene_draw_advance
    fadd d7, d5, d7
    fcmp d1, d7
    b.ge Lscene_draw_advance
    mov x0, x23
    bl _CGContextSaveGState
    mov x0, x23
    add x9, sp, #576
    ldp d0, d1, [x9]
    ldp d2, d3, [x9, #16]
    bl _CGContextClipToRect
    mov x0, x23
    ldp d0, d1, [x26, #SC_TX]
    bl _CGContextTranslateCTM
    ldr x9, [x25]
    cmp x9, #1
    b.eq Lscene_draw_box
    // Native selection/inline backgrounds belong immediately below these
    // glyphs, inside the same transformed, clipped stacking context.
    CLASS NSLayoutManager
    add x9, sp, #536
    stp x19, x0, [x9]
    mov x0, x9
    SELECT x1, sceneGlyphBackground
    ldp x2, x3, [x25, #56]
    add x9, sp, #560
    ldp d0, d1, [x9]
    bl _objc_msgSendSuper
    CLASS NSLayoutManager
    add x9, sp, #536
    stp x19, x0, [x9]
    mov x0, x9
    mov x1, x20
    ldp x2, x3, [x25, #56]
    add x9, sp, #560
    ldp d0, d1, [x9]
    bl _objc_msgSendSuper
    b Lscene_draw_restore
Lscene_draw_box:
    // Replay one stable command without mutating/moving its retained record.
    mov x9, #1
    str x9, [sp, #640]
    str x9, [sp, #648]
    str x25, [sp, #656]
    str xzr, [sp, #664]
    LOAD x9, _mac_display_painted
    str x9, [sp, #672]
    LOAD x9, _mac_display_culled
    str x9, [sp, #680]
    mov x0, x23
    bl _CGContextGetClipBoundingBox
    add x0, sp, #640
    bl _mac_display_replay
    LOAD x9, _mac_display_painted
    ldr x10, [sp, #672]
    add x9, x9, x10
    STORE x9, _mac_display_painted
    LOAD x9, _mac_display_culled
    ldr x10, [sp, #680]
    add x9, x9, x10
    STORE x9, _mac_display_culled
Lscene_draw_restore:
    mov x0, x23
    bl _CGContextRestoreGState
Lscene_draw_advance:
    add x24, x24, #1
    b Lscene_draw_next
Lscene_draw_finish:
    ldr x9, [sp, #512]
    cbz x9, Lscene_draw_done
    sub x9, x9, #1
    str x9, [sp, #512]
    ldr x10, [sp, x9, lsl #3]
    ldr x11, [x21, #8]
    add x11, x11, x10, lsl #9
    ldr x10, [x11, #SC_OPACITY]
    cmp x10, #1000
    b.hs Lscene_draw_finish
    mov x0, x23
    bl _CGContextEndTransparencyLayer
    mov x0, x23
    bl _CGContextRestoreGState
    b Lscene_draw_finish
Lscene_draw_done:
    add sp, sp, #768
    LEAVE
