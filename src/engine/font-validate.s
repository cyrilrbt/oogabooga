// Preflight uncompressed SFNT bounds before the native font codec. WOFF/TTC and
// huge glyph sets are deferred; no compressed-font allocation reaches the codec.
.text
.p2align 2
.globl _engine_font_validate
_engine_font_validate:
    cbz x0, Lfont_invalid
    cmp x1, #12
    b.lo Lfont_invalid
    mov x2, #2097152
    cmp x1, x2
    b.hi Lfont_invalid
    ldr w2, [x0]
    cmp w2, #256                 // big-endian 0x00010000
    b.eq Lfont_tables
    mov w3, #0x544f
    movk w3, #0x4f54, lsl #16     // OTTO
    cmp w2, w3
    b.ne Lfont_invalid
Lfont_tables:
    ldrh w2, [x0, #4]
    rev16 w2, w2
    cbz w2, Lfont_invalid
    cmp w2, #128
    b.hi Lfont_invalid
    lsl x3, x2, #4
    add x3, x3, #12
    cmp x3, x1
    b.hi Lfont_invalid
    add x4, x0, #12
    mov x5, #0
Lfont_table:
    cbz x2, Lfont_tables_done
    ldr w6, [x4, #8]
    rev w6, w6
    ldr w7, [x4, #12]
    rev w7, w7
    cmp x6, x3
    b.lo Lfont_invalid
    add x8, x6, x7
    cmp x8, x1
    b.hi Lfont_invalid
    ldr w8, [x4]
    mov w9, #0x616d
    movk w9, #0x7078, lsl #16     // maxp
    cmp w8, w9
    b.ne Lfont_table_next
    cmp x7, #6
    b.lo Lfont_invalid
    add x6, x0, x6
    ldrh w7, [x6, #4]
    rev16 w7, w7
    cbz w7, Lfont_invalid
    cmp w7, #8192
    b.hi Lfont_invalid
    mov x5, #1
Lfont_table_next:
    add x4, x4, #16
    sub x2, x2, #1
    b Lfont_table
Lfont_tables_done:
    mov x0, x5
    ret
Lfont_invalid:
    mov x0, #0
    ret
