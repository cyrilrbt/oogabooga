// Successful controls and URL-encoded GET/POST are collected in document order.
.include "src/gtk/gtk.inc"
.text
// node -> nearest form index+1, or zero.
.globl _gtk_form_owner
_gtk_form_owner:
    LOAD x9, _gtk_doc
    ldr x9, [x9, #16]
Lgtk_form_parent:
    cbz x0, Lgtk_form_no_owner
    mov x10, #40
    madd x10, x0, x10, x9
    ldr x11, [x10]
    cmp x11, #NODE_FORM
    b.eq Lgtk_form_owner_found
    ldr x0, [x10, #8]
    b Lgtk_form_parent
Lgtk_form_owner_found:
    add x0, x0, #1
Lgtk_form_no_owner:
    ret
.globl _gtk_form_clicked
_gtk_form_clicked:
    ENTER
    ADDR x1, gtk_form_node_key
    bl _g_object_get_data
    cbz x0, Lgtk_form_click_done
    sub x0, x0, #1
    bl _gtk_form_submit
Lgtk_form_click_done:
    LEAVE
// GString,name,value -> append one escaped pair, fail closed on budget.
.globl _gtk_form_pair
_gtk_form_pair:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x2
    cbnz x0, Lgtk_pair_value
    ADDR x0, gtk_form_empty
Lgtk_pair_value:
    bl _engine_form_encode
    mov x21, x0
    cbz x21, Lgtk_pair_done
    mov x0, x20
    bl _engine_form_encode
    mov x22, x0
    cbz x22, Lgtk_pair_free
    ldr x23, [x19, #8]
    mov x9, #1048576
    cmp x23, x9
    b.hs Lgtk_pair_free_name
    cbz x23, Lgtk_pair_append
    mov x0, x19
    ADDR x1, gtk_form_amp
    bl _g_string_append
Lgtk_pair_append:
    mov x0, x19
    ADDR x1, gtk_form_pair_format
    mov x2, x22
    mov x3, x21
    bl _g_string_append_printf
Lgtk_pair_free_name:
    mov x0, x22
    bl _free
Lgtk_pair_free:
    mov x0, x21
    bl _free
Lgtk_pair_done:
    LEAVE
.globl _gtk_form_submit
_gtk_form_submit:
    ENTER
    sub sp, sp, #256
    mov x19, x0
    bl _gtk_form_owner
    cbz x0, Lgtk_submit_done
    sub x20, x0, #1
    mov x0, #0
    bl _g_string_new
    mov x21, x0
    LOAD x22, _gtk_doc
    mov x23, #1
Lgtk_submit_control:
    ldr x9, [x22, #24]
    cmp x23, x9
    b.hs Lgtk_submit_navigate
    mov x0, x23
    bl _gtk_form_owner
    sub x0, x0, #1
    cmp x0, x20
    b.ne Lgtk_submit_next
    mov x0, x23
    bl _gtk_engine_node
    mov x24, x0
    mov x25, x1
    ldr x26, [x2]
    ldr x9, [x24, #ATTR_DISABLED]
    cbnz x9, Lgtk_submit_next
    ldr x9, [x24, #ATTR_NAME]
    cbz x9, Lgtk_submit_next
    ldrb w9, [x9]
    cbz x9, Lgtk_submit_next
    cmp x26, #NODE_INPUT
    b.eq Lgtk_submit_input
    cmp x26, #NODE_BUTTON
    b.eq Lgtk_submit_button
    cmp x26, #NODE_TEXTAREA
    b.eq Lgtk_submit_area
    cmp x26, #NODE_SELECT
    b.eq Lgtk_submit_select
    b Lgtk_submit_next
Lgtk_submit_button:
    mov x0, x24
    mov x1, x26
    bl _gtk_control_kind
    cmp x0, #1
    b.ne Lgtk_submit_next
    cmp x23, x19
    b.ne Lgtk_submit_next
    b Lgtk_submit_attribute
Lgtk_submit_input:
    mov x0, x24
    mov x1, x26
    bl _gtk_control_kind
    cmp x0, #3
    b.eq Lgtk_submit_next
    cmp x0, #8
    b.eq Lgtk_submit_next
    cmp x0, #1
    b.eq Lgtk_submit_button
    cmp x0, #2
    b.eq Lgtk_submit_attribute
    cmp x0, #4
    b.eq Lgtk_submit_toggle
    cmp x0, #5
    b.eq Lgtk_submit_toggle
Lgtk_submit_entry:
    ldr x0, [x25, #GN_WIDGET]
    cbz x0, Lgtk_submit_attribute
    bl _gtk_entry_get_text
    b Lgtk_submit_pair
Lgtk_submit_toggle:
    ldr x0, [x25, #GN_WIDGET]
    cbz x0, Lgtk_submit_next
    bl _gtk_toggle_button_get_active
    cbz x0, Lgtk_submit_next
    ldr x0, [x24, #ATTR_VALUE]
    cbnz x0, Lgtk_submit_pair
    ADDR x0, gtk_form_on
    b Lgtk_submit_pair
Lgtk_submit_area:
    ldr x0, [x25, #GN_WIDGET]
    cbz x0, Lgtk_submit_attribute
    bl _gtk_text_view_get_buffer
    mov x27, x0
    mov x1, sp
    add x2, sp, #80
    bl _gtk_text_buffer_get_bounds
    mov x0, x27
    mov x1, sp
    add x2, sp, #80
    mov x3, #1
    bl _gtk_text_buffer_get_text
    mov x27, x0
    mov x2, x0
    mov x0, x21
    ldr x1, [x24, #ATTR_NAME]
    bl _gtk_form_pair
    mov x0, x27
    bl _g_free
    b Lgtk_submit_next
Lgtk_submit_select:
    mov x0, x23
    mov x1, x21
    bl _gtk_select_pairs
    b Lgtk_submit_next
Lgtk_submit_attribute:
    ldr x0, [x24, #ATTR_VALUE]
Lgtk_submit_pair:
    mov x2, x0
    mov x0, x21
    ldr x1, [x24, #ATTR_NAME]
    bl _gtk_form_pair
Lgtk_submit_next:
    add x23, x23, #1
    b Lgtk_submit_control
Lgtk_submit_navigate:
    mov x0, x20
    bl _gtk_engine_node
    mov x24, x0
    ldr x1, [x24, #ATTR_ACTION]
    cbz x1, Lgtk_submit_current_url
    ldrb w9, [x1]
    cbz w9, Lgtk_submit_current_url
Lgtk_submit_action:
    LOAD x0, _gtk_base
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    b Lgtk_submit_resolved
Lgtk_submit_current_url:
    LOAD x0, _gtk_uri
    bl _g_strdup
Lgtk_submit_resolved:
    mov x25, x0
    cbz x25, Lgtk_submit_free
    ldr x0, [x24, #ATTR_METHOD]
    cbz x0, Lgtk_submit_get
    ADDR x1, gtk_form_post_type
    bl _strcasecmp
    cbnz x0, Lgtk_submit_get
    mov x0, x25
    ldr x1, [x21]
    bl _gtk_engine_post
    b Lgtk_submit_url_free
Lgtk_submit_get:
    mov x0, x25
    ADDR x1, gtk_form_delimiters
    bl _strcspn
    mov x1, x0
    mov x0, x25
    bl _g_strndup
    mov x26, x0
    ADDR x1, gtk_form_query
    ldr x2, [x21]
    mov x3, #0
    bl _g_strconcat
    mov x27, x0
    bl _gtk_engine_load_uri
    mov x0, x27
    bl _g_free
    mov x0, x26
    bl _g_free
Lgtk_submit_url_free:
    mov x0, x25
    bl _g_free
Lgtk_submit_free:
    mov x0, x21
    mov x1, #1
    bl _g_string_free
Lgtk_submit_done:
    add sp, sp, #256
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_form_empty: .asciz ""
gtk_form_amp: .asciz "&"
gtk_form_query: .asciz "?"
gtk_form_delimiters: .asciz "?#"
gtk_form_pair_format: .asciz "%s=%s"
gtk_form_submit_type: .asciz "submit"
gtk_form_post_type: .asciz "post"
gtk_form_hidden: .asciz "hidden"
gtk_form_check: .asciz "checkbox"
gtk_form_radio: .asciz "radio"
gtk_form_on: .asciz "on"

gtk_form_node_key: .asciz "oogabooga-control-node"
