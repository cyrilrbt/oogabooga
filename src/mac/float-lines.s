// Dense float exclusion records. The line-fragment hot path is assembly and
// scans primitive rectangles, without per-obstacle Objective-C calls.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc, UTF16 layout, text container. Runs once per render/reflow.
.globl _mac_float_prepare
_mac_float_prepare:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #72]
    ldr x23, [x19, #24]
    mov x24, #0
    mov x25, #0
Lrecords_count:
    cmp x24, x23
    b.hs Lrecords_allocate
    add x9, x22, x24, lsl #11
    str xzr, [x9, #FLOAT_NATIVE_RECORD]
    ldr x9, [x9, #FLOAT_ACTIVE]
    cmp x9, #1
    cinc x25, x25, eq
    add x24, x24, #1
    b Lrecords_count
Lrecords_allocate:
    CLASS NSMutableData
    MSG new
    mov x26, x0
    lsl x2, x25, #7
    add x2, x2, #8
    MSG setLength
    mov x0, x26
    MSG mutableBytes
    str x25, [x0]
    add x27, x0, #8
    mov x24, #0
Lrecords_fill:
    cmp x24, x23
    b.hs Lrecords_install
    add x9, x22, x24, lsl #11
    ldr x10, [x9, #FLOAT_ACTIVE]
    cmp x10, #1
    b.ne Lrecords_fill_next
    str x27, [x9, #FLOAT_NATIVE_RECORD]
    ldr x10, [x9, #(32+CSS_FLOAT*8)]
    ldr x11, [x9, #(1840+(CSS_POSITION-48)*8)]
    cmp x11, #2
    csel x10, xzr, x10, hs
    cmp x11, #3
    b.ne Lrecords_position_flags
    mov x10, #128                 // fixed: excluded from document scroll extent
Lrecords_position_flags:
    orr x10, x10, x24, lsl #8
    str x10, [x27, #56]
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x24, x11, x10
    ldp x11, x12, [x10, #16]
    ldr x10, [x20, #16]
    ldr x11, [x10, x11, lsl #3]
    ldr x12, [x10, x12, lsl #3]
    stp x11, x12, [x27]
    ldr x10, [x9, #40]
    str x10, [x27, #64]
    ldr x10, [x9, #200]
    str x10, [x27, #72]
    add x12, x9, #BOX_BORDER_LEFT
    ldp x10, x11, [x12]
    stp x10, x11, [x27, #80]
    ldp x10, x11, [x12, #16]
    stp x10, x11, [x27, #96]
    ldr x10, [x9, #776]
    ldr x11, [x9, #792]
    orr x10, x10, x11, lsl #16
    ldr x11, [x9, #784]
    orr x10, x10, x11, lsl #32
    ldr x11, [x9, #800]
    orr x10, x10, x11, lsl #48
    str x10, [x27, #112]
    ldr x10, [x9, #FLOAT_CONTEXT]
    str x10, [x27, #120]
    add x27, x27, #128
Lrecords_fill_next:
    add x24, x24, #1
    b Lrecords_fill
Lrecords_install:
    STORE x26, _mac_float_records
    mov x0, x21
    ADDR x1, _mac_float_records_key
    mov x2, x26
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x26
    MSG release
    cbz x25, Lrecords_plain_class
    ADDR x0, float_container_name
    bl _objc_getClass
    cbnz x0, Lrecords_class_ready
    CLASS NSTextContainer
    ADDR x1, float_container_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x22, x0
    ADDR x0, fragment_name
    bl _sel_registerName
    mov x1, x0
    mov x0, x22
    ADDR x2, float_fragment
    ADDR x3, fragment_encoding
    bl _class_addMethod
    mov x0, x22
    bl _objc_registerClassPair
    mov x0, x22
    b Lrecords_class_ready
Lrecords_plain_class:
    CLASS NSTextContainer
Lrecords_class_ready:
    mov x1, x0
    mov x0, x21
    bl _object_setClass
    mov x0, x19
    mov x1, x21
    bl _mac_display_begin
    mov x0, x21
    LOAD x1, _mac_float_records
    mov x2, x25
    bl _mac_float_painter
    LEAVE

// lineFragmentRectForProposedRect:atIndex:writingDirection:remainingRect:
float_fragment:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2                    // UTF16 character index
    mov x22, x3
    mov x23, x4                    // optional remainder rect
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    CLASS NSTextContainer
    stp x19, x0, [sp]
    mov x0, sp
    mov x1, x20
    mov x2, x21
    mov x3, x22
    mov x4, x23
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    bl _objc_msgSendSuper
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    mov x0, x19
    ADDR x1, _mac_float_records_key
    bl _objc_getAssociatedObject
    MSG bytes
    cbz x0, Lfragment_return
    ldr x24, [x0]
    add x25, x0, #8
    // At most one descent per obstacle; no pixel-at-a-time retries.
    add x26, x24, #1
Lfragment_band:
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    fadd d2, d0, d2                // available right edge
    mov x9, #0
    fmov d7, xzr                  // next intersecting bottom edge
Lfragment_obstacle:
    cmp x9, x24
    b.hs Lfragment_available
    add x10, x25, x9, lsl #7
    ldr x11, [x10, #56]
    tst x11, #3
    b.eq Lfragment_obstacle_next
    ldr x11, [x10, #48]
    cbz x11, Lfragment_obstacle_next
    ldr x11, [x10, #8]
    cmp x21, x11
    b.lo Lfragment_obstacle_next   // own ancestor/future float cannot exclude us
    ldp d4, d5, [x10, #16]
    ldp d6, d16, [x10, #32]
    fadd d16, d5, d16
    fcmp d16, d1
    b.le Lfragment_obstacle_next
    fadd d17, d1, d3
    fcmp d5, d17
    b.ge Lfragment_obstacle_next
    fadd d6, d4, d6
    fcmp d6, d0
    b.le Lfragment_obstacle_next
    fcmp d4, d2
    b.ge Lfragment_obstacle_next
    fcmp d7, #0.0
    b.eq Lfragment_next_bottom
    fcmp d16, d7
    b.ge Lfragment_side
Lfragment_next_bottom:
    fmov d7, d16
Lfragment_side:
    ldr x11, [x10, #56]
    and x11, x11, #255
    cmp x11, #1
    b.ne Lfragment_right
    fmax d0, d0, d6
    b Lfragment_obstacle_next
Lfragment_right:
    fmin d2, d2, d4
Lfragment_obstacle_next:
    add x9, x9, #1
    b Lfragment_obstacle
Lfragment_available:
    fsub d2, d2, d0
    fcmp d2, #0.0
    b.gt Lfragment_done
    cbz x26, Lfragment_empty
    fcmp d7, #0.0
    b.le Lfragment_empty
    str d7, [sp, #152]
    sub x26, x26, #1
    b Lfragment_band
Lfragment_empty:
    fmov d2, xzr
Lfragment_done:
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    cbz x23, Lfragment_return
    stp xzr, xzr, [x23]
    stp xzr, xzr, [x23, #16]
Lfragment_return:
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    LEAVE
.section __TEXT,__cstring,cstring_literals
float_container_name: .asciz "OogaFloatContainer"
fragment_name: .asciz "lineFragmentRectForProposedRect:atIndex:writingDirection:remainingRect:"
fragment_encoding: .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}QQ^{CGRect={CGPoint=dd}{CGSize=dd}}"
.globl _mac_float_records_key
_mac_float_records_key: .asciz "floatExclusionRecords"
.section __DATA,__bss
.p2align 3
.globl _mac_float_records
_mac_float_records: .space 8

.text
.p2align 2
// container -> out-of-flow occupied width/height. Keep tall floats scrollable.
.globl _mac_float_extent
_mac_float_extent:
    ENTER
    ADDR x1, _mac_float_records_key
    bl _objc_getAssociatedObject
    MSG bytes
    fmov d0, xzr
    fmov d1, xzr
    cbz x0, Lfloat_extent_done
    ldr x9, [x0]
    add x10, x0, #8
Lfloat_extent_next:
    cbz x9, Lfloat_extent_done
    ldr x11, [x10, #56]
    tbnz x11, #7, Lfloat_extent_advance
    ldr x11, [x10, #48]
    cbz x11, Lfloat_extent_advance
    ldp d2, d3, [x10, #16]
    ldp d4, d5, [x10, #32]
    fadd d2, d2, d4
    fadd d3, d3, d5
    fmax d0, d0, d2
    fmax d1, d1, d3
Lfloat_extent_advance:
    add x10, x10, #128
    sub x9, x9, #1
    b Lfloat_extent_next
Lfloat_extent_done:
    LEAVE
