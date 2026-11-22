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
    mov x24, #0
    ADDR x25, live_names
Lpseudo_live_name:
    mov x0, x21
    mov x1, x22
    ldr x2, [x25, x24, lsl #3]
    bl _css_eq
    cbnz x0, Lpseudo_live
    add x24, x24, #1
    cmp x24, #4
    b.lo Lpseudo_live_name
    mov x0, x21
    mov x1, x22
    ADDR x2, p_not
    bl _css_eq
    cbnz x0, Lpseudo_not
    mov x24, #0
    ADDR x25, nth_names
Lpseudo_nth_name:
    mov x0, x21
    mov x1, x22
    ldr x2, [x25, x24, lsl #3]
    bl _css_eq
    cbnz x0, Lpseudo_nth
    add x24, x24, #1
    cmp x24, #4
    b.lo Lpseudo_nth_name
    mov x0, #-1
    LEAVE
Lpseudo_nth:
    cmp x22, x23
    b.hs Lpseudo_no
    ldrb w9, [x22]
    cmp w9, #40
    b.ne Lpseudo_no
    add x25, x22, #1
    mov x26, x25
Lpseudo_nth_end:
    cmp x26, x23
    b.hs Lpseudo_no
    ldrb w9, [x26]
    cmp w9, #41
    b.eq Lpseudo_nth_test
    add x26, x26, #1
    b Lpseudo_nth_end
Lpseudo_nth_test:
    mov x0, x19
    mov x1, x20
    mov x2, x25
    mov x3, x26
    mov x4, x24
    bl _css_nth_match
    cbz x0, Lpseudo_no
    add x22, x26, #1
    b Lpseudo_yes
Lpseudo_first:
    mov x4, #0
    bl pseudo_first_or_last
    cbz x0, Lpseudo_no
    b Lpseudo_yes
Lpseudo_only:
    mov x4, #0
    bl pseudo_first_or_last
    cbz x0, Lpseudo_no
Lpseudo_last:
    mov x4, #1
    bl pseudo_first_or_last
    cbz x0, Lpseudo_no
    b Lpseudo_yes
// Persistent DOM is authoritative for structural tests, including hidden and
// stylesheet elements that the render snapshot may omit or flatten.
Lpseudo_empty:
    mov x0, x19
    mov x1, x20
    bl _css_dom_empty
    cbz x0, Lpseudo_no
    b Lpseudo_yes
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
Lpseudo_live:
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x9, [x9, #744]
    lsr x9, x9, x24
    tbz x9, #0, Lpseudo_no
    b Lpseudo_yes
Lpseudo_checked:
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x10, [x9, #744]
    tbz x10, #4, Lpseudo_checked_default
    tbz x10, #5, Lpseudo_no
    b Lpseudo_yes
Lpseudo_checked_default:
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
// x4 reverse flag; saved matcher registers supply the target.
pseudo_first_or_last:
    mov x0, x19
    mov x1, x20
    ADDR x2, nth_one
    add x3, x2, #1
    b _css_nth_match
.section __TEXT,__cstring,cstring_literals
p_first: .asciz "first-child"
p_last: .asciz "last-child"
p_only: .asciz "only-child"
p_empty: .asciz "empty"
p_disabled: .asciz "disabled"
p_enabled: .asciz "enabled"
p_checked: .asciz "checked"
p_not: .asciz "not"
p_nth: .asciz "nth-child"
p_nth_last: .asciz "nth-last-child"
p_nth_type: .asciz "nth-of-type"
p_nth_last_type: .asciz "nth-last-of-type"
nth_one: .asciz "1"
.section __DATA,__const
.p2align 3
nth_names: .quad p_nth,p_nth_last,p_nth_type,p_nth_last_type

.section __TEXT,__cstring,cstring_literals
p_hover: .asciz "hover"
p_active: .asciz "active"
p_focus: .asciz "focus"
p_focus_visible: .asciz "focus-visible"
.section __DATA,__const
.p2align 3
live_names: .quad p_hover,p_active,p_focus,p_focus_visible
