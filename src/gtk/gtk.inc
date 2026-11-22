// GTK adapter records. Engine metadata stays the shared 2048-byte ABI.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.include "src/engine/scene.inc"
// Per-flow-node native record. Pixel geometry is stored as signed integers.
.set GN_SIZE, 256
.set GN_PARENT, 0
.set GN_FIRST, 8
.set GN_NEXT, 16
.set GN_X, 24
.set GN_Y, 32
.set GN_W, 40
.set GN_H, 48
.set GN_CX, 56
.set GN_CY, 64
.set GN_CW, 72
.set GN_CH, 80
.set GN_WIDGET, 88
.set GN_IMAGE, 96
.set GN_FLAGS, 104
.set GN_PANGO, 112
.set GN_TEXT, 120
.set GN_TEXT_LEN, 128
.set GN_TEXT_START, 136
.set GN_BASELINE, 144
.set GN_CONTROL_KIND, 152
.set GN_VALUE, 160
.set GN_ANCHORS, 168
.set GN_GROUPS, 176
.set GN_LAST_GROUP, 184
.set GN_HOST, 192
.set GN_ROW_HEIGHT, 200
// Inline shaping group: linked retained Pango layouts and source maps.
.set GG_SIZE, 128
.set GG_NEXT, 0
.set GG_NODE, 8
.set GG_LAYOUT, 16
.set GG_TEXT, 24
.set GG_MAP, 32
.set GG_X, 40
.set GG_Y, 48
.set GG_W, 56
.set GG_H, 64
.set GG_LENGTH, 72
.set GG_ATTRS, 80
.set GG_ANCHORS, 88
.set GG_BASELINE, 96
// Anchor: node,UTF8 group byte,startx/y, width/height, next.
.set GA_SIZE, 64
.set GA_NODE, 0
.set GA_BYTE, 8
.set GA_NEXT, 16
.set GA_W, 24
.set GA_H, 32
// C callbacks use the native public wrapper, not the internal core convention.
.macro CALLBACK reg, name
    ADDR \reg, \name
.endm
