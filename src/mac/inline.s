// Map horizontal inline margins/padding to trailing glyph advance. This keeps
// adjacent link ranges intact while making their CSS spacing visible in TextKit.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _mac_inline_spacing
_mac_inline_spacing:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
Linline_space_next:
    ldr x9, [x19, #24]
    cmp x22, x9
    b.hs Linline_space_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x23, x22, x10, x9
    ldr x9, [x23]
    cmp x9, #NODE_TEXT
    b.eq Linline_space_advance
    cmp x9, #NODE_A
    b.eq Linline_space_metrics
    cmp x9, #NODE_SPAN
    b.eq Linline_space_metrics
    cmp x9, #NODE_STRONG
    b.eq Linline_space_metrics
    cmp x9, #NODE_EM
    b.eq Linline_space_metrics
    b Linline_space_advance
Linline_space_metrics:
    ldr x24, [x19, #72]
    add x24, x24, x22, lsl #10
    ldr x9, [x24, #872]
    cbnz x9, Linline_space_advance
    ldr x9, [x24, #776]
    ldr x10, [x24, #784]
    add x25, x9, x10
    ldr x9, [x24, #808]
    ldr x10, [x24, #816]
    add x25, x25, x9
    add x25, x25, x10
    cbz x25, Linline_space_advance
    ldr x9, [x20, #16]
    ldr x10, [x23, #16]
    ldr x11, [x23, #24]
    ldr x10, [x9, x10, lsl #3]
    ldr x26, [x9, x11, lsl #3]
    cmp x10, x26
    b.hs Linline_space_advance
    // Use the full composed character, including surrogate pairs/combining marks.
    mov x0, x21
    MSG string
    sub x2, x26, #1
    MSG composedRange
    stp x0, x1, [sp, #144]
    mov x3, x0
    adrp x9, _NSKernAttributeName@GOTPAGE
    ldr x9, [x9, _NSKernAttributeName@GOTPAGEOFF]
    ldr x24, [x9]
    mov x0, x21
    mov x2, x24
    mov x4, #0
    MSG attributeIndex
    MSG longLongValue
    add x25, x25, x0
    CLASS NSNumber
    mov x2, x25
    MSG numberLongLong
    mov x3, x0
    mov x0, x21
    mov x2, x24
    ldp x4, x5, [sp, #144]
    MSG addAttribute
Linline_space_advance:
    add x22, x22, #1
    b Linline_space_next
Linline_space_done:
    LEAVE
