// Fit an independent block beside preceding floats using their measured GTK
// bounds. Match the core's 128-float context limit and reuse the shared fitter.
.include "src/gtk/gtk.inc"
.text
// node,x,y,available -> used x/y in x0/x1. Caller retains its normal-flow cursor.
.globl _gtk_block_avoid
_gtk_block_avoid:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _gtk_engine_node
    mov x23, x0
    ldr x9, [x23, #FLOW_OWNER]
    cbnz x9, Lgtk_avoid_plain
    ldr x9, [x23, #(1840+(CSS_POSITION-48)*8)]
    cmp x9, #2
    b.hs Lgtk_avoid_plain
    ldr x1, [x2]
    bl _engine_formatting_context
    cbz x0, Lgtk_avoid_plain
    ldr x24, [x23, #FLOAT_CONTEXT]
    cbz x24, Lgtk_avoid_plain
    LOAD x9, _gtk_doc
    ldr x9, [x9, #72]
    sub x10, x24, #1
    add x9, x9, x10, lsl #11
    ldr x25, [x9, #FLOAT_FIRST]
    cbz x25, Lgtk_avoid_plain
    ldr x28, [x23, #768]
    ldr x9, [x23, #776]
    add x28, x28, x9
    ldr x9, [x23, #784]
    add x28, x28, x9
    ldr x9, [x23, #808]
    add x28, x28, x9
    ldr x9, [x23, #816]
    add x28, x28, x9
    ldr x9, [x23, #BOX_BORDER_LEFT]
    add x28, x28, x9
    ldr x9, [x23, #BOX_BORDER_RIGHT]
    add x28, x28, x9
    mov x9, #16400
    sub sp, sp, x9
    mov x0, x19
    bl _gtk_engine_node
    ldr x9, [x2, #16]
    str x9, [sp, #16392]
    mov x26, #0
    add x27, sp, #8
Lgtk_avoid_float:
    cbz x25, Lgtk_avoid_fit
    cmp x25, x19
    b.hs Lgtk_avoid_fit
    cmp x26, #128
    b.hs Lgtk_avoid_fit
    mov x0, x25
    bl _gtk_engine_node
    ldr x25, [x0, #FLOAT_NEXT]
    ldr x9, [x0, #FLOAT_CONTEXT]
    cmp x9, x24
    b.ne Lgtk_avoid_float
    ldr x9, [x1, #GN_W]
    cbz x9, Lgtk_avoid_float
    ldr x10, [x1, #GN_H]
    cbz x10, Lgtk_avoid_float
    ldp x11, x12, [x2, #16]
    stp x11, x12, [x27]
    ldr x11, [x1, #GN_X]
    ldr x12, [x0, #776]
    sub x11, x11, x12
    add x9, x9, x12
    ldr x12, [x0, #784]
    add x9, x9, x12
    ldr x12, [x1, #GN_Y]
    ldr x13, [x0, #792]
    sub x12, x12, x13
    add x10, x10, x13
    ldr x13, [x0, #800]
    add x10, x10, x13
    scvtf d0, x11
    scvtf d1, x12
    scvtf d2, x9
    scvtf d3, x10
    stp d0, d1, [x27, #16]
    stp d2, d3, [x27, #32]
    mov x9, #1
    str x9, [x27, #48]
    ldr x9, [x0, #(32+CSS_FLOAT*8)]
    str x9, [x27, #56]
    str x24, [x27, #120]
    add x26, x26, #1
    add x27, x27, #128
    b Lgtk_avoid_float
Lgtk_avoid_fit:
    str x26, [sp]
    mov x0, sp
    mov x1, x24
    ldr x2, [sp, #16392]
    mov x3, #0
    scvtf d0, x20
    scvtf d1, x21
    scvtf d2, x22
    scvtf d3, x28
    bl _engine_float_avoid
    // GTK inputs and float bounds are integral pixel coordinates.
    fcvtzs x20, d0
    fcvtzs x21, d1
    mov x9, #16400
    add sp, sp, x9
Lgtk_avoid_plain:
    mov x0, x20
    mov x1, x21
    LEAVE
