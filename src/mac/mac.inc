// Darwin ARM64 / Objective-C ABI helpers. Every function reserves a 224-byte
// frame: outgoing variadic arguments [0,48), saved registers [48,144), locals [144,224).
.macro ENTER
    sub sp, sp, #224
    stp x29, x30, [sp, #128]
    add x29, sp, #128
    stp x19, x20, [sp, #48]
    stp x21, x22, [sp, #64]
    stp x23, x24, [sp, #80]
    stp x25, x26, [sp, #96]
    stp x27, x28, [sp, #112]
.endm
.macro LEAVE
    ldp x19, x20, [sp, #48]
    ldp x21, x22, [sp, #64]
    ldp x23, x24, [sp, #80]
    ldp x25, x26, [sp, #96]
    ldp x27, x28, [sp, #112]
    ldp x29, x30, [sp, #128]
    add sp, sp, #224
    ret
.endm
.macro ADDR reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
.macro LOAD reg, label
    adrp \reg, \label@PAGE
    ldr \reg, [\reg, \label@PAGEOFF]
.endm
.macro STORE reg, label
    adrp x9, \label@PAGE
    str \reg, [x9, \label@PAGEOFF]
.endm
.macro SELECT reg, name
    LOAD \reg, _sel_\name
.endm
.macro MSG name
    SELECT x1, \name
    bl _objc_msgSend
.endm
.macro CLASS name
    ADDR x0, _class_\name
    bl _objc_getClass
.endm
.macro STR label
    ADDR x0, \label
    bl _mac_string
.endm
.macro NUM reg, value
    mov x9, #\value
    scvtf \reg, x9
.endm
.macro RECT x, y, w, h
    NUM d0, \x
    NUM d1, \y
    NUM d2, \w
    NUM d3, \h
.endm
