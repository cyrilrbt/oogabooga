// Layer-backed inline links. TextKit reserves an attachment; this native view
// paints the CSS box and text and supplies keyboard/accessibility link actions.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_inline_button_class
_mac_inline_button_class:
    ENTER
    CLASS OogaboogaInlineLink
    cbnz x0, Linline_class_done
    CLASS NSButton
    ADDR x1, inline_class_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    ADDR x20, inline_methods
Linline_class_method:
    ldr x9, [x20]
    cbz x9, Linline_class_register
    mov x0, x19
    ldr x1, [x9]
    ldr x2, [x20, #8]
    ldr x3, [x20, #16]
    bl _class_addMethod
    add x20, x20, #24
    b Linline_class_method
Linline_class_register:
    mov x0, x19
    bl _objc_registerClassPair
    mov x0, x19
Linline_class_done:
    LEAVE

inline_intrinsic:
    ENTER
    MSG frame
    fmov d0, d2
    fmov d1, d3
    LEAVE
inline_baseline:
    ENTER
    ADDR x1, baseline_key
    bl _objc_getAssociatedObject
    MSG doubleValue
    LEAVE
inline_draw:
    ENTER
    mov x19, x0
    ADDR x1, title_rect_key
    bl _objc_getAssociatedObject
    MSG rectValue
    stp d0, d1, [sp, #144]
    mov x0, x19
    MSG attributedTitle
    ldp d0, d1, [sp, #144]
    MSG drawAttributedPoint
    LEAVE
.globl _mac_inline_margins
_mac_inline_margins:
    ENTER
    ADDR x1, margins_key
    bl _objc_getAssociatedObject
    MSG rectValue
    LEAVE
inline_cursor_rects:
    ENTER
    mov x19, x0
    MSG isEnabled
    cbz w0, Linline_cursor_done
    CLASS NSCursor
    MSG pointingHandCursor
    mov x20, x0
    mov x0, x19
    MSG bounds
    mov x0, x19
    mov x2, x20
    MSG addCursorRect
Linline_cursor_done:
    LEAVE

.globl _mac_inline_link_click
_mac_inline_link_click:
    ENTER
    mov x0, x2
    MSG cell
    MSG representedObject
    bl _mac_engine_open_url
    LEAVE

// natural, explicit CSS length, min length, metadata, padding+border -> extent.
inline_extent:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    tbnz x20, #63, Linline_extent_min
    mov x0, x20
    ldr x1, [x22, #848]
    bl _engine_box_length
    ldr x9, [x22, #216]
    cbnz x9, Linline_extent_explicit
    add x0, x0, x23
Linline_extent_explicit:
    mov x19, x0
Linline_extent_min:
    mov x0, x21
    ldr x1, [x22, #848]
    bl _engine_box_length
    ldr x9, [x22, #216]
    cbnz x9, Linline_extent_compare
    add x0, x0, x23
Linline_extent_compare:
    cmp x19, x0
    csel x19, x0, x19, lt
    mov x9, #4096
    cmp x19, x9
    csel x19, x9, x19, gt
    mov x9, #1
    cmp x19, x9
    csel x0, x9, x19, lt
    LEAVE

// configure(control, metadata, node index) -> same control, ownership unchanged.
.globl _mac_inline_configure
_mac_inline_configure:
    ENTER
    sub sp, sp, #256
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x9, _engine_render_document
    ldr x10, [x9, #16]
    mov x11, #40
    madd x26, x21, x11, x10
    ldr x10, [x26, #16]
    ldr x11, [x26, #24]
    ldr x9, [x9]
    add x22, x9, x10
    sub x23, x11, x10
    CLASS NSString
    MSG alloc
    mov x2, x22
    mov x3, x23
    mov x4, #4
    MSG initBytesEncoding
    mov x23, x0
    CLASS NSMutableDictionary
    MSG new
    mov x22, x0
    mov x0, x20
    bl _mac_css_font
    mov x24, x0
    mov x2, x24
    adrp x9, _NSFontAttributeName@GOTPAGE
    ldr x9, [x9, _NSFontAttributeName@GOTPAGEOFF]
    ldr x3, [x9]
    mov x0, x22
    MSG setObjectKey
    ldr x0, [x20, #32]
    bl _mac_css_color
    cbnz x0, Linline_title_color
    CLASS NSColor
    MSG textColor
Linline_title_color:
    mov x2, x0
    adrp x9, _NSForegroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSForegroundColorAttributeName@GOTPAGEOFF]
    ldr x3, [x9]
    mov x0, x22
    MSG setObjectKey
    CLASS NSNumber
    ldr x2, [x20, #72]
    MSG numberLongLong
    mov x2, x0
    adrp x9, _NSUnderlineStyleAttributeName@GOTPAGE
    ldr x9, [x9, _NSUnderlineStyleAttributeName@GOTPAGEOFF]
    ldr x3, [x9]
    mov x0, x22
    MSG setObjectKey
    mov x0, x23
    mov x2, x22
    MSG sizeAttributes
    fcvtps x9, d0
    fcvtps x10, d1
    stp x9, x10, [sp, #24]         // natural title width/height
    mov x0, x24
    MSG ascender
    str d0, [sp, #96]
    CLASS NSAttributedString
    MSG alloc
    mov x2, x23
    mov x3, x22
    MSG initStringAttributes
    mov x24, x0
    mov x0, x19
    mov x2, x24
    MSG setAttributedTitle
    mov x0, x24
    MSG release
    mov x0, x22
    MSG release
    mov x0, x19
    mov x2, #0
    MSG setBordered
    mov x0, x19
    mov x2, #1
    MSG setWantsLayer
    mov x0, x19
    mov x2, x21
    MSG setTag
    mov x0, x19
    LOAD x2, _mac_delegate
    MSG setTarget
    mov x0, x19
    SELECT x2, inlineLink
    MSG setAction
    mov x0, x19
    mov x2, x23
    MSG setAccessibilityLabel
    STR inline_link_role
    mov x2, x0
    mov x0, x19
    MSG setAccessibilityRole
    ldr x0, [x26, #32]
    bl _mac_string
    mov x24, x0
    CLASS NSURL
    mov x2, x24
    LOAD x3, _engine_render_base
    MSG relativeURL
    MSG absoluteURL
    mov x27, x0
    MSG scheme
    bl _mac_allowed_scheme
    mov x2, x0
    mov x0, x19
    MSG setEnabled
    mov x0, x19
    MSG cell
    mov x2, x27
    MSG setRepresentedObject
    // Materialize all four padding edges and the border before sizing.
    ldr x9, [x20, #808]
    str x9, [sp, #56]
    ldr x10, [x20, #816]
    str x10, [sp, #64]
    ldr x11, [x20, #824]
    str x11, [sp, #72]
    ldr x12, [x20, #832]
    str x12, [sp, #80]
    ldr x13, [x20, #840]
    str x13, [sp, #88]
    add x4, x9, x10
    add x4, x4, x13, lsl #1
    ldr x0, [sp, #24]
    add x0, x0, x4
    ldr x1, [x20, #144]
    ldr x2, [x20, #248]
    mov x3, x20
    bl inline_extent
    str x0, [sp, #40]
    ldr x1, [x20, #208]
    tbnz x1, #63, Linline_size_height
    ldr x1, [x20, #848]
    ldr x0, [x20, #208]
    bl _engine_box_length
    ldr x9, [sp, #40]
    cmp x9, x0
    csel x9, x0, x9, gt
    str x9, [sp, #40]
Linline_size_height:
    ldr x9, [sp, #72]
    ldr x10, [sp, #80]
    ldr x11, [sp, #88]
    add x4, x9, x10
    add x4, x4, x11, lsl #1
    ldr x0, [sp, #32]
    add x0, x0, x4
    ldr x1, [x20, #152]
    ldr x2, [x20, #232]
    mov x3, x20
    bl inline_extent
    str x0, [sp, #48]
    mov x0, x19
    ldr x9, [sp, #40]
    scvtf d0, x9
    ldr x9, [sp, #48]
    scvtf d1, x9
    MSG setFrameSize
    // Place text inside the padded content area, honoring text-align.
    ldr x9, [sp, #56]
    ldr x10, [sp, #88]
    add x9, x9, x10
    scvtf d0, x9
    ldr x11, [sp, #40]
    sub x11, x11, x9
    ldr x12, [sp, #64]
    sub x11, x11, x12
    sub x11, x11, x10
    ldr x12, [sp, #24]
    sub x11, x11, x12
    cmp x11, #0
    csel x11, xzr, x11, lt
    ldr x12, [x20, #80]
    cmp x12, #2
    b.eq Linline_title_center
    cmp x12, #1
    b.ne Linline_title_x
    scvtf d1, x11
    fadd d0, d0, d1
    b Linline_title_x
Linline_title_center:
    scvtf d1, x11
    fmov d2, #0.5
    fmadd d0, d1, d2, d0
Linline_title_x:
    str d0, [sp, #104]
    ldr x9, [sp, #72]
    ldr x10, [sp, #88]
    add x9, x9, x10
    ldr x11, [sp, #48]
    sub x11, x11, x9
    ldr x12, [sp, #80]
    sub x11, x11, x12
    sub x11, x11, x10
    ldr x12, [sp, #32]
    sub x11, x11, x12
    cmp x11, #0
    csel x11, xzr, x11, lt
    scvtf d1, x9
    scvtf d2, x11
    fmov d3, #0.5
    fmadd d1, d2, d3, d1
    str d1, [sp, #112]
    ldr d0, [sp, #96]
    fadd d0, d0, d1
    ldr x9, [x20, #240]
    cbz x9, Linline_baseline_store
    ldr x9, [sp, #48]
    scvtf d0, x9
    fmov d1, #0.5
    fmul d0, d0, d1
    ldr x9, [x20, #48]
    scvtf d1, x9
    fmov d2, #0.25
    fmadd d0, d1, d2, d0
Linline_baseline_store:
    str d0, [sp, #96]
    CLASS NSNumber
    ldr d0, [sp, #96]
    MSG numberDouble
    mov x2, x0
    mov x0, x19
    ADDR x1, baseline_key
    mov x3, #1
    bl _objc_setAssociatedObject
    CLASS NSValue
    ldp d0, d1, [sp, #104]
    ldr x9, [sp, #24]
    scvtf d2, x9
    ldr x9, [sp, #32]
    scvtf d3, x9
    MSG valueRect
    mov x2, x0
    mov x0, x19
    ADDR x1, title_rect_key
    mov x3, #1
    bl _objc_setAssociatedObject
    CLASS NSValue
    ldr x9, [x20, #776]
    scvtf d0, x9
    ldr x9, [x20, #792]
    scvtf d1, x9
    ldr x9, [x20, #784]
    scvtf d2, x9
    ldr x9, [x20, #800]
    scvtf d3, x9
    MSG valueRect
    mov x2, x0
    mov x0, x19
    ADDR x1, margins_key
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x19
    MSG layer
    mov x25, x0
    ldr x0, [x20, #40]
    bl _mac_css_color
    MSG CGColor
    mov x2, x0
    mov x0, x25
    MSG setBackgroundCG
    ldr x9, [sp, #40]
    ldr x10, [sp, #48]
    cmp x9, x10
    csel x1, x9, x10, lt
    ldr x0, [x20, #224]
    bl _engine_box_length
    ldr x9, [sp, #40]
    ldr x10, [sp, #48]
    cmp x9, x10
    csel x9, x9, x10, lt
    lsr x9, x9, #1
    cmp x0, x9
    csel x0, x9, x0, hi
    scvtf d0, x0
    mov x0, x25
    MSG setCornerRadius
    ldr x9, [sp, #88]
    scvtf d0, x9
    mov x0, x25
    MSG setBorderWidth
    ldr x0, [x20, #200]
    bl _mac_css_color
    MSG CGColor
    mov x2, x0
    mov x0, x25
    MSG setBorderCG
    mov x0, x19
    mov x2, #1
    MSG setNeedsDisplay
    mov x0, x23
    MSG release
    mov x0, x19
    add sp, sp, #256
    LEAVE
.section __DATA,__data
.p2align 3
baseline_key: .quad 0
title_rect_key: .quad 0
margins_key: .quad 0
.section __DATA,__const
.p2align 3
inline_methods:
.quad _sel_intrinsicSize, inline_intrinsic, inline_size_encoding
.quad _sel_firstBaseline, inline_baseline, inline_double_encoding
.quad _sel_drawRect, inline_draw, inline_draw_encoding
.quad _sel_resetCursorRects, inline_cursor_rects, inline_void_encoding
.quad 0, 0, 0
.section __TEXT,__cstring,cstring_literals
inline_class_name: .asciz "OogaboogaInlineLink"
inline_link_role: .asciz "AXLink"
inline_size_encoding: .asciz "{CGSize=dd}@:"
inline_double_encoding: .asciz "d@:"
inline_draw_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
inline_void_encoding: .asciz "v@:"
