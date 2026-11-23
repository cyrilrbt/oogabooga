.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// vm,camelCase name -> owned CSS kebab-case string, <=128 bytes.
js_style_name:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x1, #129
    bl _js_alloc
    cbz x0, Ljs_style_name_done
    mov x21, x0
    mov x22, #0
Ljs_style_name_next:
    ldrb w9, [x20], #1
    cbz w9, Ljs_style_name_end
    cmp x22, #126
    b.hs Ljs_style_name_bad
    sub w10, w9, #65
    cmp w10, #25
    b.hi Ljs_style_name_emit
    mov w10, #45
    strb w10, [x21, x22]
    add x22, x22, #1
    add w9, w9, #32
Ljs_style_name_emit:
    strb w9, [x21, x22]
    add x22, x22, #1
    b Ljs_style_name_next
Ljs_style_name_end:
    mov x0, x21
Ljs_style_name_done:
    LEAVE
Ljs_style_name_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
// vm,handle,key,value -> set a CSS declaration without interpreting it as HTML.
.globl _js_style_set
_js_style_set:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x1, x21
    bl js_style_name
    mov x21, x0
    cbz x0, Ljs_style_set_done
    mov x0, x19
    mov x1, x22
    bl _js_to_string
    mov x22, x0
    cbz x0, Ljs_style_set_done
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    ADDR x2, js_style_key
    bl _engine_dom_get_attribute
    mov x23, x0
    mov x24, x1
    mov x0, x21
    bl _strlen
    mov x25, x0
    ldr x9, [x22, #16]
    add x26, x24, x25
    add x26, x26, x9
    add x26, x26, #3
    mov x0, x19
    add x1, x26, #1
    bl _js_alloc
    cbz x0, Ljs_style_set_done
    mov x27, x0
    cbz x24, Ljs_style_copy_name
    mov x1, x23
    mov x2, x24
    bl _memcpy
Ljs_style_copy_name:
    add x0, x27, x24
    mov w9, #59
    strb w9, [x0], #1
    mov x1, x21
    mov x2, x25
    bl _memcpy
    add x9, x24, x25
    add x9, x9, #1
    add x0, x27, x9
    mov w9, #58
    strb w9, [x0], #1
    ldr x1, [x22, #8]
    ldr x2, [x22, #16]
    bl _memcpy
    sub x9, x26, #1
    mov w10, #59
    strb w10, [x27, x9]
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    ADDR x2, js_style_key
    mov x3, x27
    mov x4, x26
    bl _engine_dom_set_attribute
    cbnz x0, Ljs_style_set_error
    mov x9, #1
    str x9, [x19, #JS_DOM_DIRTY]
    b Ljs_style_set_done
Ljs_style_set_error:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
Ljs_style_set_done:
    LEAVE
// Return the last raw declaration value. Nested functions/quoted semicolons
// are skipped with a bounded delimiter scanner, not split on arbitrary bytes.
.globl _js_style_get
_js_style_get:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x1, x2
    bl js_style_name
    mov x21, x0
    cbz x0, Ljs_style_get_done
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    ADDR x2, js_style_key
    bl _engine_dom_get_attribute
    mov x22, x0
    add x23, x0, x1
    ADDR x24, js_style_empty
    mov x25, x24
    cbz x22, Ljs_style_result
Ljs_style_decl:
    mov x0, x22
    mov x1, x23
    bl _css_skip
    mov x22, x0
    cmp x22, x23
    b.hs Ljs_style_result
    ldrb w9, [x22]
    cmp w9, #59
    b.ne Ljs_style_decl_name
    add x22, x22, #1
    b Ljs_style_decl
Ljs_style_decl_name:
    mov x26, x22
Ljs_style_colon:
    cmp x26, x23
    b.hs Ljs_style_result
    ldrb w9, [x26]
    cmp w9, #58
    b.eq Ljs_style_decl_value
    add x26, x26, #1
    b Ljs_style_colon
Ljs_style_decl_value:
    mov x0, x22
    mov x1, x26
    bl _css_trim
    mov x2, x21
    bl _css_eq
    str x0, [sp, #144]
    add x22, x26, #1
    mov x26, x22
    mov x27, #0
    mov x28, #0
Ljs_style_value_end:
    cmp x26, x23
    b.hs Ljs_style_value_ready
    ldrb w9, [x26]
    cbz x28, Ljs_style_unquoted
    cmp w9, #92
    b.ne Ljs_style_quote_end
    add x26, x26, #1
    b Ljs_style_value_advance
Ljs_style_quote_end:
    cmp w9, w28
    b.ne Ljs_style_value_advance
    mov x28, #0
    b Ljs_style_value_advance
Ljs_style_unquoted:
    cmp w9, #34
    b.eq Ljs_style_quoted
    cmp w9, #39
    b.eq Ljs_style_quoted
    cmp w9, #40
    b.ne Ljs_style_close
    add x27, x27, #1
    b Ljs_style_value_advance
Ljs_style_close:
    cmp w9, #41
    b.ne Ljs_style_semicolon
    sub x27, x27, #1
Ljs_style_semicolon:
    cbnz x27, Ljs_style_value_advance
    cmp w9, #59
    b.eq Ljs_style_value_ready
    b Ljs_style_value_advance
Ljs_style_quoted:
    mov x28, x9
Ljs_style_value_advance:
    add x26, x26, #1
    b Ljs_style_value_end
Ljs_style_value_ready:
    ldr x9, [sp, #144]
    cbz x9, Ljs_style_next_decl
    mov x0, x22
    mov x1, x26
    bl _css_trim
    mov x24, x0
    mov x25, x1
Ljs_style_next_decl:
    add x22, x26, #1
    b Ljs_style_decl
Ljs_style_result:
    mov x0, x19
    mov x1, x24
    sub x2, x25, x24
    bl _js_string
Ljs_style_get_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_style_key: .asciz "style"
js_style_empty: .asciz ""
