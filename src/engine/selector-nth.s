// Bounded an+b arithmetic, shared by forward/reverse and of-type selectors.
// No allocation, floating point, recursion or platform selector implementation.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// start,end,one-based sibling index -> BOOL.
.globl _css_nth_formula
_css_nth_formula:
    cmp x2, #0
    b.le Lnth_formula_no
Lnth_trim_start:
    cmp x0, x1
    b.hs Lnth_formula_no
    ldrb w8, [x0]
    cmp w8, #32
    b.hi Lnth_trim_end
    add x0, x0, #1
    b Lnth_trim_start
Lnth_trim_end:
    sub x9, x1, #1
    ldrb w8, [x9]
    cmp w8, #32
    b.hi Lnth_keywords
    mov x1, x9
    cmp x0, x1
    b.lo Lnth_trim_end
    b Lnth_formula_no
Lnth_keywords:
    sub x9, x1, x0
    cmp x9, #3
    b.ne Lnth_even
    ldrb w8, [x0]
    orr w8, w8, #32
    cmp w8, #111
    b.ne Lnth_number
    ldrb w8, [x0, #1]
    orr w8, w8, #32
    cmp w8, #100
    b.ne Lnth_number
    ldrb w8, [x0, #2]
    orr w8, w8, #32
    cmp w8, #100
    b.ne Lnth_number
    and x0, x2, #1
    ret
Lnth_even:
    cmp x9, #4
    b.ne Lnth_number
    ldr w8, [x0]
    mov w9, #0x2020
    movk w9, #0x2020, lsl #16
    orr w8, w8, w9
    mov w9, #0x7665
    movk w9, #0x6e65, lsl #16
    cmp w8, w9
    b.ne Lnth_number
    and x0, x2, #1
    eor x0, x0, #1
    ret
Lnth_number:
    mov x5, #1
    mov x6, #0
    mov x7, #0
    ldrb w8, [x0]
    cmp w8, #43
    b.eq Lnth_sign_skip
    cmp w8, #45
    b.ne Lnth_digits
    mov x5, #-1
Lnth_sign_skip:
    add x0, x0, #1
Lnth_digits:
    cmp x0, x1
    b.hs Lnth_constant
    ldrb w8, [x0]
    sub w9, w8, #48
    cmp w9, #9
    b.hi Lnth_n
    mov x10, #10
    madd x6, x6, x10, x9
    cmp x6, #32768
    b.hi Lnth_formula_no
    add x7, x7, #1
    add x0, x0, #1
    b Lnth_digits
Lnth_n:
    orr w8, w8, #32
    cmp w8, #110
    b.ne Lnth_formula_no
    cmp x7, #0
    mov x9, #1
    csel x6, x9, x6, eq
    mul x3, x6, x5
    add x0, x0, #1
    mov x4, #0
Lnth_b_space:
    cmp x0, x1
    b.hs Lnth_evaluate
    ldrb w8, [x0]
    cmp w8, #32
    b.hi Lnth_b_sign
    add x0, x0, #1
    b Lnth_b_space
Lnth_b_sign:
    mov x5, #1
    cmp w8, #43
    b.eq Lnth_b_skip
    cmp w8, #45
    b.ne Lnth_formula_no
    mov x5, #-1
Lnth_b_skip:
    add x0, x0, #1
Lnth_b_trim:
    cmp x0, x1
    b.hs Lnth_formula_no
    ldrb w8, [x0]
    cmp w8, #32
    b.hi Lnth_b_digits_begin
    add x0, x0, #1
    b Lnth_b_trim
Lnth_b_digits_begin:
    mov x6, #0
    mov x7, #0
Lnth_b_digits:
    cmp x0, x1
    b.hs Lnth_b_done
    ldrb w8, [x0], #1
    sub w9, w8, #48
    cmp w9, #9
    b.hi Lnth_formula_no
    mov x10, #10
    madd x6, x6, x10, x9
    cmp x6, #32768
    b.hi Lnth_formula_no
    add x7, x7, #1
    b Lnth_b_digits
Lnth_b_done:
    cbz x7, Lnth_formula_no
    mul x4, x6, x5
Lnth_evaluate:
    sub x9, x2, x4
    cbz x3, Lnth_zero_coefficient
    sdiv x10, x9, x3
    cmp x10, #0
    b.lt Lnth_formula_no
    msub x9, x10, x3, x9
Lnth_zero_coefficient:
    cmp x9, #0
    cset x0, eq
    ret
Lnth_constant:
    cbz x7, Lnth_formula_no
    mul x6, x6, x5
    cmp x6, x2
    cset x0, eq
    ret
Lnth_formula_no:
    mov x0, #0
    ret

// flow-doc,node,expressionStart,expressionEnd,flags (bit0 reverse,bit1 oftype).
// Walk persistent DOM siblings so comments, stylesheet nodes, hidden elements
// and unknown tags have correct structural-selector semantics.
.globl _css_nth_match
_css_nth_match:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    mov x22, x4
    ldr x23, [x19, #96]
    cbz x23, Lnth_match_no
    ldr x9, [x19, #72]
    add x9, x9, x1, lsl #11
    ldr x1, [x9, #2008]
    mov x0, x23
    bl _engine_dom_node
    cbz x0, Lnth_match_no
    mov x24, x0
    ldr x9, [x24, #48]
    str x9, [sp, #144]
    ldr x9, [x24]
    cmp x9, #1
    b.ne Lnth_match_no
    mov x25, #1
Lnth_match_sibling:
    ldr x9, [x19, #88]
    cbz x9, Lnth_match_no
    sub x9, x9, #1
    str x9, [x19, #88]
    mov x9, #32                   // DOM previous / next offsets
    tbz x22, #0, Lnth_match_direction
    mov x9, #40
Lnth_match_direction:
    ldr x1, [x24, x9]
    cbz x1, Lnth_match_evaluate
    mov x0, x23
    bl _engine_dom_node
    cbz x0, Lnth_match_no
    mov x24, x0
    ldr x9, [x24]
    cmp x9, #1
    b.ne Lnth_match_sibling
    tbz x22, #1, Lnth_match_count
    ldr x0, [x24, #48]
    // Compare with the original target name, saved on first iteration.
    ldr x1, [sp, #144]
    bl _strcmp
    cbnz x0, Lnth_match_sibling
Lnth_match_count:
    add x25, x25, #1
    b Lnth_match_sibling
Lnth_match_evaluate:
    mov x0, x20
    mov x1, x21
    mov x2, x25
    bl _css_nth_formula
    LEAVE
Lnth_match_no:
    mov x0, #0
    LEAVE

// doc,node -> :empty. Comments do not count; whitespace text does count.
.globl _css_dom_empty
_css_dom_empty:
    ENTER
    mov x19, x0
    ldr x20, [x19, #96]
    cbz x20, Ldom_empty_no
    ldr x9, [x19, #72]
    add x9, x9, x1, lsl #11
    ldr x1, [x9, #2008]
    mov x0, x20
    bl _engine_dom_node
    cbz x0, Ldom_empty_no
    ldr x9, [x0]
    cmp x9, #1
    b.ne Ldom_empty_no
    ldr x21, [x0, #16]
Ldom_empty_next:
    cbz x21, Ldom_empty_yes
    ldr x9, [x19, #88]
    cbz x9, Ldom_empty_no
    sub x9, x9, #1
    str x9, [x19, #88]
    mov x0, x20
    mov x1, x21
    bl _engine_dom_node
    cbz x0, Ldom_empty_no
    ldr x21, [x0, #40]
    ldr x9, [x0]
    cmp x9, #1
    b.eq Ldom_empty_no
    cmp x9, #2
    b.ne Ldom_empty_next
    ldr x9, [x0, #56]
    cbz x9, Ldom_empty_next
    ldrb w9, [x9]
    cbnz w9, Ldom_empty_no
    b Ldom_empty_next
Ldom_empty_yes:
    mov x0, #1
    LEAVE
Ldom_empty_no:
    mov x0, #0
    LEAVE
