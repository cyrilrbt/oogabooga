.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
.globl _js_bootstrap
_js_bootstrap:
    ENTER
    mov x19, x0
    ldr x20, [x19, #JS_ENV]
    // Global primitives and aliases are immutable bindings.
    mov x21, #0
    ADDR x22, js_primitive_names
Ljs_bootstrap_primitive:
    mov x0, x19
    mov x1, x20
    ldr x2, [x22, x21, lsl #3]
    mov x3, x21
    mov x4, #1
    bl _js_property_set
    add x21, x21, #1
    cmp x21, #4
    b.lo Ljs_bootstrap_primitive
    mov x0, x19
    mov x1, #JS_DOCUMENT
    bl _js_value
    cbz x0, Ljs_bootstrap_done
    mov x9, #1
    str x9, [x0, #8]
    str x9, [x19, #JS_READY]
    str x0, [x19, #JS_DOCUMENT_VALUE]
    mov x21, x0
    mov x0, x19
    mov x1, #1
    mov x2, #1
    bl _js_control_record
    cbz x0, Ljs_bootstrap_done
    str x21, [x0, #40]
    mov x3, x21
    mov x0, x19
    mov x1, x20
    ADDR x2, js_global_document
    mov x4, #1
    bl _js_property_set
    mov x0, x19
    mov x1, x20
    ADDR x2, js_global_window
    mov x3, x20
    mov x4, #1
    bl _js_property_set
    mov x0, x19
    mov x1, x20
    ADDR x2, js_global_globalthis
    mov x3, x20
    mov x4, #1
    bl _js_property_set
    ADDR x21, js_global_methods
Ljs_bootstrap_function:
    ldr x22, [x21]
    cbz x22, Ljs_bootstrap_namespaces
    ldr x1, [x21, #8]
    mov x0, x19
    ldr x2, [x19, #JS_DOCUMENT_VALUE]
    bl _js_bound
    mov x3, x0
    mov x0, x19
    mov x1, x20
    mov x2, x22
    mov x4, #1
    bl _js_property_set
    add x21, x21, #16
    b Ljs_bootstrap_function
Ljs_bootstrap_namespaces:
    ADDR x21, js_namespaces
Ljs_namespace_next:
    ldr x22, [x21]
    cbz x22, Ljs_bootstrap_done
    mov x0, x19
    mov x1, #JS_OBJECT
    bl _js_value
    mov x23, x0
    mov x26, x23
    ldr x1, [x21, #16]
    cbz x1, Ljs_namespace_bind_global
    mov x0, x19
    mov x2, x23
    bl _js_bound
    mov x26, x0
    str x23, [x26, #24]
Ljs_namespace_bind_global:
    mov x3, x26
    mov x0, x19
    mov x1, x20
    mov x2, x22
    mov x4, #1
    bl _js_property_set
    ldr x24, [x21, #8]
Ljs_namespace_method:
    ldr x25, [x24]
    cbz x25, Ljs_namespace_advance
    mov x0, x19
    ldr x1, [x24, #8]
    mov x2, x23
    bl _js_bound
    mov x3, x0
    mov x0, x19
    mov x1, x23
    mov x2, x25
    mov x4, #1
    bl _js_property_set
    add x24, x24, #16
    b Ljs_namespace_method
Ljs_namespace_advance:
    add x21, x21, #24
    b Ljs_namespace_next
Ljs_bootstrap_done:
    LEAVE
// vm,bound native,argv,argc -> value. No application/platform callback is
// callable from JS; only these explicitly enumerated operations exist.
.globl _js_native
_js_native:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x20, #16]
    ldr x24, [x20, #8]
    ldr x25, [x21]
    cmp x24, #19
    b.eq Ljs_native_push
    cmp x24, #20
    b.eq Ljs_native_string
    cmp x24, #21
    b.eq Ljs_native_number
    cmp x24, #22
    b.eq Ljs_native_boolean
    cmp x24, #23
    b.eq Ljs_native_log
    cmp x24, #24
    b.hs Ljs_native_async_or_extra
    cmp x24, #13
    b.eq Ljs_native_prevent
    cmp x24, #14
    b.eq Ljs_native_stop
    cmp x24, #15
    b.hs Ljs_native_class
    cmp x24, #1
    b.eq Ljs_native_getid
    cmp x24, #2
    b.eq Ljs_native_query
    cmp x24, #3
    b.eq Ljs_native_query
    cmp x24, #4
    b.eq Ljs_native_create
    cmp x24, #5
    b.eq Ljs_native_create
    cmp x24, #6
    b.eq Ljs_native_append
    cmp x24, #7
    b.eq Ljs_native_remove
    cmp x24, #8
    b.eq Ljs_native_set_attribute
    cmp x24, #9
    b.eq Ljs_native_get_attribute
    cmp x24, #10
    b.eq Ljs_native_remove_attribute
    cmp x24, #11
    b.eq Ljs_native_listener
    cmp x24, #12
    b.eq Ljs_native_unlistener
    b Ljs_native_bad
Ljs_native_string:
    mov x0, x19
    mov x1, x25
    cbnz x22, Ljs_native_string_arg
    ADDR x1, js_native_empty
    bl _js_cstring
    LEAVE
Ljs_native_string_arg:
    bl _js_to_string
    LEAVE
Ljs_native_number:
    mov x0, x25
    cbnz x22, Ljs_native_number_arg
    mov x0, #1
Ljs_native_number_arg:
    bl _js_to_number
    mov x0, x19
    bl _js_number
    LEAVE
Ljs_native_boolean:
    mov x0, x25
    bl _js_truth
    add x0, x0, #2
    LEAVE
Ljs_native_log:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    str x0, [x19, #JS_LAST_LOG]
    b Ljs_native_undefined
Ljs_native_push:
    mov x26, #0
Ljs_native_push_next:
    cmp x26, x22
    b.hs Ljs_native_push_done
    mov x0, x19
    mov x1, x23
    ldr x2, [x21, x26, lsl #3]
    bl _js_array_push
    add x26, x26, #1
    b Ljs_native_push_next
Ljs_native_push_done:
    mov x0, x19
    ldr x1, [x23, #16]
    bl _js_integer
    LEAVE
Ljs_native_getid:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x1, [x0, #8]
    ldr x0, [x19, #JS_DOM]
    bl _engine_dom_get_element_by_id
    mov x1, x0
    mov x0, x19
    bl _js_node
    LEAVE
Ljs_native_query:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x2, [x0, #8]
    mov x0, x19
    ldr x1, [x23, #8]
    cmp x24, #3
    cset x3, eq
    bl _js_query
    LEAVE
Ljs_native_create:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x1, [x0, #8]
    ldr x2, [x0, #16]
    ldr x0, [x19, #JS_DOM]
    cmp x24, #5
    b.eq Ljs_native_create_text
    bl _engine_dom_create_element
    b Ljs_native_created
Ljs_native_create_text:
    bl _engine_dom_create_text
Ljs_native_created:
    mov x1, x0
    mov x0, x19
    bl _js_node
    LEAVE
Ljs_native_append:
    cmp x25, #3
    b.ls Ljs_native_bad
    ldr x9, [x25]
    cmp x9, #JS_NODE
    b.ne Ljs_native_bad
    ldr x0, [x19, #JS_DOM]
    ldr x1, [x23, #8]
    ldr x2, [x25, #8]
    mov x3, #0
    bl _engine_dom_insert_before
    cbnz x0, Ljs_native_bad
    mov x9, #1
    str x9, [x19, #JS_DOM_DIRTY]
    mov x0, x25
    LEAVE
Ljs_native_remove:
    ldr x0, [x19, #JS_DOM]
    ldr x1, [x23, #8]
    bl _engine_dom_remove
    cbnz x0, Ljs_native_bad
    b Ljs_native_dom_changed
Ljs_native_set_attribute:
    cmp x22, #2
    b.lo Ljs_native_bad
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x26, [x0, #8]
    mov x0, x19
    ldr x1, [x21, #8]
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x3, [x0, #8]
    ldr x4, [x0, #16]
    ldr x0, [x19, #JS_DOM]
    ldr x1, [x23, #8]
    mov x2, x26
    bl _engine_dom_set_attribute
    cbnz x0, Ljs_native_bad
    b Ljs_native_dom_changed
Ljs_native_get_attribute:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x2, [x0, #8]
    ldr x0, [x19, #JS_DOM]
    ldr x1, [x23, #8]
    bl _engine_dom_get_attribute
    cbz x0, Ljs_native_null
    mov x2, x1
    mov x1, x0
    mov x0, x19
    bl _js_string
    LEAVE
Ljs_native_remove_attribute:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x2, [x0, #8]
    ldr x0, [x19, #JS_DOM]
    ldr x1, [x23, #8]
    bl _engine_dom_remove_attribute
    b Ljs_native_dom_changed
Ljs_native_listener:
    cmp x22, #2
    b.lo Ljs_native_bad
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x2, [x0, #8]
    mov x0, x19
    ldr x1, [x23, #8]
    ldr x3, [x21, #8]
    mov x4, #0
    ldr x9, [x21, #16]
    cmp x9, #3
    mov x10, #2
    csel x4, x10, x4, eq
    bl _js_listen
    b Ljs_native_undefined
Ljs_native_unlistener:
    cmp x22, #2
    b.lo Ljs_native_bad
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_native_undefined
    ldr x2, [x0, #8]
    mov x0, x19
    ldr x1, [x23, #8]
    ldr x3, [x21, #8]
    bl _js_unlisten
    b Ljs_native_undefined
Ljs_native_prevent:
    ldr x9, [x23, #16]
    orr x9, x9, #1
    str x9, [x23, #16]
    b Ljs_native_undefined
Ljs_native_stop:
    ldr x9, [x23, #16]
    orr x9, x9, #2
    str x9, [x23, #16]
    b Ljs_native_undefined
Ljs_native_class:
    mov x0, x19
    ldr x1, [x23, #8]
    mov x2, x24
    mov x3, x25
    ldr x4, [x21, #8]
    mov x5, x22
    bl _js_class_op
    LEAVE
Ljs_native_dom_changed:
    mov x9, #1
    str x9, [x19, #JS_DOM_DIRTY]
Ljs_native_undefined:
    mov x0, #0
    LEAVE
Ljs_native_null:
    mov x0, #1
    LEAVE
Ljs_native_async_or_extra:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    bl _js_async_native
    LEAVE
Ljs_native_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_native_empty: .asciz ""
js_global_undefined: .asciz "undefined"
js_global_null: .asciz "null"
js_global_false: .asciz "false"
js_global_true: .asciz "true"
js_global_document: .asciz "document"
js_global_window: .asciz "window"
js_global_globalthis: .asciz "globalThis"
js_global_string: .asciz "String"
js_global_number: .asciz "Number"
js_global_boolean: .asciz "Boolean"
js_global_timeout: .asciz "setTimeout"
js_global_clear: .asciz "clearTimeout"
js_global_interval: .asciz "setInterval"
js_global_clear_interval: .asciz "clearInterval"
js_global_microtask: .asciz "queueMicrotask"
js_global_fetch: .asciz "fetch"
js_global_promise_ctor: .asciz "Promise"
js_global_array_ctor: .asciz "Array"
js_global_object_ctor: .asciz "Object"
js_global_console: .asciz "console"
js_global_json: .asciz "JSON"
js_global_math: .asciz "Math"
js_native_log: .asciz "log"
js_native_parse: .asciz "parse"
js_native_floor: .asciz "floor"
js_native_abs: .asciz "abs"
js_native_resolve: .asciz "resolve"
js_native_reject: .asciz "reject"
js_native_array_is: .asciz "isArray"
js_native_object_keys: .asciz "keys"
js_native_listener_key: .asciz "addEventListener"
.section __DATA,__const
.p2align 3
js_primitive_names: .quad js_global_undefined,js_global_null,js_global_false,js_global_true
js_global_methods:
.quad js_global_string,20,js_global_number,21,js_global_boolean,22
.quad js_global_timeout,24,js_global_clear,25,js_global_microtask,26,js_global_fetch,27
.quad js_global_interval,48,js_global_clear_interval,25,js_native_listener_key,11
.quad 0,0
js_namespaces:
 .quad js_global_console,js_console_methods,0,js_global_json,js_json_methods,0,js_global_math,js_math_methods,0
.quad js_global_promise_ctor,js_promise_methods,34,js_global_array_ctor,js_array_methods,39,js_global_object_ctor,js_object_methods,40,0,0,0
js_console_methods: .quad js_native_log,23,0,0
js_json_methods: .quad js_native_parse,37,0,0
js_math_methods: .quad js_native_floor,41,js_native_abs,42,0,0

js_promise_methods: .quad js_native_resolve,28,js_native_reject,29,0,0
js_array_methods: .quad js_native_array_is,43,0,0
js_object_methods: .quad js_native_object_keys,44,0,0
