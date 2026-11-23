// Strict structural JSON parser. It shares tokenization, never bytecode/eval.
.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
.globl _js_json_parse
_js_json_parse:
    ENTER
    mov x19, x0
    cmp x1, #3
    b.ls Ljs_json_error
    ldr x9, [x1]
    cmp x9, #JS_STRING
    b.ne Ljs_json_error
    ldr x2, [x1, #16]
    ldr x1, [x1, #8]
    bl _js_lex
    cbz x0, Ljs_json_failed
    mov x0, x19
    mov x1, #0
    bl js_json_value
    mov x20, x0
    mov x0, x19
    bl _js_peek
    cbnz x0, Ljs_json_error
    mov x0, x20
    LEAVE
Ljs_json_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_json_failed:
    mov x0, #0
    LEAVE
js_json_value:
    ENTER
    mov x19, x0
    mov x20, x1
    cmp x20, #32
    b.hs Ljs_json_value_error
    bl _js_peek
    mov x21, x0
    mov x22, x1
    cmp x21, #T_STRING
    b.eq Ljs_json_string
    cmp x21, #T_NUMBER
    b.eq Ljs_json_number
    cmp x21, #45
    b.eq Ljs_json_negative
    cmp x21, #123
    b.eq Ljs_json_object
    cmp x21, #91
    b.eq Ljs_json_array
    cmp x21, #T_IDENT
    b.ne Ljs_json_value_error
    mov x23, x2
    mov x0, x23
    ADDR x1, js_json_true
    bl _strcmp
    cbz x0, Ljs_json_true_value
    mov x0, x23
    ADDR x1, js_json_false
    bl _strcmp
    cbz x0, Ljs_json_false_value
    mov x0, x23
    ADDR x1, js_json_null
    bl _strcmp
    cbnz x0, Ljs_json_value_error
    mov x22, #1
    b Ljs_json_literal
Ljs_json_true_value:
    mov x22, #3
    b Ljs_json_literal
Ljs_json_false_value:
    mov x22, #2
    b Ljs_json_literal
Ljs_json_string:
    ldr x9, [x19, #JS_TOKENS]
    ldr x10, [x19, #JS_POS]
    add x9, x9, x10, lsl #5
    ldr x9, [x9, #16]
    cmp x9, #34
    b.ne Ljs_json_value_error
    b Ljs_json_literal
Ljs_json_number:
    ldr x9, [x19, #JS_TOKENS]
    ldr x10, [x19, #JS_POS]
    add x9, x9, x10, lsl #5
    ldr x10, [x9, #16]
    ldr x11, [x9, #24]
    ldrb w12, [x11]
    cmp w12, #46
    b.eq Ljs_json_value_error
    cmp w12, #48
    b.ne Ljs_json_number_tail
    cmp x10, #1
    b.ls Ljs_json_literal
    ldrb w12, [x11, #1]
    sub w12, w12, #48
    cmp w12, #9
    b.ls Ljs_json_value_error
Ljs_json_number_tail:
    add x11, x11, x10
    ldrb w12, [x11, #-1]
    cmp w12, #46
    b.eq Ljs_json_value_error
Ljs_json_literal:
    mov x0, x19
    mov x1, x21
    bl _js_accept
    mov x0, x22
    LEAVE
Ljs_json_negative:
    mov x0, x19
    mov x1, #45
    bl _js_accept
    mov x0, x19
    bl _js_peek
    cmp x0, #T_NUMBER
    b.ne Ljs_json_value_error
    mov x0, x19
    add x1, x20, #1
    bl js_json_value
    mov x2, x0
    mov x0, x19
    mov x1, #45
    bl _js_unary
    LEAVE
Ljs_json_object:
    mov x23, #125
    mov x24, #JS_OBJECT
    b Ljs_json_container
Ljs_json_array:
    mov x23, #93
    mov x24, #JS_ARRAY
Ljs_json_container:
    mov x0, x19
    mov x1, x21
    bl _js_accept
    mov x0, x19
    mov x1, x24
    bl _js_value
    mov x25, x0
    mov x26, #0
    mov x0, x19
    mov x1, x23
    bl _js_accept
    cbnz x0, Ljs_json_container_done
Ljs_json_item:
    cmp x26, #256
    b.hs Ljs_json_value_error
    cmp x24, #JS_ARRAY
    b.eq Ljs_json_child_value
    mov x0, x19
    bl _js_peek
    cmp x0, #T_STRING
    b.ne Ljs_json_value_error
    mov x0, x19
    add x1, x20, #1
    bl js_json_value
    cbz x0, Ljs_json_value_error
    ldr x27, [x0, #8]
    mov x0, x19
    mov x1, #58
    bl _js_expect
Ljs_json_child_value:
    mov x0, x19
    add x1, x20, #1
    bl js_json_value
    mov x28, x0
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_json_value_failed
    mov x0, x19
    mov x1, x25
    cmp x24, #JS_ARRAY
    b.eq Ljs_json_array_item
    mov x2, x27
    mov x3, x28
    mov x4, #0
    bl _js_property_set
    b Ljs_json_item_done
Ljs_json_array_item:
    mov x2, x28
    bl _js_array_push
Ljs_json_item_done:
    add x26, x26, #1
    mov x0, x19
    mov x1, x23
    bl _js_accept
    cbnz x0, Ljs_json_container_done
    mov x0, x19
    mov x1, #44
    bl _js_expect
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_json_value_failed
    b Ljs_json_item
Ljs_json_container_done:
    mov x0, x25
    LEAVE
Ljs_json_value_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_json_value_failed:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_json_true: .asciz "true"
js_json_false: .asciz "false"
js_json_null: .asciz "null"
