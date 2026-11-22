// Same instruction/ABI probes run natively on macOS ARM64 and Linux x86-64.
.include "src/mac/mac.inc"
.text
CORE_C_ABI_ARGS _backend_eight, 8
.p2align 2
.globl _backend_eight
_backend_eight:
    add x0, x0, x1
    add x0, x0, x2
    add x0, x0, x3
    add x0, x0, x4
    add x0, x0, x5
    add x0, x0, x6
    add x0, x0, x7
    ret
.globl _backend_pair
_backend_pair:
    mov x9, x0
    add x0, x0, x1
    sub x1, x9, x1
    ret
.globl _backend_flags
_backend_flags:
    cmp x0, x1
    add x9, x2, #3
    cset x0, lo
    ret
.globl _backend_carry
_backend_carry:
    adds x0, x0, x1
    cset x0, hs
    ret
.globl _backend_cmn
_backend_cmn:
    cmn x0, #1
    cset x0, hs
    ret
.globl _backend_word
_backend_word:
    mov w0, #-1
    lsr x0, x0, #32
    ret
.globl _backend_shift
_backend_shift:
    lsl x0, x0, x1
    add x0, x0, x3
    ret
.globl _backend_div
_backend_div:
    sdiv x0, x0, x1
    ret
.globl _backend_udiv
_backend_udiv:
    udiv x0, x0, x1
    ret
.globl _backend_rev16
_backend_rev16:
    rev16 x0, x0
    ret
.globl _backend_reverse
_backend_reverse:
    rev x0, x0
    ret
.globl _backend_convert
_backend_convert:
    fcvtzs x0, d0
    ret
.globl _backend_max
_backend_max:
    fmax d0, d0, d1
    ret
.globl _backend_min
_backend_min:
    fmin d0, d0, d1
    ret
.globl _backend_unordered
_backend_unordered:
    fcmp d0, d1
    cset x0, vs
    ret
.globl _backend_saved
_backend_saved:
    ENTER
    mov x19, x0
    mov x24, x1
    mov x28, x2
    bl _backend_helper
    add x0, x19, x24
    add x0, x0, x28
    LEAVE
_backend_helper:
    ENTER
    mov x19, #100
    mov x24, #200
    mov x28, #300
    LEAVE
.globl _backend_native
_backend_native:
    ENTER
    mov x24, x1
    bl _strlen
    add x0, x0, x24
    LEAVE
.globl _backend_tail
_backend_tail:
    b _strlen
.globl _backend_fused
_backend_fused:
    fmadd d0, d0, d1, d2
    ret
.globl _backend_sqrt
_backend_sqrt:
    fsqrt d0, d0
    ret
.globl _backend_insert
_backend_insert:
    bfi x0, x1, #8, #16
    ret

.globl _backend_floor
_backend_floor:
    frintm d0, d0
    ret
