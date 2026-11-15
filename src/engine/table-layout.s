.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,index -> nearest containing table index, or -1.
table_owner:
    ldr x2, [x0, #16]
Ltable_owner_next:
    mov x3, #40
    madd x3, x1, x3, x2
    ldr x4, [x3]
    cmp x4, #NODE_TABLE
    b.eq Ltable_owner_found
    ldr x1, [x3, #8]
    tbnz x1, #63, Ltable_owner_missing
    b Ltable_owner_next
Ltable_owner_found:
    mov x0, x1
    ret
Ltable_owner_missing:
    mov x0, #-1
    ret

.globl _engine_table_owner
_engine_table_owner:
    ENTER
    sub sp, sp, #1664              // 64 occupancy values and 64 column widths
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    add x21, x21, x20, lsl #11
    mov x0, sp
    mov x1, #0
    mov x2, #1536
    bl _memset
    mov x22, #-1                   // current row
    mov x23, #0                    // next column in this row
    mov x24, #0                    // number of columns
    add x25, x20, #1
Ltable_scan:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Ltable_columns
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x25, x10, x9
    ldr x26, [x9]
    cmp x26, #NODE_TR
    b.eq Ltable_check_owner
    cmp x26, #NODE_TD
    b.eq Ltable_check_owner
    cmp x26, #NODE_TH
    b.ne Ltable_scan_next
Ltable_check_owner:
    mov x0, x19
    mov x1, x25
    bl table_owner
    cmp x0, x20
    b.ne Ltable_scan_next
    ldr x27, [x19, #72]
    add x27, x27, x25, lsl #11
    ldr x9, [x27, #88]
    cmp x9, #1
    b.eq Ltable_scan_next
    cmp x26, #NODE_TR
    b.ne Ltable_cell
    add x22, x22, #1
    mov x23, #0
    b Ltable_scan_next
Ltable_cell:
    cmp x22, #0
    csel x22, xzr, x22, lt
    cmp x22, #256
    b.hs Ltable_scan_next
    ldr x28, [x27, #HTML_COLSPAN]
    mov x9, #1
    cmp x28, #1
    csel x28, x9, x28, lt
Ltable_find_column:
    add x9, x23, x28
    cmp x9, #64
    b.hi Ltable_scan_next
    mov x10, x23
Ltable_check_span:
    cmp x10, x9
    b.hs Ltable_place
    ldr x11, [sp, x10, lsl #3]
    cmp x11, x22
    b.gt Ltable_occupied
    add x10, x10, #1
    b Ltable_check_span
Ltable_occupied:
    add x23, x10, #1
    b Ltable_find_column
Ltable_place:
    add x10, x20, #1
    str x10, [x27, #FLOW_OWNER]
    str x22, [x27, #FLOW_ROW]
    str x23, [x27, #FLOW_COLUMN]
    str x28, [x27, #FLOW_COLSPAN]
    ldr x10, [x27, #HTML_ROWSPAN]
    mov x11, #1
    cmp x10, #1
    csel x10, x11, x10, lt
    str x10, [x27, #FLOW_ROWSPAN]
    add x10, x10, x22
Ltable_mark_span:
    cmp x23, x9
    b.hs Ltable_marked
    str x10, [sp, x23, lsl #3]
    add x23, x23, #1
    b Ltable_mark_span
Ltable_marked:
    cmp x24, x23
    csel x24, x23, x24, lt
Ltable_scan_next:
    add x25, x25, #1
    b Ltable_scan
Ltable_columns:
    cbz x24, Ltable_done
    str x24, [x21, #FLOW_COLUMNS]
    add x25, x20, #1
Ltable_width_request:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Ltable_distribute
    ldr x27, [x19, #72]
    add x27, x27, x25, lsl #11
    ldr x9, [x27, #FLOW_OWNER]
    add x10, x20, #1
    cmp x9, x10
    b.ne Ltable_width_next
    ldr x9, [x27, #FLOW_COLSPAN]
    cmp x9, #1
    b.ne Ltable_width_next
    ldr x26, [x27, #FLOW_INTRINSIC_W]
    ldr x9, [x27, #144]
    tbnz x9, #63, Ltable_width_extras
    ldr x26, [x27, #768]
    ldr x9, [x27, #FLOW_COLUMN]
    add x10, sp, #1024
    mov x11, #1
    str x11, [x10, x9, lsl #3]
Ltable_width_extras:
    ldr x9, [x27, #808]
    ldr x10, [x27, #816]
    add x26, x26, x9
    add x26, x26, x10
    ldr x9, [x27, #BOX_BORDER_LEFT]
    add x26, x26, x9
    ldr x9, [x27, #BOX_BORDER_RIGHT]
    add x26, x26, x9
    ldr x9, [x27, #FLOW_COLUMN]
    add x10, sp, #512
    ldr x11, [x10, x9, lsl #3]
    cmp x26, x11
    csel x26, x11, x26, lt
    str x26, [x10, x9, lsl #3]
Ltable_width_next:
    add x25, x25, #1
    b Ltable_width_request
Ltable_distribute:
    mov x25, #0
    mov x26, #0
    str xzr, [sp, #1536]
    add x27, sp, #512
Ltable_width_sum:
    cmp x25, x24
    b.hs Ltable_width_scale
    ldr x9, [x27, x25, lsl #3]
    mov x10, #16
    cmp x9, x10
    csel x9, x10, x9, lt
    str x9, [x27, x25, lsl #3]
    add x26, x26, x9
    add x10, sp, #1024
    ldr x10, [x10, x25, lsl #3]
    cbnz x10, Ltable_width_sum_next
    ldr x10, [sp, #1536]
    add x10, x10, #1
    str x10, [sp, #1536]
Ltable_width_sum_next:
    add x25, x25, #1
    b Ltable_width_sum
Ltable_width_scale:
    ldr x28, [x21, #768]
    mov x25, #0
Ltable_scale_next:
    cmp x25, x24
    b.hs Ltable_apply_widths
    ldr x9, [x27, x25, lsl #3]
    cmp x26, x28
    b.gt Ltable_scale_shrink
    ldr x11, [sp, #1536]
    cbz x11, Ltable_scale_all
    add x10, sp, #1024
    ldr x10, [x10, x25, lsl #3]
    cbnz x10, Ltable_scale_store
    b Ltable_scale_extra
Ltable_scale_all:
    mov x11, x24
Ltable_scale_extra:
    sub x10, x28, x26
    udiv x10, x10, x11
    add x9, x9, x10
    b Ltable_scale_store
Ltable_scale_shrink:
    mul x9, x9, x28
    udiv x9, x9, x26
Ltable_scale_store:
    mov x10, #1
    cmp x9, x10
    csel x9, x10, x9, lt
    str x9, [x27, x25, lsl #3]
    add x25, x25, #1
    b Ltable_scale_next
Ltable_apply_widths:
    add x25, x20, #1
Ltable_apply_next:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Ltable_done
    ldr x27, [x19, #72]
    add x27, x27, x25, lsl #11
    ldr x9, [x27, #FLOW_OWNER]
    add x10, x20, #1
    cmp x9, x10
    b.ne Ltable_apply_advance
    ldr x9, [x27, #FLOW_COLUMN]
    ldr x10, [x27, #FLOW_COLSPAN]
    add x10, x10, x9
    mov x11, #0
    add x12, sp, #512
Ltable_span_width:
    cmp x9, x10
    b.hs Ltable_content_width
    ldr x13, [x12, x9, lsl #3]
    add x11, x11, x13
    add x9, x9, #1
    b Ltable_span_width
Ltable_content_width:
    ldr x9, [x27, #808]
    ldr x10, [x27, #816]
    sub x11, x11, x9
    sub x11, x11, x10
    ldr x9, [x27, #BOX_BORDER_LEFT]
    sub x11, x11, x9
    ldr x9, [x27, #BOX_BORDER_RIGHT]
    sub x11, x11, x9
    mov x9, #1
    cmp x11, x9
    csel x11, x9, x11, lt
    ldr x9, [x21, #1568]
    sub x11, x11, x9
    mov x10, #1
    cmp x11, x10
    csel x11, x10, x11, lt
    lsr x10, x9, #1
    str x10, [x27, #FLOW_LEAD]
    sub x10, x9, x10
    str x10, [x27, #FLOW_TRAIL]
    lsr x10, x9, #1
    str x10, [x27, #FLOW_BEFORE]
    sub x10, x9, x10
    str x10, [x27, #FLOW_AFTER]
    str x11, [x27, #FLOW_WIDTH]
    str x24, [x27, #FLOW_COLUMNS]
Ltable_apply_advance:
    add x25, x25, #1
    b Ltable_apply_next
Ltable_done:
    add sp, sp, #1664
    LEAVE
