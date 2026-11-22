// HTML radio grouping is by exact name and form owner, across native parents.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_radio_create
_gtk_radio_create:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x20, #ATTR_NAME]
    cbz x21, Lgtk_radio_independent
    ldrb w9, [x21]
    cbz x9, Lgtk_radio_independent
    bl _gtk_form_owner
    mov x22, x0
    mov x23, #1
Lgtk_radio_previous:
    cmp x23, x19
    b.hs Lgtk_radio_independent
    mov x0, x23
    bl _gtk_engine_node
    mov x24, x0
    mov x25, x1
    ldr x9, [x2]
    cmp x9, #NODE_INPUT
    b.ne Lgtk_radio_advance
    mov x1, x9
    bl _gtk_control_kind
    cmp x0, #5
    b.ne Lgtk_radio_advance
    ldr x0, [x24, #ATTR_NAME]
    mov x1, x21
    bl _g_strcmp0
    cbnz x0, Lgtk_radio_advance
    mov x0, x23
    bl _gtk_form_owner
    cmp x0, x22
    b.ne Lgtk_radio_advance
    ldr x0, [x25, #GN_WIDGET]
    cbz x0, Lgtk_radio_advance
    bl _gtk_radio_button_get_group
    bl _gtk_radio_button_new
    LEAVE
Lgtk_radio_advance:
    add x23, x23, #1
    b Lgtk_radio_previous
Lgtk_radio_independent:
    // An unparented sentinel allows HTML groups with no selected radio.
    mov x0, #0
    bl _gtk_radio_button_new
    bl _g_object_ref_sink
    mov x19, x0
    bl _gtk_radio_button_get_group
    bl _gtk_radio_button_new
    mov x20, x0
    ADDR x1, gtk_radio_sentinel
    mov x2, x19
    CALLBACK x3, _g_object_unref
    bl _g_object_set_data_full
    mov x0, x20
    LEAVE

.section __TEXT,__cstring,cstring_literals
gtk_radio_sentinel: .asciz "oogabooga-radio-sentinel"
