// Resolve source characters to their shaping context and view-space origin.
// Paint, hit testing and native controls use this same adapter.
.include "src/mac/mac.inc"
.include "src/mac/atomic.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// Global UTF-16 index -> manager,container,local index,global base in x0..x3;
// view-space content origin d0/d1. Native contexts own their original strings.
.globl _mac_atomic_target
_mac_atomic_target:
    mov x1, #-1                   // descend to the innermost source context
    b _mac_atomic_target_scope
.globl _mac_atomic_node_target
_mac_atomic_node_target:
    ENTER
    mov x19, x2
    bl _engine_inline_owner
    mov x1, x0
    mov x0, x19
    bl _mac_atomic_target_scope
    LEAVE
_mac_atomic_target_scope:
    ENTER
    mov x23, x1
    mov x19, x0
    mov x20, #0
    LOAD x0, _engine_text
    MSG layoutManager
    mov x21, x0
    LOAD x9, _engine_inset
    scvtf d0, x9
    stp d0, d0, [sp, #144]
    mov x22, #64
    cbz x23, Lat_target_result
Lat_target_descend:
    cbz x22, Lat_target_result
    sub x22, x22, #1
    mov x0, x21
    sub x1, x19, x20
    bl _mac_atomic_lookup
    cbz x0, Lat_target_result
    ldr x20, [x0, #AT_SOURCE_BASE]
    cmp x19, x20
    csel x19, x20, x19, lo
    ldp d0, d1, [x0, #AT_X]
    stp d0, d1, [sp, #144]
    ldr x21, [x0, #AT_MANAGER]
    ldr x9, [x0, #AT_NODE]
    add x9, x9, #1
    cmp x9, x23
    b.eq Lat_target_result
    b Lat_target_descend
Lat_target_result:
    mov x0, x21
    MSG textContainers
    mov x2, #0
    MSG objectAtIndex
    mov x1, x0
    mov x0, x21
    sub x2, x19, x20
    mov x3, x20
    ldp d0, d1, [sp, #144]
    LEAVE

// Manager and view-space content origin d0/d1. Called after layout and before
// compiling retained commands, so nested origins are stable for the whole pass.
.globl _mac_atomic_place
_mac_atomic_place:
    ENTER
    mov x19, x0
    stp d0, d1, [sp, #144]
    bl _mac_atomic_data
    cbz x0, Lat_place_done
    ldr x20, [x0]
    add x21, x0, #AT_HEADER
Lat_place_record:
    cbz x20, Lat_place_done
    mov x0, x19
    ldr x2, [x21, #AT_START]
    mov x3, #1
    mov x4, #0
    MSG glyphRange
    mov x22, x0
    mov x0, x19
    mov x2, x22
    mov x3, #0
    MSG lineFragment
    stp d0, d1, [sp, #160]
    mov x0, x19
    mov x2, x22
    MSG glyphLocation
    ldp d2, d3, [sp, #160]
    fadd d0, d0, d2
    fadd d1, d1, d3
    ldp d2, d3, [sp, #144]
    fadd d0, d0, d2
    fadd d1, d1, d3
    ldr d2, [x21, #AT_BASELINE]
    fsub d1, d1, d2
    stp d0, d1, [sp, #176]          // margin-box origin
    add x23, x21, #AT_META
    ldr x9, [x23, #776]
    scvtf d2, x9
    fadd d0, d0, d2
    ldr x9, [x23, #792]
    scvtf d2, x9
    fadd d1, d1, d2
    stp d0, d1, [sp, #192]          // border-box origin
    ldr d2, [x21, #AT_WIDTH]
    ldr d3, [x21, #AT_HEIGHT]
    ldr x9, [x23, #776]
    ldr x10, [x23, #784]
    add x9, x9, x10
    scvtf d4, x9
    fsub d2, d2, d4
    ldr x9, [x23, #792]
    ldr x10, [x23, #800]
    add x9, x9, x10
    scvtf d4, x9
    fsub d3, d3, d4
    ldr x24, [x23, #NATIVE_DISPLAY_COMMAND]
    cbz x24, Lat_place_content
    mov x9, #1
    str x9, [x24]
    stp d0, d1, [x24, #16]
    stp d2, d3, [x24, #32]
    ldr x9, [x23, #40]
    str x9, [x24, #72]
    ldr x9, [x23, #200]
    str x9, [x24, #80]
    ldr x9, [x23, #BOX_BORDER_LEFT]
    str x9, [x24, #88]
    ldr x9, [x23, #BOX_BORDER_TOP]
    str x9, [x24, #96]
    ldr x9, [x23, #BOX_BORDER_RIGHT]
    str x9, [x24, #104]
    ldr x9, [x23, #BOX_BORDER_BOTTOM]
    str x9, [x24, #112]
Lat_place_content:
    ldp d0, d1, [sp, #192]
    ldr x9, [x23, #808]
    ldr x10, [x23, #BOX_BORDER_LEFT]
    add x9, x9, x10
    scvtf d2, x9
    fadd d0, d0, d2
    ldr x9, [x23, #824]
    ldr x10, [x23, #BOX_BORDER_TOP]
    add x9, x9, x10
    scvtf d2, x9
    fadd d1, d1, d2
    stp d0, d1, [x21, #AT_X]
    ldr x0, [x21, #AT_MANAGER]
    bl _mac_atomic_place
    add x21, x21, #AT_STRIDE
    sub x20, x20, #1
    b Lat_place_record
Lat_place_done:
    LEAVE

// C/native adapter helpers for source-range geometry in view coordinates.
.globl _mac_atomic_text_rect
_mac_atomic_text_rect:
    ENTER
    mov x19, x1
    bl _mac_atomic_target
    mov x20, x0
    mov x21, x1
    stp d0, d1, [sp, #144]
    mov x3, x19
    mov x4, #0
    MSG glyphRange
    mov x2, x0
    mov x3, x1
    mov x0, x20
    mov x4, x21
    MSG glyphRect
    ldp d4, d5, [sp, #144]
    fadd d0, d0, d4
    fadd d1, d1, d5
    LEAVE
.globl _mac_atomic_text_baseline
_mac_atomic_text_baseline:
    ENTER
    bl _mac_atomic_target
    mov x19, x0
    str d1, [sp, #144]
    mov x3, #1
    mov x4, #0
    MSG glyphRange
    mov x20, x0
    mov x0, x19
    mov x2, x20
    mov x3, #0
    MSG lineFragment
    ldr d2, [sp, #144]
    fadd d1, d1, d2
    str d1, [sp, #152]
    mov x0, x19
    mov x2, x20
    MSG glyphLocation
    ldr d0, [sp, #152]
    fadd d0, d0, d1
    LEAVE

// index, out {manager,container,localIndex,sourceBase,x,y}: debug/native adapter.
// Keep this ABI explicit: the internal helper returns integer pairs plus HFA.
.globl _mac_atomic_context
_mac_atomic_context:
    ENTER
    mov x19, x1
    bl _mac_atomic_target
    stp x0, x1, [x19]
    stp x2, x3, [x19, #16]
    stp d0, d1, [x19, #32]
    LEAVE
