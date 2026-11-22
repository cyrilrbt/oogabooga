// Slice decoration: horizontal borders belong to the beginning/end fragment;
// top and bottom borders follow each line. Native shaping supplies rectangles.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
// meta, first BOOL, last BOOL, output four widths L/T/R/B.
.globl _engine_inline_edges
_engine_inline_edges:
    ldr x9, [x0, #BOX_BORDER_LEFT]
    cmp x1, #0
    csel x9, x9, xzr, ne
    str x9, [x3]
    ldr x9, [x0, #BOX_BORDER_TOP]
    str x9, [x3, #8]
    ldr x9, [x0, #BOX_BORDER_RIGHT]
    cmp x2, #0
    csel x9, x9, xzr, ne
    str x9, [x3, #16]
    ldr x9, [x0, #BOX_BORDER_BOTTOM]
    str x9, [x3, #24]
    ret
