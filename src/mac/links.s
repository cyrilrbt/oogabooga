// Resolve link visit state against SQLite history before computing CSS.
// One prepared statement per render; bind URL bytes, never interpolate SQL.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_link_states
_mac_link_states:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #0
    mov x22, #0                     // any state changed
    str xzr, [sp, #144]
    LOAD x0, _mac_db
    cbz x0, Llinks_begin
    ADDR x1, visited_query
    mov w2, #-1
    add x3, sp, #144
    mov x4, #0
    bl _sqlite3_prepare_v2
Llinks_begin:
    ldr x23, [sp, #144]
Llinks_next:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Llinks_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x21, x10, x9
    ldr x10, [x9]
    cmp x10, #6
    b.ne Llinks_advance
    ldr x24, [x19, #72]
    add x24, x24, x21, lsl #10
    mov x25, #0
    ldr x0, [x9, #32]
    cbz x0, Llinks_store
    cbz x23, Llinks_store
    bl _mac_string
    mov x26, x0
    CLASS NSURL
    mov x2, x26
    mov x3, x20
    MSG relativeURL
    MSG absoluteURL
    mov x26, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Llinks_store
    mov x0, x26
    MSG absoluteString
    MSG UTF8String
    mov x2, x0
    mov x0, x23
    mov w1, #1
    mov w3, #-1
    mov x4, #-1
    bl _sqlite3_bind_text
    cbnz w0, Llinks_reset
    mov x0, x23
    bl _sqlite3_step
    cmp w0, #100                    // SQLITE_ROW
    cset x25, eq
Llinks_reset:
    mov x0, x23
    bl _sqlite3_reset
Llinks_store:
    ldr x9, [x24, #864]
    cmp x9, x25
    cset x10, ne
    orr x22, x22, x10
    str x25, [x24, #864]
Llinks_advance:
    add x21, x21, #1
    b Llinks_next
Llinks_done:
    mov x0, x23
    bl _sqlite3_finalize
    mov x0, x22
    LEAVE
.section __TEXT,__cstring,cstring_literals
visited_query: .asciz "SELECT 1 FROM visits WHERE url=?1 LIMIT 1"
