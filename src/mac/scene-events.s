// Mouse interaction consumes exactly the transformed/clipped scene used to draw.
// Native text services convert logical UTF-16 selection indices to glyphs.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
// view point -> topmost display command, or nil.
.globl _mac_scene_pick
_mac_scene_pick:
    ENTER
    stp d0, d1, [sp, #144]
    LOAD x0, _engine_text
    MSG visibleRect
    LOAD x0, _mac_scene
    cbz x0, Lscene_pick_none
    bl _engine_scene_update
    LOAD x0, _mac_scene
    LOAD x1, _mac_display_list
    ldp d0, d1, [sp, #144]
    bl _engine_scene_hit
    LEAVE
Lscene_pick_none:
    mov x0, #0
    LEAVE

// command -> HTTP(S) anchor URL, or nil. A topmost non-link command occludes
// links below it; never ask the legacy text view to click through that command.
.globl _mac_scene_command_link
_mac_scene_command_link:
    ENTER
    cbz x0, Lscene_link_none
    ldr x19, [x0, #8]
    LOAD x20, _engine_render_document
    cbz x20, Lscene_link_none
    mov x21, #64
Lscene_link_ancestor:
    cbz x21, Lscene_link_none
    sub x21, x21, #1
    ldr x9, [x20, #24]
    cmp x19, x9
    b.hs Lscene_link_none
    ldr x9, [x20, #16]
    mov x10, #40
    madd x9, x19, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_A
    b.eq Lscene_link_found
    ldr x19, [x9, #8]
    tbnz x19, #63, Lscene_link_none
    b Lscene_link_ancestor
Lscene_link_found:
    ldr x0, [x9, #32]
    cbz x0, Lscene_link_none
    bl _mac_string
    mov x19, x0
    CLASS NSURL
    mov x2, x19
    LOAD x3, _engine_render_base
    MSG relativeURL
    MSG absoluteURL
    mov x19, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz x0, Lscene_link_none
    mov x0, x19
    LEAVE
Lscene_link_none:
    mov x0, #0
    LEAVE

// Public test/debug adapter: view point -> topmost permitted anchor URL.
.globl _mac_scene_link_at_point
_mac_scene_link_at_point:
    ENTER
    bl _mac_scene_pick
    bl _mac_scene_command_link
    LEAVE

// command, actual view point -> logical UTF-16 insertion index.
scene_character_index:
    ENTER
    mov x19, x0
    ldr x9, [x0, #8]
    LOAD x10, _mac_scene
    ldr x10, [x10, #8]
    add x10, x10, x9, lsl #9
    ldp d2, d3, [x10, #SC_TX]
    fsub d0, d0, d2
    fsub d1, d1, d3
    stp d0, d1, [sp, #144]
    ldr x9, [x19]
    cmp x9, #2
    b.lo Lcharacter_main
    cmp x9, #4
    b.hi Lcharacter_main
    ldr x20, [x19, #104]
    cbz x20, Lcharacter_main
    ldp d0, d1, [x19, #88]
    ldr x22, [x19, #120]
    cmp x9, #4
    b.ne Lcharacter_context
    ldr x22, [x19, #112]
    b Lcharacter_context
Lcharacter_main:
    LOAD x0, _engine_text
    MSG layoutManager
    mov x20, x0
    LOAD x9, _engine_inset
    scvtf d0, x9
    fmov d1, d0
    mov x22, #0
Lcharacter_context:
    ldp d2, d3, [sp, #144]
    fsub d2, d2, d0
    fsub d3, d3, d1
    stp d2, d3, [sp, #144]
    mov x0, x20
    MSG textContainers
    mov x2, #0
    MSG objectAtIndex
    mov x2, x0
    mov x0, x20
    mov x3, #0
    ldp d0, d1, [sp, #144]
    MSG sceneCharacterIndex
    add x19, x0, x22
    LOAD x0, _engine_text
    MSG string
    MSG length
    cmp x19, x0
    csel x0, x0, x19, hi
    LEAVE

// receiver,SEL,event -> normal view coordinates d0/d1.
scene_event_point:
    ENTER
    mov x19, x0
    mov x0, x2
    MSG eventLocation
    mov x0, x19
    mov x2, #0
    MSG convertScenePoint
    LEAVE

.globl _mac_scene_mouse_down
_mac_scene_mouse_down:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x9, _mac_scene
    cbz x9, Lscene_mouse_super
    STORE xzr, _mac_scene_anchor
    bl scene_event_point
    stp d0, d1, [sp, #144]
    bl _mac_scene_pick
    cbz x0, Lscene_mouse_done
    mov x22, x0
    ldr x1, [x22, #8]
    LOAD x0, _engine_render_document
    mov x2, #3
    mov x3, #3
    bl _engine_interaction_set
    cbz x0, Lscene_down_state_ready
    bl _mac_state_schedule
Lscene_down_state_ready:
    ldr x0, [x22, #8]
    ADDR x1, _mac_js_click_name
    bl _mac_js_event_node
    cbnz x0, Lscene_mouse_done
    ldp d0, d1, [sp, #144]
    bl _mac_scene_pick
    cbz x0, Lscene_mouse_done
    mov x22, x0
    mov x0, x22
    bl _mac_scene_command_link
    cbz x0, Lscene_mouse_select
    bl _mac_engine_open_url
    b Lscene_mouse_done
Lscene_mouse_select:
    mov x0, x19
    MSG window
    mov x2, x19
    MSG makeFirstResponder
    mov x0, x22
    ldp d0, d1, [sp, #144]
    bl scene_character_index
    mov x22, x0
    add x9, x0, #1
    STORE x9, _mac_scene_anchor
    mov x0, x19
    mov x2, x22
    mov x3, #0
    MSG setSceneSelectedRange
    mov x0, x21
    MSG eventClickCount
    cmp x0, #2
    b.ne Lscene_mouse_done
    mov x0, x19
    mov x2, #0
    MSG sceneSelectWord
    b Lscene_mouse_done
Lscene_mouse_super:
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    bl _objc_msgSendSuper
Lscene_mouse_done:
    LEAVE

.globl _mac_scene_mouse_dragged
_mac_scene_mouse_dragged:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x9, _mac_scene
    cbz x9, Lscene_drag_super
    LOAD x22, _mac_scene_anchor
    cbz x22, Lscene_drag_done
    sub x22, x22, #1
    bl scene_event_point
    stp d0, d1, [sp, #144]
    bl _mac_scene_pick
    cbz x0, Lscene_drag_done
    ldp d0, d1, [sp, #144]
    bl scene_character_index
    cmp x0, x22
    csel x2, x0, x22, lo
    csel x3, x22, x0, lo
    sub x3, x3, x2
    mov x0, x19
    MSG setSceneSelectedRange
    b Lscene_drag_done
Lscene_drag_super:
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    bl _objc_msgSendSuper
Lscene_drag_done:
    LEAVE

.globl _mac_scene_mouse_up
_mac_scene_mouse_up:
    LOAD x9, _mac_scene
    cbz x9, Lscene_up_legacy
    STORE xzr, _mac_scene_anchor
    ENTER
    LOAD x0, _engine_render_document
    mov x1, #0
    mov x2, #2
    mov x3, #0
    bl _engine_interaction_set
    cbz x0, Lscene_up_state_done
    bl _mac_state_schedule
Lscene_up_state_done:
    LEAVE
Lscene_up_legacy:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    bl _objc_msgSendSuper
    LEAVE

.globl _mac_scene_cursor_update
_mac_scene_cursor_update:
    ENTER
    LOAD x9, _mac_scene
    cbnz x9, Lscene_cursor_active
    mov x19, x0
    mov x20, x1
    mov x21, x2
    CLASS NSTextView
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    bl _objc_msgSendSuper
    LEAVE
Lscene_cursor_active:
    bl scene_event_point
    bl _mac_scene_pick
    mov x19, x0
    mov x1, #0
    cbz x19, Lscene_hover_set
    ldr x1, [x19, #8]
Lscene_hover_set:
    LOAD x0, _engine_render_document
    mov x2, #1
    mov x3, #1
    cbnz x19, Lscene_hover_apply
    mov x3, #0
Lscene_hover_apply:
    bl _engine_interaction_set
    cbz x0, Lscene_hover_ready
    bl _mac_hover_schedule
Lscene_hover_ready:
    mov x0, x19
    bl _mac_scene_command_link
    cbz x0, Lscene_cursor_plain
    CLASS NSCursor
    MSG pointingHandCursor
    b Lscene_cursor_set
Lscene_cursor_plain:
    cbz x19, Lscene_cursor_arrow
    ldr x9, [x19]
    cmp x9, #2
    b.ne Lscene_cursor_arrow
    CLASS NSCursor
    MSG IBeamCursor
    b Lscene_cursor_set
Lscene_cursor_arrow:
    CLASS NSCursor
    MSG arrowCursor
Lscene_cursor_set:
    MSG cursorSet
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _mac_scene_anchor
_mac_scene_anchor: .space 8

.text
.p2align 2
// Register rectangles in scene paint order, including non-link occluders.
.globl _mac_scene_cursors
_mac_scene_cursors:
    ENTER
    mov x19, x0
    MSG visibleRect
    LOAD x0, _mac_scene
    bl _engine_scene_update
    LOAD x20, _mac_scene
    LOAD x21, _mac_display_list
    ldr x22, [x20, #24]
    ldr x25, [x20, #16]
    ldr x26, [x21, #16]
    mov x23, #0
Lscene_cursor_rect:
    cmp x23, x22
    b.hs Lscene_cursor_rects_done
    ldr x9, [x25, x23, lsl #3]
    add x24, x26, x9, lsl #7
    ldr x9, [x24]
    cmp x9, #1
    b.lo Lscene_cursor_rect_next
    cmp x9, #4
    b.hi Lscene_cursor_rect_next
    mov x0, x20
    ldr x1, [x24, #8]
    add x2, sp, #144
    cmp x9, #1
    cset x3, eq
    ldp d0, d1, [x24, #16]
    ldp d2, d3, [x24, #32]
    bl _engine_scene_rect
    cbz x0, Lscene_cursor_rect_next
    mov x0, x24
    bl _mac_scene_command_link
    cbz x0, Lscene_cursor_rect_plain
    CLASS NSCursor
    MSG pointingHandCursor
    b Lscene_cursor_rect_add
Lscene_cursor_rect_plain:
    ldr x9, [x24]
    cmp x9, #2
    b.ne Lscene_cursor_rect_arrow
    CLASS NSCursor
    MSG IBeamCursor
    b Lscene_cursor_rect_add
Lscene_cursor_rect_arrow:
    CLASS NSCursor
    MSG arrowCursor
Lscene_cursor_rect_add:
    mov x2, x0
    mov x0, x19
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    MSG addCursorRect
Lscene_cursor_rect_next:
    add x23, x23, #1
    b Lscene_cursor_rect
Lscene_cursor_rects_done:
    LEAVE
