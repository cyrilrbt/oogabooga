.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// doc,handle -> next connected handle in document preorder, 0 at the end.
.globl _engine_dom_next
_engine_dom_next:
    ENTER
    mov x19, x0
    bl _engine_dom_node
    cbz x0, Ldom_next_none
    ldr x9, [x0, #16]
    cbnz x9, Ldom_next_found
Ldom_next_ancestor:
    ldr x9, [x0, #40]
    cbnz x9, Ldom_next_found
    ldr x1, [x0, #8]
    cbz x1, Ldom_next_none
    mov x0, x19
    bl _engine_dom_node
    b Ldom_next_ancestor
Ldom_next_found:
    mov x0, x9
    LEAVE
Ldom_next_none:
    mov x0, #0
    LEAVE

.globl _engine_dom_get_element_by_id
_engine_dom_get_element_by_id:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x1, Ldom_id_none
    mov x21, #1
Ldom_id_next:
    mov x0, x19
    mov x1, x21
    ADDR x2, dom_id_name
    bl _engine_dom_get_attribute
    cbz x0, Ldom_id_advance
    mov x1, x20
    bl _strcmp
    cbz w0, Ldom_id_found
Ldom_id_advance:
    mov x0, x19
    mov x1, x21
    bl _engine_dom_next
    mov x21, x0
    cbnz x0, Ldom_id_next
Ldom_id_none:
    mov x0, #0
    LEAVE
Ldom_id_found:
    mov x0, x21
    LEAVE
.section __TEXT,__cstring,cstring_literals
dom_id_name: .asciz "id"
