// Native widgets and paint commands share ancestor display/hidden visibility.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_node_visible
_gtk_node_visible:
    LOAD x9, _gtk_doc
    ldr x10, [x9, #72]
    ldr x11, [x9, #16]
    mov x12, #64
Lgtk_visibility_parent:
    cbz x12, Lgtk_visibility_no
    sub x12, x12, #1
    add x13, x10, x0, lsl #11
    ldr x14, [x13, #88]
    cmp x14, #1
    b.eq Lgtk_visibility_no
    ldr x14, [x13, #696]
    cbnz x14, Lgtk_visibility_no
    cbz x0, Lgtk_visibility_yes
    mov x13, #40
    madd x13, x0, x13, x11
    ldr x0, [x13, #8]
    b Lgtk_visibility_parent
Lgtk_visibility_yes:
    mov x0, #1
    ret
Lgtk_visibility_no:
    mov x0, #0
    ret
