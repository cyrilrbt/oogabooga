// ASCII type/class/id/universal/compound selectors, comma groups and descendants.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// match(document,node,selector_start,selector_end) -> specificity+1, or zero.
.globl _css_match
_css_match:
    mov x4, #0
    b Lmatch_entry
.globl _css_match_rule
_css_match_rule:
    mov x4, #1
Lmatch_entry:
    ldr x9, [x0, #88]
    cbnz x9, Lmatch_budget
    mov x0, #0
    ret
Lmatch_budget:
    ENTER
    str x4, [sp, #144]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, #0
Lselector_group:
    cmp x21, x22
    b.hs Lselector_result
    mov x24, x21
Lselector_comma:
    mov x0, x21
    mov x1, x22
    mov x2, #44
    bl _css_selector_boundary
    mov x24, x0
Lselector_try:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x24
    ldr x4, [sp, #144]
    bl _css_match_one
    cmp x0, x23
    csel x23, x0, x23, hi
    add x21, x24, #1
    b Lselector_group
Lselector_result:
    mov x0, x23
    LEAVE

_css_match_one:
    ENTER
    str x4, [sp, #144]
    mov x19, x0
    mov x20, x1
    mov x0, x2
    mov x1, x3
    bl _css_trim
    mov x21, x0
    mov x22, x1
    cmp x21, x22
    b.hs Lmatch_no
    ldr x9, [sp, #144]
    cbnz x9, Lselector_rightmost
    mov x0, x21
    mov x1, x22
    bl _css_selector_supported
    cbz x0, Lmatch_no
Lselector_rightmost:
    mov x23, x22
    mov x25, #0                     // accumulated specificity
    mov x27, #1                     // rightmost / child must match directly
    mov x26, #0                     // number of compounds, bounded to 8
Lselector_component:
    cmp x23, x21
    b.ls Lmatch_yes
    sub x9, x23, #1
    ldrb w10, [x9]
    cmp w10, #32
    b.hi Lselector_component_end
    mov x23, x9
    b Lselector_component
Lselector_component_end:
    mov x24, x23
Lselector_component_start:
    mov x0, x21
    mov x1, x24
    bl _css_component_start
    mov x23, x0
Lselector_component_match:
    cmp x23, x24
    b.eq Lmatch_no
    add x26, x26, #1
    cmp x26, #8
    b.hi Lmatch_no
Lselector_ancestor:
    mov x0, x19
    mov x1, x20
    mov x2, x23
    mov x3, x24
    bl _css_compound
    cbnz x0, Lselector_component_found
    cmp x27, #3
    b.eq Lselector_previous_try
    cbnz x27, Lmatch_no
    cmp x26, #1
    b.eq Lmatch_no                  // rightmost must match the element itself
    cbz x20, Lmatch_no
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x20, [x9, #8]
    tbnz x20, #63, Lmatch_no
    b Lselector_ancestor
Lselector_previous_try:
    mov x0, x19
    mov x1, x20
    bl _css_previous_sibling
    cbz x0, Lmatch_no
    mov x20, x0
    b Lselector_ancestor
Lselector_component_found:
    sub x0, x0, #1
    add x25, x25, x0
    mov x27, #0
Lselector_separator:
    cmp x23, x21
    b.ls Lmatch_yes
    sub x9, x23, #1
    ldrb w10, [x9]
    cmp w10, #32
    b.hi Lselector_separator_end
    mov x23, x9
    b Lselector_separator
Lselector_separator_end:
    cmp w10, #62
    b.eq Lselector_child
    cmp w10, #43
    b.eq Lselector_adjacent
    cmp w10, #126
    b.eq Lselector_sibling
    b Lselector_parent_step
Lselector_child:
    mov x27, #1
    b Lselector_consume_combinator
Lselector_adjacent:
    mov x27, #2
    b Lselector_consume_combinator
Lselector_sibling:
    mov x27, #3
Lselector_consume_combinator:
    mov x23, x9
    cmp x23, x21
    b.ls Lmatch_no
    cmp x27, #2
    b.lo Lselector_parent_step
    mov x0, x19
    mov x1, x20
    bl _css_previous_sibling
    cbz x0, Lmatch_no
    mov x20, x0
    b Lselector_component
Lselector_parent_step:
    cbz x20, Lmatch_no
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x20, [x9, #8]
    tbnz x20, #63, Lmatch_no
    b Lselector_component
Lmatch_yes:
    add x0, x25, #1
    LEAVE
Lmatch_no:
    mov x0, #0
    LEAVE

.globl _css_compound
_css_compound:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    mov x22, #1
    str x1, [sp, #144]
    ldr x9, [x19, #88]
    cbz x9, Lcompound_no
    sub x9, x9, #1
    str x9, [x19, #88]
    ldr x23, [x19, #72]
    add x23, x23, x1, lsl #11
    ldr x24, [x23, #24]
    cbz x24, Lcompound_no
    cmp x20, x21
    b.hs Lcompound_no
    ldrb w9, [x20]
    cmp w9, #42
    b.eq Lcompound_star
    cmp w9, #46
    b.eq Lcompound_suffix
    cmp w9, #58
    b.eq Lcompound_suffix
    cmp w9, #91
    b.eq Lcompound_suffix
    cmp w9, #35
    b.eq Lcompound_suffix
    mov x0, x20
    mov x1, x21
    bl _css_ident_end
    cmp x0, x20
    b.eq Lcompound_no
    mov x25, x0
    mov x0, x24
    bl _strlen
    sub x26, x25, x20
    cmp x0, x26
    b.ne Lcompound_no
    mov x0, x24
    mov x1, x20
    mov x2, x26
    bl _strncasecmp
    cbnz w0, Lcompound_no
    mov x20, x25
    add x22, x22, #1
    b Lcompound_suffix
Lcompound_star:
    add x20, x20, #1
Lcompound_suffix:
    cmp x20, x21
    b.hs Lcompound_yes
    ldrb w24, [x20], #1
    cmp w24, #91
    b.eq Lcompound_attribute
    cmp w24, #58
    b.eq Lcompound_link_state
    cmp w24, #35
    b.eq Lcompound_identifier
    cmp w24, #46
    b.ne Lcompound_no
    b Lcompound_identifier
Lcompound_attribute:
    mov x0, x19
    ldr x1, [sp, #144]
    mov x2, x20
    mov x3, x21
    bl _css_attribute_match
    cbz x0, Lcompound_no
    mov x20, x1
    add x22, x22, #100
    b Lcompound_suffix
Lcompound_link_state:
    mov x25, x20
    mov x0, x20
    mov x1, x21
    bl _css_ident_end
    mov x20, x0
    mov x0, x19
    ldr x1, [sp, #144]
    mov x2, x25
    mov x3, x20
    mov x4, x21
    bl _css_pseudo_match
    cmp x0, #-1
    b.eq Lcompound_known_link_pseudo
    cbz x0, Lcompound_no
    mov x20, x1
    add x22, x22, x2
    b Lcompound_suffix
Lcompound_known_link_pseudo:
    mov x1, x20
    mov x0, x25
    ADDR x2, pseudo_root
    bl _css_eq
    cbz w0, Lcompound_anchor_state
    ldr x9, [sp, #144]
    cmp x9, #1
    b.ne Lcompound_no
    b Lcompound_state_yes
Lcompound_anchor_state:
    ldr x9, [sp, #144]
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x9, x11, x10
    ldr x9, [x10]
    cmp x9, #6
    b.ne Lcompound_no
    ldr x9, [x10, #32]
    cbz x9, Lcompound_no
    mov x0, x25
    mov x1, x20
    ADDR x2, pseudo_link
    bl _css_eq
    cbnz w0, Lcompound_unvisited
    mov x0, x25
    mov x1, x20
    ADDR x2, pseudo_visited
    bl _css_eq
    cbz w0, Lcompound_no
    ldr x9, [x23, #864]
    cbz x9, Lcompound_no
    b Lcompound_state_yes
Lcompound_unvisited:
    ldr x9, [x23, #864]
    cbnz x9, Lcompound_no
Lcompound_state_yes:
    add x22, x22, #100
    b Lcompound_suffix
Lcompound_identifier:
    mov x25, x20
    mov x0, x20
    mov x1, x21
    bl _css_ident_end
    cmp x0, x25
    b.eq Lcompound_no
    mov x20, x0
    sub x26, x20, x25
    cmp w24, #35
    b.eq Lcompound_id
    ldr x27, [x23, #8]
    cbz x27, Lcompound_no
    ldr x9, [x19, #88]
    cmp x9, x26
    b.lo Lcompound_exhausted
    sub x9, x9, x26
    str x9, [x19, #88]
    mov x0, x23
    mov x1, x25
    mov x2, x20
    bl _css_class_filter_maybe
    cbz x0, Lcompound_no
Lcompound_class_next:
    ldr x9, [x19, #88]
    cbz x9, Lcompound_no
    sub x9, x9, #1
    str x9, [x19, #88]
    ldrb w9, [x27]
    cbz w9, Lcompound_no
    cmp w9, #32
    b.hi Lcompound_class_start
    add x27, x27, #1
    b Lcompound_class_next
Lcompound_class_start:
    mov x28, x27
Lcompound_class_scan:
    ldr x9, [x19, #88]
    cbz x9, Lcompound_no
    sub x9, x9, #1
    str x9, [x19, #88]
    ldrb w9, [x28]
    cbz w9, Lcompound_class_check
    cmp w9, #32
    b.ls Lcompound_class_check
    add x28, x28, #1
    b Lcompound_class_scan
Lcompound_class_check:
    mov x0, x27
    mov x1, x28
    mov x2, x25
    mov x3, x20
    bl _css_identifier_equal
    cbnz w0, Lcompound_class_yes
Lcompound_class_advance:
    mov x27, x28
    b Lcompound_class_next
Lcompound_class_yes:
    add x22, x22, #100
    b Lcompound_suffix
Lcompound_id:
    ldr x27, [x23]
    cbz x27, Lcompound_no
    mov x0, x27
    bl _strlen
    ldr x9, [x19, #88]
    cmp x9, x0
    b.lo Lcompound_exhausted
    sub x9, x9, x0
    str x9, [x19, #88]
    add x1, x27, x0
    mov x0, x27
    mov x2, x25
    mov x3, x20
    bl _css_identifier_equal
    cbz w0, Lcompound_no
    mov x9, #10000
    add x22, x22, x9
    b Lcompound_suffix
Lcompound_yes:
    mov x0, x22
    LEAVE
Lcompound_exhausted:
    str xzr, [x19, #88]
Lcompound_no:
    mov x0, #0
    LEAVE

// Return first byte after an ASCII identifier, bounded by end.
.globl _css_ident_end
_css_ident_end:
Lident_next:
    cmp x0, x1
    b.hs Lident_done
    ldrb w2, [x0]
    cmp w2, #92
    b.eq Lident_escape
    cmp w2, #45
    b.eq Lident_advance
    cmp w2, #95
    b.eq Lident_advance
    sub w3, w2, #48
    cmp w3, #9
    b.ls Lident_advance
    orr w2, w2, #32
    sub w3, w2, #97
    cmp w3, #25
    b.hi Lident_done
Lident_advance:
    add x0, x0, #1
    b Lident_next
Lident_escape:
    add x2, x0, #1
    cmp x2, x1
    b.hs Lident_done
    add x0, x0, #2
    b Lident_next
Lident_done:
    ret

// Compare an HTML identifier to a CSS identifier with simple punctuation escapes.
_css_identifier_equal:
Lidentifier_equal_next:
    cmp x2, x3
    b.hs Lidentifier_equal_end
    cmp x0, x1
    b.hs Lidentifier_equal_no
    ldrb w4, [x2], #1
    cmp w4, #92
    b.ne Lidentifier_equal_byte
    cmp x2, x3
    b.hs Lidentifier_equal_no
    ldrb w4, [x2], #1
Lidentifier_equal_byte:
    ldrb w5, [x0], #1
    cmp w4, w5
    b.ne Lidentifier_equal_no
    b Lidentifier_equal_next
Lidentifier_equal_end:
    cmp x0, x1
    cset w0, eq
    ret
Lidentifier_equal_no:
    mov w0, #0
    ret

.section __TEXT,__cstring,cstring_literals
pseudo_link: .asciz "link"
pseudo_visited: .asciz "visited"

.section __TEXT,__cstring,cstring_literals
pseudo_root: .asciz "root"
