// Resolve dependent formatting contexts after floats/positioning or an inline
// parent obtains its used width. Preserve the parent's assigned outer geometry;
// rebuild its internal flex/Grid/table allocation against that width.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
// doc,inline scope (nearest inline root index+1; zero for the main document)
.globl _engine_context_reflow
_engine_context_reflow:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    ldr x22, [x19, #24]
    mov x23, #1
Lcontext_next:
    cmp x23, x22
    b.hs Lcontext_done
    mov x0, x19
    mov x1, x23
    bl _engine_inline_owner
    cmp x0, x20
    b.ne Lcontext_advance
    add x24, x21, x23, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x25, x23, x10, x9
    ldr x9, [x25, #8]
    add x9, x21, x9, lsl #11
    ldr x1, [x9, #768]
    mov x0, x24
    bl _engine_box_metrics
    ldr x9, [x24, #FLOW_OWNER]
    cbz x9, Lcontext_kind
    ldr x9, [x24, #FLOW_WIDTH]
    str x9, [x24, #768]
Lcontext_kind:
    ldr x9, [x24, #88]
    cmp x9, #3
    b.eq Lcontext_flex
    cmp x9, #4
    b.eq Lcontext_grid
    ldr x9, [x25]
    cmp x9, #NODE_TABLE
    b.ne Lcontext_advance
    mov x0, x19
    mov x1, x23
    bl _engine_table_owner
    b Lcontext_advance
Lcontext_flex:
    mov x0, x19
    mov x1, x23
    bl _engine_flex_owner
    b Lcontext_advance
Lcontext_grid:
    mov x0, x19
    mov x1, x23
    bl _engine_grid_owner
Lcontext_advance:
    add x23, x23, #1
    b Lcontext_next
Lcontext_done:
    LEAVE
