// Stable counting sort of command indices. Records stay at fixed addresses so
// native block adapters can retain pointers into the original display list.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
// scene, display-list -> BOOL. Invalid input leaves no partial paint order.
.globl _engine_scene_order
_engine_scene_order:
    cbz x0, Lsort_bad
    str xzr, [x0, #24]
    cbz x1, Lsort_bad
    ldr x2, [x0]
    ldr x3, [x0, #8]
    ldr x4, [x0, #72]
    ldr x5, [x1]
    mov x6, #SCENE_COMMAND_CAPACITY
    cmp x5, x6
    b.hi Lsort_bad
    ldr x6, [x1, #16]
    cbz x6, Lsort_bad
    mov x7, #0
Lsort_clear:
    cmp x7, x2
    b.hs Lsort_count_begin
    str xzr, [x4, x7, lsl #3]
    add x7, x7, #1
    b Lsort_clear
Lsort_count_begin:
    mov x7, #0
Lsort_count:
    cmp x7, x5
    b.hs Lsort_prefix_begin
    add x8, x6, x7, lsl #7
    ldr x9, [x8, #8]
    cmp x9, x2
    b.hs Lsort_bad
    add x9, x3, x9, lsl #9
    ldr x9, [x9, #SC_RANK]
    cmp x9, x2
    b.hs Lsort_bad
    ldr x10, [x4, x9, lsl #3]
    add x10, x10, #1
    str x10, [x4, x9, lsl #3]
    add x7, x7, #1
    b Lsort_count
Lsort_prefix_begin:
    mov x7, #0
    mov x8, #0
Lsort_prefix:
    cmp x7, x2
    b.hs Lsort_emit_begin
    ldr x9, [x4, x7, lsl #3]
    str x8, [x4, x7, lsl #3]
    add x8, x8, x9
    add x7, x7, #1
    b Lsort_prefix
Lsort_emit_begin:
    mov x7, #0
    ldr x11, [x0, #16]
Lsort_emit:
    cmp x7, x5
    b.hs Lsort_done
    add x8, x6, x7, lsl #7
    ldr x9, [x8, #8]
    add x9, x3, x9, lsl #9
    ldr x9, [x9, #SC_RANK]
    ldr x10, [x4, x9, lsl #3]
    str x7, [x11, x10, lsl #3]
    add x10, x10, #1
    str x10, [x4, x9, lsl #3]
    add x7, x7, #1
    b Lsort_emit
Lsort_done:
    str x5, [x0, #24]
    mov x0, #1
    ret
Lsort_bad:
    mov x0, #0
    ret
