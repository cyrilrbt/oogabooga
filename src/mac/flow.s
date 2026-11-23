// Native measurement and shared table-cell drawing for assembly-computed flows.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_flow_measure
.globl _mac_flow_measure_impl
_mac_flow_measure_impl:
    ENTER
    mov x19, x0
    mov x0, #8193
    bl _malloc
    str x0, [sp, #144]
    mov x20, #1
Lmeasure_item:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lmeasure_done
    ldr x21, [x19, #72]
    add x21, x21, x20, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x22, x20, x10, x9
    str xzr, [x21, #NATIVE_HAS_REPLACED]
    str xzr, [x21, #FLOW_MIN_CONTENT]
    str xzr, [x21, #FLOW_MAX_CONTENT]
    ldr x9, [x22]
    ldr x10, [x21, #NATIVE_EMPTY]
    cbnz x10, Lmeasure_empty
    mov x23, #220
    mov x24, #28
    cmp x9, #NODE_INPUT
    b.eq Lmeasure_control
    cmp x9, #NODE_BUTTON
    b.eq Lmeasure_control
    cmp x9, #NODE_SELECT
    b.eq Lmeasure_control
    cmp x9, #NODE_TEXTAREA
    b.ne Lmeasure_image
    mov x24, #100
Lmeasure_control:
    mov x0, x21
    ldr x1, [x22]
    mov x2, x20
    bl _mac_control_create
    cbz x0, Lmeasure_control_dimensions
    mov x25, x0
    mov x0, x21
    bl _mac_css_font
    mov x2, x0
    mov x0, x25
    ldr x9, [x22]
    cmp x9, #NODE_TEXTAREA
    b.ne Lmeasure_control_font
    str x2, [sp, #152]
    MSG documentView
    ldr x2, [sp, #152]
Lmeasure_control_font:
    MSG setFont
    mov x0, x21
    ldr x1, [x22]
    bl _mac_control_kind
    mov x2, x0
    mov x0, x21
    mov x1, x25
    bl _mac_input_border
    ldr x9, [x22]
    cmp x9, #NODE_TEXTAREA
    b.eq Lmeasure_control_dimensions
    mov x0, x25
    MSG intrinsicSize
    fcvtps x26, d0
    fcvtps x27, d1
    cmp x27, #0
    csel x24, x27, x24, gt
    mov x0, x21
    ldr x1, [x22]
    bl _mac_control_kind
    cmp x0, #1
    b.eq Lmeasure_button_width
    cmp x0, #8
    b.eq Lmeasure_button_width
    cmp x0, #4
    b.eq Lmeasure_toggle_width
    cmp x0, #5
    b.ne Lmeasure_control_dimensions
Lmeasure_toggle_width:
    cmp x26, #0
    csel x23, x26, x23, gt
    b Lmeasure_control_dimensions
Lmeasure_button_width:
    mov x0, x25
    MSG buttonBordered
    cbnz w0, Lmeasure_native_button_width
    mov x23, x26
    b Lmeasure_control_dimensions
Lmeasure_native_button_width:
    mov x9, #100
    cmp x26, x9
    csel x23, x26, x9, gt
Lmeasure_control_dimensions:
    mov x0, x21
    bl _mac_element_dimensions
    cmp x0, #0
    csel x23, x23, x0, lt
    cmp x1, #0
    csel x24, x24, x1, lt
    mov x0, x21
    ldr x1, [x21, #848]
    mov x2, x23
    bl _engine_width_clamp
    mov x23, x0
    ldr x9, [x21, #BOX_MAX_HEIGHT]
    tbnz x9, #63, Lmeasure_control_min_height
    cmp x24, x9
    csel x24, x9, x24, gt
Lmeasure_control_min_height:
    ldr x9, [x21, #BOX_MIN_HEIGHT]
    cmp x24, x9
    csel x24, x9, x24, lt
    b Lmeasure_store
Lmeasure_image:
    cmp x9, #NODE_SVG
    b.eq Lmeasure_svg
    cmp x9, #NODE_IMG
    b.ne Lmeasure_text
    mov x23, #64
    mov x24, #64
    CLASS NSNumber
    mov x2, x20
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_images
    MSG objectKey
    cbz x0, Lmeasure_image_dimensions
    MSG size
    fcvtps x23, d0
    fcvtps x24, d1
    b Lmeasure_image_dimensions
Lmeasure_svg:
    mov x23, #24
    mov x24, #24
Lmeasure_image_dimensions:
    mov x0, x21
    bl _mac_element_dimensions
    cmp x0, #0
    csel x23, x23, x0, lt
    cmp x1, #0
    csel x24, x24, x1, lt
    b Lmeasure_store
Lmeasure_text:
    // Nested text below a formatting context contributes its own styled run.
    // Ordinary prose outside those contexts still skips the intrinsic pass.
    ldr x10, [x22, #8]
    mov x11, #64
Lmeasure_intrinsic_ancestor:
    cbz x11, Lmeasure_text_local
    sub x11, x11, #1
    ldr x12, [x19, #72]
    add x12, x12, x10, lsl #11
    ldr x13, [x12, #88]
    cmp x13, #3
    b.hs Lmeasure_text_needed
    ldr x13, [x12, #(32+CSS_FLOAT*8)]
    cbnz x13, Lmeasure_text_needed
    ldr x13, [x12, #(1840+(CSS_POSITION-48)*8)]
    cmp x13, #2
    b.hs Lmeasure_text_needed
    cbz x10, Lmeasure_text_local
    ldr x12, [x19, #16]
    mov x13, #40
    madd x12, x10, x13, x12
    ldr x10, [x12, #8]
    b Lmeasure_intrinsic_ancestor
Lmeasure_text_local:
    ldr x10, [x21, #(1840+(CSS_POSITION-48)*8)]
    cmp x10, #2
    b.hs Lmeasure_text_needed
    // Only flex items, table cells and floats consume intrinsic text metrics.
    // Ordinary paragraphs are shaped once by the real text layout pass.
    ldr x10, [x21, #(32+CSS_FLOAT*8)]
    cbnz x10, Lmeasure_text_needed
    cmp x9, #NODE_TD
    b.eq Lmeasure_text_needed
    cmp x9, #NODE_TH
    b.eq Lmeasure_text_needed
    ldr x10, [x22, #8]
    ldr x11, [x19, #72]
    add x10, x11, x10, lsl #11
    ldr x10, [x10, #88]
    cmp x10, #4
    b.eq Lmeasure_text_needed
    cmp x10, #3
    b.eq Lmeasure_text_needed
    mov x23, #1
    mov x24, #1
    b Lmeasure_store
Lmeasure_text_needed:
    ldr x9, [x22, #16]
    ldr x10, [x22, #24]
    sub x24, x10, x9
    cmp x24, #8192
    b.hi Lmeasure_large
    ldr x10, [x19]
    add x23, x10, x9
    ldr x10, [sp, #144]
    cbz x10, Lmeasure_large
    mov x11, #0
    mov x12, #0
Lmeasure_filter:
    cmp x11, x24
    b.hs Lmeasure_filtered
    ldrb w13, [x23, x11]
    cmp w13, #0xef
    b.ne Lmeasure_copy_byte
    add x14, x11, #2
    cmp x14, x24
    b.hs Lmeasure_copy_byte
    add x14, x23, x11
    ldrb w15, [x14, #1]
    cmp w15, #0xbf
    b.ne Lmeasure_copy_byte
    ldrb w15, [x14, #2]
    cmp w15, #0xbc
    b.ne Lmeasure_copy_byte
    add x11, x11, #2
    mov w13, #32
Lmeasure_copy_byte:
    strb w13, [x10, x12]
    add x12, x12, #1
    add x11, x11, #1
    b Lmeasure_filter
Lmeasure_filtered:
    mov x23, x10
    mov x24, x12
    CLASS NSString
    MSG alloc
    mov x2, x23
    mov x3, x24
    mov x4, #4
    MSG initBytesEncoding
    mov x23, x0
    CLASS NSMutableDictionary
    MSG new
    mov x24, x0
    mov x0, x21
    bl _mac_css_font
    mov x2, x0
    adrp x9, _NSFontAttributeName@GOTPAGE
    ldr x9, [x9, _NSFontAttributeName@GOTPAGEOFF]
    ldr x3, [x9]
    mov x0, x24
    MSG setObjectKey
    CLASS NSAttributedString
    MSG alloc
    mov x2, x23
    mov x3, x24
    MSG initStringAttributes
    str x0, [sp, #160]
    bl _mac_intrinsic_cache_get
    cbz x0, Lmeasure_uncached
    MSG bytes
    ldp x25, x26, [x0]
    ldr x9, [x0, #16]
    str x9, [x21, #FLOW_MIN_CONTENT]
    b Lmeasure_cached
Lmeasure_uncached:
    mov x0, x23
    mov x2, x24
    MSG sizeAttributes
    fcvtps x25, d0
    fcvtps x26, d1
    mov x0, x23
    mov x1, x24
    bl _mac_min_content
    str x0, [x21, #FLOW_MIN_CONTENT]
    mov x3, x0
    ldr x0, [sp, #160]
    mov x1, x25
    mov x2, x26
    bl _mac_intrinsic_cache_put
Lmeasure_cached:
    str x25, [x21, #FLOW_MAX_CONTENT]
    ldr x9, [x21, #888]
    cmp x9, #1
    b.eq Lmeasure_no_break_min
    cmp x9, #2
    b.ne Lmeasure_release_text
Lmeasure_no_break_min:
    str x25, [x21, #FLOW_MIN_CONTENT]
Lmeasure_release_text:
    ldr x0, [sp, #160]
    MSG release
    mov x0, x23
    MSG release
    mov x0, x24
    MSG release
    mov x23, x25
    mov x24, x26
    b Lmeasure_store
Lmeasure_empty:
    mov x23, #0
    mov x24, #0
    b Lmeasure_store
Lmeasure_large:
    ldr x23, [x21, #848]
    ldr x24, [x21, #48]
    lsl x24, x24, #1
Lmeasure_store:
Lmeasure_cap:
    mov x9, #4096
    cmp x23, x9
    csel x23, x9, x23, hi
    cmp x24, x9
    csel x24, x9, x24, hi
    ldr x9, [x21, #FLOW_MIN_CONTENT]
    cbnz x9, Lmeasure_min_saved
    str x23, [x21, #FLOW_MIN_CONTENT]
Lmeasure_min_saved:
    ldr x9, [x21, #FLOW_MAX_CONTENT]
    cbnz x9, Lmeasure_max_saved
    str x23, [x21, #FLOW_MAX_CONTENT]
Lmeasure_max_saved:
    str x23, [x21, #FLOW_INTRINSIC_W]
    str x24, [x21, #FLOW_INTRINSIC_H]
    add x20, x20, #1
    b Lmeasure_item
Lmeasure_done:
    ldr x0, [sp, #144]
    bl _free
    // Propagate replaced-element bounds/flags through ancestors in O(nodes*depth).
    mov x20, #1
Lmeasure_replaced_node:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lmeasure_all_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x22, x20, x10, x9
    ldr x9, [x22]
    cmp x9, #NODE_INPUT
    b.eq Lmeasure_propagate
    cmp x9, #NODE_SELECT
    b.eq Lmeasure_propagate
    cmp x9, #NODE_TEXTAREA
    b.eq Lmeasure_propagate
    cmp x9, #NODE_IMG
    b.eq Lmeasure_propagate
    cmp x9, #NODE_SVG
    b.ne Lmeasure_replaced_next
Lmeasure_propagate:
    ldr x21, [x19, #72]
    add x9, x21, x20, lsl #11
    ldr x23, [x9, #FLOW_INTRINSIC_W]
    ldr x24, [x9, #FLOW_INTRINSIC_H]
    mov x25, x20
Lmeasure_ancestor:
    add x9, x21, x25, lsl #11
    mov x10, #1
    str x10, [x9, #NATIVE_HAS_REPLACED]
    ldr x10, [x9, #FLOW_INTRINSIC_W]
    cmp x10, x23
    csel x10, x23, x10, lt
    str x10, [x9, #FLOW_INTRINSIC_W]
    ldr x10, [x9, #FLOW_INTRINSIC_H]
    cmp x10, x24
    csel x10, x24, x10, lt
    str x10, [x9, #FLOW_INTRINSIC_H]
    cbz x25, Lmeasure_replaced_next
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x25, x10, x9
    ldr x25, [x9, #8]
    b Lmeasure_ancestor
Lmeasure_replaced_next:
    add x20, x20, #1
    b Lmeasure_replaced_node
Lmeasure_all_done:
    LEAVE

// doc,node,table cache -> owned shared-flow block or nil.
.globl _mac_grid_cell
_mac_grid_cell:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #72]
    add x22, x22, x20, lsl #11
    ldr x23, [x22, #FLOW_OWNER]
    cbz x23, Lgrid_nil
    sub x23, x23, #1
    ldr x24, [x19, #72]
    add x24, x24, x23, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x23, x10, x9
    ldr x25, [x9]
    // A one-column CSS flow needs ordinary block layout, not a one-cell
    // NSTextTable wrapper. Nested wrappers can stop TextKit after one glyph.
    cmp x25, #NODE_TABLE
    b.eq Lgrid_multi_column
    ldr x9, [x22, #FLOW_COLUMNS]
    cmp x9, #1
    b.ne Lgrid_multi_column
    mov x26, #0
    add x27, x23, #1
Lgrid_single_item_scan:
    ldr x9, [x19, #24]
    cmp x27, x9
    b.hs Lgrid_single_item_found
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x27, x10, x9
    ldr x9, [x9, #8]
    cmp x9, x23
    b.lo Lgrid_single_item_found
    b.ne Lgrid_single_item_next
    mov x0, x19
    mov x1, x27
    bl _engine_flow_item
    cbz x0, Lgrid_single_item_next
    add x26, x26, #1
    cmp x26, #2
    b.hs Lgrid_multi_column
Lgrid_single_item_next:
    add x27, x27, #1
    b Lgrid_single_item_scan
Lgrid_single_item_found:
    mov x0, x22
    mov x1, x21
    bl _mac_css_block
    LEAVE
Lgrid_multi_column:
    add x9, x23, #1
    lsl x26, x9, #16
    ldr x9, [x24, #88]
    cmp x9, #4
    b.eq Lgrid_key
    cmp x25, #NODE_TABLE
    b.eq Lgrid_key
    ldr x9, [x22, #FLOW_ROW]
    add x9, x9, #1
    orr x26, x26, x9
Lgrid_key:
    CLASS NSNumber
    mov x2, x26
    MSG numberLongLong
    mov x27, x0
    mov x2, x27
    mov x0, x21
    MSG objectKey
    cbnz x0, Lgrid_table_ready
    CLASS NSTextTable
    MSG new
    mov x28, x0
    ldr x2, [x22, #FLOW_COLUMNS]
    MSG tableColumns
    mov x0, x28
    mov x2, #1
    ldr x9, [x24, #88]
    cmp x9, #4
    csel x2, xzr, x2, eq          // Grid widths can be declared after spanning rows
    MSG tableLayoutAlgorithm
    mov x0, x28
    ldr x9, [x24, #768]
    scvtf d0, x9
    mov x2, #0
    MSG blockWidth
    mov x0, x21
    mov x2, x28
    mov x3, x27
    MSG setObjectKey
    mov x0, x28
    MSG release
    mov x0, x28
Lgrid_table_ready:
    mov x28, x0
    CLASS NSTextTableBlock
    MSG alloc
    mov x2, x28
    mov x3, #0
    mov x4, #1
    ldr x9, [x24, #88]
    cmp x9, #4
    b.eq Lgrid_row_coordinates
    cmp x25, #NODE_TABLE
    b.ne Lgrid_block_coordinates
Lgrid_row_coordinates:
    ldr x3, [x22, #FLOW_ROW]
    ldr x4, [x22, #FLOW_ROWSPAN]
Lgrid_block_coordinates:
    ldr x5, [x22, #FLOW_COLUMN]
    ldr x6, [x22, #FLOW_COLSPAN]
    MSG tableBlock
    mov x27, x0
    ldr x9, [x22, #FLOW_WIDTH]
    ldr x10, [x22, #872]
    cbz x10, Lgrid_content_width
    ldr x10, [x22, #808]
    add x9, x9, x10
    ldr x10, [x22, #816]
    add x9, x9, x10
    ldr x10, [x22, #BOX_BORDER_LEFT]
    add x9, x9, x10
    ldr x10, [x22, #BOX_BORDER_RIGHT]
    add x9, x9, x10
    ldr x10, [x22, #776]
    add x9, x9, x10
    ldr x10, [x22, #784]
    add x9, x9, x10
Lgrid_content_width:
    str xzr, [x22, #FLOW_CROSS]
    str x9, [sp, #144]
    ldr x10, [x22, #FLOW_HEIGHT]
    ldr x11, [x22, #FLOW_INTRINSIC_H]
    ldr w12, [x22, #112]
    // TextKit honors authored line-height even when font ink is taller.
    // Replaced elements can enlarge the line, ordinary text cannot.
    ldr x13, [x22, #NATIVE_HAS_REPLACED]
    cmp x13, #0
    csel x11, x12, x11, eq
    cmp x11, x12
    csel x11, x12, x11, lt
    sub x10, x10, x11
    cmp x10, #0
    b.le Lgrid_height_padding_ready
    ldr x11, [x19, #16]
    mov x12, #40
    madd x11, x20, x12, x11
    ldp x12, x13, [x11, #16]
    ldr x14, [x19]
Lgrid_height_single_line:
    cmp x12, x13
    b.hs Lgrid_height_padding_store
    ldrb w15, [x14, x12]
    cmp w15, #10
    b.eq Lgrid_height_padding_ready
    add x12, x12, #1
    b Lgrid_height_single_line
Lgrid_height_padding_store:
    str x10, [x22, #FLOW_CROSS]
Lgrid_height_padding_ready:
    ldr x9, [sp, #144]
    scvtf d0, x9
    mov x2, #0
    MSG blockWidth
    ldr x9, [x22, #FLOW_HEIGHT]
    cbz x9, Lgrid_alignment
    mov x0, x27
    scvtf d0, x9
    mov x2, #0
    mov x3, #5
    MSG blockValue
Lgrid_alignment:
    mov x2, #0
    cmp x25, #NODE_TABLE
    b.eq Lgrid_table_alignment
    ldr x9, [x24, #(32+CSS_ALIGN_ITEMS*8)]
    ldr x10, [x22, #(32+CSS_ALIGN_SELF*8)]
    tbnz x10, #63, Lgrid_align_value
    mov x9, x10
Lgrid_align_value:
    cmp x9, #2
    b.ne Lgrid_align_end
    mov x2, #1
    b Lgrid_set_alignment
Lgrid_align_end:
    cmp x9, #3
    b.ne Lgrid_align_baseline
    mov x2, #2
    b Lgrid_set_alignment
Lgrid_align_baseline:
    cmp x9, #4
    b.ne Lgrid_set_alignment
    mov x2, #3
    b Lgrid_set_alignment
Lgrid_table_alignment:
    ldr x9, [x22, #880]
    cmn x9, #18
    b.ne Lgrid_set_alignment
    mov x2, #1
    b Lgrid_set_alignment
Lgrid_set_alignment:
    mov x0, x27
    MSG blockVerticalAlignment
    mov x0, x27
    LEAVE
Lgrid_nil:
    mov x0, #0
    LEAVE
