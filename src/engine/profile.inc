// Opt-in nanosecond timing. Disabled path is one flag test and a tail branch.
.macro PROFILE_WRAP name, impl, stage
.globl \name
\name:
    LOAD x9, _engine_profile_enabled
    cbz x9, 9f
    ENTER
    stp x0, x1, [sp, #144]
    stp x2, x3, [sp, #160]
    stp d0, d1, [sp, #176]
    ADDR x9, _engine_profile_totals
    ldr x20, [x9, #8]              // nested CSS cost for parser exclusivity
    bl _engine_profile_now
    mov x19, x0
    ldp x0, x1, [sp, #144]
    ldp x2, x3, [sp, #160]
    ldp d0, d1, [sp, #176]
    bl \impl
    str x0, [sp, #192]
    mov x0, #\stage
    mov x1, x19
    mov x2, #0
.if \stage == 0
    ADDR x9, _engine_profile_totals
    ldr x2, [x9, #8]
    sub x2, x2, x20
.endif
    bl _engine_profile_end
    ldr x0, [sp, #192]
    LEAVE
9:
    b \impl
.endm
