// Apple silicon, Darwin ABI. SQLite owns storage; all text uses bound parameters.
.text
.p2align 2
.globl _main
_main:
    b _browser_main

// int history_open(const char *path, sqlite3 **out)
.globl _history_open
_history_open:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl _sqlite3_open
    cbnz w0, 1f
    ldr x0, [x19]
    adrp x1, schema@PAGE
    add x1, x1, schema@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x4, #0
    bl _sqlite3_exec
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int history_add(sqlite3 *db, const char *url, const char *title)
.globl _history_add
_history_add:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x1
    mov x20, x2
    adrp x1, insert_sql@PAGE
    add x1, x1, insert_sql@PAGEOFF
    mov w2, #-1
    add x3, sp, #48
    mov x4, #0
    bl _sqlite3_prepare_v2
    cbnz w0, 2f
    ldr x21, [sp, #48]
    mov x0, x21
    mov w1, #1
    mov x2, x19
    mov w3, #-1
    mov x4, #-1
    bl _sqlite3_bind_text
    cbnz w0, 3f
    mov x0, x21
    mov w1, #2
    mov x2, x20
    mov w3, #-1
    mov x4, #-1
    bl _sqlite3_bind_text
    cbnz w0, 3f
    mov x0, x21
    bl _sqlite3_step
    cmp w0, #101 // SQLITE_DONE
    csel w0, wzr, w0, eq
3:  mov w22, w0
    mov x0, x21
    bl _sqlite3_finalize
    mov w0, w22
2:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
.section __TEXT,__cstring,cstring_literals
.include "src/history.inc"
