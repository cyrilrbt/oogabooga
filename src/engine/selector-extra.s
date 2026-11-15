.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
// start,end,delimiter -> first delimiter outside strings/brackets/parentheses.
.globl _css_selector_boundary
_css_selector_boundary:
    mov x3, #0
    mov x4, #0
    mov x5, #0
Lboundary_scan:
    cmp x0, x1
    b.hs Lboundary_done
    ldrb w6, [x0]
    cmp w6, #92
    b.eq Lboundary_escape
    cbz x3, Lboundary_unquoted
    cmp x3, x6
    csel x3, xzr, x3, eq
    b Lboundary_advance
Lboundary_unquoted:
    cmp w6, #47
    b.ne Lboundary_not_comment
    add x7, x0, #1
    cmp x7, x1
    b.hs Lboundary_not_comment
    ldrb w7, [x7]
    cmp w7, #42
    b.ne Lboundary_not_comment
    add x0, x0, #2
Lboundary_comment:
    add x7, x0, #1
    cmp x7, x1
    b.hs Lboundary_comment_end
    ldrb w6, [x0], #1
    cmp w6, #42
    b.ne Lboundary_comment
    ldrb w6, [x0]
    cmp w6, #47
    b.ne Lboundary_comment
    add x0, x0, #1
    b Lboundary_scan
Lboundary_comment_end:
    mov x0, x1
    ret
Lboundary_not_comment:
    cmp w6, #34
    b.eq Lboundary_quote
    cmp w6, #39
    b.eq Lboundary_quote
    cmp x6, x2
    b.ne Lboundary_nondelimiter
    orr x7, x4, x5
    cbz x7, Lboundary_done
Lboundary_nondelimiter:
    cmp w6, #91
    cinc x4, x4, eq
    cmp w6, #93
    b.ne Lboundary_parens
    cbz x4, Lboundary_done
    sub x4, x4, #1
Lboundary_parens:
    cmp w6, #40
    cinc x5, x5, eq
    cmp w6, #41
    b.ne Lboundary_advance
    cbz x5, Lboundary_done
    sub x5, x5, #1
    b Lboundary_advance
Lboundary_quote:
    mov x3, x6
Lboundary_advance:
    add x0, x0, #1
    b Lboundary_scan
Lboundary_escape:
    add x0, x0, #1
    cmp x0, x1
    b.hs Lboundary_done
    add x0, x0, #1
    b Lboundary_scan
Lboundary_done:
    ret

.globl _css_component_start
_css_component_start:
    mov x2, x0
    mov x3, #0
    mov x4, #0
    mov x5, #0
Lcomponent_scan:
    cmp x0, x1
    b.hs Lcomponent_done
    ldrb w6, [x0], #1
    cmp w6, #92
    b.eq Lcomponent_escape
    cbz x3, Lcomponent_unquoted
    cmp x3, x6
    csel x3, xzr, x3, eq
    b Lcomponent_scan
Lcomponent_unquoted:
    cmp w6, #34
    b.eq Lcomponent_quote
    cmp w6, #39
    b.eq Lcomponent_quote
    cmp w6, #91
    cinc x4, x4, eq
    cmp w6, #40
    cinc x5, x5, eq
    orr x7, x4, x5
    cbnz x7, Lcomponent_close
    cmp w6, #32
    b.ls Lcomponent_boundary
    cmp w6, #62
    b.eq Lcomponent_boundary
    cmp w6, #43
    b.eq Lcomponent_boundary
    cmp w6, #126
    b.ne Lcomponent_scan
Lcomponent_boundary:
    mov x2, x0
    b Lcomponent_scan
Lcomponent_close:
    cmp w6, #93
    b.ne Lcomponent_close_paren
    sub x4, x4, #1
Lcomponent_close_paren:
    cmp w6, #41
    b.ne Lcomponent_scan
    sub x5, x5, #1
    b Lcomponent_scan
Lcomponent_quote:
    mov x3, x6
    b Lcomponent_scan
Lcomponent_escape:
    cmp x0, x1
    b.hs Lcomponent_done
    add x0, x0, #1
    b Lcomponent_scan
Lcomponent_done:
    mov x0, x2
    ret

// Previous retained element sibling. Text and stylesheet resource nodes skip.
.globl _css_previous_sibling
_css_previous_sibling:
    ldr x2, [x0, #16]
    mov x3, #40
    madd x4, x1, x3, x2
    ldr x4, [x4, #8]
Lprevious_scan:
    cmp x1, x4
    b.ls Lprevious_none
    ldr x5, [x0, #88]
    cbz x5, Lprevious_none
    sub x5, x5, #1
    str x5, [x0, #88]
    sub x1, x1, #1
    madd x5, x1, x3, x2
    ldr x6, [x5, #8]
    cmp x6, x4
    b.ne Lprevious_scan
    ldr x6, [x5]
    cmp x6, #NODE_TEXT
    b.eq Lprevious_scan
    cmp x6, #NODE_SHEET
    b.eq Lprevious_scan
    cmp x6, #NODE_LINK
    b.eq Lprevious_scan
    mov x0, x1
    ret
Lprevious_none:
    mov x0, #0
    ret
