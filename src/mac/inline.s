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
    bl _mac_text_spacing
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
    add x24, x24, x22, lsl #11
    ldr x9, [x24, #88]
    cmp x9, #5
    b.eq Linline_space_advance
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

// Apply inherited tracking and additional word advance to actual text runs.
// Operate in UTF-16 coordinates so surrogate pairs and source ranges stay intact.
.globl _mac_text_spacing
_mac_text_spacing:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
Ltracking_node:
    ldr x9, [x19, #24]
    cmp x22, x9
    b.hs Ltracking_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x23, x22, x10, x9
    ldr x9, [x23]
    cmp x9, #1
    b.ne Ltracking_next
    ldr x9, [x19, #72]
    add x24, x9, x22, lsl #11
    ldr x0, [x24, #904]
    mov x1, #0
    bl _engine_box_signed_length
    str x0, [sp, #144]
    ldr x0, [x24, #896]
    mov x1, #0
    bl _engine_box_signed_length
    str x0, [sp, #152]
    ldr x9, [sp, #144]
    orr x9, x9, x0
    cbz x9, Ltracking_next
    ldr x9, [x20, #16]
    ldp x10, x11, [x23, #16]
    ldr x25, [x9, x10, lsl #3]
    ldr x26, [x9, x11, lsl #3]
    mov x0, x21
    MSG string
    mov x27, x0
Ltracking_char:
    cmp x25, x26
    b.hs Ltracking_next
    mov x0, x27
    mov x2, x25
    MSG characterAtIndex
    ldr x28, [sp, #144]
    cmp x0, #32
    b.ne Ltracking_value
    ldr x9, [sp, #152]
    add x28, x28, x9
Ltracking_value:
    CLASS NSNumber
    mov x2, x28
    MSG numberLongLong
    mov x3, x0
    mov x0, x21
    adrp x9, _NSKernAttributeName@GOTPAGE
    ldr x9, [x9, _NSKernAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x4, x25
    mov x5, #1
    MSG addAttribute
    add x25, x25, #1
    b Ltracking_char
Ltracking_next:
    add x22, x22, #1
    b Ltracking_node
Ltracking_done:
    LEAVE
