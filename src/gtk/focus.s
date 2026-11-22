// Reflow must not turn a focused editor into a new focus/select-all operation.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_focus_save
_gtk_focus_save:
    ENTER
    LOAD x0, gtk_pending_focus
    cbnz x0, Lgtk_focus_saved
    LOAD x0, _gtk_view
    cbz x0, Lgtk_focus_saved
    bl _gtk_widget_get_toplevel
    bl _gtk_window_get_focus
    cbz x0, Lgtk_focus_saved
    bl _g_object_ref
    STORE x0, gtk_pending_focus
    mov x19, x0
    STORE xzr, gtk_pending_entry
    bl _gtk_entry_get_type
    mov x1, x0
    mov x0, x19
    bl _g_type_check_instance_is_a
    cbz x0, Lgtk_focus_saved
    mov x9, #1
    STORE x9, gtk_pending_entry
    mov x0, x19
    bl _gtk_editable_get_position
    STORE x0, gtk_pending_position
    mov x0, x19
    ADDR x1, gtk_pending_start
    ADDR x2, gtk_pending_end
    bl _gtk_editable_get_selection_bounds
    STORE x0, gtk_pending_range
Lgtk_focus_saved:
    LEAVE
.globl _gtk_focus_restore
_gtk_focus_restore:
    ENTER
    LOAD x19, gtk_pending_focus
    cbz x19, Lgtk_focus_restored
    STORE xzr, gtk_pending_focus
    mov x0, x19
    bl _gtk_widget_get_parent
    cbz x0, Lgtk_focus_release
    mov x0, x19
    bl _gtk_widget_get_mapped
    cbz x0, Lgtk_focus_release
    mov x0, x19
    bl _gtk_widget_grab_focus
    LOAD x9, gtk_pending_entry
    cbz x9, Lgtk_focus_release
    LOAD x9, gtk_pending_range
    cbz x9, Lgtk_focus_cursor
    ADDR x9, gtk_pending_start
    ldr w1, [x9]
    ADDR x9, gtk_pending_end
    ldr w2, [x9]
    LOAD x9, gtk_pending_position
    cmp x9, x1
    b.ne Lgtk_focus_select
    mov x9, x1
    mov x1, x2
    mov x2, x9
Lgtk_focus_select:
    mov x0, x19
    bl _gtk_editable_select_region
    b Lgtk_focus_release
Lgtk_focus_cursor:
    mov x0, x19
    LOAD x1, gtk_pending_position
    bl _gtk_editable_set_position
Lgtk_focus_release:
    mov x0, x19
    bl _g_object_unref
Lgtk_focus_restored:
    LEAVE
.section __DATA,__bss
.p2align 3
gtk_pending_focus: .space 8
gtk_pending_entry: .space 8
gtk_pending_position: .space 8
gtk_pending_range: .space 8
gtk_pending_start: .space 8
gtk_pending_end: .space 8
