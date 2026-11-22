// Native editing baselines and CSS inline offsets are expressed in CSS pixels.
.include "src/gtk/gtk.inc"
.text
// widget,used width,height -> baseline from the top of the allocated control.
.globl _gtk_control_baseline
_gtk_control_baseline:
    ENTER
    mov x19, x2
    add x2, sp, #144
    add x3, sp, #148
    add x4, sp, #152
    add x5, sp, #156
    bl _gtk_widget_get_preferred_height_and_baseline_for_width
    ldr w0, [sp, #156]
    tbnz w0, #31, Lgtk_baseline_bottom
    ldr w9, [sp, #148]
    sub x9, x19, x9
    asr x9, x9, #1
    add x0, x0, x9
    LEAVE
Lgtk_baseline_bottom:
    mov x0, x19
    LEAVE
// metadata -> Pango rise in 1/1024 pixels, including negative/sub/super offsets.
.globl _gtk_inline_rise
_gtk_inline_rise:
    ENTER
    mov x19, x0
    ldr x0, [x19, #880]
    cmn x0, #22
    b.eq Lgtk_rise_sub
    cmn x0, #23
    b.eq Lgtk_rise_super
    cmp x0, #0
    b.lt Lgtk_rise_none
    ldr x1, [x19, #112]
    cbnz x1, Lgtk_rise_length
    ldr x1, [x19, #48]
Lgtk_rise_length:
    bl _engine_box_signed_length
    lsl x0, x0, #10
    LEAVE
Lgtk_rise_sub:
    ldr x0, [x19, #48]
    lsl x0, x0, #10
    mov x9, #5
    udiv x0, x0, x9
    neg x0, x0
    LEAVE
Lgtk_rise_super:
    ldr x0, [x19, #48]
    lsl x0, x0, #10
    mov x9, #3
    udiv x0, x0, x9
    LEAVE
Lgtk_rise_none:
    mov x0, #0
    LEAVE
// layout, UTF8 byte -> line baseline in Pango units.
.globl _gtk_line_baseline
_gtk_line_baseline:
    ENTER
    mov x19, x1
    bl _pango_layout_get_iter
    mov x20, x0
Lgtk_line_baseline_next:
    mov x0, x20
    bl _pango_layout_iter_get_line_readonly
    ldr w9, [x0, #8] // PangoLayoutLine.start_index follows layout pointer
    ldr w10, [x0, #12]
    add x10, x10, x9
    cmp x19, x10
    b.ls Lgtk_line_baseline_found
    mov x0, x20
    bl _pango_layout_iter_next_line
    cbnz x0, Lgtk_line_baseline_next
Lgtk_line_baseline_found:
    mov x0, x20
    bl _pango_layout_iter_get_baseline
    mov x21, x0
    mov x0, x20
    bl _pango_layout_iter_free
    mov x0, x21
    LEAVE
