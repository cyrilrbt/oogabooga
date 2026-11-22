// Native popup/list choices retain DOM ordering; labels remain parser-owned text.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_select_create
_gtk_select_create:
    ENTER
    mov x19, x0
    bl _gtk_engine_node
    mov x20, x0
    ldr x9, [x20, #ATTR_MULTIPLE]
    cbnz x9, Lgtk_select_multiple
    bl _gtk_combo_box_text_new
    mov x21, x0
    b Lgtk_select_options
Lgtk_select_multiple:
    bl _gtk_list_box_new
    mov x21, x0
    mov x1, #3
    bl _gtk_list_box_set_selection_mode
Lgtk_select_options:
    LOAD x22, _gtk_doc
    add x23, x19, #1
    mov x24, #0
    mov x25, #-1
Lgtk_select_next:
    ldr x9, [x22, #24]
    cmp x23, x9
    b.hs Lgtk_select_finish
    mov x0, x23
    bl _gtk_engine_node
    mov x26, x0
    ldr x9, [x2]
    cmp x9, #NODE_OPTION
    b.ne Lgtk_select_advance
    ldr x9, [x2, #8]
    cmp x9, x19
    b.ne Lgtk_select_advance
    ldr x9, [x22]
    ldr x10, [x2, #16]
    add x0, x9, x10
    ldr x10, [x2, #24]
    add x1, x9, x10
    bl _css_trim
    sub x1, x1, x0
    bl _g_strndup
    mov x27, x0
    ldr x9, [x20, #ATTR_MULTIPLE]
    cbnz x9, Lgtk_select_list_option
    mov x0, x21
    mov x1, x27
    bl _gtk_combo_box_text_append_text
    ldr x9, [x26, #ATTR_DISABLED]
    cbnz x9, Lgtk_select_option_done
    cmn x25, #1
    b.ne Lgtk_select_option_selected
    mov x25, x24
Lgtk_select_option_selected:
    ldr x9, [x26, #ATTR_SELECTED]
    cbz x9, Lgtk_select_option_done
    mov x25, x24
    b Lgtk_select_option_done
Lgtk_select_list_option:
    mov x0, x27
    bl _gtk_label_new
    mov x1, x0
    mov x0, x21
    mov x2, #-1
    bl _gtk_list_box_insert
    mov x0, x21
    mov x1, x24
    bl _gtk_list_box_get_row_at_index
    mov x28, x0
    ldr x9, [x26, #ATTR_DISABLED]
    cmp x9, #0
    cset x1, eq
    bl _gtk_widget_set_sensitive
    ldr x9, [x26, #ATTR_DISABLED]
    cbnz x9, Lgtk_select_option_done
    ldr x9, [x26, #ATTR_SELECTED]
    cbz x9, Lgtk_select_option_done
    mov x0, x21
    mov x1, x28
    bl _gtk_list_box_select_row
Lgtk_select_option_done:
    mov x0, x27
    bl _g_free
    add x24, x24, #1
Lgtk_select_advance:
    add x23, x23, #1
    b Lgtk_select_next
Lgtk_select_finish:
    ldr x9, [x20, #ATTR_MULTIPLE]
    cbnz x9, Lgtk_select_return
    mov x0, x21
    mov x1, x25
    bl _gtk_combo_box_set_active
Lgtk_select_return:
    mov x0, x21
    LEAVE
.text
// select index, query GString -> append selected enabled values in source order.
.globl _gtk_select_pairs
_gtk_select_pairs:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _gtk_engine_node
    mov x21, x0
    ldr x22, [x1, #GN_WIDGET]
    cbz x22, Lgtk_select_pairs_done
    ldr x9, [x21, #ATTR_MULTIPLE]
    cbnz x9, Lgtk_select_pairs_begin
    mov x0, x22
    bl _gtk_combo_box_get_active
    mov x23, x0
Lgtk_select_pairs_begin:
    add x24, x19, #1
    mov x25, #0
    LOAD x26, _gtk_doc
Lgtk_select_pairs_next:
    ldr x9, [x26, #24]
    cmp x24, x9
    b.hs Lgtk_select_pairs_done
    mov x0, x24
    bl _gtk_engine_node
    mov x27, x0
    str x2, [sp, #144]
    ldr x9, [x2]
    cmp x9, #NODE_OPTION
    b.ne Lgtk_select_pairs_advance
    ldr x9, [x2, #8]
    cmp x9, x19
    b.ne Lgtk_select_pairs_advance
    ldr x9, [x27, #ATTR_DISABLED]
    cbnz x9, Lgtk_select_pairs_option_advance
    ldr x9, [x21, #ATTR_MULTIPLE]
    cbnz x9, Lgtk_select_pairs_multi
    cmp x25, x23
    b.ne Lgtk_select_pairs_option_advance
    b Lgtk_select_pairs_value
Lgtk_select_pairs_multi:
    mov x0, x22
    mov x1, x25
    bl _gtk_list_box_get_row_at_index
    cbz x0, Lgtk_select_pairs_option_advance
    bl _gtk_list_box_row_is_selected
    cbz x0, Lgtk_select_pairs_option_advance
Lgtk_select_pairs_value:
    ldr x28, [x27, #ATTR_VALUE]
    str xzr, [sp, #152]
    cbnz x28, Lgtk_select_pairs_append
    ldr x9, [sp, #144]
    ldr x10, [x26]
    ldr x11, [x9, #16]
    add x0, x10, x11
    ldr x11, [x9, #24]
    add x1, x10, x11
    bl _css_trim
    sub x1, x1, x0
    bl _g_strndup
    mov x28, x0
    str x0, [sp, #152]
Lgtk_select_pairs_append:
    mov x0, x20
    ldr x1, [x21, #ATTR_NAME]
    mov x2, x28
    bl _gtk_form_pair
    ldr x0, [sp, #152]
    bl _g_free
Lgtk_select_pairs_option_advance:
    add x25, x25, #1
Lgtk_select_pairs_advance:
    add x24, x24, #1
    b Lgtk_select_pairs_next
Lgtk_select_pairs_done:
    LEAVE
