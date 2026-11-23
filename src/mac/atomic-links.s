// A private shaping store has no NSTextView to supply linkTextAttributes.
// Remove redundant native link styling before its first layout. Logical link
// attributes remain in the main source storage; scene compilation resolves URLs
// there and obtains glyph geometry from the independent shaping context.
.include "src/mac/mac.inc"
.text
.globl _mac_atomic_strip_link_attributes
_mac_atomic_strip_link_attributes:
    ENTER
    mov x19, x0
    MSG length
    mov x4, x0
    mov x3, #0
    mov x0, x19
    adrp x9, _NSLinkAttributeName@GOTPAGE
    ldr x9, [x9, _NSLinkAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    MSG removeAttribute
    mov x0, x19
    LEAVE
