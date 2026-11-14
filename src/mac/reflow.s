// Window-driven reflow preserves native controls and scroll position.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_engine_measure
_mac_engine_measure:
    ENTER
    LOAD x0, _engine_scroll
    MSG contentSize
    fcvtzs x9, d0
    sub x9, x9, #40
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
