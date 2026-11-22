// Pango shapes glyphs; the shared assembly cascade supplies every style/range.
.include "src/gtk/gtk.inc"
.text
.p2align 2
.globl _gtk_engine_font
_gtk_engine_font:
    ENTER
    mov x19, x0
    bl _pango_font_description_new
    mov x20, x0
    ldr x9, [x19, #120]
    ADDR x1, gtk_monospace
    cmp x9, #1
    b.ne Lgtk_font_serif
    ADDR x1, gtk_sans
Lgtk_font_serif:
    cmp x9, #2
    b.ne Lgtk_font_verdana
    ADDR x1, gtk_serif
Lgtk_font_verdana:
    cmp x9, #3
    b.ne Lgtk_font_family
    ADDR x1, gtk_verdana
Lgtk_font_family:
    cmp x9, #256
    b.lo Lgtk_font_family_ready
    mov x0, x9
    bl _gtk_font_family_name
    mov x1, x0
    cbnz x1, Lgtk_font_family_ready
    ADDR x1, gtk_monospace
Lgtk_font_family_ready:
    mov x0, x20
    bl _pango_font_description_set_family
    ldr x9, [x19, #48]
    lsl x9, x9, #10
    scvtf d0, x9
    mov x0, x20
    bl _pango_font_description_set_absolute_size
    mov x0, x20
    ldr x1, [x19, #56]
    bl _pango_font_description_set_weight
    mov x0, x20
    ldr x9, [x19, #64]
    cmp x9, #0
    mov x1, #2
    csel x1, x1, xzr, ne
    bl _pango_font_description_set_style
    mov x0, x20
    LEAVE

// attrs, metadata, UTF8 start/end. All constructors return owned attributes.
.globl _gtk_engine_attributes
_gtk_engine_attributes:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    str x4, [sp, #192]
    cmp x21, x22
    b.hs Lgtk_attr_done
    mov x0, x20
    bl _gtk_engine_font
    mov x23, x0
    bl _pango_attr_font_desc_new
    bl gtk_attribute_insert
    mov x0, x23
    bl _pango_font_description_free
    ldr x24, [x20, #32]
    tbnz x24, #63, Lgtk_attr_underline
    ubfx x0, x24, #16, #8
    mov x9, #257
    mul x0, x0, x9
    ubfx x1, x24, #8, #8
    mul x1, x1, x9
    and x2, x24, #255
    mul x2, x2, x9
    bl _pango_attr_foreground_new
    bl gtk_attribute_insert
    tbz x24, #40, Lgtk_attr_underline
    ubfx x0, x24, #32, #8
    mov x9, #257
    mul x0, x0, x9
    bl _pango_attr_foreground_alpha_new
    bl gtk_attribute_insert
Lgtk_attr_underline:
    ldr x9, [x20, #72]
    cbz x9, Lgtk_attr_tracking
    mov x0, #1
    bl _pango_attr_underline_new
    bl gtk_attribute_insert
Lgtk_attr_tracking:
    ldr x9, [x20, #904]
    cbz x9, Lgtk_attr_rise
    lsl x0, x9, #10
    bl _pango_attr_letter_spacing_new
    bl gtk_attribute_insert
Lgtk_attr_rise:
    ldr x9, [x20, #112]
    cmp x9, #0
    b.le Lgtk_attr_baseline
    lsl x0, x9, #10
    bl _pango_attr_line_height_new_absolute
    bl gtk_attribute_insert
Lgtk_attr_baseline:
    mov x0, x20
    bl _gtk_inline_rise
    cbz x0, Lgtk_attr_words
    bl _pango_attr_rise_new
    bl gtk_attribute_insert
Lgtk_attr_words:
    ldr x23, [x20, #896]
    cbz x23, Lgtk_attr_done
    ldr x9, [x20, #904]
    add x23, x23, x9
    lsl x23, x23, #10
    ldr x25, [sp, #192]
    mov x24, x21
Lgtk_attr_space:
    cmp x24, x22
    b.hs Lgtk_attr_done
    ldrb w9, [x25, x24]
    cmp x9, #32
    b.ne Lgtk_attr_space_next
    mov x0, x23
    bl _pango_attr_letter_spacing_new
    str w24, [x0, #8]
    add x9, x24, #1
    str w9, [x0, #12]
    mov x1, x0
    mov x0, x19
    bl _pango_attr_list_insert
Lgtk_attr_space_next:
    add x24, x24, #1
    b Lgtk_attr_space
Lgtk_attr_done:
    LEAVE
// Private insertion sees the current range in preserved x19/x21/x22.
gtk_attribute_insert:
    cbz x0, Lgtk_attribute_nil
    str w21, [x0, #8]
    str w22, [x0, #12]
    mov x1, x0
    mov x0, x19
    b _pango_attr_list_insert
Lgtk_attribute_nil:
    ret

// Measure actual glyphs and native controls before shared intrinsic/flex sizing.
.globl _gtk_engine_measure
_gtk_engine_measure:
    ENTER
    LOAD x19, _gtk_doc
    mov x20, #1
Lgtk_measure_next:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lgtk_measure_done
    mov x0, x20
    bl _gtk_engine_node
    mov x21, x0
    mov x22, x1
    ldr x23, [x2]
    cmp x23, #NODE_TEXT
    b.eq Lgtk_measure_text
    cmp x23, #NODE_INPUT
    b.eq Lgtk_measure_control
    cmp x23, #NODE_BUTTON
    b.eq Lgtk_measure_control
    cmp x23, #NODE_SELECT
    b.eq Lgtk_measure_control
    cmp x23, #NODE_TEXTAREA
    b.eq Lgtk_measure_control
    cmp x23, #NODE_IMG
    b.eq Lgtk_measure_image
    cmp x23, #NODE_SVG
    b.eq Lgtk_measure_image
    b Lgtk_measure_advance
Lgtk_measure_control:
    mov x0, x20
    bl _gtk_control_get
    cbz x0, Lgtk_measure_advance
    str x0, [x22, #GN_WIDGET]
    mov x24, x0
    mov x0, x21
    mov x1, x23
    bl _gtk_control_kind
    str x0, [x22, #GN_CONTROL_KIND]
    mov x1, x24
    mov x0, x20
    bl _gtk_control_style
    mov x0, x24
    add x1, sp, #144
    add x2, sp, #148
    bl _gtk_widget_get_preferred_width
    mov x0, x24
    add x1, sp, #152
    add x2, sp, #156
    bl _gtk_widget_get_preferred_height
    ldr w25, [sp, #148]
    ldr w26, [sp, #156]
    cmp x23, #NODE_TEXTAREA
    b.ne Lgtk_measure_control_minimum
    mov x25, #480
    mov x26, #100
Lgtk_measure_control_minimum:
    ldr x9, [x21, #144]
    tbnz x9, #63, Lgtk_control_auto_width
    ldr x25, [x21, #768]
    ldr x9, [x21, #808]
    add x25, x25, x9
    ldr x9, [x21, #816]
    add x25, x25, x9
    ldr x9, [x21, #BOX_BORDER_LEFT]
    add x25, x25, x9
    ldr x9, [x21, #BOX_BORDER_RIGHT]
    add x25, x25, x9
Lgtk_control_auto_width:
    ldr x9, [x21, #BOX_HEIGHT]
    tbnz x9, #63, Lgtk_control_auto_height
    mov x26, x9
    ldr x9, [x21, #824]
    add x26, x26, x9
    ldr x9, [x21, #832]
    add x26, x26, x9
    ldr x9, [x21, #BOX_BORDER_TOP]
    add x26, x26, x9
    ldr x9, [x21, #BOX_BORDER_BOTTOM]
    add x26, x26, x9
Lgtk_control_auto_height:
    mov x0, x21
    ldr x1, [x21, #848]
    mov x2, x25
    bl _engine_width_clamp
    mov x25, x0
    mov x9, #20
    cmp x25, x9
    csel x25, x9, x25, lt
    cmp x26, x9
    csel x26, x9, x26, lt
    mov x0, x24
    mov x1, x25
    mov x2, x26
    bl _gtk_control_baseline
    str x0, [x22, #GN_BASELINE]
    b Lgtk_measure_store
Lgtk_measure_image:
    mov x0, x20
    bl _gtk_image_get
    cbz x0, Lgtk_measure_image_alt
    str x0, [x22, #GN_IMAGE]
    mov x24, x0
    bl _gdk_pixbuf_get_width
    mov x25, x0
    mov x0, x24
    bl _gdk_pixbuf_get_height
    mov x26, x0
    mov x0, x21
    mov x1, x25
    mov x2, x26
    ldr x3, [x21, #144]
    ldr x4, [x21, #152]
    bl _engine_replaced_size
    mov x25, x0
    mov x26, x1
    b Lgtk_measure_store
Lgtk_measure_image_alt:
    mov x25, #24
    mov x26, #20
    b Lgtk_measure_store
Lgtk_measure_text:
    mov x24, x2
    ldr x0, [x24, #16]
    bl _gtk_engine_byte
    mov x25, x0
    ldr x0, [x24, #24]
    bl _gtk_engine_byte
    sub x26, x0, x25
    LOAD x9, _gtk_flow
    ldr x9, [x9]
    add x25, x9, x25
    LOAD x0, _gtk_pango_context
    bl _pango_layout_new
    mov x27, x0
    mov x1, x25
    mov x2, x26
    bl _pango_layout_set_text
    mov x0, x21
    bl _gtk_engine_font
    mov x28, x0
    mov x1, x0
    mov x0, x27
    bl _pango_layout_set_font_description
    mov x0, x28
    bl _pango_font_description_free
    mov x0, x27
    add x1, sp, #144
    add x2, sp, #148
    bl _pango_layout_get_pixel_size
    ldr w25, [sp, #144]
    ldr w26, [sp, #148]
    str x25, [x21, #FLOW_MAX_CONTENT]
    mov x0, x27
    mov x1, #1
    bl _pango_layout_set_width
    mov x0, x27
    mov x1, #0 // PANGO_WRAP_WORD, retain the longest unbreakable word
    bl _pango_layout_set_wrap
    mov x0, x27
    add x1, sp, #144
    add x2, sp, #148
    bl _pango_layout_get_pixel_size
    ldr w9, [sp, #144]
    str x9, [x21, #FLOW_MIN_CONTENT]
    mov x0, x27
    bl _g_object_unref
Lgtk_measure_store:
    str x25, [x21, #FLOW_INTRINSIC_W]
    str x26, [x21, #FLOW_INTRINSIC_H]
    str x25, [x22, #GN_W]
    str x26, [x22, #GN_H]
Lgtk_measure_advance:
    add x20, x20, #1
    b Lgtk_measure_next
Lgtk_measure_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_monospace: .asciz "monospace"
gtk_sans: .asciz "Arial"
gtk_serif: .asciz "Times New Roman"
gtk_verdana: .asciz "Verdana"
