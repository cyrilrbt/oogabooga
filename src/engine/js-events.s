.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// vm,node,event name,callback,flags(1 property / 2 capture / 4 once).
.globl _js_listen
_js_listen:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    ldr x24, [x19, #JS_LISTENERS]
    mov x25, #0
Ljs_listen_existing:
    cbz x24, Ljs_listen_create
    add x25, x25, #1
    cmp x25, #128
    b.hi Ljs_listen_limit
    ldr x9, [x24]
    cmp x9, x20
    b.ne Ljs_listen_next
    ldr x0, [x24, #8]
    mov x1, x21
    bl _strcmp
    cbnz x0, Ljs_listen_next
    tbz x23, #0, Ljs_listen_duplicate
    ldr x9, [x24, #32]
    tbz x9, #0, Ljs_listen_next
    str x22, [x24, #16]
    b Ljs_listened
Ljs_listen_duplicate:
    ldr x9, [x24, #16]
    cmp x9, x22
    b.ne Ljs_listen_next
    ldr x9, [x24, #32]
    eor x9, x9, x23
    tbz x9, #1, Ljs_listened
Ljs_listen_next:
    ldr x24, [x24, #24]
    b Ljs_listen_existing
Ljs_listen_create:
    cmp x22, #3
    b.ls Ljs_listened
    ldr x9, [x22]
    cmp x9, #JS_FUNCTION
    b.eq Ljs_listen_allocate
    cmp x9, #JS_NATIVE
    b.ne Ljs_listen_bad
Ljs_listen_allocate:
    mov x0, x19
    mov x1, x21
    bl _js_cstring
    cbz x0, Ljs_listened
    ldr x21, [x0, #8]
    mov x0, x19
    mov x1, #48
    bl _js_alloc
    cbz x0, Ljs_listened
    mov x24, x0
    stp x20, x21, [x24]
    str x22, [x24, #16]
    str x23, [x24, #32]
    ldr x9, [x19, #JS_LISTENER_TAIL]
    cbz x9, Ljs_listen_first
    str x24, [x9, #24]
    b Ljs_listen_tail
Ljs_listen_first:
    str x24, [x19, #JS_LISTENERS]
Ljs_listen_tail:
    str x24, [x19, #JS_LISTENER_TAIL]
Ljs_listened:
    mov x0, #0
    LEAVE
Ljs_listen_limit:
    mov x9, #3
    b Ljs_listen_error
Ljs_listen_bad:
    mov x9, #4
Ljs_listen_error:
    str x9, [x19, #JS_ERROR]
    b Ljs_listened
.globl _js_unlisten
_js_unlisten:
    ENTER
    mov x19, x1
    mov x20, x2
    mov x21, x3
    ldr x22, [x0, #JS_LISTENERS]
Ljs_unlisten_next:
    cbz x22, Ljs_unlistened
    ldr x9, [x22]
    cmp x9, x19
    b.ne Ljs_unlisten_advance
    ldr x9, [x22, #16]
    cmp x9, x21
    b.ne Ljs_unlisten_advance
    ldr x0, [x22, #8]
    mov x1, x20
    bl _strcmp
    cbnz x0, Ljs_unlisten_advance
    str xzr, [x22, #16]
Ljs_unlisten_advance:
    ldr x22, [x22, #24]
    b Ljs_unlisten_next
Ljs_unlistened:
    mov x0, #0
    LEAVE
// vm,target,event name -> defaultPrevented BOOL. Capture, target and bubbling
// use a stable handle path and a registration boundary; callbacks may edit DOM.
.globl _engine_js_event
_engine_js_event:
    ENTER
    sub sp, sp, #576
    mov x19, x0
    mov x20, x1
    mov x21, x2
    str xzr, [x19, #JS_ERROR]
    mov x9, #0x86a0
    movk x9, #1, lsl #16
    str x9, [x19, #JS_FUEL]
    mov x22, #0
Ljs_event_path:
    cmp x22, #64
    b.hs Ljs_event_path_done
    cbz x20, Ljs_event_path_done
    str x20, [sp, x22, lsl #3]
    add x22, x22, #1
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    bl _engine_dom_node
    cbz x0, Ljs_event_path_done
    ldr x20, [x0, #8]
    b Ljs_event_path
Ljs_event_path_done:
    cbz x22, Ljs_event_empty
    mov x0, x19
    mov x1, #JS_OBJECT
    bl _js_value
    mov x23, x0
    cbz x0, Ljs_event_empty
    ldr x9, [x19, #JS_EVENT]
    str x9, [sp, #512]
    ldr x9, [x19, #JS_THIS]
    str x9, [sp, #520]
    ldr x9, [x19, #JS_LISTENER_TAIL]
    str x9, [sp, #528]
    str x23, [x19, #JS_EVENT]
    mov x0, x19
    mov x1, x21
    bl _js_cstring
    mov x3, x0
    mov x0, x19
    mov x1, x23
    ADDR x2, js_event_type
    mov x4, #1
    bl _js_property_set
    mov x0, x19
    ldr x1, [sp]
    bl _js_node
    mov x3, x0
    mov x0, x19
    mov x1, x23
    ADDR x2, js_event_target
    mov x4, #1
    bl _js_property_set
    mov x0, x19
    mov x1, #13
    mov x2, x23
    bl _js_bound
    mov x3, x0
    mov x0, x19
    mov x1, x23
    ADDR x2, js_event_prevent
    mov x4, #1
    bl _js_property_set
    mov x0, x19
    mov x1, #14
    mov x2, x23
    bl _js_bound
    mov x3, x0
    mov x0, x19
    mov x1, x23
    ADDR x2, js_event_stop
    mov x4, #1
    bl _js_property_set
    mov x24, #0 // capture pass, then bubble pass
    mov x25, x22
Ljs_event_capture:
    cbz x25, Ljs_event_bubble_start
    sub x25, x25, #1
    b Ljs_event_current
Ljs_event_bubble_start:
    mov x24, #1
    mov x25, #0
    b Ljs_event_current
Ljs_event_bubble:
    add x25, x25, #1
    cmp x25, x22
    b.hs Ljs_event_done
Ljs_event_current:
    ldr x9, [x23, #16]
    tbnz x9, #1, Ljs_event_done
    ldr x20, [sp, x25, lsl #3]
    mov x0, x19
    mov x1, x20
    bl _js_node
    str x0, [x19, #JS_THIS]
    mov x3, x0
    mov x0, x19
    mov x1, x23
    ADDR x2, js_event_current
    mov x4, #1
    bl _js_property_set
    ldr x26, [x19, #JS_LISTENERS]
Ljs_event_listener:
    cbz x26, Ljs_event_next_target
    ldr x27, [x26, #16]
    cbz x27, Ljs_event_next_listener
    ldr x9, [x26]
    cmp x9, x20
    b.ne Ljs_event_next_listener
    ldr x28, [x26, #32]
    ubfx x9, x28, #1, #1
    eor x9, x9, #1
    cmp x9, x24
    b.ne Ljs_event_next_listener
    ldr x0, [x26, #8]
    mov x1, x21
    bl _strcmp
    cbnz x0, Ljs_event_next_listener
    tbz x28, #2, Ljs_event_invoke
    str xzr, [x26, #16]
Ljs_event_invoke:
    str x23, [sp, #536]
    mov x0, x19
    mov x1, x27
    add x2, sp, #536
    mov x3, #1
    bl _js_call
    tbz x28, #0, Ljs_event_error_check
    cmp x0, #2
    b.ne Ljs_event_error_check
    ldr x9, [x23, #16]
    orr x9, x9, #1
    str x9, [x23, #16]
Ljs_event_error_check:
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_event_done
Ljs_event_next_listener:
    ldr x9, [sp, #528]
    cmp x26, x9
    b.eq Ljs_event_next_target
    ldr x26, [x26, #24]
    b Ljs_event_listener
Ljs_event_next_target:
    cbz x24, Ljs_event_capture
    b Ljs_event_bubble
Ljs_event_done:
    ldr x9, [sp, #512]
    str x9, [x19, #JS_EVENT]
    ldr x9, [sp, #520]
    str x9, [x19, #JS_THIS]
    mov x0, x19
    bl _js_microtasks
    ldr x0, [x23, #16]
    and x0, x0, #1
    b Ljs_event_return
Ljs_event_empty:
    mov x0, #0
Ljs_event_return:
    add sp, sp, #576
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_event_type: .asciz "type"
js_event_target: .asciz "target"
js_event_current: .asciz "currentTarget"
js_event_prevent: .asciz "preventDefault"
js_event_stop: .asciz "stopPropagation"
