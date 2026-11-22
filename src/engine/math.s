// Bounded CSS dimension arithmetic. Runtime tokens retain containing-block
// percentages until layout; ownership follows the document's existing pool.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
// start,end -> owned raw token,valid. Only dimensions accept these tokens.
.globl _css_math_parse
_css_math_parse:
    ENTER
    mov x19, x0
    mov x20, x1
    sub x9, x20, x19
    cmp x9, #256
    b.hi Lmath_parse_bad
    cmp x9, #4
    b.lo Lmath_parse_bad
    // A math value must start with a function, not a bare arithmetic sequence.
    ldrb w9, [x19]
    orr w9, w9, #32
    cmp w9, #99
    b.eq Lmath_parse_validate
    cmp w9, #109
    b.ne Lmath_parse_bad
Lmath_parse_validate:
    sub sp, sp, #64
    mov x9, #16
    stp x9, x9, [sp]
    mov x9, #1000
    stp x9, x9, [sp, #16]
    str x9, [sp, #32]
    mov x0, sp
    mov x1, x19
    mov x2, x20
    mov x3, #0
    bl math_expr
    cmp x3, x20
    cset x9, eq
    and x21, x2, x9
    cmp x1, #1
    cset x9, eq
    and x21, x21, x9
    add sp, sp, #64
    cbz x21, Lmath_parse_bad
    mov x0, x19
    mov x1, x20
    bl _css_background_url_copy
    cbz x0, Lmath_parse_bad
    orr x0, x0, #0x2000000000000000
    orr x0, x0, #0x8000000000000000
    mov x1, #1
    LEAVE
Lmath_parse_bad:
    mov x0, #0
    mov x1, #0
    LEAVE
// raw token,parent,current,root -> computed token. Record is text,font,rem,vw,vh.
.globl _css_math_bind
_css_math_bind:
    ENTER
    sub sp, sp, #48
    and x0, x0, #0x1fffffffffffffff
    str x0, [sp]
    ldr x9, [x2, #48]
    str x9, [sp, #8]
    ldr x9, [x3, #48]
    str x9, [sp, #16]
    ldr x9, [x3, #856]
    str x9, [sp, #24]
    ldr x9, [x3, #1776]
    str x9, [sp, #32]
    mov x0, sp
    add x1, sp, #40
    bl _css_background_url_copy
    cbz x0, Lmath_bound
    orr x0, x0, #0x2000000000000000
Lmath_bound:
    add sp, sp, #48
    LEAVE
// computed token, containing dimension -> signed integer pixels.
.globl _css_math_resolve
_css_math_resolve:
    ENTER
    sub sp, sp, #48
    and x19, x0, #0x1fffffffffffffff
    str x1, [sp, #32]
    ldp x9, x10, [x19, #8]
    stp x9, x10, [sp]
    ldp x9, x10, [x19, #24]
    stp x9, x10, [sp, #16]
    ldr x20, [x19]
    mov x0, x20
    bl _strlen
    add x2, x20, x0
    mov x0, sp
    mov x1, x20
    mov x3, #0
    bl math_expr
    cbz x2, Lmath_resolve_bad
    mov x9, #500
    cmp x0, #0
    neg x10, x9
    csel x9, x10, x9, lt
    add x0, x0, x9
    mov x9, #1000
    sdiv x0, x0, x9
    mov x9, #16384
    cmp x0, x9
    csel x0, x9, x0, gt
    neg x9, x9
    cmp x0, x9
    csel x0, x9, x0, lt
    b Lmath_resolved
Lmath_resolve_bad:
    mov x0, #0
Lmath_resolved:
    add sp, sp, #48
    LEAVE
// ctx,start,end,depth -> fixed pixels/scalar,dimension,valid,next.
math_expr:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    bl math_product
    cbz x2, Lmath_expr_done
    mov x22, x0
    mov x23, x1
    mov x24, x3
Lmath_sum_next:
    mov x0, x24
    mov x1, x20
    bl _css_skip
    mov x24, x0
    cmp x24, x20
    b.hs Lmath_sum_done
    ldrb w25, [x24]
    cmp w25, #43
    b.eq Lmath_sum_rhs
    cmp w25, #45
    b.ne Lmath_sum_done
Lmath_sum_rhs:
    // CSS binary + and - require whitespace on both sides.
    ldrb w9, [x24, #-1]
    cmp w9, #32
    b.hi Lmath_expr_bad
    add x1, x24, #1
    cmp x1, x20
    b.hs Lmath_expr_bad
    ldrb w9, [x1]
    cmp w9, #32
    b.hi Lmath_expr_bad
    mov x0, x19
    mov x2, x20
    mov x3, x21
    bl math_product
    cbz x2, Lmath_expr_done
    cmp x1, x23
    b.ne Lmath_expr_bad
    cmp x25, #45
    b.ne Lmath_sum_add
    neg x0, x0
Lmath_sum_add:
    add x22, x22, x0
    mov x24, x3
    b Lmath_sum_next
Lmath_sum_done:
    mov x9, #0xca00
    movk x9, #0x3b9a, lsl #16
    cmp x22, x9
    b.gt Lmath_expr_bad
    neg x9, x9
    cmp x22, x9
    b.lt Lmath_expr_bad
    mov x0, x22
    mov x1, x23
    mov x2, #1
    mov x3, x24
Lmath_expr_done:
    LEAVE
Lmath_expr_bad:
    mov x2, #0
    LEAVE
math_product:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    bl math_atom
    cbz x2, Lmath_product_done
    mov x22, x0
    mov x23, x1
    mov x24, x3
Lmath_product_next:
    mov x0, x24
    mov x1, x20
    bl _css_skip
    mov x24, x0
    cmp x24, x20
    b.hs Lmath_product_good
    ldrb w25, [x24]
    cmp w25, #42
    b.eq Lmath_product_rhs
    cmp w25, #47
    b.ne Lmath_product_good
Lmath_product_rhs:
    mov x0, x19
    add x1, x24, #1
    mov x2, x20
    mov x3, x21
    bl math_atom
    cbz x2, Lmath_product_done
    cmp x25, #47
    b.eq Lmath_divide
    add x23, x23, x1
    cmp x23, #1
    b.hi Lmath_product_bad
    mul x22, x22, x0
    mov x9, #1000
    sdiv x22, x22, x9
    b Lmath_product_advance
Lmath_divide:
    cbnz x1, Lmath_product_bad
    cbz x0, Lmath_product_bad
    mov x9, #1000
    mul x22, x22, x9
    sdiv x22, x22, x0
Lmath_product_advance:
    // Bound intermediates, including repeated multiplication.
    mov x9, #0xca00
    movk x9, #0x3b9a, lsl #16
    cmp x22, x9
    b.gt Lmath_product_bad
    neg x9, x9
    cmp x22, x9
    b.lt Lmath_product_bad
    mov x24, x3
    b Lmath_product_next
Lmath_product_good:
    mov x0, x22
    mov x1, x23
    mov x2, #1
    mov x3, x24
Lmath_product_done:
    LEAVE
Lmath_product_bad:
    mov x2, #0
    LEAVE
math_atom:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    cmp x21, #8
    b.hs Lmath_atom_bad
    mov x0, x1
    mov x1, x20
    bl _css_skip
    mov x22, x0
    cmp x22, x20
    b.hs Lmath_atom_bad
    mov x23, #1
    ldrb w9, [x22]
    cmp w9, #45
    b.ne Lmath_atom_plus
    mov x23, #-1
    b Lmath_atom_sign
Lmath_atom_plus:
    cmp w9, #43
    b.ne Lmath_atom_begin
Lmath_atom_sign:
    add x22, x22, #1
    cmp x22, x20
    b.hs Lmath_atom_bad
Lmath_atom_begin:
    ldrb w9, [x22]
    cmp w9, #40
    b.eq Lmath_atom_paren
    cmp w9, #65
    b.hs Lmath_atom_function
    mov x24, x22
Lmath_atom_number_end:
    cmp x24, x20
    b.hs Lmath_atom_number
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lmath_atom_number
    cmp w9, #41
    b.eq Lmath_atom_number
    cmp w9, #44
    b.eq Lmath_atom_number
    cmp w9, #42
    b.eq Lmath_atom_number
    cmp w9, #47
    b.eq Lmath_atom_number
    add x24, x24, #1
    b Lmath_atom_number_end
Lmath_atom_number:
    mov x0, x22
    mov x1, x24
    bl _css_number
    cbz x2, Lmath_atom_done
    mov x3, x24
    cbz x1, Lmath_atom_value
    cmp x1, #1
    b.eq Lmath_atom_dimension
    cmp x1, #2
    b.eq Lmath_atom_em
    cmp x1, #4
    b.eq Lmath_atom_rem
    cmp x1, #3
    b.eq Lmath_atom_percent
    sub x9, x1, #5
    ldr x10, [x19, #16]
    ldr x11, [x19, #24]
    cmp x9, #0
    b.eq Lmath_atom_view
    mov x10, x11
    cmp x9, #1
    b.eq Lmath_atom_view
    ldr x10, [x19, #16]
    cmp x10, x11
    csel x12, x10, x11, lt
    csel x10, x10, x11, gt
    cmp x9, #2
    csel x10, x12, x10, eq
    b Lmath_atom_view
Lmath_atom_em:
    ldr x10, [x19]
    b Lmath_atom_scale
Lmath_atom_rem:
    ldr x10, [x19, #8]
    b Lmath_atom_scale
Lmath_atom_percent:
    ldr x10, [x19, #32]
Lmath_atom_view:
    mov x9, #100
    mul x0, x0, x10
    sdiv x0, x0, x9
    b Lmath_atom_dimension
Lmath_atom_scale:
    mul x0, x0, x10
Lmath_atom_dimension:
    mov x1, #1
Lmath_atom_value:
    mov x9, #0xca00
    movk x9, #0x3b9a, lsl #16
    cmp x0, x9
    b.gt Lmath_atom_bad
    mul x0, x0, x23
    mov x2, #1
    LEAVE
Lmath_atom_paren:
    mov x25, #0
    b Lmath_atom_arguments
Lmath_atom_function:
    mov x24, x22
Lmath_atom_name:
    cmp x24, x20
    b.hs Lmath_atom_bad
    ldrb w9, [x24]
    cmp w9, #40
    b.eq Lmath_atom_name_end
    add x24, x24, #1
    b Lmath_atom_name
Lmath_atom_name_end:
    mov x25, #0
    ADDR x26, math_names
Lmath_atom_name_try:
    mov x0, x22
    mov x1, x24
    ldr x2, [x26, x25, lsl #3]
    bl _css_eq
    cbnz x0, Lmath_atom_named
    add x25, x25, #1
    cmp x25, #4
    b.lo Lmath_atom_name_try
    b Lmath_atom_bad
Lmath_atom_named:
    mov x22, x24
Lmath_atom_arguments:
    mov x0, x19
    add x1, x22, #1
    mov x2, x20
    add x3, x21, #1
    bl math_expr
    cbz x2, Lmath_atom_done
    str x0, [sp, #144]
    str x1, [sp, #152]
    mov x24, #1
    mov x26, x0
    mov x27, x0
Lmath_atom_argument_next:
    cmp x3, x20
    b.hs Lmath_atom_bad
    ldrb w9, [x3]
    cmp w9, #41
    b.eq Lmath_atom_close
    cmp w9, #44
    b.ne Lmath_atom_bad
    cbz x25, Lmath_atom_bad
    mov x0, x19
    add x1, x3, #1
    mov x2, x20
    add x3, x21, #1
    bl math_expr
    cbz x2, Lmath_atom_done
    ldr x9, [sp, #152]
    cmp x1, x9
    b.ne Lmath_atom_bad
    add x24, x24, #1
    cmp x24, #32
    b.hi Lmath_atom_bad
    cmp x25, #3
    b.ne Lmath_atom_minmax
    cmp x24, #2
    b.ne Lmath_atom_clamp_high
    mov x27, x0
    b Lmath_atom_argument_next
Lmath_atom_clamp_high:
    cmp x0, x27
    csel x27, x0, x27, lt
    b Lmath_atom_argument_next
Lmath_atom_minmax:
    cmp x0, x26
    csel x10, x0, x26, lt
    csel x26, x0, x26, gt
    cmp x25, #1
    csel x26, x10, x26, eq
    b Lmath_atom_argument_next
Lmath_atom_close:
    cmp x25, #3
    b.ne Lmath_atom_not_clamp
    cmp x24, #3
    b.ne Lmath_atom_bad
    ldr x9, [sp, #144]
    cmp x9, x27
    csel x26, x9, x27, gt
    b Lmath_atom_close_good
Lmath_atom_not_clamp:
    cbnz x25, Lmath_atom_close_good
    cmp x24, #1
    b.ne Lmath_atom_bad
Lmath_atom_close_good:
    mov x0, x26
    mul x0, x0, x23
    ldr x1, [sp, #152]
    mov x2, #1
    add x3, x3, #1
    LEAVE
Lmath_atom_bad:
    mov x2, #0
Lmath_atom_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
math_calc: .asciz "calc"
math_min: .asciz "min"
math_max: .asciz "max"
math_clamp: .asciz "clamp"
.section __DATA,__const
.p2align 3
math_names: .quad math_calc,math_min,math_max,math_clamp
