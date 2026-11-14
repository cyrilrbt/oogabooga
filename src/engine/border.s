// Bounded solid/none border shorthand. Commit atomically after all tokens parse.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _css_border_declarations
_css_border_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, #3
    mov x24, #0
    mov x25, #0
Lborder_next:
    mov x0, x19
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x19, x20
    b.hs Lborder_commit
    mov x26, x19
Lborder_token:
    cmp x26, x20
    b.hs Lborder_parse
    ldrb w9, [x26]
    cmp w9, #32
    b.ls Lborder_parse
    add x26, x26, #1
    b Lborder_token
Lborder_parse:
    mov x0, x19
    mov x1, x26
    ADDR x2, border_solid
    bl _css_eq
    cbz w0, Lborder_none
    orr x25, x25, #1
    b Lborder_advance
Lborder_none:
    mov x0, x19
    mov x1, x26
    ADDR x2, border_none
    bl _css_eq
    cbz w0, Lborder_width
    orr x25, x25, #2
    b Lborder_advance
Lborder_width:
    mov x0, #CSS_BORDER
    mov x1, x19
    mov x2, x26
    bl _css_value
    cbz x1, Lborder_color
    mov x23, x0
    b Lborder_advance
Lborder_color:
    mov x0, x19
    mov x1, x26
    bl _css_color
    cbz x1, Lborder_done
    mov x24, x0
Lborder_advance:
    mov x19, x26
    b Lborder_next
Lborder_commit:
    cbz x25, Lborder_done
    tst x25, #2
    csel x23, xzr, x23, ne
    mov x0, x21
    mov x1, #CSS_BORDER
    mov x2, x22
    mov x3, x23
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BORDER_COLOR
    mov x2, x22
    mov x3, x24
    bl _css_store_decl
Lborder_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
border_solid: .asciz "solid"
border_none: .asciz "none"
