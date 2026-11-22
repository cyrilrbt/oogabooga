// Definite content heights. A percentage under an auto-height parent remains
// auto; min-height alone never makes the percentage containing height definite.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_box_height
_engine_box_height:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #0
    ldr x9, [x19, #216]
    cbz x9, Lheight_edges_done
    ldr x21, [x19, #824]
    ldr x9, [x19, #832]
    add x21, x21, x9
    ldr x9, [x19, #BOX_BORDER_TOP]
    add x21, x21, x9
    ldr x9, [x19, #BOX_BORDER_BOTTOM]
    add x21, x21, x9
Lheight_edges_done:
    mov x22, #-1
    ldr x0, [x19, #(32+CSS_HEIGHT*8)]
    mov x1, x20
    bl height_length
    tbnz x0, #63, Lheight_minimum
    sub x22, x0, x21
    cmp x22, #0
    csel x22, xzr, x22, lt
Lheight_minimum:
    mov x23, #0
    ldr x0, [x19, #(32+CSS_MIN_HEIGHT*8)]
    mov x1, x20
    bl height_length
    tbnz x0, #63, Lheight_store
    sub x23, x0, x21
    cmp x23, #0
    csel x23, xzr, x23, lt
Lheight_store:
    mov x24, #-1
    ldr x0, [x19, #(1840+(CSS_MAX_HEIGHT-48)*8)]
    mov x1, x20
    bl height_length
    tbnz x0, #63, Lheight_limit_ready
    sub x24, x0, x21
    cmp x24, #0
    csel x24, xzr, x24, lt
Lheight_limit_ready:
    str x24, [x19, #BOX_MAX_HEIGHT]
    tbnz x22, #63, Lheight_auto
    tbnz x24, #63, Lheight_min_clamp
    cmp x22, x24
    csel x22, x24, x22, gt
Lheight_min_clamp:
    cmp x22, x23
    csel x22, x23, x22, lt
Lheight_auto:
    str x22, [x19, #BOX_HEIGHT]
    str x23, [x19, #BOX_MIN_HEIGHT]
    mov x0, x22
    LEAVE

// Indefinite containing heights make only percentage-dependent values auto.
height_length:
    ENTER
    mov x19, x0
    mov x20, x1
    tbnz x19, #63, Lheight_length_auto
    tbz x20, #63, Lheight_length_ready
    tbnz x19, #61, Lheight_length_math
    tbnz x19, #32, Lheight_length_auto
    b Lheight_length_ready
Lheight_length_math:
    and x9, x19, #0x1fffffffffffffff
    ldr x0, [x9]
    mov x1, #37
    bl _strchr
    cbnz x0, Lheight_length_auto
    mov x20, #0
Lheight_length_ready:
    mov x0, x19
    mov x1, x20
    bl _engine_box_length
    LEAVE
Lheight_length_auto:
    mov x0, #-1
    LEAVE
