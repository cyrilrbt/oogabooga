.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// vm,native id,receiver -> bound native function value.
.globl _js_bound
_js_bound:
    ENTER
    mov x19, x1
    mov x20, x2
    mov x1, #JS_NATIVE
    bl _js_value
    cbz x0, Ljs_bound_done
    str x19, [x0, #8]
    str x20, [x0, #16]
Ljs_bound_done:
    LEAVE
// vm,receiver,property name -> value.
.globl _js_get
_js_get:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    cmp x20, #3
    b.ls Ljs_get_bad
    ldr x22, [x20]
    cmp x22, #JS_OBJECT
    b.eq Ljs_get_property
    cmp x22, #JS_ARRAY
    b.eq Ljs_get_array
    cmp x22, #JS_STRING
    b.eq Ljs_get_string
    cmp x22, #JS_NATIVE
    b.eq Ljs_get_native_properties
    cmp x22, #JS_NODE
    b.eq Ljs_get_dom
    cmp x22, #JS_DOCUMENT
    b.eq Ljs_get_dom
    cmp x22, #JS_STYLE
    b.eq Ljs_get_dom
    cmp x22, #JS_CLASSES
    b.eq Ljs_get_dom
    cmp x22, #JS_PROMISE
    b.eq Ljs_get_promise
    cmp x22, #JS_RESPONSE
    b.eq Ljs_get_response
    mov x0, #0
    LEAVE
Ljs_get_native_properties:
    ldr x20, [x20, #24]
    cbz x20, Ljs_get_none
Ljs_get_property:
    mov x0, x20
    mov x1, x21
    bl _js_property
    cbz x0, Ljs_get_none
    ldr x0, [x0, #8]
    LEAVE
Ljs_get_array:
    mov x0, x21
    ADDR x1, js_length_key
    bl _strcmp
    cbz x0, Ljs_get_array_length
    mov x0, x21
    ADDR x1, js_push_key
    bl _strcmp
    cbnz x0, Ljs_get_property
    mov x1, #19
    b Ljs_get_bound
Ljs_get_array_length:
    mov x0, x19
    ldr x1, [x20, #16]
    bl _js_integer
    LEAVE
Ljs_get_string:
    mov x0, x21
    ADDR x1, js_length_key
    bl _strcmp
    cbnz x0, Ljs_get_none
    // Count UTF-16 code units, including surrogate pairs, matching DOM APIs.
    ldr x9, [x20, #8]
    ldr x10, [x20, #16]
    add x10, x10, x9
    mov x1, #0
Ljs_string_units:
    cmp x9, x10
    b.hs Ljs_string_units_done
    ldrb w11, [x9], #1
    and w12, w11, #0xc0
    cmp w12, #0x80
    b.eq Ljs_string_units
    add x1, x1, #1
    cmp w11, #0xf0
    b.lo Ljs_string_units
    add x1, x1, #1
    b Ljs_string_units
Ljs_string_units_done:
    mov x0, x19
    bl _js_integer
    LEAVE
Ljs_get_dom:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _js_dom_get
    LEAVE
Ljs_get_promise:
    mov x0, x21
    ADDR x1, js_then_key
    bl _strcmp
    cbz x0, Ljs_get_then
    mov x0, x21
    ADDR x1, js_catch_key
    bl _strcmp
    cbnz x0, Ljs_get_none
    mov x1, #31
    b Ljs_get_bound
Ljs_get_then:
    mov x1, #30
    b Ljs_get_bound
Ljs_get_response:
    mov x0, x21
    ADDR x1, js_text_key
    bl _strcmp
    cbz x0, Ljs_get_text
    mov x0, x21
    ADDR x1, js_json_key
    bl _strcmp
    cbz x0, Ljs_get_json
    mov x0, x21
    ADDR x1, js_status_key
    bl _strcmp
    cbz x0, Ljs_get_status
    mov x0, x21
    ADDR x1, js_ok_key
    bl _strcmp
    cbnz x0, Ljs_get_none
    ldr x9, [x20, #16]
    cmp x9, #200
    cset x10, hs
    cmp x9, #300
    cset x9, lo
    and x0, x9, x10
    add x0, x0, #2
    LEAVE
Ljs_get_status:
    mov x0, x19
    ldr x1, [x20, #16]
    bl _js_integer
    LEAVE
Ljs_get_text:
    mov x1, #32
    b Ljs_get_bound
Ljs_get_json:
    mov x1, #33
Ljs_get_bound:
    mov x0, x19
    mov x2, x20
    bl _js_bound
    LEAVE
Ljs_get_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
Ljs_get_none:
    mov x0, #0
    LEAVE
// vm,object,key,value -> assigned value.
.globl _js_set
_js_set:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    cmp x20, #3
    b.ls Ljs_set_bad
    ldr x23, [x20]
    cmp x23, #JS_OBJECT
    b.eq Ljs_set_object
    cmp x23, #JS_ARRAY
    b.eq Ljs_set_object
    cmp x23, #JS_NODE
    b.eq Ljs_set_dom
    cmp x23, #JS_DOCUMENT
    b.eq Ljs_set_dom
    cmp x23, #JS_STYLE
    b.ne Ljs_set_bad
Ljs_set_dom:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    bl _js_dom_set
    LEAVE
Ljs_set_object:
    mov x0, x20
    mov x1, x21
    bl _js_property
    cbz x0, Ljs_set_create
    ldr x9, [x0, #24]
    cbnz x9, Ljs_set_bad
Ljs_set_create:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    mov x4, #0
    bl _js_property_set
    cmp x23, #JS_ARRAY
    b.ne Ljs_set_done
    mov x0, x21
    add x1, sp, #144
    mov x2, #10
    bl _strtol
    cmp x0, #255
    b.hi Ljs_set_done
    ldr x9, [sp, #144]
    cmp x9, x21
    b.eq Ljs_set_done
    ldrb w9, [x9]
    cbnz w9, Ljs_set_done
    ldr x9, [x20, #16]
    add x0, x0, #1
    cmp x0, x9
    csel x0, x0, x9, hi
    str x0, [x20, #16]
Ljs_set_done:
    mov x0, x22
    LEAVE
Ljs_set_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_length_key: .asciz "length"
js_push_key: .asciz "push"
js_then_key: .asciz "then"
js_catch_key: .asciz "catch"
js_text_key: .asciz "text"
js_json_key: .asciz "json"
js_status_key: .asciz "status"
js_ok_key: .asciz "ok"
