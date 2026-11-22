// Relocate an independently laid out inline formatting context as one object.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_translate_subtree
_gtk_translate_subtree:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x22, _gtk_doc
    mov x23, x19
Lgtk_translate_node:
    ldr x9, [x22, #24]
    cmp x23, x9
    b.hs Lgtk_translate_groups
    mov x24, x23
Lgtk_translate_ancestor:
    cmp x24, x19
    b.eq Lgtk_translate_this
    cbz x24, Lgtk_translate_advance
    LOAD x9, _gtk_nodes
    add x9, x9, x24, lsl #8
    ldr x24, [x9, #GN_PARENT]
    b Lgtk_translate_ancestor
Lgtk_translate_this:
    LOAD x9, _gtk_nodes
    add x9, x9, x23, lsl #8
    ldp x10, x11, [x9, #GN_X]
    add x10, x10, x20
    add x11, x11, x21
    stp x10, x11, [x9, #GN_X]
    ldp x10, x11, [x9, #GN_CX]
    add x10, x10, x20
    add x11, x11, x21
    stp x10, x11, [x9, #GN_CX]
Lgtk_translate_advance:
    add x23, x23, #1
    b Lgtk_translate_node
Lgtk_translate_groups:
    LOAD x23, _gtk_groups
Lgtk_translate_group:
    cbz x23, Lgtk_translate_done
    ldr x24, [x23, #GG_NODE]
Lgtk_translate_group_ancestor:
    cmp x24, x19
    b.eq Lgtk_translate_this_group
    cbz x24, Lgtk_translate_group_next
    LOAD x9, _gtk_nodes
    add x9, x9, x24, lsl #8
    ldr x24, [x9, #GN_PARENT]
    b Lgtk_translate_group_ancestor
Lgtk_translate_this_group:
    ldp x10, x11, [x23, #GG_X]
    add x10, x10, x20
    add x11, x11, x21
    stp x10, x11, [x23, #GG_X]
Lgtk_translate_group_next:
    ldr x23, [x23, #GG_NEXT]
    b Lgtk_translate_group
Lgtk_translate_done:
    LEAVE
