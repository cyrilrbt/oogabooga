// HTTP charset decoding is native conversion; markup parsing remains assembly.
.include "src/gtk/gtk.inc"
.text
// message, bytes, length -> owned validated UTF-8 or NULL.
.globl _gtk_decode
_gtk_decode:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    str xzr, [sp, #144]
    bl _soup_message_get_response_headers
    add x1, sp, #144
    bl _soup_message_headers_get_content_type
    ldr x0, [sp, #144]
    cbz x0, Lgtk_decode_utf8
    ADDR x1, gtk_charset_key
    bl _g_hash_table_lookup
    cbz x0, Lgtk_decode_utf8
    bl _g_strdup
    mov x22, x0
    ldr x0, [sp, #144]
    bl _g_hash_table_destroy
    str xzr, [sp, #144]
    // HTML ASCII/Latin-1 labels use Windows-1252.
    mov x0, x22
    ADDR x1, gtk_charset_latin
    bl _strcasecmp
    cbz x0, Lgtk_decode_windows
    mov x0, x22
    ADDR x1, gtk_charset_ascii
    bl _strcasecmp
    cbnz x0, Lgtk_decode_iconv
Lgtk_decode_windows:
    mov x0, x22
    bl _g_free
    ADDR x0, gtk_charset_windows
    bl _g_strdup
    mov x22, x0
Lgtk_decode_iconv:
    ADDR x0, gtk_charset_utf8
    mov x1, x22
    bl _g_iconv_open
    mov x23, x0
    mov x0, x22
    bl _g_free
    cmn x23, #1
    b.eq Lgtk_decode_bad
    mov x0, x20
    mov x1, x21
    mov x2, x23
    mov x3, #0
    add x4, sp, #152
    mov x5, #0
    bl _g_convert_with_iconv
    mov x24, x0
    mov x0, x23
    bl _g_iconv_close
    cbz x24, Lgtk_decode_bad
    ldr x21, [sp, #152]
    mov x9, #1048576
    cmp x21, x9
    b.hi Lgtk_decode_free_bad
    mov x20, x24
    b Lgtk_decode_validate
Lgtk_decode_utf8:
    ldr x0, [sp, #144]
    cbz x0, Lgtk_decode_copy
    bl _g_hash_table_destroy
Lgtk_decode_copy:
    mov x0, x20
    mov x1, x21
    bl _g_strndup
    mov x24, x0
    mov x20, x0
Lgtk_decode_validate:
    mov x0, x20
    mov x1, x21
    mov x2, #0
    bl _g_utf8_validate
    cbz x0, Lgtk_decode_free_bad
    mov x0, x24
    LEAVE
Lgtk_decode_free_bad:
    mov x0, x24
    bl _g_free
Lgtk_decode_bad:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_charset_key: .asciz "charset"
gtk_charset_utf8: .asciz "UTF-8"
gtk_charset_latin: .asciz "ISO-8859-1"
gtk_charset_ascii: .asciz "US-ASCII"
gtk_charset_windows: .asciz "WINDOWS-1252"
