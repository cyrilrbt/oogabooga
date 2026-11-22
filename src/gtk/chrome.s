// Shared browser chrome binding. NULL bindings permit standalone engine tests.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_engine_bind
_gtk_engine_bind:
    STORE x0, gtk_browser_window
    STORE x1, gtk_browser_address
    STORE x2, gtk_browser_status
    STORE x3, gtk_browser_database
    STORE x4, gtk_browser_title
    STORE x5, gtk_browser_buttons
    ret
.globl _gtk_engine_database
_gtk_engine_database:
    LOAD x0, gtk_browser_database
    ret
.globl _gtk_engine_status
_gtk_engine_status:
    mov x1, x0
    LOAD x0, gtk_browser_status
    cbz x0, Lgtk_status_done
    b _gtk_label_set_text
Lgtk_status_done:
    ret
.globl _gtk_engine_committed
_gtk_engine_committed:
    ENTER
    bl _gtk_engine_sync_chrome
    LOAD x19, _gtk_doc
    LOAD x0, gtk_browser_database
    cbz x0, Lgtk_commit_ready
    LOAD x1, _gtk_uri
    ldr x2, [x19, #32]
    bl _history_add
    cbnz x0, Lgtk_commit_history_error
    LOAD x0, gtk_browser_database
    bl _sqlite3_last_insert_rowid
    STORE x0, gtk_browser_visit
Lgtk_commit_ready:
    ADDR x0, gtk_engine_ready
    bl _gtk_engine_status
    LEAVE
Lgtk_commit_history_error:
    ADDR x0, gtk_engine_history_error
    bl _gtk_engine_status
    LEAVE
.globl _gtk_engine_sync_chrome
_gtk_engine_sync_chrome:
    ENTER
    LOAD x19, _gtk_doc
    LOAD x0, gtk_browser_window
    cbz x0, Lgtk_commit_address
    ldr x0, [x19, #32]
    ADDR x1, _ooga_engine_title_suffix
    mov x2, #0
    bl _g_strconcat
    mov x20, x0
    mov x1, x0
    LOAD x0, gtk_browser_window
    bl _gtk_window_set_title
    mov x0, x20
    bl _g_free
Lgtk_commit_address:
    LOAD x0, gtk_browser_address
    cbz x0, Lgtk_commit_history
    LOAD x1, _gtk_uri
    bl _gtk_entry_set_text
Lgtk_commit_history:
    LOAD x19, gtk_browser_buttons
    cbz x19, Lgtk_sync_finished
    LOAD x20, _gtk_nav_current
    mov x1, #0
    cbz x20, Lgtk_sync_back
    ldr x1, [x20, #8]
    cmp x1, #0
    cset x1, ne
Lgtk_sync_back:
    ldr x0, [x19]
    bl _gtk_widget_set_sensitive
    mov x1, #0
    cbz x20, Lgtk_sync_forward
    ldr x1, [x20, #16]
    cmp x1, #0
    cset x1, ne
Lgtk_sync_forward:
    ldr x0, [x19, #8]
    bl _gtk_widget_set_sensitive
Lgtk_sync_finished:
    LEAVE
.globl _gtk_engine_dom_changed
_gtk_engine_dom_changed:
    ENTER
    bl _gtk_engine_sync_chrome
    LOAD x0, gtk_browser_database
    cbz x0, Lgtk_dom_title_done
    LOAD x1, gtk_browser_visit
    cbz x1, Lgtk_dom_title_done
    LOAD x9, _gtk_doc
    ldr x2, [x9, #32]
    bl _history_update_title
Lgtk_dom_title_done:
    LEAVE
.section __DATA,__bss
.p2align 3
gtk_browser_window: .space 8
gtk_browser_address: .space 8
gtk_browser_status: .space 8
gtk_browser_database: .space 8
gtk_browser_title: .space 8
gtk_browser_buttons: .space 8
gtk_browser_visit: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_engine_ready: .asciz "Assembly engine: ready. JavaScript is not supported. Ctrl+E switches engines."

gtk_engine_history_error: .asciz "Assembly engine: page ready, but history could not be saved."
