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
    cmp x19, #CSS_BACKGROUND
    b.ls Lvalue_color
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
Lvalue_color:
    mov x0, x20
    mov x1, x21
    bl _css_color
    cbz x1, Lvalue_bad
    cmn x0, #1
    b.ne Lvalue_good
    cmp x19, #CSS_BACKGROUND
    b.ne Lvalue_bad                 // transparent foreground not supported
    b Lvalue_good
Lvalue_length:
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
    cbnz x1, Lvalue_length_units
    cbnz x0, Lvalue_bad             // only unitless zero outside line-height
Lvalue_length_units:
    cmp x19, #CSS_SIZE
    b.eq Lvalue_encode
    cmp x1, #3
    b.eq Lvalue_bad                 // percentage margins need a box layout engine
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

// declarations(start,end,decl): mask, important-mask, 14 value slots. Caller zeroes it.
.globl _css_declarations
_css_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
Ldecl_next:
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
    cmp x28, #14                    // margin shorthand
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
Ldecl_margin:
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
    mov x0, #CSS_TOP
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
    mov x0, x21
    mov x1, #CSS_TOP
    mov x2, x26
    mov x3, x22
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_RIGHT
    mov x2, x26
    mov x3, x24
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BOTTOM
    mov x2, x26
    mov x3, x27
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_LEFT
    mov x2, x26
    mov x3, x28
    bl _css_store_decl
Ldecl_advance:
    cmp x19, x20
    b.hs Ldecl_done
    add x19, x19, #1
    b Ldecl_next
Ldecl_done:
    LEAVE

// Store one declaration, preserving an earlier !important against later normal values.
_css_store_decl:
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

.section __DATA,__const
.p2align 3
property_table:
.quad p_color, CSS_COLOR
.quad p_background, CSS_BACKGROUND
.quad p_background_color, CSS_BACKGROUND
.quad p_size, CSS_SIZE
.quad p_weight, CSS_WEIGHT
.quad p_style, CSS_ITALIC
.quad p_decoration, CSS_UNDERLINE
.quad p_align, CSS_ALIGN
.quad p_display, CSS_DISPLAY
.quad p_top, CSS_TOP
.quad p_bottom, CSS_BOTTOM
.quad p_line, CSS_LINE
.quad p_family, CSS_FAMILY
.quad p_left, CSS_LEFT
.quad p_right, CSS_RIGHT
.quad p_margin, 14
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
.quad CSS_DISPLAY, block_text, 0
.quad CSS_DISPLAY, inline_text, 0
.quad CSS_DISPLAY, inline_block_text, 0
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
