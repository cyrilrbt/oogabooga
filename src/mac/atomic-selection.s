// Selection remains a single logical range in the parent text view. Temporary
// native colors project its intersection into independently shaped inline text.
.include "src/mac/mac.inc"
.text
.p2align 2
// command -> inner manager,local start,length (x0,x1,x2), or nil.
atomic_selection_range:
    ENTER
    ldr x19, [x0, #104]
    cbz x19, Lselection_none
    ldr x20, [x0, #120]
    LOAD x0, _engine_text
    MSG layoutManager
    cmp x0, x19
    b.eq Lselection_none
    LOAD x0, _engine_text
    MSG sceneSelectedRange
    tbnz x0, #63, Lselection_none
    cbz x1, Lselection_none
    mov x21, x0
    add x22, x0, x1
    mov x0, x19
    MSG textStorage
    MSG length
    add x23, x20, x0
    cmp x21, x20
    csel x21, x20, x21, lo
    cmp x22, x23
    csel x22, x23, x22, hi
    cmp x21, x22
    b.hs Lselection_none
    mov x0, x19
    sub x1, x21, x20
    sub x2, x22, x21
    LEAVE
Lselection_none:
    mov x0, #0
    LEAVE
.globl _mac_atomic_selection_prepare
_mac_atomic_selection_prepare:
    ENTER
    bl atomic_selection_range
    cbz x0, Lselection_prepare_done
    mov x19, x0
    stp x1, x2, [sp, #144]
    CLASS NSColor
    MSG atomicSelectionBackground
    mov x3, x0
    mov x0, x19
    adrp x9, _NSBackgroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSBackgroundColorAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x4, x5, [sp, #144]
    MSG atomicAddTemporary
    CLASS NSColor
    MSG atomicSelectionForeground
    mov x3, x0
    mov x0, x19
    adrp x9, _NSForegroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSForegroundColorAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x4, x5, [sp, #144]
    MSG atomicAddTemporary
Lselection_prepare_done:
    LEAVE
.globl _mac_atomic_selection_clear
_mac_atomic_selection_clear:
    ENTER
    bl atomic_selection_range
    cbz x0, Lselection_clear_done
    mov x19, x0
    stp x1, x2, [sp, #144]
    adrp x9, _NSBackgroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSBackgroundColorAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x3, x4, [sp, #144]
    MSG atomicRemoveTemporary
    mov x0, x19
    adrp x9, _NSForegroundColorAttributeName@GOTPAGE
    ldr x9, [x9, _NSForegroundColorAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x3, x4, [sp, #144]
    MSG atomicRemoveTemporary
Lselection_clear_done:
    LEAVE
