// Bounded SVG XML scanning, groups, viewBox and drawing orchestration in ARM64.
// No scripts, external references, fonts or network requests are interpreted.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
svg_tag_end:
    mov x2, #0
Lsvg_tag_byte:
    cmp x0, x1
    b.hs Lsvg_tag_bad
    ldrb w3, [x0], #1
    cbz x2, Lsvg_tag_unquoted
    cmp w3, w2
    b.ne Lsvg_tag_byte
    mov x2, #0
    b Lsvg_tag_byte
Lsvg_tag_unquoted:
    cmp w3, #34
    b.eq Lsvg_tag_quote
    cmp w3, #39
    b.eq Lsvg_tag_quote
    cmp w3, #62
    b.ne Lsvg_tag_byte
    ret
Lsvg_tag_quote:
    mov x2, x3
    b Lsvg_tag_byte
Lsvg_tag_bad:
    mov x0, #0
    ret

svg_tag_kind:
    ENTER
    mov x19, x0
    mov x20, x1
    ADDR x21, svg_tags
Lsvg_kind_next:
    ldr x1, [x21]
    cbz x1, Lsvg_kind_none
    ldr x9, [x21, #8]
    cmp x9, x20
    b.ne Lsvg_kind_advance
    mov x0, x19
    mov x2, x20
    bl _strncasecmp
    cbnz w0, Lsvg_kind_advance
    ldr x0, [x21, #16]
    LEAVE
Lsvg_kind_advance:
    add x21, x21, #24
    b Lsvg_kind_next
Lsvg_kind_none:
    mov x0, #0
    LEAVE

// UTF-8 SVG bytes,length,optional computed CSS metadata -> owned NSImage or nil.
.globl _mac_svg_image
_mac_svg_image:
    ENTER
    sub sp, sp, #2560              // 32 inherited paint states and local geometry
    mov x19, x0
    add x20, x0, x1
    mov x21, x2
    mov x9, #262144
    cmp x1, x9
    b.hi Lsvg_nil
    ADDR x2, svg_open
    mov x3, #4
    bl _memmem
    cbz x0, Lsvg_nil
    add x27, x0, #4
    mov x1, x20
    bl svg_tag_end
    cbz x0, Lsvg_nil
    mov x19, x0
    sub x28, x0, #1
    str xzr, [sp, #2368]
    // Default viewBox 0 0 24 24, replaced by four validated numbers.
    str xzr, [sp, #2112]
    str xzr, [sp, #2120]
    NUM d0, 24
    str d0, [sp, #2128]
    str d0, [sp, #2136]
    mov x0, x27
    mov x1, x28
    ADDR x2, svg_viewbox
    bl _engine_attribute
    cbz x0, Lsvg_dimensions
    mov x24, x0
    mov x25, x0
    mov x9, #1
    str x9, [sp, #2368]
    bl _strlen
    add x26, x24, x0
    mov x22, #0
Lsvg_viewbox_number:
    cmp x22, #4
    b.hs Lsvg_viewbox_free
    mov x0, x25
    mov x1, x26
    bl _svg_number
    cbz x1, Lsvg_viewbox_invalid
    mov x25, x0
    add x9, sp, #2112
    str d0, [x9, x22, lsl #3]
    add x22, x22, #1
    b Lsvg_viewbox_number
Lsvg_viewbox_invalid:
    mov x0, x24
    bl _free
    b Lsvg_nil
Lsvg_viewbox_free:
    mov x0, x24
    bl _free
Lsvg_dimensions:
    ADDR x9, svg_epsilon
    ldr d1, [x9]
    ldr d0, [sp, #2128]
    fcmp d0, d1
    b.lt Lsvg_nil
    ldr d0, [sp, #2136]
    fcmp d0, d1
    b.lt Lsvg_nil
    mov x0, x27
    mov x1, x28
    ADDR x2, svg_width_name
    ldr d0, [sp, #2128]
    bl _svg_attribute_number
    str d0, [sp, #2144]
    mov x0, x27
    mov x1, x28
    ADDR x2, svg_height_name
    ldr d0, [sp, #2136]
    bl _svg_attribute_number
    str d0, [sp, #2152]
    ldr x9, [sp, #2368]
    cbnz x9, Lsvg_viewport_ready
    ldr d0, [sp, #2144]
    str d0, [sp, #2128]
    ldr d0, [sp, #2152]
    str d0, [sp, #2136]
Lsvg_viewport_ready:
    ldr d0, [sp, #2144]
    ldr d1, [sp, #2152]
    fmov d2, #1.0
    fcmp d0, d2
    b.lt Lsvg_nil
    fcmp d1, d2
    b.lt Lsvg_nil
    NUM d2, 1024
    fcmp d0, d2
    b.hi Lsvg_nil
    fcmp d1, d2
    b.hi Lsvg_nil
    CLASS NSImage
    MSG alloc
    ldr d0, [sp, #2144]
    ldr d1, [sp, #2152]
    MSG initSize
    cbz x0, Lsvg_nil
    mov x22, x0
    MSG lockFocus
    CLASS NSGraphicsContext
    MSG currentContext
    MSG CGContext
    mov x23, x0
    bl _CGContextSaveGState
    mov x0, x23
    fmov d0, xzr
    ldr d1, [sp, #2152]
    bl _CGContextTranslateCTM
    mov x0, x23
    fmov d0, #1.0
    fmov d1, #-1.0
    bl _CGContextScaleCTM
    ldr d0, [sp, #2144]
    ldr d1, [sp, #2152]
    ldr d2, [sp, #2128]
    ldr d3, [sp, #2136]
    fdiv d4, d0, d2
    fdiv d5, d1, d3
    fmin d4, d4, d5
    str d4, [sp, #2160]
    fmul d2, d2, d4
    fmul d3, d3, d4
    fsub d0, d0, d2
    fsub d1, d1, d3
    fmov d5, #0.5
    fmul d0, d0, d5
    fmul d1, d1, d5
    ldr d2, [sp, #2112]
    ldr d3, [sp, #2120]
    fmul d2, d2, d4
    fmul d3, d3, d4
    fsub d0, d0, d2
    fsub d1, d1, d3
    mov x0, x23
    bl _CGContextTranslateCTM
    mov x0, x23
    ldr d0, [sp, #2160]
    fmov d1, d0
    bl _CGContextScaleCTM
    // Root paint: fill black, stroke none, widths/alpha one.
    mov x26, sp
    mov x0, x26
    mov x1, #0
    mov x2, #64
    bl _memset
    mov x9, #-1
    str x9, [x26, #8]
    fmov d0, #1.0
    str d0, [x26, #16]
    str d0, [x26, #24]
    str d0, [x26, #32]
    str d0, [x26, #40]
    cbz x21, Lsvg_root_attrs
    ldr x9, [x21, #(32+CSS_FILL*8)]
    cmn x9, #6
    b.ne Lsvg_root_fill
    ldr x9, [x21, #32]
    cmp x9, #0
    csel x9, xzr, x9, lt
Lsvg_root_fill:
    str x9, [x26]
    ldr x9, [x21, #(32+CSS_STROKE*8)]
    str x9, [x26, #8]
Lsvg_root_attrs:
    mov x0, x27
    mov x1, x28
    mov x2, x26
    mov x3, x21
    bl _mac_svg_paint
    cbz x21, Lsvg_root_transform
    // Author CSS on the svg element overrides XML presentation attributes.
    ADDR x24, svg_css_paint_properties
    mov x25, #0
Lsvg_root_css:
    cmp x25, #4
    b.hs Lsvg_root_transform
    ldr x9, [x24, x25, lsl #3]
    add x10, x21, #1024
    ldr x10, [x10, x9, lsl #3]
    cbz x10, Lsvg_root_css_next
    add x10, x21, #32
    ldr x10, [x10, x9, lsl #3]
    cmp x25, #2
    b.hs Lsvg_root_css_scalar
    cmn x10, #6
    b.ne Lsvg_root_css_color
    ldr x10, [x21, #32]
    cmp x10, #0
    csel x10, xzr, x10, lt
Lsvg_root_css_color:
    str x10, [x26, x25, lsl #3]
    b Lsvg_root_css_next
Lsvg_root_css_scalar:
    scvtf d0, x10
    cmp x25, #3
    b.ne Lsvg_root_css_store_scalar
    NUM d1, 1000
    fdiv d0, d0, d1
Lsvg_root_css_store_scalar:
    str d0, [x26, x25, lsl #3]
Lsvg_root_css_next:
    add x25, x25, #1
    b Lsvg_root_css
Lsvg_root_transform:
    mov x0, x27
    mov x1, x28
    mov x2, x23
    bl _mac_svg_transform
    mov x24, #0                    // group depth
    mov x25, #0                    // element budget
Lsvg_element:
    cmp x19, x20
    b.hs Lsvg_finish
    mov x0, x19
    mov w1, #60
    sub x2, x20, x19
    bl _memchr
    cbz x0, Lsvg_finish
    add x19, x0, #1
    cmp x19, x20
    b.hs Lsvg_finish
    sub x9, x20, x19
    cmp x9, #3
    b.lo Lsvg_element_normal
    mov x0, x19
    ADDR x1, svg_comment_start
    mov x2, #3
    bl _memcmp
    cbnz w0, Lsvg_element_normal
    add x0, x19, #3
    sub x1, x20, x0
    ADDR x2, svg_comment_end
    mov x3, #3
    bl _memmem
    cbz x0, Lsvg_finish
    add x19, x0, #3
    b Lsvg_element
Lsvg_element_normal:
    mov x9, #0
    ldrb w10, [x19]
    cmp w10, #47
    b.ne Lsvg_name_start
    mov x9, #1
    add x19, x19, #1
Lsvg_name_start:
    str x9, [sp, #2352]
    mov x27, x19
Lsvg_name_end:
    cmp x19, x20
    b.hs Lsvg_finish
    ldrb w9, [x19]
    orr w10, w9, #32
    sub w10, w10, #97
    cmp w10, #25
    b.hi Lsvg_name_ready
    add x19, x19, #1
    b Lsvg_name_end
Lsvg_name_ready:
    sub x1, x19, x27
    mov x0, x27
    bl svg_tag_kind
    str x0, [sp, #2360]
    str x27, [sp, #2376]
    sub x9, x19, x27
    str x9, [sp, #2384]
    mov x27, x19                   // attribute start
    mov x0, x19
    mov x1, x20
    bl svg_tag_end
    cbz x0, Lsvg_finish
    mov x19, x0
    sub x28, x19, #1
    ldr x9, [sp, #2352]
    cbnz x9, Lsvg_closing
    add x25, x25, #1
    cmp x25, #1024
    b.hi Lsvg_finish
    ldr x9, [sp, #2360]
    cmp x9, #20
    b.eq Lsvg_skip_content
    cmp x9, #10
    b.eq Lsvg_open_group
    cmp x9, #11
    b.eq Lsvg_open_group
    cbz x9, Lsvg_element
    // Each primitive has local paint/transform state.
    mov x0, x23
    bl _CGContextSaveGState
    add x0, sp, #2240
    mov x1, x26
    mov x2, #64
    bl _memcpy
    mov x0, x27
    mov x1, x28
    add x2, sp, #2240
    mov x3, x21
    bl _mac_svg_paint
    mov x0, x27
    mov x1, x28
    mov x2, x23
    bl _mac_svg_transform
    mov x0, x23
    mov x1, x27
    mov x2, x28
    ldr x3, [sp, #2360]
    add x4, sp, #2240
    bl _mac_svg_shape
    mov x0, x23
    bl _CGContextRestoreGState
    b Lsvg_element
Lsvg_open_group:
    cmp x24, #31
    b.hs Lsvg_finish
    mov x0, x23
    bl _CGContextSaveGState
    add x24, x24, #1
    mov x10, sp
    add x0, x10, x24, lsl #6
    mov x1, x26
    mov x2, #64
    bl _memcpy
    mov x10, sp
    add x26, x10, x24, lsl #6
    mov x0, x27
    mov x1, x28
    mov x2, x26
    mov x3, x21
    bl _mac_svg_paint
    mov x0, x27
    mov x1, x28
    mov x2, x23
    bl _mac_svg_transform
    ldrb w9, [x28, #-1]
    cmp w9, #47
    b.ne Lsvg_element
    b Lsvg_pop_group
Lsvg_closing:
    ldr x9, [sp, #2360]
    cmp x9, #11
    b.eq Lsvg_close_svg
    cmp x9, #10
    b.ne Lsvg_element
    cbz x24, Lsvg_element
Lsvg_pop_group:
    mov x0, x23
    bl _CGContextRestoreGState
    sub x24, x24, #1
    mov x10, sp
    add x26, x10, x24, lsl #6
    b Lsvg_element
Lsvg_close_svg:
    cbz x24, Lsvg_finish
    b Lsvg_pop_group
Lsvg_skip_content:
    // Definitions, scripts and unsupported resource containers never draw.
    ldr x9, [sp, #2384]
    cmp x9, #24
    b.hi Lsvg_element
    add x0, sp, #2400
    mov w10, #60
    strb w10, [x0]
    mov w10, #47
    strb w10, [x0, #1]
    add x0, x0, #2
    ldr x1, [sp, #2376]
    mov x2, x9
    bl _memcpy
    mov x0, x19
    mov x1, x20
    add x2, sp, #2400
    ldr x3, [sp, #2384]
    add x3, x3, #2
    bl _engine_find_close
    mov x19, x0
    b Lsvg_element
Lsvg_finish:
    cbz x24, Lsvg_restore_root
    mov x0, x23
    bl _CGContextRestoreGState
    sub x24, x24, #1
    b Lsvg_finish
Lsvg_restore_root:
    mov x0, x23
    bl _CGContextRestoreGState
    mov x0, x22
    MSG unlockFocus
    mov x0, x22
    add sp, sp, #2560
    LEAVE
Lsvg_nil:
    mov x0, #0
    add sp, sp, #2560
    LEAVE
.section __DATA,__const
.p2align 3
svg_epsilon: .double 0.000001
svg_css_paint_properties: .quad CSS_FILL,CSS_STROKE,CSS_STROKE_WIDTH,CSS_OPACITY
svg_tags:
.quad svg_path,4,1, svg_rect,4,2, svg_circle,6,3, svg_ellipse,7,4
.quad svg_line,4,5, svg_polyline,8,6, svg_polygon,7,7, svg_g,1,10, svg_svg,3,11
.quad svg_defs,4,20, svg_script,6,20, svg_style,5,20, svg_symbol,6,20
.quad svg_clip,8,20, svg_mask,4,20, svg_foreign,13,20, svg_title,5,20, svg_desc,4,20
.quad 0,0,0
.section __TEXT,__cstring,cstring_literals
svg_open: .asciz "<svg"
svg_viewbox: .asciz "viewBox"
svg_width_name: .asciz "width"
svg_height_name: .asciz "height"
svg_path: .asciz "path"
svg_rect: .asciz "rect"
svg_circle: .asciz "circle"
svg_ellipse: .asciz "ellipse"
svg_line: .asciz "line"
svg_polyline: .asciz "polyline"
svg_polygon: .asciz "polygon"
svg_g: .asciz "g"
svg_svg: .asciz "svg"
svg_defs: .asciz "defs"
svg_script: .asciz "script"
svg_style: .asciz "style"
svg_symbol: .asciz "symbol"
svg_clip: .asciz "clipPath"
svg_mask: .asciz "mask"
svg_foreign: .asciz "foreignObject"
svg_title: .asciz "title"
svg_desc: .asciz "desc"

.section __TEXT,__cstring,cstring_literals
svg_comment_start: .asciz "!--"
svg_comment_end: .asciz "-->"
