// Same-origin script/fetch transport. Every async record owns its GObjects and
// carries a generation number; stale callbacks never dereference VM memory.
.include "src/gtk/gtk.inc"
.include "src/engine/js.inc"
.text
.globl _gtk_js_requests
_gtk_js_requests:
    ENTER
Lgtk_js_request_next:
    LOAD x19, _gtk_js_vm
    cbz x19, Lgtk_js_requests_done
    mov x0, x19
    bl _engine_js_request_next
    cbz x0, Lgtk_js_requests_done
    mov x20, x0
    ldr x9, [x20, #8]
    cbz x9, Lgtk_js_request_blocked
    LOAD x0, _gtk_base
    ldr x1, [x9, #8]
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    cbz x0, Lgtk_js_request_blocked
    mov x21, x0
    mov x1, x21
    LOAD x0, _gtk_uri
    bl _engine_js_same_origin
    cbz x0, Lgtk_js_request_url_blocked
    ADDR x0, gtk_js_get
    mov x1, x21
    bl _soup_message_new
    cbz x0, Lgtk_js_request_url_blocked
    mov x22, x0
    mov x1, #2                 // SOUP_MESSAGE_NO_REDIRECT: fail closed.
    bl _soup_message_add_flags
    mov x0, #1
    mov x1, #96
    bl _calloc
    cbz x0, Lgtk_js_request_message_failed
    mov x23, x0
    str x22, [x23]
    LOAD x9, _gtk_js_generation
    str x9, [x23, #8]
    str x19, [x23, #16]
    str x20, [x23, #24]
    str x21, [x23, #72]
    LOAD x0, _gtk_js_cancel
    bl _g_object_ref
    str x0, [x23, #64]
    bl _g_byte_array_new
    str x0, [x23, #40]
    LOAD x0, _gtk_session
    cbnz x0, Lgtk_js_request_session
    bl _soup_session_new
    STORE x0, _gtk_session
Lgtk_js_request_session:
    mov x24, x0
    mov x1, #10
    bl _soup_session_set_timeout
    mov x0, x24
    mov x1, x22
    mov x2, #0
    ldr x3, [x23, #64]
    CALLBACK x4, _gtk_js_sent
    mov x5, x23
    bl _soup_session_send_async
    b Lgtk_js_request_next
Lgtk_js_request_message_failed:
    mov x0, x22
    bl _g_object_unref
Lgtk_js_request_url_blocked:
    mov x0, x21
    bl _g_free
Lgtk_js_request_blocked:
    mov x0, x19
    mov x1, x20
    mov x2, #-1
    mov x3, #0
    mov x4, #0
    bl _engine_js_complete
    b Lgtk_js_request_next
Lgtk_js_requests_done:
    LEAVE
// session,result,record
.globl _gtk_js_sent
_gtk_js_sent:
    ENTER
    mov x19, x2
    mov x2, #0
    bl _soup_session_send_finish
    str x0, [x19, #32]
    cbz x0, Lgtk_js_sent_failed
    ldr x9, [x19, #8]
    LOAD x10, _gtk_js_generation
    cmp x9, x10
    b.ne Lgtk_js_sent_stale
    ldr x0, [x19]
    bl _soup_message_get_uri
    bl _g_uri_to_string
    mov x20, x0
    mov x1, x20
    LOAD x0, _gtk_uri
    bl _engine_js_same_origin
    mov x21, x0
    mov x0, x20
    bl _g_free
    cbz x21, Lgtk_js_sent_failed
    ldr x0, [x19]
    bl _soup_message_get_status
    str x0, [x19, #48]
    cmp x0, #300
    b.lt Lgtk_js_status_ok
    cmp x0, #400
    b.lt Lgtk_js_sent_failed
Lgtk_js_status_ok:
    ldr x9, [x19, #24]
    ldr x9, [x9]
    cmp x9, #1
    b.ne Lgtk_js_sent_read
    ldr x0, [x19]
    bl _soup_message_get_response_headers
    mov x1, #0
    bl _soup_message_headers_get_content_type
    cbz x0, Lgtk_js_sent_failed
    mov x20, x0
    ADDR x1, gtk_js_mime
    bl _strcasecmp
    cbz x0, Lgtk_js_sent_read
    mov x0, x20
    ADDR x1, gtk_js_mime_alt
    bl _strcasecmp
    cbnz x0, Lgtk_js_sent_failed
Lgtk_js_sent_read:
    mov x0, x19
    bl gtk_js_read
    LEAVE
Lgtk_js_sent_failed:
    mov x0, x19
    bl gtk_js_fail
    LEAVE
Lgtk_js_sent_stale:
    mov x0, x19
    bl gtk_js_record_free
    LEAVE
gtk_js_read:
    mov x5, x0
    ldr x3, [x0, #64]
    ldr x0, [x0, #32]
    mov x1, #16384
    mov x2, #0
    CALLBACK x4, _gtk_js_chunk
    b _g_input_stream_read_bytes_async
.globl _gtk_js_chunk
_gtk_js_chunk:
    ENTER
    mov x19, x2
    mov x2, #0
    bl _g_input_stream_read_bytes_finish
    cbz x0, Lgtk_js_chunk_failed
    mov x20, x0
    ldr x9, [x19, #8]
    LOAD x10, _gtk_js_generation
    cmp x9, x10
    b.ne Lgtk_js_chunk_stale
    add x1, sp, #144
    bl _g_bytes_get_data
    mov x21, x0
    ldr x22, [sp, #144]
    cbz x22, Lgtk_js_chunk_end
    ldr x9, [x19, #80]
    add x9, x9, x22
    mov x10, #JS_MAX_SOURCE
    cmp x9, x10
    b.hi Lgtk_js_chunk_large
    str x9, [x19, #80]
    ldr x0, [x19, #40]
    mov x1, x21
    mov x2, x22
    bl _g_byte_array_append
    mov x0, x20
    bl _g_bytes_unref
    mov x0, x19
    bl gtk_js_read
    LEAVE
Lgtk_js_chunk_end:
    mov x0, x20
    bl _g_bytes_unref
    ldr x9, [x19, #40]
    ldr x0, [x9]
    ldr w1, [x9, #8]
    cbnz x1, Lgtk_js_chunk_normalize
    ADDR x0, gtk_js_empty
Lgtk_js_chunk_normalize:
    bl _g_utf8_make_valid
    mov x20, x0
    cbz x0, Lgtk_js_chunk_failed
    bl _strlen
    mov x4, x0
    ldr x0, [x19, #16]
    ldr x1, [x19, #24]
    ldr x2, [x19, #48]
    mov x3, x20
    bl _engine_js_complete
    mov x0, x20
    bl _g_free
    bl _gtk_js_flush
    bl _gtk_js_requests
    mov x0, x19
    bl gtk_js_record_free
    LEAVE
Lgtk_js_chunk_large:
    mov x0, x20
    bl _g_bytes_unref
Lgtk_js_chunk_failed:
    mov x0, x19
    bl gtk_js_fail
    LEAVE
Lgtk_js_chunk_stale:
    mov x0, x20
    bl _g_bytes_unref
    mov x0, x19
    bl gtk_js_record_free
    LEAVE
gtk_js_fail:
    ENTER
    mov x19, x0
    ldr x9, [x19, #8]
    LOAD x10, _gtk_js_generation
    cmp x9, x10
    b.ne Lgtk_js_fail_free
    ldr x0, [x19, #16]
    ldr x1, [x19, #24]
    mov x2, #-1
    mov x3, #0
    mov x4, #0
    bl _engine_js_complete
    bl _gtk_js_flush
    bl _gtk_js_requests
Lgtk_js_fail_free:
    mov x0, x19
    bl gtk_js_record_free
    LEAVE
gtk_js_record_free:
    ENTER
    mov x19, x0
    ldr x0, [x19]
    cbz x0, Lgtk_js_free_stream
    bl _g_object_unref
Lgtk_js_free_stream:
    ldr x0, [x19, #32]
    cbz x0, Lgtk_js_free_bytes
    bl _g_object_unref
Lgtk_js_free_bytes:
    ldr x0, [x19, #40]
    cbz x0, Lgtk_js_free_cancel
    bl _g_byte_array_unref
Lgtk_js_free_cancel:
    ldr x0, [x19, #64]
    cbz x0, Lgtk_js_free_url
    bl _g_object_unref
Lgtk_js_free_url:
    ldr x0, [x19, #72]
    bl _g_free
    mov x0, x19
    bl _free
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_js_get: .asciz "GET"
gtk_js_empty: .asciz ""
gtk_js_mime: .asciz "text/javascript"
gtk_js_mime_alt: .asciz "application/javascript"
