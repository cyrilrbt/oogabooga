.include "src/mac/mac.inc"
.text
.p2align 2
// CGContext, attrs start/end, shape kind, inherited paint state.
.globl _mac_svg_shape
_mac_svg_shape:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    ldr x9, [x23, #56]
    cbnz x9, Lshape_done
    mov x0, x19
    bl _CGContextBeginPath
    cmp x22, #1
    b.eq Lshape_path
    cmp x22, #6
    b.hs Lshape_points
    mov x24, #0
    cmp x22, #2
    b.eq Lshape_rect_attrs
    cmp x22, #5
    b.eq Lshape_line_attrs
    ADDR x25, svg_ellipse_attrs
    b Lshape_attribute
Lshape_rect_attrs:
    ADDR x25, svg_rect_attrs
    b Lshape_attribute
Lshape_line_attrs:
    ADDR x25, svg_line_attrs
Lshape_attribute:
    cmp x24, #6
    b.hs Lshape_geometry
    ldr x2, [x25, x24, lsl #3]
    cbz x2, Lshape_geometry
    fmov d0, xzr
    cmp x22, #2
    b.ne Lshape_attr_get
    cmp x24, #5
    b.ne Lshape_attr_get
    ldr d0, [sp, #32]             // ry defaults to rx
Lshape_attr_get:
    mov x0, x20
    mov x1, x21
    bl _svg_attribute_number
    str d0, [sp, x24, lsl #3]
    add x24, x24, #1
    b Lshape_attribute
Lshape_geometry:
    cmp x22, #5
    b.eq Lshape_line
    cmp x22, #2
    b.eq Lshape_rect
    // cx cy rx ry r: circles use r, ellipses use rx/ry.
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #16]
    cmp x22, #3
    b.ne Lshape_ellipse
    ldr d2, [sp, #32]
    fmov d3, d2
Lshape_ellipse:
    fcmp d2, #0.0
    b.le Lshape_done
    fcmp d3, #0.0
    b.le Lshape_done
    fsub d0, d0, d2
    fsub d1, d1, d3
    fadd d2, d2, d2
    fadd d3, d3, d3
    mov x0, x19
    bl _CGContextAddEllipseInRect
    b Lshape_draw
Lshape_rect:
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #16]
    fcmp d2, #0.0
    b.le Lshape_done
    fcmp d3, #0.0
    b.le Lshape_done
    ldp d4, d5, [sp, #32]
    fcmp d4, #0.0
    b.gt Lshape_rounded_rect
    mov x0, x19
    bl _CGContextAddRect
    b Lshape_draw
Lshape_rounded_rect:
    bl _CGPathCreateMutable
    mov x26, x0
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #16]
    ldp d4, d5, [sp, #32]
    fmov d6, #0.5
    fmul d7, d2, d6
    fmin d4, d4, d7
    fmul d7, d3, d6
    fmin d5, d5, d7
    mov x1, #0
    bl _CGPathAddRoundedRect
    mov x0, x19
    mov x1, x26
    bl _CGContextAddPath
    mov x0, x26
    bl _CGPathRelease
    b Lshape_draw
Lshape_line:
    mov x0, x19
    ldp d0, d1, [sp]
    bl _CGContextMoveToPoint
    mov x0, x19
    ldp d0, d1, [sp, #16]
    bl _CGContextAddLineToPoint
    b Lshape_draw
Lshape_path:
    mov x0, x20
    mov x1, x21
    ADDR x2, svg_path_data
    bl _engine_attribute
    cbz x0, Lshape_done
    mov x24, x0
    bl _strlen
    add x2, x24, x0
    mov x1, x24
    mov x0, x19
    bl _mac_svg_path
    mov x25, x0
    mov x0, x24
    bl _free
    cbz x25, Lshape_done
    b Lshape_draw
Lshape_points:
    mov x0, x20
    mov x1, x21
    ADDR x2, svg_points
    bl _engine_attribute
    cbz x0, Lshape_done
    mov x24, x0
    mov x25, x0
    bl _strlen
    add x26, x24, x0
    mov x27, #0
Lshape_point_next:
    cmp x25, x26
    b.hs Lshape_points_end
    cmp x27, #2048
    b.hs Lshape_points_end
    mov x0, x25
    mov x1, x26
    bl _svg_number
    cbz x1, Lshape_points_end
    str d0, [sp]
    mov x1, x26
    bl _svg_number
    cbz x1, Lshape_points_end
    mov x25, x0
    fmov d1, d0
    ldr d0, [sp]
    mov x0, x19
    cbnz x27, Lshape_point_line
    bl _CGContextMoveToPoint
    b Lshape_point_added
Lshape_point_line:
    bl _CGContextAddLineToPoint
Lshape_point_added:
    add x27, x27, #1
    b Lshape_point_next
Lshape_points_end:
    mov x0, x24
    bl _free
    cmp x22, #7
    b.ne Lshape_draw
    mov x0, x19
    bl _CGContextClosePath
Lshape_draw:
    mov x0, x19
    mov x1, x23
    bl _mac_svg_draw_path
Lshape_done:
    add sp, sp, #128
    LEAVE
.section __DATA,__const
.p2align 3
svg_rect_attrs: .quad svg_x,svg_y,svg_width,svg_height,svg_rx,svg_ry
svg_ellipse_attrs: .quad svg_cx,svg_cy,svg_rx,svg_ry,svg_r,0
svg_line_attrs: .quad svg_x1,svg_y1,svg_x2,svg_y2,0,0
.section __TEXT,__cstring,cstring_literals
svg_path_data: .asciz "d"
svg_points: .asciz "points"
svg_x: .asciz "x"
svg_y: .asciz "y"
svg_width: .asciz "width"
svg_height: .asciz "height"
svg_rx: .asciz "rx"
svg_ry: .asciz "ry"
svg_cx: .asciz "cx"
svg_cy: .asciz "cy"
svg_r: .asciz "r"
svg_x1: .asciz "x1"
svg_y1: .asciz "y1"
svg_x2: .asciz "x2"
svg_y2: .asciz "y2"
