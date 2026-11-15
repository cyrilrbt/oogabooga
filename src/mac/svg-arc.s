// SVG endpoint arcs converted to bounded ellipse samples. No SVG/path parser is
// delegated to the platform; native graphics draws the resulting points.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_svg_arc
_mac_svg_arc:
    ENTER
    sub sp, sp, #256
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldp d0, d1, [x20]
    stp d0, d1, [sp]
    ldp d2, d3, [x21]
    fabs d2, d2
    fabs d3, d3
    stp d2, d3, [sp, #16]
    ldp d4, d5, [x21, #40]
    stp d4, d5, [sp, #56]
    ADDR x9, arc_epsilon
    ldr d6, [x9]
    fcmp d2, d6
    b.lt Larc_line
    fcmp d3, d6
    b.lt Larc_line
    fcmp d0, d4
    b.ne Larc_start
    fcmp d1, d5
    b.eq Larc_done
Larc_start:
    ldr d0, [x21, #16]
    ADDR x9, arc_degrees
    ldr d1, [x9]
    fmul d0, d0, d1
    str d0, [sp, #32]
    bl _cos
    str d0, [sp, #40]
    ldr d0, [sp, #32]
    bl _sin
    str d0, [sp, #48]
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #56]
    fsub d0, d0, d2
    fsub d1, d1, d3
    fmov d4, #0.5
    fmul d0, d0, d4
    fmul d1, d1, d4
    ldr d2, [sp, #40]
    ldr d3, [sp, #48]
    fmul d4, d0, d2
    fmadd d4, d1, d3, d4
    fmul d5, d1, d2
    fmul d6, d0, d3
    fsub d5, d5, d6
    stp d4, d5, [sp, #72]
    ldp d0, d1, [sp, #16]
    fdiv d2, d4, d0
    fdiv d3, d5, d1
    fmul d2, d2, d2
    fmadd d2, d3, d3, d2
    fmov d3, #1.0
    fcmp d2, d3
    b.le Larc_center
    fsqrt d2, d2
    fmul d0, d0, d2
    fmul d1, d1, d2
    stp d0, d1, [sp, #16]
Larc_center:
    ldp d0, d1, [sp, #16]
    ldp d2, d3, [sp, #72]
    fmul d4, d0, d0
    fmul d5, d1, d1
    fmul d6, d2, d2
    fmul d7, d3, d3
    fmul d6, d6, d5
    fmadd d6, d7, d4, d6          // denominator
    fmul d7, d4, d5
    fsub d7, d7, d6
    fdiv d7, d7, d6
    fmov d4, xzr
    fmax d7, d7, d4
    fsqrt d7, d7
    ldr d4, [x21, #24]
    ldr d5, [x21, #32]
    fcmp d4, #0.0
    cset w9, ne
    fcmp d5, #0.0
    cset w10, ne
    cmp w9, w10
    b.ne Larc_coefficient
    fneg d7, d7
Larc_coefficient:
    fmul d4, d0, d3
    fdiv d4, d4, d1
    fmul d4, d4, d7               // cx'
    fmul d5, d1, d2
    fdiv d5, d5, d0
    fmul d5, d5, d7
    fneg d5, d5                  // cy'
    stp d4, d5, [sp, #128]
    ldr d6, [sp, #40]
    ldr d7, [sp, #48]
    fmul d0, d4, d6
    fmul d1, d5, d7
    fsub d0, d0, d1
    fmul d1, d4, d7
    fmadd d1, d5, d6, d1
    ldp d2, d3, [sp]
    ldp d4, d5, [sp, #56]
    fadd d2, d2, d4
    fadd d3, d3, d5
    fmov d4, #0.5
    fmadd d0, d2, d4, d0
    fmadd d1, d3, d4, d1
    stp d0, d1, [sp, #88]
    ldp d0, d1, [sp, #72]
    ldp d2, d3, [sp, #128]
    fsub d0, d0, d2
    fsub d1, d1, d3
    ldp d4, d5, [sp, #16]
    fdiv d6, d0, d4
    fdiv d0, d1, d5
    fmov d1, d6
    bl _atan2
    str d0, [sp, #104]
    ldp d0, d1, [sp, #72]
    fneg d0, d0
    fneg d1, d1
    ldp d2, d3, [sp, #128]
    fsub d0, d0, d2
    fsub d1, d1, d3
    ldp d4, d5, [sp, #16]
    fdiv d6, d0, d4
    fdiv d0, d1, d5
    fmov d1, d6
    bl _atan2
    ldr d1, [sp, #104]
    fsub d0, d0, d1
    ldr d2, [x21, #32]
    fcmp d2, #0.0
    b.eq Larc_negative_sweep
    fcmp d0, #0.0
    b.ge Larc_delta
    ADDR x9, arc_two_pi
    ldr d1, [x9]
    fadd d0, d0, d1
    b Larc_delta
Larc_negative_sweep:
    fcmp d0, #0.0
    b.le Larc_delta
    ADDR x9, arc_two_pi
    ldr d1, [x9]
    fsub d0, d0, d1
Larc_delta:
    NUM d1, 64
    fdiv d0, d0, d1
    str d0, [sp, #120]
    mov x22, #1
Larc_sample:
    cmp x22, #64
    b.hs Larc_line
    ldr d0, [sp, #120]
    scvtf d1, x22
    ldr d2, [sp, #104]
    fmadd d0, d0, d1, d2
    str d0, [sp, #144]
    bl _cos
    str d0, [sp, #152]
    ldr d0, [sp, #144]
    bl _sin
    ldr d1, [sp, #152]
    ldp d2, d3, [sp, #16]
    fmul d1, d1, d2
    fmul d0, d0, d3
    ldr d2, [sp, #40]
    ldr d3, [sp, #48]
    fmul d4, d1, d2
    fmul d5, d0, d3
    fsub d4, d4, d5
    fmul d5, d1, d3
    fmadd d5, d0, d2, d5
    ldp d0, d1, [sp, #88]
    fadd d0, d0, d4
    fadd d1, d1, d5
    mov x0, x19
    bl _CGContextAddLineToPoint
    add x22, x22, #1
    b Larc_sample
Larc_line:
    ldp d0, d1, [sp, #56]
    mov x0, x19
    bl _CGContextAddLineToPoint
Larc_done:
    add sp, sp, #256
    LEAVE
.section __DATA,__const
.p2align 3
arc_epsilon: .double 0.000001
arc_degrees: .double 0.017453292519943295
arc_two_pi: .double 6.2831853071795864769
