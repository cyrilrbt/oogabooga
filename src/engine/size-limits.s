// Shared content-box width limits. Minima win over conflicting maxima; auto
// and none have no upper bound. Every layout path consumes the same values.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_width_limits
_engine_width_limits:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #0
    ldr x9, [x19, #216]
    cbz x9, Llimits_edges
    ldr x21, [x19, #808]
    ldr x9, [x19, #816]
    add x21, x21, x9
    ldr x9, [x19, #BOX_BORDER_LEFT]
    add x21, x21, x9
    ldr x9, [x19, #BOX_BORDER_RIGHT]
    add x21, x21, x9
Llimits_edges:
    ldr x0, [x19, #(32+CSS_MIN_WIDTH*8)]
    mov x1, x20
    bl _engine_box_length
    sub x22, x0, x21
    cmp x22, #0
    csel x22, xzr, x22, lt
    mov x23, #-1
    ldr x0, [x19, #(32+CSS_MAX_WIDTH*8)]
    tbnz x0, #63, Llimits_done
    mov x1, x20
    bl _engine_box_length
    sub x23, x0, x21
    cmp x23, x22
    csel x23, x22, x23, lt
Llimits_done:
    mov x0, x22
    mov x1, x23
    LEAVE

// meta, containing width, candidate content width -> constrained width.
.globl _engine_width_clamp
_engine_width_clamp:
    ENTER
    mov x19, x2
    bl _engine_width_limits
    cmp x19, x0
    csel x19, x0, x19, lt
    tbnz x1, #63, Lwidth_clamped
    cmp x19, x1
    csel x19, x1, x19, gt
Lwidth_clamped:
    mov x0, x19
    LEAVE

// metadata, min-content, max-content, available margin-box width -> content.
// Do not squeeze an unbreakable run merely to fit the containing block.
.globl _engine_shrink_to_fit
_engine_shrink_to_fit:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x9, [x19, #776]
    sub x22, x22, x9
    ldr x9, [x19, #784]
    sub x22, x22, x9
    ldr x9, [x19, #808]
    sub x22, x22, x9
    ldr x9, [x19, #816]
    sub x22, x22, x9
    ldr x9, [x19, #BOX_BORDER_LEFT]
    sub x22, x22, x9
    ldr x9, [x19, #BOX_BORDER_RIGHT]
    sub x22, x22, x9
    cmp x21, x20
    csel x21, x20, x21, lt
    cmp x22, x20
    csel x22, x20, x22, lt
    cmp x22, x21
    csel x22, x21, x22, gt
    mov x0, x19
    ldr x1, [x19, #848]
    mov x2, x22
    bl _engine_width_clamp
    LEAVE
