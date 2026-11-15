// Row-major Grid auto-placement, bounded to 16 columns, 64 rows, 256 items.
// Tracks, spans, gaps and intrinsic minimums are calculated in ARM64.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// descriptor, available, gap, widths[16] -> count.
.globl _engine_grid_tracks
_engine_grid_tracks:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ubfx x23, x19, #56, #4
    add x23, x23, #1
    mov x24, #0
    mov x25, #0
    mov x26, #0
Lgrid_track:
    cmp x24, x23
    b.hs Lgrid_track_fraction
    mov x9, #0
    tbnz x19, #60, Lgrid_track_code
    mov x9, #14
    mul x9, x24, x9
Lgrid_track_code:
    lsr x27, x19, x9
    and x27, x27, #0x3fff
    cbnz x19, Lgrid_track_unit
    mov x27, #0x1001
Lgrid_track_unit:
    lsr x9, x27, #12
    and x28, x27, #0xfff
    cmp x9, #1
    b.eq Lgrid_track_weight
    cmp x9, #3
    b.eq Lgrid_track_auto
    cmp x9, #2
    b.ne Lgrid_track_fixed
    mul x28, x28, x20
    add x28, x28, #500
    mov x10, #1000
    udiv x28, x28, x10
Lgrid_track_fixed:
    str x28, [x22, x24, lsl #3]
    add x25, x25, x28
    b Lgrid_track_next
Lgrid_track_auto:
    mov x28, #1
Lgrid_track_weight:
    add x26, x26, x28
    neg x9, x28
    str x9, [x22, x24, lsl #3]
Lgrid_track_next:
    add x24, x24, #1
    b Lgrid_track
Lgrid_track_fraction:
    sub x9, x23, #1
    mul x9, x9, x21
    sub x20, x20, x9
    subs x20, x20, x25
    csel x20, xzr, x20, lt
    mov x24, #0
Lgrid_track_distribute:
    cmp x24, x23
    b.hs Lgrid_tracks_done
    ldr x9, [x22, x24, lsl #3]
    tbz x9, #63, Lgrid_track_distribute_next
    neg x9, x9
    mul x9, x9, x20
    cbz x26, Lgrid_track_zero
    udiv x9, x9, x26
Lgrid_track_zero:
    mov x10, #1
    cmp x9, #1
    csel x9, x10, x9, lt
    str x9, [x22, x24, lsl #3]
Lgrid_track_distribute_next:
    add x24, x24, #1
    b Lgrid_track_distribute
Lgrid_tracks_done:
    mov x0, x23
    LEAVE

.globl _engine_grid_owner
_engine_grid_owner:
    ENTER
    sub sp, sp, #4096
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    add x21, x21, x20, lsl #11
    mov x0, sp
    mov x1, #0
    mov x2, #4096
    bl _memset
    ldr x24, [x21, #(32+CSS_GAP*8)]
    ldr x9, [x21, #(32+CSS_COLUMN_GAP*8)]
    cmp x9, #0
    csel x24, x24, x9, lt
    str x24, [sp, #3840]
    ldr x25, [x21, #(32+CSS_GAP*8)]
    ldr x9, [x21, #(32+CSS_ROW_GAP*8)]
    cmp x9, #0
    csel x25, x25, x9, lt
    str x25, [sp, #3848]
    ldr x0, [x21, #(1840+(CSS_GRID_COLUMNS-48)*8)]
    ldr x1, [x21, #768]
    mov x2, x24
    add x3, sp, #2560
    bl _engine_grid_tracks
    mov x22, x0                    // columns
    mov x23, #0                    // item count
    mov x24, #0                    // rows
    add x25, x20, #1
Lgrid_item:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Lgrid_size_rows
    cmp x23, #256
    b.hs Lgrid_size_rows
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x25, x10, x9
    ldr x9, [x9, #8]
    cmp x9, x20
    b.lo Lgrid_size_rows
    b.ne Lgrid_next_item
    mov x0, x19
    mov x1, x25
    bl _engine_flow_item
    cbz x0, Lgrid_next_item
    ldr x9, [x19, #72]
    add x26, x9, x25, lsl #11
    ldr x9, [x26, #(1840+(CSS_GRID_COLUMN-48)*8)]
    ldr x10, [x26, #(1840+(CSS_GRID_ROW-48)*8)]
    ldr x27, [x26, #(1840+(CSS_GRID_COLSPAN-48)*8)]
    ldr x28, [x26, #(1840+(CSS_GRID_ROWSPAN-48)*8)]
    mov x11, #1
    cmp x27, #1
    csel x27, x11, x27, lt
    cmp x27, x22
    csel x27, x22, x27, hi
    cmp x28, #1
    csel x28, x11, x28, lt
    mov x11, #64
    cmp x28, x11
    csel x28, x11, x28, hi
    sub x9, x9, #1
    sub x10, x10, #1
    cmp x9, #0
    csel x9, xzr, x9, lt
    cmp x10, #0
    csel x10, xzr, x10, lt
Lgrid_find_slot:
    add x11, x9, x27
    cmp x11, x22
    b.ls Lgrid_slot_rows
    mov x9, #0
    add x10, x10, #1
Lgrid_slot_rows:
    add x11, x10, x28
    cmp x11, #64
    b.hi Lgrid_next_item
    mov x12, #1
    lsl x12, x12, x27
    sub x12, x12, #1
    lsl x12, x12, x9
    mov x13, x10
    add x14, sp, #2048
Lgrid_slot_test:
    cmp x13, x11
    b.hs Lgrid_slot_found
    ldr x15, [x14, x13, lsl #3]
    tst x15, x12
    b.ne Lgrid_slot_collision
    add x13, x13, #1
    b Lgrid_slot_test
Lgrid_slot_collision:
    ldr x13, [x26, #(1840+(CSS_GRID_COLUMN-48)*8)]
    cbz x13, Lgrid_slot_next_column
    add x10, x10, #1
    b Lgrid_find_slot
Lgrid_slot_next_column:
    add x9, x9, #1
    b Lgrid_find_slot
Lgrid_slot_found:
    mov x13, x10
Lgrid_slot_mark:
    cmp x13, x11
    b.hs Lgrid_slot_store
    ldr x15, [x14, x13, lsl #3]
    orr x15, x15, x12
    str x15, [x14, x13, lsl #3]
    add x13, x13, #1
    b Lgrid_slot_mark
Lgrid_slot_store:
    str x9, [x26, #FLOW_COLUMN]
    str x10, [x26, #FLOW_ROW]
    str x27, [x26, #FLOW_COLSPAN]
    str x28, [x26, #FLOW_ROWSPAN]
    str x22, [x26, #FLOW_COLUMNS]
    add x12, x20, #1
    str x12, [x26, #FLOW_OWNER]
    str x25, [sp, x23, lsl #3]
    add x23, x23, #1
    cmp x24, x11
    csel x24, x11, x24, lo
    // Initial row minima come from non-spanning items.
    cmp x28, #1
    b.ne Lgrid_next_item
    str x10, [sp, #3856]
    mov x0, x26
    bl grid_item_height
    ldr x10, [sp, #3856]
    add x9, sp, #2688
    ldr x11, [x9, x10, lsl #3]
    cmp x11, x0
    csel x11, x0, x11, lt
    str x11, [x9, x10, lsl #3]
Lgrid_next_item:
    add x25, x25, #1
    b Lgrid_item
Lgrid_size_rows:
    mov x25, #0
Lgrid_auto_row:
    cmp x25, x24
    b.hs Lgrid_row_template
    add x9, sp, #2688
    ldr x10, [x9, x25, lsl #3]
    ldr x11, [x21, #(1840+(CSS_GRID_AUTO_ROWS-48)*8)]
    cmp x10, x11
    csel x10, x11, x10, lt
    mov x11, #1
    cmp x10, #1
    csel x10, x11, x10, lt
    str x10, [x9, x25, lsl #3]
    add x25, x25, #1
    b Lgrid_auto_row
Lgrid_row_template:
    ldr x0, [x21, #(1840+(CSS_GRID_ROWS-48)*8)]
    cbz x0, Lgrid_span_rows
    str x0, [sp, #3864]
    ldr x1, [x21, #152]
    tbz x1, #63, Lgrid_explicit_height
    mov x1, #0
    mov x9, #0
    add x10, sp, #2688
Lgrid_natural_height:
    cmp x9, x24
    b.hs Lgrid_explicit_height
    ldr x11, [x10, x9, lsl #3]
    add x1, x1, x11
    add x9, x9, #1
    b Lgrid_natural_height
Lgrid_explicit_height:
    ldr x2, [sp, #3848]
    add x3, sp, #3200
    bl _engine_grid_tracks
    cmp x0, x24
    csel x25, x24, x0, lo
    mov x9, #0
    add x10, sp, #2688
    add x11, sp, #3200
Lgrid_copy_rows:
    cmp x9, x25
    b.hs Lgrid_span_rows
    ldr x12, [x11, x9, lsl #3]
    ldr x13, [x10, x9, lsl #3]
    cmp x13, x12
    csel x12, x13, x12, gt
    str x12, [x10, x9, lsl #3]
    add x9, x9, #1
    b Lgrid_copy_rows
Lgrid_span_rows:
    mov x25, #0
Lgrid_span_item:
    cmp x25, x23
    b.hs Lgrid_assign
    ldr x9, [sp, x25, lsl #3]
    ldr x10, [x19, #72]
    add x26, x10, x9, lsl #11
    ldr x27, [x26, #FLOW_ROW]
    ldr x28, [x26, #FLOW_ROWSPAN]
    cmp x28, #1
    b.eq Lgrid_span_next
    mov x0, x26
    bl grid_item_height
    mov x9, #0
    mov x10, #0
    add x11, sp, #2688
Lgrid_span_sum:
    cmp x9, x28
    b.hs Lgrid_span_deficit
    add x12, x27, x9
    ldr x13, [x11, x12, lsl #3]
    add x10, x10, x13
    add x9, x9, #1
    b Lgrid_span_sum
Lgrid_span_deficit:
    sub x9, x28, #1
    ldr x12, [sp, #3848]
    madd x10, x9, x12, x10
    subs x0, x0, x10
    b.le Lgrid_span_next
    add x0, x0, x28
    sub x0, x0, #1
    udiv x0, x0, x28
    mov x9, #0
Lgrid_span_grow:
    cmp x9, x28
    b.hs Lgrid_span_next
    add x12, x27, x9
    ldr x13, [x11, x12, lsl #3]
    add x13, x13, x0
    str x13, [x11, x12, lsl #3]
    add x9, x9, #1
    b Lgrid_span_grow
Lgrid_span_next:
    add x25, x25, #1
    b Lgrid_span_item
Lgrid_assign:
    mov x25, #0
Lgrid_assign_item:
    cmp x25, x23
    b.hs Lgrid_done
    ldr x9, [sp, x25, lsl #3]
    ldr x10, [x19, #72]
    add x26, x10, x9, lsl #11
    ldr x9, [x26, #FLOW_COLUMN]
    ldr x10, [x26, #FLOW_COLSPAN]
    add x11, sp, #2560
    mov x12, #0
    mov x13, #0
Lgrid_cell_width:
    cmp x12, x10
    b.hs Lgrid_width_ready
    add x14, x9, x12
    ldr x14, [x11, x14, lsl #3]
    add x13, x13, x14
    add x12, x12, #1
    b Lgrid_cell_width
Lgrid_width_ready:
    sub x10, x10, #1
    ldr x11, [sp, #3840]
    madd x13, x10, x11, x13
    ldr x14, [x26, #808]
    sub x13, x13, x14
    ldr x14, [x26, #816]
    sub x13, x13, x14
    ldr x14, [x26, #BOX_BORDER_LEFT]
    sub x13, x13, x14
    ldr x14, [x26, #BOX_BORDER_RIGHT]
    sub x13, x13, x14
    ldr x14, [x26, #776]
    sub x13, x13, x14
    ldr x14, [x26, #784]
    sub x13, x13, x14
    mov x14, #1
    cmp x13, #1
    csel x13, x14, x13, lt
    str x13, [x26, #FLOW_WIDTH]
    ldr x10, [x26, #FLOW_COLSPAN]
    add x9, x9, x10
    cmp x9, x22
    csel x11, xzr, x11, eq
    str x11, [x26, #FLOW_TRAIL]
    ldr x9, [x26, #FLOW_ROW]
    ldr x10, [x26, #FLOW_ROWSPAN]
    add x11, sp, #2688
    mov x12, #0
    mov x13, #0
Lgrid_cell_height:
    cmp x12, x10
    b.hs Lgrid_height_ready
    add x14, x9, x12
    ldr x14, [x11, x14, lsl #3]
    add x13, x13, x14
    add x12, x12, #1
    b Lgrid_cell_height
Lgrid_height_ready:
    sub x12, x10, #1
    ldr x11, [sp, #3848]
    madd x13, x12, x11, x13
    ldr x14, [x26, #824]
    sub x13, x13, x14
    ldr x14, [x26, #832]
    sub x13, x13, x14
    ldr x14, [x26, #BOX_BORDER_TOP]
    sub x13, x13, x14
    ldr x14, [x26, #BOX_BORDER_BOTTOM]
    sub x13, x13, x14
    ldr x14, [x26, #792]
    sub x13, x13, x14
    ldr x14, [x26, #800]
    sub x13, x13, x14
    mov x14, #1
    cmp x13, #1
    csel x13, x14, x13, lt
    str x13, [x26, #FLOW_HEIGHT]
    add x9, x9, x10
    cmp x9, x24
    csel x11, xzr, x11, eq
    str x11, [x26, #FLOW_AFTER]
    add x25, x25, #1
    b Lgrid_assign_item
Lgrid_done:
    add sp, sp, #4096
    LEAVE

grid_item_height:
    ldr x1, [x0, #152]
    tbnz x1, #63, Lgrid_intrinsic_height
    b Lgrid_height_extras
Lgrid_intrinsic_height:
    ldr x1, [x0, #FLOW_INTRINSIC_H]
Lgrid_height_extras:
    ldr x2, [x0, #792]
    add x1, x1, x2
    ldr x2, [x0, #800]
    add x1, x1, x2
    ldr x2, [x0, #824]
    add x1, x1, x2
    ldr x2, [x0, #832]
    add x1, x1, x2
    ldr x2, [x0, #BOX_BORDER_TOP]
    add x1, x1, x2
    ldr x2, [x0, #BOX_BORDER_BOTTOM]
    add x0, x1, x2
    ret
