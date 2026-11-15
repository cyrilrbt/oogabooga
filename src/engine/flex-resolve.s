// Flex min/max freezing with deterministic integer remainder distribution.
// Temporary records are bounded by the owner's 256-item limit and never stored
// in document metadata. Minima win conflicting maxima on either axis.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,indices,first,end,owner,available,gap,direction -> success
.globl _engine_flex_resolve
_engine_flex_resolve:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    mov x20, x1
    mov x21, x2
    sub x22, x3, x2
    mov x23, x7
    sub x9, x22, #1
    mul x9, x9, x6
    sub x24, x5, x9
    cbz x22, Lresolve_fail
    cmp x22, #256
    b.hi Lresolve_fail
    mov x0, x22
    mov x1, #64
    bl _calloc
    cbz x0, Lresolve_fail
    mov x25, x0
    mov x26, #0
    mov x27, #0
Lresolve_init:
    cmp x26, x22
    b.hs Lresolve_mode
    add x9, x21, x26
    ldr x9, [x20, x9, lsl #3]
    ldr x10, [x19, #72]
    add x28, x10, x9, lsl #11
    add x9, x25, x26, lsl #6
    str x28, [x9]
    ldr x10, [x28, #FLOW_BASE]
    str x10, [x9, #8]
    add x27, x27, x10
    ldr x11, [x28, #FLOW_WIDTH]
    tbz x23, #0, Lresolve_init_edges
    ldr x11, [x28, #FLOW_HEIGHT]
Lresolve_init_edges:
    sub x10, x10, x11
    str x10, [x9, #16]
    tbz x23, #0, Lresolve_width_limits
    ldr x0, [x28, #BOX_MIN_HEIGHT]
    ldr x1, [x28, #BOX_MAX_HEIGHT]
    tbnz x1, #63, Lresolve_limits_ready
    cmp x1, x0
    csel x1, x0, x1, lt
    b Lresolve_limits_ready
Lresolve_width_limits:
    mov x0, x28
    ldr x1, [x28, #848]
    bl _engine_width_limits
Lresolve_limits_ready:
    add x9, x25, x26, lsl #6
    stp x0, x1, [x9, #24]
    add x26, x26, #1
    b Lresolve_init
Lresolve_mode:
    cmp x24, x27
    cset x9, lt                    // shrink mode stays fixed across rounds
    str x9, [sp, #64]
    add x9, x22, #1
    str x9, [sp, #72]
    mov x26, #0
Lresolve_factors:
    cmp x26, x22
    b.hs Lresolve_round
    add x9, x25, x26, lsl #6
    ldr x10, [x9]
    ldr x11, [x10, #(32+CSS_GROW*8)]
    ldr x12, [sp, #64]
    cbz x12, Lresolve_factor_ready
    ldr x11, [x10, #(32+CSS_SHRINK*8)]
    ldr x12, [x9, #8]
    ldr x13, [x9, #16]
    sub x12, x12, x13
    cmp x12, #0
    csel x12, xzr, x12, lt
    mul x11, x11, x12
Lresolve_factor_ready:
    str x11, [x9, #56]
    cbnz x11, Lresolve_factor_next
    // Inflexible items are frozen at their constrained hypothetical size.
    ldr x0, [x9, #8]
    bl resolve_clamp
    str x0, [x9, #40]
    mov x10, #1
    str x10, [x9, #48]
Lresolve_factor_next:
    add x26, x26, #1
    b Lresolve_factors
Lresolve_round:
    mov x26, #0
    mov x27, x24
    mov x28, #0
Lresolve_free_sum:
    cmp x26, x22
    b.hs Lresolve_distribute
    add x9, x25, x26, lsl #6
    ldr x10, [x9, #48]
    ldr x11, [x9, #8]
    cbz x10, Lresolve_unfrozen_sum
    ldr x11, [x9, #40]
    b Lresolve_subtract
Lresolve_unfrozen_sum:
    ldr x12, [x9, #56]
    add x28, x28, x12
Lresolve_subtract:
    sub x27, x27, x11
    add x26, x26, #1
    b Lresolve_free_sum
Lresolve_distribute:
    str x27, [sp, #16]
    str x28, [sp, #24]
    cmp x27, #0
    cneg x9, x27, lt
    str x9, [sp, #32]
    str xzr, [sp, #40]             // total min/max violation
    mov x26, #0                    // cumulative weight
    mov x27, #0                    // allocated magnitude
    mov x28, #0                    // record index
Lresolve_candidate:
    cmp x28, x22
    b.hs Lresolve_freeze
    add x9, x25, x28, lsl #6
    ldr x10, [x9, #48]
    cbnz x10, Lresolve_candidate_next
    ldr x0, [x9, #8]
    ldr x10, [sp, #24]
    cbz x10, Lresolve_candidate_clamp
    ldr x11, [x9, #56]
    add x26, x26, x11
    ldr x11, [sp, #32]
    mul x11, x11, x26
    udiv x11, x11, x10
    sub x12, x11, x27
    mov x27, x11
    ldr x10, [sp, #16]
    cmp x10, #0
    cneg x12, x12, lt
    add x0, x0, x12
Lresolve_candidate_clamp:
    mov x14, x0
    bl resolve_clamp
    str x0, [x9, #40]
    sub x10, x0, x14
    ldr x11, [sp, #40]
    add x11, x11, x10
    str x11, [sp, #40]
    cmp x10, #0
    mov x11, #2
    mov x12, #3
    csel x11, x12, x11, lt
    csel x11, xzr, x11, eq
    str x11, [x9, #48]
Lresolve_candidate_next:
    add x28, x28, #1
    b Lresolve_candidate
Lresolve_freeze:
    ldr x10, [sp, #40]
    cbz x10, Lresolve_commit
    mov x11, #2
    mov x12, #3
    cmp x10, #0
    csel x11, x12, x11, lt
    mov x26, #0
    mov x27, #0
Lresolve_freeze_item:
    cmp x26, x22
    b.hs Lresolve_progress
    add x9, x25, x26, lsl #6
    ldr x10, [x9, #48]
    cmp x10, #1
    b.eq Lresolve_freeze_next
    cmp x10, x11
    cset x10, eq
    str x10, [x9, #48]
    add x27, x27, x10
Lresolve_freeze_next:
    add x26, x26, #1
    b Lresolve_freeze_item
Lresolve_progress:
    cbz x27, Lresolve_commit
    ldr x9, [sp, #72]
    subs x9, x9, #1
    str x9, [sp, #72]
    b.ne Lresolve_round
Lresolve_commit:
    mov x26, #0
Lresolve_commit_item:
    cmp x26, x22
    b.hs Lresolve_success
    add x9, x25, x26, lsl #6
    ldr x10, [x9]
    ldr x11, [x9, #40]
    str x11, [x10, #FLOW_BASE]
    ldr x12, [x9, #16]
    sub x11, x11, x12
    tbz x23, #0, Lresolve_commit_width
    str x11, [x10, #FLOW_HEIGHT]
    b Lresolve_commit_next
Lresolve_commit_width:
    str x11, [x10, #FLOW_WIDTH]
Lresolve_commit_next:
    add x26, x26, #1
    b Lresolve_commit_item
Lresolve_success:
    mov x0, x25
    bl _free
    mov x0, #1
    b Lresolve_return
Lresolve_fail:
    mov x0, #0
Lresolve_return:
    add sp, sp, #128
    LEAVE

// Leaf helper: record x9, proposed outer x0 -> constrained outer x0.
// Preserve x9/x14, used by the caller to accumulate signed violations.
resolve_clamp:
    ldr x10, [x9, #16]
    sub x0, x0, x10
    ldr x11, [x9, #24]
    ldr x12, [x9, #32]
    cmp x0, x11
    csel x0, x11, x0, lt
    tbnz x12, #63, Lresolve_clamp_edges
    cmp x0, x12
    csel x0, x12, x0, gt
Lresolve_clamp_edges:
    add x0, x0, x10
    ret
