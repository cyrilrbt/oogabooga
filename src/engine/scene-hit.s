// Topmost command in scene paint order, including opaque/non-link occlusion.
// The caller resolves link ancestry from the returned command's source node.
.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
.globl _engine_scene_hit
_engine_scene_hit:
    ENTER
    sub sp, sp, #48
    mov x19, x0
    mov x20, x1
    stp d0, d1, [sp, #32]
    cbz x19, Lscene_hit_nil
    cbz x20, Lscene_hit_nil
    ldr x21, [x19, #24]
    ldr x22, [x19, #16]
    ldr x23, [x20, #16]
Lscene_hit_next:
    cbz x21, Lscene_hit_nil
    sub x21, x21, #1
    ldr x9, [x22, x21, lsl #3]
    ldr x10, [x20]
    cmp x9, x10
    b.hs Lscene_hit_nil
    add x24, x23, x9, lsl #7
    ldr x9, [x24]
    cmp x9, #1
    b.lo Lscene_hit_next
    cmp x9, #4
    b.hi Lscene_hit_next
    cmp x9, #1
    cset x3, eq
    mov x0, x19
    ldr x1, [x24, #8]
    mov x2, sp
    ldp d0, d1, [x24, #16]
    ldp d2, d3, [x24, #32]
    bl _engine_scene_rect
    cbz x0, Lscene_hit_next
    ldp d0, d1, [sp, #32]
    ldp d2, d3, [sp]
    ldp d4, d5, [sp, #16]
    fcmp d0, d2
    b.lt Lscene_hit_next
    b.vs Lscene_hit_next
    fcmp d1, d3
    b.lt Lscene_hit_next
    b.vs Lscene_hit_next
    fadd d2, d2, d4
    fcmp d0, d2
    b.ge Lscene_hit_next
    fadd d3, d3, d5
    fcmp d1, d3
    b.ge Lscene_hit_next
    mov x0, x24
    b Lscene_hit_done
Lscene_hit_nil:
    mov x0, #0
Lscene_hit_done:
    add sp, sp, #48
    LEAVE
