// Paint out-of-flow rectangles after normal text backgrounds, before glyphs.
// Zero-height flow bounds intentionally do not ask TextKit to paint these boxes.
.include "src/mac/mac.inc"
.text
.p2align 2
// container, retained dense record data, float count.
.globl _mac_float_painter
_mac_float_painter:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    MSG layoutManager
    mov x22, x0
    ADDR x1, _mac_float_records_key
    mov x2, x20
    mov x3, #1
    bl _objc_setAssociatedObject
    LEAVE

// Create the renderer's layout manager with its real class from the outset.
// Changing an initialized AppKit object's isa can bypass subclass-dependent
// setup and discard private concrete-class behavior on older system releases.
.globl _mac_display_manager_create
_mac_display_manager_create:
    ENTER
    ADDR x0, painter_name
    bl _objc_getClass
    cbnz x0, Lpainter_new
    CLASS NSLayoutManager
    ADDR x1, painter_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x23, x0
    ADDR x0, painter_draw_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x23
    ADDR x2, _mac_display_background
    ADDR x3, painter_encoding
    bl _class_addMethod
    ADDR x0, painter_glyph_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x23
    ADDR x2, _mac_display_glyphs
    ADDR x3, painter_encoding
    bl _class_addMethod
    mov x0, x23
    bl _objc_registerClassPair
    mov x0, x23
Lpainter_new:
    MSG new
    LEAVE

// drawBackgroundForGlyphRange:atPoint: (range x2/x3, point d0/d1).
.globl _mac_display_background_impl
_mac_display_background_impl:
    ENTER
    mov x19, x0
    mov x20, x1
    stp x2, x3, [sp, #160]
    stp d0, d1, [sp, #144]
    CLASS NSLayoutManager
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    ldp x2, x3, [sp, #160]
    ldp d0, d1, [sp, #144]
    bl _objc_msgSendSuper
    mov x0, x19
    ADDR x1, _mac_float_records_key
    bl _objc_getAssociatedObject
    MSG bytes
    cbz x0, Lpaint_done
    ldp d0, d1, [sp, #144]
    bl _mac_display_floats
    CLASS NSGraphicsContext
    MSG currentContext
    MSG CGContext
    bl _CGContextGetClipBoundingBox
    LOAD x0, _mac_display_list
    bl _mac_display_replay
    // Restore selection and inline glyph backgrounds above retained box fills.
    CLASS NSLayoutManager
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    ldp x2, x3, [sp, #160]
    ldp d0, d1, [sp, #144]
    bl _objc_msgSendSuper
Lpaint_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
painter_name: .asciz "OogaFloatLayoutManager"
painter_draw_name: .asciz "drawBackgroundForGlyphRange:atPoint:"
painter_encoding: .asciz "v@:{_NSRange=QQ}{CGPoint=dd}"

.text
.p2align 2
// Replay retained glyph/image ranges, culling against the actual damaged rect.
.globl _mac_display_glyphs_impl
_mac_display_glyphs_impl:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    add x22, x2, x3
    stp d0, d1, [sp, #144]
    LOAD x9, _mac_display_list
    cbz x9, Lglyph_full
    ldr x10, [x9, #24]
    cbnz x10, Lglyph_full
    ldr x23, [x9]
    ldr x24, [x9, #16]
    CLASS NSGraphicsContext
    MSG currentContext
    MSG CGContext
    bl _CGContextGetClipBoundingBox
    stp d0, d1, [sp, #160]
    stp d2, d3, [sp, #176]
    mov x25, #0
Lglyph_command:
    cmp x25, x23
    b.hs Lglyph_done
    add x26, x24, x25, lsl #7
    ldr x9, [x26]
    cmp x9, #2
    b.eq Lglyph_range
    cmp x9, #3
    b.ne Lglyph_next
Lglyph_range:
    ldp x9, x10, [x26, #56]
    add x10, x9, x10
    cmp x9, x21
    csel x27, x21, x9, lo
    cmp x10, x22
    csel x28, x22, x10, hi
    cmp x27, x28
    b.hs Lglyph_next
    mov x0, x26
    ldp d0, d1, [sp, #160]
    ldp d2, d3, [sp, #176]
    bl _engine_display_intersects
    cbz x0, Lglyph_next
    CLASS NSLayoutManager
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x27
    sub x3, x28, x27
    ldp d0, d1, [sp, #144]
    bl _objc_msgSendSuper
Lglyph_next:
    add x25, x25, #1
    b Lglyph_command
Lglyph_full:
    CLASS NSLayoutManager
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    sub x3, x22, x21
    ldp d0, d1, [sp, #144]
    bl _objc_msgSendSuper
Lglyph_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
painter_glyph_name: .asciz "drawGlyphsForGlyphRange:atPoint:"
