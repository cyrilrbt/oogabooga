.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// vm,operator,left,right -> value.
.globl _js_binary
_js_binary:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    cmp x20, #43
    b.ne Ljs_binary_equality
    cmp x21, #3
    b.ls Ljs_binary_right_string
    ldr x9, [x21]
    cmp x9, #JS_STRING
    b.eq Ljs_binary_concat
Ljs_binary_right_string:
    cmp x22, #3
    b.ls Ljs_binary_numeric
    ldr x9, [x22]
    cmp x9, #JS_STRING
    b.eq Ljs_binary_concat
    b Ljs_binary_numeric
Ljs_binary_equality:
    cmp x20, #T_EQ
    b.lo Ljs_binary_numeric
    cmp x20, #T_STRICT_NE
    b.hi Ljs_binary_numeric
    cmp x21, x22
    b.ne Ljs_equal_distinct
    cmp x21, #3
    b.ls Ljs_equal_yes
    ldr x9, [x21]
    cmp x9, #JS_NUMBER
    b.eq Ljs_binary_numeric
    b Ljs_equal_yes
Ljs_equal_distinct:
    cmp x21, #3
    b.ls Ljs_equal_small
    cmp x22, #3
    b.ls Ljs_equal_different
    ldr x9, [x21]
    ldr x10, [x22]
    cmp x9, x10
    b.ne Ljs_equal_different
    cmp x9, #JS_NUMBER
    b.eq Ljs_binary_numeric
    cmp x9, #JS_STRING
    b.ne Ljs_equal_no
    ldr x0, [x21, #8]
    ldr x1, [x22, #8]
    bl _strcmp
    cbz x0, Ljs_equal_yes
    b Ljs_equal_no
Ljs_equal_small:
    cmp x20, #T_STRICT_EQ
    b.hs Ljs_equal_no
    cmp x21, #1
    b.hi Ljs_equal_different
    cmp x22, #1
    b.ls Ljs_equal_yes
Ljs_equal_different:
    cmp x20, #T_STRICT_EQ
    b.hs Ljs_equal_no
    // Abstract equality is initially limited to primitive numeric coercions.
    cmp x21, #3
    b.ls Ljs_equal_primitive_right
    ldr x9, [x21]
    cmp x9, #JS_STRING
    b.hi Ljs_equal_no
Ljs_equal_primitive_right:
    cmp x22, #3
    b.ls Ljs_binary_numeric
    ldr x9, [x22]
    cmp x9, #JS_STRING
    b.hi Ljs_equal_no
Ljs_binary_numeric:
    mov x0, x21
    bl _js_to_number
    str d0, [sp, #144]
    mov x0, x22
    bl _js_to_number
    fmov d1, d0
    ldr d0, [sp, #144]
    cmp x20, #43
    b.eq Ljs_add
    cmp x20, #45
    b.eq Ljs_sub
    cmp x20, #42
    b.eq Ljs_mul
    cmp x20, #47
    b.eq Ljs_div
    cmp x20, #37
    b.eq Ljs_mod
    fcmp d0, d1
    b.vs Ljs_equal_no
    cset x24, eq
    cset x25, lt
    cset x26, gt
    cset x27, le
    cset x28, ge
    cmp x20, #T_EQ
    b.eq Ljs_compare_equal
    cmp x20, #T_NE
    b.eq Ljs_compare_equal
    cmp x20, #T_STRICT_EQ
    b.eq Ljs_compare_equal
    cmp x20, #T_STRICT_NE
    b.eq Ljs_compare_equal
    cmp x20, #60
    b.eq Ljs_compare_lt
    cmp x20, #62
    b.eq Ljs_compare_gt
    cmp x20, #T_LE
    b.eq Ljs_compare_le
    mov x23, x28
    b Ljs_boolean
Ljs_compare_lt:
    mov x23, x25
    b Ljs_boolean
Ljs_compare_gt:
    mov x23, x26
    b Ljs_boolean
Ljs_compare_le:
    mov x23, x27
    b Ljs_boolean
Ljs_compare_equal:
    mov x23, x24
    b Ljs_equal_invert
Ljs_equal_yes:
    mov x23, #1
    b Ljs_equal_invert
Ljs_equal_no:
    mov x23, #0
Ljs_equal_invert:
    cmp x20, #T_NE
    b.eq Ljs_equal_not
    cmp x20, #T_STRICT_NE
    b.ne Ljs_boolean
Ljs_equal_not:
    eor x23, x23, #1
Ljs_boolean:
    add x0, x23, #2
    LEAVE
Ljs_add:
    fadd d0, d0, d1
    b Ljs_numeric_result
Ljs_sub:
    fsub d0, d0, d1
    b Ljs_numeric_result
Ljs_mul:
    fmul d0, d0, d1
    b Ljs_numeric_result
Ljs_div:
    fdiv d0, d0, d1
    b Ljs_numeric_result
Ljs_mod:
    bl _fmod
Ljs_numeric_result:
    mov x0, x19
    bl _js_number
    LEAVE
Ljs_binary_concat:
    mov x0, x19
    mov x1, x21
    bl _js_to_string
    mov x21, x0
    mov x0, x19
    mov x1, x22
    bl _js_to_string
    mov x22, x0
    cbz x21, Ljs_concat_bad
    cbz x22, Ljs_concat_bad
    ldr x9, [x21, #16]
    ldr x10, [x22, #16]
    add x23, x9, x10
    mov x0, x19
    add x1, x23, #1
    bl _js_alloc
    cbz x0, Ljs_concat_bad
    mov x24, x0
    ldr x1, [x21, #8]
    ldr x2, [x21, #16]
    bl _memcpy
    ldr x9, [x21, #16]
    add x0, x24, x9
    ldr x1, [x22, #8]
    ldr x2, [x22, #16]
    bl _memcpy
    mov x0, x19
    mov x1, x24
    mov x2, x23
    bl _js_string
    LEAVE
Ljs_concat_bad:
    mov x0, #0
    LEAVE
.globl _js_unary
_js_unary:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    cmp x20, #513
    b.eq Ljs_typeof
    cmp x20, #33
    b.eq Ljs_not
    mov x0, x21
    bl _js_to_number
    cmp x20, #45
    b.ne Ljs_unary_number
    fneg d0, d0
Ljs_unary_number:
    mov x0, x19
    bl _js_number
    LEAVE
Ljs_not:
    mov x0, x21
    bl _js_truth
    eor x0, x0, #1
    add x0, x0, #2
    LEAVE
Ljs_typeof:
    ADDR x1, js_type_undefined
    cbz x21, Ljs_type_string
    ADDR x1, js_type_object
    cmp x21, #1
    b.eq Ljs_type_string
    ADDR x1, js_type_boolean
    cmp x21, #3
    b.ls Ljs_type_string
    ldr x9, [x21]
    ADDR x1, js_type_number
    cmp x9, #JS_NUMBER
    b.eq Ljs_type_string
    ADDR x1, js_type_string_text
    cmp x9, #JS_STRING
    b.eq Ljs_type_string
    ADDR x1, js_type_function
    cmp x9, #JS_FUNCTION
    b.eq Ljs_type_string
    cmp x9, #JS_NATIVE
    b.eq Ljs_type_string
    ADDR x1, js_type_object
Ljs_type_string:
    mov x0, x19
    bl _js_cstring
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_type_undefined: .asciz "undefined"
js_type_boolean: .asciz "boolean"
js_type_object: .asciz "object"
js_type_number: .asciz "number"
js_type_string_text: .asciz "string"
js_type_function: .asciz "function"
