// Modern rgb()/rgba() and alpha hex colors. Opaque RGB retains its old RGB24
// representation; alpha colors carry bit40 and an alpha byte in bits32..39.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _css_extended_color
_css_extended_color:
    ENTER
    mov x19, x0
    mov x20, x1
    sub x9, x20, x19
    cmp x9, #4
    b.lo Lextended_bad
    ldrb w9, [x19]
    cmp w9, #35
    b.eq Lextended_hex
    mov x0, x19
    ADDR x1, modern_rgb
    mov x2, #4
    bl _strncasecmp
    cbz w0, Lextended_rgb
    sub x9, x20, x19
    cmp x9, #6
    b.lo Lextended_bad
    mov x0, x19
    ADDR x1, modern_rgba
    mov x2, #5
    bl _strncasecmp
    cbnz w0, Lextended_bad
    add x19, x19, #1
Lextended_rgb:
    add x19, x19, #4
    sub x20, x20, #1
    ldrb w9, [x20]
    cmp w9, #41
    b.ne Lextended_bad
    mov x21, #0
    mov x22, #0
    mov x23, #0                     // comma mode
Lmodern_component:
    mov x0, x19
    mov x1, x20
    bl _css_trim
    mov x19, x0
    mov x24, x0
Lmodern_number_end:
    cmp x24, x20
    b.hs Lmodern_number
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lmodern_number
    cmp w9, #44
    b.eq Lmodern_number
    cmp w9, #47
    b.eq Lmodern_number
    add x24, x24, #1
    b Lmodern_number_end
Lmodern_number:
    mov x0, x19
    mov x1, x24
    bl _css_number
    cbz x2, Lextended_bad
    cbz x1, Lmodern_absolute
    cmp x1, #3
    b.ne Lextended_bad
    mov x9, #255
    mul x0, x0, x9
    mov x9, #50000
    add x0, x0, x9
    mov x9, #1000
    mov x10, #100
    mul x9, x9, x10
    udiv x0, x0, x9
    b Lmodern_clamp
Lmodern_absolute:
    add x0, x0, #500
    mov x9, #1000
    udiv x0, x0, x9
Lmodern_clamp:
    mov x9, #255
    cmp x0, x9
    csel x0, x9, x0, hi
    lsl x21, x21, #8
    orr x21, x21, x0
    add x22, x22, #1
    mov x0, x24
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x22, #3
    b.eq Lmodern_alpha
    cmp x19, x20
    b.hs Lextended_bad
    ldrb w9, [x19]
    cmp w9, #44
    b.ne Lmodern_space_separator
    mov x23, #1
    add x19, x19, #1
    b Lmodern_component
Lmodern_space_separator:
    cbnz x23, Lextended_bad
    cmp x19, x24
    b.eq Lextended_bad
    b Lmodern_component
Lmodern_alpha:
    cmp x19, x20
    b.eq Lmodern_opaque
    ldrb w9, [x19], #1
    cmp w9, #47
    b.eq Lmodern_alpha_number
    cmp w9, #44
    b.ne Lextended_bad
    cbz x23, Lextended_bad
Lmodern_alpha_number:
    mov x0, x19
    mov x1, x20
    bl _css_number
    cbz x2, Lextended_bad
    cbz x1, Lmodern_alpha_unitless
    cmp x1, #3
    b.ne Lextended_bad
    mov x9, #100
    udiv x0, x0, x9
Lmodern_alpha_unitless:
    mov x9, #1000
    cmp x0, x9
    csel x0, x9, x0, hi
    mov x9, #255
    mul x0, x0, x9
    add x0, x0, #500
    mov x9, #1000
    udiv x0, x0, x9
    b Lmodern_pack
Lmodern_opaque:
    mov x0, #255
Lmodern_pack:
    cmp x0, #255
    b.eq Lmodern_rgb_value
    orr x21, x21, x0, lsl #32
    orr x21, x21, #0x10000000000
Lmodern_rgb_value:
    mov x0, x21
    mov x1, #1
    LEAVE
Lextended_hex:
    sub x21, x20, x19
    cmp x21, #5
    b.eq Lmodern_hex_start
    cmp x21, #9
    b.ne Lextended_bad
Lmodern_hex_start:
    add x19, x19, #1
    mov x22, #0
Lmodern_hex_next:
    cmp x19, x20
    b.hs Lmodern_hex_done
    ldrb w9, [x19], #1
    sub w10, w9, #48
    cmp w10, #9
    b.ls Lmodern_hex_digit
    orr w9, w9, #32
    sub w10, w9, #97
    cmp w10, #5
    b.hi Lextended_bad
    add w10, w10, #10
Lmodern_hex_digit:
    cmp x21, #5
    b.ne Lmodern_hex_long
    mov x9, #17
    mul x10, x10, x9
    lsl x22, x22, #8
    orr x22, x22, x10
    b Lmodern_hex_next
Lmodern_hex_long:
    lsl x22, x22, #4
    orr x22, x22, x10
    b Lmodern_hex_next
Lmodern_hex_done:
    and x0, x22, #255
    lsr x21, x22, #8
    b Lmodern_pack
Lextended_bad:
    mov x0, #0
    mov x1, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
modern_rgb: .asciz "rgb("
modern_rgba: .asciz "rgba("
