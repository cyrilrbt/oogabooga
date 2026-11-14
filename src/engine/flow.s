// Soften parser-inserted block boundaries for CSS inline/inline-block elements.
// Mask 1 hides content, 2 is a collapsible boundary space, 3 protects an
// explicit <br>. Preserve explicit breaks and surrounding block boundaries.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _engine_inline_flow
_engine_inline_flow:
    ldr x1, [x0, #16]
    ldr x2, [x0, #24]
    ldr x3, [x0, #72]
    ldr x4, [x0]
    ldr x5, [x0, #80]
    mov x6, #1
Linline_protect_breaks:
    cmp x6, x2
    b.hs Linline_begin
    mov x7, #40
    madd x7, x6, x7, x1
    ldr x8, [x7]
    cmp x8, #39
    b.ne Linline_protect_next
    ldr x8, [x7, #16]
    ldr x9, [x7, #24]
    cmp x8, x9
    b.hs Linline_protect_next
    ldrb w9, [x5, x8]
    cmp w9, #1
    b.eq Linline_protect_next
    mov w9, #3
    strb w9, [x5, x8]
Linline_protect_next:
    add x6, x6, #1
    b Linline_protect_breaks
Linline_begin:
    mov x6, #1
Linline_next:
    cmp x6, x2
    b.hs Linline_done
    add x7, x3, x6, lsl #10
    ldr x7, [x7, #88]
    cmp x7, #2
    b.ne Linline_advance
    mov x7, #40
    madd x7, x6, x7, x1
    ldr x8, [x7]
    cmp x8, #1                      // text and native inline tags own no breaks
    b.eq Linline_advance
    cmp x8, #6
    b.eq Linline_advance
    cmp x8, #18
    b.eq Linline_advance
    cmp x8, #21
    b.eq Linline_advance
    cmp x8, #22
    b.eq Linline_advance
    cmp x8, #28
    b.ls Linline_parent
    cmp x8, #33
    b.eq Linline_parent
    cmp x8, #38
    b.ne Linline_advance
Linline_parent:
    ldr x8, [x7, #8]
    mov x9, #40
    madd x8, x8, x9, x1
    ldr x9, [x8, #16]
    ldr x10, [x8, #24]
    ldr x11, [x7, #16]
Linline_before:
    cmp x11, x9
    b.ls Linline_after_start
    sub x12, x11, #1
    ldrb w13, [x4, x12]
    cmp w13, #10
    b.ne Linline_after_start
    ldrb w13, [x5, x12]
    cmp w13, #1
    b.eq Linline_after_start
    cmp w13, #3
    b.eq Linline_after_start
    mov w13, #2
    strb w13, [x5, x12]
    mov x11, x12
    b Linline_before
Linline_after_start:
    ldr x11, [x7, #24]
Linline_after:
    cmp x11, x10
    b.hs Linline_advance
    ldrb w13, [x4, x11]
    cmp w13, #10
    b.ne Linline_advance
    ldrb w13, [x5, x11]
    cmp w13, #1
    b.eq Linline_advance
    cmp w13, #3
    b.eq Linline_advance
    mov w13, #2
    strb w13, [x5, x11]
    add x11, x11, #1
    b Linline_after
Linline_advance:
    add x6, x6, #1
    b Linline_next
Linline_done:
    ret
