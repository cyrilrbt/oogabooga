.include "src/mac/mac.inc"
.text
.p2align 2
// A bounded SVG number token, including signs, decimals and exponents. strtod
// receives a small terminated copy, never the untrusted XML buffer directly.
.globl _svg_number
_svg_number:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    mov x20, x1
Lsvg_number_skip:
    cmp x19, x20
    b.hs Lsvg_number_bad
    ldrb w9, [x19]
    cmp w9, #32
    b.ls Lsvg_number_skip_one
    cmp w9, #44
    b.ne Lsvg_number_token
Lsvg_number_skip_one:
    add x19, x19, #1
    b Lsvg_number_skip
Lsvg_number_token:
    mov x21, #0
Lsvg_number_copy:
    add x9, x19, x21
    cmp x9, x20
    b.hs Lsvg_number_convert
    cmp x21, #95
    b.hs Lsvg_number_bad
    ldrb w10, [x9]
    sub w11, w10, #48
    cmp w11, #9
    b.ls Lsvg_number_byte
    cmp w10, #46
    b.eq Lsvg_number_byte
    cmp w10, #101
    b.eq Lsvg_number_byte
    cmp w10, #69
    b.eq Lsvg_number_byte
    cmp w10, #45
    b.eq Lsvg_number_sign
    cmp w10, #43
    b.ne Lsvg_number_convert
Lsvg_number_sign:
    cbz x21, Lsvg_number_byte
    sub x9, x21, #1
    ldrb w11, [sp, x9]
    orr w11, w11, #32
    cmp w11, #101
    b.ne Lsvg_number_convert
Lsvg_number_byte:
    strb w10, [sp, x21]
    add x21, x21, #1
    b Lsvg_number_copy
Lsvg_number_convert:
    cbz x21, Lsvg_number_bad
    strb wzr, [sp, x21]
    mov x0, sp
    add x1, sp, #104
    bl _strtod
    ldr x9, [sp, #104]
    mov x10, sp
    sub x9, x9, x10
    cbz x9, Lsvg_number_bad
    fcmp d0, d0
    b.vs Lsvg_number_bad
    fabs d1, d0
    mov x10, #1000
    mul x10, x10, x10
    scvtf d2, x10
    fcmp d1, d2
    b.hi Lsvg_number_bad
    add x0, x19, x9
    mov x1, #1
    add sp, sp, #128
    LEAVE
Lsvg_number_bad:
    mov x0, x19
    mov x1, #0
    fmov d0, xzr
    add sp, sp, #128
    LEAVE
