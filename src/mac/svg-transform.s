.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_svg_transform
_mac_svg_transform:
    ENTER
    sub sp, sp, #128
    mov x19, x0                     // attrs start
    mov x20, x1
    mov x21, x2                     // CGContext
    ADDR x2, svg_transform_name
    bl _engine_attribute
    cbz x0, Ltransform_done
    mov x22, x0
    mov x23, x0
    bl _strlen
    add x24, x22, x0
    mov x28, #0
Ltransform_next:
    cmp x23, x24
    b.hs Ltransform_free
    add x28, x28, #1
    cmp x28, #32
    b.hi Ltransform_free
    ldrb w9, [x23]
    cmp w9, #32
    b.ls Ltransform_skip
    cmp w9, #44
    b.eq Ltransform_skip
    mov x25, x23
Ltransform_open:
    cmp x23, x24
    b.hs Ltransform_free
    ldrb w9, [x23], #1
    cmp w9, #40
    b.ne Ltransform_open
    sub x26, x23, #1
    mov x27, #0
Ltransform_number:
    cmp x27, #6
    b.hs Ltransform_close
    mov x0, x23
    mov x1, x24
    bl _svg_number
    cbz x1, Ltransform_close
    str d0, [sp, x27, lsl #3]
    add x27, x27, #1
    mov x23, x0
    b Ltransform_number
Ltransform_close:
    cmp x23, x24
    b.hs Ltransform_free
    ldrb w9, [x23], #1
    cmp w9, #32
    b.ls Ltransform_close
    cmp w9, #41
    b.ne Ltransform_free
    mov x0, x25
    mov x1, x26
    bl _css_trim
    stp x0, x1, [sp, #64]
    ADDR x2, svg_translate
    bl _css_eq
    cbnz w0, Ltransform_translate
    ldp x0, x1, [sp, #64]
    ADDR x2, svg_scale
    bl _css_eq
    cbnz w0, Ltransform_scale
    ldp x0, x1, [sp, #64]
    ADDR x2, svg_rotate
    bl _css_eq
    cbnz w0, Ltransform_rotate
    ldp x0, x1, [sp, #64]
    ADDR x2, svg_matrix
    bl _css_eq
    cbz w0, Ltransform_free
    cmp x27, #6
    b.ne Ltransform_free
    mov x0, x21
    mov x1, sp
    bl _CGContextConcatCTM
    b Ltransform_next
Ltransform_translate:
    cbz x27, Ltransform_free
    ldr d0, [sp]
    fmov d1, xzr
    cmp x27, #2
    b.lo Ltransform_translate_call
    ldr d1, [sp, #8]
Ltransform_translate_call:
    mov x0, x21
    bl _CGContextTranslateCTM
    b Ltransform_next
Ltransform_scale:
    cbz x27, Ltransform_free
    ldr d0, [sp]
    fmov d1, d0
    cmp x27, #2
    b.lo Ltransform_scale_call
    ldr d1, [sp, #8]
Ltransform_scale_call:
    mov x0, x21
    bl _CGContextScaleCTM
    b Ltransform_next
Ltransform_rotate:
    cbz x27, Ltransform_free
    cmp x27, #3
    b.lo Ltransform_rotate_call
    mov x0, x21
    ldp d0, d1, [sp, #8]
    bl _CGContextTranslateCTM
Ltransform_rotate_call:
    ldr d0, [sp]
    ADDR x9, svg_rotation_factor
    ldr d1, [x9]
    fmul d0, d0, d1
    mov x0, x21
    bl _CGContextRotateCTM
    cmp x27, #3
    b.lo Ltransform_next
    ldp d0, d1, [sp, #8]
    fneg d0, d0
    fneg d1, d1
    mov x0, x21
    bl _CGContextTranslateCTM
    b Ltransform_next
Ltransform_skip:
    add x23, x23, #1
    b Ltransform_next
Ltransform_free:
    mov x0, x22
    bl _free
Ltransform_done:
    add sp, sp, #128
    LEAVE
.section __DATA,__const
.p2align 3
svg_rotation_factor: .double 0.017453292519943295
.section __TEXT,__cstring,cstring_literals
svg_transform_name: .asciz "transform"
svg_translate: .asciz "translate"
svg_scale: .asciz "scale"
svg_rotate: .asciz "rotate"
svg_matrix: .asciz "matrix"
