// Bounded flex line construction and factor distribution, independent of AppKit.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,index -> eligible direct flex item (resource/whitespace/hidden nodes skip).
flow_item:
    ldr x2, [x0, #72]
    add x2, x2, x1, lsl #11
    ldr x3, [x2, #88]
    cmp x3, #1
    b.eq Lflow_item_no
    ldr x3, [x0, #16]
    mov x4, #40
    madd x3, x1, x4, x3
    ldr x4, [x3]
    cmp x4, #NODE_LINK
    b.eq Lflow_item_no
    cmp x4, #NODE_SHEET
    b.eq Lflow_item_no
    cmp x4, #NODE_TEXT
    b.ne Lflow_item_yes
    ldr x4, [x3, #16]
    ldr x5, [x3, #24]
    ldr x6, [x0]
Lflow_item_text:
    cmp x4, x5
    b.hs Lflow_item_no
    ldrb w7, [x6, x4]
    cmp w7, #32
    b.hi Lflow_item_yes
    add x4, x4, #1
    b Lflow_item_text
Lflow_item_yes:
    mov x0, #1
    ret
Lflow_item_no:
    mov x0, #0
    ret

// Populate content width/height and the main-axis outer base for one item.
flex_base:
    ENTER
    mov x19, x0                     // metadata
    mov x20, x1                     // direction
    ldr x21, [x19, #FLOW_INTRINSIC_W]
    ldr x22, [x19, #FLOW_INTRINSIC_H]
    mov x9, #20
    cmp x21, #1
    csel x21, x9, x21, lt
    cmp x22, #1
    csel x22, x9, x22, lt
    ldr x0, [x19, #144]
    tbnz x0, #63, Lflex_base_height
    ldr x21, [x19, #768]
Lflex_base_height:
    ldr x0, [x19, #152]
    tbnz x0, #63, Lflex_base_basis
    ldr x1, [x19, #848]
    bl _engine_box_length
    mov x22, x0
Lflex_base_basis:
    ldr x0, [x19, #(32+CSS_BASIS*8)]
    tbnz x0, #63, Lflex_base_store
    ldr x1, [x19, #848]
    bl _engine_box_length
    tbz x20, #0, Lflex_basis_width
    mov x22, x0
    b Lflex_base_store
Lflex_basis_width:
    mov x21, x0
Lflex_base_store:
    str x21, [x19, #FLOW_WIDTH]
    str x22, [x19, #FLOW_HEIGHT]
    tbz x20, #0, Lflex_base_horizontal
    ldr x9, [x19, #792]
    ldr x10, [x19, #800]
    ldr x11, [x19, #824]
    ldr x12, [x19, #832]
    mov x21, x22
    b Lflex_base_extras
Lflex_base_horizontal:
    ldr x9, [x19, #776]
    ldr x10, [x19, #784]
    ldr x11, [x19, #808]
    ldr x12, [x19, #816]
Lflex_base_extras:
    add x21, x21, x9
    add x21, x21, x10
    add x21, x21, x11
    add x21, x21, x12
    add x9, x19, #BOX_BORDER_LEFT
    tbz x20, #0, Lflex_base_border_axis
    add x9, x19, #BOX_BORDER_TOP
Lflex_base_border_axis:
    ldr x10, [x9]
    add x21, x21, x10
    ldr x10, [x9, #16]
    add x21, x21, x10
    str x21, [x19, #FLOW_BASE]
    LEAVE

// doc, item array, first, end, owner-meta, available, gap, direction.
flex_line:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x25, x6
    mov x26, x7
    mov x27, #0
    mov x28, #0
    str xzr, [sp]
    mov x9, x21
Lflex_line_sum:
    cmp x9, x22
    b.hs Lflex_line_space
    ldr x10, [x20, x9, lsl #3]
    ldr x11, [x19, #72]
    add x11, x11, x10, lsl #11
    ldr x12, [x11, #FLOW_BASE]
    add x27, x27, x12
    ldr x13, [x11, #(32+CSS_GROW*8)]
    add x28, x28, x13
    ldr x13, [x11, #(32+CSS_SHRINK*8)]
    mul x13, x13, x12
    ldr x14, [sp]
    add x14, x14, x13
    str x14, [sp]
    add x9, x9, #1
    b Lflex_line_sum
Lflex_line_space:
    sub x9, x22, x21
    str x9, [sp, #8]
    sub x9, x9, #1
    mul x9, x9, x25
    sub x27, x24, x27
    sub x27, x27, x9               // signed free space
    mov x9, x27
    cmp x27, #0
    b.le Lflex_line_position_free
    cbz x28, Lflex_line_position_free
    mov x9, #0
Lflex_line_position_free:
    cmp x9, #0
    csel x9, xzr, x9, lt
    str x9, [sp, #16]
    mov x9, x21
    str x9, [sp, #24]
Lflex_line_item:
    ldr x9, [sp, #24]
    cmp x9, x22
    b.hs Lflex_line_done
    ldr x10, [x20, x9, lsl #3]
    ldr x11, [x19, #72]
    add x11, x11, x10, lsl #11
    str x11, [sp, #32]
    ldr x12, [x11, #FLOW_BASE]
    cmp x27, #0
    b.lt Lflex_line_shrink
    cbz x28, Lflex_line_allocated
    ldr x13, [x11, #(32+CSS_GROW*8)]
    mul x13, x13, x27
    udiv x13, x13, x28
    add x12, x12, x13
    b Lflex_line_allocated
Lflex_line_shrink:
    ldr x13, [sp]
    cbz x13, Lflex_line_allocated
    ldr x14, [x11, #(32+CSS_SHRINK*8)]
    mul x14, x14, x12
    neg x15, x27
    mul x14, x14, x15
    udiv x14, x14, x13
    sub x12, x12, x14
Lflex_line_allocated:
    ldr x13, [x11, #FLOW_BASE]
    sub x13, x12, x13
    tbz x26, #0, Lflex_line_width
    ldr x14, [x11, #FLOW_HEIGHT]
    add x14, x14, x13
    mov x15, #1
    cmp x14, x15
    csel x14, x15, x14, lt
    str x14, [x11, #FLOW_HEIGHT]
    ldr x14, [x23, #768]
    ldr x15, [x11, #776]
    sub x14, x14, x15
    ldr x15, [x11, #784]
    sub x14, x14, x15
    ldr x15, [x11, #808]
    sub x14, x14, x15
    ldr x15, [x11, #816]
    sub x14, x14, x15
    ldr x15, [x11, #BOX_BORDER_LEFT]
    sub x14, x14, x15
    ldr x15, [x11, #BOX_BORDER_RIGHT]
    sub x14, x14, x15
    ldr x15, [x23, #(32+CSS_ALIGN_ITEMS*8)]
    ldr x16, [x11, #(32+CSS_ALIGN_SELF*8)]
    tbnz x16, #63, Lflex_column_align
    mov x15, x16
Lflex_column_align:
    cbz x15, Lflex_column_stretch
    ldr x16, [x11, #FLOW_WIDTH]
    cmp x16, x14
    csel x16, x14, x16, gt
    sub x17, x14, x16
    cmp x15, #2
    b.ne Lflex_column_end
    lsr x17, x17, #1
    str x17, [x11, #FLOW_LEAD]
    sub x17, x14, x16
    ldr x15, [x11, #FLOW_LEAD]
    sub x17, x17, x15
    b Lflex_column_trail
Lflex_column_end:
    cmp x15, #3
    b.ne Lflex_column_trail
    str x17, [x11, #FLOW_LEAD]
    mov x17, #0
Lflex_column_trail:
    str x17, [x11, #FLOW_TRAIL]
    mov x14, x16
Lflex_column_stretch:
    str x14, [x11, #FLOW_WIDTH]
    b Lflex_line_justify
Lflex_line_width:
    ldr x14, [x11, #FLOW_WIDTH]
    add x14, x14, x13
    mov x15, #1
    cmp x14, x15
    csel x14, x15, x14, lt
    str x14, [x11, #FLOW_WIDTH]
Lflex_line_justify:
    sub x9, x9, x21
    str x9, [sp, #40]
    ldr x10, [sp, #8]
    str x10, [x11, #FLOW_COLUMNS]
    mov x12, #0                     // leading extra
    mov x13, x25                    // gap after item
    add x14, x9, #1
    cmp x14, x10
    csel x13, xzr, x13, eq
    ldr x14, [sp, #16]
    ldr x15, [x23, #(32+CSS_JUSTIFY*8)]
    cbz x14, Lflex_line_place
    cmp x15, #1
    b.eq Lflex_justify_end
    cmp x15, #2
    b.eq Lflex_justify_center
    cmp x15, #3
    b.eq Lflex_justify_between
    cmp x15, #4
    b.eq Lflex_justify_around
    cmp x15, #5
    b.eq Lflex_justify_evenly
    b Lflex_line_place
Lflex_justify_end:
    cbnz x9, Lflex_line_place
    mov x12, x14
    b Lflex_line_place
Lflex_justify_center:
    cbnz x9, Lflex_line_place
    lsr x12, x14, #1
    b Lflex_line_place
Lflex_justify_between:
    cmp x10, #1
    b.ls Lflex_line_place
    sub x15, x10, #1
    add x16, x9, #1
    cmp x16, x10
    b.eq Lflex_line_place
    udiv x14, x14, x15
    add x13, x13, x14
    b Lflex_line_place
Lflex_justify_around:
    udiv x14, x14, x10
    cbnz x9, Lflex_around_trail
    lsr x12, x14, #1
Lflex_around_trail:
    add x13, x13, x14
    b Lflex_line_place
Lflex_justify_evenly:
    add x15, x10, #1
    udiv x14, x14, x15
    cbnz x9, Lflex_even_trail
    mov x12, x14
Lflex_even_trail:
    add x13, x13, x14
Lflex_line_place:
    tbz x26, #0, Lflex_line_place_row
    str x12, [x11, #FLOW_BEFORE]
    str x13, [x11, #FLOW_AFTER]
    str xzr, [x11, #FLOW_COLUMN]
    str x9, [x11, #FLOW_ROW]
    mov x10, #1
    str x10, [x11, #FLOW_COLUMNS]
    b Lflex_line_item_next
Lflex_line_place_row:
    str x12, [x11, #FLOW_LEAD]
    str x13, [x11, #FLOW_TRAIL]
    tbz x26, #1, Lflex_line_column
    ldr x10, [sp, #8]
    sub x10, x10, #1
    sub x9, x10, x9
Lflex_line_column:
    str x9, [x11, #FLOW_COLUMN]
Lflex_line_item_next:
    ldr x9, [sp, #24]
    add x9, x9, #1
    str x9, [sp, #24]
    b Lflex_line_item
Lflex_line_done:
    add sp, sp, #128
    LEAVE

.globl _engine_flex_owner
_engine_flex_owner:
    ENTER
    sub sp, sp, #2304              // at most 256 direct items
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    add x21, x21, x20, lsl #11
    ldr x26, [x21, #(32+CSS_DIRECTION*8)]
    ldr x27, [x21, #768]
    mov x22, #0
    add x23, x20, #1
Lflex_collect:
    ldr x9, [x19, #24]
    cmp x23, x9
    b.hs Lflex_collected
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x23, x10, x9
    ldr x10, [x9, #8]
    cmp x10, x20
    b.ne Lflex_collect_next
    cmp x22, #256
    b.hs Lflex_collected
    mov x0, x19
    mov x1, x23
    bl flow_item
    cbz x0, Lflex_collect_next
    str x23, [sp, x22, lsl #3]
    ldr x24, [x19, #72]
    add x24, x24, x23, lsl #11
    add x9, x20, #1
    str x9, [x24, #FLOW_OWNER]
    mov x9, #1
    str x9, [x24, #FLOW_COLSPAN]
    str x9, [x24, #FLOW_ROWSPAN]
    mov x0, x24
    mov x1, x26
    bl flex_base
    add x22, x22, #1
Lflex_collect_next:
    add x23, x23, #1
    b Lflex_collect
Lflex_collected:
    cbz x22, Lflex_owner_done
    str x22, [sp, #2048]
    ldr x0, [x21, #(32+CSS_GAP*8)]
    tbz x26, #0, Lflex_row_gap
    ldr x9, [x21, #(32+CSS_ROW_GAP*8)]
    b Lflex_gap_resolve
Lflex_row_gap:
    ldr x9, [x21, #(32+CSS_COLUMN_GAP*8)]
Lflex_gap_resolve:
    tbnz x9, #63, Lflex_gap_default
    mov x0, x9
Lflex_gap_default:
    mov x1, x27
    bl _engine_box_length
    mov x28, x0
    tbz x26, #0, Lflex_rows
    ldr x0, [x21, #152]
    tbnz x0, #63, Lflex_column_auto
    mov x1, x27
    bl _engine_box_length
    mov x27, x0
    b Lflex_column_line
Lflex_column_auto:
    sub x9, x22, #1
    mul x27, x9, x28
    mov x9, #0
Lflex_column_sum:
    cmp x9, x22
    b.hs Lflex_column_line
    ldr x10, [sp, x9, lsl #3]
    ldr x11, [x19, #72]
    add x11, x11, x10, lsl #11
    ldr x10, [x11, #FLOW_BASE]
    add x27, x27, x10
    add x9, x9, #1
    b Lflex_column_sum
Lflex_column_line:
    mov x0, x19
    mov x1, sp
    mov x2, #0
    mov x3, x22
    mov x4, x21
    mov x5, x27
    mov x6, x28
    mov x7, x26
    bl flex_line
    b Lflex_owner_done
Lflex_rows:
    mov x23, #0                     // item index
    mov x24, #0                     // current row start
    mov x25, #0                     // current row used width
    str xzr, [sp, #2056]           // row index
Lflex_row_next:
    cmp x23, x22
    b.hs Lflex_last_line
    ldr x9, [sp, x23, lsl #3]
    ldr x10, [x19, #72]
    add x10, x10, x9, lsl #11
    ldr x11, [x10, #FLOW_BASE]
    add x12, x25, x28
    add x12, x12, x11
    cmp x23, x24
    b.eq Lflex_row_accept_first
    ldr x13, [x21, #(32+CSS_WRAP*8)]
    cbz x13, Lflex_row_accept
    cmp x12, x27
    b.le Lflex_row_accept
    mov x0, x19
    mov x1, sp
    mov x2, x24
    mov x3, x23
    mov x4, x21
    mov x5, x27
    mov x6, x28
    mov x7, x26
    bl flex_line
    ldr x9, [sp, #2056]
    add x9, x9, #1
    str x9, [sp, #2056]
    mov x24, x23
    mov x25, #0
    b Lflex_row_next
Lflex_row_accept_first:
    mov x12, x11
Lflex_row_accept:
    mov x25, x12
    ldr x9, [sp, #2056]
    str x9, [x10, #FLOW_ROW]
    add x23, x23, #1
    b Lflex_row_next
Lflex_last_line:
    mov x0, x19
    mov x1, sp
    mov x2, x24
    mov x3, x22
    mov x4, x21
    mov x5, x27
    mov x6, x28
    mov x7, x26
    bl flex_line
    ldr x9, [sp, #2056]
    str x9, [x21, #FLOW_ROW]
    str x9, [sp, #2064]
    ldr x0, [x21, #(32+CSS_ROW_GAP*8)]
    tbnz x0, #63, Lflex_wrap_default_gap
    b Lflex_wrap_resolve_gap
Lflex_wrap_default_gap:
    ldr x0, [x21, #(32+CSS_GAP*8)]
Lflex_wrap_resolve_gap:
    mov x1, x27
    bl _engine_box_length
    mov x23, #0
Lflex_wrap_gap_next:
    cmp x23, x22
    b.hs Lflex_owner_done
    ldr x9, [sp, x23, lsl #3]
    ldr x10, [x19, #72]
    add x10, x10, x9, lsl #11
    ldr x9, [x10, #FLOW_ROW]
    ldr x11, [sp, #2064]
    cmp x9, x11
    b.hs Lflex_wrap_gap_advance
    str x0, [x10, #FLOW_AFTER]
Lflex_wrap_gap_advance:
    add x23, x23, #1
    b Lflex_wrap_gap_next
Lflex_owner_done:
    add sp, sp, #2304
    LEAVE
