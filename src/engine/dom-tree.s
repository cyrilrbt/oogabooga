.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
.globl _engine_dom_new
_engine_dom_new:
    ENTER
    mov x0, #1
    mov x1, #64
    bl _calloc
    cbz x0, Ldom_new_done
    mov x19, x0
    mov x0, #DOM_MAX_NODES
    mov x1, #DOM_NODE_SIZE
    bl _calloc
    cbz x0, Ldom_new_fail
    str x0, [x19]
    mov x9, #DOM_DOCUMENT
    str x9, [x0]
    mov x9, #1
    str x9, [x0, #72]
    str x9, [x19, #8]
    str x9, [x19, #16]
    str x9, [x19, #40]
    str x9, [x19, #56]
    mov x0, x19
Ldom_new_done:
    LEAVE
Ldom_new_fail:
    mov x0, x19
    bl _free
    mov x0, #0
    LEAVE

// doc, handle -> borrowed node pointer, nil for null/tombstone/out-of-range.
.globl _engine_dom_node
_engine_dom_node:
    cbz x0, Ldom_node_nil
    cbz x1, Ldom_node_nil
    ldr x9, [x0, #8]
    cmp x1, x9
    b.hi Ldom_node_nil
    ldr x9, [x0]
    sub x10, x1, #1
    mov x11, #DOM_NODE_SIZE
    madd x0, x10, x11, x9
    ldr x9, [x0]
    cbz x9, Ldom_node_nil
    ret
Ldom_node_nil:
    mov x0, #0
    ret

// doc, type, owned name*, owned value* -> handle (caller retains on failure).
.globl _dom_allocate
_dom_allocate:
    ldr x9, [x0, #8]
    cmp x9, #DOM_MAX_NODES
    b.hs Ldom_node_nil
    ldr x10, [x0]
    mov x11, #DOM_NODE_SIZE
    madd x10, x9, x11, x10
    str x1, [x10]
    stp x2, x3, [x10, #48]
    mov x11, #1
    str x11, [x10, #72]
    mov x11, #-1
    str x11, [x10, #80]
    add x9, x9, #1
    str x9, [x0, #8]
    ldr x10, [x0, #16]
    add x10, x10, #1
    str x10, [x0, #16]
    ldr x10, [x0, #24]
    add x10, x10, #1
    str x10, [x0, #24]
    mov x0, x9
    ret

// doc, node handle: recompute cached subtree heights up to the root.
.globl _dom_heights
_dom_heights:
    ENTER
    mov x19, x0
    mov x20, x1
Ldom_height_node:
    cbz x20, Ldom_height_done
    mov x0, x19
    mov x1, x20
    bl _engine_dom_node
    cbz x0, Ldom_height_done
    mov x21, x0
    ldr x22, [x0, #16]
    mov x23, #1
Ldom_height_child:
    cbz x22, Ldom_height_store
    mov x0, x19
    mov x1, x22
    bl _engine_dom_node
    ldr x9, [x0, #72]
    add x9, x9, #1
    cmp x23, x9
    csel x23, x9, x23, lo
    ldr x22, [x0, #40]
    b Ldom_height_child
Ldom_height_store:
    ldr x9, [x21, #72]
    cmp x9, x23
    b.eq Ldom_height_done
    str x23, [x21, #72]
    ldr x20, [x21, #8]
    b Ldom_height_node
Ldom_height_done:
    LEAVE

.globl _engine_dom_detach
_engine_dom_detach:
    ENTER
    mov x19, x0
    mov x20, x1
    cmp x1, #1
    b.ls Ldom_detach_fail
    bl _engine_dom_node
    cbz x0, Ldom_detach_fail
    mov x21, x0
    ldr x22, [x21, #8]
    cbz x22, Ldom_detach_done
    ldr x23, [x21, #32]
    ldr x24, [x21, #40]
    mov x0, x19
    mov x1, x22
    bl _engine_dom_node
    mov x25, x0
    cbnz x23, Ldom_detach_previous
    str x24, [x25, #16]
    b Ldom_detach_next
Ldom_detach_previous:
    mov x0, x19
    mov x1, x23
    bl _engine_dom_node
    str x24, [x0, #40]
Ldom_detach_next:
    cbnz x24, Ldom_detach_following
    str x23, [x25, #24]
    b Ldom_detach_clear
Ldom_detach_following:
    mov x0, x19
    mov x1, x24
    bl _engine_dom_node
    str x23, [x0, #32]
Ldom_detach_clear:
    str xzr, [x21, #8]
    stp xzr, xzr, [x21, #32]
    ldr x9, [x19, #24]
    add x9, x9, #1
    str x9, [x19, #24]
    mov x0, x19
    mov x1, x22
    bl _dom_heights
Ldom_detach_done:
    mov x0, #0
    LEAVE
Ldom_detach_fail:
    mov x0, #-1
    LEAVE

// doc,parent,child,before (0=append) -> 0/-1. Validate before any mutation.
.globl _engine_dom_insert_before
_engine_dom_insert_before:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _engine_dom_node
    cbz x0, Ldom_insert_fail
    mov x23, x0
    ldr x9, [x0]
    cmp x9, #DOM_ELEMENT
    b.eq Ldom_insert_element
    cmp x9, #DOM_DOCUMENT
    b.ne Ldom_insert_fail
    b Ldom_insert_parent_ready
Ldom_insert_element:
    ldr x0, [x23, #48]
    bl _dom_is_void
    cbnz x0, Ldom_insert_fail
Ldom_insert_parent_ready:
    cmp x21, #1
    b.ls Ldom_insert_fail
    mov x0, x19
    mov x1, x21
    bl _engine_dom_node
    cbz x0, Ldom_insert_fail
    mov x24, x0
    cbz x22, Ldom_insert_before_ready
    mov x0, x19
    mov x1, x22
    bl _engine_dom_node
    cbz x0, Ldom_insert_fail
    ldr x9, [x0, #8]
    cmp x9, x20
    b.ne Ldom_insert_fail
    cmp x21, x22
    b.eq Ldom_insert_done
Ldom_insert_before_ready:
    mov x25, x20
    ldr x26, [x24, #72]
Ldom_insert_ancestor:
    cmp x25, x21
    b.eq Ldom_insert_fail
    cbz x25, Ldom_insert_valid
    add x26, x26, #1
    cmp x26, #DOM_MAX_DEPTH
    b.hi Ldom_insert_fail
    mov x0, x19
    mov x1, x25
    bl _engine_dom_node
    ldr x25, [x0, #8]
    b Ldom_insert_ancestor
Ldom_insert_valid:
    mov x0, x19
    mov x1, x21
    bl _engine_dom_detach
    cbnz x0, Ldom_insert_fail
    cbnz x22, Ldom_insert_before
    ldr x25, [x23, #24]
    str x21, [x23, #24]
    b Ldom_insert_link
Ldom_insert_before:
    mov x0, x19
    mov x1, x22
    bl _engine_dom_node
    ldr x25, [x0, #32]
    str x21, [x0, #32]
Ldom_insert_link:
    str x20, [x24, #8]
    stp x25, x22, [x24, #32]
    cbnz x25, Ldom_insert_previous
    str x21, [x23, #16]
    b Ldom_insert_height
Ldom_insert_previous:
    mov x0, x19
    mov x1, x25
    bl _engine_dom_node
    str x21, [x0, #40]
Ldom_insert_height:
    mov x0, x19
    mov x1, x20
    bl _dom_heights
    ldr x9, [x19, #24]
    add x9, x9, #1
    str x9, [x19, #24]
Ldom_insert_done:
    mov x0, #0
    LEAVE
Ldom_insert_fail:
    mov x0, #-1
    LEAVE
