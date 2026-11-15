.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// property,start,end -> value,valid. Extension values never own heap pointers.
.globl _css_layout_value
_css_layout_value:
    ENTER
    mov x19, x0
    mov x0, x1
    mov x1, x2
    bl _css_trim
    mov x20, x0
    mov x21, x1
    cmp x19, #CSS_MAX_HEIGHT
    b.eq Llayout_max_height
    cmp x19, #CSS_VERTICAL_ALIGN
    b.eq Llayout_vertical
    cmp x19, #CSS_WORD_SPACING
    b.eq Llayout_spacing
    cmp x19, #CSS_LETTER_SPACING
    b.eq Llayout_spacing
    cmp x19, #CSS_GRID_COLUMNS
    b.eq Llayout_tracks
    cmp x19, #CSS_GRID_ROWS
    b.eq Llayout_tracks
    cmp x19, #CSS_GRID_AUTO_ROWS
    b.eq Llayout_length
    cmp x19, #CSS_INSET_TOP
    b.lo Llayout_keywords
    cmp x19, #CSS_INSET_LEFT
    b.ls Llayout_length
    cmp x19, #CSS_Z_INDEX
    b.eq Llayout_z
    cmp x19, #CSS_GRID_COLUMN
    b.lo Llayout_keywords
    cmp x19, #CSS_GRID_ROWSPAN
    b.ls Llayout_integer
Llayout_keywords:
    ADDR x22, layout_keywords
Llayout_keyword:
    ldr x9, [x22]
    cmn x9, #1
    b.eq Llayout_bad
    cmp x19, x9
    b.ne Llayout_keyword_next
    mov x0, x20
    mov x1, x21
    ldr x2, [x22, #8]
    bl _css_eq
    cbnz x0, Llayout_keyword_yes
Llayout_keyword_next:
    add x22, x22, #24
    b Llayout_keyword
Llayout_keyword_yes:
    ldr x0, [x22, #16]
    b Llayout_good
Llayout_vertical:
    // Keyword values are distinct from signed pixel/percentage offsets.
    ADDR x22, layout_keywords
    b Llayout_keyword
Llayout_spacing:
    mov x0, x20
    mov x1, x21
    ADDR x2, kw_normal
    bl _css_eq
    cbnz x0, Llayout_zero
    b Llayout_signed
Llayout_tracks:
    mov x0, x20
    mov x1, x21
    bl _css_grid_tracks
    LEAVE
Llayout_max_height:
    mov x0, x20
    mov x1, x21
    ADDR x2, kw_none
    bl _css_eq
    cbnz x0, Llayout_z_auto
    mov x0, x20
    mov x1, x21
    ADDR x2, kw_auto
    bl _css_eq
    cbnz x0, Llayout_bad
    mov x0, #CSS_WIDTH
    mov x1, x20
    mov x2, x21
    bl _css_value
    LEAVE
Llayout_z:
    mov x0, x20
    mov x1, x21
    ADDR x2, kw_auto
    bl _css_eq
    cbnz x0, Llayout_z_auto
    mov x22, #0
    cmp x20, x21
    b.hs Llayout_bad
    ldrb w9, [x20]
    cmp w9, #45
    b.ne Llayout_z_number
    mov x22, #1
    add x20, x20, #1
Llayout_z_number:
    mov x0, x20
    mov x1, x21
    mov x2, #32767
    bl _css_positive_integer
    cbz x1, Llayout_bad
    cbz x22, Llayout_z_bias
    neg x0, x0
Llayout_z_bias:
    add x0, x0, #32768
    b Llayout_good
Llayout_z_auto:
    mov x0, #-1
    b Llayout_good
Llayout_integer:
    mov x0, x20
    mov x1, x21
    ADDR x2, kw_auto
    bl _css_eq
    cbnz x0, Llayout_zero
    mov x0, x20
    mov x1, x21
    mov x2, #256
    bl _css_positive_integer
    LEAVE
Llayout_length:
    mov x0, x20
    mov x1, x21
    ADDR x2, kw_auto
    bl _css_eq
    cbz x0, Llayout_signed
    mov x0, #-1
    b Llayout_good
Llayout_signed:
    mov x22, #0
    cmp x20, x21
    b.hs Llayout_bad
    ldrb w9, [x20]
    cmp w9, #45
    b.ne Llayout_number
    mov x22, #1
    add x20, x20, #1
Llayout_number:
    mov x0, #CSS_WIDTH
    mov x1, x20
    mov x2, x21
    bl _css_value
    cbz x1, Llayout_bad
    cbz x22, Llayout_good
    orr x0, x0, #0x4000000000000000
    b Llayout_good
Llayout_zero:
    mov x0, #0
Llayout_good:
    mov x1, #1
    LEAVE
Llayout_bad:
    // vertical-align also accepts a length when it was not a keyword.
    cmp x19, #CSS_VERTICAL_ALIGN
    b.ne Llayout_reject
    mov x19, #-1
    b Llayout_signed
Llayout_reject:
    mov x0, #0
    mov x1, #0
    LEAVE
.section __DATA,__const
.p2align 3
layout_keywords:
.quad CSS_WHITE_SPACE, kw_normal, 0
.quad CSS_WHITE_SPACE, kw_pre, 1
.quad CSS_WHITE_SPACE, kw_nowrap, 2
.quad CSS_WHITE_SPACE, kw_pre_wrap, 3
.quad CSS_WHITE_SPACE, kw_pre_line, 4
.quad CSS_WHITE_SPACE, kw_break_spaces, 5
.quad CSS_VERTICAL_ALIGN, kw_baseline, -16
.quad CSS_VERTICAL_ALIGN, kw_top, -17
.quad CSS_VERTICAL_ALIGN, kw_middle, -18
.quad CSS_VERTICAL_ALIGN, kw_bottom, -19
.quad CSS_VERTICAL_ALIGN, kw_text_top, -20
.quad CSS_VERTICAL_ALIGN, kw_text_bottom, -21
.quad CSS_VERTICAL_ALIGN, kw_sub, -22
.quad CSS_VERTICAL_ALIGN, kw_super, -23
.quad CSS_POSITION, kw_static, 0
.quad CSS_POSITION, kw_relative, 1
.quad CSS_POSITION, kw_absolute, 2
.quad CSS_POSITION, kw_fixed, 3
.quad CSS_OVERFLOW, kw_visible, 0
.quad CSS_OVERFLOW, kw_hidden, 1
.quad CSS_OVERFLOW, kw_clip, 3
.quad CSS_OVERFLOW, kw_auto, 2
.quad CSS_OVERFLOW, kw_scroll, 2
.quad CSS_OVERFLOW_X, kw_visible, 0
.quad CSS_OVERFLOW_X, kw_hidden, 1
.quad CSS_OVERFLOW_X, kw_clip, 3
.quad CSS_OVERFLOW_X, kw_auto, 2
.quad CSS_OVERFLOW_X, kw_scroll, 2
.quad CSS_OVERFLOW_Y, kw_visible, 0
.quad CSS_OVERFLOW_Y, kw_hidden, 1
.quad CSS_OVERFLOW_Y, kw_clip, 3
.quad CSS_OVERFLOW_Y, kw_auto, 2
.quad CSS_OVERFLOW_Y, kw_scroll, 2
.quad -1,0,0
.section __TEXT,__cstring,cstring_literals
kw_auto: .asciz "auto"
kw_none: .asciz "none"
kw_normal: .asciz "normal"
kw_pre: .asciz "pre"
kw_nowrap: .asciz "nowrap"
kw_pre_wrap: .asciz "pre-wrap"
kw_pre_line: .asciz "pre-line"
kw_break_spaces: .asciz "break-spaces"
kw_baseline: .asciz "baseline"
kw_top: .asciz "top"
kw_middle: .asciz "middle"
kw_bottom: .asciz "bottom"
kw_text_top: .asciz "text-top"
kw_text_bottom: .asciz "text-bottom"
kw_sub: .asciz "sub"
kw_super: .asciz "super"
kw_static: .asciz "static"
kw_relative: .asciz "relative"
kw_absolute: .asciz "absolute"
kw_fixed: .asciz "fixed"
kw_visible: .asciz "visible"
kw_hidden: .asciz "hidden"
kw_clip: .asciz "clip"
kw_scroll: .asciz "scroll"
