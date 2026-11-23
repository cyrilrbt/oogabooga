.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.include "src/engine/dom.inc"
.text
// class-list bytes,name -> true for an exact whitespace-delimited token.
.globl _js_class_contains
_js_class_contains:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x19, Ljs_class_no
    mov x0, x20
    bl _strlen
    mov x21, x0
Ljs_class_skip:
    ldrb w9, [x19]
    cbz w9, Ljs_class_no
    cmp w9, #32
    b.hi Ljs_class_start
    add x19, x19, #1
    b Ljs_class_skip
Ljs_class_start:
    mov x22, x19
Ljs_class_end:
    ldrb w9, [x19]
    cmp w9, #32
    b.ls Ljs_class_compare
    add x19, x19, #1
    b Ljs_class_end
Ljs_class_compare:
    sub x9, x19, x22
    cmp x9, x21
    b.ne Ljs_class_skip
    mov x0, x22
    mov x1, x20
    mov x2, x21
    bl _memcmp
    cbnz x0, Ljs_class_skip
    mov x0, #1
    LEAVE
Ljs_class_no:
    mov x0, #0
    LEAVE
// vm,root handle,selector,all -> node/null/array. Simple #id/.class/tag queries.
.globl _js_query
_js_query:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, #0
    ldrb w24, [x21]
    cmp w24, #35
    b.eq Ljs_query_prefixed
    cmp w24, #46
    b.eq Ljs_query_prefixed
    mov x24, #0
    b Ljs_query_validate
Ljs_query_prefixed:
    add x21, x21, #1
Ljs_query_validate:
    ldrb w9, [x21]
    cbz w9, Ljs_query_bad
    mov x9, x21
Ljs_query_validate_next:
    ldrb w10, [x9], #1
    cbz w10, Ljs_query_valid
    cmp w10, #32
    b.ls Ljs_query_bad
    cmp w10, #35
    b.eq Ljs_query_bad
    cmp w10, #46
    b.eq Ljs_query_bad
    cmp w10, #58
    b.eq Ljs_query_bad
    cmp w10, #91
    b.eq Ljs_query_bad
    cmp w10, #62
    b.eq Ljs_query_bad
    cmp w10, #44
    b.eq Ljs_query_bad
    b Ljs_query_validate_next
Ljs_query_valid:
    cbz x22, Ljs_query_begin
    mov x0, x19
    mov x1, #JS_ARRAY
    bl _js_value
    mov x23, x0
Ljs_query_begin:
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    bl _engine_dom_node
    cbz x0, Ljs_query_end
    ldr x25, [x0, #16]
Ljs_query_next:
    cbz x25, Ljs_query_end
    // Stop once preorder leaves this root's descendant set.
    mov x26, x25
    mov x27, #64
Ljs_query_ancestor:
    cmp x26, x20
    b.eq Ljs_query_candidate
    cbz x26, Ljs_query_end
    cbz x27, Ljs_query_end
    sub x27, x27, #1
    ldr x0, [x19, #JS_DOM]
    mov x1, x26
    bl _engine_dom_node
    cbz x0, Ljs_query_end
    ldr x26, [x0, #8]
    b Ljs_query_ancestor
Ljs_query_candidate:
    ldr x0, [x19, #JS_DOM]
    mov x1, x25
    bl _engine_dom_node
    ldr x9, [x0]
    cmp x9, #DOM_ELEMENT
    b.ne Ljs_query_advance
    cmp x24, #35
    b.eq Ljs_query_id
    cmp x24, #46
    b.eq Ljs_query_class
    ldr x0, [x0, #48]
    mov x1, x21
    bl _strcasecmp
    cbz x0, Ljs_query_matched
    b Ljs_query_advance
Ljs_query_id:
    ADDR x2, js_query_id
    b Ljs_query_attribute
Ljs_query_class:
    ADDR x2, js_query_class
Ljs_query_attribute:
    ldr x0, [x19, #JS_DOM]
    mov x1, x25
    bl _engine_dom_get_attribute
    cbz x0, Ljs_query_advance
    mov x1, x21
    cmp x24, #46
    b.eq Ljs_query_class_match
    bl _strcmp
    cbz x0, Ljs_query_matched
    b Ljs_query_advance
Ljs_query_class_match:
    bl _js_class_contains
    cbz x0, Ljs_query_advance
Ljs_query_matched:
    mov x0, x19
    mov x1, x25
    bl _js_node
    cbz x22, Ljs_query_done
    mov x2, x0
    mov x0, x19
    mov x1, x23
    bl _js_array_push
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_query_end
Ljs_query_advance:
    ldr x0, [x19, #JS_DOM]
    mov x1, x25
    bl _engine_dom_next
    mov x25, x0
    b Ljs_query_next
Ljs_query_end:
    mov x0, #1
    cmp x22, #0
    csel x0, x23, x0, ne
Ljs_query_done:
    LEAVE
Ljs_query_bad:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
// vm,array,value -> numeric new length.
.globl _js_array_push
_js_array_push:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x20, #16]
    cmp x22, #256
    b.hs Ljs_array_full
    mov x1, x22
    bl _js_integer
    mov x1, x0
    mov x0, x19
    bl _js_to_string
    cbz x0, Ljs_array_push_done
    ldr x2, [x0, #8]
    mov x0, x19
    mov x1, x20
    mov x3, x21
    mov x4, #0
    bl _js_property_set
    add x22, x22, #1
    str x22, [x20, #16]
    mov x0, x19
    mov x1, x22
    bl _js_integer
Ljs_array_push_done:
    LEAVE
Ljs_array_full:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_query_id: .asciz "id"
js_query_class: .asciz "class"
