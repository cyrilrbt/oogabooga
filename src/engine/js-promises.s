.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
.globl _js_promise_new
_js_promise_new:
    mov x1, #JS_PROMISE
    b _js_value
// vm,callback,argument,destination promise,state -> FIFO microtask.
.globl _js_enqueue
_js_enqueue:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x1, #48
    bl _js_alloc
    cbz x0, Ljs_enqueued
    stp x20, x21, [x0]
    stp x22, x23, [x0, #16]
    ldr x9, [x19, #JS_MICRO_TAIL]
    cbz x9, Ljs_enqueue_first
    str x0, [x9, #32]
    b Ljs_enqueue_tail
Ljs_enqueue_first:
    str x0, [x19, #JS_MICRO_HEAD]
Ljs_enqueue_tail:
    str x0, [x19, #JS_MICRO_TAIL]
Ljs_enqueued:
    LEAVE
// vm,source,fulfillment handler,rejection handler -> destination promise.
.globl _js_promise_then
_js_promise_then:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _js_promise_new
    mov x23, x0
    cbz x0, Ljs_then_done
    mov x0, x19
    mov x1, #40
    bl _js_alloc
    cbz x0, Ljs_then_done
    stp x21, x22, [x0]
    str x23, [x0, #16]
    mov x24, x0
    ldr x9, [x20, #24]
    cbz x9, Ljs_then_first
Ljs_then_tail:
    ldr x10, [x9, #24]
    cbz x10, Ljs_then_append
    mov x9, x10
    b Ljs_then_tail
Ljs_then_append:
    str x24, [x9, #24]
    b Ljs_then_schedule
Ljs_then_first:
    str x24, [x20, #24]
Ljs_then_schedule:
    ldr x9, [x20, #8]
    cbz x9, Ljs_then_done
    mov x0, x19
    mov x1, x20
    mov x2, x24
    bl js_promise_reaction
Ljs_then_done:
    mov x0, x23
    LEAVE
// vm,source,reaction -> queue once.
js_promise_reaction:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x21, #32]
    cbnz x9, Ljs_reaction_done
    mov x9, #1
    str x9, [x21, #32]
    ldr x4, [x20, #8]
    ldr x1, [x21]
    cmp x4, #2
    b.ne Ljs_reaction_handler
    ldr x1, [x21, #8]
Ljs_reaction_handler:
    ldr x2, [x20, #16]
    ldr x3, [x21, #16]
    mov x0, x19
    bl _js_enqueue
Ljs_reaction_done:
    LEAVE
// vm,promise,state(1 fulfilled/2 rejected),value. Adopt another promise without
// running reactions synchronously, and reject direct self resolution.
.globl _js_promise_settle
_js_promise_settle:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    cbz x20, Ljs_settled
    ldr x9, [x20, #8]
    cbnz x9, Ljs_settled
    cmp x21, #1
    b.ne Ljs_settle_direct
    cmp x22, x20
    b.eq Ljs_settle_cycle
    cmp x22, #3
    b.ls Ljs_settle_direct
    ldr x9, [x22]
    cmp x9, #JS_PROMISE
    b.ne Ljs_settle_direct
    mov x0, x19
    mov x1, x22
    mov x2, #0
    mov x3, #0
    bl _js_promise_then
    cbz x0, Ljs_settled
    // Replace the newly created reaction destination with the adopted target.
    ldr x9, [x22, #24]
    cbz x9, Ljs_settled
Ljs_adopt_last:
    ldr x10, [x9, #24]
    cbz x10, Ljs_adopt_target
    mov x9, x10
    b Ljs_adopt_last
Ljs_adopt_target:
    str x20, [x9, #16]
    // If already queued, update that task's destination too.
    ldr x10, [x19, #JS_MICRO_TAIL]
    cbz x10, Ljs_settled
    ldr x11, [x10, #16]
    cmp x11, x0
    b.ne Ljs_settled
    str x20, [x10, #16]
    b Ljs_settled
Ljs_settle_cycle:
    mov x21, #2
    mov x0, x19
    ADDR x1, js_promise_cycle
    bl _js_cstring
    mov x22, x0
Ljs_settle_direct:
    stp x21, x22, [x20, #8]
    ldr x23, [x20, #24]
Ljs_settle_reactions:
    cbz x23, Ljs_settled
    mov x0, x19
    mov x1, x20
    mov x2, x23
    bl js_promise_reaction
    ldr x23, [x23, #24]
    b Ljs_settle_reactions
Ljs_settled:
    LEAVE
// A checkpoint drains FIFO reactions with both instruction and task budgets.
.globl _js_microtasks
_js_microtasks:
    ENTER
    mov x19, x0
    mov x20, #128
Ljs_microtask_next:
    ldr x21, [x19, #JS_MICRO_HEAD]
    cbz x21, Ljs_microtasks_done
    cbz x20, Ljs_microtasks_limit
    sub x20, x20, #1
    ldr x9, [x21, #32]
    str x9, [x19, #JS_MICRO_HEAD]
    cbnz x9, Ljs_microtask_handler
    str xzr, [x19, #JS_MICRO_TAIL]
Ljs_microtask_handler:
    ldr x22, [x21]
    ldr x23, [x21, #8]
    ldr x24, [x21, #16]
    ldr x25, [x21, #24]
    cmp x22, #3
    b.ls Ljs_microtask_passthrough
    ldr x9, [x22]
    cmp x9, #JS_FUNCTION
    b.eq Ljs_microtask_call
    cmp x9, #JS_NATIVE
    b.ne Ljs_microtask_passthrough
Ljs_microtask_call:
    str x23, [sp, #144]
    mov x0, x19
    mov x1, x22
    add x2, sp, #144
    mov x3, #1
    bl _js_call
    mov x23, x0
    mov x25, #1
    ldr x9, [x19, #JS_ERROR]
    cbz x9, Ljs_microtask_passthrough
    // Reactions turn thrown VM errors into rejection, leaving later reactions
    // eligible to run. A page's allocation/fuel caps still apply to every call.
    str xzr, [x19, #JS_ERROR]
    mov x0, x19
    ADDR x1, js_promise_error
    bl _js_cstring
    mov x23, x0
    mov x25, #2
Ljs_microtask_passthrough:
    cbz x24, Ljs_microtask_next
    mov x0, x19
    mov x1, x24
    mov x2, x25
    mov x3, x23
    bl _js_promise_settle
    b Ljs_microtask_next
Ljs_microtasks_limit:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
Ljs_microtasks_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_promise_cycle: .asciz "Promise self resolution"
js_promise_error: .asciz "Script callback failed"
