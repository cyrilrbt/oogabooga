// ASCII type/class/id/universal/compound selectors, comma groups and descendants.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// match(document,node,selector_start,selector_end) -> specificity+1, or zero.
.globl _css_match
_css_match:
    ldr x9, [x0, #88]
    cbnz x9, Lmatch_budget
    mov x0, #0
    ret
Lmatch_budget:
    ENTER
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
    cmp x24, x22
    b.hs Lselector_try
    ldrb w9, [x24]
    cmp w9, #44
    b.eq Lselector_try
    add x24, x24, #1
    b Lselector_comma
Lselector_try:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x24
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
    mov x19, x0
    mov x20, x1
    mov x0, x2
    mov x1, x3
    bl _css_trim
    mov x21, x0
    mov x22, x1
    cmp x21, x22
    b.hs Lmatch_no
    // Reject unsupported combinators/pseudo/attribute/escape syntax, not partial matches.
    mov x23, x21
Lselector_validate:
    cmp x23, x22
    b.hs Lselector_rightmost
    ldr x9, [x19, #88]
    cbz x9, Lmatch_no
    sub x9, x9, #1
    str x9, [x19, #88]
    ldrb w9, [x23], #1
    cmp w9, #32
    b.ls Lselector_validate
    cmp w9, #62
    b.eq Lselector_validate
    cmp w9, #46
    b.eq Lselector_validate
    cmp w9, #35
    b.eq Lselector_validate
    cmp w9, #42
    b.eq Lselector_validate
    cmp w9, #45
    b.eq Lselector_validate
    cmp w9, #95
    b.eq Lselector_validate
    sub w10, w9, #48
    cmp w10, #9
    b.ls Lselector_validate
    orr w9, w9, #32
    sub w10, w9, #97
    cmp w10, #25
    b.ls Lselector_validate
    b Lmatch_no
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
    cmp x23, x21
    b.ls Lselector_component_match
    sub x9, x23, #1
    ldrb w10, [x9]
    cmp w10, #62
    b.eq Lselector_component_match
    cmp w10, #32
    b.ls Lselector_component_match
    mov x23, x9
    b Lselector_component_start
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
    b.ne Lselector_parent_step
    mov x27, #1
    mov x23, x9
    cmp x23, x21
    b.ls Lmatch_no
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

_css_compound:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    mov x22, #1
    ldr x9, [x19, #88]
    cbz x9, Lcompound_no
    sub x9, x9, #1
    str x9, [x19, #88]
    ldr x23, [x19, #72]
    add x23, x23, x1, lsl #10
    ldr x24, [x23, #24]
    cbz x24, Lcompound_no
    cmp x20, x21
    b.hs Lcompound_no
    ldrb w9, [x20]
    cmp w9, #42
    b.eq Lcompound_star
    cmp w9, #46
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
    cmp w24, #35
    b.eq Lcompound_identifier
    cmp w24, #46
    b.ne Lcompound_no
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
    sub x9, x28, x27
    cmp x9, x26
    b.ne Lcompound_class_advance
    mov x0, x27
    mov x1, x25
    mov x2, x26
    bl _memcmp
    cbz w0, Lcompound_class_yes
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
    cmp x0, x26
    b.ne Lcompound_no
    mov x0, x27
    mov x1, x25
    mov x2, x26
    bl _memcmp
    cbnz w0, Lcompound_no
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
_css_ident_end:
Lident_next:
    cmp x0, x1
    b.hs Lident_done
    ldrb w2, [x0]
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
Lident_done:
    ret
