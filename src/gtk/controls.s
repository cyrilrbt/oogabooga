// Native editing widgets are retained separately from the rendering snapshot.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_control_get
_gtk_control_get:
    ENTER
    mov x19, x0
    bl _gtk_engine_node
    mov x20, x0
    mov x21, x2
    ldr x1, [x21]
    bl _gtk_control_kind
    mov x25, x0
    cmp x25, #2
    b.eq Lcontrol_none
    ldr x22, [x20, #DOM_HANDLE]
    cbnz x22, Lcontrol_key
    add x22, x19, #1
Lcontrol_key:
    lsl x22, x22, #4
    orr x22, x22, x25
    LOAD x0, _gtk_controls
    cbnz x0, Lcontrol_lookup
    CALLBACK x0, _g_direct_hash
    CALLBACK x1, _g_direct_equal
    mov x2, #0
    CALLBACK x3, _gtk_control_free
    bl _g_hash_table_new_full
    STORE x0, _gtk_controls
Lcontrol_lookup:
    mov x1, x22
    bl _g_hash_table_lookup
    cbnz x0, Lcontrol_return
    cmp x25, #1
    b.eq Lcontrol_button
    cmp x25, #8
    b.eq Lcontrol_button
    cmp x25, #6
    b.eq Lcontrol_select
    cmp x25, #7
    b.eq Lcontrol_area
    cmp x25, #4
    b.eq Lcontrol_check
    cmp x25, #5
    b.eq Lcontrol_radio
Lcontrol_entry:
    bl _gtk_entry_new
    mov x23, x0
    cmp x25, #3
    b.ne Lcontrol_entry_visibility
    mov x1, #0
    bl _gtk_entry_set_visibility
Lcontrol_entry_visibility:
    mov x0, x23
    ldr x1, [x20, #ATTR_VALUE]
    cbz x1, Lcontrol_entry_placeholder
    bl _gtk_entry_set_text
Lcontrol_entry_placeholder:
    mov x0, x23
    ldr x1, [x20, #ATTR_PLACEHOLDER]
    bl _gtk_entry_set_placeholder_text
    mov x0, x23
    ldr x9, [x20, #ATTR_READONLY]
    cmp x9, #0
    cset x1, eq
    bl _gtk_editable_set_editable
    b Lcontrol_created
Lcontrol_button:
    ldr x0, [x20, #ATTR_LABEL]
    cbnz x0, Lcontrol_button_label
    ldr x0, [x20, #ATTR_VALUE]
    cbnz x0, Lcontrol_button_label
    ADDR x0, gtk_submit_label
Lcontrol_button_label:
    bl _gtk_button_new_with_label
    mov x23, x0
    b Lcontrol_created
Lcontrol_check:
    bl _gtk_check_button_new
    b Lcontrol_toggle
Lcontrol_radio:
    mov x0, x19
    mov x1, x20
    bl _gtk_radio_create
Lcontrol_toggle:
    mov x23, x0
    ldr x9, [x20, #ATTR_CHECKED]
    cmp x9, #0
    cset x1, ne
    bl _gtk_toggle_button_set_active
    b Lcontrol_created
Lcontrol_select:
    mov x0, x19
    bl _gtk_select_create
    mov x23, x0
    b Lcontrol_created
Lcontrol_area:
    bl _gtk_text_view_new
    mov x23, x0
    bl _gtk_text_view_get_buffer
    ldr x1, [x20, #ATTR_VALUE]
    cbnz x1, Lcontrol_area_text
    ADDR x1, gtk_empty
Lcontrol_area_text:
    mov x2, #-1
    bl _gtk_text_buffer_set_text
Lcontrol_created:
    cmp x25, #3
    b.eq Lcontrol_show
    cmp x25, #8
    b.eq Lcontrol_connect_button
    mov x0, x23
    ADDR x1, gtk_control_activate
    ldr x9, [x21]
    cmp x9, #NODE_INPUT
    b.eq Lcontrol_wire
    cmp x9, #NODE_BUTTON
    b.ne Lcontrol_show
    ADDR x1, gtk_control_clicked
Lcontrol_wire:
    // Only entries expose activate; toggles are submitted by the form button.
    ldr x9, [x21]
    cmp x9, #NODE_INPUT
    b.ne Lcontrol_connect
    ldr x9, [x20, #ATTR_TYPE]
    cbz x9, Lcontrol_connect
    mov x0, x9
    ADDR x1, gtk_type_submit
    bl _strcasecmp
    cbz x0, Lcontrol_connect_button
    ldr x0, [x20, #ATTR_TYPE]
    ADDR x1, gtk_type_checkbox
    bl _strcasecmp
    cbz x0, Lcontrol_show
    ldr x0, [x20, #ATTR_TYPE]
    ADDR x1, gtk_type_radio
    bl _strcasecmp
    cbz x0, Lcontrol_show
    ADDR x1, gtk_control_activate
    b Lcontrol_connect
Lcontrol_connect_button:
    ADDR x1, gtk_control_clicked
Lcontrol_connect:
    mov x0, x23
    CALLBACK x2, _gtk_form_clicked
    add x3, x19, #1
    bl _gtk_engine_connect
Lcontrol_show:
    cbnz x25, Lcontrol_js_toggle
    mov x0, x23
    ADDR x1, gtk_js_changed_signal
    CALLBACK x2, _gtk_js_input
    mov x3, #0
    bl _gtk_engine_connect
    b Lcontrol_js_connected
Lcontrol_js_toggle:
    cmp x25, #4
    b.eq Lcontrol_js_wire_toggle
    cmp x25, #5
    b.ne Lcontrol_js_connected
Lcontrol_js_wire_toggle:
    mov x0, x23
    ADDR x1, gtk_live_toggle_signal
    CALLBACK x2, _gtk_js_change
    mov x3, #0
    bl _gtk_engine_connect
Lcontrol_js_connected:
    mov x0, x23
    ADDR x1, gtk_live_key_signal
    CALLBACK x2, _gtk_state_keyboard
    mov x3, #0
    bl _gtk_engine_connect
    mov x0, x23
    ADDR x1, gtk_live_pointer_signal
    CALLBACK x2, _gtk_state_pointer
    mov x3, #0
    bl _gtk_engine_connect
    mov x0, x23
    ADDR x1, gtk_live_state_signal
    CALLBACK x2, _gtk_state_schedule
    mov x3, #0
    bl _gtk_engine_connect
    cmp x25, #4
    b.eq Lcontrol_toggle_signal
    cmp x25, #5
    b.ne Lcontrol_state_wired
Lcontrol_toggle_signal:
    mov x0, x23
    ADDR x1, gtk_live_toggle_signal
    CALLBACK x2, _gtk_state_schedule
    mov x3, #0
    bl _gtk_engine_connect
Lcontrol_state_wired:
    mov x0, x23
    bl _gtk_widget_show
    mov x0, x23
    bl _g_object_ref_sink
    mov x0, x23
    ldr x9, [x20, #ATTR_DISABLED]
    cmp x9, #0
    cset x1, eq
    cmp x25, #3
    csel x1, xzr, x1, eq

    bl _gtk_widget_set_sensitive
    LOAD x0, _gtk_controls
    mov x1, x22
    mov x2, x23
    bl _g_hash_table_insert
    mov x0, x23
Lcontrol_return:
    mov x23, x0
    ADDR x1, gtk_control_node_key
    add x2, x19, #1
    bl _g_object_set_data
    mov x0, x23
    LEAVE
Lcontrol_none:
    mov x0, #0
    LEAVE
.globl _gtk_control_free
_gtk_control_free:
    ENTER
    mov x19, x0
    ADDR x1, gtk_free_host_key
    bl _g_object_get_data
    cbnz x0, Lcontrol_free_host
    mov x0, x19
Lcontrol_free_host:
    bl _gtk_widget_destroy
    mov x0, x19
    bl _g_object_unref
    LEAVE
// Resource cache uses resolved URLs. No synchronous network I/O during layout.
.globl _gtk_image_get
_gtk_image_get:
    ENTER
    bl _gtk_engine_node
    mov x19, x0
    ldr x9, [x2]
    cmp x9, #NODE_SVG
    b.eq Limage_inline
    ldr x1, [x19, #ATTR_SRC]
    cbz x1, Limage_none
    LOAD x0, _gtk_images
    cbz x0, Limage_none
    bl _g_hash_table_lookup
    LEAVE
Limage_inline:
    ldr x20, [x2, #32]
    cbz x20, Limage_none
    LOAD x0, _gtk_images
    cbz x0, Limage_inline_render
    mov x1, x20
    bl _g_hash_table_lookup
    cbnz x0, Limage_return
Limage_inline_render:
    mov x0, x20
    bl _strlen
    mov x1, x0
    mov x0, x20
    mov x2, x19
    bl _mac_svg_image
    cbz x0, Limage_none
    mov x21, x0
    mov x1, x0
    mov x0, x20
    bl _gtk_image_cache
    mov x0, x21
Limage_return:
    LEAVE
Limage_none:
    mov x0, #0
    LEAVE
// raw resource key, owned pixbuf -> cache takes ownership.
.globl _gtk_image_cache
_gtk_image_cache:
    ENTER
    mov x19, x0
    mov x20, x1
    LOAD x0, _gtk_images
    cbnz x0, Limage_cache_store
    CALLBACK x0, _g_str_hash
    CALLBACK x1, _g_str_equal
    CALLBACK x2, _g_free
    CALLBACK x3, _g_object_unref
    bl _g_hash_table_new_full
    STORE x0, _gtk_images
Limage_cache_store:
    mov x0, x19
    bl _g_strdup
    mov x1, x0
    LOAD x0, _gtk_images
    mov x2, x20
    bl _g_hash_table_insert
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_controls,_gtk_images
_gtk_controls: .space 8
_gtk_images: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_type_hidden: .asciz "hidden"
gtk_type_checkbox: .asciz "checkbox"
gtk_type_radio: .asciz "radio"
gtk_type_submit: .asciz "submit"
gtk_submit_label: .asciz "Submit"
gtk_empty: .asciz ""

gtk_control_activate: .asciz "activate"
gtk_control_clicked: .asciz "clicked"

gtk_free_host_key: .asciz "oogabooga-control-host"
.text
.globl _gtk_controls_hide
_gtk_controls_hide:
    LOAD x0, _gtk_controls
    cbz x0, Lgtk_controls_hidden
    CALLBACK x1, _gtk_control_hide
    mov x2, #0
    b _g_hash_table_foreach
Lgtk_controls_hidden:
    ret
.globl _gtk_control_hide
_gtk_control_hide:
    ENTER
    mov x0, x1
    ADDR x1, gtk_free_host_key
    bl _g_object_get_data
    cbz x0, Lgtk_control_hidden
    mov x19, x0
    bl _gtk_widget_hide
    mov x0, x19
    mov x1, #1
    bl _gtk_widget_set_no_show_all
Lgtk_control_hidden:
    LEAVE
.globl _gtk_control_host_destroyed
_gtk_control_host_destroyed:
    mov x0, x1
    ADDR x1, gtk_free_host_key
    mov x2, #0
    b _g_object_set_data

.section __TEXT,__cstring,cstring_literals
gtk_control_node_key: .asciz "oogabooga-control-node"

.section __TEXT,__cstring,cstring_literals
gtk_live_state_signal: .asciz "state-flags-changed"
gtk_live_toggle_signal: .asciz "toggled"

.section __TEXT,__cstring,cstring_literals
gtk_live_key_signal: .asciz "key-press-event"
gtk_live_pointer_signal: .asciz "button-press-event"

gtk_js_changed_signal: .asciz "changed"
