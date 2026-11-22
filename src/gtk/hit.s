// Painting, hit occlusion and interaction consume the same shared scene order.
.include "src/gtk/gtk.inc"
.text
// x,y -> topmost retained command or NULL.
.globl _gtk_engine_hit
_gtk_engine_hit:
    scvtf d0, x0
    scvtf d1, x1
    LOAD x0, _gtk_scene
    LOAD x1, _gtk_display
    b _engine_scene_hit
// x,y -> source UTF8 byte, group pointer, exact glyph hit BOOL.
.globl _gtk_engine_text_at
_gtk_engine_text_at:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _gtk_engine_hit
    cbz x0, Lgtk_text_no_hit
    ldr x9, [x0]
    cmp x9, #2
    b.ne Lgtk_text_no_hit
    ldr x21, [x0, #120]
    ldr x9, [x0, #8]
    LOAD x10, _gtk_scene
    ldr x10, [x10, #8]
    add x10, x10, x9, lsl #9
    ldp d0, d1, [x10, #SC_TX]
    scvtf d2, x19
    scvtf d3, x20
    fsub d2, d2, d0
    fsub d3, d3, d1
    fcvtzs x19, d2
    fcvtzs x20, d3
    ldr x9, [x21, #GG_X]
    sub x1, x19, x9
    lsl x1, x1, #10
    ldr x9, [x21, #GG_Y]
    sub x2, x20, x9
    lsl x2, x2, #10
    ldr x0, [x21, #GG_LAYOUT]
    add x3, sp, #144
    add x4, sp, #148
    bl _pango_layout_xy_to_index
    mov x22, x0
    ldr w23, [sp, #144]
    ldr w1, [sp, #148]
    ldr x9, [x21, #GG_TEXT]
    ldr x24, [x9]
    add x0, x24, x23
    bl _g_utf8_offset_to_pointer
    sub x9, x0, x24
    ldr x10, [x21, #GG_LENGTH]
    cmp x9, x10
    csel x9, x10, x9, hi
    ldr x10, [x21, #GG_MAP]
    ldr x0, [x10, x9, lsl #3]
    mov x1, x21
    mov x2, x22
    LEAVE
Lgtk_text_no_hit:
    mov x0, #0
    mov x1, #0
    mov x2, #0
    LEAVE
// x,y -> borrowed href. Padding on styled anchors is clickable too.
.globl _gtk_engine_link_at
_gtk_engine_link_at:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _gtk_engine_hit
    cbz x0, Lgtk_link_none
    ldr x9, [x0]
    cmp x9, #1
    b.ne Lgtk_link_text
    ldr x24, [x0, #8]
    LOAD x23, _gtk_doc
    b Lgtk_link_ancestor
Lgtk_link_text:
    mov x0, x19
    mov x1, x20
    bl _gtk_engine_text_at
    cbz x1, Lgtk_link_none
    cbz x2, Lgtk_link_none
    mov x22, x0
    LOAD x23, _gtk_doc
    ldr x24, [x23, #24]
Lgtk_link_node:
    cbz x24, Lgtk_link_none
    sub x24, x24, #1
    mov x0, x24
    bl _gtk_engine_node
    mov x25, x2
    ldr x9, [x25]
    cmp x9, #NODE_TEXT
    b.ne Lgtk_link_node
    ldr x0, [x25, #16]
    bl _gtk_engine_byte
    cmp x22, x0
    b.lt Lgtk_link_node
    ldr x0, [x25, #24]
    bl _gtk_engine_byte
    cmp x22, x0
    b.hs Lgtk_link_node
Lgtk_link_ancestor:
    cbz x24, Lgtk_link_none
    ldr x25, [x23, #16]
    mov x9, #40
    madd x25, x24, x9, x25
    ldr x9, [x25]
    cmp x9, #NODE_A
    b.eq Lgtk_link_found
    ldr x24, [x25, #8]
    b Lgtk_link_ancestor
Lgtk_link_found:
    ldr x0, [x25, #32]
    LEAVE
Lgtk_link_none:
    mov x0, #0
    LEAVE
