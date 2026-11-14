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

.text
# int history_search(db, query, callback, context); callback(context,url,title,date,id).
.globl history_search
.type history_search,@function
history_search:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    lea rsi, [rip + search_sql]
    mov edx, -1
    lea rcx, [rbp - 48]
    xor r8d, r8d
    call sqlite3_prepare_v2@PLT
    test eax, eax
    jnz .Lsearch_return
    mov rbx, [rbp - 48]
    mov rdi, rbx
    mov esi, 1
    mov rdx, r12
    mov ecx, -1
    mov r8, -1
    call sqlite3_bind_text@PLT
    test eax, eax
    jnz .Lsearch_finalize
.Lsearch_next:
    mov rdi, rbx
    call sqlite3_step@PLT
    cmp eax, 100
    jne .Lsearch_end
    mov rdi, rbx
    xor esi, esi
    call sqlite3_column_text@PLT
    mov [rbp - 56], rax
    mov rdi, rbx
    mov esi, 1
    call sqlite3_column_text@PLT
    mov [rbp - 64], rax
    mov rdi, rbx
    mov esi, 2
    call sqlite3_column_text@PLT
    mov [rbp - 72], rax
    mov rdi, rbx
    mov esi, 3
    call sqlite3_column_int64@PLT
    mov r8, rax
    mov rdi, r14
    mov rsi, [rbp - 56]
    mov rdx, [rbp - 64]
    mov rcx, [rbp - 72]
    call r13
    jmp .Lsearch_next
.Lsearch_end:
    xor edx, edx
    cmp eax, 101
    cmove eax, edx
.Lsearch_finalize:
    mov r15d, eax
    mov rdi, rbx
    call sqlite3_finalize@PLT
    mov eax, r15d
.Lsearch_return:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.size history_search,.-history_search

.globl history_update_title
.type history_update_title,@function
history_update_title:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov r12, rsi
    mov r13, rdx
    lea rsi, [rip + update_sql]
    mov edx, -1
    lea rcx, [rbp - 40]
    xor r8d, r8d
    call sqlite3_prepare_v2@PLT
    test eax, eax
    jnz .Lupdate_return
    mov rbx, [rbp - 40]
    mov rdi, rbx
    mov esi, 1
    mov rdx, r13
    mov ecx, -1
    mov r8, -1
    call sqlite3_bind_text@PLT
    test eax, eax
    jnz .Lupdate_finalize
    mov rdi, rbx
    mov esi, 2
    mov rdx, r12
    call sqlite3_bind_int64@PLT
    test eax, eax
    jnz .Lupdate_finalize
    mov rdi, rbx
    call sqlite3_step@PLT
    xor edx, edx
    cmp eax, 101
    cmove eax, edx
.Lupdate_finalize:
    mov r14d, eax
    mov rdi, rbx
    call sqlite3_finalize@PLT
    mov eax, r14d
.Lupdate_return:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.size history_update_title,.-history_update_title
