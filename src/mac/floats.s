// TextKit adapter for assembly-positioned float boxes. No native float/table
// layout is used: callbacks supply the engine's content and margin rectangles.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,node,shared cache -> owned OogaFloatBlock.
.globl _mac_float_block
_mac_float_block:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ADDR x0, float_class_name
    bl _objc_getClass
    cbnz x0, Lfloat_class_ready
    CLASS NSTextBlock
    ADDR x1, float_class_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x22, x0
    ADDR x0, float_rect_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x22
    ADDR x2, float_rect
    ADDR x3, float_rect_encoding
    bl _class_addMethod
    ADDR x0, float_bounds_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x22
    ADDR x2, float_bounds
    ADDR x3, float_bounds_encoding
    bl _class_addMethod
    ADDR x0, float_draw_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x22
    ADDR x2, float_draw
    ADDR x3, float_draw_encoding
    bl _class_addMethod
    mov x0, x22
    bl _objc_registerClassPair
    mov x0, x22
Lfloat_class_ready:
    MSG new
    mov x22, x0
    ldr x23, [x19, #72]
    add x23, x23, x20, lsl #11
    mov x0, x22
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x9, [x9, #FLOW_WIDTH]
    scvtf d0, x9
    mov x2, #0
    MSG blockWidth
    // Snapshot geometry: document replacement may free its original metadata.
    CLASS NSMutableData
    mov x2, x23
    mov x3, #CSS_META_SIZE
    MSG dataBytesLength
    mov x2, x0
    mov x0, x22
    ADDR x1, float_meta_key
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x22
    LOAD x2, _mac_float_records
    ADDR x1, _mac_float_records_key
    mov x3, #1
    bl _objc_setAssociatedObject
    CLASS NSNumber
    ldr x2, [x23, #FLOW_OWNER]
    orr x2, x2, #0x100000000
    MSG numberLongLong
    mov x24, x0
    mov x2, x24
    mov x0, x21
    MSG objectKey
    cbnz x0, Lfloat_group_ready
    CLASS NSMutableData
    MSG new
    mov x25, x0
    mov x2, #32
    MSG setLength
    mov x0, x21
    mov x2, x25
    mov x3, x24
    MSG setObjectKey
    mov x0, x25
    MSG autorelease
Lfloat_group_ready:
    mov x2, x0
    mov x0, x22
    ADDR x1, float_group_key
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x22
    LEAVE

// rectForLayoutAtPoint:inRect:textContainer:characterRange:
// HFA ABI: startingPoint d0/d1; containing rect d2..d5; range x3/x4.
float_rect:
    ENTER
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    stp d4, d5, [sp, #176]
    mov x19, x0
    ADDR x1, float_meta_key
    bl _objc_getAssociatedObject
    MSG bytes
    mov x20, x0
    mov x0, x19
    ADDR x1, float_group_key
    bl _objc_getAssociatedObject
    MSG mutableBytes
    mov x21, x0
    ldr x9, [x21]
    cbnz x9, Lfloat_rect_anchor
    mov x9, #1
    str x9, [x21]
    ldr d0, [sp, #160]
    str d0, [x21, #8]
    ldr d0, [sp, #152]
    str d0, [x21, #16]
Lfloat_rect_anchor:
    ldr x9, [x20, #FLOAT_NATIVE_RECORD]
    cbz x9, Lfloat_record_ready
    ldr x10, [x9, #48]
    cbnz x10, Lfloat_record_cached
    str x9, [sp, #192]
    ldr x10, [x20, #144]
    tbnz x10, #63, Lfloat_auto_width
    tbz x10, #32, Lfloat_width_ready
    mov x0, x10
    ldr d0, [sp, #176]
    fcvtms x1, d0
    bl _engine_box_length
    ldr x9, [x20, #FLOW_WIDTH]
    ldr x10, [x20, #FLOAT_W]
    sub x10, x10, x9
    ldr x11, [x20, #216]
    cbz x11, Lfloat_percent_content
    ldr x11, [x20, #808]
    sub x0, x0, x11
    ldr x11, [x20, #816]
    sub x0, x0, x11
    ldr x11, [x20, #BOX_BORDER_LEFT]
    sub x0, x0, x11
    ldr x11, [x20, #BOX_BORDER_RIGHT]
    sub x0, x0, x11
Lfloat_percent_content:
    mov x11, #1
    cmp x0, #1
    csel x0, x11, x0, lt
    str x0, [x20, #FLOW_WIDTH]
    add x10, x10, x0
    str x10, [x20, #FLOAT_W]
    ldr x9, [sp, #192]
    b Lfloat_width_ready
Lfloat_auto_width:
    ldr x10, [x20, #FLOAT_W]
    ldr x11, [x20, #FLOW_WIDTH]
    sub x10, x10, x11
    scvtf d0, x10
    ldr d1, [sp, #176]
    fsub d1, d1, d0
    fcvtms x12, d1
    mov x13, #1
    cmp x12, #1
    csel x12, x13, x12, lt
    cmp x11, x12
    csel x11, x12, x11, gt
    str x11, [x20, #FLOW_WIDTH]
    add x10, x10, x11
    str x10, [x20, #FLOAT_W]
Lfloat_width_ready:
    ldr x10, [x20, #FLOAT_W]
    scvtf d0, x10
    str d0, [x9, #32]
    ldr x10, [x20, #FLOAT_H]
    scvtf d0, x10
    str d0, [x9, #40]
    str x9, [sp, #192]
    mov x0, x19
    ADDR x1, _mac_float_records_key
    bl _objc_getAssociatedObject
    MSG bytes
    ldr x1, [sp, #192]
    ldr d0, [sp, #160]
    ldr d1, [x21, #16]
    ldr d2, [x21, #24]
    fmax d1, d1, d2
    ldr d2, [sp, #168]
    fmax d1, d1, d2
    ldr d2, [sp, #176]
    ldr x2, [x20, #(32+CSS_CLEAR*8)]
    bl _engine_float_fit
    ldr x9, [sp, #192]
    stp d0, d1, [x9, #16]
    mov x10, #1
    str x10, [x9, #48]
Lfloat_record_cached:
    // Glyph content is positioned inside the reconciled margin box.
    ldr d0, [x9, #16]
    ldr d1, [x9, #24]
    stp d0, d1, [sp, #192]
Lfloat_record_ready:
    mov x9, #0
    ldr x10, [x20, #776]
    add x9, x9, x10
    ldr x10, [x20, #BOX_BORDER_LEFT]
    add x9, x9, x10
    ldr x10, [x20, #808]
    add x9, x9, x10
    scvtf d0, x9
    ldr d4, [sp, #192]
    fadd d0, d0, d4
    mov x9, #0
    ldr x10, [x20, #792]
    add x9, x9, x10
    ldr x10, [x20, #BOX_BORDER_TOP]
    add x9, x9, x10
    ldr x10, [x20, #824]
    add x9, x9, x10
    scvtf d1, x9
    ldr d4, [sp, #200]
    fadd d1, d1, d4
    ldr x9, [x20, #FLOW_WIDTH]
    scvtf d2, x9
    // Supply a generous line-layout height; CSS height controls the painted box,
    // while overflowing content remains visible rather than clipped.
    NUM d3, 1048576
    LEAVE

// boundsRectForContentRect:inRect:textContainer:characterRange:
float_bounds:
    ENTER
    str x0, [sp, #176]
    stp d0, d1, [sp, #144]
    str d3, [sp, #160]
    ADDR x1, float_meta_key
    bl _objc_getAssociatedObject
    MSG bytes
    mov x19, x0
    ldr x9, [x19, #152]
    tbz x9, #63, Lfloat_bounds_size_ready
    ldr x9, [x19, #FLOAT_NATIVE_RECORD]
    cbz x9, Lfloat_bounds_size_ready
    ldr d0, [sp, #160]
    ldr x10, [x19, #792]
    ldr x11, [x19, #800]
    add x10, x10, x11
    ldr x11, [x19, #824]
    add x10, x10, x11
    ldr x11, [x19, #832]
    add x10, x10, x11
    ldr x11, [x19, #BOX_BORDER_TOP]
    add x10, x10, x11
    ldr x11, [x19, #BOX_BORDER_BOTTOM]
    add x10, x10, x11
    scvtf d1, x10
    fadd d0, d0, d1
    str d0, [x9, #40]
    mov x20, x9
    ldr x0, [sp, #176]
    ADDR x1, _mac_float_records_key
    bl _objc_getAssociatedObject
    MSG bytes
    ldr x1, [x20, #56]
    lsr x1, x1, #8
    add x1, x1, #1
    mov x2, #-1
    mov x3, #3
    bl _engine_float_clear_bottom
    ldr d1, [x20, #24]
    fsub d0, d0, d1
    ldr x9, [x19, #800]
    ldr x10, [x19, #832]
    add x9, x9, x10
    ldr x10, [x19, #BOX_BORDER_BOTTOM]
    add x9, x9, x10
    scvtf d1, x9
    fadd d0, d0, d1
    ldr d1, [x20, #40]
    fmax d0, d0, d1
    str d0, [x20, #40]
Lfloat_bounds_size_ready:
    ldr x9, [x19, #776]
    ldr x10, [x19, #BOX_BORDER_LEFT]
    add x9, x9, x10
    ldr x10, [x19, #808]
    add x9, x9, x10
    scvtf d4, x9
    ldr d0, [sp, #144]
    fsub d0, d0, d4
    ldr x9, [x19, #792]
    ldr x10, [x19, #BOX_BORDER_TOP]
    add x9, x9, x10
    ldr x10, [x19, #824]
    add x9, x9, x10
    scvtf d4, x9
    ldr d1, [sp, #152]
    fsub d1, d1, d4
    ldr x9, [x19, #FLOAT_W]
    scvtf d2, x9
    fmov d3, xzr                   // floats do not advance ordinary block flow
    LEAVE
// Regular ancestor boxes retain native line layout but use the same exact
// margin-excluding paint path as floats.
.globl _mac_css_block
_mac_css_block:
    ENTER
    mov x19, x0
    mov x21, x1
    ADDR x0, css_block_class_name
    bl _objc_getClass
    cbnz x0, Lcss_block_class_ready
    CLASS NSTextBlock
    ADDR x1, css_block_class_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x20, x0
    ADDR x0, float_draw_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x20
    ADDR x2, float_draw
    ADDR x3, float_draw_encoding
    bl _class_addMethod
    ADDR x0, float_rect_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x20
    ADDR x2, clear_rect
    ADDR x3, float_rect_encoding
    bl _class_addMethod
    ADDR x0, float_bounds_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x20
    ADDR x2, css_bounds
    ADDR x3, float_bounds_encoding
    bl _class_addMethod
    mov x0, x20
    bl _objc_registerClassPair
    mov x0, x20
Lcss_block_class_ready:
    MSG new
    mov x20, x0
    CLASS NSMutableData
    mov x2, x19
    mov x3, #CSS_META_SIZE
    MSG dataBytesLength
    mov x2, x0
    mov x0, x20
    ADDR x1, float_meta_key
    mov x3, #1
    bl _objc_setAssociatedObject
    ldr x2, [x19, #FLOAT_GROUP]
    cbz x2, Lcss_block_return
    orr x2, x2, #0x100000000
    CLASS NSNumber
    ldr x2, [x19, #FLOAT_GROUP]
    orr x2, x2, #0x100000000
    MSG numberLongLong
    mov x2, x0
    mov x0, x21
    MSG objectKey
    cbnz x0, Lcss_group_ready
    CLASS NSMutableData
    MSG new
    mov x22, x0
    mov x2, #32
    MSG setLength
    CLASS NSNumber
    ldr x2, [x19, #FLOAT_GROUP]
    orr x2, x2, #0x100000000
    MSG numberLongLong
    mov x3, x0
    mov x0, x21
    mov x2, x22
    MSG setObjectKey
    mov x0, x22
    MSG autorelease
Lcss_group_ready:
    mov x2, x0
    mov x0, x20
    ADDR x1, float_group_key
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x20
    LOAD x2, _mac_float_records
    ADDR x1, _mac_float_records_key
    mov x3, #1
    bl _objc_setAssociatedObject
Lcss_block_return:
    mov x0, x20
    LEAVE

// Preserve normal block layout, raising its content origin for clear:left/right/both.
clear_rect:
    ENTER
    mov x19, x0
    mov x20, x1
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    stp d4, d5, [sp, #176]
    stp x2, x3, [sp, #192]
    str x4, [sp, #208]
    CLASS NSTextBlock
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    ldp d4, d5, [sp, #176]
    ldp x2, x3, [sp, #192]
    ldr x4, [sp, #208]
    bl _objc_msgSendSuper
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x19
    ADDR x1, float_group_key
    bl _objc_getAssociatedObject
    cbz x0, Lclear_rect_return
    MSG bytes
    mov x20, x0
    ldr x9, [x20]
    cbz x9, Lclear_rect_return
    mov x0, x19
    ADDR x1, float_meta_key
    bl _objc_getAssociatedObject
    MSG bytes
    mov x21, x0
    ldr x9, [x21, #(32+CSS_CLEAR*8)]
    cbz x9, Lclear_rect_return
    mov x0, x19
    ADDR x1, _mac_float_records_key
    bl _objc_getAssociatedObject
    MSG bytes
    ldr x1, [x21, #FLOAT_CONTEXT]
    ldr x2, [sp, #200]
    ldr x3, [x21, #(32+CSS_CLEAR*8)]
    bl _engine_float_clear_bottom
    ldr x9, [x21, #792]
    ldr x10, [x21, #BOX_BORDER_TOP]
    add x9, x9, x10
    ldr x10, [x21, #824]
    add x9, x9, x10
    scvtf d1, x9
    fadd d0, d0, d1
    ldr d1, [sp, #152]
    fmax d1, d1, d0
    str d1, [sp, #152]
Lclear_rect_return:
    mov x0, x19
    ADDR x1, float_meta_key
    bl _objc_getAssociatedObject
    MSG mutableBytes
    ldp d0, d1, [sp, #144]
    str d0, [x0, #NATIVE_CONTENT_X]
    str d1, [x0, #NATIVE_CONTENT_Y]
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    LEAVE

// Ordinary ancestor bounds start at their own content origin, not the first
// displaced descendant. This also keeps out-of-flow children out of auto height.
css_bounds:
    ENTER
    str x0, [sp, #176]
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    ADDR x1, float_meta_key
    bl _objc_getAssociatedObject
    MSG bytes
    mov x19, x0
    ldr d0, [x19, #NATIVE_CONTENT_X]
    ldr d1, [x19, #NATIVE_CONTENT_Y]
    ldr x9, [x19, #768]
    scvtf d2, x9
    ldr x9, [x19, #FLOAT_CONTAINER_ONLY]
    cbnz x9, Lcss_bounds_empty
    ldr d3, [sp, #152]
    ldr d4, [sp, #168]
    fadd d3, d3, d4
    fsub d3, d3, d1
    fmov d4, xzr
    fmax d3, d3, d4
    b Lcss_bounds_height
Lcss_bounds_empty:
    fmov d3, xzr
Lcss_bounds_height:
    ldr x9, [x19, #152]
    tbnz x9, #63, Lcss_bounds_edges
    scvtf d4, x9
    fmax d3, d3, d4
Lcss_bounds_edges:
    ldr x9, [x19, #776]
    ldr x10, [x19, #808]
    add x9, x9, x10
    ldr x10, [x19, #BOX_BORDER_LEFT]
    add x9, x9, x10
    scvtf d4, x9
    fsub d0, d0, d4
    fadd d2, d2, d4
    ldr x9, [x19, #784]
    ldr x10, [x19, #816]
    add x9, x9, x10
    ldr x10, [x19, #BOX_BORDER_RIGHT]
    add x9, x9, x10
    scvtf d4, x9
    fadd d2, d2, d4
    ldr x9, [x19, #792]
    ldr x10, [x19, #824]
    add x9, x9, x10
    ldr x10, [x19, #BOX_BORDER_TOP]
    add x9, x9, x10
    scvtf d4, x9
    fsub d1, d1, d4
    fadd d3, d3, d4
    ldr x9, [x19, #800]
    ldr x10, [x19, #832]
    add x9, x9, x10
    ldr x10, [x19, #BOX_BORDER_BOTTOM]
    add x9, x9, x10
    scvtf d4, x9
    fadd d3, d3, d4
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    ldr x9, [x19, #FLOAT_CONTAINER_ONLY]
    cbnz x9, Lcss_bounds_return
    // Original block object is saved separately below.
    ldr x0, [sp, #176]
    ADDR x1, float_group_key
    bl _objc_getAssociatedObject
    cbz x0, Lcss_bounds_return
    MSG mutableBytes
    ldr d0, [sp, #152]
    ldr d1, [sp, #168]
    fadd d0, d0, d1
    ldr d1, [x0, #24]
    fmax d0, d0, d1
    str d0, [x0, #24]
Lcss_bounds_return:
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    LEAVE

// Paint exactly the CSS border box, excluding margins. TextKit's default
// background method treats custom bounds differently from table-cell bounds.
float_draw:
    b _mac_display_box
.section __TEXT,__cstring,cstring_literals
float_draw_name: .asciz "drawBackgroundWithFrame:inView:characterRange:layoutManager:"
float_draw_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}@{_NSRange=QQ}@"
css_block_class_name: .asciz "OogaCssBlock"
float_class_name: .asciz "OogaFloatBlock"
float_rect_name: .asciz "rectForLayoutAtPoint:inRect:textContainer:characterRange:"
float_bounds_name: .asciz "boundsRectForContentRect:inRect:textContainer:characterRange:"
float_rect_encoding: .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGPoint=dd}{CGRect={CGPoint=dd}{CGSize=dd}}@{_NSRange=QQ}"
float_bounds_encoding: .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGRect={CGPoint=dd}{CGSize=dd}}@{_NSRange=QQ}"
float_meta_key: .asciz "floatGeometry"
float_group_key: .asciz "floatContext"
