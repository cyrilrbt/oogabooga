// Native shaping adapter for the assembly scene. The retained display data owns
// the scene allocation, so metadata snapshots held by blocks cannot outlive it.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
// doc -> attach an optional scene to the current display owner.
.globl _mac_scene_begin
_mac_scene_begin:
    ENTER
    LOAD x25, _mac_scene
    STORE xzr, _mac_scene
    STORE xzr, _mac_scene_anchor
    mov x19, x0
    ldr x20, [x19, #72]
    ldr x21, [x19, #24]
    ldr x0, [x19, #56]
    cbz x0, Lscene_needed_start
    ADDR x1, scene_hover_token
    bl _strcasestr
    cbnz x0, Lscene_allocate
    ldr x0, [x19, #56]
    ADDR x1, scene_active_token
    bl _strcasestr
    cbnz x0, Lscene_allocate
    ldr x0, [x19, #56]
    ADDR x1, scene_focus_token
    bl _strcasestr
    cbnz x0, Lscene_allocate
Lscene_needed_start:
    mov x22, #1
Lscene_needed:
    cmp x22, x21
    b.hs Lscene_begin_done
    add x9, x20, x22, lsl #11
    ldr x10, [x9, #696]
    cbnz x10, Lscene_needed_next
    ldr x10, [x9, #(32+CSS_BG_IMAGE*8)]
    cbnz x10, Lscene_allocate
    ldr x10, [x9, #88]
    cmp x10, #2
    b.ne Lscene_needed_atomic
    ldr x11, [x9, #40]
    cmn x11, #1
    b.ne Lscene_allocate
    ldr x11, [x9, #192]
    cbnz x11, Lscene_allocate
Lscene_needed_atomic:
    cmp x10, #5
    b.eq Lscene_allocate
    ldr x10, [x9, #(1840+(CSS_POSITION-48)*8)]
    ldr x11, [x9, #(1840+(CSS_OVERFLOW_X-48)*8)]
    orr x10, x10, x11
    ldr x11, [x9, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    orr x10, x10, x11
    cbnz x10, Lscene_allocate
    ldr x10, [x9, #(32+CSS_OPACITY*8)]
    cmp x10, #1000
    b.lo Lscene_allocate
Lscene_needed_next:
    add x22, x22, #1
    b Lscene_needed
Lscene_allocate:
    mov x0, x19
    LOAD x1, _engine_viewport
    ldr x2, [x20, #BOX_HEIGHT]
    cmp x2, #1
    mov x9, #1
    csel x2, x9, x2, lt
    bl _engine_scene_new
    cbz x0, Lscene_begin_done
    mov x23, x0
    mov x1, x25
    bl _engine_scene_copy_scroll
    CLASS NSData
    MSG alloc
    mov x2, x23
    mov x9, #528
    mul x3, x21, x9
    mov x9, #0x60
    movk x9, #9, lsl #16
    add x3, x3, x9
    mov x4, #1
    MSG initOwnedBytes
    cbz x0, Lscene_begin_failed
    mov x24, x0
    LOAD x0, _mac_display_data
    ADDR x1, scene_owner_key
    mov x2, x24
    mov x3, #1
    bl _objc_setAssociatedObject
    STORE x23, _mac_scene
    mov x0, x24
    MSG release
    b Lscene_begin_done
Lscene_begin_failed:
    mov x0, x23
    bl _engine_scene_free
Lscene_begin_done:
    LEAVE

// doc,UTF16 layout,manager,container. Measure all source boxes, including fixed
// boxes whose original flow location lies outside the visible glyph range.
.globl _mac_scene_measure
_mac_scene_measure:
    ENTER
    sub sp, sp, #64
    LOAD x9, _mac_scene
    cbz x9, Lscene_measure_done
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    LOAD x0, _mac_float_records
    MSG bytes
    LOAD x9, _engine_inset
    scvtf d0, x9
    fmov d1, d0
    bl _mac_display_floats
    mov x23, #1
Lscene_measure_node:
    ldr x9, [x19, #24]
    cmp x23, x9
    b.hs Lscene_measure_finish
    ldr x9, [x19, #16]
    mov x10, #40
    madd x24, x23, x10, x9
    ldr x9, [x20, #16]
    ldp x10, x11, [x24, #16]
    ldr x25, [x9, x10, lsl #3]
    ldr x26, [x9, x11, lsl #3]
    cmp x26, x25
    b.ls Lscene_measure_next
    mov x0, x19
    mov x1, x23
    mov x2, x25
    bl _mac_atomic_node_target
    mov x21, x0
    mov x22, x1
    stp d0, d1, [sp, #32]
    sub x26, x26, x3
    mov x25, x2
    mov x0, x21
    MSG textStorage
    MSG length
    cmp x26, x0
    csel x26, x0, x26, hi
    cmp x25, x26
    b.hs Lscene_measure_next
    mov x0, x21
    mov x2, x25
    sub x3, x26, x25
    mov x4, #0
    MSG glyphRange
    str x0, [sp]                    // glyph index for native block query
    stp x0, x1, [sp, #8]
    mov x0, x21
    MSG textStorage
    adrp x9, _NSParagraphStyleAttributeName@GOTPAGE
    ldr x9, [x9, _NSParagraphStyleAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, x25
    mov x4, #0
    MSG attributeIndex
    MSG textBlocks
    mov x27, x0
    MSG count
    mov x28, x0
Lscene_measure_block:
    cbz x28, Lscene_measure_geometry
    sub x28, x28, #1
    mov x0, x27
    mov x2, x28
    MSG objectAtIndex
    str x0, [sp, #24]
    bl _mac_display_descriptor
    cbz x0, Lscene_measure_block
    ldr x9, [x0]
    ldr x10, [x19, #72]
    add x10, x10, x23, lsl #11
    ldr x10, [x10, #NATIVE_DISPLAY_COMMAND]
    cmp x9, x10
    b.ne Lscene_measure_block
    mov x0, x21
    ldr x2, [sp, #24]
    ldr x3, [sp]
    mov x4, #0
    MSG sceneBlockBounds
    ldp d4, d5, [sp, #32]
    fadd d0, d0, d4
    fadd d1, d1, d5
    ldr x0, [sp, #24]
    bl _mac_display_box
    b Lscene_measure_geometry
Lscene_measure_geometry:
    ldr x9, [x19, #72]
    add x9, x9, x23, lsl #11
    ldr x9, [x9, #NATIVE_DISPLAY_COMMAND]
    ldr x10, [x9]
    cmp x10, #1
    b.ne Lscene_measure_glyphs
    ldp d0, d1, [x9, #16]
    ldp d2, d3, [x9, #32]
    b Lscene_measure_set
Lscene_measure_glyphs:
    mov x0, x21
    ldp x2, x3, [sp, #8]
    mov x4, x22
    MSG glyphRect
    ldp d4, d5, [sp, #32]
    fadd d0, d0, d4
    fadd d1, d1, d5
    // Unboxed block ancestors still supply a full containing width for relative
    // percentages. Inline ancestors retain the measured inline glyph width.
    ldr x9, [x19, #72]
    add x9, x9, x23, lsl #11
    ldr x10, [x9, #88]
    cmp x10, #2
    b.eq Lscene_measure_set
    cmp x10, #5
    b.eq Lscene_measure_set
    ldr x10, [x24]
    cmp x10, #NODE_TEXT
    b.eq Lscene_measure_set
    cmp x10, #NODE_INPUT
    b.eq Lscene_measure_set
    cmp x10, #NODE_IMG
    b.eq Lscene_measure_set
    cmp x10, #NODE_BUTTON
    b.eq Lscene_measure_set
    cmp x10, #NODE_SELECT
    b.eq Lscene_measure_set
    cmp x10, #NODE_TEXTAREA
    b.eq Lscene_measure_set
    cmp x10, #NODE_SVG
    b.eq Lscene_measure_set
    ldr x10, [x9, #768]
    scvtf d4, x10
    fmax d2, d2, d4
Lscene_measure_set:
    LOAD x0, _mac_scene
    mov x1, x23
    bl _engine_scene_set_box
Lscene_measure_next:
    add x23, x23, #1
    b Lscene_measure_node
Lscene_measure_finish:
    LOAD x0, _mac_scene
    ldr x9, [x0, #32]
    scvtf d2, x9
    ldr x9, [x0, #40]
    scvtf d3, x9
    fmov d0, xzr
    fmov d1, xzr
    mov x1, #0
    bl _engine_scene_set_box
    LOAD x0, _mac_scene
    LOAD x1, _mac_display_list
    bl _engine_scene_order
    LOAD x0, _engine_text
    MSG visibleRect
    LOAD x0, _mac_scene
    bl _engine_scene_update
    LOAD x0, _mac_scene
    bl _engine_scene_extents
    LOAD x0, _engine_text
    MSG visibleRect
    LOAD x0, _mac_scene
    bl _engine_scene_update
Lscene_measure_done:
    add sp, sp, #64
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _mac_scene
_mac_scene: .space 8
.section __TEXT,__cstring,cstring_literals
scene_owner_key: .asciz "assemblySceneOwner"

.section __TEXT,__cstring,cstring_literals
scene_hover_token: .asciz ":hover"
scene_active_token: .asciz ":active"
scene_focus_token: .asciz ":focus"
