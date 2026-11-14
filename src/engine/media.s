// Conservative screen media queries: [only] screen/all and min/max-width in px.
// Unknown conditions and comma lists remain inactive, rather than applying the
// wrong theme or print styles. Fixed-point comparisons preserve fractional px.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _css_media_match
_css_media_match:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x9, #1000
    mul x21, x2, x9
    mov x22, #0                     // have a condition/type
    mov x23, #0                     // expecting a condition after 'and'
Lmedia_next:
    mov x0, x19
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x19, x20
    b.hs Lmedia_end
    ldrb w9, [x19]
    cmp w9, #40
    b.eq Lmedia_feature
    mov x24, x19
Lmedia_word_end:
    cmp x24, x20
    b.hs Lmedia_word
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lmedia_word
    add x24, x24, #1
    b Lmedia_word_end
Lmedia_word:
    mov x0, x19
    mov x1, x24
    ADDR x2, media_only
    bl _css_eq
    cbnz w0, Lmedia_only_word
    mov x0, x19
    mov x1, x24
    ADDR x2, media_and
    bl _css_eq
    cbnz w0, Lmedia_and_word
    cbnz x22, Lmedia_no
    mov x0, x19
    mov x1, x24
    ADDR x2, media_screen
    bl _css_eq
    cbnz w0, Lmedia_type
    mov x0, x19
    mov x1, x24
    ADDR x2, media_all
    bl _css_eq
    cbz w0, Lmedia_no
Lmedia_type:
    mov x22, #1
    mov x23, #0
    b Lmedia_word_advance
Lmedia_only_word:
    cbnz x22, Lmedia_no
    cbnz x23, Lmedia_no
    mov x23, #1
    b Lmedia_word_advance
Lmedia_and_word:
    cbz x22, Lmedia_no
    cbnz x23, Lmedia_no
    mov x23, #1
Lmedia_word_advance:
    mov x19, x24
    b Lmedia_next
Lmedia_feature:
    cbz x22, Lmedia_feature_start
    cbz x23, Lmedia_no
Lmedia_feature_start:
    add x19, x19, #1
    mov x24, x19
Lmedia_colon:
    cmp x24, x20
    b.hs Lmedia_no
    ldrb w9, [x24]
    cmp w9, #58
    b.eq Lmedia_name
    add x24, x24, #1
    b Lmedia_colon
Lmedia_name:
    mov x0, x19
    mov x1, x24
    bl _css_trim
    mov x25, x0
    mov x26, x1
    ADDR x2, media_min
    bl _css_eq
    mov x27, x0
    cbnz w0, Lmedia_value_start
    mov x0, x25
    mov x1, x26
    ADDR x2, media_max
    bl _css_eq
    cbz w0, Lmedia_no
Lmedia_value_start:
    add x19, x24, #1
    mov x24, x19
Lmedia_close:
    cmp x24, x20
    b.hs Lmedia_no
    ldrb w9, [x24]
    cmp w9, #41
    b.eq Lmedia_value
    add x24, x24, #1
    b Lmedia_close
Lmedia_value:
    mov x0, x19
    mov x1, x24
    bl _css_number
    cbz x2, Lmedia_no
    cmp x1, #1
    b.ne Lmedia_no
    cmp x21, x0
    cbz x27, Lmedia_maximum
    b.lo Lmedia_no
    b Lmedia_feature_done
Lmedia_maximum:
    b.hi Lmedia_no
Lmedia_feature_done:
    mov x22, #1
    mov x23, #0
    add x19, x24, #1
    b Lmedia_next
Lmedia_end:
    cbz x22, Lmedia_no
    cbnz x23, Lmedia_no
    mov x0, #1
    LEAVE
Lmedia_no:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
media_only: .asciz "only"
media_and: .asciz "and"
media_screen: .asciz "screen"
media_all: .asciz "all"
media_min: .asciz "min-width"
media_max: .asciz "max-width"
