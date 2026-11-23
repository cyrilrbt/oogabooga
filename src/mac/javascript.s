// Main-thread native adapter for the shared assembly scripting VM.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/js.inc"
.include "src/engine/css.inc"
.text
.globl _mac_js_init_selectors
_mac_js_init_selectors:
    ENTER
    ADDR x19, js_selectors
Lmj_selector:
    ldr x20, [x19], #8
    cbz x20, Lmj_selectors_done
    ldr x0, [x20]
    bl _sel_registerName
    str x0, [x20]
    b Lmj_selector
Lmj_selectors_done:
    LEAVE
.globl _mac_js_reset
_mac_js_reset:
    ENTER
    LOAD x19, _mac_js_vm
    STORE xzr, _mac_js_vm
    LOAD x9, _mac_js_generation
    add x9, x9, #1
    STORE x9, _mac_js_generation
    LOAD x0, mac_js_timer
    MSG jsInvalidate
    LOAD x0, mac_js_timer
    MSG release
    STORE xzr, mac_js_timer
    bl _mac_js_network_reset
    mov x0, x19
    bl _engine_js_free
    LEAVE
.globl _mac_js_begin
_mac_js_begin:
    ENTER
    LOAD x9, _mac_js_vm
    cbnz x9, Lmj_begin_done
    mov x19, x0
    LOAD x9, _mac_js_csp
    cbnz x9, Lmj_blocked
    ldr x0, [x19, #96]
    bl _engine_js_new
    cbz x0, Lmj_begin_done
    STORE x0, _mac_js_vm
    mov x20, x0
    LOAD x0, _mac_db
    cbz x0, Lmj_visit_ready
    bl _sqlite3_last_insert_rowid
    STORE x0, mac_js_visit
Lmj_visit_ready:
    bl _engine_profile_now
    mov x9, #0x4240
    movk x9, #15, lsl #16
    udiv x1, x0, x9
    mov x0, x20
    bl _engine_js_tick
    mov x0, x20
    bl _engine_js_prepare
    cbz x0, Lmj_blocked
    mov x0, x20
    bl _engine_js_start
    bl _mac_js_flush
    bl _mac_js_requests
    ADDR x0, mac_js_timer_class
    bl _objc_getClass
    fmov d0, #1.0
    mov x9, #60
    scvtf d1, x9
    fdiv d0, d0, d1
    LOAD x2, _mac_delegate
    SELECT x3, jsTick
    mov x4, #0
    mov x5, #1
    MSG jsSchedule
    MSG retain
    STORE x0, mac_js_timer
    b Lmj_begin_done
Lmj_blocked:
    STR mac_js_blocked
    bl _mac_status_text
Lmj_begin_done:
    LEAVE
.globl _mac_js_tick
_mac_js_tick:
    ENTER
    LOAD x19, _mac_js_vm
    cbz x19, Lmj_tick_done
    LOAD x9, _mac_engine_enabled
    cbz x9, Lmj_tick_done
    bl _engine_profile_now
    mov x9, #0x4240
    movk x9, #15, lsl #16
    udiv x1, x0, x9
    mov x0, x19
    bl _engine_js_tick
    bl _mac_js_flush
    bl _mac_js_requests
Lmj_tick_done:
    LEAVE
.globl _mac_js_flush
_mac_js_flush:
    ENTER
    LOAD x19, _mac_js_vm
    cbz x19, Lmj_flushed
    LOAD x9, mac_js_applying
    cbnz x9, Lmj_flushed
    mov x9, #1
    STORE x9, mac_js_applying
    mov x0, x19
    bl _engine_js_dirty
    mov x20, x0
    tbz x20, #0, Lmj_controls
    LOAD x0, _engine_document
    bl _mac_dom_rebuild
    LOAD x9, _engine_document
    ldr x0, [x9, #32]
    bl _mac_string
    mov x21, x0
    STR _ooga_engine_title_suffix
    mov x2, x0
    mov x0, x21
    MSG append
    mov x2, x0
    LOAD x0, _mac_window
    MSG setTitle
    LOAD x9, _engine_history_failed
    cbnz x9, Lmj_controls
    LOAD x0, _mac_db
    cbz x0, Lmj_controls
    LOAD x1, mac_js_visit
    LOAD x9, _engine_document
    ldr x2, [x9, #32]
    bl _history_update_title
Lmj_controls:
    tbz x20, #1, Lmj_errors
    LOAD x21, _engine_document
    cbz x21, Lmj_errors
    mov x22, #1
Lmj_control_next:
    ldr x9, [x21, #24]
    cmp x22, x9
    b.hs Lmj_errors
    ldr x9, [x21, #72]
    add x9, x9, x22, lsl #11
    ldr x1, [x9, #DOM_HANDLE]
    mov x0, x19
    bl _engine_js_control_read
    cbz x0, Lmj_control_advance
    mov x23, x0
    mov x0, x22
    bl _mac_control_key
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    cbz x0, Lmj_control_advance
    mov x24, x0
    ldr x9, [x21, #72]
    add x0, x9, x22, lsl #11
    ldr x9, [x21, #16]
    mov x10, #40
    madd x9, x22, x10, x9
    ldr x1, [x9]
    bl _mac_control_kind
    cmp x0, #4
    b.eq Lmj_control_toggle
    cmp x0, #5
    b.eq Lmj_control_toggle
    cbnz x0, Lmj_control_advance
    ldr x9, [x23, #8]
    cbz x9, Lmj_control_advance
    ldr x0, [x9, #8]
    bl _mac_string
    mov x25, x0
    mov x0, x24
    MSG stringValue
    mov x2, x25
    MSG jsEqual
    cbnz x0, Lmj_control_advance
    mov x0, x24
    mov x2, x25
    MSG setStringValue
    b Lmj_control_advance
Lmj_control_toggle:
    ldr x9, [x23, #16]
    cbz x9, Lmj_control_advance
    cmp x9, #3
    cset x2, eq
    mov x0, x24
    MSG setState
Lmj_control_advance:
    add x22, x22, #1
    b Lmj_control_next
Lmj_errors:
    mov x0, x19
    bl _engine_js_error
    cbz x0, Lmj_applied
    STR mac_js_error
    bl _mac_status_text
Lmj_applied:
    STORE xzr, mac_js_applying
Lmj_flushed:
    LEAVE
// Flow index and event UTF-8 name -> default prevented.
.globl _mac_js_event_node
_mac_js_event_node:
    ENTER
    mov x19, x0
    mov x20, x1
    LOAD x21, _mac_js_vm
    cbz x21, Lmj_event_no
    LOAD x9, mac_js_applying
    cbnz x9, Lmj_event_no
    LOAD x22, _engine_document
    cbz x22, Lmj_event_no
    ldr x9, [x22, #24]
    cmp x19, x9
    b.hs Lmj_event_no
    ldr x9, [x22, #72]
    add x23, x9, x19, lsl #11
    ldr x24, [x23, #DOM_HANDLE]
    mov x0, x19
    bl _mac_control_key
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    cbz x0, Lmj_event_dispatch
    mov x25, x0
    ldr x9, [x22, #16]
    mov x10, #40
    madd x9, x19, x10, x9
    ldr x1, [x9]
    mov x0, x23
    bl _mac_control_kind
    cmp x0, #4
    b.eq Lmj_feed_toggle
    cmp x0, #5
    b.eq Lmj_feed_toggle
    cbnz x0, Lmj_event_dispatch
    mov x0, x25
    MSG stringValue
    MSG UTF8String
    mov x26, x0
    bl _strlen
    mov x3, x0
    mov x0, x21
    mov x1, x24
    mov x2, x26
    mov x4, #-1
    bl _engine_js_control
    b Lmj_event_dispatch
Lmj_feed_toggle:
    mov x0, x25
    MSG state
    mov x4, x0
    mov x0, x21
    mov x1, x24
    mov x2, #0
    mov x3, #0
    bl _engine_js_control
Lmj_event_dispatch:
    mov x0, x21
    mov x1, x24
    mov x2, x20
    bl _engine_js_event
    mov x19, x0
    bl _mac_js_flush
    bl _mac_js_requests
    LOAD x0, _engine_document
    mov x1, x24
    bl _engine_js_flow_index
    mov x1, x0
    cmp x0, #0
    mov x9, #1
    csel x0, x9, x19, lt
    LEAVE
Lmj_event_no:
    mov x1, x19
    mov x0, #0
    LEAVE
.globl _mac_js_input
_mac_js_input:
    ENTER
    mov x0, x2
    MSG jsObject
    MSG tag
    ADDR x1, mac_js_input_name
    bl _mac_js_event_node
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _mac_js_vm,_mac_js_generation,_mac_js_csp
_mac_js_vm: .space 8
_mac_js_generation: .space 8
_mac_js_csp: .space 8
mac_js_visit: .space 8
mac_js_timer: .space 8
mac_js_applying: .space 8
.section __TEXT,__cstring,cstring_literals
mac_js_timer_class: .asciz "NSTimer"
mac_js_tick_name: .asciz "oogaScriptTick:"
mac_js_schedule: .asciz "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"
mac_js_invalidate: .asciz "invalidate"
mac_js_equal: .asciz "isEqualToString:"
mac_js_object: .asciz "object"
mac_js_changed: .asciz "controlTextDidChange:"
.globl _mac_js_click_name,_mac_js_change_name
_mac_js_click_name: .asciz "click"
_mac_js_change_name: .asciz "change"
mac_js_input_name: .asciz "input"
mac_js_blocked: .asciz "JavaScript blocked: CSP requires a policy the experimental VM cannot enforce."
mac_js_error: .asciz "Experimental JavaScript stopped: unsupported syntax, runtime error or resource limit."
.section __DATA,__data
.p2align 3
.globl _sel_jsTick,_sel_jsInput
_sel_jsTick: .quad mac_js_tick_name
_sel_jsInput: .quad mac_js_changed
_sel_jsSchedule: .quad mac_js_schedule
_sel_jsInvalidate: .quad mac_js_invalidate
_sel_jsEqual: .quad mac_js_equal
_sel_jsObject: .quad mac_js_object
js_selectors:
.quad _sel_jsTick,_sel_jsInput,_sel_jsSchedule,_sel_jsInvalidate,_sel_jsEqual,_sel_jsObject
.quad _sel_jsConfiguration,_sel_jsInvalidateCancel,_sel_jsURLRelative,_sel_jsAbsoluteURL,_sel_jsTimeout,_sel_jsHeader,0
