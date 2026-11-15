// Bounded Grid track descriptors: four explicit tracks, or repeat(1..16, track).
// Four 14-bit tracks + count at bit56; repeat flag bit60. Units: px=0, fr=1,
// percentage=2, auto=3; magnitude 0..4095. No pointers escape declaration parsing.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _css_grid_tracks
_css_grid_tracks:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #0
    mov x22, #0
    mov x23, #0
    sub x9, x20, x19
    cmp x9, #8
    b.lo Ltracks_next
    mov x0, x19
    ADDR x1, repeat_word
    mov x2, #7
    bl _strncasecmp
    cbnz x0, Ltracks_next
    add x19, x19, #7
    mov x24, x19
Lrepeat_count:
    cmp x24, x20
    b.hs Ltracks_bad
    ldrb w9, [x24]
    cmp w9, #44
    b.eq Lrepeat_number
    add x24, x24, #1
    b Lrepeat_count
Lrepeat_number:
    mov x0, x19
    mov x1, x24
    mov x2, #16
    bl _css_positive_integer
    cbz x1, Ltracks_bad
    cbz x0, Ltracks_bad
    mov x23, x0
    add x19, x24, #1
    sub x20, x20, #1
    ldrb w9, [x20]
    cmp w9, #41
    b.ne Ltracks_bad
Ltracks_next:
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    cmp x19, x20
    b.hs Ltracks_done
    cmp x22, #4
    b.hs Ltracks_bad
    mov x24, x19
    // minmax(0,1fr) is equivalent to a flexible track for this initial subset.
    sub x9, x20, x19
    cmp x9, #13
    b.lo Ltrack_token_scan
    mov x0, x19
    ADDR x1, minmax_word
    mov x2, #7
    bl _strncasecmp
    cbnz x0, Ltrack_token_scan
    add x19, x19, #7
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    cmp x19, x20
    b.hs Ltracks_bad
    ldrb w9, [x19], #1
    cmp w9, #48
    b.ne Ltracks_bad
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    ldrb w9, [x19], #1
    cmp w9, #44
    b.ne Ltracks_bad
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    mov x24, x19
Ltrack_minmax_end:
    cmp x24, x20
    b.hs Ltracks_bad
    ldrb w9, [x24]
    cmp w9, #41
    b.eq Ltrack_minmax_parse
    add x24, x24, #1
    b Ltrack_minmax_end
Ltrack_minmax_parse:
    add x25, x24, #1
    b Ltrack_parse
Ltrack_token_scan:
    cmp x24, x20
    b.hs Ltrack_token_end
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Ltrack_token_end
    add x24, x24, #1
    b Ltrack_token_scan
Ltrack_token_end:
    mov x25, x24
Ltrack_parse:
    mov x0, x19
    mov x1, x24
    ADDR x2, auto_word
    bl _css_eq
    cbz x0, Ltrack_fr
    mov x26, #0x3000
    b Ltrack_pack
Ltrack_fr:
    sub x9, x24, x19
    cmp x9, #2
    b.lo Ltrack_length
    sub x9, x24, #2
    ldrb w10, [x9]
    orr w10, w10, #32
    cmp w10, #102
    b.ne Ltrack_length
    ldrb w10, [x9, #1]
    orr w10, w10, #32
    cmp w10, #114
    b.ne Ltrack_length
    mov x0, x19
    mov x1, x9
    mov x2, #4095
    bl _css_positive_integer
    cbz x1, Ltracks_bad
    cbz x0, Ltracks_bad
    orr x26, x0, #0x1000
    b Ltrack_pack
Ltrack_length:
    mov x0, x19
    mov x1, x24
    bl _css_number
    cbz x2, Ltracks_bad
    cmp x1, #3
    b.eq Ltrack_percent
    cmp x1, #1
    b.hi Ltracks_bad
    mov x9, #1000
    udiv x26, x0, x9
    cmp x26, #4095
    b.hi Ltracks_bad
    b Ltrack_pack
Ltrack_percent:
    mov x9, #100
    udiv x26, x0, x9             // percentage tenths
    cmp x26, #1000
    b.hi Ltracks_bad
    orr x26, x26, #0x2000
Ltrack_pack:
    mov x9, #14
    mul x9, x22, x9
    lsl x26, x26, x9
    orr x21, x21, x26
    add x22, x22, #1
    mov x19, x25
    b Ltracks_next
Ltracks_done:
    cbz x22, Ltracks_bad
    cbz x23, Ltracks_explicit
    cmp x22, #1
    b.ne Ltracks_bad
    mov x22, x23
    orr x21, x21, #0x1000000000000000
Ltracks_explicit:
    sub x22, x22, #1
    orr x0, x21, x22, lsl #56
    mov x1, #1
    LEAVE
Ltracks_bad:
    mov x0, #0
    mov x1, #0
    LEAVE

// ASCII nonnegative integer, strict units/fractions and bounded magnitude.
.globl _css_positive_integer
_css_positive_integer:
    ENTER
    mov x19, x2
    bl _css_trim
    bl _css_number
    cbz x2, Linteger_bad
    cbnz x1, Linteger_bad
    mov x9, #1000
    udiv x10, x0, x9
    msub x11, x10, x9, x0
    cbnz x11, Linteger_bad
    cmp x10, x19
    b.hi Linteger_bad
    mov x0, x10
    mov x1, #1
    LEAVE
Linteger_bad:
    mov x0, #0
    mov x1, #0
    LEAVE

// start,end,decl,important,first-property: Grid placement shorthand.
.globl _css_grid_placement
_css_grid_placement:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, #0
    mov x25, #1
    mov x26, x19
Lplacement_slash:
    cmp x26, x20
    b.hs Lplacement_first
    ldrb w9, [x26]
    cmp w9, #47
    b.eq Lplacement_first
    add x26, x26, #1
    b Lplacement_slash
Lplacement_first:
    // A standalone span has an auto start, e.g. grid-column:span 2.
    sub x9, x26, x19
    cmp x9, #5
    b.lo Lplacement_start_line
    mov x0, x19
    ADDR x1, span_word
    mov x2, #4
    bl _strncasecmp
    cbnz x0, Lplacement_start_line
    ldrb w9, [x19, #4]
    cmp w9, #32
    b.hi Lplacement_start_line
    cmp x26, x20
    b.ne Lplacement_done          // span/span combinations need full line grammar
    add x0, x19, #4
    mov x1, x20
    mov x2, #64
    bl _css_positive_integer
    cbz x1, Lplacement_done
    cbz x0, Lplacement_done
    mov x25, x0
    b Lplacement_commit
Lplacement_start_line:
    mov x0, x23
    mov x1, x19
    mov x2, x26
    bl _css_layout_value
    cbz x1, Lplacement_done
    mov x24, x0
    cmp x26, x20
    b.hs Lplacement_commit
    add x0, x26, #1
    mov x1, x20
    bl _css_trim
    mov x19, x0
    sub x9, x1, x0
    cmp x9, #4
    b.lo Lplacement_end_line
    mov x0, x19
    ADDR x1, span_word
    mov x2, #4
    bl _strncasecmp
    cbnz x0, Lplacement_end_line
    add x0, x19, #4
    mov x1, x20
    mov x2, #64
    bl _css_positive_integer
    cbz x1, Lplacement_done
    cbz x0, Lplacement_done
    mov x25, x0
    b Lplacement_commit
Lplacement_end_line:
    mov x0, x19
    mov x1, x20
    mov x2, #256
    bl _css_positive_integer
    cbz x1, Lplacement_done
    cmp x0, x24
    b.ls Lplacement_done
    sub x25, x0, x24
Lplacement_commit:
    mov x0, x21
    mov x1, x23
    mov x2, x22
    mov x3, x24
    bl _css_store_decl
    mov x0, x21
    add x1, x23, #1
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
Lplacement_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
repeat_word: .asciz "repeat("
minmax_word: .asciz "minmax("
auto_word: .asciz "auto"
span_word: .asciz "span"
