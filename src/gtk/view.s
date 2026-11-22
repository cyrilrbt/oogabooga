// GTK document view. One retained layout backs painting and native controls.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_engine_view_new
_gtk_engine_view_new:
    ENTER
    mov x0, #0
    mov x1, #0
    bl _gtk_scrolled_window_new
    STORE x0, _gtk_view
    mov x0, #0
    mov x1, #0
    bl _gtk_layout_new
    STORE x0, _gtk_canvas
    mov x1, x0
    LOAD x0, _gtk_view
    bl _gtk_container_add
    bl _gtk_drawing_area_new
    STORE x0, _gtk_drawing
    mov x1, x0
    LOAD x0, _gtk_canvas
    mov x2, #0
    mov x3, #0
    bl _gtk_layout_put
    LOAD x0, _gtk_drawing
    ADDR x1, gtk_sig_draw
    CALLBACK x2, _gtk_engine_draw
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_canvas
    ADDR x1, gtk_sig_allocate
    CALLBACK x2, _gtk_engine_allocate
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_view
    bl _gtk_scrolled_window_get_hadjustment
    ADDR x1, gtk_sig_scroll_changed
    CALLBACK x2, _gtk_scroll_changed
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_view
    bl _gtk_scrolled_window_get_vadjustment
    ADDR x1, gtk_sig_scroll_changed
    CALLBACK x2, _gtk_scroll_changed
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_drawing
    mov x1, #10487556 // pointer, keyboard, discrete and smooth scroll events
    bl _gtk_widget_add_events
    LOAD x0, _gtk_drawing
    mov x1, #1
    bl _gtk_widget_set_can_focus
    LOAD x0, _gtk_drawing
    ADDR x1, gtk_sig_wheel
    CALLBACK x2, _gtk_engine_wheel
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_drawing
    ADDR x1, gtk_sig_key
    CALLBACK x2, _gtk_engine_key
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_drawing
    ADDR x1, gtk_sig_release
    CALLBACK x2, _gtk_engine_release
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_drawing
    ADDR x1, gtk_sig_motion
    CALLBACK x2, _gtk_engine_motion
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_drawing
    ADDR x1, gtk_sig_click
    CALLBACK x2, _gtk_engine_click
    mov x3, #0
    bl _gtk_engine_connect
    LOAD x0, _gtk_view
    LEAVE
.globl _gtk_engine_draw
_gtk_engine_draw:
    ENTER
    mov x0, x1
    bl _gtk_engine_paint
    mov x0, #0
    LEAVE
.globl _gtk_engine_allocate
_gtk_engine_allocate:
    ENTER
    ldr w9, [x1, #12]
    STORE x9, _gtk_viewport_height
    ldr w19, [x1, #8]
    cmp x19, #64
    b.lt Lgtk_allocate_done
    LOAD x9, _gtk_width
    cmp x19, x9
    b.eq Lgtk_allocate_done
    LOAD x0, _gtk_doc
    cbz x0, Lgtk_allocate_done
    mov x1, x19
    bl _gtk_engine_prepare
    bl _gtk_engine_place
Lgtk_allocate_done:
    LEAVE
.globl _gtk_engine_show_document
_gtk_engine_show_document:
    ENTER
    mov x19, x0
    LOAD x0, _gtk_canvas
    bl _gtk_widget_get_allocated_width
    mov x1, x0
    mov x0, x19
    bl _gtk_engine_prepare
    bl _gtk_engine_place
    LEAVE
.globl _gtk_engine_place
_gtk_engine_place:
    ENTER
    LOAD x0, _gtk_canvas
    cbz x0, Lgtk_place_done
    LOAD x1, _gtk_width
    LOAD x2, _gtk_height
    bl _gtk_layout_set_size
    LOAD x0, _gtk_drawing
    LOAD x1, _gtk_width
    LOAD x2, _gtk_height
    bl _gtk_widget_set_size_request
    bl _gtk_engine_controls_place
    LEAVE
.globl _gtk_engine_controls_place
_gtk_engine_controls_place:
    ENTER
    LOAD x19, _gtk_doc
    cbz x19, Lgtk_place_done
    mov x20, #1
Lgtk_place_control:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lgtk_place_draw
    mov x0, x20
    bl _gtk_engine_node
    mov x21, x1
    mov x0, x20
    bl _gtk_node_visible
    cbz x0, Lgtk_place_next
    ldr x22, [x21, #GN_WIDGET]
    cbz x22, Lgtk_place_next
    mov x0, x22
    ADDR x1, gtk_control_host_key
    bl _g_object_get_data
    mov x23, x0
    cbnz x23, Lgtk_place_host_ready
    mov x0, #0
    mov x1, #0
    bl _gtk_layout_new
    mov x23, x0
    ADDR x1, gtk_sig_host_destroy
    CALLBACK x2, _gtk_control_host_destroyed
    mov x3, x22
    bl _gtk_engine_connect
    mov x0, x23
    mov x1, #1
    bl _gtk_widget_set_app_paintable
    mov x0, x22
    ADDR x1, gtk_control_host_key
    mov x2, x23
    bl _g_object_set_data
    LOAD x0, _gtk_canvas
    mov x1, x23
    mov x2, #0
    mov x3, #0
    bl _gtk_layout_put
    mov x0, x23
    mov x1, x22
    mov x2, #0
    mov x3, #0
    bl _gtk_layout_put
Lgtk_place_host_ready:
    str x23, [x21, #GN_HOST]
    LOAD x9, _gtk_scene
    ldr x9, [x9, #8]
    mov x10, x20
    mov x11, #1000
    mov x12, #64
Lgtk_control_opacity:
    cbz x12, Lgtk_control_opacity_ready
    sub x12, x12, #1
    add x13, x9, x10, lsl #9
    ldr x14, [x13, #SC_OPACITY]
    mul x11, x11, x14
    mov x15, #1000
    udiv x11, x11, x15
    cbz x10, Lgtk_control_opacity_ready
    ldr x10, [x13, #SC_PARENT]
    b Lgtk_control_opacity
Lgtk_control_opacity_ready:
    mov x0, x23
    scvtf d0, x11
    mov x9, #1000
    scvtf d1, x9
    fdiv d0, d0, d1
    bl _gtk_widget_set_opacity
    LOAD x0, _gtk_scene
    mov x1, x20
    add x2, sp, #144
    mov x3, #0
    ldr x9, [x21, #GN_X]
    scvtf d0, x9
    ldr x9, [x21, #GN_Y]
    scvtf d1, x9
    ldr x9, [x21, #GN_W]
    scvtf d2, x9
    ldr x9, [x21, #GN_H]
    scvtf d3, x9
    bl _engine_scene_rect
    cbz x0, Lgtk_place_host_hidden
    mov x0, x23
    mov x1, #0
    bl _gtk_widget_set_no_show_all
    LOAD x0, _gtk_canvas
    mov x1, x23
    ldp d0, d1, [sp, #144]
    fcvtzs x2, d0
    fcvtzs x3, d1
    bl _gtk_layout_move
    mov x0, x23
    ldp d0, d1, [sp, #160]
    fcvtzs x1, d0
    fcvtzs x2, d1
    bl _gtk_widget_set_size_request
    LOAD x9, _gtk_scene
    ldr x9, [x9, #8]
    add x9, x9, x20, lsl #9
    ldp d0, d1, [x9, #SC_TX]
    ldr x10, [x21, #GN_X]
    scvtf d2, x10
    fadd d0, d0, d2
    ldr x10, [x21, #GN_Y]
    scvtf d2, x10
    fadd d1, d1, d2
    ldp d2, d3, [sp, #144]
    fsub d0, d0, d2
    fsub d1, d1, d3
    mov x0, x23
    mov x1, x22
    fcvtzs x2, d0
    fcvtzs x3, d1
    bl _gtk_layout_move
    mov x0, x22
    ldr x1, [x21, #GN_W]
    ldr x2, [x21, #GN_H]
    bl _gtk_widget_set_size_request
    b Lgtk_place_next
Lgtk_place_host_hidden:
    mov x0, x23
    bl _gtk_widget_hide
    mov x0, x23
    mov x1, #1
    bl _gtk_widget_set_no_show_all
Lgtk_place_next:
    add x20, x20, #1
    b Lgtk_place_control
Lgtk_place_draw:
    LOAD x0, _gtk_view
    bl _gtk_widget_show_all
    bl _gtk_focus_restore
    LOAD x0, _gtk_drawing
    bl _gtk_widget_queue_draw
Lgtk_place_done:
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_view,_gtk_canvas,_gtk_drawing
_gtk_view: .space 8
_gtk_canvas: .space 8
_gtk_drawing: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_sig_draw: .asciz "draw"
gtk_sig_allocate: .asciz "size-allocate"

gtk_sig_motion: .asciz "motion-notify-event"
gtk_sig_click: .asciz "button-press-event"

.section __TEXT,__cstring,cstring_literals
gtk_control_host_key: .asciz "oogabooga-control-host"

gtk_sig_key: .asciz "key-press-event"
gtk_sig_release: .asciz "button-release-event"

gtk_sig_scroll_changed: .asciz "value-changed"

gtk_sig_wheel: .asciz "scroll-event"

gtk_sig_host_destroy: .asciz "destroy"
