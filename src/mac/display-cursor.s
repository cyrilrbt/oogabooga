// Native cursor rectangles consume the assembly hit-region commands.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_display_cursor_install
_mac_display_cursor_install:
    ENTER
    LOAD x19, _engine_text
    mov x0, x19
    ADDR x1, _mac_display_key
    LOAD x2, _mac_display_data
    mov x3, #1
    bl _objc_setAssociatedObject
    ADDR x0, display_text_name
    bl _objc_getClass
    cbnz x0, Lcursor_class
    CLASS NSTextView
    ADDR x1, display_text_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x20, x0
    ADDR x0, display_cursor_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x20
    ADDR x2, display_cursors
    ADDR x3, display_cursor_encoding
    bl _class_addMethod
    mov x0, x20
    bl _objc_registerClassPair
    mov x0, x20
Lcursor_class:
    mov x1, x0
    mov x0, x19
    bl _object_setClass
    LEAVE

display_cursors:
    ENTER
    mov x19, x0
    mov x20, x1
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    bl _objc_msgSendSuper
    mov x0, x19
    MSG visibleRect
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x19
    ADDR x1, _mac_display_key
    bl _objc_getAssociatedObject
    MSG bytes
    cbz x0, Lcursor_done
    ldr x21, [x0]
    ldr x22, [x0, #16]
    CLASS NSCursor
    MSG pointingHandCursor
    mov x23, x0
    mov x24, #0
Lcursor_hit:
    cmp x24, x21
    b.hs Lcursor_done
    add x25, x22, x24, lsl #7
    ldr x9, [x25]
    cmp x9, #4
    b.ne Lcursor_next
    mov x0, x25
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _engine_display_intersects
    cbz x0, Lcursor_next
    mov x0, x19
    mov x2, x23
    ldp d0, d1, [x25, #16]
    ldp d2, d3, [x25, #32]
    MSG addCursorRect
Lcursor_next:
    add x24, x24, #1
    b Lcursor_hit
Lcursor_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
display_text_name: .asciz "OogaDisplayTextView"
display_cursor_name: .asciz "resetCursorRects"
display_cursor_encoding: .asciz "v@:"
