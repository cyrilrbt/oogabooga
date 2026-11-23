// Source-based selection and link activation share the retained scene hit map.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_selection_reset
_gtk_selection_reset:
    STORE xzr, _gtk_selection_anchor
    STORE xzr, _gtk_selection_focus
    STORE xzr, gtk_selection_drag
    STORE xzr, gtk_press_armed
    ret
// Event coordinates -> integer document pixels, x0/x1.
gtk_event_xy:
    ENTER
    add x1, sp, #144
    add x2, sp, #152
    bl _gdk_event_get_coords
    ldp d0, d1, [sp, #144]
    fcvtzs x0, d0
    fcvtzs x1, d1
    LEAVE
.globl _gtk_engine_click
_gtk_engine_click:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x1
    add x1, sp, #144
    bl _gdk_event_get_button
    ldr w9, [sp, #144]
    cmp x9, #1
    b.ne Lgtk_press_done
    mov x0, x19
    bl _gtk_widget_grab_focus
    mov x0, x20
    bl gtk_event_xy
    STORE xzr, _gtk_keyboard_mode
    STORE x0, gtk_press_x
    STORE x1, gtk_press_y
    mov x2, #3
    mov x3, #3
    bl _gtk_state_point
    LOAD x0, gtk_press_x
    LOAD x1, gtk_press_y
    bl _gtk_engine_text_at
    cbz x1, Lgtk_press_clear
    STORE x0, _gtk_selection_anchor
    STORE x0, _gtk_selection_focus
    mov x9, #1
    STORE x9, gtk_selection_drag
    b Lgtk_press_redraw
Lgtk_press_clear:
    bl _gtk_selection_reset
Lgtk_press_redraw:
    mov x9, #1
    STORE x9, gtk_press_armed
    LOAD x0, _gtk_drawing
    bl _gtk_widget_queue_draw
Lgtk_press_done:
    mov x0, #1
    LEAVE
.globl _gtk_engine_motion
_gtk_engine_motion:
    ENTER
    mov x19, x0
    mov x0, x1
    bl gtk_event_xy
    mov x20, x0
    mov x21, x1
    STORE x20, _gtk_mouse_x
    STORE x21, _gtk_mouse_y
    LOAD x9, gtk_selection_drag
    cbz x9, Lgtk_motion_hover
    bl _gtk_engine_text_at
    cbz x1, Lgtk_motion_done
    STORE x0, _gtk_selection_focus
    LOAD x0, _gtk_drawing
    bl _gtk_widget_queue_draw
    b Lgtk_motion_done
Lgtk_motion_hover:
    mov x0, x20
    mov x1, x21
    mov x2, #1
    mov x3, #1
    bl _gtk_state_point
    mov x0, x20
    mov x1, x21
    bl _gtk_engine_link_at
    mov x22, x0
    mov x0, x19
    bl _gtk_widget_get_display
    ADDR x1, gtk_text_cursor
    cbz x22, Lgtk_cursor_create
    ADDR x1, gtk_link_cursor
Lgtk_cursor_create:
    bl _gdk_cursor_new_from_name
    mov x23, x0
    mov x0, x19
    bl _gtk_widget_get_window
    mov x1, x23
    bl _gdk_window_set_cursor
    mov x0, x23
    cbz x0, Lgtk_motion_done
    bl _g_object_unref
Lgtk_motion_done:
    mov x0, #1
    LEAVE
.globl _gtk_engine_release
_gtk_engine_release:
    ENTER
    mov x19, x1
    LOAD x9, gtk_press_armed
    cbz x9, Lgtk_release_done
    STORE xzr, gtk_press_armed
    STORE xzr, gtk_selection_drag
    LOAD x0, _gtk_doc
    mov x1, #0
    mov x2, #2
    mov x3, #0
    bl _engine_interaction_set
    bl _gtk_state_schedule
    mov x0, x19
    add x1, sp, #144
    bl _gdk_event_get_button
    ldr w9, [sp, #144]
    cmp x9, #1
    b.ne Lgtk_release_done
    mov x0, x19
    bl gtk_event_xy
    mov x19, x0
    mov x20, x1
    LOAD x9, gtk_press_x
    sub x9, x0, x9
    cmp x9, #3
    b.gt Lgtk_release_done
    cmn x9, #3
    b.lt Lgtk_release_done
    LOAD x9, gtk_press_y
    sub x9, x1, x9
    cmp x9, #3
    b.gt Lgtk_release_done
    cmn x9, #3
    b.lt Lgtk_release_done
    mov x0, x19
    mov x1, x20
    bl _gtk_js_click_at
    cbnz x0, Lgtk_release_done
    mov x0, x19
    mov x1, x20
    bl _gtk_engine_link_at
    cbz x0, Lgtk_release_done
    mov x1, x0
    LOAD x0, _gtk_base
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    cbz x0, Lgtk_release_done
    mov x21, x0
    bl _gtk_engine_load_uri
    mov x0, x21
    bl _g_free
Lgtk_release_done:
    mov x0, #1
    LEAVE
.globl _gtk_selection_copy
_gtk_selection_copy:
    ENTER
    LOAD x19, _gtk_selection_anchor
    LOAD x20, _gtk_selection_focus
    cmp x19, x20
    b.le Lgtk_copy_ordered
    mov x9, x19
    mov x19, x20
    mov x20, x9
Lgtk_copy_ordered:
    cmp x19, x20
    b.eq Lgtk_copy_done
    LOAD x21, _gtk_flow
    cbz x21, Lgtk_copy_done
    ldr x9, [x21, #8]
    cmp x20, x9
    b.hi Lgtk_copy_done
    ADDR x0, gtk_clipboard_atom
    bl _gdk_atom_intern_static_string
    bl _gtk_clipboard_get
    ldr x1, [x21]
    add x1, x1, x19
    sub x2, x20, x19
    bl _gtk_clipboard_set_text
Lgtk_copy_done:
    LEAVE
.globl _gtk_engine_key
_gtk_engine_key:
    ENTER
    mov x9, #1
    STORE x9, _gtk_keyboard_mode
    mov x19, x1
    mov x0, x1
    add x1, sp, #144
    bl _gdk_event_get_state
    ldr w9, [sp, #144]
    mov x10, #0x1c00000d
    and x9, x9, x10
    cmp x9, #4
    b.ne Lgtk_key_unhandled
    mov x0, x19
    add x1, sp, #148
    bl _gdk_event_get_keyval
    ldr w9, [sp, #148]
    cmp x9, #97
    b.eq Lgtk_select_all
    cmp x9, #99
    b.ne Lgtk_key_unhandled
    bl _gtk_selection_copy
    mov x0, #1
    LEAVE
Lgtk_select_all:
    LOAD x9, _gtk_flow
    cbz x9, Lgtk_key_unhandled
    STORE xzr, _gtk_selection_anchor
    ldr x9, [x9, #8]
    STORE x9, _gtk_selection_focus
    LOAD x0, _gtk_drawing
    bl _gtk_widget_queue_draw
    mov x0, #1
    LEAVE
Lgtk_key_unhandled:
    mov x0, x19
    bl _gtk_engine_scroll_key
    LEAVE

// cairo,group -> draw per-line selection rectangles in source coordinates.
.globl _gtk_selection_paint
_gtk_selection_paint:
    ENTER
    mov x19, x0
    mov x20, x1
    LOAD x21, _gtk_selection_anchor
    LOAD x22, _gtk_selection_focus
    cmp x21, x22
    b.eq Lgtk_selection_painted
    b.lt Lgtk_selection_ordered
    mov x9, x21
    mov x21, x22
    mov x22, x9
Lgtk_selection_ordered:
    ldr x23, [x20, #GG_MAP]
    ldr x24, [x20, #GG_LENGTH]
    mov x25, #0
Lgtk_selection_start:
    cmp x25, x24
    b.hs Lgtk_selection_painted
    ldr x9, [x23, x25, lsl #3]
    cmp x9, x21
    b.ge Lgtk_selection_end_start
    add x25, x25, #1
    b Lgtk_selection_start
Lgtk_selection_end_start:
    mov x26, x25
Lgtk_selection_end:
    cmp x26, x24
    b.hs Lgtk_selection_ranges
    ldr x9, [x23, x26, lsl #3]
    cmp x9, x22
    b.ge Lgtk_selection_ranges
    add x26, x26, #1
    b Lgtk_selection_end
Lgtk_selection_ranges:
    cmp x25, x26
    b.eq Lgtk_selection_painted
    ldr x0, [x20, #GG_LAYOUT]
    bl _pango_layout_get_iter
    mov x21, x0
    mov x0, x19
    mov x1, #0x80aaff
    bl _gtk_paint_color
Lgtk_selection_line:
    mov x0, x21
    mov x1, #0
    add x2, sp, #144
    bl _pango_layout_iter_get_line_extents
    mov x0, x21
    bl _pango_layout_iter_get_line_readonly
    mov x1, x25
    mov x2, x26
    add x3, sp, #160
    add x4, sp, #168
    bl _pango_layout_line_get_x_ranges
    ldr x22, [sp, #160]
    ldr w23, [sp, #168]
    mov x24, #0
Lgtk_selection_range:
    cmp x24, x23
    b.hs Lgtk_selection_line_next
    add x9, x22, x24, lsl #3
    ldp w10, w11, [x9]
    scvtf d0, x10
    sub x11, x11, x10
    scvtf d2, x11
    ldr w9, [sp, #148]
    scvtf d1, x9
    ldr w9, [sp, #156]
    scvtf d3, x9
    mov x9, #1024
    scvtf d4, x9
    fdiv d0, d0, d4
    fdiv d1, d1, d4
    fdiv d2, d2, d4
    fdiv d3, d3, d4
    ldr x9, [x20, #GG_X]
    scvtf d4, x9
    fadd d0, d0, d4
    ldr x9, [x20, #GG_Y]
    scvtf d4, x9
    fadd d1, d1, d4
    mov x0, x19
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_fill
    add x24, x24, #1
    b Lgtk_selection_range
Lgtk_selection_line_next:
    mov x0, x22
    bl _g_free
    mov x0, x21
    bl _pango_layout_iter_next_line
    cbnz x0, Lgtk_selection_line
    mov x0, x21
    bl _pango_layout_iter_free
Lgtk_selection_painted:
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_selection_anchor,_gtk_selection_focus
_gtk_selection_anchor: .space 8
_gtk_selection_focus: .space 8
.globl _gtk_mouse_x,_gtk_mouse_y
_gtk_mouse_x: .space 8
_gtk_mouse_y: .space 8
gtk_selection_drag: .space 8
gtk_press_x: .space 8
gtk_press_y: .space 8
gtk_press_armed: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_text_cursor: .asciz "text"
gtk_link_cursor: .asciz "pointer"
gtk_clipboard_atom: .asciz "CLIPBOARD"
