// Bounded document navigation entries; SQLite remains the persistent visit log.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_navigation_commit
_gtk_navigation_commit:
    ENTER
    LOAD x19, _gtk_nav_pending
    cbz x19, Lgtk_navigation_append
    STORE x19, _gtk_nav_current
    STORE xzr, _gtk_nav_pending
    b Lgtk_navigation_done
Lgtk_navigation_append:
    LOAD x19, _gtk_nav_current
    cbz x19, Lgtk_navigation_allocate
    ldr x20, [x19, #16]
    str xzr, [x19, #16]
Lgtk_navigation_prune:
    cbz x20, Lgtk_navigation_allocate
    ldr x21, [x20, #16]
    ldr x0, [x20]
    bl _g_free
    mov x0, x20
    bl _free
    mov x20, x21
    b Lgtk_navigation_prune
Lgtk_navigation_allocate:
    mov x0, #1
    mov x1, #40
    bl _calloc
    mov x20, x0
    LOAD x0, _gtk_uri
    bl _g_strdup
    str x0, [x20]
    str x19, [x20, #8]
    cbz x19, Lgtk_navigation_store
    str x20, [x19, #16]
Lgtk_navigation_store:
    STORE x20, _gtk_nav_current
    // Retain at most 512 traversable entries.
    mov x21, #1
    mov x22, x20
Lgtk_navigation_bound:
    ldr x9, [x22, #8]
    cbz x9, Lgtk_navigation_done
    add x21, x21, #1
    cmp x21, #512
    b.hs Lgtk_navigation_detach
    mov x22, x9
    b Lgtk_navigation_bound
Lgtk_navigation_detach:
    str xzr, [x22, #8]
    mov x20, x9
Lgtk_navigation_free_old:
    cbz x20, Lgtk_navigation_done
    ldr x21, [x20, #8]
    ldr x0, [x20]
    bl _g_free
    mov x0, x20
    bl _free
    mov x20, x21
    b Lgtk_navigation_free_old
Lgtk_navigation_done:
    LEAVE
.globl _gtk_engine_back
_gtk_engine_back:
    LOAD x9, _gtk_nav_current
    cbz x9, Lgtk_navigation_no_target
    ldr x9, [x9, #8]
    b gtk_navigation_target
.globl _gtk_engine_forward
_gtk_engine_forward:
    LOAD x9, _gtk_nav_current
    cbz x9, Lgtk_navigation_no_target
    ldr x9, [x9, #16]
    b gtk_navigation_target
.globl _gtk_engine_reload
_gtk_engine_reload:
    LOAD x9, _gtk_nav_current
 gtk_navigation_target:
    cbz x9, Lgtk_navigation_no_target
    STORE x9, _gtk_nav_pending
    ENTER
    mov x19, x9
    bl _gtk_navigation_save
    mov x0, x19
    STORE x0, _gtk_nav_pending
    ldr x0, [x19]
    bl _gtk_fragment_navigate
    cbnz x0, Lgtk_target_loaded
    ldr x0, [x19]
    bl _gtk_engine_load_target
Lgtk_target_loaded:
    LEAVE
Lgtk_navigation_no_target:
    ret
.section __DATA,__bss
.p2align 3
.globl _gtk_nav_current,_gtk_nav_pending
_gtk_nav_current: .space 8
_gtk_nav_pending: .space 8

.text
.globl _gtk_navigation_save
_gtk_navigation_save:
    ENTER
    LOAD x19, _gtk_nav_current
    cbz x19, Lgtk_nav_saved
    LOAD x0, _gtk_view
    cbz x0, Lgtk_nav_saved
    bl _gtk_scrolled_window_get_hadjustment
    bl _gtk_adjustment_get_value
    str d0, [x19, #24]
    LOAD x0, _gtk_view
    bl _gtk_scrolled_window_get_vadjustment
    bl _gtk_adjustment_get_value
    str d0, [x19, #32]
Lgtk_nav_saved:
    LEAVE
.globl _gtk_navigation_restore
_gtk_navigation_restore:
    ENTER
    LOAD x19, _gtk_nav_current
    cbz x19, Lgtk_nav_restored
    LOAD x0, _gtk_view
    cbz x0, Lgtk_nav_restored
    bl _gtk_scrolled_window_get_hadjustment
    ldr d0, [x19, #24]
    bl _gtk_adjustment_set_value
    LOAD x0, _gtk_view
    bl _gtk_scrolled_window_get_vadjustment
    ldr d0, [x19, #32]
    bl _gtk_adjustment_set_value
Lgtk_nav_restored:
    LEAVE
