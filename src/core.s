// Apple silicon, Darwin ABI. SQLite owns storage; all text uses bound parameters.
.text
.p2align 2
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

.text
.p2align 2
// int history_search(db, query, callback, context).
// callback(context, url, title, local_date, id); strings are borrowed for that call.
// Returns SQLITE_OK only after all rows have been delivered successfully.
.globl _history_search
_history_search:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x1
    mov x20, x2
    mov x21, x3
    adrp x1, search_sql@PAGE
    add x1, x1, search_sql@PAGEOFF
    mov w2, #-1
    add x3, sp, #80
    mov x4, #0
    bl _sqlite3_prepare_v2
    cbnz w0, Lsearch_return
    ldr x22, [sp, #80]
    mov x0, x22
    mov w1, #1
    mov x2, x19
    mov w3, #-1
    mov x4, #-1
    bl _sqlite3_bind_text
    cbnz w0, Lsearch_finalize
Lsearch_next:
    mov x0, x22
    bl _sqlite3_step
    cmp w0, #100
    b.ne Lsearch_end
    mov x0, x22
    mov w1, #0
    bl _sqlite3_column_text
    mov x23, x0
    mov x0, x22
    mov w1, #1
    bl _sqlite3_column_text
    mov x24, x0
    mov x0, x22
    mov w1, #2
    bl _sqlite3_column_text
    mov x25, x0
    mov x0, x22
    mov w1, #3
    bl _sqlite3_column_int64
    mov x4, x0
    mov x0, x21
    mov x1, x23
    mov x2, x24
    mov x3, x25
    blr x20
    b Lsearch_next
Lsearch_end:
    cmp w0, #101
    csel w0, wzr, w0, eq
Lsearch_finalize:
    mov w26, w0
    mov x0, x22
    bl _sqlite3_finalize
    mov w0, w26
Lsearch_return:
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// int history_update_title(db, id, title). Never changes another visit with the same URL.
.globl _history_update_title
_history_update_title:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x1
    mov x20, x2
    adrp x1, update_sql@PAGE
    add x1, x1, update_sql@PAGEOFF
    mov w2, #-1
    add x3, sp, #48
    mov x4, #0
    bl _sqlite3_prepare_v2
    cbnz w0, Lupdate_return
    ldr x21, [sp, #48]
    mov x0, x21
    mov w1, #1
    mov x2, x20
    mov w3, #-1
    mov x4, #-1
    bl _sqlite3_bind_text
    cbnz w0, Lupdate_finalize
    mov x0, x21
    mov w1, #2
    mov x2, x19
    bl _sqlite3_bind_int64
    cbnz w0, Lupdate_finalize
    mov x0, x21
    bl _sqlite3_step
    cmp w0, #101
    csel w0, wzr, w0, eq
Lupdate_finalize:
    mov w22, w0
    mov x0, x21
    bl _sqlite3_finalize
    mov w0, w22
Lupdate_return:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
