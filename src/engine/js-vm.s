.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
.globl _engine_js_new
_engine_js_new:
    ENTER
    mov x19, x0
    mov x0, #1
    mov x1, #JS_SIZE
    bl _calloc
    cbz x0, Ljs_new_done
    mov x20, x0
    mov x0, x19
    bl _engine_dom_retain
    str x0, [x20, #JS_DOM]
    mov x0, x20
    mov x1, #262144
    bl _js_alloc
    str x0, [x20, #JS_CODE]
    mov x0, x20
    mov x1, #4096
    bl _js_alloc
    str x0, [x20, #JS_STACK]
    mov x0, x20
    mov x1, #JS_OBJECT
    bl _js_value
    cbz x0, Ljs_new_bad
    mov x9, #1
    str x9, [x0, #16]
    str x0, [x20, #JS_ENV]
    mov x0, x20
    bl _js_bootstrap
    ldr x9, [x20, #JS_ERROR]
    cbnz x9, Ljs_new_bad
    mov x0, x20
Ljs_new_done:
    LEAVE
Ljs_new_bad:
    mov x0, x20
    bl _engine_js_free
    mov x0, #0
    LEAVE
// vm,script,length -> result; inspect engine_js_error to distinguish undefined.
.globl _engine_js_eval
_engine_js_eval:
    ENTER
    mov x19, x0
    ldr x20, [x19, #JS_CODE_COUNT]
    str xzr, [x19, #JS_ERROR]
    str xzr, [x19, #JS_PARSE_DEPTH]
    str xzr, [x19, #JS_SOURCE_DEPTH]
    mov x9, #0x86a0
    movk x9, #1, lsl #16
    str x9, [x19, #JS_FUEL]
    bl _js_lex
    cbz x0, Ljs_eval_rollback
    mov x0, x19
    bl _js_compile
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_eval_rollback
    mov x0, x19
    mov x1, x20
    ldr x2, [x19, #JS_ENV]
    bl _js_execute
    mov x20, x0
    mov x0, x19
    bl _js_microtasks
    mov x0, x20
    LEAVE
Ljs_eval_rollback:
    str x20, [x19, #JS_CODE_COUNT]
    mov x0, #0
    LEAVE
.globl _engine_js_error
_engine_js_error:
    ldr x0, [x0, #JS_ERROR]
    ret
.globl _engine_js_global
_engine_js_global:
    mov x2, x1
    mov x3, #1
    ldr x1, [x0, #JS_ENV]
    b _js_lookup
.globl _js_push
_js_push:
    ldr x9, [x0, #JS_SP]
    cmp x9, #JS_MAX_STACK
    b.hs Ljs_stack_error
    ldr x10, [x0, #JS_STACK]
    str x1, [x10, x9, lsl #3]
    add x9, x9, #1
    str x9, [x0, #JS_SP]
    ret
.globl _js_pop
_js_pop:
    ldr x9, [x0, #JS_SP]
    cbz x9, Ljs_stack_error
    sub x9, x9, #1
    str x9, [x0, #JS_SP]
    ldr x10, [x0, #JS_STACK]
    ldr x0, [x10, x9, lsl #3]
    ret
Ljs_stack_error:
    mov x9, #3
    str x9, [x0, #JS_ERROR]
    mov x0, #0
    ret
.globl _js_execute
_js_execute:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #JS_SP]
    ldr x9, [x19, #JS_DEPTH]
    add x9, x9, #1
    str x9, [x19, #JS_DEPTH]
    cmp x9, #JS_MAX_DEPTH
    b.hi Ljs_execute_limit
Ljs_execute_next:
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_execute_failed
    ldr x9, [x19, #JS_FUEL]
    cbz x9, Ljs_execute_limit
    sub x9, x9, #1
    str x9, [x19, #JS_FUEL]
    ldr x9, [x19, #JS_CODE_COUNT]
    cmp x20, x9
    b.hs Ljs_execute_limit
    ldr x23, [x19, #JS_CODE]
    add x23, x23, x20, lsl #5
    add x20, x20, #1
    ldp x24, x25, [x23]
    cmp x24, #J_PUSH
    b.eq Ljs_execute_constant
    cmp x24, #J_LOAD
    b.eq Ljs_execute_load
    cmp x24, #J_STORE
    b.eq Ljs_execute_store
    cmp x24, #J_DECLARE
    b.eq Ljs_execute_store
    cmp x24, #J_GET
    b.eq Ljs_execute_get
    cmp x24, #J_SET
    b.eq Ljs_execute_set
    cmp x24, #J_INDEX
    b.eq Ljs_execute_index
    cmp x24, #J_PUT_INDEX
    b.eq Ljs_execute_put_index
    cmp x24, #J_CALL
    b.eq Ljs_execute_call
    cmp x24, #J_BINARY
    b.eq Ljs_execute_binary
    cmp x24, #J_UNARY
    b.eq Ljs_execute_unary
    cmp x24, #J_POP
    b.eq Ljs_execute_pop
    cmp x24, #J_DUP
    b.eq Ljs_execute_dup
    cmp x24, #J_JUMP
    b.eq Ljs_execute_jump
    cmp x24, #J_FALSE
    b.eq Ljs_execute_branch
    cmp x24, #J_TRUE
    b.eq Ljs_execute_branch
    cmp x24, #J_RETURN
    b.eq Ljs_execute_return
    cmp x24, #J_FUNCTION
    b.eq Ljs_execute_function
    cmp x24, #J_OBJECT
    b.eq Ljs_execute_object
    cmp x24, #J_ARRAY
    b.eq Ljs_execute_array
    cmp x24, #J_SCOPE
    b.eq Ljs_execute_scope
    cmp x24, #J_UNSCOPE
    b.eq Ljs_execute_unscope
    b Ljs_execute_limit
Ljs_execute_constant:
    mov x0, x25
    b Ljs_execute_push
Ljs_execute_load:
    mov x0, x19
    mov x1, x21
    mov x2, x25
    ldr x3, [x23, #16]
    bl _js_lookup
    b Ljs_execute_push
Ljs_execute_store:
    mov x0, x19
    bl _js_pop
    mov x3, x0
    mov x0, x19
    mov x1, x21
    mov x2, x25
    mov x4, #0
    cmp x24, #J_DECLARE
    b.ne Ljs_execute_assign
    ldr x4, [x23, #16]
Ljs_execute_assign:
    bl _js_assign
    b Ljs_execute_push
Ljs_execute_get:
    mov x0, x19
    bl _js_pop
    mov x1, x0
    mov x0, x19
    mov x2, x25
    bl _js_get
    b Ljs_execute_push
Ljs_execute_set:
    mov x0, x19
    bl _js_pop
    mov x26, x0
    mov x0, x19
    bl _js_pop
    mov x1, x0
    mov x0, x19
    mov x2, x25
    mov x3, x26
    bl _js_set
    b Ljs_execute_push
Ljs_execute_index:
    mov x0, x19
    bl _js_pop
    mov x1, x0
    mov x0, x19
    bl _js_to_string
    cbz x0, Ljs_execute_failed
    ldr x25, [x0, #8]
    b Ljs_execute_get
Ljs_execute_put_index:
    mov x0, x19
    bl _js_pop
    mov x26, x0
    mov x0, x19
    bl _js_pop
    mov x1, x0
    mov x0, x19
    bl _js_to_string
    cbz x0, Ljs_execute_failed
    ldr x25, [x0, #8]
    mov x0, x19
    mov x1, x26
    bl _js_push
    b Ljs_execute_set
Ljs_execute_call:
    cmp x25, #8
    b.hi Ljs_execute_limit
    ldr x9, [x19, #JS_SP]
    add x10, x25, #1
    cmp x9, x10
    b.lo Ljs_execute_limit
    sub x9, x9, x10
    ldr x10, [x19, #JS_STACK]
    add x10, x10, x9, lsl #3
    ldr x1, [x10]
    add x2, x10, #8
    mov x3, x25
    str x9, [x19, #JS_SP]
    mov x0, x19
    bl _js_call
    b Ljs_execute_push
Ljs_execute_binary:
    mov x0, x19
    bl _js_pop
    mov x26, x0
    mov x0, x19
    bl _js_pop
    mov x2, x0
    mov x0, x19
    mov x1, x25
    mov x3, x26
    bl _js_binary
    b Ljs_execute_push
Ljs_execute_unary:
    mov x0, x19
    bl _js_pop
    mov x2, x0
    mov x0, x19
    mov x1, x25
    bl _js_unary
    b Ljs_execute_push
Ljs_execute_pop:
    mov x0, x19
    bl _js_pop
    b Ljs_execute_next
Ljs_execute_dup:
    mov x0, x19
    bl _js_pop
    mov x26, x0
    mov x0, x19
    mov x1, x26
    bl _js_push
    mov x0, x26
    b Ljs_execute_push
Ljs_execute_jump:
    mov x20, x25
    b Ljs_execute_next
Ljs_execute_branch:
    mov x0, x19
    bl _js_pop
    bl _js_truth
    cmp x24, #J_FALSE
    b.eq Ljs_execute_false
    cbnz x0, Ljs_execute_jump
    b Ljs_execute_next
Ljs_execute_false:
    cbz x0, Ljs_execute_jump
    b Ljs_execute_next
Ljs_execute_return:
    mov x0, x19
    bl _js_pop
    b Ljs_execute_done
Ljs_execute_function:
    mov x0, x19
    mov x1, #JS_FUNCTION
    bl _js_value
    cbz x0, Ljs_execute_failed
    str x25, [x0, #8]
    str x21, [x0, #16]
    ldr x9, [x23, #16]
    str x9, [x0, #24]
    b Ljs_execute_push
Ljs_execute_array:
    mov x1, #JS_ARRAY
    b Ljs_execute_make_object
Ljs_execute_object:
    mov x1, #JS_OBJECT
Ljs_execute_make_object:
    mov x0, x19
    bl _js_value
    b Ljs_execute_push
Ljs_execute_scope:
    mov x0, x19
    mov x1, #JS_OBJECT
    bl _js_value
    cbz x0, Ljs_execute_failed
    str x21, [x0, #24]
    mov x21, x0
    b Ljs_execute_next
Ljs_execute_unscope:
    ldr x9, [x21, #24]
    cbz x9, Ljs_execute_limit
    mov x21, x9
    b Ljs_execute_next
Ljs_execute_push:
    mov x1, x0
    mov x0, x19
    bl _js_push
    b Ljs_execute_next
Ljs_execute_limit:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
Ljs_execute_failed:
    mov x0, #0
Ljs_execute_done:
    str x22, [x19, #JS_SP]
    ldr x9, [x19, #JS_DEPTH]
    sub x9, x9, #1
    str x9, [x19, #JS_DEPTH]
    LEAVE
// vm,function,argv,argc -> value. Copy arguments before recursive execution.
.globl _js_call
_js_call:
    ENTER
    sub sp, sp, #80
    mov x19, x0
    mov x20, x1
    mov x21, x3
    mov x22, x2
    mov x0, sp
    mov x1, #0
    mov x2, #64
    bl _memset
    cmp x21, #8
    b.hi Ljs_call_bad
    mov x9, #0
Ljs_call_copy:
    cmp x9, x21
    b.hs Ljs_call_dispatch
    ldr x10, [x22, x9, lsl #3]
    str x10, [sp, x9, lsl #3]
    add x9, x9, #1
    b Ljs_call_copy
Ljs_call_dispatch:
    cmp x20, #3
    b.ls Ljs_call_bad
    ldr x9, [x20]
    cmp x9, #JS_NATIVE
    b.eq Ljs_call_native
    cmp x9, #JS_FUNCTION
    b.ne Ljs_call_bad
    mov x0, x19
    mov x1, #JS_OBJECT
    bl _js_value
    cbz x0, Ljs_call_done
    mov x22, x0
    ldr x9, [x20, #16]
    str x9, [x22, #24]
    mov x9, #1
    str x9, [x22, #16]
    ldr x23, [x20, #24]
    mov x24, #0
Ljs_call_parameter:
    cmp x24, #8
    b.hs Ljs_call_this
    ldr x2, [x23, x24, lsl #3]
    cbz x2, Ljs_call_this
    mov x3, #0
    cmp x24, x21
    b.hs Ljs_call_param_value
    ldr x3, [sp, x24, lsl #3]
Ljs_call_param_value:
    mov x0, x19
    mov x1, x22
    mov x4, #1
    bl _js_assign
    add x24, x24, #1
    b Ljs_call_parameter
Ljs_call_this:
    mov x0, x19
    mov x1, x22
    ADDR x2, js_this_key
    ldr x3, [x19, #JS_THIS]
    mov x4, #1
    bl _js_assign
    mov x0, x19
    ldr x1, [x20, #8]
    mov x2, x22
    bl _js_execute
    b Ljs_call_done
Ljs_call_native:
    mov x0, x19
    mov x1, x20
    mov x2, sp
    mov x3, x21
    bl _js_native
    b Ljs_call_done
Ljs_call_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
Ljs_call_done:
    add sp, sp, #80
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_this_key: .asciz "this"
