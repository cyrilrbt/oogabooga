// Sequential optional resources with a generation token and bounded budgets.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_resources_begin
_gtk_resources_begin:
    STORE xzr, gtk_resource_index
    STORE xzr, gtk_resource_count
    STORE xzr, gtk_resource_bytes
    STORE xzr, gtk_background_index
    b _gtk_resources_next
.globl _gtk_resources_rebind
_gtk_resources_rebind:
    STORE xzr, gtk_resource_index
    STORE xzr, gtk_background_index
    b _gtk_resources_next
.globl _gtk_resources_next
_gtk_resources_next:
    ENTER
    LOAD x19, _gtk_doc
    cbz x19, Lgtk_resources_done
Lgtk_resources_imports:
    bl _gtk_imports_next
    cbz x0, Lgtk_resources_scan
    mov x23, x0
    LOAD x20, _gtk_import_pending
    mov x22, #3
    b Lgtk_resource_url
Lgtk_resources_scan:
    LOAD x20, gtk_resource_index
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lgtk_resources_fonts
    add x9, x20, #1
    STORE x9, gtk_resource_index
    LOAD x9, gtk_resource_count
    cmp x9, #32
    b.hs Lgtk_resources_done
    mov x0, x20
    bl _gtk_engine_node
    mov x21, x0
    ldr x9, [x2]
    mov x22, #1
    cmp x9, #NODE_SHEET
    b.eq Lgtk_resource_embedded
    cmp x9, #NODE_LINK
    b.eq Lgtk_resource_css
    cmp x9, #NODE_IMG
    b.ne Lgtk_resources_scan
    mov x22, #2
    ldr x23, [x21, #ATTR_SRC]
    b Lgtk_resource_url
Lgtk_resources_fonts:
    bl _gtk_fonts_next
    cbz x0, Lgtk_resources_backgrounds
    mov x23, x0
    LOAD x20, _gtk_font_pending
    mov x22, #5
    b Lgtk_resource_url
Lgtk_resources_backgrounds:
    LOAD x20, gtk_background_index
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lgtk_resources_done
    add x9, x20, #1
    STORE x9, gtk_background_index
    mov x0, x20
    bl _gtk_engine_node
    ldr x23, [x0, #(32+CSS_BG_IMAGE*8)]
    cmp x23, #0
    b.le Lgtk_resources_backgrounds
    LOAD x0, _gtk_images
    cbz x0, Lgtk_resource_background_request
    mov x1, x23
    bl _g_hash_table_lookup
    cbnz x0, Lgtk_resources_backgrounds
Lgtk_resource_background_request:
    mov x22, #4
    b Lgtk_resource_url
Lgtk_resource_embedded:
    ldr x23, [x2, #32]
    cbz x23, Lgtk_resources_scan
    mov x0, x23
    bl _strlen
    mov x1, x0
    mov x0, x23
    LOAD x2, _gtk_base
    bl _gtk_fonts_add_sheet
    mov x0, x23
    mov x1, x20
    LOAD x2, _gtk_base
    bl _gtk_imports_add
    b Lgtk_resources_imports
Lgtk_resource_css:
    ldr x23, [x21, #ATTR_CSS_DATA]
    cbnz x23, Lgtk_resource_css_cached
    ldr x0, [x21, #ATTR_REL]
    cbz x0, Lgtk_resources_scan
    ADDR x1, gtk_stylesheet
    bl _strcasecmp
    cbnz x0, Lgtk_resources_scan
    mov x0, x20
    bl _gtk_engine_node
    ldr x23, [x2, #32]
    b Lgtk_resource_url
Lgtk_resource_css_cached:
    ldr x1, [x2, #32]
    LOAD x0, _gtk_base
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    cbz x0, Lgtk_resources_scan
    mov x24, x0
    mov x0, x23
    bl _strlen
    mov x1, x0
    mov x0, x23
    mov x2, x24
    bl _gtk_fonts_add_sheet
    mov x0, x23
    mov x1, x20
    mov x2, x24
    bl _gtk_imports_add
    mov x0, x24
    bl _g_free
    b Lgtk_resources_imports
Lgtk_resource_url:
    LOAD x9, gtk_resource_count
    cmp x9, #32
    b.hs Lgtk_resources_done
    LOAD x9, gtk_resource_bytes
    mov x10, #8388608
    cmp x9, x10
    b.hs Lgtk_resources_done
    cbz x23, Lgtk_resources_scan
    LOAD x0, _gtk_base
    mov x1, x23
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    cbz x0, Lgtk_resources_scan
    mov x24, x0
    bl _g_uri_parse_scheme
    cbz x0, Lgtk_resource_bad_url
    mov x25, x0
    ADDR x1, gtk_resource_http
    bl _strcasecmp
    cbz x0, Lgtk_resource_scheme
    mov x0, x25
    ADDR x1, gtk_resource_https
    bl _strcasecmp
    mov x26, x0
    mov x0, x25
    bl _g_free
    cbnz x26, Lgtk_resource_bad_url
    b Lgtk_resource_request
Lgtk_resource_scheme:
    mov x0, x25
    bl _g_free
Lgtk_resource_request:
    ADDR x0, gtk_resource_get
    mov x1, x24
    bl _soup_message_new
    mov x25, x0
    mov x0, x24
    bl _g_free
    cbz x25, Lgtk_resources_scan
    mov x0, #1
    mov x1, #48
    bl _calloc
    mov x26, x0
    str x25, [x26]
    LOAD x0, _gtk_cancel
    bl _g_object_ref
    str x0, [x26, #8]
    str x20, [x26, #16]
    str x22, [x26, #24]
    str xzr, [x26, #32]
    mov x0, x25
    ADDR x1, gtk_resource_auth_signal
    CALLBACK x2, _gtk_authenticate
    mov x3, x26
    bl _gtk_engine_connect
    LOAD x9, gtk_resource_count
    add x9, x9, #1
    STORE x9, gtk_resource_count
    LOAD x0, _gtk_session
    mov x1, x25
    mov x2, #0
    LOAD x3, _gtk_cancel
    CALLBACK x4, _gtk_resource_loaded
    mov x5, x26
    bl _soup_session_send_and_read_async
    b Lgtk_resources_done
Lgtk_resource_bad_url:
    mov x0, x24
    bl _g_free
    b Lgtk_resources_scan
Lgtk_resources_done:
    LEAVE
.globl _gtk_resource_loaded
_gtk_resource_loaded:
    ENTER
    mov x19, x2
    str xzr, [sp, #144]
    add x2, sp, #144
    bl _soup_session_send_and_read_finish
    mov x20, x0
    LOAD x9, _gtk_cancel
    ldr x10, [x19, #8]
    cmp x9, x10
    cset x28, eq
    ldr x0, [sp, #144]
    cbz x0, Lgtk_resource_current
    bl _g_error_free
    b Lgtk_resource_cleanup
Lgtk_resource_current:
    cbz x28, Lgtk_resource_cleanup
    cbz x20, Lgtk_resource_cleanup
    ldr x0, [x19]
    bl _soup_message_get_status
    cmp x0, #200
    b.lt Lgtk_resource_cleanup
    cmp x0, #300
    b.ge Lgtk_resource_cleanup
    mov x0, x20
    add x1, sp, #152
    bl _g_bytes_get_data
    mov x21, x0
    ldr x22, [sp, #152]
    LOAD x9, gtk_resource_bytes
    add x9, x9, x22
    mov x10, #8388608
    cmp x9, x10
    b.hi Lgtk_resource_cleanup
    STORE x9, gtk_resource_bytes
    ldr x9, [x19, #24]
    cmp x9, #5
    b.eq Lgtk_resource_font
    cmp x9, #2
    b.eq Lgtk_resource_image
    cmp x9, #4
    b.eq Lgtk_resource_image
    mov x9, #1048576
    cmp x22, x9
    b.hi Lgtk_resource_cleanup
    mov x0, x21
    mov x1, x22
    mov x2, #0
    bl _g_utf8_validate
    cbz x0, Lgtk_resource_cleanup
    ldr x0, [x19]
    bl _soup_message_get_uri
    bl _g_uri_to_string
    mov x24, x0
    mov x2, x0
    mov x0, x21
    mov x1, x22
    bl _gtk_css_urls
    mov x23, x0
    cbz x23, Lgtk_resource_css_url_free
    mov x0, x23
    bl _strlen
    mov x22, x0
    mov x0, x23
    mov x1, x22
    mov x2, x24
    bl _gtk_fonts_add_sheet
Lgtk_resource_css_url_free:
    mov x0, x24
    bl _g_free
    cbz x23, Lgtk_resource_cleanup
    ldr x9, [x19, #24]
    cmp x9, #3
    b.eq Lgtk_resource_import_css
    ldr x0, [x19, #16]
    bl _gtk_engine_node
    str x23, [x0, #ATTR_CSS_DATA]
    ldr x0, [x19]
    bl _soup_message_get_uri
    bl _g_uri_to_string
    mov x24, x0
    mov x2, x24
    mov x0, x23
    ldr x1, [x19, #16]
    bl _gtk_imports_add
    mov x0, x24
    bl _g_free
    b Lgtk_resource_css_styles
Lgtk_resource_import_css:
    ldr x0, [x19, #16]
    mov x1, x23
    mov x2, x22
    bl _gtk_imports_complete
    mov x0, x23
    bl _g_free
Lgtk_resource_css_styles:
    bl _gtk_resources_styles
    b Lgtk_resource_reflow
Lgtk_resource_font:
    ldr x0, [x19, #16]
    mov x1, x21
    mov x2, x22
    bl _gtk_fonts_complete
    mov x9, #1
    str x9, [x19, #32]
    b Lgtk_resource_reflow
Lgtk_resource_image:
    mov x0, x21
    mov x1, x22
    ADDR x2, gtk_svg_marker
    mov x3, #4
    bl _memmem
    cbz x0, Lgtk_resource_raster
    mov x0, x21
    mov x1, x22
    mov x2, #0
    bl _mac_svg_image
    cbz x0, Lgtk_resource_cleanup
    mov x24, x0
    mov x0, x19
    bl gtk_resource_image_key
    mov x1, x24
    bl _gtk_image_cache
    b Lgtk_resource_reflow
Lgtk_resource_raster:
    bl _gdk_pixbuf_loader_new
    mov x23, x0
    ADDR x1, gtk_resource_size_signal
    CALLBACK x2, _gtk_image_size
    mov x3, #0
    bl _gtk_engine_connect
    mov x0, x23
    mov x1, x21
    mov x2, x22
    mov x3, #0
    bl _gdk_pixbuf_loader_write
    mov x24, x0
    mov x0, x23
    mov x1, #0
    bl _gdk_pixbuf_loader_close
    cbz x24, Lgtk_resource_loader_free
    cbz x0, Lgtk_resource_loader_free
    mov x0, x23
    bl _gdk_pixbuf_loader_get_pixbuf
    cbz x0, Lgtk_resource_loader_free
    bl _g_object_ref
    mov x24, x0
    LOAD x0, _gtk_images
    cbnz x0, Lgtk_resource_cache
    CALLBACK x0, _g_str_hash
    CALLBACK x1, _g_str_equal
    CALLBACK x2, _g_free
    CALLBACK x3, _g_object_unref
    bl _g_hash_table_new_full
    STORE x0, _gtk_images
Lgtk_resource_cache:
    mov x0, x19
    bl gtk_resource_image_key
    bl _g_strdup
    mov x1, x0
    LOAD x0, _gtk_images
    mov x2, x24
    bl _g_hash_table_insert
Lgtk_resource_loader_free:
    mov x0, x23
    bl _g_object_unref
Lgtk_resource_reflow:
    LOAD x0, _gtk_doc
    bl _gtk_engine_show_document
Lgtk_resource_cleanup:
    cbz x28, Lgtk_resource_cleanup_bytes
    ldr x9, [x19, #24]
    cmp x9, #5
    b.ne Lgtk_resource_cleanup_bytes
    ldr x9, [x19, #32]
    cbnz x9, Lgtk_resource_cleanup_bytes
    ldr x0, [x19, #16]
    mov x1, #0
    mov x2, #0
    bl _gtk_fonts_complete
Lgtk_resource_cleanup_bytes:
    cbz x20, Lgtk_resource_record_free
    mov x0, x20
    bl _g_bytes_unref
Lgtk_resource_record_free:
    ldr x0, [x19]
    bl _g_object_unref
    ldr x0, [x19, #8]
    bl _g_object_unref
    mov x0, x19
    bl _free
    cbz x28, Lgtk_resource_finished
    bl _gtk_resources_next
Lgtk_resource_finished:
    LEAVE
// Reject decompression bombs before a full image buffer is allocated.
.globl _gtk_image_size
_gtk_image_size:
    cmp x1, #8192
    b.hi Lgtk_image_reject
    cmp x2, #8192
    b.hi Lgtk_image_reject
    mul x9, x1, x2
    mov x10, #16777216
    cmp x9, x10
    b.hi Lgtk_image_reject
    ret
Lgtk_image_reject:
    mov x1, #1
    mov x2, #1
    b _gdk_pixbuf_loader_set_size

.globl _gtk_resources_styles
_gtk_resources_styles:
    ENTER
    bl _gtk_imports_styles
    LOAD x19, _gtk_doc
    ldr x9, [x19, #56]
    strb wzr, [x9]
    str xzr, [x19, #64]
    mov x20, #1
Lgtk_styles_next:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lgtk_styles_done
    mov x0, x20
    bl _gtk_engine_node
    ldr x9, [x2]
    cmp x9, #NODE_SHEET
    b.eq Lgtk_styles_inline
    cmp x9, #NODE_LINK
    b.ne Lgtk_styles_advance
    ldr x21, [x0, #ATTR_CSS_DATA]
    b Lgtk_styles_source
Lgtk_styles_inline:
    ldr x21, [x0, #ATTR_CSS_DATA]
    cbnz x21, Lgtk_styles_source
    ldr x21, [x2, #32]
Lgtk_styles_source:
    cbz x21, Lgtk_styles_advance
    mov x0, x21
    bl _strlen
    mov x2, x0
    mov x1, x21
    mov x0, x19
    bl _engine_css_source
Lgtk_styles_advance:
    add x20, x20, #1
    b Lgtk_styles_next
Lgtk_styles_done:
    LEAVE
.section __DATA,__bss
.p2align 3
gtk_resource_index: .space 8
gtk_resource_count: .space 8
gtk_resource_bytes: .space 8
gtk_background_index: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_stylesheet: .asciz "stylesheet"
gtk_resource_get: .asciz "GET"
gtk_resource_http: .asciz "http"
gtk_resource_https: .asciz "https"
gtk_resource_size_signal: .asciz "size-prepared"

gtk_svg_marker: .asciz "<svg"
gtk_resource_auth_signal: .asciz "authenticate"

.text
gtk_resource_image_key:
    ENTER
    ldr x19, [x0, #24]
    ldr x0, [x0, #16]
    bl _gtk_engine_node
    cmp x19, #4
    b.eq Lgtk_resource_background_key
    ldr x0, [x0, #ATTR_SRC]
    LEAVE
Lgtk_resource_background_key:
    ldr x0, [x0, #(32+CSS_BG_IMAGE*8)]
    LEAVE
