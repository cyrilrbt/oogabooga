.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// Attribute number with a supplied default in d0.
.globl _svg_attribute_number
_svg_attribute_number:
    ENTER
    str d0, [sp, #144]
    bl _engine_attribute
    cbz x0, Lsvg_attribute_default
    mov x19, x0
    bl _strlen
    add x1, x19, x0
    mov x0, x19
    bl _svg_number
    cbz x1, Lsvg_attribute_free
    str d0, [sp, #144]
Lsvg_attribute_free:
    mov x0, x19
    bl _free
Lsvg_attribute_default:
    ldr d0, [sp, #144]
    LEAVE

// start,end,name,currentColor -> paint or none, with caller fallback x4.
svg_attribute_paint:
    ENTER
    mov x19, x3
    mov x20, x4
    bl _engine_attribute
    cbz x0, Lsvg_paint_fallback
    mov x21, x0
    bl _strlen
    add x22, x21, x0
    mov x0, x21
    mov x1, x22
    ADDR x2, svg_none
    bl _css_eq
    cbz w0, Lsvg_paint_current
    mov x20, #-1
    b Lsvg_paint_free
Lsvg_paint_current:
    mov x0, x21
    mov x1, x22
    ADDR x2, svg_current_color
    bl _css_eq
    cbz w0, Lsvg_paint_color
    mov x20, x19
    b Lsvg_paint_free
Lsvg_paint_color:
    mov x0, x21
    mov x1, x22
    bl _css_color
    cbz x1, Lsvg_paint_free
    mov x20, x0
Lsvg_paint_free:
    mov x0, x21
    bl _free
Lsvg_paint_fallback:
    mov x0, x20
    LEAVE

// attrs start/end,state[64],CSS metadata (optional). State inherits from groups.
.globl _mac_svg_paint
_mac_svg_paint:
    ENTER
    sub sp, sp, #688
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, #0
    cbz x22, Lsvg_paint_attrs
    ldr x23, [x22, #32]
    tbnz x23, #63, Lsvg_default_current
    b Lsvg_paint_attrs
Lsvg_default_current:
    mov x23, #0
Lsvg_paint_attrs:
    mov x0, x19
    mov x1, x20
    ADDR x2, svg_fill
    mov x3, x23
    ldr x4, [x21]
    bl svg_attribute_paint
    str x0, [x21]
    mov x0, x19
    mov x1, x20
    ADDR x2, svg_stroke
    mov x3, x23
    ldr x4, [x21, #8]
    bl svg_attribute_paint
    str x0, [x21, #8]
    mov x0, x19
    mov x1, x20
    ADDR x2, svg_stroke_width
    ldr d0, [x21, #16]
    bl _svg_attribute_number
    fabs d0, d0
    str d0, [x21, #16]
    mov x24, #0
    ADDR x25, svg_opacity_attributes
Lsvg_opacity_attr:
    cmp x24, #3
    b.hs Lsvg_fill_rule
    mov x0, x19
    mov x1, x20
    ldr x2, [x25, x24, lsl #3]
    fmov d0, #1.0
    cbz x24, Lsvg_opacity_read
    add x9, x21, #24
    ldr d0, [x9, x24, lsl #3]
Lsvg_opacity_read:
    bl _svg_attribute_number
    fmov d1, xzr
    fmax d0, d0, d1
    fmov d1, #1.0
    fmin d0, d0, d1
    add x9, x21, #24
    cbnz x24, Lsvg_opacity_store
    ldr d1, [x9, x24, lsl #3]
    fmul d0, d0, d1
Lsvg_opacity_store:
    str d0, [x9, x24, lsl #3]
    add x24, x24, #1
    b Lsvg_opacity_attr
Lsvg_fill_rule:
    mov x0, x19
    mov x1, x20
    ADDR x2, svg_fill_rule
    bl _engine_attribute
    cbz x0, Lsvg_paint_style
    mov x24, x0
    bl _strlen
    add x1, x24, x0
    mov x0, x24
    ADDR x2, svg_evenodd
    bl _css_eq
    cmp w0, #0
    cset x9, ne
    ldr x10, [x21, #48]
    bfi x10, x9, #0, #1
    str x10, [x21, #48]
    mov x0, x24
    bl _free
Lsvg_paint_style:
    mov x0, x19
    mov x1, x20
    ADDR x2, svg_display
    bl _engine_attribute
    cbz x0, Lsvg_line_attributes_start
    mov x24, x0
    bl _strlen
    add x1, x24, x0
    mov x0, x24
    ADDR x2, svg_none
    bl _css_eq
    cbz w0, Lsvg_display_free
    mov x9, #1
    str x9, [x21, #56]
Lsvg_display_free:
    mov x0, x24
    bl _free
Lsvg_line_attributes_start:
    mov x24, #0
    ADDR x25, svg_line_attributes
Lsvg_line_attribute:
    cmp x24, #2
    b.hs Lsvg_paint_style_value
    mov x0, x19
    mov x1, x20
    ldr x2, [x25, x24, lsl #3]
    bl _engine_attribute
    cbz x0, Lsvg_line_attribute_next
    mov x26, x0
    bl _strlen
    add x27, x26, x0
    mov x0, x26
    mov x1, x27
    ADDR x2, svg_round
    bl _css_eq
    cbz w0, Lsvg_line_not_round
    mov x28, #1
    b Lsvg_line_store
Lsvg_line_not_round:
    mov x0, x26
    mov x1, x27
    ADDR x2, svg_square
    cbz x24, Lsvg_line_last_keyword
    ADDR x2, svg_bevel
Lsvg_line_last_keyword:
    bl _css_eq
    cmp w0, #0
    mov x9, #2
    csel x28, x9, xzr, ne
Lsvg_line_store:
    ldr x9, [x21, #48]
    cbnz x24, Lsvg_line_join_store
    bfi x9, x28, #8, #2
    b Lsvg_line_flags
Lsvg_line_join_store:
    bfi x9, x28, #16, #2
Lsvg_line_flags:
    str x9, [x21, #48]
    mov x0, x26
    bl _free
Lsvg_line_attribute_next:
    add x24, x24, #1
    b Lsvg_line_attribute
Lsvg_paint_style_value:
    mov x0, x19
    mov x1, x20
    ADDR x2, svg_style
    bl _engine_attribute
    cbz x0, Lsvg_paint_done
    mov x24, x0
    mov x0, sp
    mov x1, #0
    mov x2, #CSS_DECL_SIZE
    bl _memset
    mov x0, x24
    bl _strlen
    add x1, x24, x0
    mov x0, x24
    mov x2, sp
    mov x3, x22
    bl _css_declarations_resolved
    ldr x9, [sp]
    tbz x9, #CSS_DISPLAY, Lsvg_style_paint
    ldr x10, [sp, #(16+CSS_DISPLAY*8)]
    cmp x10, #1
    b.ne Lsvg_style_paint
    str x10, [x21, #56]
Lsvg_style_paint:
    tbz x9, #CSS_FILL, Lsvg_style_stroke
    ldr x10, [sp, #(16+CSS_FILL*8)]
    cmn x10, #6
    csel x10, x23, x10, eq
    str x10, [x21]
Lsvg_style_stroke:
    tbz x9, #CSS_STROKE, Lsvg_style_width
    ldr x10, [sp, #(16+CSS_STROKE*8)]
    cmn x10, #6
    csel x10, x23, x10, eq
    str x10, [x21, #8]
Lsvg_style_width:
    tbz x9, #CSS_STROKE_WIDTH, Lsvg_style_opacity
    str x9, [sp, #656]
    ldr x0, [sp, #(16+CSS_STROKE_WIDTH*8)]
    // Raw px width from the declaration parser; SVG unitless lengths also work.
    and x0, x0, #0xffffffff
    mov x10, #1000
    udiv x0, x0, x10
    scvtf d0, x0
    str d0, [x21, #16]
    ldr x9, [sp, #656]
Lsvg_style_opacity:
    tbz x9, #CSS_OPACITY, Lsvg_style_free
    ldr x9, [sp, #(16+CSS_OPACITY*8)]
    scvtf d0, x9
    NUM d1, 1000
    fdiv d0, d0, d1
    ldr d1, [x21, #24]
    fmul d0, d0, d1
    str d0, [x21, #24]
Lsvg_style_free:
    mov x0, x24
    bl _free
Lsvg_paint_done:
    add sp, sp, #688
    LEAVE

// CGContext,state -> fill/stroke the path with inherited paint and opacity.
.globl _mac_svg_draw_path
_mac_svg_draw_path:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x9, [x20, #48]
    ubfx x1, x9, #8, #2
    bl _CGContextSetLineCap
    mov x0, x19
    ldr x9, [x20, #48]
    ubfx x1, x9, #16, #2
    bl _CGContextSetLineJoin
    mov x21, #0
    ldr x0, [x20]
    cmn x0, #1
    b.eq Lsvg_draw_stroke
    bl _mac_css_color
    MSG CGColor
    mov x1, x0
    mov x0, x19
    bl _CGContextSetFillColorWithColor
    mov x21, #1
Lsvg_draw_stroke:
    ldr x0, [x20, #8]
    cmn x0, #1
    b.eq Lsvg_draw_ready
    bl _mac_css_color
    MSG CGColor
    mov x1, x0
    mov x0, x19
    bl _CGContextSetStrokeColorWithColor
    mov x0, x19
    ldr d0, [x20, #16]
    bl _CGContextSetLineWidth
    orr x21, x21, #2
Lsvg_draw_ready:
    cbz x21, Lsvg_draw_empty
    mov x22, #0
    cmp x21, #3
    b.ne Lsvg_draw_fill
    mov x0, x19
    bl _CGContextCopyPath
    mov x22, x0
Lsvg_draw_fill:
    tbz x21, #0, Lsvg_draw_only_stroke
    mov x0, x19
    ldr d0, [x20, #24]
    ldr d1, [x20, #32]
    fmul d0, d0, d1
    bl _CGContextSetAlpha
    mov x0, x19
    ldr x1, [x20, #48]
    and x1, x1, #1
    bl _CGContextDrawPath
    tbz x21, #1, Lsvg_draw_release
    mov x0, x19
    mov x1, x22
    bl _CGContextAddPath
Lsvg_draw_only_stroke:
    mov x0, x19
    ldr d0, [x20, #24]
    ldr d1, [x20, #40]
    fmul d0, d0, d1
    bl _CGContextSetAlpha
    mov x0, x19
    mov x1, #2
    bl _CGContextDrawPath
Lsvg_draw_release:
    cbz x22, Lsvg_draw_return
    mov x0, x22
    bl _CGPathRelease
Lsvg_draw_return:
    LEAVE
Lsvg_draw_empty:
    mov x0, x19
    bl _CGContextBeginPath
    LEAVE
.section __DATA,__const
.p2align 3
svg_line_attributes: .quad svg_linecap,svg_linejoin
svg_opacity_attributes: .quad svg_opacity,svg_fill_opacity,svg_stroke_opacity
.section __TEXT,__cstring,cstring_literals
svg_none: .asciz "none"
svg_current_color: .asciz "currentColor"
svg_fill: .asciz "fill"
svg_stroke: .asciz "stroke"
svg_stroke_width: .asciz "stroke-width"
svg_opacity: .asciz "opacity"
svg_fill_opacity: .asciz "fill-opacity"
svg_stroke_opacity: .asciz "stroke-opacity"
svg_fill_rule: .asciz "fill-rule"
svg_evenodd: .asciz "evenodd"
svg_style: .asciz "style"

.section __TEXT,__cstring,cstring_literals
svg_linecap: .asciz "stroke-linecap"
svg_linejoin: .asciz "stroke-linejoin"
svg_round: .asciz "round"
svg_square: .asciz "square"
svg_bevel: .asciz "bevel"

.section __TEXT,__cstring,cstring_literals
svg_display: .asciz "display"
