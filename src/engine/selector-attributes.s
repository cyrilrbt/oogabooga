.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,node,after '[',compound end -> matched, next selector byte.
.globl _css_attribute_match
_css_attribute_match:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x23, x3
    mov x0, x2
    mov x1, x3
    mov x2, #93
    bl _css_selector_boundary
    cmp x0, x23
    b.hs Lattr_no
    mov x22, x0
    add x9, x22, #1
    str x9, [sp, #144]
    mov x0, x21
    mov x1, x22
    bl _css_skip
    mov x21, x0
    bl _css_ident_end
    cmp x0, x21
    b.eq Lattr_no
    mov x23, x0
    mov x0, x21
    sub x1, x23, x21
    cmp x1, #128
    b.hi Lattr_no
    bl _strndup
    mov x24, x0
    cbz x0, Lattr_no
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x25, [x9, #ATTR_RAW]
    cbz x25, Lattr_free_name_no
    mov x0, x25
    bl _strlen
    mov x26, x0
    ldr x9, [x19, #88]
    cmp x9, x26
    b.lo Lattr_exhausted
    sub x9, x9, x26
    str x9, [x19, #88]
    mov x0, x25
    add x1, x25, x26
    mov x2, x24
    bl _engine_attribute
    mov x25, x0
    mov x0, x24
    bl _free
    cbz x25, Lattr_no
    mov x0, x23
    mov x1, x22
    bl _css_skip
    mov x21, x0
    cmp x21, x22
    b.hs Lattr_yes_free
    ldrb w23, [x21], #1
    cmp w23, #61
    b.eq Lattr_value
    cmp x21, x22
    b.hs Lattr_no_free
    ldrb w9, [x21], #1
    cmp w9, #61
    b.ne Lattr_no_free
    cmp w23, #126
    b.eq Lattr_value
    cmp w23, #94
    b.eq Lattr_value
    cmp w23, #36
    b.eq Lattr_value
    cmp w23, #42
    b.eq Lattr_value
    cmp w23, #124
    b.ne Lattr_no_free
Lattr_value:
    mov x0, x21
    mov x1, x22
    bl _css_skip
    mov x21, x0
    cmp x21, x22
    b.hs Lattr_no_free
    ldrb w9, [x21]
    mov x24, x21
    cmp w9, #34
    b.eq Lattr_quoted
    cmp w9, #39
    b.ne Lattr_unquoted
Lattr_quoted:
    add x21, x21, #1
    mov x24, x21
Lattr_quote_end:
    cmp x24, x22
    b.hs Lattr_no_free
    ldrb w10, [x24]
    cmp w10, w9
    b.eq Lattr_quote_found
    add x24, x24, #1
    b Lattr_quote_end
Lattr_quote_found:
    add x26, x24, #1
    b Lattr_flag
Lattr_unquoted:
    cmp x24, x22
    b.hs Lattr_unquoted_end
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lattr_unquoted_end
    add x24, x24, #1
    b Lattr_unquoted
Lattr_unquoted_end:
    mov x26, x24
Lattr_flag:
    sub x24, x24, x21
    mov x0, x26
    mov x1, x22
    bl _css_skip
    mov x27, #0
    cmp x0, x22
    b.hs Lattr_compare
    ldrb w9, [x0], #1
    orr w9, w9, #32
    cmp w9, #105
    b.eq Lattr_insensitive
    cmp w9, #115
    b.ne Lattr_no_free
    b Lattr_flag_end
Lattr_insensitive:
    mov x27, #1
Lattr_flag_end:
    mov x1, x22
    bl _css_skip
    cmp x0, x22
    b.ne Lattr_no_free
Lattr_compare:
    mov x0, x25
    bl _strlen
    mov x26, x0
    cmp w23, #61
    b.eq Lattr_exact
    cbz x24, Lattr_no_free
    cmp x26, x24
    b.lo Lattr_no_free
    cmp w23, #94
    b.eq Lattr_prefix
    cmp w23, #36
    b.eq Lattr_suffix
    cmp w23, #124
    b.eq Lattr_hyphen
    cmp w23, #126
    b.eq Lattr_words
    mov x28, #0
Lattr_contains:
    add x9, x28, x24
    cmp x9, x26
    b.hi Lattr_no_free
    add x0, x25, x28
    mov x1, x21
    mov x2, x24
    mov x3, x27
    bl attr_equal
    cbnz x0, Lattr_yes_free
    add x28, x28, #1
    b Lattr_contains
Lattr_words:
    mov x28, #0
Lattr_word_start:
    cmp x28, x26
    b.hs Lattr_no_free
    ldrb w9, [x25, x28]
    cmp w9, #32
    b.hi Lattr_word_end_start
    add x28, x28, #1
    b Lattr_word_start
Lattr_word_end_start:
    mov x22, x28
Lattr_word_end:
    cmp x22, x26
    b.hs Lattr_word_test
    ldrb w9, [x25, x22]
    cmp w9, #32
    b.ls Lattr_word_test
    add x22, x22, #1
    b Lattr_word_end
Lattr_word_test:
    sub x9, x22, x28
    cmp x9, x24
    b.ne Lattr_word_next
    add x0, x25, x28
    mov x1, x21
    mov x2, x24
    mov x3, x27
    bl attr_equal
    cbnz x0, Lattr_yes_free
Lattr_word_next:
    mov x28, x22
    b Lattr_word_start
Lattr_hyphen:
    cmp x26, x24
    b.eq Lattr_prefix
    ldrb w9, [x25, x24]
    cmp w9, #45
    b.ne Lattr_no_free
    b Lattr_prefix
Lattr_suffix:
    sub x9, x26, x24
    add x0, x25, x9
    b Lattr_equal_test
Lattr_exact:
    cmp x26, x24
    b.ne Lattr_no_free
Lattr_prefix:
    mov x0, x25
Lattr_equal_test:
    mov x1, x21
    mov x2, x24
    mov x3, x27
    bl attr_equal
    cbz x0, Lattr_no_free
Lattr_yes_free:
    mov x0, x25
    bl _free
    mov x0, #1
    ldr x1, [sp, #144]
    LEAVE
Lattr_exhausted:
    str xzr, [x19, #88]
Lattr_free_name_no:
    mov x0, x24
    bl _free
    b Lattr_no
Lattr_no_free:
    mov x0, x25
    bl _free
Lattr_no:
    mov x0, #0
    mov x1, #0
    LEAVE
attr_equal:
    cbnz x3, Lattr_equal_fold
    b _memcmp_equal
Lattr_equal_fold:
    ENTER
    bl _strncasecmp
    cmp x0, #0
    cset x0, eq
    LEAVE
_memcmp_equal:
    ENTER
    bl _memcmp
    cmp x0, #0
    cset x0, eq
    LEAVE
