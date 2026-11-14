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
_mac_resources_next:
    ENTER
    LOAD x19, _engine_resource_doc
    cbz x19, Lresources_done
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
    add x22, x22, x20, lsl #10
    ldr x9, [x21]
    cmp x9, #NODE_SHEET
    b.eq Lresource_embedded
    cmp x9, #NODE_LINK
    b.eq Lresource_css
    cmp x9, #NODE_IMG
    b.ne Lresource_next
    mov x23, #2
    ldr x0, [x22, #ATTR_SRC]
    b Lresource_url
Lresource_css:
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
    bl _mac_string
    MSG lowercase
    mov x24, x0
    STR screen_media
    mov x2, x0
    mov x0, x24
    MSG equal
    cbnz w0, Lresource_css_url
    STR all_media
    mov x2, x0
    mov x0, x24
    MSG equal
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
    LOAD x3, _engine_pending_url
    MSG relativeURL
    MSG absoluteURL
    cbz x0, Lresource_next
    mov x24, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lresource_next
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
    b Lresource_next
Lresources_finish:
    bl _mac_resources_styles
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
    cmp x9, #1
    b.ne Lresource_image_mime
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
Lresource_image_mime:
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
    cmp x9, #1
    b.ne Lresource_decode_image
    LOAD x0, _engine_data
    LOAD x1, _engine_charset
    bl _mac_engine_decode
    cbz x0, Lresource_consumed
    mov x19, x0
    MSG length
    mov x20, x0
    mov x0, x19
    MSG bytes
    mov x1, x20
    bl _strndup
    mov x21, x0
    LOAD x9, _engine_resource_doc
    ldr x22, [x9, #72]
    LOAD x9, _engine_resource_node
    add x22, x22, x9, lsl #10
    ldr x0, [x22, #ATTR_CSS_DATA]
    bl _free
    str x21, [x22, #ATTR_CSS_DATA]
    mov x0, x19
    MSG release
    b Lresource_consumed
Lresource_decode_image:
    LOAD x0, _engine_data
    bl _mac_resource_image
    cbz x0, Lresource_consumed
    mov x19, x0
    CLASS NSNumber
    LOAD x2, _engine_resource_node
    MSG numberLongLong
    mov x3, x0
    mov x2, x19
    LOAD x0, _engine_images
    MSG setObjectKey
    mov x0, x19
    MSG release
Lresource_consumed:
    LOAD x9, _engine_phase
    cmp x9, #1
    b.ne Lresource_refresh
    bl _mac_resources_styles
Lresource_refresh:
    bl _mac_engine_refresh
    bl _mac_engine_cancel
    bl _mac_resources_next
    LEAVE
.section __TEXT,__cstring,cstring_literals
sheet_rel: .asciz "stylesheet"
css_mime: .asciz "text/css"
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
    LOAD x19, _engine_resource_doc
    cbz x19, Lstyles_done
    str xzr, [x19, #64]
    ldr x9, [x19, #56]
    strb wzr, [x9]
    mov x20, #0
Lstyles_next:
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
    add x9, x9, x20, lsl #10
    ldr x21, [x9, #ATTR_CSS_DATA]
    b Lstyles_source
Lstyles_inline:
    ldr x21, [x9, #32]
Lstyles_source:
    cbz x21, Lstyles_advance
    mov x0, x21
    bl _strlen
    mov x2, x0
    mov x1, x21
    mov x0, x19
    bl _engine_css_source
Lstyles_advance:
    add x20, x20, #1
    b Lstyles_next
Lstyles_apply:
    mov x0, x19
    bl _engine_css_apply
Lstyles_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
resources_loading: .asciz "Assembly engine: HTML ready; loading styles and images…"
resources_ready: .asciz "Assembly engine: ready. JavaScript is not supported. ⌘E switches to WebKit."

resources_history_error: .asciz "Assembly engine: page ready, but history could not be saved."
.section __DATA,__bss
.p2align 3
.globl _engine_history_failed
_engine_history_failed: .space 8
