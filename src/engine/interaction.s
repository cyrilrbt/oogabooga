// Live state is separate from HTML default attributes. Bits: hover, active,
// focus, focus-visible, checked override, checked value. Main-thread confined.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/dom.inc"
.text
// document,node,mask,value -> changed. Hover/active also apply to ancestors.
.globl _engine_interaction_set
_engine_interaction_set:
    ENTER
    mov x19, x0
    mov x20, x1
    and x21, x2, #63
    and x22, x3, x21
    cbz x19, Linteraction_invalid
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Linteraction_invalid
    ldr x23, [x19, #72]
    mov x24, #0
    mov x25, #0
Linteraction_clear:
    ldr x9, [x19, #24]
    cmp x24, x9
    b.hs Linteraction_apply
    add x10, x23, x24, lsl #11
    ldr x9, [x10, #744]
    and x11, x21, #15
    bic x11, x9, x11
    str x11, [x10, #752]          // scratch candidate, compare after propagation
    add x24, x24, #1
    b Linteraction_clear
Linteraction_apply:
    add x10, x23, x20, lsl #11
    ldr x9, [x10, #752]
    bic x9, x9, x21
    orr x9, x9, x22
    str x9, [x10, #752]
    and x22, x22, #3
    cbz x22, Linteraction_compare_begin
    cbz x20, Linteraction_compare_begin
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x20, [x9, #8]
    b Linteraction_apply
Linteraction_compare_begin:
    mov x24, #0
Linteraction_compare:
    ldr x9, [x19, #24]
    cmp x24, x9
    b.hs Linteraction_done
    add x10, x23, x24, lsl #11
    ldr x9, [x10, #744]
    ldr x11, [x10, #752]
    cmp x9, x11
    cset x12, ne
    orr x25, x25, x12
    str x11, [x10, #744]
    add x24, x24, #1
    b Linteraction_compare
Linteraction_done:
    mov x0, x25
    LEAVE
Linteraction_invalid:
    mov x0, #0
    LEAVE

// old/new flow snapshots of the same persistent DOM -> transfer live state by
// stable handle. Render indices may change after an insertion/removal.
.globl _engine_interaction_transfer
_engine_interaction_transfer:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x9, [x19, #96]
    ldr x10, [x20, #96]
    cmp x9, x10
    b.ne Linteraction_transfer_done
    cbz x9, Linteraction_transfer_done
    mov x0, #(DOM_MAX_NODES+1)
    mov x1, #8
    bl _calloc
    cbz x0, Linteraction_transfer_done
    mov x21, x0
    ldr x22, [x19, #72]
    mov x23, #1
Linteraction_index_old:
    ldr x9, [x19, #24]
    cmp x23, x9
    b.hs Linteraction_copy_begin
    add x9, x22, x23, lsl #11
    ldr x10, [x9, #DOM_HANDLE]
    cbz x10, Linteraction_index_next
    cmp x10, #DOM_MAX_NODES
    b.hi Linteraction_index_next
    ldr x11, [x9, #744]
    str x11, [x21, x10, lsl #3]
Linteraction_index_next:
    add x23, x23, #1
    b Linteraction_index_old
Linteraction_copy_begin:
    ldr x22, [x20, #72]
    mov x23, #1
Linteraction_copy_next:
    ldr x9, [x20, #24]
    cmp x23, x9
    b.hs Linteraction_copy_done
    add x9, x22, x23, lsl #11
    ldr x10, [x9, #DOM_HANDLE]
    cbz x10, Linteraction_copy_advance
    cmp x10, #DOM_MAX_NODES
    b.hi Linteraction_copy_advance
    ldr x11, [x21, x10, lsl #3]
    str x11, [x9, #744]
Linteraction_copy_advance:
    add x23, x23, #1
    b Linteraction_copy_next
Linteraction_copy_done:
    mov x0, x21
    bl _free
Linteraction_transfer_done:
    LEAVE
