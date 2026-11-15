// Inline images and controls occupy measured attachment glyphs, preserving links
// and UTF-16 ranges without delegating HTML parsing to native importers.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// Resolve CSS dimensions first, then legacy HTML integer dimensions. Auto=-1.
// metadata -> width x0, height x1, each bounded to 4096 points.
.globl _mac_element_dimensions
_mac_element_dimensions:
    ENTER
    mov x19, x0
    mov x20, #0
Ldimension_next:
    add x9, x19, #144
    ldr x21, [x9, x20, lsl #3]
    tbnz x21, #63, Ldimension_html
    cbz x20, Ldimension_width
    tbz x21, #32, Ldimension_width
    ldr x21, [x19, #BOX_HEIGHT]
    tbnz x21, #63, Ldimension_html
    b Ldimension_save
Ldimension_width:
    ldr x1, [x19, #848]
    mov x0, x21
    bl _engine_box_length
    mov x21, x0
    b Ldimension_save
Ldimension_html:
    add x9, x19, #ATTR_WIDTH
    ldr x0, [x9, x20, lsl #3]
    cbz x0, Ldimension_save
    mov x1, #0
    mov x2, #10
    bl _strtol
    cmp x0, #0
    b.le Ldimension_save
    mov x21, x0
Ldimension_save:
    mov x9, #4096
    cmp x21, x9
    csel x21, x9, x21, gt
    add x9, sp, #144
    str x21, [x9, x20, lsl #3]
    add x20, x20, #1
    cmp x20, #2
    b.lo Ldimension_next
    ldp x20, x21, [sp, #144]
    ldr x0, [x19, #208]
    tbnz x0, #63, Ldimension_result
    ldr x1, [x19, #848]
    bl _engine_box_length
    tbnz x20, #63, Ldimension_result
    cmp x20, x0
    csel x20, x0, x20, hi
Ldimension_result:
    mov x0, x20
    mov x1, x21
    LEAVE

.globl _mac_attachments
_mac_attachments:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
Lattachment_next:
    ldr x9, [x19, #24]
    cmp x22, x9
    b.hs Lattachments_done
    ldr x23, [x19, #16]
    mov x9, #40
    madd x23, x22, x9, x23
    ldr x24, [x23]
    cmp x24, #NODE_SVG
    b.eq Lattachment_element
    cmp x24, #NODE_A
    b.eq Lattachment_inline_candidate
    cmp x24, #NODE_IMG
    b.eq Lattachment_element
    cmp x24, #NODE_SELECT
    b.eq Lattachment_element
    cmp x24, #NODE_TEXTAREA
    b.eq Lattachment_element
    cmp x24, #NODE_INPUT
    b.eq Lattachment_element
    cmp x24, #NODE_BUTTON
    b.ne Lattachment_advance
    b Lattachment_element
Lattachment_inline_candidate:
    ldr x9, [x19, #72]
    add x9, x9, x22, lsl #11
    ldr x9, [x9, #872]
    cbz x9, Lattachment_advance
Lattachment_element:
    ldr x9, [x20, #16]
    ldr x10, [x23, #16]
    ldr x11, [x23, #24]
    ldr x25, [x9, x10, lsl #3]
    ldr x10, [x9, x11, lsl #3]
    cmp x25, x10
    b.eq Lattachment_advance
    ldr x26, [x19, #72]
    add x26, x26, x22, lsl #11
    CLASS NSTextAttachment
    MSG new
    mov x27, x0
    mov x0, x26
    bl _mac_element_dimensions
    ldr x9, [x26, #FLOW_OWNER]
    cbz x9, Lattachment_flow_dimensions_done
    cmp x24, #NODE_A
    b.eq Lattachment_flow_dimensions_done
    ldr x10, [x26, #FLOW_WIDTH]
    cbz x10, Lattachment_flow_dimensions_done
    mov x0, x10
    sub x9, x9, #1
    ldr x10, [x19, #72]
    add x10, x10, x9, lsl #11
    ldr x10, [x10, #(32+CSS_DIRECTION*8)]
    tbz x10, #0, Lattachment_flow_dimensions_done
    ldr x10, [x26, #FLOW_HEIGHT]
    cmp x10, #0
    csel x1, x1, x10, le
Lattachment_flow_dimensions_done:
    stp x0, x1, [sp, #144]
    cmp x24, #NODE_SVG
    b.eq Lattachment_svg
    cmp x24, #NODE_IMG
    b.eq Lattachment_image
    mov x0, x26
    mov x1, x24
    mov x2, x22
    bl _mac_control_create
    cbz x0, Lattachment_hidden
    mov x28, x0
    str x0, [sp, #192]
    mov x0, x26
    mov x1, x24
    bl _mac_control_kind
    str x0, [sp, #176]
    mov x0, x26
    bl _mac_css_font
    mov x2, x0
    ldr x0, [sp, #192]
    cmp x24, #NODE_TEXTAREA
    b.ne Lattachment_control_font
    str x2, [sp, #184]
    MSG documentView
    ldr x2, [sp, #184]
Lattachment_control_font:
    MSG setFont
    mov x0, x26
    ldr x1, [sp, #192]
    ldr x2, [sp, #176]
    bl _mac_input_border
    ldr x9, [sp, #176]
    cmp x9, #0
    b.eq Lattachment_single_line
    cmp x9, #3
    b.ne Lattachment_size_control
Lattachment_single_line:
    ldr x0, [sp, #192]
    MSG cell
    mov x2, #1
    MSG singleLine
Lattachment_size_control:
    mov x9, #100
    str x9, [sp, #184]
    cmp x24, #NODE_TEXTAREA
    b.eq Lattachment_natural_height
    ldr x0, [sp, #192]
    MSG intrinsicSize
    fcvtps x9, d0
    cmp x9, #0
    mov x10, #16
    csel x9, x10, x9, le
    str x9, [sp, #208]
    fcvtps x9, d1
    cmp x9, #0
    mov x10, #28
    csel x9, x10, x9, le
    str x9, [sp, #184]
Lattachment_natural_height:
    ldr x0, [sp, #176]
    cmp x0, #9
    b.ne Lattachment_default_width
    ldr x0, [sp, #192]
    MSG frame
    fcvtps x9, d2
    fcvtps x10, d3
    ldr x11, [x26, #776]
    add x9, x9, x11
    ldr x11, [x26, #784]
    add x9, x9, x11
    ldr x11, [x26, #792]
    add x10, x10, x11
    ldr x11, [x26, #800]
    add x10, x10, x11
    stp x9, x10, [sp, #144]
    str x10, [sp, #184]
    mov x28, x9
    b Lattachment_control_max
Lattachment_default_width:
    ldr x9, [x26, #FLOW_INTRINSIC_W]
    ldr x10, [sp, #144]
    cmp x10, #0
    csel x28, x9, x10, lt
    mov x0, x26
    ldr x1, [x26, #848]
    mov x2, x28
    bl _engine_width_clamp
    mov x28, x0
Lattachment_control_max:
    str x28, [sp, #144]
    ldr x9, [sp, #152]
    ldr x10, [sp, #184]
    cmp x9, #0
    csel x9, x10, x9, lt
    ldr x10, [x26, #BOX_MAX_HEIGHT]
    tbnz x10, #63, Lattachment_height_minimum
    cmp x9, x10
    csel x9, x10, x9, gt
Lattachment_height_minimum:
    ldr x10, [x26, #BOX_MIN_HEIGHT]
    cmp x9, x10
    csel x9, x10, x9, lt
    str x9, [sp, #152]
    ldr x9, [sp, #176]
    cmp x9, #9
    b.eq Lattachment_reserve_image
    ldr x0, [sp, #192]
    ldp x9, x10, [sp, #144]
    scvtf d0, x9
    scvtf d1, x10
    MSG setFrameSize
    mov x0, x26
    ldr x1, [sp, #192]
    ldr x2, [sp, #176]
    bl _mac_input_border
Lattachment_reserve_image:
    CLASS NSImage
    MSG alloc
    ldp x9, x10, [sp, #144]
    scvtf d0, x9
    scvtf d1, x10
    MSG initSize
    mov x28, x0
    str x0, [sp, #184]
    bl _mac_control_cell_class
    MSG alloc
    mov x2, x28
    MSG initImageCell
    mov x28, x0
    ldr x2, [sp, #192]
    MSG setRepresentedObject
    mov x0, x27
    mov x2, x28
    MSG setAttachmentCell
    mov x0, x28
    MSG release
    ldr x0, [sp, #184]
    MSG release
    b Lattachment_attribute
Lattachment_hidden:
    CLASS NSImage
    MSG alloc
    NUM d0, 0
    NUM d1, 0
    MSG initSize
    mov x28, x0
    b Lattachment_set_image
Lattachment_svg:
    ldr x0, [x23, #32]
    cbz x0, Lattachment_alt
    mov x28, x0
    bl _strlen
    mov x1, x0
    mov x0, x28
    mov x2, x26
    bl _mac_svg_image
    cbz x0, Lattachment_alt
    mov x28, x0
    b Lattachment_image_size
Lattachment_image:
    CLASS NSNumber
    mov x2, x22
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_images
    MSG objectKey
    cbz x0, Lattachment_alt
    MSG copyObject
    mov x28, x0
Lattachment_image_size:
    mov x0, x28
    MSG size
    // Validate dimensions before arithmetic and retain natural aspect ratio when
    // exactly one dimension is specified. Large images fit the text viewport.
    fmov d2, #1.0
    fcmp d0, d2
    b.lt Lattachment_bad_image
    fcmp d1, d2
    b.lt Lattachment_bad_image
    NUM d2, 16384
    fcmp d0, d2
    b.hi Lattachment_bad_image
    fcmp d1, d2
    b.hi Lattachment_bad_image
    fcvtps x1, d0
    fcvtps x2, d1
    mov x0, x26
    ldp x3, x4, [sp, #144]
    bl _engine_replaced_size
    scvtf d0, x0
    scvtf d1, x1
    // Bound raster allocations independently of CSS dimensions.
    NUM d2, 4096
    fmax d3, d0, d1
    fcmp d3, d2
    b.le Limage_size
    fdiv d2, d2, d3
    fmul d0, d0, d2
    fmul d1, d1, d2
Limage_size:
    stp d0, d1, [sp, #144]
    mov x0, x28
    MSG setSize
    b Lattachment_set_image
Lattachment_bad_image:
    mov x0, x28
    MSG release
Lattachment_alt:
    ldr x0, [x26, #ATTR_ALT]
    cbnz x0, Lattachment_alt_text
    ADDR x0, image_alt
Lattachment_alt_text:
    bl _mac_string
    mov x28, x0
    CLASS NSTextAttachmentCell
    MSG alloc
    mov x2, x28
    MSG initTextCell
    mov x28, x0
    str x28, [sp, #168]
    mov x0, x26
    bl _mac_alt_image
    mov x2, x0
    ldr x0, [sp, #168]
    MSG setImage
    mov x0, x27
    mov x2, x28
    MSG setAttachmentCell
    mov x0, x28
    MSG release
    b Lattachment_attribute
Lattachment_set_image:
    mov x0, x27
    mov x2, x28
    MSG setImage
    mov x0, x28
    MSG release
Lattachment_attribute:
    mov x0, x21
    adrp x9, _NSAttachmentAttributeName@GOTPAGE
    ldr x9, [x9, _NSAttachmentAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, x27
    mov x4, x25
    mov x5, #1
    MSG addAttribute
    cmp x24, #NODE_SVG
    b.eq Lattachment_release
    cmp x24, #NODE_IMG
    b.eq Lattachment_release
    mov x0, x21
    adrp x9, _NSBackgroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSBackgroundColorAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, x25
    mov x4, #1
    MSG removeAttribute
Lattachment_release:
    mov x0, x27
    MSG release
Lattachment_advance:
    add x22, x22, #1
    b Lattachment_next
Lattachments_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
image_alt: .asciz "[Image]"

.text
.p2align 2
// A plain-text alt fallback rasterized with native glyph drawing, never HTML.
_mac_alt_image:
    ENTER
    mov x19, x0
    ldr x0, [x19, #ATTR_ALT]
    cbnz x0, Lalt_string
    ADDR x0, image_alt
Lalt_string:
    bl _mac_string
    mov x20, x0
    MSG length
    mov x9, #7
    mul x9, x0, x9
    add x9, x9, #8
    mov x10, #700
    cmp x9, x10
    csel x9, x10, x9, hi
    str x9, [sp, #144]
    CLASS NSImage
    MSG alloc
    ldr x9, [sp, #144]
    scvtf d0, x9
    NUM d1, 24
    MSG initSize
    mov x21, x0
    mov x2, x20
    MSG setImageDescription
    mov x0, x21
    MSG lockFocus
    CLASS NSMutableDictionary
    MSG new
    mov x22, x0
    ldr x0, [x19, #32]
    bl _mac_css_color
    cbnz x0, Lalt_color
    CLASS NSColor
    MSG textColor
Lalt_color:
    mov x2, x0
    adrp x9, _NSForegroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSForegroundColorAttributeName@GOTPAGEOFF]
    ldr x3, [x9]
    mov x0, x22
    MSG setObjectKey
    CLASS NSFont
    NUM d0, 14
    MSG systemFont
    mov x2, x0
    adrp x9, _NSFontAttributeName@GOTPAGE
    ldr x9, [x9, _NSFontAttributeName@GOTPAGEOFF]
    ldr x3, [x9]
    mov x0, x22
    MSG setObjectKey
    mov x0, x20
    NUM d0, 0
    NUM d1, 2
    mov x2, x22
    MSG drawTextPoint
    mov x0, x21
    MSG unlockFocus
    mov x0, x22
    MSG release
    mov x0, x21
    MSG autorelease
    LEAVE
