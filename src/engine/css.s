// Embedded/inline CSS collection, bounded stylesheet parsing, cascade and inheritance.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_css_capture
_engine_css_capture:
    ENTER
    ldr x19, [x0, #72]
    add x19, x19, x1, lsl #10
    str x4, [x19, #24]              // borrowed canonical tag name
    mov x20, x2
    mov x21, x3
    // Repeated explicit document start tags replace owned attribute strings safely.
    ldr x0, [x19]
    bl _free
    ldr x0, [x19, #8]
    bl _free
    ldr x0, [x19, #16]
    bl _free
    mov x0, x20
    mov x1, x21
    ADDR x2, id_name
    bl _engine_attribute
    str x0, [x19]
    mov x0, x20
    mov x1, x21
    ADDR x2, class_name
    bl _engine_attribute
    str x0, [x19, #8]
    mov x0, x20
    mov x1, x21
    ADDR x2, style_name
    bl _engine_attribute
    str x0, [x19, #16]
    mov x22, #0
    ADDR x23, html_attributes
Lcapture_extra:
    ldr x2, [x23, x22, lsl #3]
    cbz x2, Lcapture_done
    add x24, x19, #512
    ldr x0, [x24, x22, lsl #3]
    bl _free
    mov x0, x20
    mov x1, x21
    ldr x2, [x23, x22, lsl #3]
    bl _engine_attribute
    str x0, [x24, x22, lsl #3]
    add x22, x22, #1
    b Lcapture_extra
Lcapture_done:
    ldr x9, [x19, #ATTR_LABEL]
    cbnz x9, Lcapture_visibility
    mov x0, x20
    mov x1, x21
    ADDR x2, aria_label_name
    bl _engine_attribute
    str x0, [x19, #ATTR_LABEL]
Lcapture_visibility:
    mov x0, x20
    mov x1, x21
    ADDR x2, hidden_name
    bl _engine_attribute
    cmp x0, #0
    cset x9, ne
    str x9, [x19, #696]
    bl _free
    LEAVE

// Append a complete embedded block if it fits; oversized blocks are ignored whole.
.globl _engine_css_source
_engine_css_source:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #64]
    add x9, x22, x21
    add x9, x9, #1
    mov x10, #CSS_MAX_SOURCE
    cmp x9, x10
    b.hi Lsource_done
    ldr x0, [x19, #56]
    add x0, x0, x22
    mov x1, x20
    mov x2, x21
    bl _memcpy
    ldr x9, [x19, #56]
    add x22, x22, x21
    mov w10, #10
    strb w10, [x9, x22]
    add x22, x22, #1
    strb wzr, [x9, x22]
    str x22, [x19, #64]
Lsource_done:
    LEAVE

.globl _engine_css_free
_engine_css_free:
    ENTER
    mov x19, x0
    ldr x20, [x19, #72]
    ldr x21, [x19, #24]
    cbz x20, Lcss_free_buffers
Lcss_free_meta:
    cbz x21, Lcss_free_buffers
    ldr x0, [x20]
    bl _free
    ldr x0, [x20, #8]
    bl _free
    ldr x0, [x20, #16]
    bl _free
    mov x22, #0
Lfree_extra:
    add x9, x20, #512
    ldr x0, [x9, x22, lsl #3]
    bl _free
    add x22, x22, #1
    cmp x22, #22
    b.lo Lfree_extra
    add x20, x20, #CSS_META_SIZE
    sub x21, x21, #1
    b Lcss_free_meta
Lcss_free_buffers:
    ldr x0, [x19, #56]
    bl _free
    ldr x0, [x19, #72]
    bl _free
    ldr x0, [x19, #80]
    bl _free
    LEAVE

// Find the matching block close while honoring strings/comments and nested braces.
_css_block_end:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #1
    mov x22, #0
Lblock_next:
    cmp x19, x20
    b.hs Lblock_done
    ldrb w9, [x19]
    cbz x22, Lblock_unquoted
    cmp w9, #92
    b.eq Lblock_escape
    cmp w9, w22
    b.ne Lblock_advance
    mov x22, #0
    b Lblock_advance
Lblock_escape:
    add x19, x19, #1
    cmp x19, x20
    b.hs Lblock_done
    b Lblock_advance
Lblock_unquoted:
    cmp w9, #34
    b.eq Lblock_quote
    cmp w9, #39
    b.eq Lblock_quote
    cmp w9, #47
    b.ne Lblock_brace
    mov x0, x19
    mov x1, x20
    bl _css_skip
    cmp x0, x19
    b.eq Lblock_advance
    mov x19, x0
    b Lblock_next
Lblock_brace:
    cmp w9, #123
    b.eq Lblock_open
    cmp w9, #125
    b.ne Lblock_advance
    sub x21, x21, #1
    cbz x21, Lblock_done
    b Lblock_advance
Lblock_open:
    add x21, x21, #1
    b Lblock_advance
Lblock_quote:
    mov x22, x9
Lblock_advance:
    add x19, x19, #1
    b Lblock_next
Lblock_done:
    mov x0, x19
    LEAVE

// parse_rules(doc,rules) -> count. Sources remain owned by the document.
_css_rules:
    ENTER
    sub sp, sp, #128                // bounded stack of eight nested media ranges
    ldr x9, [x0, #72]
    ldr x9, [x9, #856]
    mov x10, #1024
    cmp x9, #0
    csel x9, x10, x9, eq
    str x9, [sp, #64]
    str xzr, [sp, #72]
    mov x19, x1
    ldr x20, [x0, #56]
    ldr x21, [x0, #64]
    add x21, x20, x21
    mov x22, #0
Lrules_next:
    cmp x20, x21
    b.lo Lrules_scan
    ldr x9, [sp, #72]
    cbz x9, Lrules_done
    sub x9, x9, #1
    str x9, [sp, #72]
    add x20, x21, #1
    ldr x21, [sp, x9, lsl #3]
    b Lrules_next
Lrules_scan:
    cmp x22, #CSS_MAX_RULES
    b.hs Lrules_done
    mov x0, x20
    mov x1, x21
    bl _css_skip
    mov x20, x0
    cmp x20, x21
    b.hs Lrules_next
    mov x23, x20
    ldrb w9, [x20]
    cmp w9, #64
    b.eq Lrules_at
Lrules_selector:
    cmp x20, x21
    b.hs Lrules_done
    ldrb w9, [x20], #1
    cmp w9, #125
    b.eq Lrules_next
    cmp w9, #123
    b.ne Lrules_selector
    mov x0, x23
    sub x1, x20, #1
    bl _css_trim
    mov x23, x0
    sub x24, x1, x0
    mov x0, x20
    mov x1, x21
    bl _css_block_end
    mov x25, x0
    cbz x24, Lrules_advance
    cmp x24, #256
    b.hi Lrules_advance
    mov x9, #CSS_RULE_SIZE
    madd x26, x22, x9, x19
    stp x23, x24, [x26]
    mov x0, x20
    mov x1, x25
    add x2, x26, #16
    bl _css_declarations
    // Visited-state selectors affect foreground color only, never layout.
    mov x0, x23
    mov x1, x24
    ADDR x2, visited_selector
    mov x3, #8
    bl _memmem
    cbz x0, Lrules_visible_properties
    ldr x9, [x26, #16]
    and x9, x9, #1
    str x9, [x26, #16]
Lrules_visible_properties:
    ldr x9, [x26, #16]
    cbz x9, Lrules_advance
    add x22, x22, #1
Lrules_advance:
    cmp x25, x21
    b.hs Lrules_done
    add x20, x25, #1
    b Lrules_next
Lrules_at:
    mov x24, #0
Lrules_at_scan:
    cmp x20, x21
    b.hs Lrules_done
    ldrb w9, [x20], #1
    cbz x24, Lrules_at_unquoted
    cmp w9, w24
    b.ne Lrules_at_scan
    mov x24, #0
    b Lrules_at_scan
Lrules_at_unquoted:
    cmp w9, #34
    b.eq Lrules_at_quote
    cmp w9, #39
    b.eq Lrules_at_quote
    cmp w9, #59
    b.eq Lrules_next
    cmp w9, #123
    b.ne Lrules_at_scan
    mov x0, x20
    mov x1, x21
    bl _css_block_end
    mov x25, x0
    sub x9, x20, x23
    cmp x9, #7
    b.lo Lrules_skip_at
    mov x0, x23
    ADDR x1, media_at_name
    mov x2, #6
    bl _strncasecmp
    cbnz w0, Lrules_skip_at
    ldrb w9, [x23, #6]
    cmp w9, #40
    b.eq Lrules_media
    cmp w9, #32
    b.hi Lrules_skip_at
Lrules_media:
    add x0, x23, #6
    sub x1, x20, #1
    ldr x2, [sp, #64]
    bl _css_media_match
    cbz x0, Lrules_skip_at
    ldr x9, [sp, #72]
    cmp x9, #8
    b.hs Lrules_skip_at
    str x21, [sp, x9, lsl #3]
    add x9, x9, #1
    str x9, [sp, #72]
    mov x21, x25
    b Lrules_next
Lrules_skip_at:
    add x20, x25, #1
    b Lrules_next
Lrules_at_quote:
    mov x24, x9
    b Lrules_at_scan
Lrules_done:
    mov x0, x22
    add sp, sp, #128
    LEAVE

// Cascade one declaration block onto a metadata record, property by property.
_css_cascade:
    mov x3, #0
    ldr x4, [x1]
    ldr x5, [x1, #8]
    add x1, x1, #16
Lcascade_property:
    cmp x3, #CSS_PROPERTIES
    b.hs Lcascade_done
    mov x6, #1
    lsl x6, x6, x3
    tst x4, x6
    b.eq Lcascade_next
    mov x7, x2
    tst x5, x6
    b.eq Lcascade_compare
    orr x7, x7, #0x1000000000000
Lcascade_compare:
    add x8, x0, #256
    ldr x9, [x8, x3, lsl #3]
    cmp x7, x9
    b.lo Lcascade_next
    str x7, [x8, x3, lsl #3]
    ldr x9, [x1, x3, lsl #3]
    add x8, x0, #32
    str x9, [x8, x3, lsl #3]
Lcascade_next:
    add x3, x3, #1
    b Lcascade_property
Lcascade_done:
    ret

// Resolve one length token. Font size uses parent font; other lengths use current font.
_css_length:
    mov x5, x0
    cmp x1, #CSS_LINE
    b.ne Llength_raw
    tbnz x0, #63, Llength_raw
    lsr x6, x0, #32
    cbz x6, Llength_return
    ldr x7, [x3, #48]
    mul x0, x6, x7
    mov x8, #1000
    udiv x0, x0, x8
    b Llength_line_factor
Llength_raw:
    cmn x0, #1
    b.eq Llength_return
    cmn x0, #5
    b.ne Llength_numeric
    cmp x1, #CSS_LEFT
    b.eq Llength_return
    cmp x1, #CSS_RIGHT
    b.eq Llength_return
    mov x0, #0
    ret
Llength_numeric:
    tbz x0, #63, Llength_return
    and x6, x0, #0xffffffff
    lsr x7, x0, #32
    and x7, x7, #15
    cmp x1, #CSS_LINE
    b.ne Llength_reference
    cbz x7, Llength_line_unitless
Llength_reference:
    cmp x7, #3
    b.ne Llength_font_reference
    cmp x1, #CSS_SIZE
    b.eq Llength_font_reference
    cmp x1, #CSS_LINE
    b.eq Llength_font_reference
    orr x0, x6, #0x100000000
    ret
Llength_font_reference:
    ldr x8, [x3, #48]
    cmp x1, #CSS_SIZE
    b.ne Llength_rem
    ldr x8, [x2, #48]
Llength_rem:
    cmp x7, #4
    b.ne Llength_scale
    ldr x8, [x4, #48]
Llength_scale:
    cmp x7, #1
    b.ls Llength_pixels
    mul x6, x6, x8
    cmp x7, #3
    b.ne Llength_pixels
    mov x8, #1000
    mov x9, #100
    mul x8, x8, x9
    udiv x0, x6, x8
    b Llength_clamp
Llength_pixels:
    mov x8, #1000
    udiv x0, x6, x8
Llength_clamp:
    cmp x1, #CSS_SIZE
    b.ne Llength_spacing
    mov x8, #6
    cmp x0, x8
    csel x0, x8, x0, lo
    mov x8, #72
    cmp x0, x8
    csel x0, x8, x0, hi
    ret
Llength_spacing:
    mov x8, #200
    cmp x1, #CSS_WIDTH
    b.lo Llength_spacing_clamp
    mov x8, #4096
Llength_spacing_clamp:
    cmp x0, x8
    csel x0, x8, x0, hi
    ret
Llength_line_unitless:
    ldr x7, [x3, #48]
    mul x0, x6, x7
    mov x8, #1000
    udiv x0, x0, x8
Llength_line_factor:
    mov x8, #200
    cmp x0, x8
    csel x0, x8, x0, hi
    orr x0, x0, x6, lsl #32         // preserve unitless multiplier for descendants
Llength_return:
    ret

.globl _engine_css_apply
_engine_css_apply:
    ENTER
    sub sp, sp, #320                // temporary inline declaration block + locals
    mov x19, x0
    ldr x0, [x19, #80]
    mov x1, #0
    ldr x2, [x19, #40]
    bl _memset
    mov x0, #CSS_MAX_RULES
    mov x1, #CSS_RULE_SIZE
    bl _calloc
    cbz x0, Lapply_no_rules
    mov x20, x0
    mov x0, x19
    mov x1, x20
    bl _css_rules
    mov x21, x0
    b Lapply_begin
Lapply_no_rules:
    mov x20, #0
    mov x21, #0
Lapply_begin:
    mov x9, #134217728              // bounded work for large utility stylesheets
    str x9, [x19, #88]
    mov x22, #0
Lapply_node:
    ldr x9, [x19, #24]
    cmp x22, x9
    b.hs Lapply_done
    ldr x23, [x19, #72]
    add x23, x23, x22, lsl #10
    ldr x25, [x19, #16]
    mov x9, #40
    madd x25, x22, x9, x25
    ldr x9, [x25, #8]
    ldr x24, [x19, #72]
    tbnz x9, #63, Lapply_default
    add x24, x24, x9, lsl #10
Lapply_default:
    add x0, x23, #256
    mov x1, #0
    mov x2, #224
    bl _memset
    mov x26, #0
    ADDR x27, css_defaults
    mov x28, #3197                  // inherited color/font/text/line properties
Lapply_default_property:
    cmp x26, #CSS_PROPERTIES
    b.hs Lapply_ua
    ldr x10, [x27, x26, lsl #3]
    cbz x22, Lapply_default_store
    mov x11, #1
    lsl x11, x11, x26
    tst x28, x11
    b.eq Lapply_default_store
    add x11, x24, #32
    ldr x10, [x11, x26, lsl #3]
Lapply_default_store:
    add x11, x23, #32
    str x10, [x11, x26, lsl #3]
    add x26, x26, #1
    b Lapply_default_property
Lapply_ua:
    ldr x9, [x25]
    cmp x9, #NODE_CENTER
    b.eq Lapply_center_ua
    cmp x9, #NODE_TEXT
    b.eq Lapply_text_node
    cmp x9, #NODE_A
    b.eq Lapply_link_ua
    cmp x9, #NODE_PRE
    b.eq Lapply_pre_ua
    cmp x9, #NODE_STRONG
    b.eq Lapply_bold_ua
    cmp x9, #NODE_EM
    b.eq Lapply_italic_ua
    cmp x9, #NODE_H1
    b.lo Lapply_rules
    cmp x9, #NODE_H3
    b.hi Lapply_rules
    ldr x10, [x24, #48]
    cmp x9, #NODE_H1
    b.eq Lapply_h1
    cmp x9, #NODE_H2
    b.eq Lapply_h2
    mov x11, #9
    mul x10, x10, x11
    mov x11, #7
    udiv x10, x10, x11
    b Lapply_heading
Lapply_h1:
    lsl x10, x10, #1
    b Lapply_heading
Lapply_h2:
    mov x11, #3
    mul x10, x10, x11
    lsr x10, x10, #1
Lapply_heading:
    mov x11, #72
    cmp x10, x11
    csel x10, x11, x10, hi
    str x10, [x23, #48]
    mov x10, #8
    str x10, [x23, #96]
    str x10, [x23, #104]
Lapply_bold_ua:
    mov x10, #700
    str x10, [x23, #56]
    b Lapply_rules
Lapply_center_ua:
    mov x10, #2
    str x10, [x23, #80]
    b Lapply_rules
Lapply_pre_ua:
    str xzr, [x23, #120]             // UA preformatted text uses monospace
    b Lapply_rules
Lapply_italic_ua:
    mov x10, #1
    str x10, [x23, #64]
    b Lapply_rules
Lapply_link_ua:
    mov x10, #1
    str x10, [x23, #72]
    mov x10, #0x66d6
    movk x10, #0x1a, lsl #16
    ldr x11, [x23, #864]
    cbz x11, Lapply_link_color
    mov x10, #0x0080
    movk x10, #0x80, lsl #16         // visited UA purple #800080
Lapply_link_color:
    str x10, [x23, #32]
Lapply_rules:
    mov x26, #0
Lapply_rule:
    cmp x26, x21
    b.hs Lapply_inline
    mov x9, #CSS_RULE_SIZE
    madd x27, x26, x9, x20
    mov x0, x19
    mov x1, x22
    ldr x2, [x27]
    ldr x3, [x27, #8]
    add x3, x2, x3
    bl _css_match
    cbz x0, Lapply_rule_next
    sub x0, x0, #1
    lsl x2, x0, #16
    add x9, x26, #1
    orr x2, x2, x9
    mov x0, x23
    add x1, x27, #16
    bl _css_cascade
Lapply_rule_next:
    add x26, x26, #1
    b Lapply_rule
Lapply_inline:
    ldr x26, [x23, #16]
    cbz x26, Lapply_resolve
    mov x0, sp
    mov x1, #0
    mov x2, #240
    bl _memset
    mov x0, x26
    bl _strlen
    add x1, x26, x0
    mov x0, x26
    mov x2, sp
    bl _css_declarations
    mov x0, x23
    mov x1, sp
    // Inline is an independent cascade tier, above every bounded selector score.
    mov x2, #0x10000000000
    orr x2, x2, #0xffff
    bl _css_cascade
Lapply_resolve:
    mov x26, #0
    ADDR x27, css_defaults
Lapply_resolve_property:
    cmp x26, #CSS_PROPERTIES
    b.hs Lapply_inherited_hidden
    add x9, x23, #32
    ldr x0, [x9, x26, lsl #3]
    cmn x0, #2
    b.eq Lapply_inherit
    cmn x0, #3
    b.eq Lapply_initial
    cmn x0, #4
    b.ne Lapply_resolve_length
    mov x10, #3197
    mov x11, #1
    lsl x11, x11, x26
    tst x10, x11
    b.ne Lapply_inherit
Lapply_initial:
    ldr x0, [x27, x26, lsl #3]
    b Lapply_resolve_length
Lapply_inherit:
    add x9, x24, #32
    ldr x0, [x9, x26, lsl #3]
Lapply_resolve_length:
    cmp x26, #CSS_SIZE
    b.eq Lapply_length
    cmp x26, #CSS_TOP
    b.eq Lapply_length
    cmp x26, #CSS_BOTTOM
    b.eq Lapply_length
    cmp x26, #CSS_LINE
    b.eq Lapply_length
    cmp x26, #CSS_LEFT
    b.eq Lapply_length
    cmp x26, #CSS_RIGHT
    b.eq Lapply_length
    cmp x26, #CSS_WIDTH
    b.lo Lapply_resolved_store
    cmp x26, #CSS_MAX_WIDTH
    b.eq Lapply_length
    cmp x26, #CSS_RADIUS
    b.eq Lapply_length
    cmp x26, #CSS_MIN_HEIGHT
    b.eq Lapply_length
    cmp x26, #CSS_MIN_WIDTH
    b.eq Lapply_length
    cmp x26, #CSS_BORDER
    b.hi Lapply_resolved_store
Lapply_length:
    mov x1, x26
    mov x2, x24
    mov x3, x23
    ldr x4, [x19, #72]
    bl _css_length
Lapply_resolved_store:
    add x9, x23, #32
    str x0, [x9, x26, lsl #3]
    add x26, x26, #1
    b Lapply_resolve_property
Lapply_text_node:
    add x0, x23, #32
    add x1, x24, #32
    mov x2, #224
    bl _memcpy
Lapply_inherited_hidden:
    cbz x22, Lapply_canvas
    ldr x9, [x24, #88]
    cmp x9, #1
    b.ne Lapply_canvas
    mov x9, #1
    str x9, [x23, #88]
Lapply_canvas:
    ldr x9, [x25]
    cmp x9, #NODE_HTML
    b.ne Lapply_body_canvas
    ldr x9, [x19, #72]
    ldr x10, [x23, #48]
    str x10, [x9, #48]              // rem reference is the root element font
    ldr x10, [x23, #40]
    cmn x10, #1
    b.eq Lapply_mark_hidden
    str x10, [x9, #40]
    b Lapply_mark_hidden
Lapply_body_canvas:
    cmp x9, #NODE_BODY
    b.ne Lapply_mark_hidden
    ldr x10, [x23, #40]
    cmn x10, #1
    b.eq Lapply_mark_hidden
    ldr x9, [x19, #72]
    str x10, [x9, #40]
Lapply_mark_hidden:
    ldr x9, [x23, #696]
    cbz x9, Lapply_special_hidden
    str x9, [x23, #88]
Lapply_special_hidden:
    ldr x9, [x25]
    cmp x9, #NODE_OPTION
    b.ne Lapply_input_visibility
    mov x9, #1
    str x9, [x23, #88]
    b Lapply_visibility
Lapply_input_visibility:
    ldr x9, [x25]
    cmp x9, #NODE_INPUT
    b.ne Lapply_visibility
    ldr x0, [x23, #ATTR_TYPE]
    cbz x0, Lapply_visibility
    ADDR x1, hidden_input_type
    bl _strcasecmp
    cbnz w0, Lapply_visibility
    mov x9, #1
    str x9, [x23, #88]
Lapply_visibility:
    ldr x9, [x23, #88]
    cmp x9, #1
    b.ne Lapply_node_next
    ldr x0, [x19, #80]
    ldr x10, [x25, #16]
    ldr x11, [x25, #24]
    add x0, x0, x10
    mov x1, #1
    sub x2, x11, x10
    bl _memset
Lapply_node_next:
    add x22, x22, #1
    b Lapply_node
Lapply_done:
    mov x0, x19
    bl _engine_inline_flow
    mov x0, x20
    bl _free
    add sp, sp, #320
    LEAVE

.section __DATA,__const
.p2align 3
css_defaults:
.quad -1, -1, 14, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0
.section __TEXT,__cstring,cstring_literals
id_name: .asciz "id"
class_name: .asciz "class"
style_name: .asciz "style"

.section __DATA,__const
.p2align 3
html_attributes:
.quad attr_src, attr_action, attr_name, attr_value, attr_type, attr_alt, attr_width, attr_height, attr_method, attr_rel, attr_disabled, attr_media, attr_label, attr_checked, attr_selected, attr_multiple, attr_rows, attr_cols, attr_readonly, attr_placeholder, attr_enctype, 0
.section __TEXT,__cstring,cstring_literals
attr_src: .asciz "src"
attr_action: .asciz "action"
attr_name: .asciz "name"
attr_value: .asciz "value"
attr_type: .asciz "type"
attr_alt: .asciz "alt"
attr_width: .asciz "width"
attr_height: .asciz "height"
attr_method: .asciz "method"
attr_rel: .asciz "rel"
attr_disabled: .asciz "disabled"
attr_media: .asciz "media"
hidden_input_type: .asciz "hidden"
attr_label: .asciz "label"
attr_checked: .asciz "checked"
attr_selected: .asciz "selected"
attr_multiple: .asciz "multiple"
attr_rows: .asciz "rows"
attr_cols: .asciz "cols"
attr_readonly: .asciz "readonly"
attr_placeholder: .asciz "placeholder"
attr_enctype: .asciz "enctype"

.section __TEXT,__cstring,cstring_literals
aria_label_name: .asciz "aria-label"
hidden_name: .asciz "hidden"

.section __TEXT,__cstring,cstring_literals
media_at_name: .asciz "@media"

.section __TEXT,__cstring,cstring_literals
visited_selector: .asciz ":visited"
