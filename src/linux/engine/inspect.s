# Headless native-core probe. No GTK/WebKit, network, or C implementation.
# Usage: engine-inspect FILE [COLUMNS]; write wrapped UTF-8 flow to stdout.
.intel_syntax noprefix
.text
.p2align 4
.globl main
.type main, @function
main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
    xor r12d, r12d                # FILE
    xor r13d, r13d                # source
    xor r14d, r14d                # document
    xor r15d, r15d                # layout
    mov [rbp - 56], rsi
    mov qword ptr [rbp - 64], 100
    mov dword ptr [rbp - 72], 1
    cmp edi, 2
    je .Linspect_open
    cmp edi, 3
    jne .Linspect_usage
    mov rdi, [rsi + 16]
    lea rsi, [rbp - 48]
    mov edx, 10
    call strtol@PLT
    mov rcx, [rbp - 48]
    cmp byte ptr [rcx], 0
    jne .Linspect_usage
    cmp rax, 8
    jl .Linspect_usage
    cmp rax, 240
    jg .Linspect_usage
    mov [rbp - 64], rax
.Linspect_open:
    mov rax, [rbp - 56]
    mov rdi, [rax + 8]
    lea rsi, [rip + inspect_read_mode]
    call fopen@PLT
    test rax, rax
    je .Linspect_error
    mov r12, rax
    mov rdi, r12
    xor esi, esi
    mov edx, 2
    call fseek@PLT
    test eax, eax
    jne .Linspect_error
    mov rdi, r12
    call ftell@PLT
    test rax, rax
    js .Linspect_error
    cmp rax, 1048576
    ja .Linspect_error
    mov rbx, rax
    mov rdi, r12
    xor esi, esi
    xor edx, edx
    call fseek@PLT
    test eax, eax
    jne .Linspect_error
    lea rdi, [rbx + 1]
    call malloc@PLT
    test rax, rax
    je .Linspect_error
    mov r13, rax
    mov rdi, r13
    mov esi, 1
    mov rdx, rbx
    mov rcx, r12
    call fread@PLT
    cmp rax, rbx
    jne .Linspect_error
    mov byte ptr [r13 + rbx], 0
    mov rdi, r12
    call fclose@PLT
    xor r12d, r12d
    mov rdi, r13
    mov rsi, rbx
    call engine_parse
    test rax, rax
    je .Linspect_error
    mov r14, rax
    mov rdi, r14
    mov rsi, [rbp - 64]
    call engine_layout
    test rax, rax
    je .Linspect_error
    mov r15, rax
    mov rdi, [r15]
    mov esi, 1
    mov rdx, [r15 + 8]
    mov rcx, [rip + stdout]
    call fwrite@PLT
    cmp rax, [r15 + 8]
    jne .Linspect_error
    mov dword ptr [rbp - 72], 0
    jmp .Linspect_cleanup
.Linspect_usage:
    mov dword ptr [rbp - 72], 2
    lea rdi, [rip + inspect_usage]
    jmp .Linspect_message
.Linspect_error:
    lea rdi, [rip + inspect_error]
.Linspect_message:
    mov rsi, [rip + stderr]
    call fputs@PLT
.Linspect_cleanup:
    test r15, r15
    je .Linspect_free_document
    mov rdi, r15
    call engine_layout_free
.Linspect_free_document:
    test r14, r14
    je .Linspect_free_source
    mov rdi, r14
    call engine_document_free
.Linspect_free_source:
    mov rdi, r13
    call free@PLT
    test r12, r12
    je .Linspect_done
    mov rdi, r12
    call fclose@PLT
.Linspect_done:
    mov eax, [rbp - 72]
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.size main, .-main
.section .rodata
inspect_read_mode: .asciz "rb"
inspect_usage: .asciz "Usage: engine-inspect FILE [COLUMNS: 8..240]\n"
inspect_error: .asciz "engine-inspect: cannot read/parse/layout file (maximum HTML size: 1 MiB)\n"
.section .note.GNU-stack,"",@progbits
