// Release page-scoped resources, including temporary native font files, on quit.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_engine_shutdown
_gtk_engine_shutdown:
    ENTER
    bl _gtk_js_reset
    bl _gtk_engine_cancel_load
    bl _gtk_engine_clear_layout
    LOAD x19, _gtk_doc
    STORE xzr, _gtk_doc
    LOAD x0, _gtk_controls
    cbz x0, Lgtk_shutdown_images
    bl _g_hash_table_destroy
    STORE xzr, _gtk_controls
Lgtk_shutdown_images:
    LOAD x0, _gtk_images
    cbz x0, Lgtk_shutdown_fonts
    bl _g_hash_table_destroy
    STORE xzr, _gtk_images
Lgtk_shutdown_fonts:
    bl _gtk_fonts_reset
    bl _gtk_imports_reset
    mov x0, x19
    bl _engine_document_free
    LOAD x0, _gtk_base
    bl _g_free
    STORE xzr, _gtk_base
    LOAD x0, _gtk_uri
    bl _g_free
    STORE xzr, _gtk_uri
    LOAD x19, _gtk_nav_current
    STORE xzr, _gtk_nav_current
    STORE xzr, _gtk_nav_pending
    cbz x19, Lgtk_shutdown_session
Lgtk_shutdown_navigation_start:
    ldr x9, [x19, #8]
    cbz x9, Lgtk_shutdown_navigation
    mov x19, x9
    b Lgtk_shutdown_navigation_start
Lgtk_shutdown_navigation:
    cbz x19, Lgtk_shutdown_session
    ldr x20, [x19, #16]
    ldr x0, [x19]
    bl _g_free
    mov x0, x19
    bl _free
    mov x19, x20
    b Lgtk_shutdown_navigation
Lgtk_shutdown_session:
    LOAD x0, _gtk_session
    cbz x0, Lgtk_shutdown_done
    bl _g_object_unref
    STORE xzr, _gtk_session
Lgtk_shutdown_done:
    LEAVE
