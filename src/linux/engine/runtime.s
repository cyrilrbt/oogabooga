# Native System V shim for the shared engine's opt-in nanosecond profiler.
.intel_syntax noprefix
.text
.p2align 4
.globl oogabooga_clock_gettime_nsec
.type oogabooga_clock_gettime_nsec, @function
oogabooga_clock_gettime_nsec:
    sub rsp, 24
    mov edi, 1                      # Linux CLOCK_MONOTONIC
    mov rsi, rsp
    call clock_gettime@PLT
    test eax, eax
    jne .Lclock_failed
    mov rax, [rsp]
    imul rax, rax, 1000000000
    add rax, [rsp + 8]
    add rsp, 24
    ret
.Lclock_failed:
    xor eax, eax
    add rsp, 24
    ret
.size oogabooga_clock_gettime_nsec, .-oogabooga_clock_gettime_nsec
.section .note.GNU-stack,"",@progbits
