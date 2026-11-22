// Paint a single CSS background layer inside the existing scene clip/transform.
// Native image decoding/drawing supplies pixels; sizing, placement and tiling
// stay in assembly. Repetition is bounded to 4096 tiles per box.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_background_paint
_mac_background_paint:
    ENTER
    sub sp, sp, #160
    mov x19, x0
    .ifdef OOGA_GTK
    mov x28, x1
    LOAD x9, _gtk_doc
    .else
    LOAD x9, _engine_document
    .endif
    cbz x9, Lbg_paint_done
    ldr x10, [x19, #8]
    ldr x11, [x9, #24]
    cmp x10, x11
    b.hs Lbg_paint_done
.ifndef OOGA_GTK
    ldr x11, [x19]
    cmp x11, #99
    b.eq Lbg_paint_native_ready
    ldr x11, [x9, #16]
    mov x12, #40
    madd x11, x10, x12, x11
    ldr x11, [x11]
    cmp x11, #31 // native input/button cells paint their own background once
    b.eq Lbg_paint_done
    cmp x11, #34
    b.eq Lbg_paint_done
.endif
Lbg_paint_native_ready:
    ldr x21, [x9, #72]
    add x21, x21, x10, lsl #11
    ldr x24, [x21, #CSS_BG_SIDECAR]
    cbz x24, Lbg_paint_done
    .ifdef OOGA_GTK
    ldr x1, [x21, #(32+CSS_BG_IMAGE*8)]
    cmp x1, #0
    b.le Lbg_paint_done
    LOAD x0, _gtk_images
    cbz x0, Lbg_paint_done
    bl _g_hash_table_lookup
    cbz x0, Lbg_paint_done
    mov x23, x0
    bl _gdk_pixbuf_get_width
    scvtf d0, x0
    str d0, [sp, #32]
    mov x0, x23
    bl _gdk_pixbuf_get_height
    scvtf d1, x0
    ldr d0, [sp, #32]
    .else
    mov x0, x21
    bl _mac_background_url
    cbz x0, Lbg_paint_done
    MSG absoluteString
    mov x2, x0
    LOAD x0, _engine_images
    MSG objectKey
    cbz x0, Lbg_paint_done
    mov x23, x0
    CLASS NSImage
    mov x2, x0
    mov x0, x23
    MSG bgIsKind
    cbz x0, Lbg_paint_done
    mov x0, x23
    MSG size
    .endif
    stp d0, d1, [sp, #32] // natural dimensions
    fcmp d0, #0.0
    b.le Lbg_paint_done
    fcmp d1, #0.0
    b.le Lbg_paint_done
    ldp d0, d1, [x19, #16]
    ldp d2, d3, [x19, #32]
    stp d0, d1, [sp, #128]
    stp d2, d3, [sp, #144]
    ldr x9, [x21, #BOX_BORDER_LEFT]
    scvtf d4, x9
    fadd d0, d0, d4
    fsub d2, d2, d4
    ldr x9, [x21, #BOX_BORDER_RIGHT]
    scvtf d4, x9
    fsub d2, d2, d4
    ldr x9, [x21, #BOX_BORDER_TOP]
    scvtf d4, x9
    fadd d1, d1, d4
    fsub d3, d3, d4
    ldr x9, [x21, #BOX_BORDER_BOTTOM]
    scvtf d4, x9
    fsub d3, d3, d4
    stp d0, d1, [sp, #48]
    stp d2, d3, [sp, #64]
    ldr x25, [x24]
    ldr x26, [x24, #8]
    cmn x25, #10
    b.eq Lbg_paint_cover
    cmn x25, #11
    b.eq Lbg_paint_contain
    cmp x25, #0
    b.lt Lbg_paint_width_auto
    mov x0, x25
    fcvtzs x1, d2
    bl _engine_box_length
    scvtf d0, x0
    str d0, [sp, #80]
Lbg_paint_width_auto:
    cmp x26, #0
    b.lt Lbg_paint_height_auto
    mov x0, x26
    ldr d3, [sp, #72]
    fcvtzs x1, d3
    bl _engine_box_length
    scvtf d0, x0
    str d0, [sp, #88]
Lbg_paint_height_auto:
    ldp d0, d1, [sp, #32]
    cmp x25, #0
    b.ge Lbg_paint_auto_height
    cmp x26, #0
    b.lt Lbg_paint_natural
    ldr d2, [sp, #88]
    fmul d0, d0, d2
    fdiv d0, d0, d1
    fmov d1, d2
    b Lbg_paint_size_ready
Lbg_paint_auto_height:
    ldr d2, [sp, #80]
    cmp x26, #0
    b.ge Lbg_paint_explicit_size
    fmul d1, d1, d2
    fdiv d1, d1, d0
    fmov d0, d2
    b Lbg_paint_size_ready
Lbg_paint_explicit_size:
    fmov d0, d2
    ldr d1, [sp, #88]
    b Lbg_paint_size_ready
Lbg_paint_cover:
    mov x25, #1
    b Lbg_paint_fit
Lbg_paint_contain:
    mov x25, #0
Lbg_paint_fit:
    ldp d0, d1, [sp, #32]
    ldp d2, d3, [sp, #64]
    fdiv d2, d2, d0
    fdiv d3, d3, d1
    cbz x25, Lbg_paint_fit_min
    fmax d2, d2, d3
    b Lbg_paint_fit_scale
Lbg_paint_fit_min:
    fmin d2, d2, d3
Lbg_paint_fit_scale:
    fmul d0, d0, d2
    fmul d1, d1, d2
    b Lbg_paint_size_ready
Lbg_paint_natural:
Lbg_paint_size_ready:
    fcmp d0, #0.0
    b.le Lbg_paint_done
    fcmp d1, #0.0
    b.le Lbg_paint_done
    stp d0, d1, [sp, #80]
    ldr d2, [sp, #64]
    fsub d0, d2, d0
    ldr x0, [x24, #16]
    bl bg_axis
    ldr d1, [sp, #48]
    fadd d0, d0, d1
    str d0, [sp, #96]
    ldr d0, [sp, #72]
    ldr d1, [sp, #88]
    fsub d0, d0, d1
    ldr x0, [x24, #24]
    bl bg_axis
    ldr d1, [sp, #56]
    fadd d0, d0, d1
    str d0, [sp, #104]
    .ifdef OOGA_GTK
    mov x0, x28
    .else
    CLASS NSGraphicsContext
    MSG currentContext
    MSG CGContext
    .endif
    mov x22, x0
    bl _CGContextSaveGState
    ldp d0, d1, [sp, #128]
    ldp d2, d3, [sp, #144]
    mov x0, x22
    bl _CGContextClipToRect
    // Round the image clip without changing border geometry.
    ldr x0, [x21, #224]
    ldr d0, [sp, #64]
    fcvtzs x1, d0
    bl _engine_box_length
    cmp x0, #0
    b.le Lbg_paint_clip_ready
    .ifdef OOGA_GTK
    scvtf d4, x0
    fmov d5, d4
    ldp d0, d1, [sp, #128]
    ldp d2, d3, [sp, #144]
    mov x0, x22
    bl _gtk_cairo_rounded_rect
    mov x0, x22
    bl _cairo_clip
    .else
    scvtf d0, x0
    fmov d1, d0
    add x0, sp, #128
    mov x1, #0
    bl _CGPathCreateWithRoundedRect
    mov x25, x0
    mov x0, x22
    mov x1, x25
    bl _CGContextAddPath
    mov x0, x22
    bl _CGContextClip
    mov x0, x25
    bl _CGPathRelease
    .endif
Lbg_paint_clip_ready:
    ldr x26, [x24, #32]
    // Move repeated axes to the first tile intersecting the box.
    cmp x26, #1
    b.eq Lbg_paint_start
    cmp x26, #3
    b.eq Lbg_paint_repeat_y
    ldr d0, [sp, #96]
    ldr d1, [sp, #48]
    ldr d2, [sp, #80]
    fsub d3, d1, d0
    fdiv d3, d3, d2
    frintm d3, d3
    fmadd d0, d3, d2, d0
    str d0, [sp, #96]
Lbg_paint_repeat_y:
    cmp x26, #2
    b.eq Lbg_paint_start
    ldr d0, [sp, #104]
    ldr d1, [sp, #56]
    ldr d2, [sp, #88]
    fsub d3, d1, d0
    fdiv d3, d3, d2
    frintm d3, d3
    fmadd d0, d3, d2, d0
    str d0, [sp, #104]
Lbg_paint_start:
    mov x27, #4096
    ldr d0, [sp, #104]
    str d0, [sp, #120]
Lbg_paint_row:
    ldr d0, [sp, #96]
    str d0, [sp, #112]
Lbg_paint_tile:
    ldr d0, [sp, #112]
    ldr d1, [sp, #120]
    ldp d2, d3, [sp, #80]
    .ifdef OOGA_GTK
    mov x0, x23
    mov x1, x22
    bl _gtk_pixbuf_draw
    .else
    fmov d4, xzr
    fmov d5, xzr
    fmov d6, xzr
    fmov d7, xzr
    fmov d16, #1.0
    str d16, [sp] // ninth FP argument spills; integer args retain registers
    mov x0, x23
    mov x2, #2 // NSCompositingOperationSourceOver
    mov x3, #1 // respect flipped scene coordinates
    mov x4, #0
    MSG bgDrawImage
    .endif
    subs x27, x27, #1
    b.eq Lbg_paint_restore
    cmp x26, #1
    b.eq Lbg_paint_restore
    cmp x26, #3
    b.eq Lbg_paint_next_row
    ldr d0, [sp, #112]
    ldr d1, [sp, #80]
    fadd d0, d0, d1
    str d0, [sp, #112]
    ldr d1, [sp, #48]
    ldr d2, [sp, #64]
    fadd d1, d1, d2
    fcmp d0, d1
    b.lt Lbg_paint_tile
Lbg_paint_next_row:
    cmp x26, #2
    b.eq Lbg_paint_restore
    ldr d0, [sp, #120]
    ldr d1, [sp, #88]
    fadd d0, d0, d1
    str d0, [sp, #120]
    ldr d1, [sp, #56]
    ldr d2, [sp, #72]
    fadd d1, d1, d2
    fcmp d0, d1
    b.lt Lbg_paint_row
Lbg_paint_restore:
    mov x0, x22
    bl _CGContextRestoreGState
Lbg_paint_done:
    add sp, sp, #160
    LEAVE
// Position percentages refer to remaining space, including negative space for
// an image larger than its box. x0 value, d0 remaining -> d0 offset.
bg_axis:
    tbz x0, #32, Lbg_axis_pixels
    and x9, x0, #0xffffffff
    scvtf d1, x9
    fmul d0, d0, d1
    mov x9, #34464
    movk x9, #1, lsl #16
    scvtf d1, x9
    fdiv d0, d0, d1
    ret
Lbg_axis_pixels:
    scvtf d0, x0
    ret

.ifndef OOGA_GTK
.globl _mac_background_control_paint
_mac_background_control_paint:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    MSG tag
    str x0, [sp, #8]
    mov x9, #99
    str x9, [sp]
    mov x0, x19
    MSG bounds
    stp d0, d1, [sp, #16]
    stp d2, d3, [sp, #32]
    mov x0, sp
    bl _mac_background_paint
    add sp, sp, #128
    LEAVE

.endif
