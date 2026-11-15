// Native adapter for the assembly retained display list. Native text services
// shape glyphs; command order, clipping, bounds and hit regions are ours.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _mac_display_descriptor
_mac_display_descriptor:
    ENTER
    ADDR x1, paint_descriptor_key
    bl _objc_getAssociatedObject
    MSG bytes
    LEAVE
.globl _mac_display_begin
_mac_display_begin:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #24]
    lsl x22, x21, #3
    add x22, x22, #1024
    mov x9, #32768
    cmp x22, x9
    csel x22, x9, x22, hi
    CLASS NSMutableData
    MSG new
    mov x23, x0
    lsl x2, x22, #7
    add x2, x2, #32
    MSG setLength
    mov x0, x23
    MSG mutableBytes
    mov x1, x22
    bl _engine_display_init
    STORE x0, _mac_display_list
    STORE x23, _mac_display_data
    str x21, [x0]                  // stable box slot per source node
    ldr x22, [x0, #16]
    ldr x24, [x19, #72]
    mov x25, #0
Ldisplay_slots:
    cmp x25, x21
    b.hs Ldisplay_attach
    add x9, x22, x25, lsl #7
    str x25, [x9, #8]
    add x10, x24, x25, lsl #11
    str x9, [x10, #NATIVE_DISPLAY_COMMAND]
    add x25, x25, #1
    b Ldisplay_slots
Ldisplay_attach:
    mov x0, x19
    bl _mac_scene_begin
    mov x0, x20
    ADDR x1, _mac_display_key
    mov x2, x23
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x23
    MSG release
    bl _mac_display_cursor_install
    LEAVE

// block, metadata. Compact immutable paint descriptor + retained command owner.
.globl _mac_display_bind
_mac_display_bind:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    mov x20, x1
    ldr x9, [x20, #NATIVE_DISPLAY_COMMAND]
    str x9, [sp]
    ldr x9, [x20, #40]
    str x9, [sp, #8]
    ldr x9, [x20, #200]
    str x9, [sp, #16]
    add x9, x20, #BOX_BORDER_LEFT
    ldp x10, x11, [x9]
    stp x10, x11, [sp, #24]
    ldp x10, x11, [x9, #16]
    stp x10, x11, [sp, #40]
    ldr x9, [x20, #776]
    str x9, [sp, #56]
    ldr x9, [x20, #792]
    str x9, [sp, #64]
    ldr x9, [x20, #784]
    str x9, [sp, #72]
    ldr x9, [x20, #800]
    str x9, [sp, #80]
    // Flow gaps and alignment offsets are native cell margins, not background.
    ldr x9, [x20, #FLOW_OWNER]
    cbz x9, Lbind_flow_margins_done
    ldr x9, [sp, #56]
    ldr x10, [x20, #FLOW_LEAD]
    add x9, x9, x10
    str x9, [sp, #56]
    ldr x9, [sp, #64]
    ldr x10, [x20, #FLOW_BEFORE]
    add x9, x9, x10
    str x9, [sp, #64]
    ldr x9, [sp, #72]
    ldr x10, [x20, #FLOW_TRAIL]
    add x9, x9, x10
    str x9, [sp, #72]
    ldr x9, [sp, #80]
    ldr x10, [x20, #FLOW_AFTER]
    add x9, x9, x10
    str x9, [sp, #80]
Lbind_flow_margins_done:
    ldr x9, [x20, #FLOAT_ACTIVE]
    str x9, [sp, #88]
    CLASS NSData
    mov x2, sp
    mov x3, #96
    MSG dataBytesLength
    mov x2, x0
    mov x0, x19
    ADDR x1, paint_descriptor_key
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x19
    ADDR x1, _mac_display_key
    LOAD x2, _mac_display_data
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x19
    bl _object_getClass
    mov x21, x0
    CLASS NSTextTableBlock
    cmp x0, x21
    b.ne Lbind_done
    ADDR x0, display_table_name
    bl _objc_getClass
    cbnz x0, Lbind_class_ready
    CLASS NSTextTableBlock
    ADDR x1, display_table_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x21, x0
    ADDR x0, display_box_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x21
    ADDR x2, _mac_display_box
    ADDR x3, display_box_encoding
    bl _class_addMethod
    mov x0, x21
    bl _objc_registerClassPair
    mov x0, x21
Lbind_class_ready:
    mov x1, x0
    mov x0, x19
    bl _object_setClass
Lbind_done:
    add sp, sp, #128
    LEAVE

// NSTextBlock background callback: record, don't paint out of source order.
.globl _mac_display_box
_mac_display_box:
    ENTER
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    ADDR x1, paint_descriptor_key
    bl _objc_getAssociatedObject
    MSG bytes
    cbz x0, Lbox_record_done
    ldr x9, [x0, #88]
    cmp x9, #1
    b.eq Lbox_record_done
    ldr x19, [x0]
    cbz x19, Lbox_record_done
    mov x20, x0
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    ldr x9, [x20, #56]
    scvtf d4, x9
    fadd d0, d0, d4
    ldr x10, [x20, #72]
    add x9, x9, x10
    scvtf d4, x9
    fsub d2, d2, d4
    ldr x9, [x20, #64]
    scvtf d4, x9
    fadd d1, d1, d4
    ldr x10, [x20, #80]
    add x9, x9, x10
    scvtf d4, x9
    fsub d3, d3, d4
    stp d0, d1, [x19, #16]
    stp d2, d3, [x19, #32]
    mov x9, #1
    str x9, [x19]
    ldp x9, x10, [x20, #8]
    stp x9, x10, [x19, #72]
    ldp x9, x10, [x20, #24]
    stp x9, x10, [x19, #88]
    ldp x9, x10, [x20, #40]
    stp x9, x10, [x19, #104]
Lbox_record_done:
    LEAVE

// Dense measured floats -> stable source-node box slots. Point is view inset.
.globl _mac_display_floats
_mac_display_floats:
    ENTER
    stp d0, d1, [sp, #144]
    mov x19, x0                    // float record data bytes
    cbz x19, Lfloat_commands_done
    ldr x20, [x19]
    add x19, x19, #8
    LOAD x9, _mac_display_list
    ldr x21, [x9, #16]
Lfloat_command:
    cbz x20, Lfloat_commands_done
    ldr x9, [x19, #48]
    cbz x9, Lfloat_command_next
    ldr x9, [x19, #56]
    lsr x9, x9, #8
    add x22, x21, x9, lsl #7
    ldp d0, d1, [x19, #16]
    ldp d2, d3, [x19, #32]
    ldp d4, d5, [sp, #144]
    fadd d0, d0, d4
    fadd d1, d1, d5
    ldr x9, [x19, #112]
    ubfx x10, x9, #0, #16
    scvtf d4, x10
    fadd d0, d0, d4
    ubfx x11, x9, #32, #16
    add x10, x10, x11
    scvtf d4, x10
    fsub d2, d2, d4
    ubfx x10, x9, #16, #16
    scvtf d4, x10
    fadd d1, d1, d4
    ubfx x11, x9, #48, #16
    add x10, x10, x11
    scvtf d4, x10
    fsub d3, d3, d4
    stp d0, d1, [x22, #16]
    stp d2, d3, [x22, #32]
    mov x9, #1
    str x9, [x22]
    ldp x9, x10, [x19, #64]
    stp x9, x10, [x22, #72]
    ldp x9, x10, [x19, #80]
    stp x9, x10, [x22, #88]
    ldp x9, x10, [x19, #96]
    stp x9, x10, [x22, #104]
Lfloat_command_next:
    add x19, x19, #128
    sub x20, x20, #1
    b Lfloat_command
Lfloat_commands_done:
    LEAVE

// list*, damaged view rect d0..d3. Background/border replay in source order.
.globl _mac_display_replay
_mac_display_replay:
    ENTER
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    ldr x19, [x0]
    ldr x20, [x0, #16]
    mov x21, #0
    STORE xzr, _mac_display_painted
    STORE xzr, _mac_display_culled
Lreplay_command:
    cmp x21, x19
    b.hs Lreplay_done
    add x22, x20, x21, lsl #7
    ldr x9, [x22]
    cmp x9, #1
    b.ne Lreplay_next
    mov x0, x22
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _engine_display_intersects
    cbz x0, Lreplay_cull
    LOAD x9, _mac_display_painted
    add x9, x9, #1
    STORE x9, _mac_display_painted
    ldr x0, [x22, #72]
    bl _mac_css_color
    cbz x0, Lreplay_border
    MSG setFill
    ldp d0, d1, [x22, #16]
    ldp d2, d3, [x22, #32]
    bl _NSRectFill
Lreplay_border:
    ldr x0, [x22, #80]
    bl _mac_css_color
    cbz x0, Lreplay_next
    MSG setFill
    mov x23, #0
Lreplay_edge:
    add x9, x22, #88
    ldr x9, [x9, x23, lsl #3]
    cbz x9, Lreplay_edge_next
    scvtf d4, x9
    ldp d0, d1, [x22, #16]
    ldp d2, d3, [x22, #32]
    cmp x23, #1
    b.eq Lreplay_top
    cmp x23, #2
    b.eq Lreplay_right
    cmp x23, #3
    b.eq Lreplay_bottom
    fmov d2, d4
    b Lreplay_fill
Lreplay_top:
    fmov d3, d4
    b Lreplay_fill
Lreplay_right:
    fadd d0, d0, d2
    fsub d0, d0, d4
    fmov d2, d4
    b Lreplay_fill
Lreplay_bottom:
    fadd d1, d1, d3
    fsub d1, d1, d4
    fmov d3, d4
Lreplay_fill:
    bl _NSRectFill
Lreplay_edge_next:
    add x23, x23, #1
    cmp x23, #4
    b.lo Lreplay_edge
    b Lreplay_next
Lreplay_cull:
    LOAD x9, _mac_display_culled
    add x9, x9, #1
    STORE x9, _mac_display_culled
Lreplay_next:
    add x21, x21, #1
    b Lreplay_command
Lreplay_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
paint_descriptor_key: .asciz "displayPaintDescriptor"
display_table_name: .asciz "OogaDisplayTableBlock"
display_box_name: .asciz "drawBackgroundWithFrame:inView:characterRange:layoutManager:"
display_box_encoding: .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}@{_NSRange=QQ}@"
.globl _mac_display_key
_mac_display_key: .asciz "assemblyDisplayList"
.section __DATA,__bss
.p2align 3
.globl _mac_display_list, _mac_display_data, _mac_display_painted, _mac_display_culled
_mac_display_list: .space 8
_mac_display_data: .space 8
_mac_display_painted: .space 8
_mac_display_culled: .space 8

.text
.p2align 2
// doc,layout,layout-manager,container -> glyph/image commands and link regions.
.globl _mac_display_compile
.globl _mac_display_compile_impl
_mac_display_compile_impl:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x24, #0
Lcompile_node:
    ldr x9, [x19, #24]
    cmp x24, x9
    b.hs Lcompile_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x25, x24, x10, x9
    ldr x26, [x25]
    cmp x26, #NODE_A
    b.eq Lcompile_anchor
    cmp x26, #NODE_TEXT
    b.eq Lcompile_leaf
    cmp x26, #NODE_IMG
    b.eq Lcompile_leaf
    cmp x26, #NODE_SVG
    b.eq Lcompile_leaf
    cmp x26, #NODE_INPUT
    b.eq Lcompile_leaf
    cmp x26, #NODE_SELECT
    b.eq Lcompile_leaf
    cmp x26, #NODE_TEXTAREA
    b.eq Lcompile_leaf
    cmp x26, #NODE_BUTTON
    b.ne Lcompile_next
Lcompile_leaf:
    ldr x9, [x20, #16]
    ldp x10, x11, [x25, #16]
    ldr x2, [x9, x10, lsl #3]
    ldr x3, [x9, x11, lsl #3]
    sub x3, x3, x2
    cbz x3, Lcompile_next
    mov x0, x21
    mov x4, #0
    MSG glyphRange
    cbz x1, Lcompile_next
    stp x0, x1, [sp, #144]
    LOAD x0, _mac_display_list
    bl _engine_display_append
    cbz x0, Lcompile_done
    mov x27, x0
    mov x9, #2
    cmp x26, #NODE_TEXT
    b.eq Lcompile_type
    mov x9, #3
Lcompile_type:
    str x9, [x27]
    str x24, [x27, #8]
    ldp x2, x3, [sp, #144]
    stp x2, x3, [x27, #56]
    mov x0, x21
    mov x4, x22
    MSG glyphRect
    LOAD x9, _engine_inset
    scvtf d4, x9
    fadd d0, d0, d4
    fadd d1, d1, d4
    stp d0, d1, [x27, #16]
    stp d2, d3, [x27, #32]
    b Lcompile_next
Lcompile_anchor:
    ldr x9, [x19, #72]
    add x9, x9, x24, lsl #11
    ldr x9, [x9, #872]
    cbz x9, Lcompile_link
    // Styled anchors use a native attachment instead of their hidden text leaves.
    mov x0, x20
    mov x1, x25
    mov x2, x21
    mov x3, x22
    mov x4, x24
    bl compile_anchor_image
    b Lcompile_link
Lcompile_link:
    ldr x9, [x25, #32]
    cbz x9, Lcompile_next
    ldr x9, [x20, #16]
    ldp x10, x11, [x25, #16]
    ldr x23, [x9, x10, lsl #3]
    ldr x28, [x9, x11, lsl #3]
    sub x28, x28, x23
    cbz x28, Lcompile_next
    mov x0, x21
    MSG textStorage
    adrp x9, _NSLinkAttributeName@GOTPAGE
    ldr x9, [x9, _NSLinkAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, x23
    mov x4, #0
    MSG attributeIndex
    cbz x0, Lcompile_next
    mov x0, x21
    mov x1, x22
    mov x2, x23
    mov x3, x28
    mov x4, x24
    bl compile_link_lines
Lcompile_next:
    add x24, x24, #1
    b Lcompile_node
Lcompile_done:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    bl _mac_scene_measure
    LOAD x0, _engine_text
    MSG window
    LOAD x2, _engine_text
    MSG invalidateCursorRects
    LEAVE

compile_anchor_image:
    ENTER
    mov x19, x2
    mov x20, x3
    mov x21, x4
    mov x25, x1
    ldr x9, [x0, #16]
    ldp x10, x11, [x25, #16]
    ldr x2, [x9, x10, lsl #3]
    ldr x3, [x9, x11, lsl #3]
    sub x3, x3, x2
    cbz x3, Lanchor_image_done
    mov x0, x19
    mov x4, #0
    MSG glyphRange
    stp x0, x1, [sp, #144]
    LOAD x0, _mac_display_list
    bl _engine_display_append
    cbz x0, Lanchor_image_done
    mov x22, x0
    mov x9, #3
    str x9, [x22]
    str x21, [x22, #8]
    ldp x2, x3, [sp, #144]
    stp x2, x3, [x22, #56]
    mov x0, x19
    mov x4, x20
    MSG glyphRect
    LOAD x9, _engine_inset
    scvtf d4, x9
    fadd d0, d0, d4
    fadd d1, d1, d4
    stp d0, d1, [x22, #16]
    stp d2, d3, [x22, #32]
Lanchor_image_done:
    LEAVE

// manager,container,char location,length,node. Split wrapped links by line.
compile_link_lines:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x4
    mov x4, #0
    MSG glyphRange
    mov x23, x0
    add x24, x0, x1
Llink_line:
    cmp x23, x24
    b.hs Llink_lines_done
    mov x0, x19
    mov x2, x23
    add x3, sp, #144
    MSG lineFragment
    ldp x9, x10, [sp, #144]
    add x10, x10, x9
    cmp x10, x24
    csel x25, x10, x24, lo
    cmp x25, x23
    b.ls Llink_lines_done
    LOAD x0, _mac_display_list
    bl _engine_display_append
    cbz x0, Llink_lines_done
    mov x26, x0
    mov x9, #4
    str x9, [x26]
    str x22, [x26, #8]
    str x21, [x26, #120]
    mov x0, x19
    mov x2, x23
    sub x3, x25, x23
    mov x4, x20
    MSG glyphRect
    LOAD x9, _engine_inset
    scvtf d4, x9
    fadd d0, d0, d4
    fadd d1, d1, d4
    stp d0, d1, [x26, #16]
    stp d2, d3, [x26, #32]
    mov x23, x25
    b Llink_line
Llink_lines_done:
    LEAVE
