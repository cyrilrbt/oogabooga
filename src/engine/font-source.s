// Select the next TrueType/OpenType URL from a font-face src list. Local fonts,
// WOFF/Brotli containers and escaped URLs are outside this initial codec subset.
.include "src/mac/mac.inc"
.text
.p2align 2
// src bytes,length,offset,out{owned URL*,nextOffset} -> BOOL.
.globl _engine_css_font_source_next
_engine_css_font_source_next:
    ENTER
    mov x19, x0
    mov x21, x3
    cbz x0, Lfont_source_none
    cmp x1, #2048
    b.hi Lfont_source_none
    cmp x2, x1
    b.hs Lfont_source_none
    add x20, x0, x1
    add x22, x0, x2
    stp xzr, xzr, [x21]
Lfont_source_candidate:
    mov x0, x22
    mov x1, x20
    bl _css_skip
    mov x22, x0
    cmp x22, x20
    b.hs Lfont_source_none
    mov x1, x20
    mov x2, #44
    bl _css_selector_boundary
    mov x23, x0
    add x24, x23, #1
    mov x0, x22
    mov x1, x23
    bl _css_trim
    mov x22, x0
    mov x23, x1
    sub x9, x23, x22
    cmp x9, #5
    b.lo Lfont_source_advance
    mov x0, x22
    ADDR x1, font_url_keyword
    mov x2, #4
    bl _strncasecmp
    cbnz x0, Lfont_source_advance
    add x0, x22, #4
    mov x1, x23
    bl _css_skip
    mov x25, x0
    cmp x25, x23
    b.hs Lfont_source_advance
    ldrb w9, [x25]
    mov x26, x25
    cmp w9, #34
    b.eq Lfont_source_quote
    cmp w9, #39
    b.eq Lfont_source_quote
Lfont_source_raw:
    cmp x26, x23
    b.hs Lfont_source_advance
    ldrb w9, [x26]
    cmp w9, #41
    b.eq Lfont_source_raw_end
    cmp w9, #92
    b.eq Lfont_source_advance
    cmp w9, #34
    b.eq Lfont_source_advance
    cmp w9, #39
    b.eq Lfont_source_advance
    cmp w9, #40
    b.eq Lfont_source_advance
    add x26, x26, #1
    b Lfont_source_raw
Lfont_source_raw_end:
    add x27, x26, #1
    mov x0, x25
    mov x1, x26
    bl _css_trim
    mov x25, x0
    mov x26, x1
    // CSS raw URL tokens cannot contain whitespace.
    mov x9, x25
Lfont_source_raw_validate:
    cmp x9, x26
    b.hs Lfont_source_tail
    ldrb w10, [x9], #1
    cmp w10, #32
    b.ls Lfont_source_advance
    b Lfont_source_raw_validate
Lfont_source_quote:
    add x25, x25, #1
    mov x26, x25
    mov x28, x9
Lfont_source_quoted_next:
    cmp x26, x23
    b.hs Lfont_source_advance
    ldrb w9, [x26]
    cmp w9, w28
    b.eq Lfont_source_quoted_end
    cmp w9, #32
    b.lo Lfont_source_advance
    cmp w9, #92
    b.eq Lfont_source_advance
    add x26, x26, #1
    b Lfont_source_quoted_next
Lfont_source_quoted_end:
    add x0, x26, #1
    mov x1, x23
    bl _css_skip
    cmp x0, x23
    b.hs Lfont_source_advance
    ldrb w9, [x0], #1
    cmp w9, #41
    b.ne Lfont_source_advance
    mov x27, x0
Lfont_source_tail:
    cmp x25, x26
    b.hs Lfont_source_advance
    mov x0, x27
    mov x1, x23
    bl _css_skip
    cmp x0, x23
    b.hs Lfont_source_copy
    mov x27, x0
    sub x9, x23, x27
    cmp x9, #9
    b.lo Lfont_source_advance
    ADDR x1, font_format_keyword
    mov x2, #7
    bl _strncasecmp
    cbnz x0, Lfont_source_advance
    sub x9, x23, #1
    ldrb w10, [x9]
    cmp w10, #41
    b.ne Lfont_source_advance
    add x0, x27, #7
    mov x1, x9
    bl _css_trim
    cmp x0, x1
    b.hs Lfont_source_advance
    ldrb w9, [x0]
    cmp w9, #34
    b.eq Lfont_format_unquote
    cmp w9, #39
    b.ne Lfont_format_compare
Lfont_format_unquote:
    sub x10, x1, #1
    ldrb w11, [x10]
    cmp w9, w11
    b.ne Lfont_source_advance
    add x0, x0, #1
    mov x1, x10
Lfont_format_compare:
    stp x0, x1, [sp, #144]
    ADDR x2, font_truetype
    bl _css_eq
    cbnz x0, Lfont_source_copy
    ldp x0, x1, [sp, #144]
    ADDR x2, font_opentype
    bl _css_eq
    cbz x0, Lfont_source_advance
Lfont_source_copy:
    mov x0, x25
    sub x1, x26, x25
    bl _strndup
    cbz x0, Lfont_source_none
    str x0, [x21]
    sub x9, x24, x19
    str x9, [x21, #8]
    mov x0, #1
    LEAVE
Lfont_source_advance:
    mov x22, x24
    cmp x22, x20
    b.lo Lfont_source_candidate
Lfont_source_none:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
font_url_keyword: .asciz "url("
font_format_keyword: .asciz "format("
font_truetype: .asciz "truetype"
font_opentype: .asciz "opentype"
