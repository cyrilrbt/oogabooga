// Generate only trusted numeric CSS for one widget; never feed website CSS to GTK.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_control_style
_gtk_control_style:
    ENTER
    mov x19, x1
    bl _gtk_engine_node
    mov x20, x0
    ldr x9, [x2]
    cmp x9, #NODE_INPUT
    b.ne Lgtk_control_style_begin
    ldr x0, [x20, #ATTR_TYPE]
    cbz x0, Lgtk_control_style_begin
    ADDR x1, gtk_style_check
    bl _strcasecmp
    cbz x0, Lgtk_control_style_done
    ldr x0, [x20, #ATTR_TYPE]
    ADDR x1, gtk_style_radio
    bl _strcasecmp
    cbz x0, Lgtk_control_style_done
Lgtk_control_style_begin:
    mov x0, x19
    ADDR x1, gtk_style_widget_name
    bl _gtk_widget_set_name
    mov x0, x20
    bl _gtk_engine_font
    mov x23, x0
    mov x1, x0
    mov x0, x19
    bl _gtk_widget_override_font
    mov x0, x23
    bl _pango_font_description_free
    ADDR x0, gtk_style_base
    bl _g_string_new
    mov x21, x0
    ADDR x1, gtk_style_font
    ldr x2, [x20, #48]
    ldr x3, [x20, #56]
    bl _g_string_append_printf
    mov x0, x21
    ADDR x1, gtk_style_color
    ldr x2, [x20, #32]
    tbnz x2, #63, Lgtk_control_style_black
    and x2, x2, #0xffffff
    b Lgtk_control_style_color
Lgtk_control_style_black:
    mov x2, #0
Lgtk_control_style_color:
    bl _g_string_append_printf
    mov x0, x21
    ADDR x1, gtk_style_padding
    ldr x2, [x20, #824]
    ldr x3, [x20, #816]
    ldr x4, [x20, #832]
    ldr x5, [x20, #808]
    bl _g_string_append_printf
    mov x0, x21
    ADDR x1, gtk_style_end
    bl _g_string_append
    mov x0, x19
    ADDR x1, gtk_style_provider_key
    bl _g_object_get_data
    cbnz x0, Lgtk_style_provider_ready
    bl _gtk_css_provider_new
    mov x22, x0
    mov x0, x19
    ADDR x1, gtk_style_provider_key
    mov x2, x22
    CALLBACK x3, _g_object_unref
    bl _g_object_set_data_full
    mov x0, x19
    bl _gtk_widget_get_style_context
    mov x1, x22
    mov x2, #800
    bl _gtk_style_context_add_provider
    mov x0, x22
Lgtk_style_provider_ready:
    mov x22, x0
    ldr x1, [x21]
    mov x2, #-1
    mov x3, #0
    bl _gtk_css_provider_load_from_data
    mov x0, x21
    mov x1, #1
    bl _g_string_free
Lgtk_control_style_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
gtk_style_check: .asciz "checkbox"
gtk_style_radio: .asciz "radio"
gtk_style_base: .asciz "#oogabooga-control { min-width:0;min-height:0;border:0;box-shadow:none;background-image:none;background-color:transparent;border-radius:0;outline-width:0;"
gtk_style_font: .asciz "font-size:%ldpx;font-weight:%ld;"
gtk_style_color: .asciz "color:#%06x;"
gtk_style_padding: .asciz "padding:%ldpx %ldpx %ldpx %ldpx;"
gtk_style_end: .asciz "} #oogabooga-control text {background-color:transparent;}"

gtk_style_provider_key: .asciz "oogabooga-style-provider"

gtk_style_widget_name: .asciz "oogabooga-control"
