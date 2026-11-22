// Resolve stylesheet-relative url() tokens before the shared cascade owns them.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_css_urls
_gtk_css_urls:
    ENTER
    mov x19, x0
    add x20, x0, x1
    mov x21, x2
    mov x0, #0
    bl _g_string_new
    mov x22, x0
Lgtk_css_url_next:
    mov x0, x19
    mov x1, x20
    bl _css_background_url_next
    cbz x0, Lgtk_css_url_tail
    stp x0, x1, [sp, #144]
    stp x2, x3, [sp, #160]
    sub x2, x0, x19
    mov x0, x22
    mov x1, x19
    bl _g_string_append_len
    ldp x0, x1, [sp, #160]
    sub x1, x1, x0
    bl _g_strndup
    mov x23, x0
    mov x1, x0
    mov x0, x21
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    mov x24, x0
    mov x0, x23
    bl _g_free
    cbz x24, Lgtk_css_url_original
    mov x0, x22
    ADDR x1, gtk_css_url_format
    mov x2, x24
    bl _g_string_append_printf
    mov x0, x24
    bl _g_free
    b Lgtk_css_url_advance
Lgtk_css_url_original:
    ldp x1, x2, [sp, #144]
    sub x2, x2, x1
    mov x0, x22
    bl _g_string_append_len
Lgtk_css_url_advance:
    ldr x19, [sp, #152]
    ldr x9, [x22, #8]
    mov x10, #1048576
    cmp x9, x10
    b.hi Lgtk_css_url_bad
    b Lgtk_css_url_next
Lgtk_css_url_tail:
    mov x0, x22
    mov x1, x19
    sub x2, x20, x19
    bl _g_string_append_len
    mov x0, x22
    mov x1, #0
    bl _g_string_free
    LEAVE
Lgtk_css_url_bad:
    mov x0, x22
    mov x1, #1
    bl _g_string_free
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_css_url_format: .asciz "url(\"%s\")"
