// Validate the supported selector alphabet once per rule, rather than once for
// every target node. Compound matching still checks identifiers and link states.
.text
.p2align 2
.globl _css_selector_supported
_css_selector_supported:
Lselector_check_next:
    cmp x0, x1
    b.hs Lselector_check_yes
    ldrb w2, [x0], #1
    cmp w2, #92
    b.eq Lselector_check_escape
    cmp w2, #32
    b.ls Lselector_check_next
    cmp w2, #91
    b.eq Lselector_check_next
    cmp w2, #93
    b.eq Lselector_check_next
    cmp w2, #40
    b.eq Lselector_check_next
    cmp w2, #41
    b.eq Lselector_check_next
    cmp w2, #61
    b.eq Lselector_check_next
    cmp w2, #43
    b.eq Lselector_check_next
    cmp w2, #126
    b.eq Lselector_check_next
    cmp w2, #94
    b.eq Lselector_check_next
    cmp w2, #36
    b.eq Lselector_check_next
    cmp w2, #124
    b.eq Lselector_check_next
    cmp w2, #34
    b.eq Lselector_check_next
    cmp w2, #39
    b.eq Lselector_check_next
    cmp w2, #44
    b.eq Lselector_check_next
    cmp w2, #62
    b.eq Lselector_check_next
    cmp w2, #58
    b.eq Lselector_check_next
    cmp w2, #46
    b.eq Lselector_check_next
    cmp w2, #35
    b.eq Lselector_check_next
    cmp w2, #42
    b.eq Lselector_check_next
    cmp w2, #45
    b.eq Lselector_check_next
    cmp w2, #95
    b.eq Lselector_check_next
    sub w3, w2, #48
    cmp w3, #9
    b.ls Lselector_check_next
    orr w2, w2, #32
    sub w3, w2, #97
    cmp w3, #25
    b.ls Lselector_check_next
    b Lselector_check_no
Lselector_check_escape:
    cmp x0, x1
    b.hs Lselector_check_no
    ldrb w2, [x0], #1
    cmp w2, #33
    b.lo Lselector_check_no
    cmp w2, #126
    b.hi Lselector_check_no
    cmp w2, #62
    b.eq Lselector_check_no
    cmp w2, #44
    b.eq Lselector_check_no
    sub w3, w2, #48
    cmp w3, #9
    b.ls Lselector_check_no
    orr w2, w2, #32
    sub w3, w2, #97
    cmp w3, #25
    b.ls Lselector_check_no
    b Lselector_check_next
Lselector_check_yes:
    mov x0, #1
    ret
Lselector_check_no:
    mov x0, #0
    ret
