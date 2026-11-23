// Pointer feedback is immediate; hover CSS waits until pointer/scroll activity
// settles. A full native layout must never run between wheel events.
.include "src/mac/mac.inc"
.text
.globl _mac_hover_scroll
_mac_hover_scroll:
    ENTER
    bl _engine_profile_now
    mov x9, #0x5180
    movk x9, #0x8f0, lsl #16       // 150,000,000 ns
    add x0, x0, x9
    STORE x0, mac_hover_deadline
    LEAVE

.globl _mac_hover_schedule
_mac_hover_schedule:
    ENTER
    LOAD x0, _engine_render_document
    cbz x0, Lhover_schedule_done
    ldr x0, [x0, #56]
    cbz x0, Lhover_schedule_done
    ADDR x1, hover_token
    bl _strcasestr
    cbz x0, Lhover_schedule_done
    bl _mac_hover_scroll
    mov x9, #1
    STORE x9, mac_hover_pending
    LOAD x9, mac_hover_queued
    cbnz x9, Lhover_schedule_done
    mov x9, #1
    STORE x9, mac_hover_queued
    bl hover_enqueue
Lhover_schedule_done:
    LEAVE

// Invalidate pending hover work whenever a new scene supersedes it. A queued
// callback remains harmless and can service a later hover without duplicates.
.globl _mac_hover_cancel
_mac_hover_cancel:
    STORE xzr, mac_hover_pending
    ret

.globl _mac_hover_restyle
_mac_hover_restyle:
    ENTER
    LOAD x9, mac_hover_pending
    cbz x9, Lhover_restyle_clear
    bl _engine_profile_now
    LOAD x9, mac_hover_deadline
    cmp x0, x9
    b.hs Lhover_restyle_ready
    bl hover_enqueue
    LEAVE
Lhover_restyle_ready:
    STORE xzr, mac_hover_pending
    STORE xzr, mac_hover_queued
    bl _mac_state_schedule
    LEAVE
Lhover_restyle_clear:
    STORE xzr, mac_hover_queued
    LEAVE

hover_enqueue:
    ENTER
    LOAD x0, _mac_delegate
    SELECT x2, hoverRestyle
    mov x3, #0
    ADDR x9, hover_delay
    ldr d0, [x9]
    MSG liveLater
    LEAVE
.section __DATA,__bss
.p2align 3
mac_hover_pending: .space 8
mac_hover_queued: .space 8
mac_hover_deadline: .space 8
.section __TEXT,__cstring,cstring_literals
hover_token: .asciz ":hover"
hover_restyle_name: .asciz "restyleAssemblyHover:"
.section __DATA,__data
.p2align 3
.globl _sel_hoverRestyle
_sel_hoverRestyle: .quad hover_restyle_name
hover_delay: .double 0.15
