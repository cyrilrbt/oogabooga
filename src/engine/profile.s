// Local, opt-in profiling; no telemetry, files, or network transmission.
.include "src/mac/mac.inc"
.include "src/engine/profile.inc"
.text
.p2align 2
.globl _engine_profile_now
_engine_profile_now:
    mov x0, #4                    // CLOCK_MONOTONIC_RAW, Darwin time.h
    b _clock_gettime_nsec_np
// stage, start timestamp, nested cost to exclude.
.globl _engine_profile_end
_engine_profile_end:
    cmp x0, #8
    b.hs Lprofile_return
    cbz x1, Lprofile_return
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _engine_profile_now
    sub x0, x0, x20
    subs x0, x0, x21
    csel x0, xzr, x0, lo
    ADDR x9, _engine_profile_totals
    ldr x10, [x9, x19, lsl #3]
    add x10, x10, x0
    str x10, [x9, x19, lsl #3]
    ADDR x9, _engine_profile_counts
    ldr x10, [x9, x19, lsl #3]
    add x10, x10, #1
    str x10, [x9, x19, lsl #3]
    LEAVE
Lprofile_return:
    ret
.globl _engine_profile_reset
_engine_profile_reset:
    ADDR x0, _engine_profile_totals
    mov x1, #0
    mov x2, #128
    b _memset
PROFILE_WRAP _engine_parse, _engine_parse_impl, 0
PROFILE_WRAP _engine_css_apply, _engine_css_apply_impl, 1
PROFILE_WRAP _engine_box_tree, _engine_box_tree_impl, 2
PROFILE_WRAP _engine_flow_tree, _engine_flow_tree_impl, 2
PROFILE_WRAP _engine_float_tree, _engine_float_tree_impl, 2
.section __DATA,__bss
.p2align 3
.globl _engine_profile_enabled, _engine_profile_totals, _engine_profile_counts
_engine_profile_enabled: .space 8
_engine_profile_totals: .space 64
_engine_profile_counts: .space 64
