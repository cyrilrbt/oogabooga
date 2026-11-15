// SVG path command interpretation in ARM64. CoreGraphics only draws geometry.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_svg_path
_mac_svg_path:
    ENTER
    sub sp, sp, #256
    mov x19, x0                     // CGContext
    mov x20, x1
    mov x21, x2
    mov x22, #0
    mov x23, #0
    mov x24, #0                     // previous command
    mov x27, #0
    mov x0, sp
    mov x1, #0
    mov x2, #128
    bl _memset
Lpath_next:
    cmp x20, x21
    b.hs Lpath_ok
    add x27, x27, #1
    cmp x27, #4096
    b.hs Lpath_bad
    ldrb w9, [x20]
    cmp w9, #32
    b.ls Lpath_skip
    cmp w9, #44
    b.eq Lpath_skip
    orr w10, w9, #32
    sub w11, w10, #97
    cmp w11, #25
    b.hi Lpath_repeat
    and x23, x9, #32
    mov x22, x10
    add x20, x20, #1
    cmp x22, #122
    b.eq Lpath_close
Lpath_repeat:
    mov x26, #0
    cmp x22, #109
    b.eq Lpath_pair
    cmp x22, #108
    b.eq Lpath_pair
    cmp x22, #116
    b.eq Lpath_pair
    cmp x22, #104
    b.eq Lpath_single
    cmp x22, #118
    b.eq Lpath_single
    cmp x22, #99
    b.eq Lpath_six
    cmp x22, #115
    b.eq Lpath_four
    cmp x22, #113
    b.eq Lpath_four
    cmp x22, #97
    b.eq Lpath_seven
    b Lpath_bad
Lpath_single:
    mov x26, #1
    b Lpath_read
Lpath_pair:
    mov x26, #2
    b Lpath_read
Lpath_four:
    mov x26, #4
    b Lpath_read
Lpath_six:
    mov x26, #6
    b Lpath_read
Lpath_seven:
    mov x26, #7
Lpath_read:
    mov x25, #0
Lpath_read_number:
    cmp x25, x26
    b.hs Lpath_execute
    mov x0, x20
    mov x1, x21
    bl _svg_number
    cbz x1, Lpath_bad
    mov x20, x0
    add x9, sp, #64
    str d0, [x9, x25, lsl #3]
    add x25, x25, #1
    b Lpath_read_number
Lpath_execute:
    cmp x22, #104
    b.eq Lpath_horizontal
    cmp x22, #118
    b.eq Lpath_vertical
    cmp x22, #97
    b.eq Lpath_arc
    cbz x23, Lpath_absolute
    mov x9, #0
Lpath_relative_pairs:
    cmp x9, x26
    b.hs Lpath_absolute
    add x10, sp, #64
    add x10, x10, x9, lsl #3
    ldp d0, d1, [x10]
    ldp d2, d3, [sp]
    fadd d0, d0, d2
    fadd d1, d1, d3
    stp d0, d1, [x10]
    add x9, x9, #2
    b Lpath_relative_pairs
Lpath_absolute:
    cmp x22, #109
    b.eq Lpath_move
    cmp x22, #108
    b.eq Lpath_line
    cmp x22, #99
    b.eq Lpath_cubic
    cmp x22, #115
    b.eq Lpath_smooth
    cmp x22, #113
    b.eq Lpath_quad
    b Lpath_smooth_quad
Lpath_move:
    ldp d0, d1, [sp, #64]
    stp d0, d1, [sp]
    stp d0, d1, [sp, #16]
    mov x0, x19
    bl _CGContextMoveToPoint
    mov x22, #108                   // repeated moveto pairs are lineto
    mov x24, #109
    b Lpath_next
Lpath_line:
    ldp d0, d1, [sp, #64]
Lpath_line_point:
    stp d0, d1, [sp]
    mov x0, x19
    bl _CGContextAddLineToPoint
    mov x24, x22
    b Lpath_next
Lpath_horizontal:
    ldr d0, [sp, #64]
    ldr d1, [sp, #8]
    cbz x23, Lpath_line_point
    ldr d2, [sp]
    fadd d0, d0, d2
    b Lpath_line_point
Lpath_vertical:
    ldr d0, [sp]
    ldr d1, [sp, #64]
    cbz x23, Lpath_line_point
    ldr d2, [sp, #8]
    fadd d1, d1, d2
    b Lpath_line_point
Lpath_cubic:
    ldp d0, d1, [sp, #64]
    ldp d2, d3, [sp, #80]
    ldp d4, d5, [sp, #96]
    stp d2, d3, [sp, #32]
    stp d4, d5, [sp]
    mov x0, x19
    bl _CGContextAddCurveToPoint
    mov x24, #99
    b Lpath_next
Lpath_smooth:
    ldp d0, d1, [sp]
    cmp x24, #99
    b.eq Lpath_reflect_cubic
    cmp x24, #115
    b.ne Lpath_smooth_cubic
Lpath_reflect_cubic:
    ldp d2, d3, [sp, #32]
    fadd d0, d0, d0
    fadd d1, d1, d1
    fsub d0, d0, d2
    fsub d1, d1, d3
Lpath_smooth_cubic:
    ldp d2, d3, [sp, #64]
    ldp d4, d5, [sp, #80]
    stp d2, d3, [sp, #32]
    stp d4, d5, [sp]
    mov x0, x19
    bl _CGContextAddCurveToPoint
    mov x24, #115
    b Lpath_next
Lpath_quad:
    ldp d0, d1, [sp, #64]
    ldp d2, d3, [sp, #80]
Lpath_quad_point:
    stp d0, d1, [sp, #48]
    stp d2, d3, [sp]
    mov x0, x19
    bl _CGContextAddQuadCurveToPoint
    mov x24, x22
    b Lpath_next
Lpath_smooth_quad:
    ldp d0, d1, [sp]
    cmp x24, #113
    b.eq Lpath_reflect_quad
    cmp x24, #116
    b.ne Lpath_smooth_quad_point
Lpath_reflect_quad:
    ldp d2, d3, [sp, #48]
    fadd d0, d0, d0
    fadd d1, d1, d1
    fsub d0, d0, d2
    fsub d1, d1, d3
Lpath_smooth_quad_point:
    ldp d2, d3, [sp, #64]
    b Lpath_quad_point
Lpath_arc:
    cbz x23, Lpath_arc_absolute
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #104]          // arc endpoint, params 5 and 6
    fadd d2, d2, d0
    fadd d3, d3, d1
    stp d2, d3, [sp, #104]
Lpath_arc_absolute:
    mov x0, x19
    mov x1, sp
    add x2, sp, #64
    bl _mac_svg_arc
    ldp d0, d1, [sp, #104]
    stp d0, d1, [sp]
    mov x24, #97
    b Lpath_next
Lpath_close:
    mov x0, x19
    bl _CGContextClosePath
    ldp d0, d1, [sp, #16]
    stp d0, d1, [sp]
    mov x22, #0
    mov x24, #122
    b Lpath_next
Lpath_skip:
    add x20, x20, #1
    b Lpath_next
Lpath_ok:
    mov x0, #1
    add sp, sp, #256
    LEAVE
Lpath_bad:
    mov x0, #0
    add sp, sp, #256
    LEAVE
