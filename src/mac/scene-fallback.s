// Empty native block/table measurements can still have valid shaped children.
// Reconcile those missing boxes bottom-up; never enlarge an authored zero box.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/scene.inc"
.text
.globl _mac_scene_repair_empty
_mac_scene_repair_empty:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x20]
    ldr x22, [x20, #8]
    mov x0, x21
    mov x1, #40
    bl _calloc
    cbz x0, Lrepair_done
    mov x23, x0
    mov x24, x21
Lrepair_node:
    cbz x24, Lrepair_free
    sub x24, x24, #1
    ldr x9, [x19, #72]
    add x25, x9, x24, lsl #11
    ldr x9, [x25, #88]
    cmp x9, #1
    b.eq Lrepair_node
    ldr x9, [x25, #NATIVE_EMPTY]
    cbnz x9, Lrepair_node
    ldr x9, [x25, #BOX_HEIGHT]
    cbz x9, Lrepair_node
    ldr x9, [x25, #144]
    cbz x9, Lrepair_node
    add x26, x22, x24, lsl #9
    mov x9, #40
    madd x27, x24, x9, x23
    ldp d0, d1, [x26, #SC_X]
    ldp d2, d3, [x26, #SC_W]
    fcmp d2, #0.0
    b.le Lrepair_missing
    fcmp d3, #0.0
    b.gt Lrepair_propagate
Lrepair_missing:
    ldr x9, [x27, #32]
    cbz x9, Lrepair_node
    ldp d0, d1, [x27]
    ldp d2, d3, [x27, #16]
    mov x0, x20
    mov x1, x24
    bl _engine_scene_set_box
    ldp d0, d1, [x26, #SC_X]
    ldp d2, d3, [x26, #SC_W]
Lrepair_propagate:
    cbz x24, Lrepair_node
    ldr x9, [x26, #SC_POSITION]
    cmp x9, #2
    b.hs Lrepair_node
    ldr x9, [x26, #SC_PARENT]
    cmp x9, x24
    b.hs Lrepair_node
    mov x10, #40
    madd x27, x9, x10, x23
    ldr x9, [x27, #32]
    cbz x9, Lrepair_store
    ldp d4, d5, [x27]
    ldp d6, d7, [x27, #16]
    fadd d6, d6, d4
    fadd d7, d7, d5
    fadd d2, d2, d0
    fadd d3, d3, d1
    fmin d0, d0, d4
    fmin d1, d1, d5
    fmax d2, d2, d6
    fmax d3, d3, d7
    fsub d2, d2, d0
    fsub d3, d3, d1
Lrepair_store:
    stp d0, d1, [x27]
    stp d2, d3, [x27, #16]
    mov x9, #1
    str x9, [x27, #32]
    b Lrepair_node
Lrepair_free:
    mov x0, x23
    bl _free
Lrepair_done:
    LEAVE
