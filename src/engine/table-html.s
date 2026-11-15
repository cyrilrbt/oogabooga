.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// Close omitted </td>, </th>, </tr> without escaping a nested table boundary.
.globl _engine_table_autoclose
_engine_table_autoclose:
    mov x4, x2
    cmp x3, #NODE_DT
    b.eq Ldefinition_auto_scan
    cmp x3, #NODE_DD
    b.eq Ldefinition_auto_scan
    cmp x3, #NODE_TR
    b.eq Ltable_auto_scan
    cmp x3, #NODE_TD
    b.eq Ltable_auto_scan
    cmp x3, #NODE_TH
    b.ne Ltable_auto_done
    b Ltable_auto_scan
Ldefinition_auto_scan:
    cmp x4, #3
    b.ls Ltable_auto_done
    sub x4, x4, #1
    ldr x5, [x1, x4, lsl #3]
    ldr x6, [x0, #16]
    mov x7, #40
    madd x5, x5, x7, x6
    ldr x6, [x5]
    cmp x6, #NODE_DL
    b.eq Ltable_auto_done
    cmp x6, #NODE_DT
    b.eq Ltable_auto_close
    cmp x6, #NODE_DD
    b.eq Ltable_auto_close
    b Ldefinition_auto_scan
Ltable_auto_scan:
    cmp x4, #3
    b.ls Ltable_auto_done
    sub x4, x4, #1
    ldr x5, [x1, x4, lsl #3]
    ldr x6, [x0, #16]
    mov x7, #40
    madd x5, x5, x7, x6
    ldr x6, [x5]
    cmp x6, #NODE_TABLE
    b.eq Ltable_auto_done
    cmp x3, #NODE_TR
    b.eq Ltable_auto_row
    cmp x6, #NODE_TR
    b.eq Ltable_auto_done
    cmp x6, #NODE_TD
    b.eq Ltable_auto_close
    cmp x6, #NODE_TH
    b.eq Ltable_auto_close
    b Ltable_auto_scan
Ltable_auto_row:
    cmp x6, #NODE_TR
    b.ne Ltable_auto_scan
Ltable_auto_close:
    ldr x8, [x0, #8]
Ltable_auto_unwind:
    sub x2, x2, #1
    ldr x5, [x1, x2, lsl #3]
    ldr x6, [x0, #16]
    mov x7, #40
    madd x5, x5, x7, x6
    str x8, [x5, #24]
    cmp x2, x4
    b.hi Ltable_auto_unwind
Ltable_auto_done:
    sub x4, x2, #1
    ldr x1, [x1, x4, lsl #3]
    mov x0, x2
    ret

.globl _engine_table_attributes
_engine_table_attributes:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ADDR x22, table_integer_attributes
Ltable_attribute_next:
    ldr x2, [x22]
    cbz x2, Ltable_attribute_align
    mov x0, x20
    mov x1, x21
    bl _engine_attribute
    mov x23, x0
    mov x24, #0
    cbz x0, Ltable_attribute_store
    mov x1, #0
    mov x2, #10
    bl _strtol
    cmp x0, #0
    csel x24, xzr, x0, lt
    mov x9, #64
    cmp x24, x9
    csel x24, x9, x24, hi
Ltable_attribute_store:
    ldr x9, [x22, #8]
    str x24, [x19, x9]
    mov x0, x23
    bl _free
    add x22, x22, #16
    b Ltable_attribute_next
Ltable_attribute_align:
    mov x0, x20
    mov x1, x21
    ADDR x2, table_align
    bl _engine_attribute
    mov x23, x0
    cbz x0, Ltable_attribute_done
    bl _strlen
    mov x2, x0
    add x2, x23, x2
    mov x1, x23
    mov x0, #CSS_ALIGN
    bl _css_value
    cbz x1, Ltable_align_free
    add x0, x0, #1
    str x0, [x19, #1536]
Ltable_align_free:
    mov x0, x23
    bl _free
Ltable_attribute_done:
    LEAVE

// Low-priority legacy presentation hints. Author CSS cascades afterward.
.globl _engine_table_hints
_engine_table_hints:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    add x21, x21, x20, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x22, x20, x10, x9
    ldr x23, [x22]
    cmp x23, #NODE_TH
    b.ne Ltable_hint_align
    mov x9, #700
    str x9, [x21, #56]
    mov x9, #2
    str x9, [x21, #80]
Ltable_hint_align:
    ldr x9, [x21, #1536]
    cbz x9, Ltable_hint_width
    sub x9, x9, #1
    str x9, [x21, #80]
Ltable_hint_width:
    ldr x24, [x21, #ATTR_WIDTH]
    cbz x24, Ltable_hint_owner
    mov x0, x24
    bl _strlen
    add x1, x24, x0
    mov x0, x24
    bl _css_number
    cbz x2, Ltable_hint_owner
    cbnz x1, Ltable_hint_width_units
    mov x9, #1000
    udiv x0, x0, x9
    str x0, [x21, #144]
    b Ltable_hint_owner
Ltable_hint_width_units:
    orr x0, x0, x1, lsl #32
    orr x0, x0, #0x8000000000000000
    str x0, [x21, #144]
Ltable_hint_owner:
    mov x24, x20
Ltable_hint_find:
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x24, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_TABLE
    b.eq Ltable_hint_found
    ldr x24, [x9, #8]
    tbnz x24, #63, Ltable_hint_done
    b Ltable_hint_find
Ltable_hint_found:
    ldr x25, [x19, #72]
    add x25, x25, x24, lsl #11
    ldr x9, [x25, #1552]
    cmp x23, #NODE_TABLE
    b.eq Ltable_hint_border
    cmp x23, #NODE_TD
    b.eq Ltable_hint_cell
    cmp x23, #NODE_TH
    b.ne Ltable_hint_done
Ltable_hint_cell:
    cmp x9, #0
    cset x9, ne
    ldr x10, [x25, #1560]
    stp x10, x10, [x21, #160]
    stp x10, x10, [x21, #176]
Ltable_hint_border:
    str x9, [x21, #192]
    str x9, [x21, #(32+CSS_BORDER_RIGHT*8)]
    str x9, [x21, #(32+CSS_BORDER_BOTTOM*8)]
    str x9, [x21, #(32+CSS_BORDER_LEFT*8)]
Ltable_hint_done:
    LEAVE
.section __DATA,__const
.p2align 3
table_integer_attributes:
.quad table_colspan, HTML_COLSPAN, table_rowspan, HTML_ROWSPAN
.quad table_border, 1552, table_cellpadding, 1560, table_cellspacing, 1568
.quad 0, 0
.section __TEXT,__cstring,cstring_literals
table_colspan: .asciz "colspan"
table_rowspan: .asciz "rowspan"
table_border: .asciz "border"
table_cellpadding: .asciz "cellpadding"
table_cellspacing: .asciz "cellspacing"
table_align: .asciz "align"
