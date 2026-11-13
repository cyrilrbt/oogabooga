# Linux x86-64 System V ABI. Handwritten SQLite core; position independent.
.intel_syntax noprefix
.text
.globl main
.type main,@function
main:
    jmp browser_main
.size main,.-main

.globl history_open
.type history_open,@function
history_open:
    push rbx
    mov rbx, rsi
    call sqlite3_open@PLT
    test eax, eax
    jnz .Lopen_done
    mov rdi, [rbx]
    lea rsi, [rip + schema]
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    call sqlite3_exec@PLT
.Lopen_done:
    pop rbx
    ret
.size history_open,.-history_open

.globl history_add
.type history_add,@function
history_add:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov r12, rsi
    mov r13, rdx
    lea rsi, [rip + insert_sql]
    mov edx, -1
    lea rcx, [rbp - 40]
    xor r8d, r8d
    call sqlite3_prepare_v2@PLT
    test eax, eax
    jnz .Ladd_done
    mov rbx, [rbp - 40]
    mov rdi, rbx
    mov esi, 1
    mov rdx, r12
    mov ecx, -1
    mov r8, -1
    call sqlite3_bind_text@PLT
    test eax, eax
    jnz .Lfinalize
    mov rdi, rbx
    mov esi, 2
    mov rdx, r13
    mov ecx, -1
    mov r8, -1
    call sqlite3_bind_text@PLT
    test eax, eax
    jnz .Lfinalize
    mov rdi, rbx
    call sqlite3_step@PLT
    xor edx, edx
    cmp eax, 101
    cmove eax, edx
.Lfinalize:
    mov r14d, eax
    mov rdi, rbx
    call sqlite3_finalize@PLT
    mov eax, r14d
.Ladd_done:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.size history_add,.-history_add
.section .rodata
.include "src/history.inc"
.section .note.GNU-stack,"",@progbits
