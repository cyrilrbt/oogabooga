// Bounded stable ordering for the core's at-most-256 flex items. DOM/source
// order remains intact for selection and form submission.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_flex_children
_gtk_flex_children:
    ENTER
    sub sp, sp, #4096
    mov x19, x0
    bl _gtk_engine_node
    mov x20, x1
    ldr x28, [x0, #(32+CSS_DIRECTION*8)]
    ldr x21, [x20, #GN_FIRST]
    mov x22, #0
    mov x23, #0 // ineligible tail chain
    mov x24, #0
Lgtk_order_collect:
    cbz x21, Lgtk_order_sort
    mov x0, x21
    bl _gtk_engine_node
    ldr x25, [x1, #GN_NEXT]
    mov x26, x1
    LOAD x0, _gtk_doc
    mov x1, x21
    bl _engine_flow_item
    cbz x0, Lgtk_order_excluded
    cmp x22, #256
    b.hs Lgtk_order_excluded
    mov x0, x21
    bl _gtk_engine_node
    ldr x9, [x0, #FLOW_ROW]
    ldr x10, [x0, #FLOW_COLUMN]
    cmp x28, #2
    csel x10, x21, x10, eq
    lsl x9, x9, #32
    orr x9, x9, x10
    add x10, sp, x22, lsl #4
    stp x21, x9, [x10]
    add x22, x22, #1
    b Lgtk_order_collect_next
Lgtk_order_excluded:
    cbz x24, Lgtk_order_excluded_first
    LOAD x9, _gtk_nodes
    add x9, x9, x24, lsl #8
    str x21, [x9, #GN_NEXT]
    b Lgtk_order_excluded_last
Lgtk_order_excluded_first:
    mov x23, x21
Lgtk_order_excluded_last:
    mov x24, x21
    str xzr, [x26, #GN_NEXT]
Lgtk_order_collect_next:
    mov x21, x25
    b Lgtk_order_collect
Lgtk_order_sort:
    mov x21, #1
Lgtk_order_insert:
    cmp x21, x22
    b.hs Lgtk_order_link
    add x9, sp, x21, lsl #4
    ldp x25, x26, [x9]
    mov x27, x21
Lgtk_order_shift:
    cbz x27, Lgtk_order_slot
    sub x9, x27, #1
    add x9, sp, x9, lsl #4
    ldp x10, x11, [x9]
    cmp x11, x26
    b.ls Lgtk_order_slot
    stp x10, x11, [x9, #16]
    sub x27, x27, #1
    b Lgtk_order_shift
Lgtk_order_slot:
    add x9, sp, x27, lsl #4
    stp x25, x26, [x9]
    add x21, x21, #1
    b Lgtk_order_insert
Lgtk_order_link:
    cbz x22, Lgtk_order_no_items
    ldr x9, [sp]
    str x9, [x20, #GN_FIRST]
    mov x21, #0
Lgtk_order_link_item:
    add x9, sp, x21, lsl #4
    ldr x10, [x9]
    add x21, x21, #1
    mov x11, x23
    cmp x21, x22
    b.hs Lgtk_order_link_next
    ldr x11, [x9, #16]
Lgtk_order_link_next:
    LOAD x9, _gtk_nodes
    add x9, x9, x10, lsl #8
    str x11, [x9, #GN_NEXT]
    cmp x21, x22
    b.lo Lgtk_order_link_item
    b Lgtk_order_done
Lgtk_order_no_items:
    str x23, [x20, #GN_FIRST]
Lgtk_order_done:
    add sp, sp, #4096
    LEAVE
