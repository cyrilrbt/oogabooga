.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// Object own-property lookup; keys are owned VM strings.
.globl _js_property
_js_property:
    ENTER
    mov x19, x1
    cmp x0, #3
    b.ls Ljs_property_none
    ldr x20, [x0, #8]
Ljs_property_next:
    cbz x20, Ljs_property_none
    ldr x0, [x20]
    mov x1, x19
    bl _strcmp
    cbz x0, Ljs_property_found
    ldr x20, [x20, #16]
    b Ljs_property_next
Ljs_property_found:
    mov x0, x20
    LEAVE
Ljs_property_none:
    mov x0, #0
    LEAVE
// vm,object,key,value,flags -> property. Arena keys outlive all references.
.globl _js_property_set
_js_property_set:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x0, x20
    mov x1, x21
    bl _js_property
    cbnz x0, Ljs_property_update
    mov x0, x19
    mov x1, #32
    bl _js_alloc
    cbz x0, Ljs_property_set_done
    str x21, [x0]
    ldr x9, [x20, #8]
    cbz x9, Ljs_property_first
Ljs_property_tail:
    ldr x10, [x9, #16]
    cbz x10, Ljs_property_append
    mov x9, x10
    b Ljs_property_tail
Ljs_property_append:
    str x0, [x9, #16]
    b Ljs_property_flags
Ljs_property_first:
    str x0, [x20, #8]
Ljs_property_flags:
    str x23, [x0, #24]
Ljs_property_update:
    str x22, [x0, #8]
Ljs_property_set_done:
    LEAVE
// vm,environment,key -> value. Missing names report ReferenceError unless x3.
.globl _js_lookup
_js_lookup:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
Ljs_lookup_scope:
    mov x0, x20
    mov x1, x21
    bl _js_property
    cbnz x0, Ljs_lookup_found
    ldr x20, [x20, #24]
    cbnz x20, Ljs_lookup_scope
    cbnz x22, Ljs_lookup_undefined
    mov x9, #2
    str x9, [x19, #JS_ERROR]
Ljs_lookup_undefined:
    mov x0, #0
    LEAVE
Ljs_lookup_found:
    ldr x0, [x0, #8]
    LEAVE
// vm,environment,key,value,declare mode (0 assign,1 let,2 const,3 var).
.globl _js_assign
_js_assign:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    cmp x23, #0
    b.ne Ljs_declare
Ljs_assign_find:
    mov x0, x20
    mov x1, x21
    bl _js_property
    cbnz x0, Ljs_assign_property
    ldr x20, [x20, #24]
    cbnz x20, Ljs_assign_find
    mov x9, #2
    b Ljs_assign_error
Ljs_assign_property:
    ldr x9, [x0, #24]
    cbnz x9, Ljs_assign_readonly
    str x22, [x0, #8]
    b Ljs_assigned
Ljs_declare:
    cmp x23, #3
    b.ne Ljs_declare_here
    ldr x9, [x20, #16]
    cbnz x9, Ljs_declare_here
    ldr x9, [x20, #24]
    cbz x9, Ljs_declare_here
    mov x20, x9
    b Ljs_declare
Ljs_declare_here:
    mov x0, x20
    mov x1, x21
    bl _js_property
    cbz x0, Ljs_declare_create
    cmp x23, #3
    b.ne Ljs_assign_readonly
    b Ljs_assign_property
Ljs_declare_create:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    cmp x23, #2
    cset x4, eq
    bl _js_property_set
    b Ljs_assigned
Ljs_assign_readonly:
    mov x9, #4
Ljs_assign_error:
    str x9, [x19, #JS_ERROR]
Ljs_assigned:
    mov x0, x22
    LEAVE
// Value -> numeric double. String conversion is a bounded libc numeric parse;
// objects are not coerced through script-defined methods in this first VM.
.globl _js_to_number
_js_to_number:
    ENTER
    cmp x0, #3
    b.eq Ljs_numeric_one
    cmp x0, #1
    b.eq Ljs_numeric_zero
    cmp x0, #2
    b.eq Ljs_numeric_zero
    cmp x0, #3
    b.ls Ljs_numeric_nan
    ldr x9, [x0]
    cmp x9, #JS_NUMBER
    b.eq Ljs_numeric_value
    cmp x9, #JS_STRING
    b.ne Ljs_numeric_nan
    ldr x19, [x0, #8]
    ldr x9, [x0, #16]
    cbz x9, Ljs_numeric_zero
    mov x0, x19
    add x1, sp, #144
    bl _strtod
    ldr x9, [sp, #144]
    ldrb w9, [x9]
    cbnz w9, Ljs_numeric_nan
    LEAVE
Ljs_numeric_value:
    ldr d0, [x0, #8]
    LEAVE
Ljs_numeric_zero:
    fmov d0, xzr
    LEAVE
Ljs_numeric_one:
    fmov d0, #1.0
    LEAVE
Ljs_numeric_nan:
    fmov d0, xzr
    fdiv d0, d0, d0
    LEAVE
// vm,double -> decimal string. Bounded fixed six-decimal presentation for now;
// arithmetic itself retains binary64 precision. Full ECMA formatting is TODO.
.globl _js_number_string
_js_number_string:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    fcmp d0, d0
    b.vs Ljs_format_nan
    fmov x9, d0
    lsr x10, x9, #52
    and x10, x10, #0x7ff
    cmp x10, #0x7ff
    b.eq Ljs_format_infinity
    fmov d1, xzr
    fcmp d0, d1
    cset x20, lt
    fabs d0, d0
    fcvtzs x21, d0
    scvtf d1, x21
    fsub d0, d0, d1
    mov x9, #1000
    mul x9, x9, x9
    scvtf d1, x9
    fmul d0, d0, d1
    fmov d1, #0.5
    fadd d0, d0, d1
    fcvtzs x22, d0
    cmp x22, x9
    b.lo Ljs_format_digits
    mov x22, #0
    add x21, x21, #1
Ljs_format_digits:
    add x23, sp, #96
    mov x24, x23
    cbz x22, Ljs_format_integer
    mov x25, #6
Ljs_format_fraction:
    mov x9, #10
    udiv x10, x22, x9
    msub x11, x10, x9, x22
    add x11, x11, #48
    sub x23, x23, #1
    strb w11, [x23]
    mov x22, x10
    sub x25, x25, #1
    cbnz x25, Ljs_format_fraction
Ljs_format_trim:
    sub x9, x24, #1
    ldrb w10, [x9]
    cmp w10, #48
    b.ne Ljs_format_dot
    mov x24, x9
    b Ljs_format_trim
Ljs_format_dot:
    sub x23, x23, #1
    mov w9, #46
    strb w9, [x23]
Ljs_format_integer:
    mov x9, #10
    udiv x10, x21, x9
    msub x11, x10, x9, x21
    add x11, x11, #48
    sub x23, x23, #1
    strb w11, [x23]
    mov x21, x10
    cbnz x21, Ljs_format_integer
    cbz x20, Ljs_format_copy
    sub x23, x23, #1
    mov w9, #45
    strb w9, [x23]
Ljs_format_copy:
    mov x0, x19
    mov x1, x23
    sub x2, x24, x23
    bl _js_string
    b Ljs_formatted
Ljs_format_infinity:
    ADDR x1, js_positive_infinity
    tbz x9, #63, Ljs_format_infinity_copy
    ADDR x1, js_negative_infinity
Ljs_format_infinity_copy:
    mov x0, x19
    bl _js_cstring
    b Ljs_formatted
Ljs_format_nan:
    mov x0, x19
    ADDR x1, js_nan_text
    bl _js_cstring
Ljs_formatted:
    add sp, sp, #128
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_nan_text: .asciz "NaN"

js_positive_infinity: .asciz "Infinity"
js_negative_infinity: .asciz "-Infinity"
