// Ordinary inline decorations follow native line fragments, not one union box.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_inline_paint
_gtk_inline_paint:
    ENTER
    mov x19, x0
    mov x20, x1
    LOAD x21, _gtk_doc
    LOAD x22, _gtk_nodes
    mov x23, #1
Lgtk_inline_node:
    ldr x9, [x21, #24]
    cmp x23, x9
    b.hs Lgtk_inline_done
    add x24, x22, x23, lsl #8
    ldr x9, [x24, #GN_PANGO]
    cmp x9, x20
    b.ne Lgtk_inline_next
    ldr x25, [x21, #72]
    add x25, x25, x23, lsl #11
    ldr x9, [x25, #88]
    cmp x9, #2
    b.ne Lgtk_inline_next
    ldr x9, [x21, #16]
    mov x10, #40
    madd x9, x23, x10, x9
    ldr x9, [x9]
    cmp x9, #NODE_TEXT
    b.eq Lgtk_inline_next
    mov x0, x19
    mov x1, x20
    mov x2, x24
    mov x3, x25
    bl gtk_inline_range
Lgtk_inline_next:
    add x23, x23, #1
    b Lgtk_inline_node
Lgtk_inline_done:
    LEAVE
gtk_inline_range:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x27, x3
    ldr x25, [x2, #GN_TEXT_START]
    ldr x26, [x2, #GN_TEXT_LEN]
    add x26, x26, x25
Lgtk_fragment_ranges:
    cmp x25, x26
    b.eq Lgtk_fragment_painted
    ldr x0, [x20, #GG_LAYOUT]
    bl _pango_layout_get_iter
    mov x21, x0
Lgtk_fragment_line:
    mov x0, x21
    mov x1, #0
    add x2, sp, #144
    bl _pango_layout_iter_get_line_extents
    mov x0, x21
    bl _pango_layout_iter_get_line_readonly
    ldr w9, [x0, #8]
    cmp x25, x9
    cset x10, hs
    str x10, [sp, #176]
    ldr w10, [x0, #12]
    add x9, x9, x10
    cmp x26, x9
    cset x10, ls
    str x10, [sp, #184]
    mov x1, x25
    mov x2, x26
    add x3, sp, #160
    add x4, sp, #168
    bl _pango_layout_line_get_x_ranges
    ldr x22, [sp, #160]
    ldr w23, [sp, #168]
    mov x24, #0
Lgtk_fragment_range:
    cmp x24, x23
    b.hs Lgtk_fragment_line_next
    add x9, x22, x24, lsl #3
    ldp w10, w11, [x9]
    scvtf d0, x10
    sub x11, x11, x10
    scvtf d2, x11
    ldr w9, [sp, #148]
    scvtf d1, x9
    ldr w9, [sp, #156]
    scvtf d3, x9
    mov x9, #1024
    scvtf d4, x9
    fdiv d0, d0, d4
    fdiv d1, d1, d4
    fdiv d2, d2, d4
    fdiv d3, d3, d4
    ldr x9, [x20, #GG_X]
    scvtf d4, x9
    fadd d0, d0, d4
    ldr x9, [x20, #GG_Y]
    scvtf d4, x9
    fadd d1, d1, d4
    mov x0, x19
    mov x1, x27
    ldr x2, [sp, #176]
    ldr x3, [sp, #184]
    bl gtk_inline_rect
    add x24, x24, #1
    b Lgtk_fragment_range
Lgtk_fragment_line_next:
    mov x0, x22
    bl _g_free
    mov x0, x21
    bl _pango_layout_iter_next_line
    cbnz x0, Lgtk_fragment_line
    mov x0, x21
    bl _pango_layout_iter_free
Lgtk_fragment_painted:
    LEAVE
// cairo,meta,first,last; rectangle in d0..d3.
gtk_inline_rect:
    ENTER
    sub sp, sp, #96
    stp d0, d1, [sp]
    stp d2, d3, [sp, #16]
    mov x19, x0
    mov x20, x1
    mov x0, x1
    mov x1, x2
    mov x2, x3
    add x3, sp, #32
    bl _engine_inline_edges
    ldr x1, [x20, #40]
    tbnz x1, #63, Lgtk_inline_border
    mov x0, x19
    bl _gtk_paint_color
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #16]
    mov x0, x19
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_fill
Lgtk_inline_border:
    ldr x1, [x20, #200]
    tbz x1, #63, Lgtk_inline_border_color
    ldr x1, [x20, #32]
Lgtk_inline_border_color:
    mov x0, x19
    bl _gtk_paint_color
    mov x21, #0
Lgtk_inline_edge:
    add x9, sp, #32
    ldr x9, [x9, x21, lsl #3]
    cbz x9, Lgtk_inline_edge_next
    scvtf d4, x9
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #16]
    cmp x21, #0
    b.eq Lgtk_inline_left
    cmp x21, #1
    b.eq Lgtk_inline_top
    cmp x21, #2
    b.eq Lgtk_inline_right
    fadd d1, d1, d3
    fsub d1, d1, d4
Lgtk_inline_top:
    fmov d3, d4
    b Lgtk_inline_fill
Lgtk_inline_right:
    fadd d0, d0, d2
    fsub d0, d0, d4
Lgtk_inline_left:
    fmov d2, d4
Lgtk_inline_fill:
    mov x0, x19
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_fill
Lgtk_inline_edge_next:
    add x21, x21, #1
    cmp x21, #4
    b.lo Lgtk_inline_edge
    add sp, sp, #96
    LEAVE
