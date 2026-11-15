.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _dom_stamp
_dom_stamp:
    ENTER
    mov x19, x2
    bl _engine_dom_node
    cbz x0, Lstamp_done
    str x19, [x0, #80]
Lstamp_done:
    LEAVE

// doc,flow snapshot -> 0/-1. Match source offsets with a bounded primitive hash
// table, not tag names or positional indices that shift after DOM insertion.
.globl _engine_dom_bind_flow
_engine_dom_bind_flow:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x0, Lbind_dom_fail
    mov x0, #8192
    mov x1, #16
    bl _calloc
    cbz x0, Lbind_dom_fail
    mov x21, x0
    mov x22, #1
Lbind_dom_node:
    mov x0, x19
    mov x1, x22
    bl _engine_dom_next
    mov x22, x0
    cbz x0, Lbind_dom_flow
    mov x1, x22
    mov x0, x19
    bl _engine_dom_node
    ldr x23, [x0, #80]
    adds x23, x23, #1
    b.eq Lbind_dom_node
    eor x24, x23, x23, lsr #13
    and x24, x24, #8191
Lbind_dom_probe:
    add x9, x21, x24, lsl #4
    ldr x10, [x9]
    cbz x10, Lbind_dom_store
    cmp x10, x23
    b.eq Lbind_dom_node
    add x24, x24, #1
    and x24, x24, #8191
    b Lbind_dom_probe
Lbind_dom_store:
    stp x23, x22, [x9]
    b Lbind_dom_node
Lbind_dom_flow:
    ldr x22, [x20, #72]
    ldr x23, [x20, #24]
    mov x24, #0
Lbind_flow_node:
    cmp x24, x23
    b.hs Lbind_dom_implied
    add x25, x22, x24, lsl #11
    str xzr, [x25, #DOM_HANDLE]
    ldr x26, [x25, #SOURCE_OFFSET]
    adds x26, x26, #1
    b.eq Lbind_flow_advance
    eor x27, x26, x26, lsr #13
    and x27, x27, #8191
Lbind_flow_probe:
    add x9, x21, x27, lsl #4
    ldr x10, [x9]
    cbz x10, Lbind_flow_advance
    cmp x10, x26
    b.eq Lbind_flow_found
    add x27, x27, #1
    and x27, x27, #8191
    b Lbind_flow_probe
Lbind_flow_found:
    ldr x10, [x9, #8]
    str x10, [x25, #DOM_HANDLE]
Lbind_flow_advance:
    add x24, x24, #1
    b Lbind_flow_node
Lbind_dom_implied:
    mov x9, #1
    str x9, [x22, #DOM_HANDLE]
    mov x24, #0
Lbind_implied_next:
    cmp x24, #2
    b.hs Lbind_dom_done
    ADDR x9, dom_implied_handles
    ldr x25, [x9, x24, lsl #3]
    mov x0, x19
    mov x1, x25
    bl _engine_dom_node
    cbz x0, Lbind_implied_advance
    ldr x0, [x0, #48]
    cbz x0, Lbind_implied_advance
    ADDR x9, dom_implied_names
    ldr x1, [x9, x24, lsl #3]
    bl _strcmp
    cbnz w0, Lbind_implied_advance
    add x9, x24, #1
    add x9, x22, x9, lsl #11
    str x25, [x9, #DOM_HANDLE]
Lbind_implied_advance:
    add x24, x24, #1
    b Lbind_implied_next
Lbind_dom_done:
    ldr x9, [x19, #24]
    str x9, [x20, #104]
    mov x0, x21
    bl _free
    mov x0, #0
    LEAVE
Lbind_dom_fail:
    mov x0, #-1
    LEAVE
.section __TEXT,__cstring,cstring_literals
dom_bind_html: .asciz "html"
dom_bind_body: .asciz "body"
.section __DATA,__const
.p2align 3
dom_implied_handles: .quad 2,4
dom_implied_names: .quad dom_bind_html,dom_bind_body
