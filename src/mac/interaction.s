.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.globl _mac_state_schedule
_mac_state_schedule:
    ENTER
    LOAD x0, _mac_window
    MSG currentEvent
    MSG type
    cmp x0, #10
    b.ne Lmac_state_pointer_mode
    mov x9, #1
    STORE x9, mac_keyboard_mode
    b Lmac_state_mode_ready
Lmac_state_pointer_mode:
    cmp x0, #1
    b.eq Lmac_state_mouse_mode
    cmp x0, #2
    b.ne Lmac_state_mode_ready
Lmac_state_mouse_mode:
    STORE xzr, mac_keyboard_mode
Lmac_state_mode_ready:
    mov x9, #1
    STORE x9, _mac_style_dirty
    LOAD x9, mac_state_queued
    cbnz x9, Lmac_state_scheduled
    mov x9, #1
    STORE x9, mac_state_queued
    LOAD x0, _mac_delegate
    SELECT x2, liveRestyle
    mov x3, #0
    fmov d0, xzr
    MSG liveLater
Lmac_state_scheduled:
    LEAVE
.globl _mac_state_restyle
_mac_state_restyle:
    ENTER
    STORE xzr, mac_state_queued
    bl _mac_engine_refresh
    LEAVE
// doc -> update control focus and checked state without editing default attrs.
.globl _mac_state_sync
_mac_state_sync:
    ENTER
    mov x19, x0
    mov x20, #0
Lmac_state_next:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lmac_state_synced
    mov x0, x20
    bl _mac_control_key
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    mov x21, x0
    cbz x21, Lmac_state_advance
    ldr x22, [x19, #72]
    add x22, x22, x20, lsl #11
    ldr x23, [x22, #744]
    bic x24, x23, #60
    mov x0, x21
    MSG window
    MSG liveFirstResponder
    mov x25, x0
    cmp x25, x21
    b.eq Lmac_state_focused
    mov x0, x21
    bl _mac_state_editor_capable
    cbz x0, Lmac_state_toggle
    mov x0, x21
    MSG inputCurrentEditor
    cbz x0, Lmac_state_toggle
    cmp x0, x25
    b.ne Lmac_state_toggle
Lmac_state_focused:
    orr x24, x24, #4
    LOAD x9, mac_keyboard_mode
    cbz x9, Lmac_state_toggle
    orr x24, x24, #8
Lmac_state_toggle:
    mov x0, x22
    mov x1, #31
    bl _mac_control_kind
    cmp x0, #4
    b.eq Lmac_state_checked
    cmp x0, #5
    b.ne Lmac_state_store
Lmac_state_checked:
    orr x24, x24, #16
    mov x0, x21
    MSG state
    cbz x0, Lmac_state_store
    orr x24, x24, #32
Lmac_state_store:
    cmp x23, x24
    b.eq Lmac_state_advance
    str x24, [x22, #744]
    mov x9, #1
    STORE x9, _mac_style_dirty
Lmac_state_advance:
    add x20, x20, #1
    b Lmac_state_next
Lmac_state_synced:
    LEAVE
// Internal respondsToSelector: wrapper avoids sending editor selectors to buttons.
.text
.globl _mac_state_editor_capable
_mac_state_editor_capable:
    ENTER
    SELECT x2, inputCurrentEditor
    MSG responds
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _mac_style_dirty
_mac_style_dirty: .space 8
mac_state_queued: .space 8
mac_keyboard_mode: .space 8
.section __TEXT,__cstring,cstring_literals
live_later_name: .asciz "performSelector:withObject:afterDelay:"
live_restyle_name: .asciz "restyleAssembly:"
live_responder_name: .asciz "firstResponder"
.section __DATA,__data
.p2align 3
.globl _sel_liveLater,_sel_liveRestyle,_sel_liveFirstResponder
_sel_liveLater: .quad live_later_name
_sel_liveRestyle: .quad live_restyle_name
_sel_liveFirstResponder: .quad live_responder_name
.section __TEXT,__cstring,cstring_literals
live_current_event_name: .asciz "currentEvent"
live_type_name: .asciz "type"
live_responds_name: .asciz "respondsToSelector:"
.section __DATA,__data
.p2align 3
.globl _sel_currentEvent,_sel_type,_sel_responds
_sel_currentEvent: .quad live_current_event_name
_sel_type: .quad live_type_name
_sel_responds: .quad live_responds_name
.text
.globl _mac_live_tracking_install
_mac_live_tracking_install:
    ENTER
    mov x19, x0
    ADDR x1, mac_live_tracking_key
    bl _objc_getAssociatedObject
    cbnz x0, Lmac_tracking_done
    CLASS NSTrackingArea
    MSG alloc
    RECT 0,0,0,0
    mov x2, #0x623 // entered/exited, moves, key window, visible rect, dragging
    mov x3, x19
    mov x4, #0
    MSG liveTrackingInit
    mov x20, x0
    mov x2, x0
    mov x0, x19
    MSG liveTrackingAdd
    mov x0, x19
    ADDR x1, mac_live_tracking_key
    mov x2, x20
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x20
    MSG release
Lmac_tracking_done:
    LEAVE
.globl _mac_live_mouse_exit
_mac_live_mouse_exit:
    ENTER
    LOAD x0, _engine_render_document
    cbz x0, Lmac_live_exited
    mov x1, #0
    mov x2, #1
    mov x3, #0
    bl _engine_interaction_set
    cbz x0, Lmac_live_exited
    bl _mac_state_schedule
Lmac_live_exited:
    LEAVE
.section __TEXT,__cstring,cstring_literals
.globl _class_NSTrackingArea
_class_NSTrackingArea: .asciz "NSTrackingArea"
mac_live_tracking_key: .asciz "OogaLiveTrackingArea"
live_tracking_init_name: .asciz "initWithRect:options:owner:userInfo:"
live_tracking_add_name: .asciz "addTrackingArea:"
.section __DATA,__data
.p2align 3
.globl _sel_liveTrackingInit,_sel_liveTrackingAdd
_sel_liveTrackingInit: .quad live_tracking_init_name
_sel_liveTrackingAdd: .quad live_tracking_add_name
