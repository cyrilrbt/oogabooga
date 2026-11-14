// Native glyph layout inside assembly-created CSS boxes. TextKit supplies text
// measurement, while our tree/cascade determines nesting and box dimensions.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// document, UTF16 layout, attributed string
.globl _mac_blocks
_mac_blocks:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x0, [x19, #24]
    mov x1, #8
    bl _calloc
    cbz x0, Lblocks_done
    mov x22, x0
    ldr x9, [x19, #72]
    LOAD x10, _engine_viewport
    str x10, [x9, #768]
    mov x23, #1
Lblock_create:
    ldr x9, [x19, #24]
    cmp x23, x9
    b.hs Lblocks_ranges
    ldr x24, [x19, #72]
    add x24, x24, x23, lsl #10
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x23, x10, x9
    ldr x10, [x9, #8]
    ldr x11, [x19, #72]
    add x11, x11, x10, lsl #10
    ldr x1, [x11, #768]
    mov x0, x24
    bl _engine_box_metrics
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x23, x10, x9
    ldr x9, [x9]
    cmp x9, #NODE_TEXT
    b.eq Lblock_create_next
    cmp x9, #NODE_A
    b.eq Lblock_create_next
    cmp x9, #NODE_SPAN
    b.eq Lblock_create_next
    cmp x9, #NODE_STRONG
    b.eq Lblock_create_next
    cmp x9, #NODE_EM
    b.eq Lblock_create_next
    cmp x9, #NODE_NAV
    b.hi Lblock_create_next
    ldr x9, [x24, #208]
    cmn x9, #1
    b.ne Lblock_make
    ldr x9, [x24, #144]             // width/height or nonzero padding/border
    cmn x9, #1
    b.ne Lblock_make
    ldr x9, [x24, #152]
    cmn x9, #1
    b.ne Lblock_make
    ldp x9, x10, [x24, #160]
    orr x9, x9, x10
    ldp x10, x11, [x24, #176]
    orr x9, x9, x10
    orr x9, x9, x11
    ldr x10, [x24, #192]
    orr x9, x9, x10
    cbz x9, Lblock_create_next
Lblock_make:
    CLASS NSTextTable
    MSG new
    mov x27, x0
    mov x2, #1
    MSG tableColumns
    CLASS NSTextTableBlock
    MSG alloc
    mov x2, x27
    mov x3, #0
    mov x4, #1
    mov x5, #0
    mov x6, #1
    MSG tableBlock
    mov x25, x0
    mov x0, x27
    MSG release
    mov x0, x25
    str x0, [x22, x23, lsl #3]
    ldr x9, [x24, #768]
    scvtf d0, x9
    mov x2, #0
    MSG blockWidth
Lblock_height:
    ldr x9, [x24, #152]
    tbnz x9, #63, Lblock_edges
    scvtf d0, x9
    mov x0, x25
    mov x2, #0
    mov x3, #5                     // minimum height, allowing content to grow
    MSG blockValue
Lblock_edges:
    mov x26, #0
Lblock_edge:
    // NSRectEdge = left, top, right, bottom in flipped text coordinates.
    ADDR x9, edge_properties
    ldr x10, [x9, x26, lsl #3]
    mov x9, x24
    ldr x9, [x9, x10, lsl #3]
    scvtf d0, x9
    mov x0, x25
    mov x2, #0
    mov x3, #-1                    // padding layer
    mov x4, x26
    MSG blockEdge
    mov x0, x25
    ldr x9, [x24, #192]
    scvtf d0, x9
    mov x2, #0
    mov x3, #0                     // solid border
    mov x4, x26
    MSG blockEdge
    ADDR x9, margin_properties
    ldr x10, [x9, x26, lsl #3]
    mov x9, x24
    ldr x9, [x9, x10, lsl #3]
    scvtf d0, x9
    mov x0, x25
    mov x2, #0
    mov x3, #1
    mov x4, x26
    MSG blockEdge
    add x26, x26, #1
    cmp x26, #4
    b.lo Lblock_edge
    ldr x0, [x24, #200]
    bl _mac_css_color
    mov x2, x0
    mov x0, x25
    MSG blockBorderColor
    ldr x0, [x24, #40]
    bl _mac_css_color
    mov x2, x0
    mov x0, x25
    MSG setBackgroundColor
Lblock_create_next:
    add x23, x23, #1
    b Lblock_create
Lblocks_ranges:
    mov x23, #0
Lblocks_range:
    ldr x9, [x19, #24]
    cmp x23, x9
    b.hs Lblocks_free
    ldr x24, [x19, #16]
    mov x9, #40
    madd x24, x23, x9, x24
    // Include container ranges and their blank paragraph separators, so one
    // shared table cell encloses the entire block instead of painting fragments.
Lblocks_leaf:
    ldr x9, [x20, #16]
    ldr x10, [x24, #16]
    ldr x11, [x24, #24]
    ldr x25, [x9, x10, lsl #3]
    ldr x26, [x9, x11, lsl #3]
    sub x26, x26, x25
    cbz x26, Lblocks_range_next
    CLASS NSMutableArray
    MSG new
    mov x27, x0
    mov x28, x23
Lblocks_ancestors:
    cmp x28, #1
    b.lo Lblocks_apply
    ldr x2, [x22, x28, lsl #3]
    cbz x2, Lblocks_parent
    mov x0, x27
    mov x3, #0
    MSG insertObjectIndex
Lblocks_parent:
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x28, x10, x9
    ldr x28, [x9, #8]
    b Lblocks_ancestors
Lblocks_apply:
    mov x0, x27
    MSG count
    cbz x0, Lblocks_release_array
    ldr x9, [x24]
    cmp x9, #NODE_TEXT
    b.eq Lblocks_copy_style
    cmp x9, #NODE_A
    b.eq Lblocks_copy_style
    cmp x9, #NODE_SPAN
    b.eq Lblocks_copy_style
    cmp x9, #NODE_STRONG
    b.eq Lblocks_copy_style
    cmp x9, #NODE_EM
    b.eq Lblocks_copy_style
    cmp x9, #NODE_SELECT
    b.eq Lblocks_copy_style
    cmp x9, #NODE_TEXTAREA
    b.eq Lblocks_copy_style
    cmp x9, #NODE_INPUT
    b.eq Lblocks_copy_style
    cmp x9, #NODE_IMG
    b.eq Lblocks_copy_style
    cmp x9, #NODE_BUTTON
    b.eq Lblocks_copy_style
    ldr x0, [x19, #72]
    add x0, x0, x23, lsl #10
    bl _mac_css_paragraph
    b Lblocks_style
Lblocks_copy_style:
    mov x0, x21
    adrp x9, _NSParagraphStyleAttributeName@GOTPAGE
    ldr x9, [x9, _NSParagraphStyleAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, x25
    mov x4, #0
    MSG attributeIndex
    MSG mutableCopy
    cbnz x0, Lblocks_style
    CLASS NSMutableParagraphStyle
    MSG new
Lblocks_style:
    mov x28, x0
    mov x2, x27
    MSG setTextBlocks
    ldr x9, [x22, x23, lsl #3]
    cbz x9, Lblocks_install
    mov x0, x28
    fmov d0, xzr
    MSG setHeadIndent
    mov x0, x28
    fmov d0, xzr
    MSG setFirstIndent
    mov x0, x28
    fmov d0, xzr
    MSG setTailIndent
    mov x0, x28
    fmov d0, xzr
    MSG setParagraphBefore
    mov x0, x28
    fmov d0, xzr
    MSG setParagraphAfter
Lblocks_install:
    // Box margins are represented by block geometry; native paragraph spacing
    // remains available for nested paragraphs without their own boxes.
    mov x0, x21
    adrp x9, _NSParagraphStyleAttributeName@GOTPAGE
    ldr x9, [x9, _NSParagraphStyleAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, x28
    mov x4, x25
    mov x5, x26
    MSG addAttribute
    mov x0, x28
    MSG release
Lblocks_release_array:
    mov x0, x27
    MSG release
Lblocks_range_next:
    add x23, x23, #1
    b Lblocks_range
Lblocks_free:
    mov x23, #0
Lblocks_free_next:
    ldr x9, [x19, #24]
    cmp x23, x9
    b.hs Lblocks_free_buffer
    ldr x0, [x22, x23, lsl #3]
    MSG release
    add x23, x23, #1
    b Lblocks_free_next
Lblocks_free_buffer:
    mov x0, x22
    bl _free
Lblocks_done:
    LEAVE
.section __DATA,__const
.p2align 3
edge_properties: .quad 101, 103, 102, 104
margin_properties: .quad 97, 99, 98, 100
