// doc,node -> nearest independent formatting root index + 1, or zero.
// Inline blocks, positioned roots and nested flex/Grid own their glyph shaping.
// The element itself belongs to its parent's formatting context.
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_inline_owner
_engine_inline_owner:
    ldr x2, [x0, #16]
    ldr x3, [x0, #72]
    mov x4, #40
    madd x5, x1, x4, x2
    ldr x1, [x5, #8]
    mov x6, #ENGINE_MAX_DEPTH
Linline_owner_parent:
    tbnz x1, #63, Linline_owner_none
    cbz x1, Linline_owner_none
    cbz x6, Linline_owner_none
    sub x6, x6, #1
    add x5, x3, x1, lsl #11
    ldr x7, [x5, #(1840+(CSS_POSITION-48)*8)]
    cmp x7, #2
    b.hs Linline_owner_candidate
    ldr x7, [x5, #88]
    cmp x7, #5
    b.eq Linline_owner_candidate
    cmp x7, #3
    b.lo Linline_owner_next
    cmp x7, #4
    b.hi Linline_owner_next
    ldr x7, [x5, #FLOW_OWNER]
    cbz x7, Linline_owner_next
Linline_owner_candidate:
    ldr x7, [x5, #872]             // existing styled-link native attachment
    cbz x7, Linline_owner_yes
Linline_owner_next:
    madd x5, x1, x4, x2
    ldr x1, [x5, #8]
    b Linline_owner_parent
Linline_owner_yes:
    add x0, x1, #1
    ret
Linline_owner_none:
    mov x0, #0
    ret
