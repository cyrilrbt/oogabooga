// Retained rendering commands. No platform objects or ownership in this ABI.
// Header: count,capacity,records*,overflow. Commands are 128 bytes:
// type,node,rect[4 doubles],flags,glyphStart,glyphLength,color,border,edges[4],aux.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _engine_display_init
_engine_display_init:
    str xzr, [x0]
    str x1, [x0, #8]
    add x2, x0, #32
    str x2, [x0, #16]
    str xzr, [x0, #24]
    ret
.globl _engine_display_new
_engine_display_new:
    ENTER
    cmp x0, #0
    b.eq Ldisplay_new_nil
    mov x9, #32768
    cmp x0, x9
    b.hi Ldisplay_new_nil
    mov x19, x0
    lsl x1, x0, #7
    add x1, x1, #32
    mov x0, #1
    bl _calloc
    cbz x0, Ldisplay_new_done
    mov x1, x19
    bl _engine_display_init
Ldisplay_new_done:
    LEAVE
Ldisplay_new_nil:
    mov x0, #0
    LEAVE
.globl _engine_display_free
_engine_display_free:
    b _free
.globl _engine_display_append
_engine_display_append:
    ldr x1, [x0]
    ldr x2, [x0, #8]
    cmp x1, x2
    b.hs Ldisplay_full
    ldr x2, [x0, #16]
    add x2, x2, x1, lsl #7
    add x1, x1, #1
    str x1, [x0]
    mov x0, x2
    ret
Ldisplay_full:
    mov x1, #1
    str x1, [x0, #24]
    mov x0, #0
    ret
// command*, dirty rect d0..d3 -> BOOL. Empty/invalid rectangles never draw.
.globl _engine_display_intersects
_engine_display_intersects:
    ldr x1, [x0]
    cbz x1, Ldisplay_no
    ldp d4, d5, [x0, #16]
    ldp d6, d7, [x0, #32]
    fcmp d2, #0.0
    b.le Ldisplay_no
    fcmp d3, #0.0
    b.le Ldisplay_no
    fcmp d6, #0.0
    b.le Ldisplay_no
    fcmp d7, #0.0
    b.le Ldisplay_no
    fadd d6, d4, d6
    fcmp d6, d0
    b.le Ldisplay_no
    fadd d7, d5, d7
    fcmp d7, d1
    b.le Ldisplay_no
    fadd d2, d0, d2
    fcmp d4, d2
    b.ge Ldisplay_no
    fadd d3, d1, d3
    fcmp d5, d3
    b.ge Ldisplay_no
    mov x0, #1
    ret
Ldisplay_no:
    mov x0, #0
    ret
// list*, point d0/d1 -> topmost hit command*, or nil. Half-open rectangles.
.globl _engine_display_hit
_engine_display_hit:
    ldr x1, [x0]
    ldr x2, [x0, #16]
Lhit_next:
    cbz x1, Lhit_nil
    sub x1, x1, #1
    add x3, x2, x1, lsl #7
    ldr x4, [x3]
    cmp x4, #4
    b.ne Lhit_next
    ldp d2, d3, [x3, #16]
    ldp d4, d5, [x3, #32]
    fcmp d0, d2
    b.lt Lhit_next
    fcmp d1, d3
    b.lt Lhit_next
    fadd d4, d2, d4
    fcmp d0, d4
    b.ge Lhit_next
    fadd d5, d3, d5
    fcmp d1, d5
    b.ge Lhit_next
    mov x0, x3
    ret
Lhit_nil:
    mov x0, #0
    ret
