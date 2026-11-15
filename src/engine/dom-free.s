.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// doc,node pointer: release owned data, retaining a tombstone in its stable slot.
dom_release_node:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x19
    ldr x1, [x20, #48]
    bl _dom_string_free
    mov x0, x19
    ldr x1, [x20, #56]
    bl _dom_string_free
    ldr x21, [x20, #64]
Ldom_release_attribute:
    cbz x21, Ldom_release_clear
    ldr x22, [x21, #16]
    mov x0, x19
    ldr x1, [x21]
    bl _dom_string_free
    mov x0, x19
    ldr x1, [x21, #8]
    bl _dom_string_free
    mov x0, x21
    bl _free
    mov x21, x22
    b Ldom_release_attribute
Ldom_release_clear:
    mov x0, x20
    mov x1, #0
    mov x2, #DOM_NODE_SIZE
    bl _memset
    ldr x9, [x19, #16]
    sub x9, x9, #1
    str x9, [x19, #16]
    LEAVE

.globl _engine_dom_remove
_engine_dom_remove:
    ENTER
    mov x19, x0
    mov x20, x1
    cmp x1, #1
    b.ls Ldom_remove_fail
    bl _engine_dom_node
    cbz x0, Ldom_remove_fail
    mov x0, x19
    mov x1, x20
    bl _engine_dom_detach
    mov x21, x20
Ldom_remove_visit:
    mov x0, x19
    mov x1, x21
    bl _engine_dom_node
    mov x22, x0
    ldr x9, [x0, #16]
    cbz x9, Ldom_remove_leaf
    mov x21, x9
    b Ldom_remove_visit
Ldom_remove_leaf:
    ldr x23, [x22, #8]
    mov x0, x19
    mov x1, x21
    bl _engine_dom_detach
    mov x0, x19
    mov x1, x22
    bl dom_release_node
    cmp x21, x20
    b.eq Ldom_remove_done
    mov x21, x23
    b Ldom_remove_visit
Ldom_remove_done:
    mov x0, #0
    LEAVE
Ldom_remove_fail:
    mov x0, #-1
    LEAVE

.globl _engine_dom_free
_engine_dom_free:
    ENTER
    mov x19, x0
    cbz x0, Ldom_free_done
    ldr x9, [x19, #56]
    subs x9, x9, #1
    str x9, [x19, #56]
    b.ne Ldom_free_done
    mov x20, #1
Ldom_free_next:
    ldr x9, [x19, #8]
    cmp x20, x9
    b.hi Ldom_free_array
    mov x0, x19
    mov x1, x20
    bl _engine_dom_node
    cbz x0, Ldom_free_advance
    mov x1, x0
    mov x0, x19
    bl dom_release_node
Ldom_free_advance:
    add x20, x20, #1
    b Ldom_free_next
Ldom_free_array:
    ldr x0, [x19]
    bl _free
    mov x0, x19
    bl _free
Ldom_free_done:
    LEAVE

.globl _engine_dom_retain
_engine_dom_retain:
    cbz x0, Ldom_retain_done
    ldr x9, [x0, #56]
    add x9, x9, #1
    str x9, [x0, #56]
Ldom_retain_done:
    ret
