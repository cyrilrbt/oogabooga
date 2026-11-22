// Shared scene paint order and grouped opacity; Cairo only rasterizes commands.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_engine_commands
_gtk_engine_commands:
    ENTER
    LOAD x19, _gtk_doc
    ldr x0, [x19, #24]
    lsl x0, x0, #1
    bl _engine_display_new
    STORE x0, _gtk_display
    mov x20, #0
Lgtk_command_node:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lgtk_command_groups
    mov x0, x20
    bl _gtk_node_visible
    cbz x0, Lgtk_command_advance
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x9, [x9]
    cmp x9, #NODE_TEXT
    b.eq Lgtk_command_advance
    LOAD x10, _gtk_doc
    ldr x10, [x10, #72]
    add x10, x10, x20, lsl #11
    ldr x10, [x10, #88]
    cmp x10, #2
    b.ne Lgtk_command_inline_ready
    LOAD x10, _gtk_nodes
    add x10, x10, x20, lsl #8
    ldr x11, [x10, #GN_WIDGET]
    ldr x12, [x10, #GN_IMAGE]
    orr x11, x11, x12
    cbz x11, Lgtk_command_advance
Lgtk_command_inline_ready:
    LOAD x0, _gtk_display
    bl _engine_display_append
    cbz x0, Lgtk_command_done
    mov x9, #1
    str x9, [x0]
    str x20, [x0, #8]
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
    stp d0, d1, [x0, #16]
    stp d2, d3, [x0, #32]
Lgtk_command_advance:
    add x20, x20, #1
    b Lgtk_command_node
Lgtk_command_groups:
    LOAD x20, _gtk_groups
Lgtk_command_group:
    cbz x20, Lgtk_command_order
    LOAD x0, _gtk_display
    bl _engine_display_append
    cbz x0, Lgtk_command_done
    mov x9, #2
    str x9, [x0]
    ldr x9, [x20, #GG_NODE]
    str x9, [x0, #8]
    str x20, [x0, #120]
    ldr x9, [x20, #GG_X]
    scvtf d0, x9
    ldr x9, [x20, #GG_Y]
    scvtf d1, x9
    ldr x9, [x20, #GG_W]
    scvtf d2, x9
    ldr x9, [x20, #GG_H]
    scvtf d3, x9
    stp d0, d1, [x0, #16]
    stp d2, d3, [x0, #32]
    ldr x20, [x20, #GG_NEXT]
    b Lgtk_command_group
Lgtk_command_order:
    LOAD x0, _gtk_scene
    LOAD x1, _gtk_display
    bl _engine_scene_order
Lgtk_command_done:
    LEAVE
.globl _gtk_engine_paint
_gtk_engine_paint:
    ENTER
    sub sp, sp, #768
    mov x19, x0
    mov x1, #0xffffff
    bl _gtk_paint_color
    mov x0, x19
    bl _cairo_paint
    LOAD x20, _gtk_scene
    LOAD x21, _gtk_display
    cbz x20, Lgtk_replay_done
    cbz x21, Lgtk_replay_done
    mov x22, #0
    str xzr, [sp, #512]
    mov x9, #-1
    str x9, [sp, #520]
Lgtk_replay_next:
    ldr x9, [x20, #24]
    cmp x22, x9
    b.hs Lgtk_replay_finish
    ldr x9, [x20, #16]
    ldr x9, [x9, x22, lsl #3]
    ldr x10, [x21, #16]
    add x23, x10, x9, lsl #7
    ldr x9, [x23, #8]
    ldr x10, [x20, #8]
    add x24, x10, x9, lsl #9
    ldr x25, [x24, #SC_RANK]
    ldr x9, [sp, #520]
    cmp x25, x9
    b.eq Lgtk_replay_command
Lgtk_replay_close:
    ldr x9, [sp, #512]
    cbz x9, Lgtk_replay_enter
    sub x9, x9, #1
    ldr x10, [sp, x9, lsl #3]
    ldr x11, [x20, #8]
    add x26, x11, x10, lsl #9
    ldr x10, [x26, #SC_END_RANK]
    cmp x10, x25
    b.hs Lgtk_replay_enter
    str x9, [sp, #512]
    mov x0, x19
    mov x1, x26
    bl gtk_replay_pop
    b Lgtk_replay_close
Lgtk_replay_enter:
    str x25, [sp, #520]
    ldr x9, [x24, #SC_FLAGS]
    tbz x9, #0, Lgtk_replay_command
    ldr x9, [sp, #512]
    cmp x9, #64
    b.hs Lgtk_replay_command
    ldr x10, [x23, #8]
    str x10, [sp, x9, lsl #3]
    add x9, x9, #1
    str x9, [sp, #512]
    ldr x9, [x24, #SC_OPACITY]
    cmp x9, #1000
    b.hs Lgtk_replay_command
    mov x0, x19
    bl _cairo_push_group
Lgtk_replay_command:
    mov x0, x20
    ldr x1, [x23, #8]
    add x2, sp, #544
    ldr x9, [x23]
    cmp x9, #1
    cset x3, eq
    ldp d0, d1, [x23, #16]
    ldp d2, d3, [x23, #32]
    bl _engine_scene_rect
    cbz x0, Lgtk_replay_advance
    mov x0, x19
    bl _cairo_save
    mov x0, x19
    ldp d0, d1, [sp, #544]
    ldp d2, d3, [sp, #560]
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_clip
    mov x0, x19
    ldp d0, d1, [x24, #SC_TX]
    bl _cairo_translate
    ldr x9, [x23]
    cmp x9, #1
    b.ne Lgtk_replay_text
    mov x0, x19
    ldr x1, [x23, #8]
    bl _gtk_paint_node
    b Lgtk_replay_restore
Lgtk_replay_text:
    mov x0, x19
    ldr x1, [x23, #120]
    bl _gtk_inline_paint
    mov x0, x19
    ldr x1, [x23, #120]
    bl _gtk_selection_paint
    mov x0, x19
    mov x1, #0
    bl _gtk_paint_color
    mov x0, x19
    ldp d0, d1, [x23, #16]
    bl _cairo_move_to
    ldr x9, [x23, #120]
    ldr x1, [x9, #GG_LAYOUT]
    mov x0, x19
    bl _pango_cairo_show_layout
Lgtk_replay_restore:
    mov x0, x19
    bl _cairo_restore
Lgtk_replay_advance:
    add x22, x22, #1
    b Lgtk_replay_next
Lgtk_replay_finish:
    ldr x9, [sp, #512]
    cbz x9, Lgtk_replay_done
    sub x9, x9, #1
    str x9, [sp, #512]
    ldr x10, [sp, x9, lsl #3]
    ldr x11, [x20, #8]
    add x1, x11, x10, lsl #9
    mov x0, x19
    bl gtk_replay_pop
    b Lgtk_replay_finish
Lgtk_replay_done:
    add sp, sp, #768
    LEAVE
// cairo,scene record -> close one opacity group.
gtk_replay_pop:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x9, [x20, #SC_OPACITY]
    cmp x9, #1000
    b.hs Lgtk_pop_done
    bl _cairo_pop_group_to_source
    mov x0, x19
    ldr x9, [x20, #SC_OPACITY]
    scvtf d0, x9
    mov x9, #1000
    scvtf d1, x9
    fdiv d0, d0, d1
    bl _cairo_paint_with_alpha
Lgtk_pop_done:
    LEAVE
