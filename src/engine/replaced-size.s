// Intrinsic replaced sizing in content coordinates. Natural dimensions are
// positive bounded integers. An explicit axis stays independent; two automatic
// axes preserve aspect ratio unless contradictory constraints make it impossible.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// metadata, natural width/height, specified width/height (-1=auto) -> width,height
.globl _engine_replaced_size
_engine_replaced_size:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, #0
    tbz x22, #63, Lreplaced_width_present
    orr x24, x24, #1
    mov x22, x20
Lreplaced_width_present:
    tbz x23, #63, Lreplaced_height_present
    orr x24, x24, #2
    mov x23, x21
Lreplaced_height_present:
    cmp x24, #1
    b.ne Lreplaced_width_limit
    mul x22, x23, x20
    udiv x22, x22, x21
Lreplaced_width_limit:
    mov x0, x19
    ldr x1, [x19, #848]
    mov x2, x22
    bl _engine_width_clamp
    mov x22, x0
    tbz x24, #1, Lreplaced_height_limit
    mul x23, x22, x21
    udiv x23, x23, x20
Lreplaced_height_limit:
    ldr x9, [x19, #BOX_MAX_HEIGHT]
    tbnz x9, #63, Lreplaced_min_height
    cmp x23, x9
    csel x23, x9, x23, gt
Lreplaced_min_height:
    ldr x9, [x19, #BOX_MIN_HEIGHT]
    cmp x23, x9
    csel x23, x9, x23, lt
    tbz x24, #0, Lreplaced_done
    mul x22, x23, x20
    udiv x22, x22, x21
    mov x0, x19
    ldr x1, [x19, #848]
    mov x2, x22
    bl _engine_width_clamp
    mov x22, x0
Lreplaced_done:
    mov x0, x22
    mov x1, x23
    LEAVE
