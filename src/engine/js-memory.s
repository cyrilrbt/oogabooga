// Arena ownership makes navigation teardown deterministic. Exhaustion is an
// explicit VM error; no language operation can allocate beyond the page budget.
.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
.globl _js_alloc
_js_alloc:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_alloc_fail
    ldr x9, [x19, #JS_BYTES]
    add x21, x9, x20
    add x21, x21, #16
    mov x10, #JS_MAX_HEAP
    cmp x21, x10
    b.hi Ljs_alloc_error
    mov x0, #1
    add x1, x20, #16
    bl _calloc
    cbz x0, Ljs_alloc_error
    ldr x9, [x19, #JS_HEAP]
    str x9, [x0]
    str x0, [x19, #JS_HEAP]
    str x21, [x19, #JS_BYTES]
    add x0, x0, #16
    LEAVE
Ljs_alloc_error:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
Ljs_alloc_fail:
    mov x0, #0
    LEAVE
.globl _js_value
_js_value:
    ENTER
    mov x19, x1
    mov x1, #32
    bl _js_alloc
    cbz x0, Ljs_value_done
    str x19, [x0]
Ljs_value_done:
    LEAVE
// vm,bytes,length -> string value. Sources need not be NUL terminated.
.globl _js_string
_js_string:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x9, #JS_MAX_SOURCE
    cmp x21, x9
    b.hi Ljs_string_bad
    mov x1, #JS_STRING
    bl _js_value
    mov x22, x0
    cbz x0, Ljs_string_done
    mov x0, x19
    add x1, x21, #1
    bl _js_alloc
    cbz x0, Ljs_string_done
    str x0, [x22, #8]
    str x21, [x22, #16]
    mov x1, x20
    mov x2, x21
    bl _memcpy
    mov x0, x22
Ljs_string_done:
    LEAVE
Ljs_string_bad:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
// vm,zero-terminated bytes -> string.
.globl _js_cstring
_js_cstring:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x1
    bl _strlen
    mov x2, x0
    mov x1, x20
    mov x0, x19
    bl _js_string
    LEAVE
// vm,double -> number record.
.globl _js_number
_js_number:
    ENTER
    str d0, [sp, #144]
    mov x1, #JS_NUMBER
    bl _js_value
    cbz x0, Ljs_number_done
    ldr d0, [sp, #144]
    str d0, [x0, #8]
Ljs_number_done:
    LEAVE
.globl _js_integer
_js_integer:
    scvtf d0, x1
    b _js_number
// value -> boolean. NaN and both zero signs are false.
.globl _js_truth
_js_truth:
    cmp x0, #3
    b.eq Ljs_truth_yes
    b.lo Ljs_truth_no
    ldr x9, [x0]
    cmp x9, #JS_NUMBER
    b.eq Ljs_truth_number
    cmp x9, #JS_STRING
    b.ne Ljs_truth_yes
    ldr x9, [x0, #16]
    cbz x9, Ljs_truth_no
    b Ljs_truth_yes
Ljs_truth_number:
    ldr d0, [x0, #8]
    fcmp d0, #0.0
    b.eq Ljs_truth_no
    b.vs Ljs_truth_no
Ljs_truth_yes:
    mov x0, #1
    ret
Ljs_truth_no:
    mov x0, #0
    ret
// vm,value -> string (conversion is bounded, never executes user code).
.globl _js_to_string
_js_to_string:
    ENTER
    mov x19, x0
    mov x20, x1
    cmp x20, #3
    b.ls Ljs_small_string
    ldr x9, [x20]
    cmp x9, #JS_STRING
    b.eq Ljs_string_identity
    cmp x9, #JS_NUMBER
    b.eq Ljs_string_number
    ADDR x1, js_object_text
    b Ljs_string_literal
Ljs_small_string:
    ADDR x9, js_small_strings
    ldr x1, [x9, x20, lsl #3]
Ljs_string_literal:
    mov x0, x19
    bl _js_cstring
    LEAVE
Ljs_string_identity:
    mov x0, x20
    LEAVE
Ljs_string_number:
    // snprintf's floating vararg ABI differs on Darwin and System V. Use the
    // integer fast path here; decimal formatting has an explicit shared shim.
    mov x0, x19
    ldr d0, [x20, #8]
    bl _js_number_string
    LEAVE
.globl _engine_js_free
_engine_js_free:
    ENTER
    mov x19, x0
    cbz x19, Ljs_freed
    ldr x0, [x19, #JS_DOM]
    bl _engine_dom_free
    ldr x20, [x19, #JS_HEAP]
Ljs_free_next:
    cbz x20, Ljs_free_vm
    ldr x21, [x20]
    mov x0, x20
    bl _free
    mov x20, x21
    b Ljs_free_next
Ljs_free_vm:
    mov x0, x19
    bl _free
Ljs_freed:
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_undefined_text: .asciz "undefined"
js_null_text: .asciz "null"
js_false_text: .asciz "false"
js_true_text: .asciz "true"
js_object_text: .asciz "[object Object]"
.section __DATA,__const
.p2align 3
js_small_strings: .quad js_undefined_text,js_null_text,js_false_text,js_true_text
