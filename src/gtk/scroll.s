// Native viewport offsets feed fixed-position transforms in the shared scene.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_scroll_changed
_gtk_scroll_changed:
    ENTER
    LOAD x19, _gtk_scene
    cbz x19, Lgtk_scroll_changed_done
    LOAD x0, _gtk_view
    cbz x0, Lgtk_scroll_headless
    bl _gtk_scrolled_window_get_hadjustment
    bl _gtk_adjustment_get_value
    str d0, [sp, #144]
    LOAD x0, _gtk_view
    bl _gtk_scrolled_window_get_vadjustment
    bl _gtk_adjustment_get_value
    fmov d1, d0
    ldr d0, [sp, #144]
    mov x0, x19
    bl _engine_scene_update
    bl _gtk_engine_controls_place
    b Lgtk_scroll_changed_done
Lgtk_scroll_headless:
    mov x0, x19
    ldp d0, d1, [x19, #48]
    bl _engine_scene_update
Lgtk_scroll_changed_done:
    LEAVE
// node,positive content deltas -> consume at deepest eligible container.
.globl _gtk_engine_scroll_node
_gtk_engine_scroll_node:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    LOAD x20, _gtk_scene
    cbz x20, Lgtk_scroll_unconsumed
    mov x21, #64
Lgtk_scroll_ancestor:
    cbz x21, Lgtk_scroll_unconsumed
    sub x21, x21, #1
    mov x0, x20
    mov x1, x19
    ldp d0, d1, [sp, #144]
    bl _engine_scene_scroll
    cbnz x0, Lgtk_scroll_consumed
    cbz x19, Lgtk_scroll_unconsumed
    ldr x9, [x20, #8]
    add x9, x9, x19, lsl #9
    ldr x19, [x9, #SC_PARENT]
    b Lgtk_scroll_ancestor
Lgtk_scroll_consumed:
    bl _gtk_scroll_changed
    mov x0, #1
    LEAVE
Lgtk_scroll_unconsumed:
    mov x0, #0
    LEAVE
// document point x0/x1 and positive deltas d0/d1 -> consumed BOOL.
.globl _gtk_engine_scroll_at
_gtk_engine_scroll_at:
    ENTER
    stp d0, d1, [sp, #144]
    bl _gtk_engine_hit
    cbz x0, Lgtk_scroll_at_none
    ldr x0, [x0, #8]
    ldp d0, d1, [sp, #144]
    bl _gtk_engine_scroll_node
    LEAVE
Lgtk_scroll_at_none:
    mov x0, #0
    LEAVE
.globl _gtk_engine_wheel
_gtk_engine_wheel:
    ENTER
    mov x19, x1
    mov x0, x19
    add x1, sp, #144
    add x2, sp, #152
    bl _gdk_event_get_coords
    mov x0, x19
    add x1, sp, #160
    add x2, sp, #168
    bl _gdk_event_get_scroll_deltas
    cbnz x0, Lgtk_wheel_smooth
    mov x0, x19
    add x1, sp, #176
    bl _gdk_event_get_scroll_direction
    fmov d0, xzr
    fmov d1, xzr
    ldr w9, [sp, #176]
    mov x10, #40
    scvtf d2, x10
    cmp x9, #0
    b.eq Lgtk_wheel_up
    cmp x9, #1
    b.eq Lgtk_wheel_down
    cmp x9, #2
    b.eq Lgtk_wheel_left
    cmp x9, #3
    b.ne Lgtk_wheel_no_delta
    fmov d0, d2
    b Lgtk_wheel_point
Lgtk_wheel_up:
    fneg d1, d2
    b Lgtk_wheel_point
Lgtk_wheel_down:
    fmov d1, d2
    b Lgtk_wheel_point
Lgtk_wheel_left:
    fneg d0, d2
    b Lgtk_wheel_point
Lgtk_wheel_smooth:
    ldp d0, d1, [sp, #160]
    mov x9, #40
    scvtf d2, x9
    fmul d0, d0, d2
    fmul d1, d1, d2
Lgtk_wheel_point:
    ldp d2, d3, [sp, #144]
    fcvtzs x0, d2
    fcvtzs x1, d3
    bl _gtk_engine_scroll_at
    LEAVE
Lgtk_wheel_no_delta:
    mov x0, #0
    LEAVE
// Unmodified reading keys use contained scroll chaining before the document.
.globl _gtk_engine_scroll_key
_gtk_engine_scroll_key:
    ENTER
    mov x19, x0
    add x1, sp, #144
    bl _gdk_event_get_state
    ldr w9, [sp, #144]
    and x9, x9, #0x1c00000d
    cbnz x9, Lgtk_scroll_key_no
    mov x0, x19
    add x1, sp, #148
    bl _gdk_event_get_keyval
    ldr w20, [sp, #148]
    mov x21, #0
    mov x22, #0
    cmp x20, #65362 // Up
    b.eq Lgtk_key_up
    cmp x20, #65364 // Down
    b.eq Lgtk_key_down
    cmp x20, #65361 // Left
    b.eq Lgtk_key_left
    cmp x20, #65363 // Right
    b.eq Lgtk_key_right
    cmp x20, #65365 // Page Up
    b.eq Lgtk_key_page_up
    cmp x20, #65366 // Page Down
    b.eq Lgtk_key_page_down
    cmp x20, #32
    b.eq Lgtk_key_page_down
    cmp x20, #65360 // Home
    b.eq Lgtk_key_home
    cmp x20, #65367 // End
    b.ne Lgtk_scroll_key_no
    mov x22, #1000000000
    b Lgtk_key_scroll
Lgtk_key_home:
    mov x22, #-1000000000
    b Lgtk_key_scroll
Lgtk_key_page_up:
    LOAD x22, _gtk_viewport_height
    neg x22, x22
    b Lgtk_key_scroll
Lgtk_key_page_down:
    LOAD x22, _gtk_viewport_height
    b Lgtk_key_scroll
Lgtk_key_up:
    mov x22, #-40
    b Lgtk_key_scroll
Lgtk_key_down:
    mov x22, #40
    b Lgtk_key_scroll
Lgtk_key_left:
    mov x21, #-40
    b Lgtk_key_scroll
Lgtk_key_right:
    mov x21, #40
Lgtk_key_scroll:
    LOAD x0, _gtk_mouse_x
    LOAD x1, _gtk_mouse_y
    scvtf d0, x21
    scvtf d1, x22
    bl _gtk_engine_scroll_at
    cbnz x0, Lgtk_scroll_key_yes
    LOAD x0, _gtk_view
    cbnz x21, Lgtk_key_document_horizontal
    bl _gtk_scrolled_window_get_vadjustment
    b Lgtk_key_document_adjust
Lgtk_key_document_horizontal:
    mov x22, x21
    bl _gtk_scrolled_window_get_hadjustment
Lgtk_key_document_adjust:
    mov x23, x0
    bl _gtk_adjustment_get_value
    scvtf d1, x22
    fadd d0, d0, d1
    mov x0, x23
    bl _gtk_adjustment_set_value
Lgtk_scroll_key_yes:
    mov x0, #1
    LEAVE
Lgtk_scroll_key_no:
    mov x0, #0
    LEAVE

.globl _gtk_scene_view_origin
_gtk_scene_view_origin:
    ENTER
    LOAD x0, _gtk_view
    cbz x0, Lgtk_origin_zero
    bl _gtk_scrolled_window_get_hadjustment
    bl _gtk_adjustment_get_value
    str d0, [sp, #144]
    LOAD x0, _gtk_view
    bl _gtk_scrolled_window_get_vadjustment
    bl _gtk_adjustment_get_value
    fmov d1, d0
    ldr d0, [sp, #144]
    LEAVE
Lgtk_origin_zero:
    fmov d0, xzr
    fmov d1, xzr
    LEAVE
