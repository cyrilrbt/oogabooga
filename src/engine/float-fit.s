// Reconcile float placement with shaped line geometry. Primitive records only;
// no AppKit calls. Same context + preceding active records form the obstacles.
.include "src/mac/mac.inc"
.text
.p2align 2
// records header*, current record*, x/y/available width (d0/d1/d2).
// Returns margin-box origin d0/d1. Records are 128 bytes; context id at +120.
.globl _engine_float_fit
_engine_float_fit:
    mov x13, x2
    ldr x15, [x1, #56]            // bit 6: immutable block-avoidance query
    ldr x16, [x1]                 // query source position
    ldr x2, [x0]
    add x3, x0, #8
    ldr x4, [x1, #120]
    ldr x5, [x1, #56]
    and x5, x5, #255
    ldr d16, [x1, #32]
    fmov d17, d0
    fadd d18, d0, d2
    mov x6, #0
    mov x14, #0
Lfit_source_top:
    cmp x14, x2
    b.hs Lfit_source_top_done
    add x8, x3, x14, lsl #7
    cmp x8, x1
    b.eq Lfit_source_top_done
    tbz x15, #6, Lquery_source_ok
    ldr x17, [x8, #8]
    cmp x17, x16
    b.hi Lfit_source_top_next
Lquery_source_ok:
    ldr x9, [x8, #56]
    tst x9, #3
    b.eq Lfit_source_top_next
    ldr x9, [x8, #48]
    cbz x9, Lfit_source_top_next
    ldr x9, [x8, #120]
    cmp x9, x4
    b.ne Lfit_source_top_next
    ldr d3, [x8, #24]
    fmax d1, d1, d3
Lfit_source_top_next:
    add x14, x14, #1
    b Lfit_source_top
Lfit_source_top_done:
    cbz x13, Lfit_band
    mov x14, #0
Lfit_clear:
    cmp x14, x2
    b.hs Lfit_band
    add x8, x3, x14, lsl #7
    cmp x8, x1
    b.eq Lfit_band
    tbz x15, #6, Lquery_clear_ok
    ldr x17, [x8, #8]
    cmp x17, x16
    b.hi Lfit_clear_next
Lquery_clear_ok:
    ldr x9, [x8, #48]
    cbz x9, Lfit_clear_next
    ldr x9, [x8, #120]
    cmp x9, x4
    b.ne Lfit_clear_next
    ldr x9, [x8, #56]
    tst x9, x13
    b.eq Lfit_clear_next
    ldr d3, [x8, #24]
    ldr d4, [x8, #40]
    fadd d3, d3, d4
    fmax d1, d1, d3
Lfit_clear_next:
    add x14, x14, #1
    b Lfit_clear
Lfit_band:
    fmov d0, d17
    fmov d2, d18
    fmov d7, xzr
    mov x7, #0
Lfit_obstacle:
    cmp x7, x2
    b.hs Lfit_available
    add x8, x3, x7, lsl #7
    cmp x8, x1
    b.eq Lfit_available
    tbz x15, #6, Lquery_obstacle_ok
    ldr x17, [x8, #8]
    cmp x17, x16
    b.hi Lfit_next
Lquery_obstacle_ok:
    ldr x9, [x8, #56]
    tst x9, #3
    b.eq Lfit_next
    ldr x9, [x8, #48]
    cbz x9, Lfit_next
    ldr x9, [x8, #120]
    cmp x9, x4
    b.ne Lfit_next
    ldp d3, d4, [x8, #16]
    ldp d5, d6, [x8, #32]
    fadd d6, d4, d6
    fcmp d4, d1
    b.gt Lfit_next
    fcmp d6, d1
    b.le Lfit_next
    fcmp d7, #0.0
    b.eq Lfit_bottom
    fcmp d6, d7
    b.ge Lfit_side
Lfit_bottom:
    fmov d7, d6
Lfit_side:
    ldr x9, [x8, #56]
    and x9, x9, #255
    cmp x9, #1
    b.ne Lfit_right
    fadd d3, d3, d5
    fmax d0, d0, d3
    b Lfit_next
Lfit_right:
    fmin d2, d2, d3
Lfit_next:
    add x7, x7, #1
    b Lfit_obstacle
Lfit_available:
    fsub d3, d2, d0
    fcmp d3, d16
    b.ge Lfit_place
    fcmp d7, #0.0
    b.le Lfit_place
    cmp x6, x2
    b.hs Lfit_place
    fmov d1, d7
    add x6, x6, #1
    b Lfit_band
Lfit_place:
    cmp x5, #2
    b.ne Lfit_done
    fsub d0, d2, d16
Lfit_done:
    ret

// records*, context, character offset, clear sides -> measured bottom d0.
.globl _engine_float_clear_bottom
_engine_float_clear_bottom:
    fmov d0, xzr
    cbz x0, Lclear_bottom_done
    ldr x4, [x0]
    add x0, x0, #8
Lclear_bottom_next:
    cbz x4, Lclear_bottom_done
    ldr x5, [x0, #48]
    cbz x5, Lclear_bottom_advance
    ldr x5, [x0, #120]
    cmp x5, x1
    b.ne Lclear_bottom_advance
    ldr x5, [x0, #8]
    cmp x5, x2
    b.hi Lclear_bottom_advance
    ldr x5, [x0, #56]
    tst x5, x3
    b.eq Lclear_bottom_advance
    ldr d1, [x0, #24]
    ldr d2, [x0, #40]
    fadd d1, d1, d2
    fmax d0, d0, d1
Lclear_bottom_advance:
    add x0, x0, #128
    sub x4, x4, #1
    b Lclear_bottom_next
Lclear_bottom_done:
    ret

// records,context,source position,clear sides; available rect left/top/
// width in d0..d2 and requested outer width d3. Returns fitted origin d0/d1.
// Source offsets use the same units as the caller's records (UTF-16 or UTF-8).
// The query is stack-owned; source bounds exclude future records independently
// of allocation order. Existing float records are never changed.
.globl _engine_float_avoid
CORE_C_ABI_ARGS _engine_float_avoid, 4
_engine_float_avoid:
    sub sp, sp, #160
    str x30, [sp, #144]
    str x2, [sp]
    str d3, [sp, #32]
    mov x9, #64
    str x9, [sp, #56]
    str x1, [sp, #120]
    mov x1, sp
    mov x2, x3
    bl _engine_float_fit
    ldr x30, [sp, #144]
    add sp, sp, #160
    ret
