// Window-driven reflow preserves native controls and scroll position.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_engine_measure
_mac_engine_measure:
    ENTER
    mov x19, #20
    LOAD x9, _engine_render_document
    cbz x9, Lmeasure_inset_ready
    ldr x9, [x9, #72]
    add x9, x9, #4096              // implied body node 2
    ldr x10, [x9, #1088]
    ldr x11, [x9, #1096]
    orr x10, x10, x11
    ldr x11, [x9, #1120]
    orr x10, x10, x11
    ldr x11, [x9, #1128]
    orr x10, x10, x11
    cmp x10, #0
    csel x19, xzr, x19, ne
Lmeasure_inset_ready:
    STORE x19, _engine_inset
    LOAD x0, _engine_scroll
    MSG contentSize
    LOAD x10, _engine_render_document
    cbz x10, Lmeasure_height_ready
    ldr x10, [x10, #72]
    fcvtzs x11, d1
    sub x11, x11, x19, lsl #1
    cmp x11, #0
    csel x11, xzr, x11, lt
    str x11, [x10, #1776]          // initial containing block content height
Lmeasure_height_ready:
    fcvtzs x9, d0
    sub x9, x9, x19, lsl #1
    mov x10, #80
    cmp x9, x10
    csel x9, x10, x9, lt
    STORE x9, _engine_viewport
    LEAVE
.globl _mac_engine_resize
_mac_engine_resize:
    ENTER
    LOAD x9, _mac_engine_enabled
    cbz x9, Lresize_done
    LOAD x9, _engine_reflowing
    cbnz x9, Lresize_done
    bl _mac_engine_refresh
Lresize_done:
    LEAVE
.globl _mac_engine_refresh
_mac_engine_refresh:
    ENTER
    LOAD x19, _engine_document
    cbz x19, Lrefresh_done
    ldr x9, [x19, #96]
    cbz x9, Lrefresh_layout
    ldr x9, [x9, #24]
    ldr x10, [x19, #104]
    cmp x9, x10
    b.eq Lrefresh_layout
    mov x0, x19
    bl _mac_dom_rebuild
    b Lrefresh_done
Lrefresh_layout:
    mov x9, #1
    STORE x9, _engine_reflowing
    mov x0, x19
    LOAD x1, _engine_url
    bl _mac_engine_display
    STORE xzr, _engine_reflowing
Lrefresh_done:
    LEAVE
.section __DATA,__data
.p2align 3
.globl _engine_viewport, _engine_reflowing
_engine_viewport: .quad 860
_engine_reflowing: .quad 0

.globl _engine_inset
_engine_inset: .quad 20
