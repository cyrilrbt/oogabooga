// GTK state notifications coalesce into one main-loop restyle. Rebuilding uses
// retained controls, so live values, editor selection and focus survive.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_state_schedule
_gtk_state_schedule:
    ENTER
    LOAD x9, gtk_state_idle
    cbnz x9, Lgtk_state_scheduled
    CALLBACK x0, _gtk_state_idle_run
    mov x1, #0
    bl _g_idle_add
    STORE x0, gtk_state_idle
Lgtk_state_scheduled:
    mov x0, #0
    LEAVE
.globl _gtk_state_idle_run
_gtk_state_idle_run:
    ENTER
    STORE xzr, gtk_state_idle
    LOAD x0, _gtk_doc
    cbz x0, Lgtk_state_idle_done
    bl _gtk_state_sync
    LOAD x9, gtk_pointer_dirty
    STORE xzr, gtk_pointer_dirty
    orr x0, x0, x9
    cbz x0, Lgtk_state_idle_done
    LOAD x0, _gtk_doc
    LOAD x1, _gtk_width
    bl _gtk_engine_prepare
    bl _gtk_engine_place
    LOAD x0, _gtk_drawing
    cbz x0, Lgtk_state_idle_done
    bl _gtk_widget_queue_draw
Lgtk_state_idle_done:
    mov x0, #0
    LEAVE
.globl _gtk_state_sync
_gtk_state_sync:
    ENTER
    LOAD x19, _gtk_doc
    LOAD x20, _gtk_nodes
    mov x21, #0
    mov x22, #0
    cbz x19, Lgtk_state_sync_done
    cbz x20, Lgtk_state_sync_done
Lgtk_state_sync_node:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lgtk_state_sync_done
    add x23, x20, x21, lsl #8
    ldr x24, [x23, #GN_WIDGET]
    cbz x24, Lgtk_state_sync_next
    ldr x25, [x19, #72]
    add x25, x25, x21, lsl #11
    ldr x26, [x25, #744]
    bic x27, x26, #63
    mov x0, x24
    bl _gtk_widget_get_state_flags
    tbz x0, #1, Lgtk_state_active
    orr x27, x27, #1
Lgtk_state_active:
    tbz x0, #0, Lgtk_state_focus
    orr x27, x27, #2
Lgtk_state_focus:
    tbz x0, #5, Lgtk_state_toggle
    orr x27, x27, #4
    LOAD x9, _gtk_keyboard_mode
    cbz x9, Lgtk_state_toggle
    orr x27, x27, #8
Lgtk_state_toggle:
    ldr x9, [x23, #GN_CONTROL_KIND]
    cmp x9, #4
    b.eq Lgtk_state_check
    cmp x9, #5
    b.ne Lgtk_state_store
Lgtk_state_check:
    orr x27, x27, #16
    mov x0, x24
    bl _gtk_toggle_button_get_active
    cbz x0, Lgtk_state_store
    orr x27, x27, #32
Lgtk_state_store:
    cmp x26, x27
    cset x9, ne
    orr x22, x22, x9
    str x27, [x25, #744]
Lgtk_state_sync_next:
    add x21, x21, #1
    b Lgtk_state_sync_node
Lgtk_state_sync_done:
    mov x0, x22
    LEAVE
// document pixel point -> update hover/active using source-mapped text leaves.
.globl _gtk_state_point
_gtk_state_point:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _gtk_engine_hit
    mov x23, #0
    cbz x0, Lgtk_state_point_set
    ldr x23, [x0, #8]
    mov x0, x19
    mov x1, x20
    bl _gtk_engine_text_at
    cbz x1, Lgtk_state_point_set
    mov x24, x0
    LOAD x25, _gtk_doc
    ldr x26, [x25, #24]
Lgtk_state_point_leaf:
    cbz x26, Lgtk_state_point_set
    sub x26, x26, #1
    mov x0, x26
    bl _gtk_engine_node
    ldr x9, [x2]
    cmp x9, #NODE_TEXT
    b.ne Lgtk_state_point_leaf
    ldr x0, [x2, #16]
    bl _gtk_engine_byte
    cmp x24, x0
    b.lt Lgtk_state_point_leaf
    mov x0, x26
    bl _gtk_engine_node
    ldr x0, [x2, #24]
    bl _gtk_engine_byte
    cmp x24, x0
    b.hs Lgtk_state_point_leaf
    mov x23, x26
Lgtk_state_point_set:
    LOAD x0, _gtk_doc
    cbz x0, Lgtk_state_point_done
    mov x1, x23
    mov x2, x21
    mov x3, x22
    bl _engine_interaction_set
    cbz x0, Lgtk_state_point_done
    // The idle path must restyle even when only the pointer state changed.
    mov x9, #1
    STORE x9, gtk_pointer_dirty
    bl _gtk_state_schedule
Lgtk_state_point_done:
    LEAVE
.section __DATA,__bss
.p2align 3
gtk_state_idle: .space 8
gtk_pointer_dirty: .space 8
.globl _gtk_keyboard_mode
_gtk_keyboard_mode: .space 8

.text
.globl _gtk_state_keyboard
_gtk_state_keyboard:
    mov x9, #1
    STORE x9, _gtk_keyboard_mode
    b _gtk_state_schedule
.globl _gtk_state_pointer
_gtk_state_pointer:
    STORE xzr, _gtk_keyboard_mode
    b _gtk_state_schedule

.text
.globl _gtk_state_leave
_gtk_state_leave:
    ENTER
    LOAD x0, _gtk_doc
    cbz x0, Lgtk_state_left
    mov x1, #0
    mov x2, #1
    mov x3, #0
    bl _engine_interaction_set
    cbz x0, Lgtk_state_left
    mov x9, #1
    STORE x9, gtk_pointer_dirty
    bl _gtk_state_schedule
Lgtk_state_left:
    mov x0, #0
    LEAVE
