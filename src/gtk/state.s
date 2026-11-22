// GTK/Pango/Cairo adapter state. All access is on the GLib main context.
.include "src/gtk/gtk.inc"
.text
.p2align 2
// widget,signal,callback,user_data -> signal connection
.globl _gtk_engine_connect
_gtk_engine_connect:
    mov x4, #0
    mov x5, #0
    b _g_signal_connect_data

// doc, width. The caller owns doc until the next navigation commit.
.globl _gtk_engine_prepare
_gtk_engine_prepare:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _gtk_focus_save
    bl _gtk_controls_hide
    LOAD x9, _gtk_scene
    STORE x9, _gtk_previous_scene
    STORE xzr, _gtk_scene
    bl _gtk_engine_clear_layout
    STORE x19, _gtk_doc
    mov x9, #64
    cmp x20, x9
    csel x20, x9, x20, lt
    STORE x20, _gtk_width
    ldr x9, [x19, #72]
    str x20, [x9, #856]
    mov x0, x19
    bl _gtk_link_states
    mov x0, x19
    bl _engine_css_apply
    mov x0, x19
    mov x1, #0
    bl _engine_layout
    cbz x0, Lgtk_prepare_bad
    STORE x0, _gtk_flow
    mov x21, x0
    ldr x22, [x0, #8]
    add x0, x22, #2
    mov x1, #8
    bl _calloc
    cbz x0, Lgtk_prepare_bad
    STORE x0, _gtk_utf16_bytes
    mov x23, x0
    ldr x24, [x21]
    mov x25, #0
    mov x26, #0
Lgtk_utf16_map:
    cmp x25, x22
    b.hs Lgtk_utf16_done
    str x25, [x23, x26, lsl #3]
    add x26, x26, #1
    ldrb w9, [x24, x25]
    cmp w9, #0xf0
    b.lo Lgtk_utf16_advance
    str x25, [x23, x26, lsl #3]
    add x26, x26, #1
Lgtk_utf16_advance:
    add x25, x25, #1
Lgtk_utf16_continuation:
    cmp x25, x22
    b.hs Lgtk_utf16_map
    ldrb w9, [x24, x25]
    and w9, w9, #0xc0
    cmp w9, #0x80
    b.ne Lgtk_utf16_map
    add x25, x25, #1
    b Lgtk_utf16_continuation
Lgtk_utf16_done:
    str x25, [x23, x26, lsl #3]
    ldr x0, [x19, #24]
    mov x1, #GN_SIZE
    bl _calloc
    cbz x0, Lgtk_prepare_bad
    STORE x0, _gtk_nodes
    mov x21, x0
    // First-child / next-sibling indices; nodes occur in source order.
    ldr x22, [x19, #24]
Lgtk_index_reverse:
    cmp x22, #1
    b.ls Lgtk_prepare_context
    sub x22, x22, #1
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x22, x10, x9
    ldr x9, [x9, #8]
    add x10, x21, x9, lsl #8
    ldr x11, [x10, #GN_FIRST]
    str x22, [x10, #GN_FIRST]
    add x12, x21, x22, lsl #8
    str x11, [x12, #GN_NEXT]
    str x9, [x12, #GN_PARENT]
    b Lgtk_index_reverse
Lgtk_prepare_context:
    LOAD x0, _gtk_pango_context
    cbnz x0, Lgtk_prepare_measure
    bl _pango_cairo_font_map_get_default
    bl _pango_font_map_create_context
    STORE x0, _gtk_pango_context
Lgtk_prepare_measure:
    mov x0, x19
    mov x1, x20
    bl _engine_box_tree
    bl _gtk_engine_measure
    mov x0, x19
    mov x1, x20
    bl _engine_box_tree
    mov x0, x19
    bl _engine_intrinsic_tree
    mov x0, x19
    bl _engine_flow_tree
    mov x0, x19
    bl _engine_float_tree
    mov x0, x19
    bl _engine_position_tree
    mov x0, x19
    mov x1, #0
    bl _engine_context_reflow
    mov x0, x19
    bl _engine_margin_tree
    mov x0, #0
    mov x1, #0
    mov x2, #0
    mov x3, x20
    bl _gtk_layout_node
    STORE x0, _gtk_height
    bl _gtk_engine_scene
    bl _gtk_engine_commands
    mov x0, #1
    LEAVE
Lgtk_prepare_bad:
    mov x0, #0
    LEAVE

// node -> metadata in x0, native record in x1, source node in x2.
.globl _gtk_engine_node
_gtk_engine_node:
    LOAD x9, _gtk_doc
    ldr x10, [x9, #72]
    add x10, x10, x0, lsl #11
    LOAD x11, _gtk_nodes
    add x1, x11, x0, lsl #8
    ldr x2, [x9, #16]
    mov x11, #40
    madd x2, x0, x11, x2
    mov x0, x10
    ret

// source byte -> normalized UTF8 byte. The core map is indexed in UTF16 units.
.globl _gtk_engine_byte
_gtk_engine_byte:
    LOAD x9, _gtk_flow
    ldr x9, [x9, #16]
    ldr x9, [x9, x0, lsl #3]
    LOAD x10, _gtk_utf16_bytes
    ldr x0, [x10, x9, lsl #3]
    ret

.globl _gtk_engine_clear_layout
_gtk_engine_clear_layout:
    ENTER
    LOAD x19, _gtk_groups
Lgtk_clear_group:
    cbz x19, Lgtk_clear_arrays
    ldr x20, [x19, #GG_NEXT]
    ldr x0, [x19, #GG_LAYOUT]
    cbz x0, Lgtk_clear_attrs
    bl _g_object_unref
Lgtk_clear_attrs:
    ldr x0, [x19, #GG_ATTRS]
    cbz x0, Lgtk_clear_text
    bl _pango_attr_list_unref
Lgtk_clear_text:
    ldr x0, [x19, #GG_TEXT]
    cbz x0, Lgtk_clear_map
    mov x1, #1
    bl _g_string_free
Lgtk_clear_map:
    ldr x0, [x19, #GG_MAP]
    bl _free
    ldr x21, [x19, #GG_ANCHORS]
Lgtk_clear_anchor:
    cbz x21, Lgtk_clear_group_record
    ldr x22, [x21, #GA_NEXT]
    mov x0, x21
    bl _free
    mov x21, x22
    b Lgtk_clear_anchor
Lgtk_clear_group_record:
    mov x0, x19
    bl _free
    mov x19, x20
    b Lgtk_clear_group
Lgtk_clear_arrays:
    STORE xzr, _gtk_groups
    STORE xzr, _gtk_groups_tail
    LOAD x0, _gtk_flow
    cbz x0, Lgtk_clear_nodes
    bl _engine_layout_free
Lgtk_clear_nodes:
    STORE xzr, _gtk_flow
    LOAD x0, _gtk_nodes
    bl _free
    STORE xzr, _gtk_nodes
    LOAD x0, _gtk_utf16_bytes
    bl _free
    STORE xzr, _gtk_utf16_bytes
    LOAD x0, _gtk_scene
    cbz x0, Lgtk_clear_list
    bl _engine_scene_free
Lgtk_clear_list:
    STORE xzr, _gtk_scene
    LOAD x0, _gtk_display
    bl _free
    STORE xzr, _gtk_display
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_doc,_gtk_flow,_gtk_nodes,_gtk_groups,_gtk_groups_tail,_gtk_width,_gtk_height,_gtk_pango_context,_gtk_utf16_bytes,_gtk_scene,_gtk_display
_gtk_doc: .space 8
_gtk_flow: .space 8
_gtk_nodes: .space 8
_gtk_groups: .space 8
_gtk_groups_tail: .space 8
_gtk_width: .space 8
_gtk_height: .space 8
_gtk_pango_context: .space 8
_gtk_utf16_bytes: .space 8
_gtk_scene: .space 8
_gtk_display: .space 8

.globl _gtk_viewport_height
_gtk_viewport_height: .space 8
.globl _gtk_previous_scene
_gtk_previous_scene: .space 8
