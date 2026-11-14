// Responsive content-box/border-box metrics. Computed percentage lengths carry
// bit32 and a percent*1000 magnitude. Scratch geometry never changes the cascade.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_box_length
_engine_box_length:
    tbnz x0, #63, Lbox_zero
    tbz x0, #32, Lbox_length_done
    and x0, x0, #0xffffffff
    mul x0, x0, x1
    mov x2, #1000
    mov x3, #100
    mul x2, x2, x3
    udiv x0, x0, x2
Lbox_length_done:
    mov x2, #16384
    cmp x0, x2
    csel x0, x2, x0, hi
    ret
Lbox_zero:
    mov x0, #0
    ret

// metrics(meta, containing_width) -> content_width. Scratch +768..848.
.globl _engine_box_metrics
_engine_box_metrics:
    ENTER
    mov x19, x0
    mov x20, x1
    str x1, [x19, #848]
    mov x21, #0
    ADDR x22, metric_properties
Lmetric_next:
    ldr x9, [x22, x21, lsl #3]
    add x9, x19, x9, lsl #3
    ldr x0, [x9, #32]
    mov x1, x20
    bl _engine_box_length
    add x9, x19, #776
    str x0, [x9, x21, lsl #3]
    add x21, x21, #1
    cmp x21, #9
    b.lo Lmetric_next
    ldr x21, [x19, #776]
    ldr x22, [x19, #784]       // resolved margins left/right
    ldr x23, [x19, #808]
    ldr x24, [x19, #816]       // padding left/right
    add x23, x23, x24
    ldr x24, [x19, #840]
    add x23, x23, x24, lsl #1       // horizontal border + padding
    sub x24, x20, x21
    sub x24, x24, x22
    sub x24, x24, x23              // auto fills remaining content width
    ldr x0, [x19, #144]
    tbnz x0, #63, Lmetric_max
    mov x1, x20
    bl _engine_box_length
    mov x24, x0
    ldr x9, [x19, #216]
    cbz x9, Lmetric_max
    sub x24, x24, x23              // border-box width includes padding/border
Lmetric_max:
    ldr x0, [x19, #208]
    tbnz x0, #63, Lmetric_clamp
    mov x1, x20
    bl _engine_box_length
    ldr x9, [x19, #216]
    cbz x9, Lmetric_max_compare
    sub x0, x0, x23
Lmetric_max_compare:
    cmp x24, x0
    csel x24, x0, x24, gt
Lmetric_clamp:
    mov x9, #1
    cmp x24, x9
    csel x24, x9, x24, lt
    str x24, [x19, #768]
    sub x25, x20, x24
    sub x25, x25, x23
    sub x25, x25, x21
    sub x25, x25, x22
    cmp x25, #0
    csel x25, xzr, x25, lt
    ldr x9, [x19, #128]
    ldr x10, [x19, #136]
    cmn x9, #5
    b.ne Lmetric_right_auto
    cmn x10, #5
    b.ne Lmetric_left_only
    lsr x25, x25, #1
    str x25, [x19, #776]
    str x25, [x19, #784]
    b Lmetric_done
Lmetric_left_only:
    str x25, [x19, #776]
    b Lmetric_done
Lmetric_right_auto:
    cmn x10, #5
    b.ne Lmetric_done
    str x25, [x19, #784]
Lmetric_done:
    mov x0, x24
    LEAVE
.section __DATA,__const
.p2align 3
metric_properties: .quad CSS_LEFT,CSS_RIGHT,CSS_TOP,CSS_BOTTOM,CSS_PAD_LEFT,CSS_PAD_RIGHT,CSS_PAD_TOP,CSS_PAD_BOTTOM,CSS_BORDER

.text
.p2align 2
.globl _engine_box_tree
_engine_box_tree:
    ENTER
    mov x19, x0
    ldr x20, [x19, #72]
    str x1, [x20, #768]
    str x1, [x20, #848]
    mov x21, #1
Lbox_tree_next:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lbox_tree_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x21, x10, x9
    ldr x9, [x9, #8]
    add x9, x20, x9, lsl #10
    ldr x1, [x9, #768]
    add x0, x20, x21, lsl #10
    bl _engine_box_metrics
    add x21, x21, #1
    b Lbox_tree_next
Lbox_tree_done:
    LEAVE
