// JavaScript stays in the shared assembly VM. GTK supplies main-loop timing,
// native editor access and the existing DOM rebuild adapter only.
.include "src/gtk/gtk.inc"
.include "src/engine/js.inc"
.text
.globl _gtk_js_reset
_gtk_js_reset:
    ENTER
    LOAD x19, _gtk_js_vm
    STORE xzr, _gtk_js_vm
    LOAD x9, _gtk_js_generation
    add x9, x9, #1
    STORE x9, _gtk_js_generation
    LOAD x0, gtk_js_timer
    cbz x0, Lgtk_js_no_timer
    bl _g_source_remove
    STORE xzr, gtk_js_timer
Lgtk_js_no_timer:
    LOAD x0, _gtk_js_cancel
    cbz x0, Lgtk_js_no_cancel
    bl _g_cancellable_cancel
    LOAD x0, _gtk_js_cancel
    bl _g_object_unref
    STORE xzr, _gtk_js_cancel
Lgtk_js_no_cancel:
    mov x0, x19
    bl _engine_js_free
    LEAVE
.globl _gtk_js_begin
_gtk_js_begin:
    ENTER
    mov x19, x0
    bl _gtk_js_reset
    LOAD x9, _gtk_js_csp
    cbnz x9, Lgtk_js_begin_blocked
    ldr x0, [x19, #96]
    bl _engine_js_new
    cbz x0, Lgtk_js_begin_done
    STORE x0, _gtk_js_vm
    mov x20, x0
    bl _g_cancellable_new
    STORE x0, _gtk_js_cancel
    bl _g_get_monotonic_time
    mov x9, #1000
    udiv x1, x0, x9
    mov x0, x20
    bl _engine_js_tick
    mov x0, x20
    bl _engine_js_prepare
    cbz x0, Lgtk_js_begin_blocked
    mov x0, x20
    bl _engine_js_start
    bl _gtk_js_flush
    bl _gtk_js_requests
    mov x0, #16
    CALLBACK x1, _gtk_js_tick
    mov x2, #0
    bl _g_timeout_add
    STORE x0, gtk_js_timer
    b Lgtk_js_begin_done
Lgtk_js_begin_blocked:
    ADDR x0, gtk_js_blocked
    bl _gtk_engine_status
Lgtk_js_begin_done:
    LEAVE
.globl _gtk_js_tick
_gtk_js_tick:
    ENTER
    LOAD x19, _gtk_js_vm
    cbz x19, Lgtk_js_tick_done
    LOAD x0, _gtk_view
    cbz x0, Lgtk_js_tick_run
    bl _gtk_widget_get_visible
    cbz x0, Lgtk_js_tick_done
Lgtk_js_tick_run:
    bl _g_get_monotonic_time
    mov x9, #1000
    udiv x1, x0, x9
    mov x0, x19
    bl _engine_js_tick
    bl _gtk_js_flush
    bl _gtk_js_requests
Lgtk_js_tick_done:
    mov x0, #1
    LEAVE
.globl _gtk_js_flush
_gtk_js_flush:
    ENTER
    LOAD x19, _gtk_js_vm
    cbz x19, Lgtk_js_flushed
    LOAD x9, gtk_js_applying
    cbnz x9, Lgtk_js_flushed
    mov x9, #1
    STORE x9, gtk_js_applying
    mov x0, x19
    bl _engine_js_dirty
    mov x20, x0
    tbz x20, #0, Lgtk_js_control_changes
    LOAD x0, _gtk_doc
    cbz x0, Lgtk_js_control_changes
    bl _gtk_dom_rebuild
Lgtk_js_control_changes:
    tbz x20, #1, Lgtk_js_errors
    LOAD x21, _gtk_doc
    cbz x21, Lgtk_js_errors
    mov x22, #1
Lgtk_js_control_next:
    ldr x9, [x21, #24]
    cmp x22, x9
    b.hs Lgtk_js_errors
    LOAD x9, _gtk_nodes
    add x23, x9, x22, lsl #8
    ldr x24, [x23, #GN_WIDGET]
    cbz x24, Lgtk_js_control_advance
    ldr x9, [x21, #72]
    add x9, x9, x22, lsl #11
    ldr x1, [x9, #DOM_HANDLE]
    mov x0, x19
    bl _engine_js_control_read
    cbz x0, Lgtk_js_control_advance
    mov x25, x0
    ldr x26, [x23, #GN_CONTROL_KIND]
    cmp x26, #4
    b.eq Lgtk_js_apply_toggle
    cmp x26, #5
    b.eq Lgtk_js_apply_toggle
    cbnz x26, Lgtk_js_control_advance
    ldr x9, [x25, #8]
    cbz x9, Lgtk_js_control_advance
    ldr x27, [x9, #8]
    mov x0, x24
    bl _gtk_entry_get_text
    mov x1, x27
    bl _strcmp
    cbz x0, Lgtk_js_control_advance
    mov x0, x24
    mov x1, x27
    bl _gtk_entry_set_text
    b Lgtk_js_control_advance
Lgtk_js_apply_toggle:
    ldr x9, [x25, #16]
    cbz x9, Lgtk_js_control_advance
    cmp x9, #3
    cset x27, eq
    mov x0, x24
    bl _gtk_toggle_button_get_active
    cmp x0, x27
    b.eq Lgtk_js_control_advance
    mov x0, x24
    mov x1, x27
    bl _gtk_toggle_button_set_active
Lgtk_js_control_advance:
    add x22, x22, #1
    b Lgtk_js_control_next
Lgtk_js_errors:
    mov x0, x19
    bl _engine_js_error
    cbz x0, Lgtk_js_apply_done
    ADDR x0, gtk_js_error
    bl _gtk_engine_status
Lgtk_js_apply_done:
    STORE xzr, gtk_js_applying
Lgtk_js_flushed:
    LEAVE
// flow node,event name -> canceled. Feed the native editor before script reads.
.globl _gtk_js_event_node
_gtk_js_event_node:
    ENTER
    mov x19, x0
    mov x20, x1
    LOAD x21, _gtk_js_vm
    cbz x21, Lgtk_js_event_no
    LOAD x9, gtk_js_applying
    cbnz x9, Lgtk_js_event_no
    LOAD x22, _gtk_doc
    ldr x9, [x22, #24]
    cmp x19, x9
    b.hs Lgtk_js_event_no
    ldr x9, [x22, #72]
    add x9, x9, x19, lsl #11
    ldr x23, [x9, #DOM_HANDLE]
    LOAD x9, _gtk_nodes
    add x24, x9, x19, lsl #8
    ldr x25, [x24, #GN_WIDGET]
    cbz x25, Lgtk_js_event_call
    ldr x26, [x24, #GN_CONTROL_KIND]
    cmp x26, #4
    b.eq Lgtk_js_feed_toggle
    cmp x26, #5
    b.eq Lgtk_js_feed_toggle
    cbnz x26, Lgtk_js_event_call
    mov x0, x25
    bl _gtk_entry_get_text
    mov x27, x0
    bl _strlen
    mov x3, x0
    mov x0, x21
    mov x1, x23
    mov x2, x27
    mov x4, #-1
    bl _engine_js_control
    b Lgtk_js_event_call
Lgtk_js_feed_toggle:
    mov x0, x25
    bl _gtk_toggle_button_get_active
    mov x4, x0
    mov x0, x21
    mov x1, x23
    mov x2, #0
    mov x3, #0
    bl _engine_js_control
Lgtk_js_event_call:
    mov x0, x21
    mov x1, x23
    mov x2, x20
    bl _engine_js_event
    mov x19, x0
    bl _gtk_js_flush
    bl _gtk_js_requests
    LOAD x0, _gtk_doc
    mov x1, x23
    bl _engine_js_flow_index
    mov x1, x0
    cmp x0, #0
    mov x9, #1
    csel x0, x9, x19, lt
    LEAVE
Lgtk_js_event_no:
    mov x1, x19
    mov x0, #0
    LEAVE
// widget -> flow index+1 stored by the existing stable control binding.
.globl _gtk_js_input
_gtk_js_input:
    ENTER
    ADDR x1, gtk_js_node_key
    bl _g_object_get_data
    cbz x0, Lgtk_js_input_done
    sub x0, x0, #1
    ADDR x1, gtk_js_input_name
    bl _gtk_js_event_node
Lgtk_js_input_done:
    LEAVE
.globl _gtk_js_change
_gtk_js_change:
    ENTER
    mov x19, x0
    bl _gtk_js_input
    mov x0, x19
    ADDR x1, gtk_js_node_key
    bl _g_object_get_data
    cbz x0, Lgtk_js_changed
    sub x0, x0, #1
    ADDR x1, gtk_js_change_name
    bl _gtk_js_event_node
Lgtk_js_changed:
    LEAVE
// Document pixel point -> click event target. Source-mapped text is resolved to
// its enclosing element, not the paragraph that happens to own its Pango group.
.globl _gtk_js_click_at
_gtk_js_click_at:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _gtk_engine_hit
    cbz x0, Lgtk_js_click_none
    ldr x21, [x0, #8]
    mov x0, x19
    mov x1, x20
    bl _gtk_engine_text_at
    cbz x1, Lgtk_js_click_target
    mov x22, x0
    LOAD x23, _gtk_doc
    ldr x24, [x23, #24]
Lgtk_js_click_leaf:
    cbz x24, Lgtk_js_click_target
    sub x24, x24, #1
    mov x0, x24
    bl _gtk_engine_node
    ldr x9, [x2]
    cmp x9, #NODE_TEXT
    b.ne Lgtk_js_click_leaf
    ldr x25, [x2, #8]
    ldr x0, [x2, #16]
    bl _gtk_engine_byte
    cmp x22, x0
    b.lt Lgtk_js_click_leaf
    mov x0, x24
    bl _gtk_engine_node
    ldr x0, [x2, #24]
    bl _gtk_engine_byte
    cmp x22, x0
    b.hs Lgtk_js_click_leaf
    mov x21, x25
Lgtk_js_click_target:
    mov x0, x21
    ADDR x1, gtk_js_click_name
    bl _gtk_js_event_node
    LEAVE
Lgtk_js_click_none:
    mov x0, #0
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_js_vm,_gtk_js_generation,_gtk_js_cancel,_gtk_js_csp
_gtk_js_vm: .space 8
_gtk_js_generation: .space 8
_gtk_js_cancel: .space 8
_gtk_js_csp: .space 8
gtk_js_timer: .space 8
gtk_js_applying: .space 8
.section __TEXT,__cstring,cstring_literals
.globl _gtk_js_click_name
gtk_js_click_name: .asciz "click"
_gtk_js_click_name: .asciz "click"
gtk_js_input_name: .asciz "input"
gtk_js_change_name: .asciz "change"
gtk_js_node_key: .asciz "oogabooga-control-node"
gtk_js_blocked: .asciz "JavaScript blocked: CSP requires a policy the experimental VM cannot enforce."
gtk_js_error: .asciz "Experimental JavaScript stopped: unsupported syntax, runtime error or resource limit."
