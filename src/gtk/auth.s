// Native HTTP authentication. Cancellation never substitutes empty credentials.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_authenticate
_gtk_authenticate:
    ENTER
    mov x19, x1
    mov x20, x3
    ldr x9, [x20, #40]
    cmp x9, #3
    b.hs Lgtk_auth_cancel
    add x9, x9, #1
    str x9, [x20, #40]
    ADDR x0, gtk_auth_title
    mov x1, #0
    mov x2, #1
    mov x3, #0
    mov x4, #0
    mov x5, #0
    bl _gtk_dialog_new_with_buttons
    mov x21, x0
    ADDR x1, gtk_auth_cancel
    mov x2, #-6
    bl _gtk_dialog_add_button
    mov x0, x21
    ADDR x1, gtk_auth_signin
    mov x2, #-5
    bl _gtk_dialog_add_button
    mov x0, x21
    bl _gtk_dialog_get_content_area
    mov x22, x0
    bl _gtk_entry_new
    mov x23, x0
    ADDR x1, gtk_auth_username
    bl _gtk_entry_set_placeholder_text
    mov x0, x22
    mov x1, x23
    mov x2, #0
    mov x3, #0
    mov x4, #4
    bl _gtk_box_pack_start
    bl _gtk_entry_new
    mov x24, x0
    mov x1, #0
    bl _gtk_entry_set_visibility
    mov x0, x24
    ADDR x1, gtk_auth_password
    bl _gtk_entry_set_placeholder_text
    mov x0, x22
    mov x1, x24
    mov x2, #0
    mov x3, #0
    mov x4, #4
    bl _gtk_box_pack_start
    mov x0, x21
    bl _gtk_widget_show_all
    mov x0, x21
    bl _gtk_dialog_run
    cmn w0, #5
    b.ne Lgtk_auth_dialog_cancel
    ldr x0, [x20, #8]
    bl _g_cancellable_is_cancelled
    cbnz x0, Lgtk_auth_dialog_cancel
    mov x0, x23
    bl _gtk_entry_get_text
    mov x25, x0
    mov x0, x24
    bl _gtk_entry_get_text
    mov x2, x0
    mov x1, x25
    mov x0, x19
    bl _soup_auth_authenticate
    mov x0, x21
    bl _gtk_widget_destroy
    mov x0, #1
    LEAVE
Lgtk_auth_dialog_cancel:
    mov x0, x21
    bl _gtk_widget_destroy
Lgtk_auth_cancel:
    mov x0, x19
    bl _soup_auth_cancel
    mov x0, #1
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_auth_title: .asciz "HTTP authentication"
gtk_auth_cancel: .asciz "Cancel"
gtk_auth_signin: .asciz "Sign in"
gtk_auth_username: .asciz "Username"
gtk_auth_password: .asciz "Password"
