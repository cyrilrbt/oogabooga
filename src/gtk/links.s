// One indexed, bound SQLite statement per render; website link colors remain CSS.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_link_states
_gtk_link_states:
    ENTER
    mov x19, x0
    str xzr, [sp, #144]
    bl _gtk_engine_database
    cbz x0, Lgtk_links_begin
    ADDR x1, gtk_visited_query
    mov x2, #-1
    add x3, sp, #144
    mov x4, #0
    bl _sqlite3_prepare_v2
Lgtk_links_begin:
    ldr x20, [sp, #144]
    mov x21, #1
Lgtk_links_next:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lgtk_links_done
    mov x0, x21
    bl _gtk_engine_node
    mov x22, x0
    ldr x9, [x2]
    cmp x9, #NODE_A
    b.ne Lgtk_links_advance
    str xzr, [x22, #864]
    cbz x20, Lgtk_links_advance
    ldr x1, [x2, #32]
    cbz x1, Lgtk_links_advance
    LOAD x0, _gtk_base
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    cbz x0, Lgtk_links_advance
    mov x23, x0
    mov x2, x0
    mov x0, x20
    mov x1, #1
    mov x3, #-1
    mov x4, #-1
    bl _sqlite3_bind_text
    cbnz w0, Lgtk_links_reset
    mov x0, x20
    bl _sqlite3_step
    cmp w0, #100
    cset x9, eq
    str x9, [x22, #864]
Lgtk_links_reset:
    mov x0, x20
    bl _sqlite3_reset
    mov x0, x23
    bl _g_free
Lgtk_links_advance:
    add x21, x21, #1
    b Lgtk_links_next
Lgtk_links_done:
    mov x0, x20
    bl _sqlite3_finalize
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_visited_query: .asciz "SELECT 1 FROM visits WHERE url=?1 LIMIT 1"
