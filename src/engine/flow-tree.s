.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_flow_tree
.globl _engine_flow_tree_impl
_engine_flow_tree_impl:
    ENTER
    mov x19, x0
    ldr x20, [x19, #72]
    ldr x21, [x19, #24]
    mov x22, #0
Lflow_clear:
    cmp x22, x21
    b.hs Lflow_layout_start
    add x23, x20, x22, lsl #11
    add x0, x23, #FLOW_OWNER
    mov x1, #0
    mov x2, #80
    bl _memset
    str xzr, [x23, #FLOW_BASE]
    str xzr, [x23, #FLOW_CROSS]
    str xzr, [x23, #FLOW_BEFORE]
    str xzr, [x23, #FLOW_AFTER]
    add x22, x22, #1
    b Lflow_clear
Lflow_layout_start:
    mov x22, #1
Lflow_layout_next:
    cmp x22, x21
    b.hs Lflow_layout_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x24, x22, x10, x9
    ldr x9, [x24, #8]
    add x9, x20, x9, lsl #11
    ldr x1, [x9, #768]
    add x23, x20, x22, lsl #11
    mov x0, x23
    bl _engine_box_metrics
    ldr x9, [x23, #FLOW_OWNER]
    cbz x9, Lflow_owner_kind
    ldr x9, [x23, #FLOW_WIDTH]
    cbz x9, Lflow_owner_kind
    str x9, [x23, #768]
Lflow_owner_kind:
    ldr x9, [x23, #88]
    cmp x9, #1
    b.eq Lflow_layout_advance
    cmp x9, #3
    b.ne Lflow_table_kind
    mov x0, x19
    mov x1, x22
    bl _engine_flex_owner
    b Lflow_layout_advance
Lflow_table_kind:
    ldr x9, [x24]
    cmp x9, #NODE_TABLE
    b.ne Lflow_layout_advance
    mov x0, x19
    mov x1, x22
    bl _engine_table_owner
Lflow_layout_advance:
    add x22, x22, #1
    b Lflow_layout_next
Lflow_layout_done:
    LEAVE

// Forced paragraph events let native shared table cells retain separate ranges
// even when source markup has adjacent inline elements and no separating byte.
.globl _engine_flow_breaks
_engine_flow_breaks:
    ldr x2, [x0, #72]
    ldr x3, [x0, #16]
    ldr x4, [x0, #24]
    ldr x5, [x0]
    ldr x6, [x0, #80]
    mov x7, #0
Lflow_break_next:
    cmp x7, x4
    b.hs Lflow_break_done
    add x8, x2, x7, lsl #11
    ldr x8, [x8, #FLOW_OWNER]
    cbz x8, Lflow_break_advance
    sub x8, x8, #1
    mov x9, #40
    madd x10, x7, x9, x3
    madd x8, x8, x9, x3
    ldr x11, [x10, #16]
    ldr x12, [x10, #24]
    cmp x11, x12
    b.hs Lflow_break_advance
    mov w9, #1
    strb w9, [x1, x11]
    strb w9, [x1, x12]
    ldr x13, [x8, #16]
Lflow_gap_before:
    cmp x11, x13
    b.ls Lflow_gap_after_start
    sub x14, x11, #1
    ldrb w15, [x5, x14]
    cmp w15, #32
    b.hi Lflow_gap_after_start
    ldrb w15, [x6, x14]
    cmp w15, #3
    b.eq Lflow_gap_after_start
    strb w9, [x6, x14]
    mov x11, x14
    b Lflow_gap_before
Lflow_gap_after_start:
    ldr x13, [x8, #24]
Lflow_gap_after:
    cmp x12, x13
    b.hs Lflow_break_advance
    ldrb w15, [x5, x12]
    cmp w15, #32
    b.hi Lflow_break_advance
    ldrb w15, [x6, x12]
    cmp w15, #3
    b.eq Lflow_break_advance
    strb w9, [x6, x12]
    add x12, x12, #1
    b Lflow_gap_after
Lflow_break_advance:
    add x7, x7, #1
    b Lflow_break_next
Lflow_break_done:
    ret
