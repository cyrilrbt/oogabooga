.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// vm,node,operation(15 add/16 remove/17 toggle/18 contains),token,force,argc.
.globl _js_class_op
_js_class_op:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x1, x22
    bl _js_to_string
    cbz x0, Ljs_class_op_done
    mov x22, x0
    ldr x0, [x22, #8]
    ldr x9, [x22, #16]
    cbz x9, Ljs_class_op_bad
    cmp x9, #256
    b.hi Ljs_class_op_bad
    mov x10, #0
Ljs_class_token_valid:
    cmp x10, x9
    b.hs Ljs_class_load
    ldrb w11, [x0, x10]
    cmp w11, #32
    b.ls Ljs_class_op_bad
    add x10, x10, #1
    b Ljs_class_token_valid
Ljs_class_load:
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    ADDR x2, js_classes_attr
    bl _engine_dom_get_attribute
    mov x25, x0
    mov x26, x1
    ldr x1, [x22, #8]
    bl _js_class_contains
    mov x27, x0
    cmp x21, #18
    b.eq Ljs_class_op_boolean
    mov x28, #1
    cmp x21, #16
    b.eq Ljs_class_remove_value
    cmp x21, #17
    b.ne Ljs_class_edit
    eor x28, x27, #1
    cmp x24, #2
    b.lo Ljs_class_edit
    mov x0, x23
    bl _js_truth
    mov x28, x0
    b Ljs_class_edit
Ljs_class_remove_value:
    mov x28, #0
Ljs_class_edit:
    cmp x27, x28
    b.eq Ljs_class_edit_done
    mov x0, x19
    ldr x9, [x22, #16]
    add x1, x26, x9
    add x1, x1, #3
    bl _js_alloc
    cbz x0, Ljs_class_op_done
    mov x23, x0
    mov x24, #0
    cbz x25, Ljs_class_append
Ljs_class_edit_next:
    ldrb w9, [x25]
    cbz w9, Ljs_class_append
    cmp w9, #32
    b.hi Ljs_class_word_start
    add x25, x25, #1
    b Ljs_class_edit_next
Ljs_class_word_start:
    mov x26, x25
Ljs_class_word_end:
    ldrb w9, [x25]
    cmp w9, #32
    b.ls Ljs_class_word_match
    add x25, x25, #1
    b Ljs_class_word_end
Ljs_class_word_match:
    sub x9, x25, x26
    ldr x10, [x22, #16]
    cmp x9, x10
    b.ne Ljs_class_word_copy
    mov x0, x26
    ldr x1, [x22, #8]
    mov x2, x9
    bl _memcmp
    cbz x0, Ljs_class_edit_next
Ljs_class_word_copy:
    cbz x24, Ljs_class_word_bytes
    mov w9, #32
    strb w9, [x23, x24]
    add x24, x24, #1
Ljs_class_word_bytes:
    add x0, x23, x24
    mov x1, x26
    sub x2, x25, x26
    add x24, x24, x2
    bl _memcpy
    b Ljs_class_edit_next
Ljs_class_append:
    cbz x28, Ljs_class_save
    cbz x24, Ljs_class_append_bytes
    mov w9, #32
    strb w9, [x23, x24]
    add x24, x24, #1
Ljs_class_append_bytes:
    add x0, x23, x24
    ldr x1, [x22, #8]
    ldr x2, [x22, #16]
    add x24, x24, x2
    bl _memcpy
Ljs_class_save:
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    ADDR x2, js_classes_attr
    mov x3, x23
    mov x4, x24
    bl _engine_dom_set_attribute
    cbnz x0, Ljs_class_op_bad
    mov x9, #1
    str x9, [x19, #JS_DOM_DIRTY]
Ljs_class_edit_done:
    mov x27, x28
Ljs_class_op_boolean:
    add x0, x27, #2
Ljs_class_op_done:
    LEAVE
Ljs_class_op_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_classes_attr: .asciz "class"
