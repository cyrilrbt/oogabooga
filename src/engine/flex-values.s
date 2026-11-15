.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// flex: none | auto | grow [shrink] [basis]. Numeric factors use 1/1000 units.
.globl _css_flex_declarations
_css_flex_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, #1000
    mov x24, #1000
    mov x25, #0
    ADDR x2, flex_none
    bl _css_eq
    cbz w0, Lflex_auto
    mov x23, #0
    mov x24, #0
    mov x25, #-1
    b Lflex_store
Lflex_auto:
    mov x0, x19
    mov x1, x20
    ADDR x2, flex_auto
    bl _css_eq
    cbz w0, Lflex_tokens
    mov x25, #-1
    b Lflex_store
Lflex_tokens:
    mov x26, #0
Lflex_token_next:
    mov x0, x19
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x19, x20
    b.hs Lflex_tokens_done
    mov x27, x19
Lflex_token_end:
    cmp x27, x20
    b.hs Lflex_token_value
    ldrb w9, [x27]
    cmp w9, #32
    b.ls Lflex_token_value
    add x27, x27, #1
    b Lflex_token_end
Lflex_token_value:
    cmp x26, #3
    b.hs Lflex_done
    cmp x26, #2
    b.eq Lflex_basis
    mov x0, #CSS_GROW
    mov x1, x19
    mov x2, x27
    bl _css_value
    cbz x1, Lflex_basis
    cbnz x26, Lflex_shrink
    mov x23, x0
    b Lflex_token_advance
Lflex_shrink:
    mov x24, x0
    b Lflex_token_advance
Lflex_basis:
    mov x0, #CSS_BASIS
    mov x1, x19
    mov x2, x27
    bl _css_value
    cbz x1, Lflex_done
    mov x25, x0
    mov x26, #2
Lflex_token_advance:
    add x26, x26, #1
    mov x19, x27
    b Lflex_token_next
Lflex_tokens_done:
    cbz x26, Lflex_done
Lflex_store:
    mov x0, x21
    mov x1, #CSS_GROW
    mov x2, x22
    mov x3, x23
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_SHRINK
    mov x2, x22
    mov x3, x24
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BASIS
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
Lflex_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
flex_none: .asciz "none"
flex_auto: .asciz "auto"

.text
.p2align 2
.globl _css_gap_declarations
_css_gap_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, #0
Lgap_token_start:
    mov x0, x19
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x19, x20
    b.hs Lgap_tokens_done
    cmp x23, #2
    b.hs Lgap_done
    mov x24, x19
Lgap_token_end:
    cmp x24, x20
    b.hs Lgap_token_value
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lgap_token_value
    add x24, x24, #1
    b Lgap_token_end
Lgap_token_value:
    mov x0, #CSS_GAP
    mov x1, x19
    mov x2, x24
    bl _css_value
    cbz x1, Lgap_done
    cbnz x23, Lgap_column
    mov x25, x0
    mov x26, x0
    b Lgap_token_next
Lgap_column:
    mov x26, x0
Lgap_token_next:
    add x23, x23, #1
    mov x19, x24
    b Lgap_token_start
Lgap_tokens_done:
    cbz x23, Lgap_done
    mov x0, x21
    mov x1, #CSS_GAP
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_ROW_GAP
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_COLUMN_GAP
    mov x2, x22
    mov x3, x26
    bl _css_store_decl
Lgap_done:
    LEAVE
