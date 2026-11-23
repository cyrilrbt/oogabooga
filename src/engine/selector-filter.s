// Compile a conservative rightmost-compound rejection key once per rule.
// Complex/escaped/grouped selectors retain the full matcher. Positive Bloom
// results always go through that matcher; this filter can only reject rules.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.globl _css_rule_filter_build
_css_rule_filter_build:
    ENTER
    mov x19, x0
    str xzr, [x19, #688]
    str xzr, [x19, #696]
    ldp x20, x21, [x19]
    add x21, x20, x21
    mov x22, x20
    mov x23, #0
Lrule_filter_scan:
    cmp x20, x21
    b.hs Lrule_filter_token
    ldrb w9, [x20], #1
    // Avoid guessing at escapes, groups, attribute values or functional pseudos.
    cmp w9, #47
    b.eq Lrule_filter_done
    cmp w9, #124
    b.eq Lrule_filter_done
    cmp w9, #92
    b.eq Lrule_filter_done
    cmp w9, #44
    b.eq Lrule_filter_done
    cmp w9, #91
    b.eq Lrule_filter_done
    cmp w9, #40
    b.eq Lrule_filter_done
    cmp w9, #32
    b.ls Lrule_filter_separator
    cmp w9, #62
    b.eq Lrule_filter_separator
    cmp w9, #43
    b.eq Lrule_filter_separator
    cmp w9, #126
    b.ne Lrule_filter_scan
Lrule_filter_separator:
    mov x23, x20
    b Lrule_filter_scan
Lrule_filter_token:
    // Parser trims trailing selector whitespace; if present, fall back safely.
    cbz x23, Lrule_filter_start
    mov x22, x23
Lrule_filter_start:
    cmp x22, x21
    b.hs Lrule_filter_done
    ldrb w9, [x22]
    mov x23, #1                    // type selector
    cmp w9, #46
    b.eq Lrule_filter_class
    cmp w9, #35
    b.eq Lrule_filter_id
    orr w10, w9, #32
    cmp w10, #97
    b.lo Lrule_filter_done
    cmp w10, #122
    b.hi Lrule_filter_done
    b Lrule_filter_ident
Lrule_filter_class:
    mov x23, #2
    b Lrule_filter_prefix
Lrule_filter_id:
    mov x23, #3
Lrule_filter_prefix:
    add x22, x22, #1
Lrule_filter_ident:
    mov x0, x22
    mov x1, x21
    bl _css_ident_end
    sub x21, x0, x22
    cbz x21, Lrule_filter_done
    lsl x21, x21, #2
    orr x21, x21, x23
    cmp x23, #2
    b.ne Lrule_filter_store
    mov x9, x22
    mov x10, #5381
Lrule_filter_hash:
    cmp x9, x0
    b.hs Lrule_filter_hash_done
    ldrb w11, [x9], #1
    add x12, x10, x10, lsl #5
    eor x10, x12, x11
    b Lrule_filter_hash
Lrule_filter_hash_done:
    and x10, x10, #0xffff
    orr x21, x21, x10, lsl #16
Lrule_filter_store:
    str x22, [x19, #688]
    str x21, [x19, #696]
Lrule_filter_done:
    LEAVE

// metadata,rule -> maybe. Leaf class rejects avoid selector parsing and hashing.
.globl _css_rule_filter_maybe
_css_rule_filter_maybe:
    ldr x2, [x1, #688]
    ldr x3, [x1, #696]
    cbz x2, Lrule_maybe_yes
    and x4, x3, #3
    cmp x4, #2
    b.ne Lrule_maybe_string
    ldr x4, [x0, #8]
    cbz x4, Lrule_maybe_no
    ldr x4, [x0, #1632]
    cbz x4, Lrule_maybe_yes
    add x5, x0, #1600
    ubfx x4, x3, #16, #8
    lsr x6, x4, #6
    ldr x7, [x5, x6, lsl #3]
    mov x8, #1
    lsl x8, x8, x4
    tst x7, x8
    b.eq Lrule_maybe_no
    ubfx x4, x3, #24, #8
    lsr x6, x4, #6
    ldr x7, [x5, x6, lsl #3]
    mov x8, #1
    lsl x8, x8, x4
    tst x7, x8
    b.eq Lrule_maybe_no
    b Lrule_maybe_yes
Lrule_maybe_string:
    cmp x4, #3
    b.eq Lrule_maybe_id
    ldr x4, [x0, #24]
    b Lrule_maybe_compare
Lrule_maybe_id:
    ldr x4, [x0]
Lrule_maybe_compare:
    cbz x4, Lrule_maybe_no
    // Case folding is conservative for IDs; the full matcher checks exact case.
    mov x0, x2
    ubfx x3, x3, #2, #14
    add x1, x2, x3
    mov x2, x4
    b _css_eq
Lrule_maybe_yes:
    mov x0, #1
    ret
Lrule_maybe_no:
    mov x0, #0
    ret
