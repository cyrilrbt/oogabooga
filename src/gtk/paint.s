// Cairo is a raster backend; shared assembly owns geometry and scene ordering.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_engine_scene
_gtk_engine_scene:
    ENTER
    LOAD x0, _gtk_doc
    LOAD x1, _gtk_width
    LOAD x2, _gtk_viewport_height
    cbnz x2, Lgtk_scene_height
    mov x2, #768
Lgtk_scene_height:
    bl _engine_scene_new
    STORE x0, _gtk_scene
    mov x19, x0
    cbz x19, Lgtk_scene_done
    mov x20, #0
    LOAD x21, _gtk_doc
Lgtk_scene_boxes:
    ldr x9, [x21, #24]
    cmp x20, x9
    b.hs Lgtk_scene_update
    mov x0, x20
    bl _gtk_node_visible
    cbz x0, Lgtk_scene_box_next
    ldr x9, [x21, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x9, [x9]
    cmp x9, #NODE_TEXT
    b.ne Lgtk_scene_native_box
    mov x0, x20
    bl _gtk_scene_text_box
Lgtk_scene_native_box:
    LOAD x9, _gtk_nodes
    add x9, x9, x20, lsl #8
    ldr x10, [x9, #GN_X]
    scvtf d0, x10
    ldr x10, [x9, #GN_Y]
    scvtf d1, x10
    ldr x10, [x9, #GN_W]
    scvtf d2, x10
    ldr x10, [x9, #GN_H]
    scvtf d3, x10
    mov x0, x19
    mov x1, x20
    bl _engine_scene_set_box
Lgtk_scene_box_next:
    add x20, x20, #1
    b Lgtk_scene_boxes
Lgtk_scene_update:
    mov x0, x19
    LOAD x1, _gtk_previous_scene
    bl _engine_scene_copy_scroll
    LOAD x0, _gtk_previous_scene
    cbz x0, Lgtk_scene_old_freed
    bl _engine_scene_free
Lgtk_scene_old_freed:
    STORE xzr, _gtk_previous_scene
    mov x0, x19
    bl _engine_scene_extents
    bl _gtk_scene_view_origin
    mov x0, x19
    bl _engine_scene_update
Lgtk_scene_done:
    LEAVE

// cairo,color (engine RGBA encoding) -> source
.globl _gtk_paint_color
_gtk_paint_color:
    ubfx x9, x1, #16, #8
    scvtf d0, x9
    ubfx x9, x1, #8, #8
    scvtf d1, x9
    and x9, x1, #255
    scvtf d2, x9
    mov x9, #255
    scvtf d4, x9
    fdiv d0, d0, d4
    fdiv d1, d1, d4
    fdiv d2, d2, d4
    fmov d3, #1.0
    tbz x1, #40, Lgtk_color_ready
    ubfx x9, x1, #32, #8
    scvtf d3, x9
    fdiv d3, d3, d4
Lgtk_color_ready:
    b _cairo_set_source_rgba

// cairo,node -> background, borders and replaced image in source coordinates.
.globl _gtk_paint_node
_gtk_paint_node:
    ENTER
    mov x19, x0
    mov x21, x1
    mov x0, x21
    bl _gtk_engine_node
    mov x22, x0
    mov x23, x1
    ldr x9, [x22, #88]
    cmp x9, #1
    b.eq Lgtk_node_hidden
    mov x0, x19
    bl _cairo_save
    mov x0, x22
    ldr x1, [x23, #GN_W]
    ldr x0, [x0, #224]
    bl _engine_box_length
    cbz x0, Lgtk_node_clip_ready
    scvtf d4, x0
    fmov d5, d4
    ldr x9, [x23, #GN_X]
    scvtf d0, x9
    ldr x9, [x23, #GN_Y]
    scvtf d1, x9
    ldr x9, [x23, #GN_W]
    scvtf d2, x9
    ldr x9, [x23, #GN_H]
    scvtf d3, x9
    mov x0, x19
    bl _gtk_cairo_rounded_rect
    mov x0, x19
    bl _cairo_clip
Lgtk_node_clip_ready:
    mov x0, x19
    mov x1, x23
    mov x2, x22
    bl _gtk_control_background
    ldr x1, [x22, #40]
    tbnz x1, #63, Lgtk_paint_background_image
    mov x0, x19
    bl _gtk_paint_color
    mov x0, x19
    mov x1, x23
    bl gtk_paint_rectangle
    mov x0, x19
    bl _cairo_fill
Lgtk_paint_background_image:
    mov x0, x21
    mov x1, x19
    bl _gtk_background_node
Lgtk_paint_border:
    mov x0, x19
    mov x1, x23
    mov x2, x22
    bl _gtk_control_border
    ldr x24, [x22, #BOX_BORDER_TOP]
    ldr x9, [x22, #BOX_BORDER_LEFT]
    orr x24, x24, x9
    ldr x9, [x22, #BOX_BORDER_RIGHT]
    orr x24, x24, x9
    ldr x9, [x22, #BOX_BORDER_BOTTOM]
    orr x24, x24, x9
    cbz x24, Lgtk_paint_image
    mov x0, x19
    ldr x1, [x22, #200]
    bl _gtk_paint_color
    mov x24, #0
Lgtk_paint_border_side:
    add x9, x22, #BOX_BORDER_LEFT
    ldr x3, [x9, x24, lsl #3]
    cbz x3, Lgtk_paint_border_side_next
    mov x0, x19
    mov x1, x23
    mov x2, x24
    bl gtk_paint_side
Lgtk_paint_border_side_next:
    add x24, x24, #1
    cmp x24, #4
    b.lo Lgtk_paint_border_side
Lgtk_paint_image:
    ldr x24, [x23, #GN_IMAGE]
    cbz x24, Lgtk_node_done
    mov x0, x19
    bl _cairo_save
    ldr x9, [x23, #GN_X]
    scvtf d0, x9
    ldr x9, [x23, #GN_Y]
    scvtf d1, x9
    mov x0, x19
    bl _cairo_translate
    mov x0, x24
    bl _gdk_pixbuf_get_width
    scvtf d4, x0
    str d4, [sp, #144]
    mov x0, x24
    bl _gdk_pixbuf_get_height
    scvtf d1, x0
    ldr x9, [x23, #GN_H]
    scvtf d0, x9
    fdiv d1, d0, d1
    ldr x9, [x23, #GN_W]
    scvtf d0, x9
    ldr d4, [sp, #144]
    fdiv d0, d0, d4
    mov x0, x19
    bl _cairo_scale
    mov x0, x19
    mov x1, x24
    fmov d0, #0.0
    fmov d1, #0.0
    bl _gdk_cairo_set_source_pixbuf
    mov x0, x19
    bl _cairo_paint
    mov x0, x19
    bl _cairo_restore
Lgtk_node_done:
    mov x0, x19
    bl _cairo_restore
Lgtk_node_hidden:
    LEAVE
// cairo,native node -> path rectangle
 gtk_paint_rectangle:
    ldr x9, [x1, #GN_X]
    scvtf d0, x9
    ldr x9, [x1, #GN_Y]
    scvtf d1, x9
    ldr x9, [x1, #GN_W]
    scvtf d2, x9
    ldr x9, [x1, #GN_H]
    scvtf d3, x9
    b _cairo_rectangle

.text
// cairo,node,side,width: fill each border inside the box, without stroke offsets.
gtk_paint_side:
    ENTER
    mov x19, x0
    ldr x9, [x1, #GN_X]
    ldr x10, [x1, #GN_Y]
    ldr x11, [x1, #GN_W]
    ldr x12, [x1, #GN_H]
    cmp x2, #0
    b.eq Lgtk_side_left
    cmp x2, #1
    b.eq Lgtk_side_top
    cmp x2, #2
    b.eq Lgtk_side_right
    add x10, x10, x12
    sub x10, x10, x3
    mov x12, x3
    b Lgtk_side_draw
Lgtk_side_right:
    add x9, x9, x11
    sub x9, x9, x3
Lgtk_side_left:
    mov x11, x3
    b Lgtk_side_draw
Lgtk_side_top:
    mov x12, x3
Lgtk_side_draw:
    scvtf d0, x9
    scvtf d1, x10
    scvtf d2, x11
    scvtf d3, x12
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_fill
    LEAVE

.globl _gtk_background_node
_gtk_background_node:
    ENTER
    sub sp, sp, #64
    mov x19, x1
    str x0, [sp, #8]
    bl _gtk_engine_node
    mov x9, #99
    str x9, [sp]
    ldr x9, [x1, #GN_X]
    scvtf d0, x9
    ldr x9, [x1, #GN_Y]
    scvtf d1, x9
    ldr x9, [x1, #GN_W]
    scvtf d2, x9
    ldr x9, [x1, #GN_H]
    scvtf d3, x9
    stp d0, d1, [sp, #16]
    stp d2, d3, [sp, #32]
    mov x0, sp
    mov x1, x19
    bl _mac_background_paint
    add sp, sp, #64
    LEAVE

// Actual shaped leaf boxes supply scroll extents; they are not paint commands.
.globl _gtk_scene_text_box
_gtk_scene_text_box:
    ENTER
    bl _gtk_engine_node
    mov x19, x1
    ldr x20, [x19, #GN_PANGO]
    cbz x20, Lgtk_text_box_done
    ldr x0, [x20, #GG_LAYOUT]
    ldr x1, [x19, #GN_TEXT_START]
    add x2, sp, #144
    bl _pango_layout_index_to_pos
    ldr x0, [x20, #GG_LAYOUT]
    ldr x1, [x19, #GN_TEXT_START]
    ldr x9, [x19, #GN_TEXT_LEN]
    cbz x9, Lgtk_text_box_done
    add x1, x1, x9
    sub x1, x1, #1
    add x2, sp, #160
    bl _pango_layout_index_to_pos
    ldr w9, [sp, #144]
    asr x9, x9, #10
    ldr x10, [x20, #GG_X]
    add x9, x9, x10
    str x9, [x19, #GN_X]
    ldr w9, [sp, #148]
    asr x9, x9, #10
    ldr x10, [x20, #GG_Y]
    add x9, x9, x10
    str x9, [x19, #GN_Y]
    ldr w9, [sp, #160]
    ldr w10, [sp, #168]
    add x9, x9, x10
    ldr w10, [sp, #144]
    sub x9, x9, x10
    asr x9, x9, #10
    str x9, [x19, #GN_W]
    ldr w9, [sp, #164]
    ldr w10, [sp, #172]
    add x9, x9, x10
    ldr w10, [sp, #148]
    sub x9, x9, x10
    asr x9, x9, #10
    str x9, [x19, #GN_H]
    ldr w9, [sp, #148]
    ldr w10, [sp, #164]
    cmp x9, x10
    b.eq Lgtk_text_box_done
    ldr x9, [x20, #GG_X]
    str x9, [x19, #GN_X]
    ldr x9, [x20, #GG_W]
    str x9, [x19, #GN_W]
Lgtk_text_box_done:
    LEAVE
