// Native text supplies row minima; shared assembly supplies track allocation,
// sparse placement and spans. Prefix offsets preserve holes and spanning cells.
.include "src/gtk/gtk.inc"
.text
// node,content x,y,width,is_table -> content height.
.globl _gtk_layout_tracks
_gtk_layout_tracks:
    ENTER
    sub sp, sp, #4096
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x0, sp
    mov x1, #0
    mov x2, #4096
    bl _memset
    str x23, [sp, #4000]
    mov x0, x19
    bl _gtk_engine_node
    mov x24, x0
    cbnz x23, Lgtk_tracks_table
    LOAD x0, _gtk_doc
    mov x1, x19
    add x2, sp, #1024
    bl _engine_grid_geometry
    ldr x9, [sp, #1024]
    str x9, [sp, #3968]
    ldr x9, [sp, #1032]
    str x9, [sp, #3976]
    add x0, sp, #512
    add x1, sp, #1040
    mov x2, #128
    bl _memcpy
    add x0, sp, #1152
    add x1, sp, #1168
    mov x2, #512
    bl _memmove
    // The grid result rows live at 1024+144; retain them at 1152 only after copy.
    ldr x9, [x24, #(32+CSS_GAP*8)]
    ldr x10, [x24, #(32+CSS_COLUMN_GAP*8)]
    cmp x10, #0
    csel x10, x9, x10, lt
    str x10, [sp, #3984]
    ldr x10, [x24, #(32+CSS_ROW_GAP*8)]
    cmp x10, #0
    csel x10, x9, x10, lt
    str x10, [sp, #3992]
    b Lgtk_tracks_collect
Lgtk_tracks_table:
    LOAD x0, _gtk_doc
    mov x1, x19
    add x2, sp, #512
    bl _engine_table_tracks
    str x0, [sp, #3968]
Lgtk_tracks_collect:
    LOAD x25, _gtk_doc
    mov x26, #1
    mov x27, #0
Lgtk_tracks_item:
    ldr x9, [x25, #24]
    cmp x26, x9
    b.hs Lgtk_tracks_measure
    cmp x27, #256
    b.hs Lgtk_tracks_measure
    mov x0, x26
    bl _gtk_engine_node
    ldr x9, [x0, #FLOW_OWNER]
    add x10, x19, #1
    cmp x9, x10
    b.ne Lgtk_tracks_item_next
    // Sorted/source-independent storage; 256 item indices fit after row arrays.
    add x9, sp, #1856
    str x26, [x9, x27, lsl #3]
    add x27, x27, #1
    ldr x9, [x0, #FLOW_ROW]
    ldr x10, [x0, #FLOW_ROWSPAN]
    add x9, x9, x10
    ldr x10, [sp, #3976]
    cmp x9, x10
    csel x9, x9, x10, gt
    str x9, [sp, #3976]
Lgtk_tracks_item_next:
    add x26, x26, #1
    b Lgtk_tracks_item
Lgtk_tracks_measure:
    str x27, [sp, #3952]
    mov x26, #0
Lgtk_tracks_measure_item:
    cmp x26, x27
    b.hs Lgtk_tracks_spans
    add x9, sp, #1856
    ldr x28, [x9, x26, lsl #3]
    mov x0, x28
    bl _gtk_engine_node
    mov x24, x0
    ldr x0, [x24, #FLOW_COLUMN]
    add x1, sp, #512
    ldr x2, [sp, #3984]
    bl gtk_track_prefix
    add x1, x20, x0
    ldr x9, [x24, #FLOW_LEAD]
    add x1, x1, x9
    str x1, [sp, #3936]
    ldr x0, [x24, #FLOW_ROW]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    add x2, x21, x0
    ldr x9, [x24, #FLOW_BEFORE]
    add x2, x2, x9
    ldr x1, [sp, #3936]
    mov x0, x28
    mov x3, x22
    bl _gtk_layout_node
    ldr x9, [x24, #FLOW_BEFORE]
    ldr x10, [x24, #FLOW_AFTER]
    add x9, x9, x10
    add x0, x0, x9
    str x0, [sp, #3928]
    LOAD x9, _gtk_nodes
    add x9, x9, x28, lsl #8
    str x0, [x9, #GN_ROW_HEIGHT]
    ldr x9, [x24, #FLOW_ROWSPAN]
    cmp x9, #1
    b.hi Lgtk_tracks_measure_next
    ldr x0, [x24, #FLOW_ROW]
    ldr x1, [x24, #FLOW_ROWSPAN]
    add x0, x0, x1
    str x0, [sp, #3920]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    mov x23, x0
    ldr x0, [x24, #FLOW_ROW]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    sub x23, x23, x0
    ldr x9, [sp, #3992]
    sub x23, x23, x9
    ldr x9, [sp, #3928]
    sub x9, x9, x23
    cmp x9, #0
    b.le Lgtk_tracks_measure_next
    ldr x10, [sp, #3920]
    sub x10, x10, #1
    cmp x10, #64
    b.hs Lgtk_tracks_measure_next
    add x11, sp, #1152
    ldr x12, [x11, x10, lsl #3]
    add x12, x12, x9
    str x12, [x11, x10, lsl #3]
Lgtk_tracks_measure_next:
    add x26, x26, #1
    b Lgtk_tracks_measure_item
Lgtk_tracks_spans:
    mov x26, #0
Lgtk_track_span_item:
    cmp x26, x27
    b.hs Lgtk_tracks_place
    add x9, sp, #1856
    ldr x28, [x9, x26, lsl #3]
    mov x0, x28
    bl _gtk_engine_node
    mov x24, x0
    mov x23, x1
    ldr x9, [x24, #FLOW_ROWSPAN]
    cmp x9, #1
    b.ls Lgtk_track_span_next
    ldr x0, [x24, #FLOW_ROW]
    add x0, x0, x9
    str x0, [sp, #3920]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    str x0, [sp, #3928]
    ldr x0, [x24, #FLOW_ROW]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    ldr x9, [sp, #3928]
    sub x9, x9, x0
    ldr x10, [sp, #3992]
    sub x9, x9, x10
    ldr x10, [x23, #GN_ROW_HEIGHT]
    sub x10, x10, x9
    cmp x10, #0
    b.le Lgtk_track_span_next
    ldr x9, [sp, #3920]
    sub x9, x9, #1
    cmp x9, #64
    b.hs Lgtk_track_span_next
    add x11, sp, #1152
    ldr x12, [x11, x9, lsl #3]
    add x12, x12, x10
    str x12, [x11, x9, lsl #3]
Lgtk_track_span_next:
    add x26, x26, #1
    b Lgtk_track_span_item
Lgtk_tracks_place:
    mov x26, #0
Lgtk_tracks_place_item:
    cmp x26, x27
    b.hs Lgtk_tracks_height
    add x9, sp, #1856
    ldr x28, [x9, x26, lsl #3]
    mov x0, x28
    bl _gtk_engine_node
    mov x24, x0
    mov x23, x1
    ldr x0, [x24, #FLOW_ROW]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    add x2, x21, x0
    ldr x9, [x24, #FLOW_BEFORE]
    add x2, x2, x9
    ldr x9, [x24, #792]
    add x2, x2, x9
    ldr x9, [x23, #GN_Y]
    sub x2, x2, x9
    mov x0, x28
    mov x1, #0
    bl _gtk_translate_subtree
    ldr x0, [x24, #FLOW_ROW]
    ldr x9, [x24, #FLOW_ROWSPAN]
    add x0, x0, x9
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    str x0, [sp, #3928]
    ldr x0, [x24, #FLOW_ROW]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    ldr x9, [sp, #3928]
    sub x9, x9, x0
    ldr x10, [sp, #3992]
    sub x9, x9, x10
    ldr x10, [x24, #FLOW_BEFORE]
    sub x9, x9, x10
    ldr x10, [x24, #FLOW_AFTER]
    sub x9, x9, x10
    ldr x10, [x24, #792]
    sub x9, x9, x10
    ldr x10, [x24, #800]
    sub x9, x9, x10
    ldr x10, [x23, #GN_H]
    subs x11, x9, x10
    b.le Lgtk_tracks_stretched
    str x9, [x23, #GN_H]
    ldr x9, [x23, #GN_CH]
    add x9, x9, x11
    str x9, [x23, #GN_CH]
Lgtk_tracks_stretched:
    add x26, x26, #1
    b Lgtk_tracks_place_item
Lgtk_tracks_height:
    ldr x0, [sp, #3976]
    add x1, sp, #1152
    ldr x2, [sp, #3992]
    bl gtk_track_prefix
    ldr x9, [sp, #3992]
    sub x0, x0, x9
    cmp x0, #0
    csel x0, xzr, x0, lt
    add sp, sp, #4096
    LEAVE
// count,track array,gap -> sum preceding tracks plus count gaps.
gtk_track_prefix:
    mov x9, #0
    mov x10, #0
    mov x11, #64
    cmp x0, x11
    csel x0, x11, x0, hi
Lgtk_track_sum:
    cmp x9, x0
    b.hs Lgtk_track_sum_done
    ldr x11, [x1, x9, lsl #3]
    add x10, x10, x11
    add x10, x10, x2
    add x9, x9, #1
    b Lgtk_track_sum
Lgtk_track_sum_done:
    mov x0, x10
    ret
