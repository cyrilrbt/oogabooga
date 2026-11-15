// Native fields retain their editor and focus ring; buttons retain tracking.
// Website-styled buttons replace the native bezel with their CSS layer.
// Uniform borders/radii are shared with the visible default input outline.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// metadata,control,kind (text=0/3, submit=1, inert button=8).
.globl _mac_input_border
_mac_input_border:
    cmp x2, #1
    b.eq Linput_border_button
    cmp x2, #8
    b.eq Linput_border_button
    cbz x2, Linput_border_text
    cmp x2, #3
    b.ne Linput_border_return
Linput_border_button:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _mac_button_style
    mov x23, #1
    mov x22, #0
    cbz x0, Linput_border_layer
    b Linput_border_authored
Linput_border_text:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x22, #1
    mov x23, #0
Linput_border_authored:
    ldr x9, [x19, #(1024+CSS_BORDER*8)]
    ldr x10, [x19, #(1024+CSS_BORDER_RIGHT*8)]
    orr x9, x9, x10
    ldr x10, [x19, #(1024+CSS_BORDER_BOTTOM*8)]
    orr x9, x9, x10
    ldr x10, [x19, #(1024+CSS_BORDER_LEFT*8)]
    orr x9, x9, x10
    cbz x9, Linput_border_width_ready
    ldr x22, [x19, #BOX_BORDER_LEFT]
    ldr x9, [x19, #BOX_BORDER_RIGHT]
    cmp x22, x9
    csel x22, x9, x22, lt
    ldr x9, [x19, #BOX_BORDER_TOP]
    cmp x22, x9
    csel x22, x9, x22, lt
    ldr x9, [x19, #BOX_BORDER_BOTTOM]
    cmp x22, x9
    csel x22, x9, x22, lt
Linput_border_width_ready:
    cbnz x23, Linput_border_layer
    mov x0, x20
    cmp x22, #0
    cset x2, ne
    MSG inputSetBezeled
    cbnz x22, Linput_border_native_ready
    mov x0, x20
    mov x2, #0
    MSG setBordered
Linput_border_native_ready:
Linput_border_layer:
    mov x0, x20
    mov x2, #1
    MSG setWantsLayer
    mov x0, x20
    MSG layer
    mov x21, x0
    cbz x23, Linput_border_background_done
    ldr x0, [x19, #40]
    bl _mac_css_color
    MSG CGColor
    mov x2, x0
    mov x0, x21
    MSG setBackgroundCG
Linput_border_background_done:
    mov x0, x21
    scvtf d0, x22
    MSG setBorderWidth
    mov x0, #0x8a8a
    movk x0, #0x8a, lsl #16
    ldr x9, [x19, #(1024+CSS_BORDER_COLOR*8)]
    cbz x9, Linput_border_color
    ldr x0, [x19, #200]
Linput_border_color:
    bl _mac_css_color
    MSG CGColor
    mov x2, x0
    mov x0, x21
    MSG setBorderCG
    mov x9, #4
    cmp x23, #0
    csel x9, x9, xzr, eq
    scvtf d0, x9
    ldr x9, [x19, #(1024+CSS_RADIUS*8)]
    cbz x9, Linput_border_radius
    mov x0, x20
    MSG frame
    fcvtzs x9, d2
    fcvtzs x10, d3
    cmp x9, x10
    csel x23, x9, x10, lt
    mov x1, x23
    ldr x0, [x19, #224]
    bl _engine_box_length
    lsr x9, x23, #1
    cmp x0, x9
    csel x0, x9, x0, hi
    scvtf d0, x0
Linput_border_radius:
    mov x0, x21
    MSG setCornerRadius
    LEAVE
Linput_border_return:
    ret
