// Single-line CSS fields share one padded, vertically centered rectangle for
// display and field-editor entry. Native editing/selection stays in AppKit.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_input_cell_install
_mac_input_cell_install:
    ENTER
    mov x19, x0
    CLASS OogaboogaInputCell
    cbnz x0, Linput_cell_new
    CLASS NSTextFieldCell
    ADDR x1, input_cell_class
    mov x2, #0
    bl _objc_allocateClassPair
    mov x20, x0
    SELECT x1, inputDrawingRect
    ADDR x2, input_cell_rect
    ADDR x3, input_rect_encoding
    bl _class_addMethod
    mov x0, x20
    SELECT x1, inputEditFrame
    ADDR x2, input_cell_edit
    ADDR x3, input_edit_encoding
    bl _class_addMethod
    mov x0, x20
    SELECT x1, inputSelectFrame
    ADDR x2, input_cell_select
    ADDR x3, input_select_encoding
    bl _class_addMethod
    mov x0, x20
    bl _objc_registerClassPair
    mov x0, x20
Linput_cell_new:
    MSG alloc
    mov x20, x0
    STR input_empty
    mov x2, x0
    mov x0, x20
    MSG initTextCell
    mov x20, x0
    mov x2, x0
    mov x0, x19
    MSG buttonSetCell
    mov x0, x20
    MSG release
    mov x0, x19
    mov x2, #1
    MSG setEditable
    mov x0, x19
    mov x2, #1
    MSG setSelectable
    mov x0, x20
    mov x2, #1
    MSG singleLine
    mov x0, x20
    mov x2, #1
    MSG setScrollable
    mov x0, x20
    mov x2, #0
    MSG setWraps
    mov x0, x20
    mov x2, #2
    MSG setLineBreak
    LEAVE

// cell -> mutable inset snapshot bytes, or nil.
input_cell_data:
    ENTER
    ADDR x1, input_insets_key
    bl _objc_getAssociatedObject
    MSG mutableBytes
    LEAVE

input_cell_rect:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    bl input_cell_data
    cbz x0, Linput_rect_original
    ldr x9, [x0, #32]
    cbnz x9, Linput_rect_original // super's editor path already has this rectangle
    ldp d4, d5, [x0]
    ldp d6, d7, [x0, #16]
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    fadd d0, d0, d4
    fadd d1, d1, d5
    fsub d2, d2, d4
    fsub d2, d2, d6
    fsub d3, d3, d5
    fsub d3, d3, d7
    fmov d4, xzr
    fmax d2, d2, d4
    fmax d3, d3, d4
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    CLASS NSTextFieldCell
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, buttonCellSize
    bl _objc_msgSendSuper
    ldr d3, [sp, #168]
    fmin d1, d1, d3
    fsub d3, d3, d1
    fmov d4, #0.5
    fmul d3, d3, d4
    ldr d0, [sp, #152]
    fadd d0, d0, d3
    str d0, [sp, #152]
    str d1, [sp, #168]
Linput_rect_original:
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    LEAVE

input_cell_edit:
    mov x7, #0
    b input_cell_enter_editor
input_cell_select:
    mov x7, #1
input_cell_enter_editor:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    mov x22, x4
    mov x23, x5
    mov x24, x6
    str x7, [sp, #176]
    bl input_cell_rect
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x19
    bl input_cell_data
    cbz x0, Linput_editor_super
    mov x9, #1
    str x9, [x0, #32]
Linput_editor_super:
    CLASS NSTextFieldCell
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, inputEditFrame
    ldr x9, [sp, #176]
    cbz x9, Linput_editor_selector
    SELECT x1, inputSelectFrame
Linput_editor_selector:
    mov x2, x20
    mov x3, x21
    mov x4, x22
    mov x5, x23
    mov x6, x24
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _objc_msgSendSuper
    mov x0, x19
    bl input_cell_data
    cbz x0, Linput_editor_done
    str xzr, [x0, #32]
Linput_editor_done:
    mov x0, x20
    bl _mac_input_editor_layout
    LEAVE

// metadata,field. Snapshot CSS edges; no borrowed document pointer in the cell.
.globl _mac_input_cell_style
_mac_input_cell_style:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x20
    mov x2, #0
    MSG inputSetBezeled
    mov x0, x20
    mov x2, #0
    MSG setBordered
    mov x0, x20
    mov x2, #1 // NSFocusRingTypeNone
    MSG inputFocusRing
    mov x0, x20
    mov x2, #0
    MSG setDrawsBackground
    ldr x0, [x19, #32]
    bl _mac_css_color
    mov x2, x0
    mov x0, x20
    MSG setTextColor
    mov x0, x20
    MSG cell
    mov x21, x0
    CLASS NSMutableData
    MSG new
    mov x22, x0
    mov x2, #40
    MSG setLength
    mov x0, x22
    MSG mutableBytes
    mov x23, x0
    // Default horizontal inset is 2px; explicit CSS padding (including zero)
    // takes precedence. Borders are included in the content inset once.
    mov x24, #0
Linput_inset_next:
    ADDR x9, input_edge_offsets
    ldr x10, [x9, x24, lsl #3]
    ldr x25, [x19, x10]
    ADDR x9, input_edge_props
    ldr x10, [x9, x24, lsl #3]
    add x9, x19, x10, lsl #3
    ldr x9, [x9, #1024]
    cbnz x9, Linput_inset_border
    tbnz x24, #0, Linput_inset_border
    mov x25, #2
Linput_inset_border:
    ADDR x9, input_border_offsets
    ldr x10, [x9, x24, lsl #3]
    ldr x9, [x19, x10]
    add x25, x25, x9
    scvtf d0, x25
    str d0, [x23, x24, lsl #3]
    add x24, x24, #1
    cmp x24, #4
    b.lo Linput_inset_next
    mov x0, x21
    ADDR x1, input_insets_key
    mov x2, x22
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x22
    MSG release
    LEAVE
.section __TEXT,__cstring,cstring_literals
_class_NSTextFieldCell: .asciz "NSTextFieldCell"
_class_OogaboogaInputCell: .asciz "OogaboogaInputCell"
input_cell_class: .asciz "OogaboogaInputCell"
input_empty: .asciz ""
input_insets_key: .asciz "OogaboogaInputInsets"
input_rect_encoding: .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}"
input_edit_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}@@@@"
input_select_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}@@@QQ"
.section __DATA,__const
.p2align 3
input_edge_offsets: .quad 808,824,816,832
input_edge_props: .quad CSS_PAD_LEFT,CSS_PAD_TOP,CSS_PAD_RIGHT,CSS_PAD_BOTTOM
input_border_offsets: .quad BOX_BORDER_LEFT,BOX_BORDER_TOP,BOX_BORDER_RIGHT,BOX_BORDER_BOTTOM

.text
// Keep the active editor's viewport in the CSS rectangle after NSControl's
// frame updates. Its document width may exceed the viewport for horizontal
// scrolling; preserve that width and the horizontal scroll offset.
.globl _mac_input_editor_layout
_mac_input_editor_layout:
    ENTER
    mov x19, x0
    MSG inputCurrentEditor
    cbz x0, Linput_editor_layout_done
    mov x20, x0
    MSG superview
    cbz x0, Linput_editor_layout_done
    mov x21, x0
    MSG bounds
    fmov d4, xzr
    fmax d0, d0, d4
    str d0, [sp, #176]
    mov x0, x21
    MSG superview
    mov x22, x0
    mov x0, x21
    mov x2, #1
    MSG inputFocusRing
    mov x0, x20
    mov x2, #1
    MSG inputFocusRing
    mov x0, x19
    MSG bounds
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x19
    MSG cell
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    MSG inputDrawingRect
    stp d2, d3, [sp, #184]
    mov x0, x19
    mov x2, x22
    MSG inputConvertRect
    mov x0, x21
    MSG setFrame
    mov x0, x20
    MSG frame
    ldp d4, d5, [sp, #184]
    fmax d0, d2, d4
    fmax d1, d3, d5
    mov x0, x20
    MSG setFrameSize
    mov x0, x20
    fmov d0, xzr
    fmov d1, xzr
    MSG inputFrameOrigin
    mov x0, x20
    fmov d0, xzr
    fmov d1, xzr
    MSG setTextInset
    mov x0, x20
    MSG textContainer
    fmov d0, xzr
    MSG inputLinePadding
    mov x0, x21
    ldr d0, [sp, #176]
    fmov d1, xzr
    MSG inputScrollPoint
Linput_editor_layout_done:
    LEAVE

.globl _mac_input_field_class
_mac_input_field_class:
    ENTER
    CLASS OogaboogaInputField
    cbnz x0, Linput_field_class_ready
    CLASS NSTextField
    ADDR x1, input_field_class
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    SELECT x1, setFrame
    ADDR x2, input_field_frame
    ADDR x3, input_frame_encoding
    bl _class_addMethod
    mov x0, x19
    SELECT x1, setFrameSize
    ADDR x2, input_field_size
    ADDR x3, input_size_encoding
    bl _class_addMethod
    mov x0, x19
    SELECT x1, liveBecome
    ADDR x2, input_live_focus
    ADDR x3, live_focus_encoding
    bl _class_addMethod
    mov x0, x19
    SELECT x1, liveResign
    ADDR x2, input_live_focus
    ADDR x3, live_focus_encoding
    bl _class_addMethod
    mov x0, x19
    bl _objc_registerClassPair
    mov x0, x19
Linput_field_class_ready:
    LEAVE
input_field_frame:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    CLASS NSTextField
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, setFrame
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _objc_msgSendSuper
    mov x0, x19
    bl _mac_input_editor_layout
    LEAVE
input_field_size:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    CLASS NSTextField
    stp x19, x0, [sp]
    mov x0, sp
    SELECT x1, setFrameSize
    ldp d0, d1, [sp, #144]
    bl _objc_msgSendSuper
    mov x0, x19
    bl _mac_input_editor_layout
    LEAVE
.section __TEXT,__cstring,cstring_literals
_class_OogaboogaInputField: .asciz "OogaboogaInputField"
input_field_class: .asciz "OogaboogaInputField"
input_frame_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
input_size_encoding: .asciz "v@:{CGSize=dd}"

.text
input_live_focus:
    ENTER
    mov x19, x0
    mov x20, x1
    CLASS NSTextField
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    bl _objc_msgSendSuper
    mov x19, x0
    bl _mac_state_schedule
    mov x0, x19
    LEAVE
.section __TEXT,__cstring,cstring_literals
live_become_name: .asciz "becomeFirstResponder"
live_resign_name: .asciz "resignFirstResponder"
live_focus_encoding: .asciz "B@:"
.section __DATA,__data
.p2align 3
.globl _sel_liveBecome,_sel_liveResign
_sel_liveBecome: .quad live_become_name
_sel_liveResign: .quad live_resign_name
