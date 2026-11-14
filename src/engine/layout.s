// Fixed-column word wrapping and UTF-8 -> UTF-16 range mapping, in ARM64.
// Native text services supply glyph shaping/drawing; this engine supplies flow,
// line breaks, document structure, and link/style ranges.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _engine_layout
_engine_layout:
    ENTER
    mov x19, x0
    mov x26, x1
    cbz x0, Llayout_nil
    cmp x1, #8
    b.lo Llayout_nil
    cmp x1, #240
    b.hi Llayout_nil
    mov x0, #1
    mov x1, #32
    bl _calloc
    cbz x0, Llayout_nil
    mov x20, x0
    ldr x21, [x19]
    ldr x22, [x19, #8]
    mov x9, #ENGINE_MAX_INPUT
    cmp x22, x9
    b.hi Llayout_error
    lsl x0, x22, #1
    add x0, x0, #2
    bl _malloc
    str x0, [x20]
    cbz x0, Llayout_error
    mov x23, x0
    add x0, x22, #1
    lsl x0, x0, #3
    bl _malloc
    str x0, [x20, #16]
    cbz x0, Llayout_error
    str x0, [sp, #192]
    add x22, x21, x22
    mov x24, #0                      // output bytes
    mov x25, #0                      // output UTF-16 units
    mov x27, #0                      // current column
    mov x28, #0                      // input byte offset
    mov x9, #-1
    str x9, [sp, #144]               // last space output byte offset
    mov x9, #1
    str x9, [sp, #160]               // line count
Llayout_next:
    cmp x21, x22
    b.hs Llayout_done
    mov x0, x21
    mov x1, x22
    bl _engine_utf8
    cbz x0, Llayout_error
    str x0, [sp, #168]
    str x1, [sp, #176]
    ldrb w9, [x21]
    cmp w9, #10
    b.eq Llayout_newline
    cmp w9, #13
    b.eq Llayout_cr
    cmp x27, x26
    b.lo Llayout_map
    ldr x9, [sp, #144]
    cmn x9, #1
    b.eq Llayout_hard_wrap
    mov w10, #10
    strb w10, [x23, x9]
    ldr x9, [sp, #152]
    add x9, x9, #1
    sub x27, x27, x9
    b Llayout_wrapped
Llayout_hard_wrap:
    mov w9, #10
    strb w9, [x23, x24]
    add x24, x24, #1
    add x25, x25, #1
    mov x27, #0
Llayout_wrapped:
    ldr x9, [sp, #160]
    add x9, x9, #1
    str x9, [sp, #160]
    mov x9, #-1
    str x9, [sp, #144]
Llayout_map:
    ldr x10, [sp, #192]
    ldr x11, [sp, #168]
    mov x12, #0
Llayout_map_bytes:
    cmp x12, x11
    b.hs Llayout_copy
    add x9, x28, x12
    str x25, [x10, x9, lsl #3]
    add x12, x12, #1
    b Llayout_map_bytes
Llayout_copy:
    ldrb w9, [x21]
    cmp w9, #32
    b.ne Llayout_copy_bytes
    str x24, [sp, #144]
    str x27, [sp, #152]
Llayout_copy_bytes:
    mov x12, #0
Llayout_copy_loop:
    cmp x12, x11
    b.hs Llayout_advance
    ldrb w9, [x21, x12]
    strb w9, [x23, x24]
    add x24, x24, #1
    add x12, x12, #1
    b Llayout_copy_loop
Llayout_advance:
    add x21, x21, x11
    add x28, x28, x11
    ldr x9, [sp, #176]
    add x25, x25, x9
    add x27, x27, #1
    b Llayout_next
Llayout_cr:
    add x9, x21, #1
    cmp x9, x22
    b.hs Llayout_newline
    ldrb w9, [x9]
    cmp w9, #10
    b.ne Llayout_newline
    mov x9, #2
    str x9, [sp, #168]
Llayout_newline:
    ldr x10, [sp, #192]
    str x25, [x10, x28, lsl #3]
    ldr x11, [sp, #168]
    cmp x11, #2
    b.ne Llayout_newline_copy
    add x9, x28, #1
    str x25, [x10, x9, lsl #3]
Llayout_newline_copy:
    mov w9, #10
    strb w9, [x23, x24]
    add x24, x24, #1
    add x25, x25, #1
    add x21, x21, x11
    add x28, x28, x11
    mov x27, #0
    ldr x9, [sp, #160]
    add x9, x9, #1
    str x9, [sp, #160]
    mov x9, #-1
    str x9, [sp, #144]
    b Llayout_next
Llayout_done:
    ldr x10, [sp, #192]
    str x25, [x10, x28, lsl #3]
    strb wzr, [x23, x24]
    str x24, [x20, #8]
    ldr x9, [sp, #160]
    str x9, [x20, #24]
    mov x0, x20
    LEAVE
Llayout_error:
    mov x0, x20
    bl _engine_layout_free
Llayout_nil:
    mov x0, #0
    LEAVE

.globl _engine_layout_free
_engine_layout_free:
    cbz x0, Llayout_free_return
    ENTER
    mov x19, x0
    ldr x0, [x19]
    bl _free
    ldr x0, [x19, #16]
    bl _free
    mov x0, x19
    bl _free
    LEAVE
Llayout_free_return:
    ret

// Validate one Unicode scalar. Return byte length and UTF-16 length, or zero.
.globl _engine_utf8
_engine_utf8:
    ldrb w2, [x0]
    cmp w2, #128
    b.hs Lutf_multibyte
    mov x0, #1
    mov x1, #1
    ret
Lutf_multibyte:
    cmp w2, #0xc2
    b.lo Lutf_bad
    cmp w2, #0xdf
    b.ls Lutf_two
    cmp w2, #0xef
    b.ls Lutf_three
    cmp w2, #0xf4
    b.hi Lutf_bad
    mov x3, #4
    and w4, w2, #7
    b Lutf_continuations
Lutf_two:
    mov x3, #2
    and w4, w2, #0x1f
    b Lutf_continuations
Lutf_three:
    mov x3, #3
    and w4, w2, #0xf
Lutf_continuations:
    sub x5, x1, x0
    cmp x5, x3
    b.lo Lutf_bad
    mov x5, #1
Lutf_cont_loop:
    cmp x5, x3
    b.hs Lutf_scalar
    ldrb w6, [x0, x5]
    and w7, w6, #0xc0
    cmp w7, #0x80
    b.ne Lutf_bad
    and w6, w6, #0x3f
    lsl w4, w4, #6
    orr w4, w4, w6
    add x5, x5, #1
    b Lutf_cont_loop
Lutf_scalar:
    cmp x3, #3
    b.lo Lutf_valid
    cmp w4, #0x800
    b.lo Lutf_bad
    mov w5, #0xd800
    cmp w4, w5
    b.lo Lutf_check_four
    mov w5, #0xdfff
    cmp w4, w5
    b.ls Lutf_bad
Lutf_check_four:
    cmp x3, #4
    b.ne Lutf_valid
    mov w5, #0x10000
    cmp w4, w5
    b.lo Lutf_bad
    mov w5, #0xffff
    movk w5, #0x10, lsl #16
    cmp w4, w5
    b.hi Lutf_bad
Lutf_valid:
    mov x0, x3
    mov x1, #1
    cmp x3, #4
    b.ne Lutf_return
    mov x1, #2
Lutf_return:
    ret
Lutf_bad:
    mov x0, #0
    mov x1, #0
    ret
