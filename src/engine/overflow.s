.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// start,end,declaration,important. Expand to actual longhands while preserving
// declaration order and !important; a parallel shorthand value cannot do that.
.globl _css_overflow_declarations
_css_overflow_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _css_skip
    mov x19, x0
    mov x23, x0
Loverflow_token:
    cmp x23, x20
    b.hs Loverflow_token_end
    ldrb w9, [x23]
    cmp w9, #32
    b.ls Loverflow_token_end
    cmp w9, #47
    b.eq Loverflow_token_end
    add x23, x23, #1
    b Loverflow_token
Loverflow_token_end:
    mov x0, #CSS_OVERFLOW_X
    mov x1, x19
    mov x2, x23
    bl _css_value
    cbz x1, Loverflow_decl_done
    mov x24, x0
    mov x0, x23
    mov x1, x20
    bl _css_skip
    cmp x0, x20
    b.hs Loverflow_one
    cmp x24, #0
    b.lt Loverflow_decl_done
    mov x1, x0
    mov x0, #CSS_OVERFLOW_Y
    mov x2, x20
    bl _css_value
    cbz x1, Loverflow_decl_done
    cmp x0, #0
    b.lt Loverflow_decl_done
    mov x25, x0
    b Loverflow_store
Loverflow_one:
    mov x25, x24
Loverflow_store:
    mov x0, x21
    mov x1, #CSS_OVERFLOW_X
    mov x2, x22
    mov x3, x24
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_OVERFLOW_Y
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
Loverflow_decl_done:
    LEAVE

// visible/clip compute to auto/hidden when paired with a scrolling axis.
.globl _engine_overflow_compute
_engine_overflow_compute:
    ldr x1, [x0, #(1840+(CSS_OVERFLOW_X-48)*8)]
    ldr x2, [x0, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    cmp x1, #1
    b.eq Loverflow_y_compute
    cmp x1, #2
    b.ne Loverflow_x_check
Loverflow_y_compute:
    cbnz x2, Loverflow_y_clip
    mov x2, #2
    b Loverflow_x_check
Loverflow_y_clip:
    cmp x2, #3
    b.ne Loverflow_x_check
    mov x2, #1
Loverflow_x_check:
    cmp x2, #1
    b.eq Loverflow_x_compute
    cmp x2, #2
    b.ne Loverflow_compute_store
Loverflow_x_compute:
    cbnz x1, Loverflow_x_clip
    mov x1, #2
    b Loverflow_compute_store
Loverflow_x_clip:
    cmp x1, #3
    b.ne Loverflow_compute_store
    mov x1, #1
Loverflow_compute_store:
    str x1, [x0, #(1840+(CSS_OVERFLOW_X-48)*8)]
    str x2, [x0, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    ret
