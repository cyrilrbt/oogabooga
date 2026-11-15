// Top-of-sheet @import scanner. Strings remain owned by the returned record;
// source offsets let expansion preserve cascade order without reparsing rules.
.include "src/mac/mac.inc"
.text
.p2align 2
// source,length,offset,out[5 qwords] -> BOOL. out = URL*,media*,start,end,next.
// The loader bounds recursion, requests and bytes separately from this parser.
.globl _engine_css_import_next
_engine_css_import_next:
    ENTER
    mov x19, x0
    cbz x19, Limport_none
    mov x9, #1048576
    cmp x1, x9
    b.hi Limport_none
    add x20, x0, x1
    mov x21, x3
    cmp x2, x1
    b.hs Limport_none
    add x22, x19, x2
    stp xzr, xzr, [x21]
    stp xzr, xzr, [x21, #16]
    str xzr, [x21, #32]
Limport_header:
    mov x0, x22
    mov x1, x20
    bl _css_skip
    mov x22, x0
    cmp x22, x20
    b.hs Limport_none
    sub x9, x20, x22
    cmp x9, #8
    b.lo Limport_none
    mov x0, x22
    ADDR x1, import_keyword
    mov x2, #7
    bl _strncasecmp
    cbz x0, Limport_keyword
    mov x0, x22
    ADDR x1, charset_keyword
    mov x2, #8
    bl _strncasecmp
    cbnz x0, Limport_none        // imports after an ordinary rule are invalid
    add x23, x22, #8
    b Limport_charset
Limport_keyword:
    ldrb w9, [x22, #7]
    cmp w9, #32
    b.ls Limport_after_keyword
    cmp w9, #34
    b.eq Limport_after_keyword
    cmp w9, #39
    b.eq Limport_after_keyword
    cmp w9, #47
    b.ne Limport_none
Limport_after_keyword:
    add x23, x22, #7
    mov x0, x23
    mov x1, x20
    bl _css_skip
    mov x23, x0
    cmp x23, x20
    b.hs Limport_none
    mov x24, #0                 // url() wrapper
    ldrb w25, [x23]
    cmp w25, #34
    b.eq Limport_quoted
    cmp w25, #39
    b.eq Limport_quoted
    sub x9, x20, x23
    cmp x9, #4
    b.lo Limport_none
    mov x0, x23
    ADDR x1, url_keyword
    mov x2, #4
    bl _strncasecmp
    cbnz x0, Limport_none
    mov x24, #1
    add x0, x23, #4
    mov x1, x20
    bl _css_skip
    mov x23, x0
    cmp x23, x20
    b.hs Limport_none
    ldrb w25, [x23]
    cmp w25, #34
    b.eq Limport_quoted
    cmp w25, #39
    b.eq Limport_quoted
    mov x26, x23
Limport_unquoted:
    cmp x26, x20
    b.hs Limport_none
    ldrb w9, [x26]
    cmp w9, #41
    b.eq Limport_unquoted_end
    cmp w9, #32
    b.ls Limport_unquoted_space
    cmp w9, #92
    b.eq Limport_none            // escaped URLs require the future CSS tokenizer
    cmp w9, #34
    b.eq Limport_none
    cmp w9, #39
    b.eq Limport_none
    cmp w9, #40
    b.eq Limport_none
    add x26, x26, #1
    b Limport_unquoted
Limport_unquoted_space:
    mov x0, x26
    mov x1, x20
    bl _css_skip
    mov x27, x0
    cmp x27, x20
    b.hs Limport_none
    ldrb w9, [x27]
    cmp w9, #41
    b.ne Limport_none
    add x27, x27, #1
    b Limport_url_ready
Limport_unquoted_end:
    add x27, x26, #1
    b Limport_url_ready
Limport_quoted:
    add x23, x23, #1
    mov x26, x23
Limport_quote_next:
    cmp x26, x20
    b.hs Limport_none
    ldrb w9, [x26]
    cmp w9, w25
    b.eq Limport_quote_end
    cmp w9, #32
    b.lo Limport_none
    cmp w9, #92
    b.eq Limport_none
    add x26, x26, #1
    b Limport_quote_next
Limport_quote_end:
    add x27, x26, #1
    cbz x24, Limport_url_ready
    mov x0, x27
    mov x1, x20
    bl _css_skip
    mov x27, x0
    cmp x27, x20
    b.hs Limport_none
    ldrb w9, [x27], #1
    cmp w9, #41
    b.ne Limport_none
Limport_url_ready:
    sub x9, x26, x23
    cbz x9, Limport_none
    cmp x9, #4096
    b.hi Limport_none
    mov x0, x27
    mov x1, x20
    bl _css_skip
    mov x27, x0               // media start
    mov x28, x0
    mov x24, #0               // media parentheses
Limport_media:
    cmp x28, x20
    b.hs Limport_none
    ldrb w9, [x28]
    cmp w9, #47
    b.ne Limport_media_character
    add x9, x28, #1
    cmp x9, x20
    b.hs Limport_none
    ldrb w9, [x9]
    cmp w9, #42
    b.ne Limport_media_character
    mov x0, x28
    mov x1, x20
    bl _css_skip
    mov x28, x0
    b Limport_media
Limport_media_character:
    ldrb w9, [x28]
    cmp w9, #59
    b.eq Limport_semicolon
    cmp w9, #123
    b.eq Limport_none
    cmp w9, #125
    b.eq Limport_none
    cmp w9, #34
    b.eq Limport_none
    cmp w9, #39
    b.eq Limport_none
    cmp w9, #40
    b.ne Limport_media_close
    add x24, x24, #1
    cmp x24, #8
    b.hi Limport_none
Limport_media_close:
    cmp w9, #41
    b.ne Limport_media_next
    cbz x24, Limport_none
    sub x24, x24, #1
Limport_media_next:
    add x28, x28, #1
    sub x9, x28, x27
    cmp x9, #1024
    b.hi Limport_none
    b Limport_media
Limport_semicolon:
    cbnz x24, Limport_none
    sub x9, x28, x27
    cmp x9, #1024
    b.hi Limport_none
    mov x0, x23
    sub x1, x26, x23
    bl _strndup
    cbz x0, Limport_none
    str x0, [x21]
    mov x0, x27
    mov x1, x28
    bl _css_trim
    sub x1, x1, x0
    bl _strndup
    cbz x0, Limport_alloc_fail
    str x0, [x21, #8]
    sub x9, x22, x19
    str x9, [x21, #16]
    add x9, x28, #1
    sub x9, x9, x19
    stp x9, x9, [x21, #24]
    mov x0, #1
    LEAVE
Limport_charset:
    // Skip a bounded charset declaration, respecting its quoted value.
    mov x24, #0
Limport_charset_next:
    cmp x23, x20
    b.hs Limport_none
    ldrb w9, [x23], #1
    cbz x24, Limport_charset_unquoted
    cmp w9, w24
    csel x24, xzr, x24, eq
    b Limport_charset_next
Limport_charset_unquoted:
    cmp w9, #34
    b.eq Limport_charset_quote
    cmp w9, #39
    b.eq Limport_charset_quote
    cmp w9, #59
    b.ne Limport_charset_next
    mov x22, x23
    b Limport_header
Limport_charset_quote:
    mov x24, x9
    b Limport_charset_next
Limport_alloc_fail:
    ldr x0, [x21]
    bl _free
    str xzr, [x21]
Limport_none:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
import_keyword: .asciz "@import"
charset_keyword: .asciz "@charset"
url_keyword: .asciz "url("
