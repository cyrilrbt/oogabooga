.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// Native async/utility functions share one audited dispatch. No eval/FFI.
.globl _js_async_native
_js_async_native:
    ENTER
    sub sp, sp, #64
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x20, #16]
    ldr x24, [x20, #8]
    ldr x25, [x21]
    cmp x24, #24
    b.eq Ljs_async_timer
    cmp x24, #48
    b.eq Ljs_async_timer
    cmp x24, #25
    b.eq Ljs_async_clear
    cmp x24, #26
    b.eq Ljs_async_queue
    cmp x24, #27
    b.eq Ljs_async_fetch
    cmp x24, #28
    b.eq Ljs_async_resolved
    cmp x24, #29
    b.eq Ljs_async_resolved
    cmp x24, #30
    b.eq Ljs_async_then
    cmp x24, #31
    b.eq Ljs_async_then
    cmp x24, #32
    b.eq Ljs_async_response
    cmp x24, #33
    b.eq Ljs_async_response
    cmp x24, #34
    b.eq Ljs_async_promise_ctor
    cmp x24, #35
    b.eq Ljs_async_resolver
    cmp x24, #36
    b.eq Ljs_async_resolver
    cmp x24, #37
    b.eq Ljs_async_json
    cmp x24, #39
    b.eq Ljs_async_array
    cmp x24, #40
    b.eq Ljs_async_object
    cmp x24, #41
    b.eq Ljs_async_math
    cmp x24, #42
    b.eq Ljs_async_math
    cmp x24, #43
    b.eq Ljs_async_isarray
    cmp x24, #44
    b.eq Ljs_async_keys
    cmp x24, #46
    b.eq Ljs_async_style
    cmp x24, #47
    b.eq Ljs_async_style
    b Ljs_async_bad
Ljs_async_resolved:
    cmp x24, #28
    b.ne Ljs_async_new_settled
    cmp x25, #3
    b.ls Ljs_async_new_settled
    ldr x9, [x25]
    cmp x9, #JS_PROMISE
    b.eq Ljs_async_identity
Ljs_async_new_settled:
    mov x0, x19
    bl _js_promise_new
    mov x26, x0
    mov x1, x0
    mov x0, x19
    mov x2, #1
    cmp x24, #29
    mov x9, #2
    csel x2, x9, x2, eq
    mov x3, x25
    bl _js_promise_settle
    mov x0, x26
    b Ljs_async_done
Ljs_async_then:
    mov x2, x25
    ldr x3, [x21, #8]
    cmp x24, #31
    b.ne Ljs_async_then_call
    mov x3, x25
    mov x2, #0
Ljs_async_then_call:
    mov x0, x19
    mov x1, x23
    bl _js_promise_then
    b Ljs_async_done
Ljs_async_promise_ctor:
    cmp x25, #3
    b.ls Ljs_async_bad
    ldr x9, [x25]
    cmp x9, #JS_FUNCTION
    b.ne Ljs_async_bad
    mov x0, x19
    bl _js_promise_new
    mov x26, x0
    cbz x0, Ljs_async_done
    mov x0, x19
    mov x1, #35
    mov x2, x26
    bl _js_bound
    str x0, [sp]
    mov x0, x19
    mov x1, #36
    mov x2, x26
    bl _js_bound
    str x0, [sp, #8]
    mov x0, x19
    mov x1, x25
    mov x2, sp
    mov x3, #2
    bl _js_call
    ldr x9, [x19, #JS_ERROR]
    cbz x9, Ljs_async_promise_created
    str xzr, [x19, #JS_ERROR]
    mov x0, x19
    ADDR x1, js_async_callback_error
    bl _js_cstring
    mov x3, x0
    mov x0, x19
    mov x1, x26
    mov x2, #2
    bl _js_promise_settle
Ljs_async_promise_created:
    mov x0, x26
    b Ljs_async_done
Ljs_async_resolver:
    mov x0, x19
    mov x1, x23
    mov x2, #1
    cmp x24, #36
    mov x9, #2
    csel x2, x9, x2, eq
    mov x3, x25
    bl _js_promise_settle
    b Ljs_async_undefined
Ljs_async_queue:
    cmp x25, #3
    b.ls Ljs_async_bad
    ldr x9, [x25]
    cmp x9, #JS_FUNCTION
    b.ne Ljs_async_bad
    mov x0, x19
    mov x1, x25
    mov x2, #0
    mov x3, #0
    mov x4, #1
    bl _js_enqueue
    b Ljs_async_undefined
Ljs_async_timer:
    cmp x25, #3
    b.ls Ljs_async_bad
    ldr x9, [x25]
    cmp x9, #JS_FUNCTION
    b.ne Ljs_async_bad
    ldr x0, [x21, #8]
    bl _js_to_number
    fcvtzs x26, d0
    cmp x26, #0
    csel x26, xzr, x26, lt
    mov x9, #60000
    cmp x26, x9
    csel x26, x9, x26, hi
    mov x0, x19
    mov x1, #112
    bl _js_alloc
    cbz x0, Ljs_async_done
    mov x27, x0
    ldr x28, [x19, #JS_ID_COUNTER]
    add x28, x28, #1
    str x28, [x19, #JS_ID_COUNTER]
    stp x28, x25, [x27]
    ldr x9, [x19, #JS_TIME]
    add x9, x9, x26
    str x9, [x27, #16]
    cmp x24, #48
    b.ne Ljs_timer_args
    cmp x26, #1
    mov x9, #1
    csel x26, x9, x26, lt
    str x26, [x27, #24]
Ljs_timer_args:
    subs x9, x22, #2
    csel x9, xzr, x9, lt
    str x9, [x27, #32]
    mov x10, #0
Ljs_timer_arg_next:
    cmp x10, x9
    b.hs Ljs_timer_link
    add x11, x10, #2
    ldr x12, [x21, x11, lsl #3]
    add x11, x27, #40
    str x12, [x11, x10, lsl #3]
    add x10, x10, #1
    b Ljs_timer_arg_next
Ljs_timer_link:
    ldr x9, [x19, #JS_TIMERS]
    cbz x9, Ljs_timer_first
Ljs_timer_tail:
    ldr x10, [x9, #104]
    cbz x10, Ljs_timer_append
    mov x9, x10
    b Ljs_timer_tail
Ljs_timer_append:
    str x27, [x9, #104]
    b Ljs_timer_id
Ljs_timer_first:
    str x27, [x19, #JS_TIMERS]
Ljs_timer_id:
    mov x0, x19
    mov x1, x28
    bl _js_integer
    b Ljs_async_done
Ljs_async_clear:
    mov x0, x25
    bl _js_to_number
    fcvtzs x26, d0
    ldr x9, [x19, #JS_TIMERS]
Ljs_timer_clear_next:
    cbz x9, Ljs_async_undefined
    ldr x10, [x9]
    cmp x10, x26
    b.ne Ljs_timer_clear_advance
    str xzr, [x9, #8]
Ljs_timer_clear_advance:
    ldr x9, [x9, #104]
    b Ljs_timer_clear_next
Ljs_async_fetch:
    mov x0, x19
    mov x1, x25
    mov x2, x22
    ldr x3, [x21, #8]
    bl _js_fetch_new
    b Ljs_async_done
Ljs_async_response:
    mov x0, x19
    bl _js_promise_new
    mov x26, x0
    cbz x0, Ljs_async_done
    ldr x27, [x23, #8]
    cmp x24, #32
    b.eq Ljs_async_response_settle
    mov x0, x19
    mov x1, x27
    bl _js_json_parse
    mov x27, x0
Ljs_async_response_settle:
    mov x2, #1
    ldr x9, [x19, #JS_ERROR]
    cbz x9, Ljs_async_response_value
    str xzr, [x19, #JS_ERROR]
    mov x2, #2
Ljs_async_response_value:
    mov x0, x19
    mov x1, x26
    mov x3, x27
    bl _js_promise_settle
    mov x0, x26
    b Ljs_async_done
Ljs_async_json:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    mov x1, x0
    mov x0, x19
    bl _js_json_parse
    b Ljs_async_done
Ljs_async_array:
    mov x0, x19
    mov x1, #JS_ARRAY
    bl _js_value
    mov x26, x0
    mov x27, #0
    cmp x22, #1
    b.ne Ljs_async_array_items
    cmp x25, #3
    b.ls Ljs_async_array_items
    ldr x9, [x25]
    cmp x9, #JS_NUMBER
    b.ne Ljs_async_array_items
    ldr d0, [x25, #8]
    fcvtzs x9, d0
    cmp x9, #256
    b.hi Ljs_async_bad
    str x9, [x26, #16]
    mov x0, x26
    b Ljs_async_done
Ljs_async_array_items:
    cmp x27, x22
    b.hs Ljs_async_array_done
    mov x0, x19
    mov x1, x26
    ldr x2, [x21, x27, lsl #3]
    bl _js_array_push
    add x27, x27, #1
    b Ljs_async_array_items
Ljs_async_array_done:
    mov x0, x26
    b Ljs_async_done
Ljs_async_object:
    cmp x25, #3
    b.ls Ljs_async_object_new
    ldr x9, [x25]
    cmp x9, #JS_OBJECT
    b.eq Ljs_async_identity
    cmp x9, #JS_ARRAY
    b.eq Ljs_async_identity
Ljs_async_object_new:
    mov x0, x19
    mov x1, #JS_OBJECT
    bl _js_value
    b Ljs_async_done
Ljs_async_math:
    mov x0, x25
    bl _js_to_number
    cmp x24, #42
    b.eq Ljs_math_abs
    frintm d0, d0
    b Ljs_math_result
Ljs_math_abs:
    fabs d0, d0
Ljs_math_result:
    mov x0, x19
    bl _js_number
    b Ljs_async_done
Ljs_async_isarray:
    mov x0, #2
    cmp x25, #3
    b.ls Ljs_async_done
    ldr x9, [x25]
    cmp x9, #JS_ARRAY
    cset x0, eq
    add x0, x0, #2
    b Ljs_async_done
Ljs_async_keys:
    cmp x25, #3
    b.ls Ljs_async_bad
    ldr x9, [x25]
    cmp x9, #JS_OBJECT
    b.eq Ljs_keys_start
    cmp x9, #JS_ARRAY
    b.ne Ljs_async_bad
Ljs_keys_start:
    ldr x27, [x25, #8]
    mov x0, x19
    mov x1, #JS_ARRAY
    bl _js_value
    mov x26, x0
Ljs_keys_next:
    cbz x27, Ljs_async_array_done
    mov x0, x19
    ldr x1, [x27]
    bl _js_cstring
    mov x2, x0
    mov x0, x19
    mov x1, x26
    bl _js_array_push
    ldr x27, [x27, #16]
    b Ljs_keys_next
Ljs_async_style:
    mov x0, x19
    mov x1, x25
    bl _js_to_string
    cbz x0, Ljs_async_done
    ldr x2, [x0, #8]
    mov x0, x19
    ldr x1, [x23, #8]
    cmp x24, #47
    b.eq Ljs_async_style_get
    ldr x3, [x21, #8]
    bl _js_style_set
    b Ljs_async_undefined
Ljs_async_style_get:
    bl _js_style_get
    b Ljs_async_done
Ljs_async_identity:
    mov x0, x25
    b Ljs_async_done
Ljs_async_undefined:
    mov x0, #0
    b Ljs_async_done
Ljs_async_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
Ljs_async_done:
    add sp, sp, #64
    LEAVE
// vm,monotonic milliseconds -> bounded task turn. Newly scheduled zero-delay
// tasks wait until the following tick; microtasks run between timer callbacks.
.globl _engine_js_tick
_engine_js_tick:
    ENTER
    mov x19, x0
    str x1, [x19, #JS_TIME]
    str xzr, [x19, #JS_ERROR]
    mov x9, #0x86a0
    movk x9, #1, lsl #16
    str x9, [x19, #JS_FUEL]
    ldr x20, [x19, #JS_ID_COUNTER]
    ldr x21, [x19, #JS_TIMERS]
    mov x22, #32
Ljs_tick_timer:
    cbz x21, Ljs_tick_checkpoint
    cbz x22, Ljs_tick_checkpoint
    ldr x23, [x21, #8]
    cbz x23, Ljs_tick_next
    ldr x9, [x21]
    cmp x9, x20
    b.hi Ljs_tick_next
    ldr x9, [x21, #16]
    ldr x10, [x19, #JS_TIME]
    cmp x9, x10
    b.hi Ljs_tick_next
    sub x22, x22, #1
    ldr x9, [x21, #24]
    cbz x9, Ljs_tick_once
    add x9, x9, x10
    str x9, [x21, #16]
    b Ljs_tick_call
Ljs_tick_once:
    str xzr, [x21, #8]
Ljs_tick_call:
    mov x0, x19
    mov x1, x23
    add x2, x21, #40
    ldr x3, [x21, #32]
    bl _js_call
    mov x0, x19
    bl _js_microtasks
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_tick_done
Ljs_tick_next:
    ldr x21, [x21, #104]
    b Ljs_tick_timer
Ljs_tick_checkpoint:
    mov x0, x19
    bl _js_microtasks
Ljs_tick_done:
    LEAVE
// Native adapters read/clear dirty bits after a complete task checkpoint.
.globl _engine_js_dirty
_engine_js_dirty:
    ldr x9, [x0, #JS_DOM_DIRTY]
    ldr x10, [x0, #JS_CONTROL_DIRTY]
    orr x9, x9, x10, lsl #1
    str xzr, [x0, #JS_DOM_DIRTY]
    str xzr, [x0, #JS_CONTROL_DIRTY]
    mov x0, x9
    ret
.section __TEXT,__cstring,cstring_literals
js_async_callback_error: .asciz "Promise executor failed"
