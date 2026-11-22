// Sequential, cancellable HTTP(S) subresources progressively update committed
// HTML. Available stylesheets always follow document order.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_resources_reset
_mac_resources_reset:
    ENTER
    bl _mac_imports_reset
    bl _mac_fonts_reset
    LOAD x0, resource_base_url
    MSG release
    STORE xzr, resource_base_url
    STORE xzr, _engine_resource_doc
    STORE xzr, _engine_phase
    STORE xzr, resource_index
    STORE xzr, resource_count
    STORE xzr, resource_total
    LOAD x0, _engine_images
    MSG release
    CLASS NSMutableDictionary
    MSG new
    STORE x0, _engine_images
    LEAVE

.globl _mac_resources_begin
_mac_resources_begin:
    ENTER
    mov x19, x0
    bl _mac_engine_cancel
    mov x0, x19
    bl _mac_engine_commit            // display HTML and record exactly one visit
    cbz w0, Lresource_begin_done
    STORE x19, _engine_resource_doc  // borrowed: displayed document owns the tree
    STR resources_loading
    bl _mac_status_text
    bl _mac_resources_next
Lresource_begin_done:
    LEAVE

.globl _mac_resources_next
.globl _mac_resources_rebind
_mac_resources_rebind:
    ENTER
    STORE x0, _engine_resource_doc
    STORE xzr, resource_index
    bl _mac_imports_rebind
    bl _mac_resources_styles
    LEAVE

_mac_resources_next:
    ENTER
    LOAD x19, _engine_resource_doc
    cbz x19, Lresources_done
Lresources_imports:
    bl _mac_imports_next
    cbz x0, Lresource_next
    mov x24, x0
    LOAD x20, _mac_import_owner
    mov x23, #1
    LOAD x9, resource_count
    cmp x9, #32
    b.hs Lresource_import_limit
    add x9, x9, #1
    STORE x9, resource_count
    b Lresource_request
Lresource_import_limit:
    mov x0, #0
    mov x1, #0
    bl _mac_imports_complete
    b Lresources_imports
Lresource_next:
    LOAD x20, resource_index
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lresources_finish
    add x9, x20, #1
    STORE x9, resource_index
    ldr x21, [x19, #16]
    mov x9, #40
    madd x21, x20, x9, x21
    ldr x22, [x19, #72]
    add x22, x22, x20, lsl #11
    ldr x9, [x21]
    cmp x9, #NODE_SHEET
    b.eq Lresource_embedded
    cmp x9, #NODE_LINK
    b.eq Lresource_css
    cmp x9, #NODE_IMG
    b.ne Lresource_next
    CLASS NSNumber
    mov x2, x20
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_images
    MSG objectKey
    cbnz x0, Lresource_next
    mov x23, #2
    ldr x0, [x22, #ATTR_SRC]
    b Lresource_url
Lresource_css:
    ldr x9, [x22, #ATTR_CSS_DATA]
    cbnz x9, Lresource_next
    ldr x0, [x22, #ATTR_REL]
    cbz x0, Lresource_next
    bl _mac_string
    MSG lowercase
    mov x24, x0
    STR sheet_rel
    mov x2, x0
    mov x0, x24
    MSG equal
    cbz w0, Lresource_next
    ldr x0, [x22, #ATTR_MEDIA]
    cbz x0, Lresource_css_url
    ldrb w9, [x0]
    cbz w9, Lresource_css_url
    mov x24, x0
    bl _strlen
    add x1, x24, x0
    mov x0, x24
    mov x2, #-1 // defer viewport conditions to the wrapped stylesheet
    bl _css_media_match
    cbz w0, Lresource_next
Lresource_css_url:
    mov x23, #1
    ldr x0, [x21, #32]
Lresource_url:
    cbz x0, Lresource_next
    LOAD x9, resource_count
    cmp x9, #32
    b.hs Lresource_next
    add x9, x9, #1
    STORE x9, resource_count
    bl _mac_string
    mov x24, x0
    CLASS NSURL
    mov x2, x24
    LOAD x3, _engine_render_base
    MSG relativeURL
    MSG absoluteURL
    cbz x0, Lresource_next
    mov x24, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lresource_next
Lresource_request:
    STORE x23, _engine_phase
    STORE x20, _engine_resource_node
    CLASS NSMutableData
    MSG new
    STORE x0, _engine_data
    CLASS NSURLRequest
    mov x2, x24
    LOAD x3, _engine_cache_policy   // normal HTTP caching; reload bypasses cache
    NUM d0, 10
    MSG resourceRequest
    mov x2, x0
    LOAD x0, _engine_session
    MSG dataTask
    MSG retain
    STORE x0, _engine_task
    MSG resume
    b Lresources_done
Lresource_embedded:
    ldr x23, [x21, #32]
    mov x0, x23
    bl _strlen
    mov x1, x0
    mov x0, x23
    LOAD x2, _engine_render_base
    bl _mac_fonts_add_sheet
    ldr x0, [x21, #32]
    mov x1, x20
    LOAD x2, _engine_render_base
    bl _mac_imports_add
    b Lresources_imports
Lresources_finish:
    bl _mac_resources_styles
    bl _mac_fonts_next
    cbz x0, Lresources_fonts_done
    mov x24, x0
    mov x23, #3
    LOAD x20, _mac_font_pending
    sub x20, x20, #1
    LOAD x9, resource_count
    cmp x9, #32
    b.hs Lresource_font_limit
    add x9, x9, #1
    STORE x9, resource_count
    b Lresource_request
Lresource_font_limit:
    mov x0, #0
    bl _mac_fonts_complete
    b Lresources_finish
Lresources_fonts_done:
    mov x0, x19
    bl _mac_background_next
    cbz x0, Lresources_backgrounds_done
    mov x24, x0
    mov x20, x1
    mov x23, #4
    LOAD x9, resource_count
    cmp x9, #32
    b.hs Lresources_backgrounds_done
    add x9, x9, #1
    STORE x9, resource_count
    b Lresource_request
Lresources_backgrounds_done:
    bl _mac_engine_refresh
    STORE xzr, _engine_resource_doc
    STORE xzr, _engine_phase
    LOAD x9, _engine_history_failed
    cbnz x9, Lresources_history_error
    STR resources_ready
    b Lresources_status
Lresources_history_error:
    STR resources_history_error
Lresources_status:
    bl _mac_status_text
Lresources_done:
    LEAVE

// resource response: returns allow BOOL. No document navigation state is changed.
.globl _mac_resource_response
_mac_resource_response:
    ENTER
    mov x19, x0
    MSG statusCode
    cmp x0, #200
    b.lo Lresource_reject
    cmp x0, #300
    b.hs Lresource_reject
    mov x0, x19
    MSG expectedLength
    bl _mac_resource_limit
    cmp x0, #0
    b.lt Lresource_mime
    cmp x0, x1
    b.hi Lresource_reject
Lresource_mime:
    mov x0, x19
    MSG MIMEType
    MSG lowercase
    mov x20, x0
    LOAD x9, _engine_phase
    cmp x9, #3
    b.eq Lresource_font_mime
    cmp x9, #1
    b.ne Lresource_image_mime
    mov x0, x19
    MSG URL
    MSG retain
    mov x21, x0
    LOAD x0, resource_base_url
    MSG release
    STORE x21, resource_base_url
    mov x0, x21
    bl _mac_imports_accept_url
    cbz x0, Lresource_reject
    STR css_mime
    mov x2, x0
    mov x0, x20
    MSG equal
    cbz w0, Lresource_reject
    LOAD x0, _engine_charset
    MSG release
    mov x0, x19
    MSG textEncodingName
    MSG retain
    STORE x0, _engine_charset
    mov w0, #1
    LEAVE
Lresource_font_mime:
    STR font_mime
    mov x2, x0
    mov x0, x20
    MSG hasPrefix
    cbnz x0, Lresource_font_allow
    STR font_binary_mime
    mov x2, x0
    mov x0, x20
    MSG equal
    cbnz x0, Lresource_font_allow
    STR font_legacy_mime
    mov x2, x0
    mov x0, x20
    MSG equal
    cbz x0, Lresource_reject
Lresource_font_allow:
    mov x0, #1
    LEAVE
Lresource_image_mime:
    STR svg_mime
    mov x2, x0
    mov x0, x20
    MSG equal
    STORE x0, resource_is_svg
    STR image_mime
    mov x2, x0
    mov x0, x20
    MSG hasPrefix
    LEAVE
Lresource_reject:
    mov w0, #0
    LEAVE

.globl _mac_resource_limit
_mac_resource_limit:
    LOAD x9, _engine_phase
    mov x1, #1048576
    cmp x9, #1
    b.eq Lresource_limit_return
    mov x1, #2097152
Lresource_limit_return:
    ret

// Consume optional resource data; errors leave alt text/default styles intact.
.globl _mac_resource_complete
_mac_resource_complete:
    ENTER
    cbnz x0, Lresource_consumed
    LOAD x0, _engine_data
    MSG length
    LOAD x9, resource_total
    add x9, x9, x0
    STORE x9, resource_total
    mov x10, #8388608
    cmp x9, x10
    b.hi Lresource_consumed
    LOAD x9, _engine_phase
    cmp x9, #3
    b.eq Lresource_decode_font
    cmp x9, #1
    b.ne Lresource_decode_image
    LOAD x0, _engine_data
    LOAD x1, _engine_charset
    bl _mac_engine_decode
    cbz x0, Lresource_consumed
    mov x19, x0
    LOAD x1, resource_base_url
    bl _mac_background_source
    mov x20, x0
    mov x0, x19
    MSG release
    mov x19, x20
    cbz x19, Lresource_consumed
    mov x0, x19
    MSG length
    mov x20, x0
    mov x0, x19
    MSG bytes
    LOAD x9, _mac_import_pending
    cbnz x9, Lresource_import_complete
    mov x1, x20
    bl _strndup
    mov x21, x0
    LOAD x9, _engine_resource_doc
    ldr x22, [x9, #72]
    LOAD x9, _engine_resource_node
    add x22, x22, x9, lsl #11
    ldr x0, [x22, #ATTR_CSS_DATA]
    bl _free
    str x21, [x22, #ATTR_CSS_DATA]
    mov x0, x21
    mov x1, x20
    LOAD x2, resource_base_url
    bl _mac_fonts_add_sheet
    mov x0, x21
    LOAD x1, _engine_resource_node
    LOAD x2, resource_base_url
    bl _mac_imports_add
    b Lresource_css_decoded
Lresource_import_complete:
    mov x1, x20
    LOAD x2, resource_base_url
    bl _mac_fonts_add_sheet
    mov x0, x19
    MSG bytes
    mov x1, x20
    bl _mac_imports_complete
Lresource_css_decoded:
    mov x0, x19
    MSG release
    b Lresource_consumed
Lresource_decode_font:
    LOAD x0, _engine_data
    bl _mac_fonts_complete
    b Lresource_consumed
Lresource_decode_image:
    LOAD x0, _engine_data
    bl _mac_resource_image
    cbz x0, Lresource_consumed
    mov x19, x0
    LOAD x9, _engine_phase
    cmp x9, #4
    b.ne Lresource_image_node_key
    LOAD x0, _engine_resource_doc
    ldr x0, [x0, #72]
    LOAD x9, _engine_resource_node
    add x0, x0, x9, lsl #11
    bl _mac_background_url
    MSG absoluteString
    b Lresource_image_key_ready
Lresource_image_node_key:
    CLASS NSNumber
    LOAD x2, _engine_resource_node
    MSG numberLongLong
Lresource_image_key_ready:
    mov x3, x0
    mov x2, x19
    LOAD x0, _engine_images
    MSG setObjectKey
    mov x0, x19
    MSG release
Lresource_consumed:
    // Rejected responses and network errors still finish the pending import.
    LOAD x9, _mac_import_pending
    cbz x9, Lresource_import_finished
    mov x0, #0
    mov x1, #0
    bl _mac_imports_complete
Lresource_import_finished:
    LOAD x9, _mac_font_pending
    cbz x9, Lresource_font_finished
    mov x0, #0
    bl _mac_fonts_complete
Lresource_font_finished:
    LOAD x9, _engine_phase
    cmp x9, #1
    b.eq Lresource_reapply_styles
    cmp x9, #3
    b.ne Lresource_refresh
Lresource_reapply_styles:
    bl _mac_resources_styles
Lresource_refresh:
    bl _mac_engine_refresh
    bl _mac_engine_cancel
    bl _mac_resources_next
    LEAVE
.section __TEXT,__cstring,cstring_literals
sheet_rel: .asciz "stylesheet"
css_mime: .asciz "text/css"
font_mime: .asciz "font/"
font_binary_mime: .asciz "application/octet-stream"
font_legacy_mime: .asciz "application/x-font-ttf"
image_mime: .asciz "image/"
screen_media: .asciz "screen"
all_media: .asciz "all"
.section __DATA,__bss
.p2align 3
.globl _engine_phase, _engine_resource_doc, _engine_resource_node, _engine_images
_engine_phase: .space 8
_engine_resource_doc: .space 8
_engine_resource_node: .space 8
_engine_images: .space 8
resource_index: .space 8
resource_count: .space 8
resource_total: .space 8

.text
.p2align 2
// Validate raster metadata before asking NSImage to decode pixels. This avoids
// allocating an unbounded bitmap from a tiny compressed resource.
_mac_resource_image:
    ENTER
    mov x19, x0
    LOAD x9, resource_is_svg
    cbz x9, Lresource_decode_raster
    MSG length
    mov x20, x0
    mov x0, x19
    MSG bytes
    mov x1, x20
    mov x2, #0
    bl _mac_svg_image
    LEAVE
Lresource_decode_raster:
    mov x0, x19
    mov x1, #0
    bl _CGImageSourceCreateWithData
    cbz x0, Lraster_none
    mov x20, x0
    mov x1, #0
    mov x2, #0
    bl _CGImageSourceCopyPropertiesAtIndex
    cbz x0, Lraster_source
    mov x21, x0
    adrp x9, _kCGImagePropertyPixelWidth@GOTPAGE
    ldr x9, [x9, _kCGImagePropertyPixelWidth@GOTPAGEOFF]
    ldr x1, [x9]
    bl _CFDictionaryGetValue
    cbz x0, Lraster_properties
    mov x1, #4                      // kCFNumberSInt64Type
    add x2, sp, #144
    bl _CFNumberGetValue
    cbz w0, Lraster_properties
    mov x0, x21
    adrp x9, _kCGImagePropertyPixelHeight@GOTPAGE
    ldr x9, [x9, _kCGImagePropertyPixelHeight@GOTPAGEOFF]
    ldr x1, [x9]
    bl _CFDictionaryGetValue
    cbz x0, Lraster_properties
    mov x1, #4
    add x2, sp, #152
    bl _CFNumberGetValue
    cbz w0, Lraster_properties
    ldp x9, x10, [sp, #144]
    cmp x9, #1
    b.lt Lraster_properties
    cmp x10, #1
    b.lt Lraster_properties
    cmp x9, #8192
    b.hi Lraster_properties
    cmp x10, #8192
    b.hi Lraster_properties
    mul x9, x9, x10
    mov x10, #16777216
    cmp x9, x10
    b.hi Lraster_properties
    mov x0, x21
    bl _CFRelease
    mov x0, x20
    bl _CFRelease
    CLASS NSImage
    MSG alloc
    mov x2, x19
    MSG initData
    LEAVE
Lraster_properties:
    mov x0, x21
    bl _CFRelease
Lraster_source:
    mov x0, x20
    bl _CFRelease
Lraster_none:
    mov x0, #0
    LEAVE

.text
.p2align 2
// Rebuild from every available sheet in document order, including inline sheets
// that occur after a pending fetch. Repeated refreshes never reorder the cascade.
_mac_resources_styles:
    ENTER
    bl _mac_imports_styles
    LOAD x19, _engine_resource_doc
    cbz x19, Lstyles_done
    str xzr, [x19, #64]
    ldr x9, [x19, #56]
    strb wzr, [x9]
    mov x20, #0
Lstyles_next:
    mov x22, #0
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lstyles_apply
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_SHEET
    b.eq Lstyles_inline
    cmp x10, #NODE_LINK
    b.ne Lstyles_advance
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x21, [x9, #ATTR_CSS_DATA]
    ldr x22, [x9, #ATTR_MEDIA]
    b Lstyles_source
Lstyles_inline:
    ldr x21, [x9, #32]
    ldr x10, [x19, #72]
    add x10, x10, x20, lsl #11
    ldr x22, [x10, #ATTR_MEDIA]
    ldr x10, [x10, #ATTR_CSS_DATA]
    cmp x10, #0
    csel x21, x21, x10, eq
Lstyles_source:
    cbz x21, Lstyles_advance
    mov x23, #0
    cbz x22, Lstyles_source_ready
    ldrb w9, [x22]
    cbz w9, Lstyles_source_ready
    mov x0, x21
    mov x1, x22
    bl _mac_media_source
    cbz x0, Lstyles_advance
    mov x21, x0
    mov x23, x0
Lstyles_source_ready:
    mov x0, x21
    bl _strlen
    mov x2, x0
    mov x1, x21
    mov x0, x19
    bl _engine_css_source
    mov x0, x23
    bl _free
Lstyles_advance:
    add x20, x20, #1
    b Lstyles_next
Lstyles_apply:
    mov x0, x19
    bl _engine_css_apply
Lstyles_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
resources_loading: .asciz "Assembly engine: HTML ready; loading styles, images and fonts…"
resources_ready: .asciz "Assembly engine: ready. JavaScript is not supported. ⌘E switches to WebKit."

resources_history_error: .asciz "Assembly engine: page ready, but history could not be saved."
.section __DATA,__bss
.p2align 3
.globl _engine_history_failed
_engine_history_failed: .space 8

.section __DATA,__data
.p2align 3
resource_is_svg: .quad 0
.section __TEXT,__cstring,cstring_literals
svg_mime: .asciz "image/svg+xml"
.section __DATA,__bss
.p2align 3
resource_base_url: .space 8
