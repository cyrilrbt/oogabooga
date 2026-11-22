// Cairo adapters for the shared assembly SVG scanner/path/shape implementation.
.include "src/gtk/gtk.inc"
.text
.globl _CGContextSaveGState
_CGContextSaveGState: b _cairo_save
.globl _CGContextRestoreGState
_CGContextRestoreGState: b _cairo_restore
.globl _CGContextTranslateCTM
_CGContextTranslateCTM: b _cairo_translate
.globl _CGContextScaleCTM
_CGContextScaleCTM: b _cairo_scale
.globl _CGContextRotateCTM
_CGContextRotateCTM: b _cairo_rotate
.globl _CGContextConcatCTM
_CGContextConcatCTM: b _cairo_transform
.globl _CGContextBeginPath
_CGContextBeginPath: b _cairo_new_path
.globl _CGContextClosePath
_CGContextClosePath: b _cairo_close_path
.globl _CGContextMoveToPoint
_CGContextMoveToPoint: b _cairo_move_to
.globl _CGContextAddLineToPoint
_CGContextAddLineToPoint: b _cairo_line_to
.globl _CGContextAddCurveToPoint
_CGContextAddCurveToPoint: b _cairo_curve_to
.globl _CGContextAddRect
_CGContextAddRect: b _cairo_rectangle
.globl _CGContextAddEllipseInRect
_CGContextAddEllipseInRect:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    bl _cairo_save
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    fmov d4, #0.5
    fmul d2, d2, d4
    fmul d3, d3, d4
    fadd d0, d0, d2
    fadd d1, d1, d3
    mov x0, x19
    bl _cairo_translate
    ldp d0, d1, [sp, #160]
    fmov d4, #0.5
    fmul d0, d0, d4
    fmul d1, d1, d4
    mov x0, x19
    bl _cairo_scale
    mov x0, x19
    fmov d0, xzr
    fmov d1, xzr
    fmov d2, #1.0
    fmov d3, xzr
    ADDR x9, gtk_svg_tau
    ldr d4, [x9]
    bl _cairo_arc
    mov x0, x19
    bl _cairo_restore
    LEAVE
.globl _CGContextAddQuadCurveToPoint
_CGContextAddQuadCurveToPoint:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    add x1, sp, #176
    add x2, sp, #184
    bl _cairo_get_current_point
    ldp d0, d1, [sp, #176]
    ldp d2, d3, [sp, #144]
    ADDR x9, gtk_svg_two_thirds
    ldr d6, [x9]
    fsub d2, d2, d0
    fsub d3, d3, d1
    fmul d2, d2, d6
    fmul d3, d3, d6
    fadd d0, d0, d2
    fadd d1, d1, d3
    ldp d4, d5, [sp, #160]
    ldp d2, d3, [sp, #144]
    fsub d2, d2, d4
    fsub d3, d3, d5
    fmul d2, d2, d6
    fmul d3, d3, d6
    fadd d2, d2, d4
    fadd d3, d3, d5
    mov x0, x19
    bl _cairo_curve_to
    LEAVE

// cairo,x/y/w/h/rx/ry -> rounded rectangle path, bounded radii.
.globl _gtk_cairo_rounded_rect
_gtk_cairo_rounded_rect:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    stp d0, d1, [sp]
    fadd d2, d0, d2
    fadd d3, d1, d3
    stp d2, d3, [sp, #16]
    fsub d6, d2, d0
    fsub d7, d3, d1
    fmov d16, #0.5
    fmul d6, d6, d16
    fmul d7, d7, d16
    fmin d4, d4, d6
    fmin d5, d5, d7
    stp d4, d5, [sp, #32]
    // Corner ellipse centers, clockwise from upper right.
    fsub d6, d2, d4
    fadd d7, d1, d5
    stp d6, d7, [sp, #48]
    fsub d7, d3, d5
    stp d6, d7, [sp, #64]
    fadd d6, d0, d4
    stp d6, d7, [sp, #80]
    fadd d7, d1, d5
    stp d6, d7, [sp, #96]
    fadd d0, d0, d4
    mov x0, x19
    bl _cairo_move_to
    mov x20, #0
Lgtk_rounded_corner:
    mov x0, x19
    bl _cairo_save
    add x9, sp, #48
    add x9, x9, x20, lsl #4
    ldp d0, d1, [x9]
    mov x0, x19
    bl _cairo_translate
    ldp d0, d1, [sp, #32]
    mov x0, x19
    bl _cairo_scale
    mov x0, x19
    fmov d0, xzr
    fmov d1, xzr
    fmov d2, #1.0
    sub x9, x20, #1
    scvtf d3, x9
    scvtf d4, x20
    ADDR x9, gtk_svg_half_pi
    ldr d5, [x9]
    fmul d3, d3, d5
    fmul d4, d4, d5
    bl _cairo_arc
    mov x0, x19
    bl _cairo_restore
    add x20, x20, #1
    cmp x20, #4
    b.lo Lgtk_rounded_corner
    mov x0, x19
    bl _cairo_close_path
    add sp, sp, #128
    LEAVE

.globl _gtk_svg_draw_path
_gtk_svg_draw_path:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x9, [x20, #48]
    ubfx x1, x9, #8, #2
    bl _cairo_set_line_cap
    mov x0, x19
    ldr x9, [x20, #48]
    ubfx x1, x9, #16, #2
    bl _cairo_set_line_join
    mov x0, x19
    ldr x1, [x20, #48]
    and x1, x1, #1
    bl _cairo_set_fill_rule
    ldr x1, [x20]
    cmn x1, #1
    b.eq Lgtk_svg_stroke
    mov x0, x19
    ldr d0, [x20, #24]
    ldr d1, [x20, #32]
    fmul d0, d0, d1
    bl gtk_svg_color
    mov x0, x19
    bl _cairo_fill_preserve
Lgtk_svg_stroke:
    ldr x1, [x20, #8]
    cmn x1, #1
    b.eq Lgtk_svg_empty
    mov x0, x19
    ldr d0, [x20, #24]
    ldr d1, [x20, #40]
    fmul d0, d0, d1
    bl gtk_svg_color
    mov x0, x19
    ldr d0, [x20, #16]
    bl _cairo_set_line_width
    mov x0, x19
    bl _cairo_stroke
    LEAVE
Lgtk_svg_empty:
    mov x0, x19
    bl _cairo_new_path
    LEAVE
// cairo,color,alpha -> encoded color source including SVG inherited opacity.
gtk_svg_color:
    fmov d3, d0
    mov x9, #255
    scvtf d4, x9
    tbz x1, #40, Lgtk_svg_rgb
    ubfx x9, x1, #32, #8
    scvtf d5, x9
    fdiv d5, d5, d4
    fmul d3, d3, d5
Lgtk_svg_rgb:
    ubfx x9, x1, #16, #8
    scvtf d0, x9
    ubfx x9, x1, #8, #8
    scvtf d1, x9
    and x9, x1, #255
    scvtf d2, x9
    fdiv d0, d0, d4
    fdiv d1, d1, d4
    fdiv d2, d2, d4
    b _cairo_set_source_rgba
.section __DATA,__const
.p2align 3
gtk_svg_tau: .double 6.283185307179586
gtk_svg_half_pi: .double 1.5707963267948966
gtk_svg_two_thirds: .double 0.6666666666666666
.text
.globl _CGContextClipToRect
_CGContextClipToRect:
    ENTER
    mov x19, x0
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_clip
    LEAVE
// pixbuf,cairo,destination rect -> draw exactly one image tile.
.globl _gtk_pixbuf_draw
_gtk_pixbuf_draw:
    ENTER
    mov x19, x0
    mov x20, x1
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x20
    bl _cairo_save
    mov x0, x20
    ldp d0, d1, [sp, #144]
    bl _cairo_translate
    mov x0, x19
    bl _gdk_pixbuf_get_width
    scvtf d0, x0
    str d0, [sp, #176]
    mov x0, x19
    bl _gdk_pixbuf_get_height
    scvtf d1, x0
    ldp d2, d3, [sp, #160]
    fdiv d1, d3, d1
    ldr d0, [sp, #176]
    fdiv d0, d2, d0
    mov x0, x20
    bl _cairo_scale
    mov x0, x20
    mov x1, x19
    fmov d0, xzr
    fmov d1, xzr
    bl _gdk_cairo_set_source_pixbuf
    mov x0, x20
    bl _cairo_paint
    mov x0, x20
    bl _cairo_restore
    LEAVE
