// Successful/native control classes mirror the supported macOS form subset.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_control_kind
_gtk_control_kind:
    ENTER
    mov x19, x0
    cmp x1, #NODE_SELECT
    b.eq Lgtk_kind_select
    cmp x1, #NODE_TEXTAREA
    b.eq Lgtk_kind_area
    cmp x1, #NODE_BUTTON
    b.ne Lgtk_kind_input
    ldr x0, [x19, #ATTR_TYPE]
    cbz x0, Lgtk_kind_submit
    ADDR x1, gtk_kind_submit
    bl _strcasecmp
    cbz x0, Lgtk_kind_submit
    mov x0, #8
    LEAVE
Lgtk_kind_input:
    ldr x20, [x19, #ATTR_TYPE]
    cbz x20, Lgtk_kind_entry
    ADDR x21, gtk_kind_names
Lgtk_kind_find:
    ldr x1, [x21]
    cbz x1, Lgtk_kind_unsupported
    mov x0, x20
    bl _strcasecmp
    cbz x0, Lgtk_kind_found
    add x21, x21, #16
    b Lgtk_kind_find
Lgtk_kind_found:
    ldr x0, [x21, #8]
    LEAVE
Lgtk_kind_entry:
    mov x0, #0
    LEAVE
Lgtk_kind_submit:
    mov x0, #1
    LEAVE
Lgtk_kind_select:
    mov x0, #6
    LEAVE
Lgtk_kind_area:
    mov x0, #7
    LEAVE
Lgtk_kind_unsupported:
    mov x0, #3
    LEAVE
.section __DATA,__const
.p2align 3
gtk_kind_names:
.quad gtk_kind_text,0,gtk_kind_search,0,gtk_kind_email,0,gtk_kind_url,0,gtk_kind_tel,0,gtk_kind_number,0
.quad gtk_kind_submit,1,gtk_kind_hidden,2,gtk_kind_check,4,gtk_kind_radio,5,0,0
.section __TEXT,__cstring,cstring_literals
gtk_kind_text: .asciz "text"
gtk_kind_search: .asciz "search"
gtk_kind_email: .asciz "email"
gtk_kind_url: .asciz "url"
gtk_kind_tel: .asciz "tel"
gtk_kind_number: .asciz "number"
gtk_kind_submit: .asciz "submit"
gtk_kind_hidden: .asciz "hidden"
gtk_kind_check: .asciz "checkbox"
gtk_kind_radio: .asciz "radio"
