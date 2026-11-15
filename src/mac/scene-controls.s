// Native widgets keep their full dimensions inside a flipped clipping host.
// Scene transforms move the host; clipping never changes the editor/font size.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
// control,node,untransformed frame d0..d3.
.globl _mac_scene_control_place
_mac_scene_control_place:
    ENTER
    LOAD x9, _mac_scene
    ldr x9, [x9, #8]
    add x19, x9, x1, lsl #9
    str x0, [x19, #SC_CONTROL]
    stp d0, d1, [x19, #SC_CONTROL_RECT]
    stp d2, d3, [x19, #(SC_CONTROL_RECT+16)]
    // Hidden out-of-flow attachment glyphs can have no native text box. The
    // widget's actual untransformed frame is authoritative for scene insets.
    LOAD x0, _mac_scene
    bl _engine_scene_set_box
    LEAVE

// Recompute transforms once after all widget boxes have been registered. This
// keeps form layout linear rather than walking the scene once per control.
.globl _mac_scene_controls_commit
_mac_scene_controls_commit:
    ENTER
    LOAD x0, _mac_scene
    cbz x0, Lscene_controls_commit_done
    LOAD x0, _engine_text
    MSG visibleRect
    LOAD x0, _mac_scene
    bl _engine_scene_update
    LOAD x0, _mac_scene
    bl _engine_scene_extents
    bl _mac_scene_controls_update
Lscene_controls_commit_done:
    LEAVE

// Reposition fixed/contained-scroll widgets after updating the scene, without
// recreating controls or touching the field editor, live value or selection.
.globl _mac_scene_controls_update
_mac_scene_controls_update:
    ENTER
    LOAD x19, _mac_scene
    cbz x19, Lscene_controls_done
    ldr x20, [x19]
    ldr x21, [x19, #8]
    mov x22, #0
Lscene_controls_next:
    cmp x22, x20
    b.hs Lscene_controls_done
    add x0, x21, x22, lsl #9
    ldr x9, [x0, #SC_CONTROL]
    cbz x9, Lscene_controls_advance
    bl scene_control_update
Lscene_controls_advance:
    add x22, x22, #1
    b Lscene_controls_next
Lscene_controls_done:
    LEAVE

scene_control_update:
    ENTER
    sub sp, sp, #64
    mov x19, x0
    ldr x20, [x19, #SC_CONTROL]
    mov x0, x20
    ADDR x1, scene_control_host_key
    bl _objc_getAssociatedObject
    mov x21, x0
    cbnz x21, Lscene_control_host_ready
    ADDR x0, scene_host_class
    bl _objc_getClass
    cbnz x0, Lscene_control_host_class
    CLASS NSView
    ADDR x1, scene_host_class
    mov x2, #0
    bl _objc_allocateClassPair
    mov x22, x0
    ADDR x0, scene_flipped_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x22
    ADDR x2, scene_host_flipped
    ADDR x3, scene_flipped_encoding
    bl _class_addMethod
    mov x0, x22
    bl _objc_registerClassPair
    mov x0, x22
Lscene_control_host_class:
    MSG alloc
    RECT 0, 0, 0, 0
    MSG initFrame
    mov x21, x0
    mov x2, #1
    MSG setWantsLayer
    mov x0, x21
    MSG layer
    mov x2, #1
    MSG sceneMasksBounds
    mov x0, x20
    MSG superview
    mov x22, x0
    mov x0, x21
    mov x2, x20
    MSG addSubview
    LOAD x0, _engine_text
    mov x2, x21
    MSG addSubview
    LOAD x9, _engine_text
    cmp x22, x9
    b.eq Lscene_control_parent_clean
    mov x0, x22
    MSG removeFromSuperview          // obsolete radio wrapper, if present
Lscene_control_parent_clean:
    mov x0, x20
    ADDR x1, scene_control_host_key
    mov x2, x21
    mov x3, #0                      // assign: parent owns host, host owns control
    bl _objc_setAssociatedObject
    mov x0, x21
    MSG release
Lscene_control_host_ready:
    str x21, [x19, #SC_CONTROL_HOST]
    LOAD x0, _mac_scene
    ldr x9, [x0, #8]
    sub x1, x19, x9
    lsr x1, x1, #9
    mov x2, sp
    mov x3, #0
    ldp d0, d1, [x19, #SC_CONTROL_RECT]
    ldp d2, d3, [x19, #(SC_CONTROL_RECT+16)]
    bl _engine_scene_rect
    cmp x0, #0
    cset x2, eq
    mov x0, x21
    MSG setHidden
    mov x0, x21
    ldp d0, d1, [sp]
    ldp d2, d3, [sp, #16]
    MSG setFrame
    ldp d0, d1, [x19, #SC_CONTROL_RECT]
    ldp d2, d3, [x19, #(SC_CONTROL_RECT+16)]
    ldp d4, d5, [x19, #SC_TX]
    fadd d0, d0, d4
    fadd d1, d1, d5
    ldp d4, d5, [sp]
    fsub d0, d0, d4
    fsub d1, d1, d5
    mov x0, x20
    MSG setFrame
    // Native widgets compose opacity through their host; retain the same
    // hierarchy for radio grouping, clipping, focus and accessibility.
    mov x22, x19
    mov x23, #1000
    mov x24, #64
Lscene_control_opacity:
    cbz x24, Lscene_control_alpha
    sub x24, x24, #1
    ldr x9, [x22, #SC_OPACITY]
    mul x23, x23, x9
    mov x10, #1000
    udiv x23, x23, x10
    LOAD x9, _mac_scene
    ldr x9, [x9, #8]
    cmp x22, x9
    b.eq Lscene_control_alpha
    ldr x10, [x22, #SC_PARENT]
    add x22, x9, x10, lsl #9
    b Lscene_control_opacity
Lscene_control_alpha:
    mov x0, x21
    scvtf d0, x23
    mov x9, #1000
    scvtf d1, x9
    fdiv d0, d0, d1
    MSG sceneAlpha
    add sp, sp, #64
    LEAVE

.globl _mac_scene_control_detach
_mac_scene_control_detach:
    ENTER
    mov x19, x0
    ADDR x1, scene_control_host_key
    bl _objc_getAssociatedObject
    cbz x0, Lscene_detach_done
    mov x20, x0
    mov x0, x19
    MSG removeFromSuperview
    mov x0, x20
    MSG removeFromSuperview
    mov x0, x19
    ADDR x1, scene_control_host_key
    mov x2, #0
    mov x3, #0
    bl _objc_setAssociatedObject
Lscene_detach_done:
    LEAVE

.globl _mac_scene_control_hide
_mac_scene_control_hide:
    ENTER
    ADDR x1, scene_control_host_key
    bl _objc_getAssociatedObject
    mov x2, #1
    MSG setHidden
    LEAVE
scene_host_flipped:
    mov x0, #1
    ret
.section __TEXT,__cstring,cstring_literals
scene_host_class: .asciz "OogaSceneControlHost"
scene_flipped_name: .asciz "isFlipped"
scene_flipped_encoding: .asciz "B@:"
scene_control_host_key: .asciz "assemblyControlClipHost"
