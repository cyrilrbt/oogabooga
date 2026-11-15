// Bounded CSS declaration/value parser. Unknown or malformed declarations are ignored.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// trim(start,end) -> trimmed [x0,x1).
.globl _css_trim
_css_trim:
Ltrim_left:
    cmp x0, x1
    b.hs Ltrim_return
    ldrb w2, [x0]
    cmp w2, #32
    b.hi Ltrim_right
    add x0, x0, #1
    b Ltrim_left
Ltrim_right:
    cmp x1, x0
    b.ls Ltrim_return
    sub x2, x1, #1
    ldrb w3, [x2]
    cmp w3, #32
    b.hi Ltrim_return
    mov x1, x2
    b Ltrim_right
Ltrim_return:
    ret

// skip(start,end) -> next non-whitespace/non-comment position, or end.
.globl _css_skip
_css_skip:
Lskip_next:
    cmp x0, x1
    b.hs Lskip_return
    ldrb w2, [x0]
    cmp w2, #32
    b.hi Lskip_comment
    add x0, x0, #1
    b Lskip_next
Lskip_comment:
    cmp w2, #47
    b.ne Lskip_return
    add x2, x0, #1
    cmp x2, x1
    b.hs Lskip_return
    ldrb w3, [x2]
    cmp w3, #42
    b.ne Lskip_return
    add x0, x0, #2
Lskip_comment_loop:
    add x2, x0, #1
    cmp x2, x1
    b.hs Lskip_end
    ldrb w3, [x0], #1
    cmp w3, #42
    b.ne Lskip_comment_loop
    ldrb w3, [x0]
    cmp w3, #47
    b.ne Lskip_comment_loop
    add x0, x0, #1
    b Lskip_next
Lskip_end:
    mov x0, x1
Lskip_return:
    ret

// eq(start,end,constant): ASCII case-insensitive exact match.
.globl _css_eq
_css_eq:
    ENTER
    mov x19, x0
    sub x20, x1, x0
    mov x21, x2
    mov x0, x2
    bl _strlen
    cmp x0, x20
    b.ne Leq_no
    mov x0, x19
    mov x1, x21
    mov x2, x20
    bl _strncasecmp
    cmp w0, #0
    cset w0, eq
    LEAVE
Leq_no:
    mov w0, #0
    LEAVE

// number(start,end) -> magnitude*1000 in x0, unit in x1, valid in x2.
// unit: 0 unitless, 1 px, 2 em, 3 %, 4 rem. Negative values are unsupported.
.globl _css_number
_css_number:
    ENTER
    bl _css_trim
    mov x19, x0
    mov x20, x1
    mov x21, #0
    mov x22, #0
    mov x23, #0
Lnumber_integer:
    cmp x19, x20
    b.hs Lnumber_suffix
    ldrb w9, [x19]
    sub w10, w9, #48
    cmp w10, #9
    b.hi Lnumber_dot
    mov x11, #10
    madd x21, x21, x11, x10
    mov x9, #10000
    cmp x21, x9
    b.hi Lnumber_bad
    add x19, x19, #1
    add x23, x23, #1
    b Lnumber_integer
Lnumber_dot:
    cmp w9, #46
    b.ne Lnumber_suffix
    add x19, x19, #1
    mov x24, #100
Lnumber_fraction:
    cmp x19, x20
    b.hs Lnumber_suffix
    ldrb w9, [x19]
    sub w10, w9, #48
    cmp w10, #9
    b.hi Lnumber_suffix
    madd x22, x10, x24, x22
    mov x11, #10
    udiv x24, x24, x11
    add x23, x23, #1
    add x19, x19, #1
    b Lnumber_fraction
Lnumber_suffix:
    cbz x23, Lnumber_bad
    mov x9, #1000
    madd x21, x21, x9, x22
    cmp x19, x20
    b.eq Lnumber_unitless
    mov x0, x19
    mov x1, x20
    ADDR x2, px_text
    bl _css_eq
    cbnz w0, Lnumber_px
    mov x0, x19
    mov x1, x20
    ADDR x2, em_text
    bl _css_eq
    cbnz w0, Lnumber_em
    mov x0, x19
    mov x1, x20
    ADDR x2, rem_text
    bl _css_eq
    cbnz w0, Lnumber_rem
    sub x9, x20, x19
    cmp x9, #1
    b.ne Lnumber_bad
    ldrb w9, [x19]
    cmp w9, #37
    b.ne Lnumber_bad
    mov x1, #3
    b Lnumber_good
Lnumber_unitless:
    mov x1, #0
    b Lnumber_good
Lnumber_px:
    mov x1, #1
    b Lnumber_good
Lnumber_em:
    mov x1, #2
    b Lnumber_good
Lnumber_rem:
    mov x1, #4
Lnumber_good:
    mov x0, x21
    mov x2, #1
    LEAVE
Lnumber_bad:
    mov x0, #0
    mov x1, #0
    mov x2, #0
    LEAVE

// color(start,end) -> RGB or transparent(-1), valid x1.
.globl _css_color
_css_color:
    ENTER
    bl _css_trim
    mov x19, x0
    mov x20, x1
    bl _css_extended_color
    cbnz x1, Lcolor_good_return
    mov x0, x19
    mov x1, x20
    cmp x0, x1
    b.hs Lcolor_bad
    ldrb w9, [x0]
    cmp w9, #35
    b.eq Lcolor_hex
    sub x9, x20, x19
    cmp x9, #5
    b.lo Lcolor_names
    mov x0, x19
    ADDR x1, rgb_text
    mov x2, #4
    bl _strncasecmp
    cbz w0, Lcolor_rgb
Lcolor_names:
    ADDR x21, color_table
Lcolor_name:
    ldr x2, [x21]
    cbz x2, Lcolor_bad
    mov x0, x19
    mov x1, x20
    bl _css_eq
    cbnz w0, Lcolor_named
    add x21, x21, #16
    b Lcolor_name
Lcolor_named:
    ldr x0, [x21, #8]
    mov x1, #1
    LEAVE
Lcolor_rgb:
    sub x21, x20, #1
    ldrb w9, [x21]
    cmp w9, #41
    b.ne Lcolor_bad
    add x19, x19, #4
    mov x22, #0
    mov x23, #0
Lrgb_component:
    mov x24, x19
Lrgb_find_end:
    cmp x24, x21
    b.hs Lrgb_parse
    ldrb w9, [x24]
    cmp w9, #44
    b.eq Lrgb_parse
    add x24, x24, #1
    b Lrgb_find_end
Lrgb_parse:
    mov x0, x19
    mov x1, x24
    bl _css_number
    cbz x2, Lcolor_bad
    cbz x1, Lrgb_absolute
    cmp x1, #3
    b.ne Lcolor_bad
    mov x9, #255
    mul x0, x0, x9
    mov x9, #50000
    add x0, x0, x9
    mov x9, #1000
    mov x10, #100
    mul x9, x9, x10
    udiv x0, x0, x9
    b Lrgb_clamp
Lrgb_absolute:
    add x0, x0, #500
    mov x9, #1000
    udiv x0, x0, x9
Lrgb_clamp:
    mov x9, #255
    cmp x0, x9
    csel x0, x9, x0, hi
    lsl x23, x23, #8
    orr x23, x23, x0
    add x22, x22, #1
    cmp x22, #3
    b.eq Lrgb_finished
    cmp x24, x21
    b.hs Lcolor_bad
    add x19, x24, #1
    b Lrgb_component
Lrgb_finished:
    cmp x24, x21
    b.ne Lcolor_bad
    mov x0, x23
    mov x1, #1
    LEAVE
Lcolor_hex:
    sub x21, x20, x19
    cmp x21, #4
    b.eq Lcolor_digits
    cmp x21, #7
    b.ne Lcolor_bad
Lcolor_digits:
    add x19, x19, #1
    mov x22, #0
Lcolor_digit:
    cmp x19, x20
    b.hs Lcolor_good
    ldrb w9, [x19], #1
    sub w10, w9, #48
    cmp w10, #9
    b.ls Lcolor_add
    orr w9, w9, #32
    sub w10, w9, #97
    cmp w10, #5
    b.hi Lcolor_bad
    add w10, w10, #10
Lcolor_add:
    cmp x21, #4
    b.ne Lcolor_long
    mov x11, #17
    mul x10, x10, x11
    lsl x22, x22, #8
    orr x22, x22, x10
    b Lcolor_digit
Lcolor_long:
    lsl x22, x22, #4
    orr x22, x22, x10
    b Lcolor_digit
Lcolor_good:
    mov x0, x22
    mov x1, #1
    LEAVE
Lcolor_good_return:
    LEAVE
Lcolor_bad:
    mov x0, #0
    mov x1, #0
    LEAVE

// value(property,start,end) -> x0 value, x1 valid.
.globl _css_value
_css_value:
    ENTER
    mov x19, x0
    mov x0, x1
    mov x1, x2
    bl _css_trim
    mov x20, x0
    mov x21, x1
    ADDR x2, inherit_text
    bl _css_eq
    cbnz w0, Lvalue_inherit
    mov x0, x20
    mov x1, x21
    ADDR x2, initial_text
    bl _css_eq
    cbnz w0, Lvalue_initial
    mov x0, x20
    mov x1, x21
    ADDR x2, unset_text
    bl _css_eq
    cbnz w0, Lvalue_unset
    cmp x19, #CSS_POSITION
    b.hs Lvalue_layout
    cmp x19, #CSS_TOP
    b.eq Lvalue_margin_sign
    cmp x19, #CSS_BOTTOM
    b.eq Lvalue_margin_sign
    cmp x19, #CSS_LEFT
    b.eq Lvalue_margin_sign
    cmp x19, #CSS_RIGHT
    b.ne Lvalue_nonnegative_length
Lvalue_margin_sign:
    cmp x20, x21
    b.hs Lvalue_nonnegative_length
    ldrb w9, [x20]
    cmp w9, #45
    b.ne Lvalue_nonnegative_length
    mov x0, #CSS_INSET_LEFT
    mov x1, x20
    mov x2, x21
    bl _css_layout_value
    LEAVE
Lvalue_nonnegative_length:
    cmp x19, #CSS_BORDER_RIGHT
    b.hs Lvalue_length
    cmp x19, #CSS_GROW
    b.eq Lvalue_factor
    cmp x19, #CSS_SHRINK
    b.eq Lvalue_factor
    cmp x19, #CSS_OPACITY
    b.eq Lvalue_factor
    cmp x19, #CSS_BACKGROUND
    b.ls Lvalue_color
    cmp x19, #CSS_FILL
    b.eq Lvalue_color
    cmp x19, #CSS_STROKE
    b.eq Lvalue_color
    cmp x19, #CSS_STROKE_WIDTH
    b.eq Lvalue_length
    cmp x19, #CSS_GAP
    b.eq Lvalue_length
    cmp x19, #CSS_ROW_GAP
    b.eq Lvalue_length
    cmp x19, #CSS_COLUMN_GAP
    b.eq Lvalue_length
    cmp x19, #CSS_BASIS
    b.eq Lvalue_length
    cmp x19, #CSS_MAX_WIDTH
    b.eq Lvalue_length
    cmp x19, #CSS_RADIUS
    b.eq Lvalue_length
    cmp x19, #CSS_MIN_HEIGHT
    b.eq Lvalue_length
    cmp x19, #CSS_MIN_WIDTH
    b.eq Lvalue_length
    cmp x19, #CSS_BORDER_COLOR
    b.eq Lvalue_color
    cmp x19, #CSS_WIDTH
    b.lo Lvalue_old_lengths
    cmp x19, #CSS_BORDER
    b.ls Lvalue_length
Lvalue_old_lengths:
    cmp x19, #CSS_SIZE
    b.eq Lvalue_length
    cmp x19, #CSS_TOP
    b.eq Lvalue_length
    cmp x19, #CSS_BOTTOM
    b.eq Lvalue_length
    cmp x19, #CSS_LINE
    b.eq Lvalue_length
    cmp x19, #CSS_LEFT
    b.eq Lvalue_length
    cmp x19, #CSS_RIGHT
    b.eq Lvalue_length
    cmp x19, #CSS_FAMILY
    b.eq Lvalue_family
    ADDR x22, keyword_table
Lvalue_keyword:
    ldr x9, [x22]
    cmn x9, #1
    b.eq Lvalue_weight_number
    cmp x9, x19
    b.ne Lvalue_keyword_next
    mov x0, x20
    mov x1, x21
    ldr x2, [x22, #8]
    bl _css_eq
    cbnz w0, Lvalue_keyword_found
Lvalue_keyword_next:
    add x22, x22, #24
    b Lvalue_keyword
Lvalue_keyword_found:
    ldr x0, [x22, #16]
    b Lvalue_good
Lvalue_weight_number:
    cmp x19, #CSS_WEIGHT
    b.ne Lvalue_bad
    mov x0, x20
    mov x1, x21
    bl _css_number
    cbz x2, Lvalue_bad
    cbnz x1, Lvalue_bad
    mov x9, #1000
    udiv x0, x0, x9
    cmp x0, #100
    b.lo Lvalue_bad
    cmp x0, #900
    b.hi Lvalue_bad
    b Lvalue_good
Lvalue_layout:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _css_layout_value
    LEAVE
Lvalue_factor:
    mov x0, x20
    mov x1, x21
    bl _css_number
    cbz x2, Lvalue_bad
    cbnz x1, Lvalue_bad
    mov x9, #1000
    cmp x19, #CSS_OPACITY
    b.eq Lvalue_factor_clamp
    mov x9, #60000
Lvalue_factor_clamp:
    cmp x0, x9
    csel x0, x9, x0, hi
    b Lvalue_good
Lvalue_color:
    mov x0, x20
    mov x1, x21
    ADDR x2, current_color_text
    bl _css_eq
    cbz w0, Lvalue_not_current
    mov x0, #-6
    b Lvalue_good
Lvalue_not_current:
    mov x0, x20
    mov x1, x21
    ADDR x2, none_text
    bl _css_eq
    cbz w0, Lvalue_parse_color
    cmp x19, #CSS_FILL
    b.eq Lvalue_paint_none
    cmp x19, #CSS_STROKE
    b.ne Lvalue_bad
Lvalue_paint_none:
    mov x0, #-1
    b Lvalue_good
Lvalue_parse_color:
    mov x0, x20
    mov x1, x21
    bl _css_color
    cbz x1, Lvalue_bad
    cmn x0, #1
    b.ne Lvalue_good
    cmp x19, #CSS_COLOR
    b.ne Lvalue_good
    mov x0, #0x10000000000
    b Lvalue_good
    b Lvalue_good
Lvalue_length:
    mov x0, x20
    mov x1, x21
    ADDR x2, auto_text
    bl _css_eq
    cbz w0, Lvalue_length_normal
    cmp x19, #CSS_WIDTH
    b.eq Lvalue_auto
    cmp x19, #CSS_HEIGHT
    b.eq Lvalue_auto
    cmp x19, #CSS_MAX_WIDTH
    b.eq Lvalue_auto
    cmp x19, #CSS_BASIS
    b.eq Lvalue_auto
    cmp x19, #CSS_TOP
    b.eq Lvalue_margin_auto
    cmp x19, #CSS_BOTTOM
    b.eq Lvalue_margin_auto
    cmp x19, #CSS_LEFT
    b.eq Lvalue_margin_auto
    cmp x19, #CSS_RIGHT
    b.ne Lvalue_bad
Lvalue_margin_auto:
    mov x0, #-5
    b Lvalue_good
Lvalue_auto:
    mov x0, #-1
    b Lvalue_good
Lvalue_length_normal:
    mov x0, x20
    mov x1, x21
    ADDR x2, normal_text
    bl _css_eq
    cbz w0, Lvalue_length_number
    cmp x19, #CSS_LINE
    b.ne Lvalue_bad
    mov x0, #0
    b Lvalue_good
Lvalue_length_number:
    mov x0, x20
    mov x1, x21
    bl _css_number
    cbz x2, Lvalue_bad
    cmp x19, #CSS_LINE
    b.eq Lvalue_encode
    cmp x19, #CSS_STROKE_WIDTH
    b.eq Lvalue_encode
    cbnz x1, Lvalue_length_units
    cbnz x0, Lvalue_bad             // only unitless zero outside line-height
Lvalue_length_units:
    cmp x19, #CSS_SIZE
    b.eq Lvalue_encode
    cmp x1, #3
    b.ne Lvalue_encode
    cmp x19, #CSS_BORDER
    b.eq Lvalue_bad
Lvalue_encode:
    lsl x1, x1, #32
    orr x0, x0, x1
    orr x0, x0, #0x8000000000000000
    b Lvalue_good
Lvalue_family:
    // Try each comma-separated fallback; quoted names are accepted.
    mov x22, x20
Lfamily_next:
    cmp x22, x21
    b.hs Lvalue_bad
    mov x23, x22
Lfamily_scan:
    cmp x23, x21
    b.hs Lfamily_token
    ldrb w9, [x23]
    cmp w9, #44
    b.eq Lfamily_token
    add x23, x23, #1
    b Lfamily_scan
Lfamily_token:
    mov x0, x22
    mov x1, x23
    bl _css_trim
    mov x24, x0
    mov x25, x1
    cmp x24, x25
    b.hs Lfamily_advance
    ldrb w9, [x24]
    cmp w9, #34
    b.eq Lfamily_unquote
    cmp w9, #39
    b.ne Lfamily_lookup
Lfamily_unquote:
    sub x10, x25, #1
    ldrb w11, [x10]
    cmp w9, w11
    b.ne Lfamily_advance
    add x24, x24, #1
    mov x25, x10
Lfamily_lookup:
    mov x0, x24
    mov x1, x25
    bl _engine_font_family_lookup
    cbnz x0, Lvalue_good
    ADDR x26, family_table
Lfamily_name:
    ldr x2, [x26]
    cbz x2, Lfamily_advance
    mov x0, x24
    mov x1, x25
    bl _css_eq
    cbnz w0, Lfamily_found
    add x26, x26, #16
    b Lfamily_name
Lfamily_found:
    ldr x0, [x26, #8]
    b Lvalue_good
Lfamily_advance:
    add x22, x23, #1
    b Lfamily_next
Lvalue_inherit:
    mov x0, #CSS_INHERIT
    b Lvalue_good
Lvalue_initial:
    mov x0, #CSS_INITIAL
    b Lvalue_good
Lvalue_unset:
    mov x0, #CSS_UNSET
Lvalue_good:
    mov x1, #1
    LEAVE
Lvalue_bad:
    mov x0, #0
    mov x1, #0
    LEAVE

// declarations(start,end,decl): mask, important-mask, 24 value slots. Caller zeroes it.
.globl _css_declarations
_css_declarations:
    mov x3, #0
.globl _css_declarations_resolved
_css_declarations_resolved:
    ENTER
    str x3, [sp, #192]
    str xzr, [sp, #184]
    mov x19, x0
    mov x20, x1
    mov x21, x2
Ldecl_next:
    ldr x0, [sp, #184]
    bl _free
    str xzr, [sp, #184]
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    cmp x19, x20
    b.hs Ldecl_done
    mov x22, x19
Ldecl_name:
    cmp x19, x20
    b.hs Ldecl_done
    ldrb w9, [x19], #1
    cmp w9, #59
    b.eq Ldecl_next
    cmp w9, #58
    b.ne Ldecl_name
    sub x1, x19, #1
    mov x0, x22
    bl _css_trim
    mov x22, x0
    mov x23, x1
    mov x24, x19
    mov x25, #0                     // quote
    mov x26, #0                     // parentheses
Ldecl_scan_value:
    cmp x19, x20
    b.hs Ldecl_value_end
    ldrb w9, [x19]
    cbz x25, Ldecl_value_unquoted
    cmp w9, #92
    b.eq Ldecl_escape
    cmp w9, w25
    b.ne Ldecl_scan_advance
    mov x25, #0
    b Ldecl_scan_advance
Ldecl_escape:
    add x19, x19, #1
    cmp x19, x20
    b.hs Ldecl_value_end
    b Ldecl_scan_advance
Ldecl_value_unquoted:
    cmp w9, #34
    b.eq Ldecl_quote
    cmp w9, #39
    b.eq Ldecl_quote
    cmp w9, #40
    b.eq Ldecl_paren_open
    cmp w9, #41
    b.eq Ldecl_paren_close
    cbnz x26, Ldecl_scan_advance
    cmp w9, #59
    b.eq Ldecl_value_end
Ldecl_scan_advance:
    add x19, x19, #1
    b Ldecl_scan_value
Ldecl_quote:
    mov x25, x9
    b Ldecl_scan_advance
Ldecl_paren_open:
    add x26, x26, #1
    b Ldecl_scan_advance
Ldecl_paren_close:
    cbz x26, Ldecl_scan_advance
    sub x26, x26, #1
    b Ldecl_scan_advance
Ldecl_value_end:
    mov x0, x24
    mov x1, x19
    bl _css_trim
    mov x24, x0
    mov x25, x1
    mov x26, #0                     // !important flag
    sub x9, x25, x24
    cmp x9, #10
    b.lo Ldecl_property
    sub x0, x25, #9
    mov x1, x25
    ADDR x2, important_word
    bl _css_eq
    cbz w0, Ldecl_property
    sub x1, x25, #9
    mov x0, x24
    bl _css_trim
    cmp x1, x0
    b.ls Ldecl_property
    sub x27, x1, #1
    ldrb w9, [x27]
    cmp w9, #33
    b.ne Ldecl_property
    mov x0, x24
    mov x1, x27
    bl _css_trim
    mov x24, x0
    mov x25, x1
    mov x26, #1
Ldecl_property:
    ldr x2, [sp, #192]
    cbz x2, Ldecl_expanded
    mov x0, x24
    mov x1, x25
    bl _css_expand
    cbz x0, Ldecl_advance
    str x0, [sp, #184]
    mov x24, x0
    bl _strlen
    add x25, x24, x0
Ldecl_expanded:
    ADDR x27, property_table
Ldecl_property_next:
    ldr x2, [x27]
    cbz x2, Ldecl_advance
    mov x0, x22
    mov x1, x23
    bl _css_eq
    cbnz w0, Ldecl_property_found
    add x27, x27, #16
    b Ldecl_property_next
Ldecl_property_found:
    ldr x28, [x27, #8]
    cmp x28, #CSS_OVERFLOW
    b.eq Ldecl_overflow
    cmp x28, #108
    b.hs Ldecl_grid_placement
    cmp x28, #107
    b.eq Ldecl_border_style
    cmp x28, #106
    b.eq Ldecl_margin
    cmp x28, #105
    b.eq Ldecl_gap
    cmp x28, #104
    b.eq Ldecl_flex
    cmp x28, #103
    b.eq Ldecl_font
    cmp x28, #102
    b.eq Ldecl_border
    cmp x28, #100                    // margin shorthand
    b.eq Ldecl_margin
    cmp x28, #101
    b.eq Ldecl_margin
    mov x0, x28
    mov x1, x24
    mov x2, x25
    bl _css_value
    cbz x1, Ldecl_advance
    mov x1, x28
    mov x2, x26
    mov x3, x0
    mov x0, x21
    bl _css_store_decl
    b Ldecl_advance
Ldecl_grid_placement:
    mov x0, x24
    mov x1, x25
    mov x2, x21
    mov x3, x26
    mov x4, #CSS_GRID_COLUMN
    cmp x28, #109
    mov x9, #CSS_GRID_ROW
    csel x4, x9, x4, eq
    bl _css_grid_placement
    b Ldecl_advance
Ldecl_overflow:
    mov x0, x24
    mov x1, x25
    mov x2, x21
    mov x3, x26
    bl _css_overflow_declarations
    b Ldecl_advance
Ldecl_border_style:
    mov x0, x24
    mov x1, x25
    ADDR x2, none_text
    bl _css_eq
    cbz w0, Ldecl_advance
    mov x0, x21
    mov x1, x26
    mov x2, #0
    mov x3, #0
    mov x4, #0
    mov x5, #0
    bl _css_border_sides
    b Ldecl_advance
Ldecl_gap:
    mov x0, x24
    mov x1, x25
    mov x2, x21
    mov x3, x26
    bl _css_gap_declarations
    b Ldecl_advance
Ldecl_flex:
    mov x0, x24
    mov x1, x25
    mov x2, x21
    mov x3, x26
    bl _css_flex_declarations
    b Ldecl_advance
Ldecl_font:
    mov x0, x24
    mov x1, x25
    mov x2, x21
    mov x3, x26
    bl _css_font_declarations
    b Ldecl_advance
Ldecl_border:
    mov x0, x24
    mov x1, x25
    mov x2, x21
    mov x3, x26
    bl _css_border_declarations
    b Ldecl_advance
Ldecl_margin:
    str x28, [sp, #176]
    // Parse up to four whitespace-delimited lengths, then expand T/R/B/L.
    mov x22, x24
    mov x23, #0
Lmargin_token:
    mov x0, x22
    mov x1, x25
    bl _css_trim
    mov x22, x0
    cmp x22, x25
    b.hs Lmargin_expand
    cmp x23, #4
    b.hs Ldecl_advance
    mov x24, x22
Lmargin_token_end:
    cmp x24, x25
    b.hs Lmargin_value
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lmargin_value
    add x24, x24, #1
    b Lmargin_token_end
Lmargin_value:
    mov x0, #CSS_LEFT
    ldr x9, [sp, #176]
    cmp x9, #101
    mov x9, #CSS_PAD_TOP
    csel x0, x9, x0, eq
    mov x1, x22
    mov x2, x24
    bl _css_value
    cbz x1, Ldecl_advance
    add x9, sp, #144
    str x0, [x9, x23, lsl #3]
    add x23, x23, #1
    mov x22, x24
    b Lmargin_token
Lmargin_expand:
    cbz x23, Ldecl_advance
    ldr x22, [sp, #144]
    mov x24, x22
    mov x27, x22
    mov x28, x22
    cmp x23, #2
    b.lo Lmargin_store
    ldr x24, [sp, #152]
    mov x28, x24
    cmp x23, #3
    b.lo Lmargin_store
    ldr x27, [sp, #160]
    cmp x23, #4
    b.lo Lmargin_store
    ldr x28, [sp, #168]
Lmargin_store:
    ldr x9, [sp, #176]
    cmp x9, #106
    b.ne Lmargin_store_normal
    mov x0, x21
    mov x1, x26
    mov x2, x22
    mov x3, x24
    mov x4, x27
    mov x5, x28
    bl _css_border_sides
    b Ldecl_advance
Lmargin_store_normal:
    mov x0, x21
    mov x1, #CSS_TOP
    ldr x9, [sp, #176]
    cmp x9, #101
    mov x9, #CSS_PAD_TOP
    csel x1, x9, x1, eq
    mov x2, x26
    mov x3, x22
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_RIGHT
    ldr x9, [sp, #176]
    cmp x9, #101
    mov x9, #CSS_PAD_RIGHT
    csel x1, x9, x1, eq
    mov x2, x26
    mov x3, x24
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BOTTOM
    ldr x9, [sp, #176]
    cmp x9, #101
    mov x9, #CSS_PAD_BOTTOM
    csel x1, x9, x1, eq
    mov x2, x26
    mov x3, x27
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_LEFT
    ldr x9, [sp, #176]
    cmp x9, #101
    mov x9, #CSS_PAD_LEFT
    csel x1, x9, x1, eq
    mov x2, x26
    mov x3, x28
    bl _css_store_decl
Ldecl_advance:
    cmp x19, x20
    b.hs Ldecl_done
    add x19, x19, #1
    b Ldecl_next
Ldecl_done:
    ldr x0, [sp, #184]
    bl _free
    LEAVE

// Store one declaration, preserving an earlier !important against later normal values.
.globl _css_store_decl
_css_store_decl:
    cmp x1, #64
    b.hs Lstore_extended
    mov x4, #1
    lsl x4, x4, x1
    ldr x5, [x0, #8]
    cbnz x2, Lstore_important
    tst x5, x4
    b.ne Lstore_return
    b Lstore_value
Lstore_important:
    orr x5, x5, x4
    str x5, [x0, #8]
Lstore_value:
    ldr x5, [x0]
    orr x5, x5, x4
    str x5, [x0]
    add x0, x0, #16
    str x3, [x0, x1, lsl #3]
Lstore_return:
    ret
Lstore_extended:
    sub x1, x1, #64
    mov x4, #1
    lsl x4, x4, x1
    ldr x5, [x0, #536]
    cbnz x2, Lstore_ext_important
    tst x5, x4
    b.ne Lstore_return
    b Lstore_ext_value
Lstore_ext_important:
    orr x5, x5, x4
    str x5, [x0, #536]
Lstore_ext_value:
    ldr x5, [x0, #528]
    orr x5, x5, x4
    str x5, [x0, #528]
    add x0, x0, #544
    str x3, [x0, x1, lsl #3]
    ret

.section __DATA,__const
.p2align 3
property_table:
.quad p_vertical_align, CSS_VERTICAL_ALIGN
.quad p_white_space, CSS_WHITE_SPACE
.quad p_word_spacing, CSS_WORD_SPACING
.quad p_letter_spacing, CSS_LETTER_SPACING
.quad p_position, CSS_POSITION
.quad p_inset_top, CSS_INSET_TOP
.quad p_inset_right, CSS_INSET_RIGHT
.quad p_inset_bottom, CSS_INSET_BOTTOM
.quad p_inset_left, CSS_INSET_LEFT
.quad p_z_index, CSS_Z_INDEX
.quad p_overflow, CSS_OVERFLOW
.quad p_overflow_x, CSS_OVERFLOW_X
.quad p_overflow_y, CSS_OVERFLOW_Y
.quad p_grid_columns, CSS_GRID_COLUMNS
.quad p_grid_rows, CSS_GRID_ROWS
.quad p_grid_column, 108
.quad p_grid_row, 109
.quad p_grid_column_start, CSS_GRID_COLUMN
.quad p_grid_row_start, CSS_GRID_ROW
.quad p_grid_auto_rows, CSS_GRID_AUTO_ROWS
.quad p_direction, CSS_DIRECTION
.quad p_justify, CSS_JUSTIFY
.quad p_align_items, CSS_ALIGN_ITEMS
.quad p_gap, 105
.quad p_row_gap, CSS_ROW_GAP
.quad p_column_gap, CSS_COLUMN_GAP
.quad p_wrap, CSS_WRAP
.quad p_grow, CSS_GROW
.quad p_shrink, CSS_SHRINK
.quad p_basis, CSS_BASIS
.quad p_align_self, CSS_ALIGN_SELF
.quad p_fill, CSS_FILL
.quad p_stroke, CSS_STROKE
.quad p_stroke_width, CSS_STROKE_WIDTH
.quad p_opacity, CSS_OPACITY
.quad p_flex, 104
.quad p_radius, CSS_RADIUS
.quad p_min_height, CSS_MIN_HEIGHT
.quad p_min_width, CSS_MIN_WIDTH
.quad p_font, 103
.quad p_color, CSS_COLOR
.quad p_background, CSS_BACKGROUND
.quad p_background_color, CSS_BACKGROUND
.quad p_size, CSS_SIZE
.quad p_weight, CSS_WEIGHT
.quad p_style, CSS_ITALIC
.quad p_decoration, CSS_UNDERLINE
.quad p_align, CSS_ALIGN
.quad p_display, CSS_DISPLAY
.quad p_max_height, CSS_MAX_HEIGHT
.quad p_top, CSS_TOP
.quad p_bottom, CSS_BOTTOM
.quad p_line, CSS_LINE
.quad p_family, CSS_FAMILY
.quad p_left, CSS_LEFT
.quad p_right, CSS_RIGHT
.quad p_max_width, CSS_MAX_WIDTH
.quad p_box_sizing, CSS_BOX_SIZING
.quad p_border, 102
.quad p_margin, 100
.quad p_width, CSS_WIDTH
.quad p_height, CSS_HEIGHT
.quad p_padding_top, CSS_PAD_TOP
.quad p_padding_right, CSS_PAD_RIGHT
.quad p_padding_bottom, CSS_PAD_BOTTOM
.quad p_padding_left, CSS_PAD_LEFT
.quad p_border_width, 106
.quad p_border_top_width, CSS_BORDER
.quad p_border_right_width, CSS_BORDER_RIGHT
.quad p_border_bottom_width, CSS_BORDER_BOTTOM
.quad p_border_left_width, CSS_BORDER_LEFT
.quad p_border_style, 107
.quad p_float, CSS_FLOAT
.quad p_clear, CSS_CLEAR
.quad p_border_color, CSS_BORDER_COLOR
.quad p_padding, 101
.quad 0, 0
color_table:
.quad c_black, 0x000000
.quad c_white, 0xffffff
.quad c_red, 0xff0000
.quad c_green, 0x008000
.quad c_blue, 0x0000ff
.quad c_yellow, 0xffff00
.quad c_gray, 0x808080
.quad c_grey, 0x808080
.quad c_silver, 0xc0c0c0
.quad c_maroon, 0x800000
.quad c_purple, 0x800080
.quad c_fuchsia, 0xff00ff
.quad c_lime, 0x00ff00
.quad c_olive, 0x808000
.quad c_navy, 0x000080
.quad c_teal, 0x008080
.quad c_aqua, 0x00ffff
.quad c_orange, 0xffa500
.quad c_rebecca, 0x663399
.quad c_transparent, -1
.quad 0, 0
family_table:
.quad f_verdana, 3
.quad f_mono, 0
.quad f_courier, 0
.quad f_sans, 1
.quad f_arial, 1
.quad f_helvetica, 1
.quad f_system, 1
.quad f_serif, 2
.quad f_times, 2
.quad f_times_new, 2
.quad f_georgia, 2
.quad 0, 0
keyword_table:
.quad CSS_FLOAT, none_text, 0
.quad CSS_FLOAT, left_text, 1
.quad CSS_FLOAT, right_text, 2
.quad CSS_CLEAR, none_text, 0
.quad CSS_CLEAR, left_text, 1
.quad CSS_CLEAR, right_text, 2
.quad CSS_CLEAR, both_text, 3
.quad CSS_DIRECTION, flow_CSS_DIRECTION_0, 0
.quad CSS_DIRECTION, flow_CSS_DIRECTION_1, 1
.quad CSS_DIRECTION, flow_CSS_DIRECTION_2, 2
.quad CSS_DIRECTION, flow_CSS_DIRECTION_3, 3
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_0, 0
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_1, 0
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_2, 1
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_3, 1
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_4, 2
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_5, 3
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_6, 4
.quad CSS_JUSTIFY, flow_CSS_JUSTIFY_7, 5
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_0, 0
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_1, 1
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_2, 1
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_3, 2
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_4, 3
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_5, 3
.quad CSS_ALIGN_ITEMS, flow_CSS_ALIGN_ITEMS_6, 4
.quad CSS_ALIGN_SELF, flow_CSS_ALIGN_SELF_0, -1
.quad CSS_ALIGN_SELF, flow_CSS_ALIGN_SELF_1, 0
.quad CSS_ALIGN_SELF, flow_CSS_ALIGN_SELF_2, 1
.quad CSS_ALIGN_SELF, flow_CSS_ALIGN_SELF_3, 2
.quad CSS_ALIGN_SELF, flow_CSS_ALIGN_SELF_4, 3
.quad CSS_ALIGN_SELF, flow_CSS_ALIGN_SELF_5, 4
.quad CSS_WRAP, flow_CSS_WRAP_0, 0
.quad CSS_WRAP, flow_CSS_WRAP_1, 1
.quad CSS_WRAP, flow_CSS_WRAP_2, 2
.quad CSS_VERTICAL_ALIGN, baseline_text, 0
.quad CSS_VERTICAL_ALIGN, middle_text, 1
.quad CSS_BOX_SIZING, content_box, 0
.quad CSS_BOX_SIZING, border_box, 1
.quad CSS_WEIGHT, normal_text, 400
.quad CSS_WEIGHT, bold_text, 700
.quad CSS_WEIGHT, bolder_text, 700
.quad CSS_WEIGHT, lighter_text, 300
.quad CSS_ITALIC, normal_text, 0
.quad CSS_ITALIC, italic_text, 1
.quad CSS_ITALIC, oblique_text, 1
.quad CSS_UNDERLINE, none_text, 0
.quad CSS_UNDERLINE, underline_text, 1
.quad CSS_ALIGN, left_text, 0
.quad CSS_ALIGN, start_text, 0
.quad CSS_ALIGN, right_text, 1
.quad CSS_ALIGN, end_text, 1
.quad CSS_ALIGN, center_text, 2
.quad CSS_ALIGN, justify_text, 3
.quad CSS_DISPLAY, none_text, 1
.quad CSS_DISPLAY, flex_text, 3
.quad CSS_DISPLAY, inline_flex_text, 3
.quad CSS_DISPLAY, grid_text, 4
.quad CSS_DISPLAY, block_text, 0
.quad CSS_DISPLAY, inline_text, 2
.quad CSS_DISPLAY, inline_block_text, 5
.quad -1, 0, 0
.section __TEXT,__cstring,cstring_literals
rgb_text: .asciz "rgb("
px_text: .asciz "px"
em_text: .asciz "em"
rem_text: .asciz "rem"
inherit_text: .asciz "inherit"
initial_text: .asciz "initial"
unset_text: .asciz "unset"
normal_text: .asciz "normal"
important_word: .asciz "important"
none_text: .asciz "none"
bold_text: .asciz "bold"
bolder_text: .asciz "bolder"
lighter_text: .asciz "lighter"
italic_text: .asciz "italic"
oblique_text: .asciz "oblique"
underline_text: .asciz "underline"
left_text: .asciz "left"
right_text: .asciz "right"
start_text: .asciz "start"
end_text: .asciz "end"
center_text: .asciz "center"
justify_text: .asciz "justify"
block_text: .asciz "block"
inline_text: .asciz "inline"
inline_block_text: .asciz "inline-block"
p_color: .asciz "color"
p_background: .asciz "background"
p_background_color: .asciz "background-color"
p_size: .asciz "font-size"
p_weight: .asciz "font-weight"
p_style: .asciz "font-style"
p_decoration: .asciz "text-decoration"
p_align: .asciz "text-align"
p_display: .asciz "display"
p_max_height: .asciz "max-height"
p_vertical_align: .asciz "vertical-align"
p_white_space: .asciz "white-space"
p_word_spacing: .asciz "word-spacing"
p_letter_spacing: .asciz "letter-spacing"
p_top: .asciz "margin-top"
p_bottom: .asciz "margin-bottom"
p_line: .asciz "line-height"
p_family: .asciz "font-family"
p_left: .asciz "margin-left"
p_right: .asciz "margin-right"
p_margin: .asciz "margin"
c_black: .asciz "black"
c_white: .asciz "white"
c_red: .asciz "red"
c_green: .asciz "green"
c_blue: .asciz "blue"
c_yellow: .asciz "yellow"
c_gray: .asciz "gray"
c_grey: .asciz "grey"
c_silver: .asciz "silver"
c_maroon: .asciz "maroon"
c_purple: .asciz "purple"
c_fuchsia: .asciz "fuchsia"
c_lime: .asciz "lime"
c_olive: .asciz "olive"
c_navy: .asciz "navy"
c_teal: .asciz "teal"
c_aqua: .asciz "aqua"
c_orange: .asciz "orange"
c_rebecca: .asciz "rebeccapurple"
c_transparent: .asciz "transparent"
f_mono: .asciz "monospace"
f_courier: .asciz "courier"
f_sans: .asciz "sans-serif"
f_arial: .asciz "arial"
f_helvetica: .asciz "helvetica"
f_system: .asciz "system-ui"
f_serif: .asciz "serif"
f_times: .asciz "times"
f_times_new: .asciz "times new roman"
f_georgia: .asciz "georgia"

auto_text: .asciz "auto"
p_width: .asciz "width"
p_height: .asciz "height"
p_padding_top: .asciz "padding-top"
p_padding_right: .asciz "padding-right"
p_padding_bottom: .asciz "padding-bottom"
p_padding_left: .asciz "padding-left"
p_border_width: .asciz "border-width"
p_border_color: .asciz "border-color"
p_padding: .asciz "padding"
p_max_width: .asciz "max-width"
p_box_sizing: .asciz "box-sizing"
p_border: .asciz "border"
content_box: .asciz "content-box"
border_box: .asciz "border-box"

.section __TEXT,__cstring,cstring_literals
p_font: .asciz "font"

.section __TEXT,__cstring,cstring_literals
flex_text: .asciz "flex"
grid_text: .asciz "grid"

.section __TEXT,__cstring,cstring_literals
p_radius: .asciz "border-radius"
p_min_height: .asciz "min-height"
p_min_width: .asciz "min-width"
p_valign: .asciz "vertical-align"
baseline_text: .asciz "baseline"
middle_text: .asciz "middle"

.section __TEXT,__cstring,cstring_literals
flow_CSS_DIRECTION_0: .asciz "row"
flow_CSS_DIRECTION_1: .asciz "column"
flow_CSS_DIRECTION_2: .asciz "row-reverse"
flow_CSS_DIRECTION_3: .asciz "column-reverse"
flow_CSS_JUSTIFY_0: .asciz "flex-start"
flow_CSS_JUSTIFY_1: .asciz "start"
flow_CSS_JUSTIFY_2: .asciz "flex-end"
flow_CSS_JUSTIFY_3: .asciz "end"
flow_CSS_JUSTIFY_4: .asciz "center"
flow_CSS_JUSTIFY_5: .asciz "space-between"
flow_CSS_JUSTIFY_6: .asciz "space-around"
flow_CSS_JUSTIFY_7: .asciz "space-evenly"
flow_CSS_ALIGN_ITEMS_0: .asciz "stretch"
flow_CSS_ALIGN_ITEMS_1: .asciz "flex-start"
flow_CSS_ALIGN_ITEMS_2: .asciz "start"
flow_CSS_ALIGN_ITEMS_3: .asciz "center"
flow_CSS_ALIGN_ITEMS_4: .asciz "flex-end"
flow_CSS_ALIGN_ITEMS_5: .asciz "end"
flow_CSS_ALIGN_ITEMS_6: .asciz "baseline"
flow_CSS_ALIGN_SELF_0: .asciz "auto"
flow_CSS_ALIGN_SELF_1: .asciz "stretch"
flow_CSS_ALIGN_SELF_2: .asciz "flex-start"
flow_CSS_ALIGN_SELF_3: .asciz "center"
flow_CSS_ALIGN_SELF_4: .asciz "flex-end"
flow_CSS_ALIGN_SELF_5: .asciz "baseline"
flow_CSS_WRAP_0: .asciz "nowrap"
flow_CSS_WRAP_1: .asciz "wrap"
flow_CSS_WRAP_2: .asciz "wrap-reverse"
p_direction: .asciz "flex-direction"
p_justify: .asciz "justify-content"
p_align_items: .asciz "align-items"
p_gap: .asciz "gap"
p_row_gap: .asciz "row-gap"
p_column_gap: .asciz "column-gap"
p_wrap: .asciz "flex-wrap"
p_grow: .asciz "flex-grow"
p_shrink: .asciz "flex-shrink"
p_basis: .asciz "flex-basis"
p_align_self: .asciz "align-self"
p_flex: .asciz "flex"
p_fill: .asciz "fill"
p_stroke: .asciz "stroke"
p_stroke_width: .asciz "stroke-width"
p_opacity: .asciz "opacity"
inline_flex_text: .asciz "inline-flex"
current_color_text: .asciz "currentColor"

p_float: .asciz "float"
p_clear: .asciz "clear"
both_text: .asciz "both"
p_border_top_width: .asciz "border-top-width"
p_border_right_width: .asciz "border-right-width"
p_border_bottom_width: .asciz "border-bottom-width"
p_border_left_width: .asciz "border-left-width"
p_border_style: .asciz "border-style"
f_verdana: .asciz "Verdana"

p_position: .asciz "position"
p_inset_top: .asciz "top"
p_inset_right: .asciz "right"
p_inset_bottom: .asciz "bottom"
p_inset_left: .asciz "left"
p_z_index: .asciz "z-index"
p_overflow: .asciz "overflow"
p_overflow_x: .asciz "overflow-x"
p_overflow_y: .asciz "overflow-y"
p_grid_columns: .asciz "grid-template-columns"
p_grid_rows: .asciz "grid-template-rows"
p_grid_column: .asciz "grid-column"
p_grid_row: .asciz "grid-row"
p_grid_column_start: .asciz "grid-column-start"
p_grid_row_start: .asciz "grid-row-start"
p_grid_auto_rows: .asciz "grid-auto-rows"
