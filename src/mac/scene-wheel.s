// Wheel chaining uses the deepest eligible scene container under the pointer.
// Positive API deltas advance content; AppKit wheel signs are adapted below.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
.globl _mac_scene_scroll_at_point
_mac_scene_scroll_at_point:
    ENTER
    stp d2, d3, [sp, #144]
    bl _mac_scene_pick
    cbz x0, Lwheel_unconsumed
    ldr x19, [x0, #8]
    LOAD x20, _mac_scene
    ldr x21, [x20, #8]
    mov x22, #64
Lwheel_ancestor:
    cbz x22, Lwheel_unconsumed
    sub x22, x22, #1
    mov x0, x20
    mov x1, x19
    ldp d0, d1, [sp, #144]
    bl _engine_scene_scroll
    cbnz x0, Lwheel_consumed
    cbz x19, Lwheel_unconsumed
    add x9, x21, x19, lsl #9
    ldr x19, [x9, #SC_PARENT]
    b Lwheel_ancestor
Lwheel_consumed:
    LOAD x0, _engine_text
    MSG visibleRect
    mov x0, x20
    bl _engine_scene_update
    bl _mac_scene_controls_update
    LOAD x0, _engine_text
    mov x2, #1
    MSG setNeedsDisplay
    LOAD x0, _engine_text
    MSG window
    LOAD x2, _engine_text
    MSG invalidateCursorRects
    mov x0, #1
    LEAVE
Lwheel_unconsumed:
    mov x0, #0
    LEAVE

.globl _mac_scene_scroll_wheel
_mac_scene_scroll_wheel:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x9, _mac_scene
    cbz x9, Lwheel_super
    mov x0, x21
    MSG eventLocation
    mov x0, x19
    mov x2, #0
    MSG convertScenePoint
    stp d0, d1, [sp, #144]
    mov x0, x21
    MSG sceneDeltaX
    fneg d0, d0
    str d0, [sp, #160]
    mov x0, x21
    MSG sceneDeltaY
    fneg d0, d0
    str d0, [sp, #168]
    mov x0, x21
    MSG scenePreciseScroll
    cbnz x0, Lwheel_dispatch
    ldp d2, d3, [sp, #160]
    mov x9, #10
    scvtf d4, x9
    fmul d2, d2, d4
    fmul d3, d3, d4
    stp d2, d3, [sp, #160]
Lwheel_dispatch:
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _mac_scene_scroll_at_point
    cbnz x0, Lwheel_done
Lwheel_super:
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    bl _objc_msgSendSuper
Lwheel_done:
    LEAVE
