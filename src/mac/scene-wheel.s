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
    cbz x0, Lwheel_pick_unconsumed
    ldr x0, [x0, #8]
    ldp d0, d1, [sp, #144]
    bl _mac_scene_scroll_node
    LEAVE
Lwheel_pick_unconsumed:
    mov x0, #0
    LEAVE

// Node and content deltas. Keyboard and wheel share the same chaining policy.
.globl _mac_scene_scroll_node
_mac_scene_scroll_node:
    ENTER
    stp d0, d1, [sp, #144]
    mov x19, x0
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

// Read-only document navigation. Modified events continue through NSTextView
// so native selection, accessibility, menus and responder-chain editing survive.
.globl _mac_scene_key_down
_mac_scene_key_down:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x9, _mac_scene
    cbz x9, Lscene_key_super
    mov x0, x21
    MSG sceneKeyModifiers
    mov x9, #0x1e0000              // Shift, Control, Option, Command
    tst x0, x9
    b.ne Lscene_key_super
    mov x0, x21
    MSG sceneKeyCode
    mov x22, x0
    cmp x22, #123
    b.lo Lscene_key_page
    cmp x22, #126
    b.hi Lscene_key_super
    mov x23, #40
    b Lscene_key_delta
Lscene_key_page:
    cmp x22, #116
    b.eq Lscene_key_page_delta
    cmp x22, #121
    b.eq Lscene_key_page_delta
    cmp x22, #115
    b.eq Lscene_key_edge_delta
    cmp x22, #119
    b.ne Lscene_key_super
Lscene_key_edge_delta:
    mov x23, #0x3b9a
    lsl x23, x23, #16
    b Lscene_key_delta
Lscene_key_page_delta:
    mov x0, x19
    MSG visibleRect
    fcvtzs x23, d3
    sub x23, x23, #20
    cmp x23, #40
    mov x9, #40
    csel x23, x9, x23, lt
Lscene_key_delta:
    cmp x22, #123
    b.eq Lscene_key_negative
    cmp x22, #126
    b.eq Lscene_key_negative
    cmp x22, #116
    b.eq Lscene_key_negative
    cmp x22, #115
    b.ne Lscene_key_find
Lscene_key_negative:
    neg x23, x23
Lscene_key_find:
    mov x0, x19
    MSG sceneSelectedRange
    mov x24, x0
    cmn x24, #1
    b.eq Lscene_key_super
    LOAD x9, _mac_display_list
    cbz x9, Lscene_key_super
    ldr x25, [x9]
    ldr x26, [x9, #16]
    mov x27, #0
Lscene_key_command:
    cmp x27, x25
    b.hs Lscene_key_super
    add x9, x26, x27, lsl #7
    ldr x10, [x9]
    cmp x10, #2
    b.ne Lscene_key_next
    mov x28, x9
    ldr x0, [x28, #104]
    cbz x0, Lscene_key_next
    ldp x2, x3, [x28, #56]
    mov x4, #0
    MSG atomicCharacterRange
    ldr x9, [x28, #120]
    add x0, x0, x9
    cmp x24, x0
    b.lo Lscene_key_next
    add x0, x0, x1
    cmp x24, x0
    b.hs Lscene_key_next
    mov x9, x28
    ldr x0, [x9, #8]
    cmp x22, #116
    b.eq Lscene_key_port_page
    cmp x22, #121
    b.ne Lscene_key_ready_delta
Lscene_key_port_page:
    mov x10, x0
    LOAD x11, _mac_scene
    ldr x12, [x11, #8]
    mov x13, #64
Lscene_key_page_ancestor:
    cbz x13, Lscene_key_ready_delta
    sub x13, x13, #1
    add x14, x12, x10, lsl #9
    ldr x15, [x14, #SC_OVERFLOW_Y]
    cmp x15, #2
    b.ne Lscene_key_page_parent
    ldr d0, [x14, #SC_SCROLL_MAX_Y]
    fcmp d0, #0.0
    b.le Lscene_key_page_parent
    ldr d0, [x14, #SC_H]
    fcvtzs x23, d0
    sub x23, x23, #20
    cmp x23, #1
    mov x15, #1
    csel x23, x15, x23, lt
    cmp x22, #116
    b.ne Lscene_key_ready_delta
    neg x23, x23
    b Lscene_key_ready_delta
Lscene_key_page_parent:
    cbz x10, Lscene_key_ready_delta
    ldr x10, [x14, #SC_PARENT]
    b Lscene_key_page_ancestor
Lscene_key_ready_delta:
    scvtf d1, x23
    fmov d0, xzr
    cmp x22, #123
    b.eq Lscene_key_horizontal
    cmp x22, #124
    b.ne Lscene_key_dispatch
Lscene_key_horizontal:
    fmov d0, d1
    fmov d1, xzr
Lscene_key_dispatch:
    bl _mac_scene_scroll_node
    cbnz x0, Lscene_key_done
    b Lscene_key_super
Lscene_key_next:
    add x27, x27, #1
    b Lscene_key_command
Lscene_key_super:
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    bl _objc_msgSendSuper
Lscene_key_done:
    LEAVE
