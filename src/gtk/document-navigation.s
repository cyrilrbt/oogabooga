.include "src/gtk/gtk.inc"
.text
.globl _gtk_base_update
_gtk_base_update:
    ENTER
    LOAD x0, _gtk_base
    bl _g_free
    LOAD x0, _gtk_doc
    cbz x0, Lgtk_base_fallback
    bl _engine_base_href
    cbz x0, Lgtk_base_fallback
    mov x1, x0
    LOAD x0, _gtk_uri
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    cbnz x0, Lgtk_base_store
Lgtk_base_fallback:
    LOAD x0, _gtk_uri
    cbz x0, Lgtk_base_store
    bl _g_strdup
Lgtk_base_store:
    STORE x0, _gtk_base
    LEAVE
// current URL fragment -> scroll to a visible flow box, preserving missing IDs.
.globl _gtk_fragment_scroll
_gtk_fragment_scroll:
    ENTER
    LOAD x0, _gtk_uri
    cbz x0, Lgtk_fragment_done
    mov x1, #35
    bl _strchr
    cbz x0, Lgtk_fragment_top
    add x0, x0, #1
    mov x1, #0
    bl _g_uri_unescape_string
    cbz x0, Lgtk_fragment_done
    mov x19, x0
    mov x1, x0
    LOAD x0, _gtk_doc
    bl _engine_fragment_node
    mov x20, x0
    mov x0, x19
    bl _g_free
    tbnz x20, #63, Lgtk_fragment_done
    LOAD x9, _gtk_nodes
    cbz x9, Lgtk_fragment_done
    add x9, x9, x20, lsl #8
    ldr x21, [x9, #GN_Y]
Lgtk_fragment_adjust:
    LOAD x0, _gtk_view
    cbz x0, Lgtk_fragment_done
    bl _gtk_scrolled_window_get_vadjustment
    scvtf d0, x21
    bl _gtk_adjustment_set_value
    b Lgtk_fragment_done
Lgtk_fragment_top:
    mov x21, #0
    b Lgtk_fragment_adjust
Lgtk_fragment_done:
    LEAVE
// target URL -> handled iff this is a same-document fragment navigation.
.globl _gtk_fragment_navigate
_gtk_fragment_navigate:
    ENTER
    mov x19, x0
    LOAD x0, _gtk_uri
    mov x1, x19
    bl _engine_same_document
    cbz x0, Lgtk_fragment_not_same
    LOAD x9, _gtk_doc
    cbz x9, Lgtk_fragment_not_same
    bl _gtk_navigation_save
    bl _gtk_engine_cancel_load
    mov x0, x19
    bl _g_strdup
    mov x20, x0
    LOAD x0, _gtk_uri
    bl _g_free
    STORE x20, _gtk_uri
    LOAD x21, _gtk_nav_pending
    bl _gtk_navigation_commit
    cbz x21, Lgtk_fragment_new_entry
    bl _gtk_navigation_restore
    b Lgtk_fragment_chrome
Lgtk_fragment_new_entry:
    bl _gtk_fragment_scroll
Lgtk_fragment_chrome:
    bl _gtk_engine_committed
    mov x0, #1
    LEAVE
Lgtk_fragment_not_same:
    mov x0, #0
    LEAVE
.section __DATA,__bss
.p2align 3
.globl _gtk_base
_gtk_base: .space 8
