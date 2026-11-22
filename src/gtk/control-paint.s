// Author styles win. Unstyled editors and buttons keep a visible native-like
// affordance while GTK's own frame/focus outline stays disabled.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_control_background
_gtk_control_background:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x20, #GN_WIDGET]
    cbz x9, Lgtk_control_bg_done
    ldr x9, [x21, #40]
    tbz x9, #63, Lgtk_control_bg_done
    ldr x9, [x20, #GN_CONTROL_KIND]
    cmp x9, #4
    b.eq Lgtk_control_bg_done
    cmp x9, #5
    b.eq Lgtk_control_bg_done
    mov x1, #0xffffff
    cmp x9, #1
    b.eq Lgtk_control_button_bg
    cmp x9, #8
    b.eq Lgtk_control_button_bg
    cmp x9, #6
    b.ne Lgtk_control_bg_color
Lgtk_control_button_bg:
    mov x1, #0xeeeeee
Lgtk_control_bg_color:
    mov x0, x19
    bl _gtk_paint_color
    ldr x9, [x20, #GN_X]
    scvtf d0, x9
    ldr x9, [x20, #GN_Y]
    scvtf d1, x9
    ldr x9, [x20, #GN_W]
    scvtf d2, x9
    ldr x9, [x20, #GN_H]
    scvtf d3, x9
    mov x0, x19
    bl _cairo_rectangle
    mov x0, x19
    bl _cairo_fill
Lgtk_control_bg_done:
    LEAVE
.globl _gtk_control_border
_gtk_control_border:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x20, #GN_WIDGET]
    cbz x9, Lgtk_control_border_done
    ldr x9, [x20, #GN_CONTROL_KIND]
    cmp x9, #4
    b.eq Lgtk_control_border_done
    cmp x9, #5
    b.eq Lgtk_control_border_done
    ldr x9, [x21, #(1024+CSS_BORDER*8)]
    ldr x10, [x21, #(1024+CSS_BORDER_RIGHT*8)]
    orr x9, x9, x10
    ldr x10, [x21, #(1024+CSS_BORDER_BOTTOM*8)]
    orr x9, x9, x10
    ldr x10, [x21, #(1024+CSS_BORDER_LEFT*8)]
    orr x9, x9, x10
    cbnz x9, Lgtk_control_border_done
    mov x0, x19
    mov x1, #0x888888
    bl _gtk_paint_color
    ldr x9, [x20, #GN_X]
    scvtf d0, x9
    ldr x9, [x20, #GN_Y]
    scvtf d1, x9
    fmov d4, #0.5
    fadd d0, d0, d4
    fadd d1, d1, d4
    ldr x9, [x20, #GN_W]
    sub x9, x9, #1
    scvtf d2, x9
    ldr x9, [x20, #GN_H]
    sub x9, x9, #1
    scvtf d3, x9
    mov x0, x19
    bl _cairo_rectangle
    mov x0, x19
    fmov d0, #1.0
    bl _cairo_set_line_width
    mov x0, x19
    bl _cairo_stroke
Lgtk_control_border_done:
    LEAVE
