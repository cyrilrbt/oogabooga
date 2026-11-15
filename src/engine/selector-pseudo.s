.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
// doc,node,name start/name end,compound end -> yes/no/-1unknown,next,specificity.
.globl _css_pseudo_match
_css_pseudo_match:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x0, x21
    mov x1, x22
    ADDR x2, p_first
    bl _css_eq
    cbnz x0, Lpseudo_first
    mov x0, x21
    mov x1, x22
    ADDR x2, p_last
    bl _css_eq
    cbnz x0, Lpseudo_last
    mov x0, x21
    mov x1, x22
    ADDR x2, p_only
    bl _css_eq
    cbnz x0, Lpseudo_only
    mov x0, x21
    mov x1, x22
    ADDR x2, p_empty
    bl _css_eq
    cbnz x0, Lpseudo_empty
    mov x0, x21
    mov x1, x22
    ADDR x2, p_disabled
    bl _css_eq
    cbnz x0, Lpseudo_disabled
    mov x0, x21
    mov x1, x22
    ADDR x2, p_enabled
    bl _css_eq
    cbnz x0, Lpseudo_enabled
    mov x0, x21
    mov x1, x22
    ADDR x2, p_checked
    bl _css_eq
    cbnz x0, Lpseudo_checked
    mov x0, x21
    mov x1, x22
    ADDR x2, p_not
    bl _css_eq
    cbnz x0, Lpseudo_not
    mov x0, #-1
    LEAVE
Lpseudo_first:
    mov x0, x19
    mov x1, x20
    bl _css_previous_sibling
    cbnz x0, Lpseudo_no
    b Lpseudo_yes
Lpseudo_only:
    mov x0, x19
    mov x1, x20
    bl _css_previous_sibling
    cbnz x0, Lpseudo_no
Lpseudo_last:
    ldr x24, [x19, #16]
    mov x9, #40
    madd x9, x20, x9, x24
    ldr x25, [x9, #8]
    add x26, x20, #1
    ldr x27, [x19, #24]
Lpseudo_after:
    cmp x26, x27
    b.hs Lpseudo_yes
    ldr x9, [x19, #88]
    cbz x9, Lpseudo_no
    sub x9, x9, #1
    str x9, [x19, #88]
    mov x9, #40
    madd x9, x26, x9, x24
    ldr x10, [x9, #8]
    cmp x10, x25
    b.lo Lpseudo_yes
    b.ne Lpseudo_after_next
    ldr x10, [x9]
    cmp x10, #NODE_TEXT
    b.eq Lpseudo_after_next
    cmp x10, #NODE_SHEET
    b.eq Lpseudo_after_next
    cmp x10, #NODE_LINK
    b.ne Lpseudo_no
Lpseudo_after_next:
    add x26, x26, #1
    b Lpseudo_after
Lpseudo_empty:
    ldr x24, [x19, #16]
    ldr x25, [x19, #24]
    add x26, x20, #1
Lpseudo_empty_child:
    cmp x26, x25
    b.hs Lpseudo_yes
    mov x9, #40
    madd x9, x26, x9, x24
    ldr x10, [x9, #8]
    cmp x10, x20
    b.lo Lpseudo_yes
    b.ne Lpseudo_empty_next
    ldr x10, [x9]
    cmp x10, #NODE_SHEET
    b.eq Lpseudo_empty_next
    cmp x10, #NODE_LINK
    b.eq Lpseudo_empty_next
    cmp x10, #NODE_TEXT
    b.ne Lpseudo_no
    ldp x10, x11, [x9, #16]
    cmp x10, x11
    b.ne Lpseudo_no
Lpseudo_empty_next:
    add x26, x26, #1
    b Lpseudo_empty_child
Lpseudo_disabled:
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x9, [x9, #ATTR_DISABLED]
    cbz x9, Lpseudo_no
    b Lpseudo_yes
Lpseudo_enabled:
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x9, [x9]
    cmp x9, #NODE_INPUT
    b.eq Lpseudo_enabled_control
    cmp x9, #NODE_BUTTON
    b.eq Lpseudo_enabled_control
    cmp x9, #NODE_SELECT
    b.eq Lpseudo_enabled_control
    cmp x9, #NODE_TEXTAREA
    b.ne Lpseudo_no
Lpseudo_enabled_control:
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x9, [x9, #ATTR_DISABLED]
    cbnz x9, Lpseudo_no
    b Lpseudo_yes
Lpseudo_checked:
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x10, [x9, #ATTR_CHECKED]
    ldr x9, [x9, #ATTR_SELECTED]
    orr x9, x9, x10
    cbz x9, Lpseudo_no
    b Lpseudo_yes
Lpseudo_not:
    cmp x22, x23
    b.hs Lpseudo_no
    ldrb w9, [x22]
    cmp w9, #40
    b.ne Lpseudo_no
    // Nested functions intentionally unsupported: bounded simple compound only.
    add x24, x22, #1
    mov x25, x24
Lpseudo_not_end:
    cmp x25, x23
    b.hs Lpseudo_no
    ldrb w9, [x25]
    cmp w9, #41
    b.eq Lpseudo_not_test
    cmp w9, #40
    b.eq Lpseudo_no
    cmp w9, #58
    b.eq Lpseudo_no
    cmp w9, #44
    b.eq Lpseudo_no
    add x25, x25, #1
    b Lpseudo_not_end
Lpseudo_not_test:
    mov x0, x19
    mov x1, x20
    mov x2, x24
    mov x3, x25
    bl _css_compound
    cbnz x0, Lpseudo_no
    add x22, x25, #1
    // Specificity of common simple class/id/type arguments.
    mov x2, #1
    ldrb w9, [x24]
    cmp w9, #46
    mov x10, #100
    csel x2, x10, x2, eq
    cmp w9, #35
    mov x10, #10000
    csel x2, x10, x2, eq
    mov x0, #1
    mov x1, x22
    LEAVE
Lpseudo_yes:
    mov x0, #1
    mov x1, x22
    mov x2, #100
    LEAVE
Lpseudo_no:
    mov x0, #0
    mov x1, x22
    mov x2, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
p_first: .asciz "first-child"
p_last: .asciz "last-child"
p_only: .asciz "only-child"
p_empty: .asciz "empty"
p_disabled: .asciz "disabled"
p_enabled: .asciz "enabled"
p_checked: .asciz "checked"
p_not: .asciz "not"
