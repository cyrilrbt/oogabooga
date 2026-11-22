// Retained inline shaping. All indices and source maps are UTF-8 byte offsets.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_group_new
_gtk_group_new:
    ENTER
    mov x19, x0
    mov x0, #1
    mov x1, #GG_SIZE
    bl _calloc
    mov x20, x0
    str x19, [x20, #GG_NODE]
    mov x0, #0
    bl _g_string_new
    str x0, [x20, #GG_TEXT]
    bl _pango_attr_list_new
    str x0, [x20, #GG_ATTRS]
    LOAD x0, _gtk_pango_context
    bl _pango_layout_new
    str x0, [x20, #GG_LAYOUT]
    LOAD x9, _gtk_groups_tail
    cbz x9, Lgroup_first
    str x20, [x9, #GG_NEXT]
    b Lgroup_linked
Lgroup_first:
    STORE x20, _gtk_groups
Lgroup_linked:
    STORE x20, _gtk_groups_tail
    mov x0, x20
    LEAVE

// group,node: append text or recursively flatten inline descendants.
.globl _gtk_group_append
_gtk_group_append:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x20
    bl _gtk_engine_node
    mov x21, x0
    mov x22, x1
    mov x23, x2
    ldr x9, [x21, #88]
    cmp x9, #1
    b.eq Lgroup_append_done
    ldr x9, [x23]
    cmp x9, #NODE_TEXT
    b.eq Lgroup_append_text
    cmp x9, #NODE_BR
    b.eq Lgroup_append_break
    ldr x9, [x22, #GN_WIDGET]
    cbnz x9, Lgroup_append_object
    ldr x9, [x23]
    cmp x9, #NODE_IMG
    b.eq Lgroup_append_object
    cmp x9, #NODE_SVG
    b.eq Lgroup_append_object
    ldr x9, [x21, #88]
    cmp x9, #5
    b.ne Lgroup_append_container
    mov x0, x20
    mov x1, #0
    mov x2, #0
    ldr x9, [x19, #GG_NODE]
    LOAD x10, _gtk_nodes
    add x9, x10, x9, lsl #8
    ldr x3, [x9, #GN_CW]
    bl _gtk_layout_node
    b Lgroup_append_object
Lgroup_append_container:
    ldr x24, [x22, #GN_FIRST]
Lgroup_append_children:
    cbz x24, Lgroup_append_done
    mov x0, x19
    mov x1, x24
    bl _gtk_group_append
    LOAD x9, _gtk_nodes
    add x9, x9, x24, lsl #8
    ldr x24, [x9, #GN_NEXT]
    b Lgroup_append_children
Lgroup_append_text:
    ldr x0, [x23, #16]
    bl _gtk_engine_byte
    mov x24, x0
    ldr x0, [x23, #24]
    bl _gtk_engine_byte
    sub x25, x0, x24
    cbz x25, Lgroup_append_done
    LOAD x9, _gtk_flow
    ldr x9, [x9]
    add x1, x9, x24
    ldr x10, [x21, #888]
    cmp x10, #1 // pre
    b.eq Lgroup_text_ready
    cmp x10, #3 // pre-wrap
    b.eq Lgroup_text_ready
    cmp x10, #5 // break-spaces
    b.eq Lgroup_text_ready
Lgroup_trim_leading:
    cbz x25, Lgroup_append_done
    ldrb w10, [x1]
    cmp x10, #10
    b.ne Lgroup_trim_trailing
    add x1, x1, #1
    add x24, x24, #1
    sub x25, x25, #1
    b Lgroup_trim_leading
Lgroup_trim_trailing:
    cbz x25, Lgroup_append_done
    sub x10, x25, #1
    ldrb w10, [x1, x10]
    cmp x10, #10
    b.ne Lgroup_text_ready
    sub x25, x25, #1
    b Lgroup_trim_trailing
Lgroup_text_ready:
    mov x0, x19
    mov x2, x25
    mov x3, x24
    bl gtk_group_bytes
    b Lgroup_append_style
Lgroup_append_break:
    mov x0, x19
    ADDR x1, gtk_group_lf
    mov x2, #1
    mov x3, #0
    bl gtk_group_bytes
    b Lgroup_append_done
Lgroup_append_object:
    mov x0, #1
    mov x1, #GA_SIZE
    bl _calloc
    mov x24, x0
    str x20, [x24, #GA_NODE]
    ldr x9, [x19, #GG_LENGTH]
    str x9, [x24, #GA_BYTE]
    ldr x9, [x19, #GG_ANCHORS]
    str x9, [x24, #GA_NEXT]
    str x24, [x19, #GG_ANCHORS]
    ldr x25, [x22, #GN_W]
    ldr x26, [x22, #GN_H]
    str x25, [x24, #GA_W]
    str x26, [x24, #GA_H]
    ldr x9, [x22, #GN_BASELINE]
    cmp x9, #0
    csel x9, x26, x9, le
    str x9, [x24, #40]
    mov x0, x21
    bl _gtk_inline_rise
    str x0, [x24, #48]
    ldr x0, [x23, #16]
    bl _gtk_engine_byte
    mov x3, x0
    mov x0, x19
    ADDR x1, gtk_group_object
    mov x2, #3
    bl gtk_group_bytes
    // Pango shape rectangle: baseline at bottom, fixed CSS box dimensions.
    str wzr, [sp, #144]
    ldr x9, [x24, #40]
    ldr x10, [x21, #792]
    add x9, x9, x10
    neg x9, x9
    lsl x9, x9, #10
    str w9, [sp, #148]
    ldr x9, [x21, #776]
    str x9, [x24, #56]
    ldr x10, [x21, #784]
    add x9, x9, x10
    add x9, x25, x9
    lsl x9, x9, #10
    str w9, [sp, #152]
    ldr x9, [x21, #792]
    ldr x10, [x21, #800]
    add x9, x9, x10
    add x9, x26, x9
    lsl x9, x9, #10
    str w9, [sp, #156]
    add x0, sp, #144
    mov x1, x0
    bl _pango_attr_shape_new
    ldr x9, [x24, #GA_BYTE]
    str w9, [x0, #8]
    add x9, x9, #3
    str w9, [x0, #12]
    mov x1, x0
    ldr x0, [x19, #GG_ATTRS]
    bl _pango_attr_list_insert
Lgroup_append_style:
    ldr x0, [x19, #GG_ATTRS]
    mov x1, x21
    ldr x3, [x19, #GG_LENGTH]
    sub x2, x3, x25
    // Objects have three UTF-8 bytes, regardless of their pixel width.
    ldr x9, [x23]
    cmp x9, #NODE_TEXT
    b.eq Lgroup_style_ready
    sub x2, x3, #3
Lgroup_style_ready:
    cmp x9, #NODE_TEXT
    b.ne Lgroup_style_attributes
    str x2, [x22, #GN_TEXT_START]
    sub x10, x3, x2
    str x10, [x22, #GN_TEXT_LEN]
    str x19, [x22, #GN_PANGO]
Lgroup_style_attributes:
    ldr x4, [x19, #GG_TEXT]
    ldr x4, [x4]
    bl _gtk_engine_attributes
Lgroup_append_done:
    LEAVE

// group,bytes,length,global byte. Geometric growth bounds mapping storage.
gtk_group_bytes:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x19, #GG_LENGTH]
    add x24, x23, x21
    add x25, x24, #1
    ldr x9, [x19, #104]
    cmp x25, x9
    b.ls Lgroup_capacity_ready
    mov x9, #64
Lgroup_capacity_grow:
    cmp x9, x25
    b.hs Lgroup_capacity_allocate
    lsl x9, x9, #1
    b Lgroup_capacity_grow
Lgroup_capacity_allocate:
    str x9, [x19, #104]
    lsl x1, x9, #3
    ldr x0, [x19, #GG_MAP]
    bl _realloc
    str x0, [x19, #GG_MAP]
Lgroup_capacity_ready:
    ldr x9, [x19, #GG_MAP]
    mov x10, #0
Lgroup_map_fill:
    cmp x10, x21
    b.hi Lgroup_map_done
    add x11, x23, x10
    add x12, x22, x10
    str x12, [x9, x11, lsl #3]
    add x10, x10, #1
    b Lgroup_map_fill
Lgroup_map_done:
    ldr x0, [x19, #GG_TEXT]
    mov x1, x20
    mov x2, x21
    bl _g_string_append_len
    str x24, [x19, #GG_LENGTH]
    LEAVE

// group,x,y,width -> height. Resolve each inline object's actual native frame.
.globl _gtk_group_finish
_gtk_group_finish:
    ENTER
    mov x19, x0
    str x1, [x19, #GG_X]
    str x2, [x19, #GG_Y]
    str x3, [x19, #GG_W]
    mov x20, x3
    ldr x21, [x19, #GG_LAYOUT]
    ldr x9, [x19, #GG_TEXT]
    ldr x1, [x9]
    ldr x2, [x19, #GG_LENGTH]
    mov x0, x21
    bl _pango_layout_set_text
    mov x0, x21
    ldr x1, [x19, #GG_ATTRS]
    bl _pango_layout_set_attributes
    mov x0, x21
    lsl x1, x20, #10
    bl _pango_layout_set_width
    mov x0, x21
    mov x1, #2
    bl _pango_layout_set_wrap
    ldr x0, [x19, #GG_NODE]
    bl _gtk_engine_node
    mov x22, x0
    ldr x9, [x22, #80]
    mov x1, #0
    cmp x9, #1
    mov x10, #2
    csel x1, x10, x1, eq
    cmp x9, #2
    mov x10, #1
    csel x1, x10, x1, eq
    mov x0, x21
    bl _pango_layout_set_alignment
    ldr x9, [x22, #888]
    cmp x9, #2
    b.ne Lgroup_wrap_ready
    mov x0, x21
    mov x1, #-1
    bl _pango_layout_set_width
Lgroup_wrap_ready:
    mov x0, x21
    add x1, sp, #144
    add x2, sp, #148
    bl _pango_layout_get_pixel_size
    ldr w9, [sp, #148]
    str x9, [x19, #GG_H]
    mov x0, x21
    bl _pango_layout_get_baseline
    asr x0, x0, #10
    str x0, [x19, #GG_BASELINE]
    ldr x1, [x19, #GG_LENGTH]
    mov x0, x21
    bl _gtk_line_baseline
    asr x9, x0, #10
    ldr x10, [x19, #GG_Y]
    add x9, x9, x10
    ldr x0, [x19, #GG_NODE]
    LOAD x10, _gtk_nodes
    add x10, x10, x0, lsl #8
    ldr x11, [x10, #GN_Y]
    sub x9, x9, x11
    str x9, [x10, #GN_BASELINE]
    ldr x22, [x19, #GG_ANCHORS]
Lgroup_place_anchor:
    cbz x22, Lgroup_finish_done
    mov x0, x21
    ldr x1, [x22, #GA_BYTE]
    add x2, sp, #144
    bl _pango_layout_index_to_pos
    mov x0, x21
    ldr x1, [x22, #GA_BYTE]
    bl _gtk_line_baseline
    str x0, [sp, #184]
    ldr x0, [x22, #GA_NODE]
    bl _gtk_engine_node
    ldr w9, [sp, #144]
    lsl x9, x9, #32
    asr x9, x9, #32
    asr x9, x9, #10
    ldr x10, [x19, #GG_X]
    add x9, x9, x10
    ldr x10, [x22, #56]
    add x9, x9, x10
    str x9, [sp, #168]
    ldr x9, [sp, #184]
    ldr x10, [x22, #48]
    sub x9, x9, x10
    asr x9, x9, #10
    ldr x10, [x19, #GG_Y]
    add x9, x9, x10
    ldr x10, [x22, #40]
    sub x9, x9, x10
    str x9, [sp, #176]
    ldr x10, [x0, #88]
    cmp x10, #5
    b.ne Lgroup_place_replaced
    ldr x0, [x22, #GA_NODE]
    ldr x2, [x1, #GN_Y]
    sub x2, x9, x2
    ldr x9, [sp, #168]
    ldr x10, [x1, #GN_X]
    sub x1, x9, x10
    bl _gtk_translate_subtree
    b Lgroup_anchor_next
Lgroup_place_replaced:
    ldr x9, [sp, #168]
    str x9, [x1, #GN_X]
    ldr x9, [sp, #176]
    str x9, [x1, #GN_Y]
Lgroup_anchor_next:
    ldr x22, [x22, #GA_NEXT]
    b Lgroup_place_anchor
Lgroup_finish_done:
    ldr x0, [x19, #GG_H]
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_group_lf: .asciz "\n"
gtk_group_object: .asciz "\357\277\274"
