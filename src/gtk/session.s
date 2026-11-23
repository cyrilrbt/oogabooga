// Independent HTTP session: libsoup supplies transport and certificate checks.
// No WebKit requests are used by the assembly document engine.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_engine_post
_gtk_engine_post:
    ENTER
    mov x19, x0
    mov x0, x1
    bl _g_strdup
    STORE x0, gtk_request_body
    mov x0, x19
    STORE xzr, _gtk_nav_pending
    bl _gtk_engine_load_target
    LEAVE
// URI -> asynchronous navigation. GTK remains responsive during transport.
.globl _gtk_engine_load_uri
_gtk_engine_load_uri:
    STORE xzr, gtk_request_body
    STORE xzr, _gtk_nav_pending
    ENTER
    mov x19, x0
    bl _gtk_fragment_navigate
    cbnz x0, Lgtk_uri_fragment_done
    mov x0, x19
    bl _gtk_engine_load_target
Lgtk_uri_fragment_done:
    LEAVE
.globl _gtk_engine_load_target
_gtk_engine_load_target:
    ENTER
    mov x19, x0
    bl _gtk_navigation_save
    mov x0, x19
    bl _g_uri_parse_scheme
    cbz x0, Lgtk_load_reject
    mov x20, x0
    ADDR x1, gtk_http
    bl _strcasecmp
    cbz x0, Lgtk_load_scheme_ok
    mov x0, x20
    ADDR x1, gtk_https
    bl _strcasecmp
    cbnz x0, Lgtk_load_scheme_bad
Lgtk_load_scheme_ok:
    bl _gtk_js_reset
    mov x0, x20
    bl _g_free
    LOAD x0, _gtk_cancel
    cbz x0, Lgtk_load_session
    bl _g_cancellable_cancel
    LOAD x0, _gtk_cancel
    bl _g_object_unref
Lgtk_load_session:
    bl _g_cancellable_new
    STORE x0, _gtk_cancel
    LOAD x0, _gtk_session
    cbnz x0, Lgtk_load_message
    bl _soup_session_new
    STORE x0, _gtk_session
    bl _soup_cookie_jar_new
    mov x20, x0
    mov x1, x0
    LOAD x0, _gtk_session
    bl _soup_session_add_feature
    mov x0, x20
    bl _g_object_unref
Lgtk_load_message:
    ADDR x0, gtk_get
    LOAD x9, gtk_request_body
    cbz x9, Lgtk_method_ready
    ADDR x0, gtk_post
Lgtk_method_ready:
    mov x1, x19
    bl _soup_message_new
    cbz x0, Lgtk_load_reject
    mov x20, x0
    LOAD x21, gtk_request_body
    cbz x21, Lgtk_request_record
    mov x0, x21
    bl _strlen
    mov x1, x0
    mov x0, x21
    bl _g_bytes_new
    mov x22, x0
    mov x0, x20
    ADDR x1, gtk_form_content_type
    mov x2, x22
    bl _soup_message_set_request_body_from_bytes
    mov x0, x22
    bl _g_bytes_unref
    mov x0, x21
    bl _g_free
    STORE xzr, gtk_request_body
Lgtk_request_record:
    mov x0, #1
    mov x1, #48
    bl _calloc
    mov x21, x0
    str x20, [x21]
    LOAD x0, _gtk_cancel
    bl _g_object_ref
    str x0, [x21, #8]
    mov x0, x19
    bl _g_strdup
    str x0, [x21, #16]
    LOAD x9, _gtk_nav_pending
    str x9, [x21, #24]
    mov x0, x20
    ADDR x1, gtk_auth_signal
    CALLBACK x2, _gtk_authenticate
    mov x3, x21
    bl _gtk_engine_connect
    ADDR x0, gtk_loading_text
    bl _gtk_engine_status
    LOAD x0, _gtk_session
    mov x1, x20
    mov x2, #0
    LOAD x3, _gtk_cancel
    CALLBACK x4, _gtk_engine_loaded
    mov x5, x21
    bl _soup_session_send_and_read_async
    mov x0, #1
    LEAVE
Lgtk_load_scheme_bad:
    mov x0, x20
    bl _g_free
Lgtk_load_reject:
    LOAD x0, gtk_request_body
    bl _g_free
    STORE xzr, gtk_request_body
    mov x0, #0
    LEAVE

// SoupSession, GAsyncResult, owned request record. Stale completions never commit.
.globl _gtk_engine_loaded
_gtk_engine_loaded:
    ENTER
    mov x19, x2
    str xzr, [sp, #144]
    add x2, sp, #144
    bl _soup_session_send_and_read_finish
    mov x20, x0
    ldr x0, [sp, #144]
    cbz x0, Lgtk_loaded_current
    mov x27, x0
    LOAD x9, _gtk_cancel
    ldr x10, [x19, #8]
    cmp x9, x10
    b.ne Lgtk_error_release
    ldr x0, [x27, #8]
    bl _gtk_engine_status
Lgtk_error_release:
    mov x0, x27
    bl _g_error_free
    b Lgtk_loaded_cleanup
Lgtk_loaded_current:
    LOAD x9, _gtk_cancel
    ldr x10, [x19, #8]
    cmp x9, x10
    b.ne Lgtk_loaded_cleanup
    cbz x20, Lgtk_loaded_cleanup
    mov x0, x20
    add x1, sp, #152
    bl _g_bytes_get_data
    mov x21, x0
    ldr x22, [sp, #152]
    mov x9, #1048576
    cmp x22, x9
    b.hi Lgtk_loaded_decode_error
    ldr x0, [x19]
    mov x1, x21
    mov x2, x22
    bl _gtk_decode
    cbz x0, Lgtk_loaded_decode_error
    mov x25, x0
    bl _strlen
    mov x1, x0
    mov x0, x25
    bl _engine_parse
    mov x26, x0
    mov x0, x25
    bl _g_free
    mov x0, x26
    cbz x0, Lgtk_loaded_cleanup
    mov x23, x0
    bl _gtk_js_reset
    ldr x0, [x19]
    bl _soup_message_get_response_headers
    ADDR x1, gtk_js_csp_header
    bl _soup_message_headers_get_one
    cmp x0, #0
    cset x9, ne
    STORE x9, _gtk_js_csp
    bl _gtk_selection_reset
    bl _gtk_imports_reset
    bl _gtk_fonts_reset
    LOAD x24, _gtk_doc
    bl _gtk_engine_clear_layout
    LOAD x0, _gtk_controls
    cbz x0, Lgtk_loaded_widgets_cleared
    // Remove old native widgets before releasing the document generation.
    bl _g_hash_table_remove_all
Lgtk_loaded_widgets_cleared:
    LOAD x0, _gtk_images
    cbz x0, Lgtk_loaded_images_cleared
    bl _g_hash_table_remove_all
Lgtk_loaded_images_cleared:
    mov x0, x24
    cbz x0, Lgtk_loaded_show
    bl _engine_document_free
Lgtk_loaded_show:
    LOAD x0, _gtk_uri
    bl _g_free
    ldr x0, [x19]
    bl _soup_message_get_uri
    bl _g_uri_to_string
    STORE x0, _gtk_uri
    STORE x23, _gtk_doc
    bl _gtk_base_update
    mov x0, x23
    bl _gtk_engine_show_document
    ldr x9, [x19, #24]
    STORE x9, _gtk_nav_pending
    bl _gtk_navigation_commit
    bl _gtk_engine_committed
    ldr x9, [x19, #24]
    cbz x9, Lgtk_commit_fragment
    bl _gtk_navigation_restore
    b Lgtk_commit_resources
Lgtk_commit_fragment:
    bl _gtk_fragment_scroll
Lgtk_commit_resources:
    bl _gtk_resources_begin
    LOAD x0, _gtk_doc
    bl _gtk_js_begin
    b Lgtk_loaded_cleanup
Lgtk_loaded_decode_error:
    ADDR x0, gtk_decode_error
    bl _gtk_engine_status
Lgtk_loaded_cleanup:
    cbz x20, Lgtk_loaded_record
    mov x0, x20
    bl _g_bytes_unref
Lgtk_loaded_record:
    ldr x0, [x19]
    bl _g_object_unref
    ldr x0, [x19, #8]
    bl _g_object_unref
    ldr x0, [x19, #16]
    bl _g_free
    mov x0, x19
    bl _free
    LEAVE
.globl _gtk_engine_cancel_load
_gtk_engine_cancel_load:
    ENTER
    LOAD x19, _gtk_cancel
    STORE xzr, _gtk_cancel
    cbz x19, Lgtk_cancelled
    mov x0, x19
    bl _g_cancellable_cancel
    mov x0, x19
    bl _g_object_unref
Lgtk_cancelled:
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_session,_gtk_cancel,_gtk_uri
_gtk_session: .space 8
_gtk_cancel: .space 8
_gtk_uri: .space 8
gtk_request_body: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_get: .asciz "GET"
gtk_http: .asciz "http"
gtk_https: .asciz "https"

gtk_loading_text: .asciz "Assembly engine: loading…"

gtk_post: .asciz "POST"
gtk_form_content_type: .asciz "application/x-www-form-urlencoded"

gtk_auth_signal: .asciz "authenticate"

gtk_decode_error: .asciz "Assembly engine: response is too large or has an unsupported text encoding."

gtk_js_csp_header: .asciz "Content-Security-Policy"
