.include "src/mac/mac.inc"
.include "src/engine/profile.inc"
.text
.p2align 2
PROFILE_WRAP _mac_flow_measure, _mac_flow_measure_impl, 3
PROFILE_WRAP _mac_display_compile, _mac_display_compile_impl, 5
PROFILE_WRAP _mac_display_background, _mac_display_background_impl, 6
PROFILE_WRAP _mac_display_glyphs, _mac_display_glyphs_impl, 6
// Display total (7), with native attribute/text layout excluding child phases (4).
.globl _mac_engine_display
_mac_engine_display:
    LOAD x9, _engine_profile_enabled
    cbz x9, Ldisplay_unprofiled
    ENTER
    mov x19, x0
    mov x20, x1
    ADDR x9, _engine_profile_totals
    ldr x21, [x9, #8]
    ldr x10, [x9, #16]
    add x21, x21, x10
    ldr x10, [x9, #24]
    add x21, x21, x10
    ldr x10, [x9, #40]
    add x21, x21, x10
    bl _engine_profile_now
    mov x22, x0
    mov x0, x19
    mov x1, x20
    bl _mac_engine_display_impl
    mov x23, x0
    mov x0, #7
    mov x1, x22
    mov x2, #0
    bl _engine_profile_end
    ADDR x9, _engine_profile_totals
    ldr x2, [x9, #8]
    ldr x10, [x9, #16]
    add x2, x2, x10
    ldr x10, [x9, #24]
    add x2, x2, x10
    ldr x10, [x9, #40]
    add x2, x2, x10
    sub x2, x2, x21
    mov x0, #4
    mov x1, x22
    bl _engine_profile_end
    mov x0, x23
    LEAVE
Ldisplay_unprofiled:
    b _mac_engine_display_impl
