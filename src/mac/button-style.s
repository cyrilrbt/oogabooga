// CSS button metrics with native NSButton tracking, focus and accessibility.
// Cells own an immutable inset snapshot; no document pointers survive reflow.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_button_cell_install
_mac_button_cell_install:
    ENTER
    mov x19, x0
    CLASS OogaboogaButtonCell
    cbnz x0, Lbutton_cell_allocate
    CLASS NSButtonCell
    ADDR x1, button_cell_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x20, x0
    SELECT x1, buttonTitleRect
    ADDR x2, button_title_rect
    ADDR x3, button_rect_encoding
    bl _class_addMethod
    mov x0, x20
    SELECT x1, buttonCellSize
    ADDR x2, button_cell_size
    ADDR x3, button_size_encoding
    bl _class_addMethod
    mov x0, x20
    SELECT x1, bgCellDraw
    ADDR x2, button_background_draw
    ADDR x3, button_draw_encoding
    bl _class_addMethod
    mov x0, x20
    bl _objc_registerClassPair
    mov x0, x20
Lbutton_cell_allocate:
    MSG alloc
    mov x20, x0
    STR button_empty
    mov x2, x0
    mov x0, x20
    MSG initTextCell
    mov x20, x0
    mov x2, x0
    mov x0, x19
    MSG buttonSetCell
    mov x0, x20
    MSG release
    LEAVE

// Styled button title content area. Native cells still draw and track the title.
button_title_rect:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    ADDR x1, button_insets_key
    bl _objc_getAssociatedObject
    cbz x0, Lbutton_title_native
    MSG bytes
    ldp d0, d1, [x0]
    ldp d2, d3, [x0, #16]
    stp d0, d1, [sp, #176]
    stp d2, d3, [sp, #192]
    mov x0, x19
    MSG attributedTitle
    MSG size
    ldp d2, d3, [sp, #160]
    ldp d4, d5, [sp, #176] // left, top
    ldp d6, d7, [sp, #192] // right, bottom
    fsub d2, d2, d4
    fsub d2, d2, d6
    fsub d3, d3, d5
    fsub d3, d3, d7
    fmov d16, xzr
    fmax d2, d2, d16
    fmax d3, d3, d16
    fmin d0, d0, d2
    fmin d1, d1, d3
    fmov d6, d0
    fmov d7, d1
    fsub d2, d2, d0
    fsub d3, d3, d1
    fmov d0, #0.5
    fmul d2, d2, d0
    fmul d3, d3, d0
    ldp d0, d1, [sp, #144]
    fadd d0, d0, d4
    fadd d0, d0, d2
    fadd d1, d1, d5
    fadd d1, d1, d3
    fmov d2, d6
    fmov d3, d7
    LEAVE
Lbutton_title_native:
    CLASS NSButtonCell
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, buttonTitleRect
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _objc_msgSendSuper
    LEAVE

button_cell_size:
    ENTER
    mov x19, x0
    ADDR x1, button_insets_key
    bl _objc_getAssociatedObject
    cbz x0, Lbutton_size_native
    MSG bytes
    ldp d0, d1, [x0]
    ldp d2, d3, [x0, #16]
    fadd d0, d0, d2
    fadd d1, d1, d3
    stp d0, d1, [sp, #144]
    mov x0, x19
    MSG attributedTitle
    MSG size
    ldp d2, d3, [sp, #144]
    fadd d0, d0, d2
    fadd d1, d1, d3
    LEAVE
Lbutton_size_native:
    CLASS NSButtonCell
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, buttonCellSize
    bl _objc_msgSendSuper
    LEAVE

// x0 metadata, x1 NSButton. Return authored visual styling flag.
.globl _mac_button_style
_mac_button_style:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #0
    // Color/font inheritance alone does not suppress the platform bezel.
    ldr x9, [x19, #(1024+CSS_BG_IMAGE*8)]
    orr x21, x21, x9
    ldr x9, [x19, #(1024+CSS_BACKGROUND*8)]
    orr x21, x21, x9
    mov x22, #CSS_PAD_TOP
Lbutton_style_priority:
    add x9, x19, x22, lsl #3
    ldr x9, [x9, #1024]
    orr x21, x21, x9
    add x22, x22, #1
    cmp x22, #CSS_BORDER
    b.ls Lbutton_style_priority
    ldr x9, [x19, #(1024+CSS_RADIUS*8)]
    orr x21, x21, x9
    ldr x9, [x19, #(1024+CSS_BORDER_RIGHT*8)]
    ldr x10, [x19, #(1024+CSS_BORDER_BOTTOM*8)]
    ldr x11, [x19, #(1024+CSS_BORDER_LEFT*8)]
    orr x9, x9, x10
    orr x9, x9, x11
    orr x21, x21, x9
    mov x0, x20
    cmp x21, #0
    cset x2, eq
    MSG setBordered
    mov x0, x20
    MSG cell
    mov x22, x0
    cbz x21, Lbutton_style_clear
    ldr x9, [x19, #808]
    ldr x10, [x19, #BOX_BORDER_LEFT]
    add x9, x9, x10
    scvtf d0, x9
    ldr x9, [x19, #824]
    ldr x10, [x19, #BOX_BORDER_TOP]
    add x9, x9, x10
    scvtf d1, x9
    ldr x9, [x19, #816]
    ldr x10, [x19, #BOX_BORDER_RIGHT]
    add x9, x9, x10
    scvtf d2, x9
    ldr x9, [x19, #832]
    ldr x10, [x19, #BOX_BORDER_BOTTOM]
    add x9, x9, x10
    scvtf d3, x9
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    CLASS NSData
    add x2, sp, #144
    mov x3, #32
    MSG dataBytesLength
    mov x2, x0
    b Lbutton_style_snapshot
Lbutton_style_clear:
    mov x2, #0
Lbutton_style_snapshot:
    mov x0, x22
    ADDR x1, button_insets_key
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x20
    MSG title
    mov x22, x0
    CLASS NSMutableAttributedString
    MSG alloc
    mov x2, x22
    MSG initString
    mov x22, x0
    mov x0, x22
    MSG length
    mov x3, x0
    mov x0, x22
    mov x1, x19
    mov x2, #0
    mov x4, #1 // NODE_TEXT: font/color without paragraph geometry
    bl _mac_css_attributes
    mov x0, x20
    mov x2, x22
    MSG setAttributedTitle
    mov x0, x22
    MSG release
    mov x0, x21
    LEAVE
.section __TEXT,__cstring,cstring_literals
.globl _class_NSButtonCell
_class_NSButtonCell: .asciz "NSButtonCell"
_class_OogaboogaButtonCell: .asciz "OogaboogaButtonCell"
button_cell_name: .asciz "OogaboogaButtonCell"
button_empty: .asciz ""
button_insets_key: .asciz "OogaboogaButtonInsets"
button_rect_encoding: .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}"
button_size_encoding: .asciz "{CGSize=dd}@:"

.text
button_background_draw:
    ENTER
    mov x19, x0
    mov x20, x2
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x20
    bl _mac_background_control_paint
    CLASS NSButtonCell
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, bgCellDraw
    mov x2, x20
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _objc_msgSendSuper
    LEAVE
.section __TEXT,__cstring,cstring_literals
button_draw_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}@"
