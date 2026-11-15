.include "src/mac/mac.inc"
.include "src/engine/scene.inc"
.text
.p2align 2
.globl _engine_scene_context_link
_engine_scene_context_link:
    ldr x2, [x0, #8]
    add x3, x2, x1, lsl #9
    ldr x4, [x3, #SC_PARENT]
    add x5, x2, x4, lsl #9
    ldr x6, [x5, #SC_FLAGS]
    tbz x6, #0, Lcontext_inherited
    add x7, x4, #1
    mov x8, #0
    b Lcontext_parent
Lcontext_inherited:
    ldr x7, [x5, #SC_CONTEXT_PARENT]
    ldr x8, [x5, #SC_PAINT_PHASE]
Lcontext_parent:
    str x7, [x3, #SC_CONTEXT_PARENT]
    ldr x9, [x3, #SC_POSITION]
    cmp x9, #0
    mov x10, #1
    csel x8, x8, x10, eq
    str x8, [x3, #SC_PAINT_PHASE]
    ldr x9, [x5, #SC_POSITION]
    cbz x9, Lcontext_containing_inherit
    add x9, x4, #1
    b Lcontext_containing
Lcontext_containing_inherit:
    ldr x9, [x5, #SC_CONTAINING]
Lcontext_containing:
    str x9, [x3, #SC_CONTAINING]
    ldr x9, [x3, #SC_FLAGS]
    tbz x9, #0, Lcontext_done
    sub x7, x7, #1
    add x7, x2, x7, lsl #9
    add x7, x7, #SC_CONTEXT_FIRST
    ldr x8, [x3, #SC_Z]
Lcontext_insert:
    ldr x9, [x7]
    cbz x9, Lcontext_insert_here
    sub x10, x9, #1
    add x10, x2, x10, lsl #9
    ldr x11, [x10, #SC_Z]
    cmp x11, x8
    b.gt Lcontext_insert_here
    add x7, x10, #SC_CONTEXT_NEXT
    b Lcontext_insert
Lcontext_insert_here:
    str x9, [x3, #SC_CONTEXT_NEXT]
    add x1, x1, #1
    str x1, [x7]
Lcontext_done:
    ret

scene_assign_rank:
    ldr x9, [x0, #64]
    ldr x10, [x0, #8]
    add x10, x10, x1, lsl #9
    str x9, [x10, #SC_RANK]
    add x9, x9, #1
    str x9, [x0, #64]
    ret

// Stacking contexts remain contiguous; descendants never escape an ancestor's
// z-order. Negative, normal-flow, zero/positioned, positive phases are separate.
.globl _engine_scene_rank_context
_engine_scene_rank_context:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #8]
    add x22, x21, x20, lsl #9
    bl scene_assign_rank
    ldr x23, [x22, #SC_CONTEXT_FIRST]
Lrank_negative:
    cbz x23, Lrank_normal_begin
    sub x1, x23, #1
    add x24, x21, x1, lsl #9
    ldr x9, [x24, #SC_Z]
    cmp x9, #32768
    b.ge Lrank_normal_begin
    mov x0, x19
    bl _engine_scene_rank_context
    ldr x23, [x24, #SC_CONTEXT_NEXT]
    b Lrank_negative
Lrank_normal_begin:
    mov x23, #0
    add x25, x20, #1
Lrank_normal:
    ldr x9, [x19]
    cmp x23, x9
    b.hs Lrank_positioned_begin
    add x24, x21, x23, lsl #9
    ldr x9, [x24, #SC_CONTEXT_PARENT]
    cmp x9, x25
    b.ne Lrank_normal_next
    ldr x9, [x24, #SC_FLAGS]
    tbnz x9, #0, Lrank_normal_next
    ldr x9, [x24, #SC_PAINT_PHASE]
    cbnz x9, Lrank_normal_next
    mov x0, x19
    mov x1, x23
    bl scene_assign_rank
Lrank_normal_next:
    add x23, x23, #1
    b Lrank_normal
Lrank_positioned_begin:
    mov x23, #0
Lrank_positioned:
    ldr x9, [x19]
    cmp x23, x9
    b.hs Lrank_positive_begin
    add x24, x21, x23, lsl #9
    ldr x9, [x24, #SC_CONTEXT_PARENT]
    cmp x9, x25
    b.ne Lrank_positioned_next
    ldr x9, [x24, #SC_FLAGS]
    tbz x9, #0, Lrank_positioned_normal
    ldr x9, [x24, #SC_Z]
    cmp x9, #32768
    b.ne Lrank_positioned_next
    mov x0, x19
    mov x1, x23
    bl _engine_scene_rank_context
    b Lrank_positioned_next
Lrank_positioned_normal:
    ldr x9, [x24, #SC_PAINT_PHASE]
    cbz x9, Lrank_positioned_next
    mov x0, x19
    mov x1, x23
    bl scene_assign_rank
Lrank_positioned_next:
    add x23, x23, #1
    b Lrank_positioned
Lrank_positive_begin:
    ldr x23, [x22, #SC_CONTEXT_FIRST]
Lrank_positive:
    cbz x23, Lrank_done
    sub x1, x23, #1
    add x24, x21, x1, lsl #9
    ldr x9, [x24, #SC_Z]
    cmp x9, #32768
    b.le Lrank_positive_next
    mov x0, x19
    bl _engine_scene_rank_context
Lrank_positive_next:
    ldr x23, [x24, #SC_CONTEXT_NEXT]
    b Lrank_positive
Lrank_done:
    ldr x9, [x19, #64]
    sub x9, x9, #1
    str x9, [x22, #SC_END_RANK]
    LEAVE
