.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// doc,element,name,value,length -> 0/-1. Attribute names ASCII case-insensitive.
.globl _engine_dom_set_attribute
_engine_dom_set_attribute:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    mov x22, x4
    bl _engine_dom_node
    cbz x0, Ldom_attr_fail
    mov x23, x0
    ldr x9, [x0]
    cmp x9, #DOM_ELEMENT
    b.ne Ldom_attr_fail
    mov x0, x21
    mov x1, x22
    bl _dom_valid_text
    cbz x0, Ldom_attr_fail
    cbz x20, Ldom_attr_fail
    mov x0, x20
    mov x1, #129
    bl _strnlen
    mov x2, x0
    mov x0, x19
    mov x1, x20
    bl _dom_name
    cbz x0, Ldom_attr_fail
    mov x24, x0
    ldr x25, [x23, #64]
    mov x26, #0
    mov x28, #0
Ldom_attr_find:
    cbz x25, Ldom_attr_new
    ldr x0, [x25]
    mov x1, x24
    bl _strcmp
    cbz w0, Ldom_attr_value
    mov x28, x25
    ldr x25, [x25, #16]
    add x26, x26, #1
    b Ldom_attr_find
Ldom_attr_new:
    cmp x26, #64
    b.hs Ldom_attr_name_fail
Ldom_attr_value:
    mov x0, x19
    mov x1, x21
    mov x2, x22
    bl _dom_copy
    cbz x0, Ldom_attr_name_fail
    mov x27, x0
    cbnz x25, Ldom_attr_replace
    mov x0, #1
    mov x1, #32
    bl _calloc
    cbz x0, Ldom_attr_value_fail
    stp x24, x27, [x0]
    str x22, [x0, #24]
    cbnz x28, Ldom_attr_append
    str x0, [x23, #64]
    b Ldom_attr_changed
Ldom_attr_append:
    str x0, [x28, #16]
    b Ldom_attr_changed
Ldom_attr_replace:
    mov x0, x19
    mov x1, x24
    bl _dom_string_free
    mov x0, x19
    ldr x1, [x25, #8]
    bl _dom_string_free
    str x27, [x25, #8]
    str x22, [x25, #24]
Ldom_attr_changed:
    ldr x9, [x19, #24]
    add x9, x9, #1
    str x9, [x19, #24]
    mov x0, #0
    LEAVE
Ldom_attr_value_fail:
    mov x0, x19
    mov x1, x27
    bl _dom_string_free
Ldom_attr_name_fail:
    mov x0, x19
    mov x1, x24
    bl _dom_string_free
Ldom_attr_fail:
    mov x0, #-1
    LEAVE

// doc,element,name -> borrowed value pointer (nil absent), length in x1.
.globl _engine_dom_get_attribute
_engine_dom_get_attribute:
    ENTER
    mov x19, x2
    bl _engine_dom_node
    cbz x0, Ldom_attr_get_nil
    cbz x19, Ldom_attr_get_nil
    ldr x20, [x0, #64]
Ldom_attr_get:
    cbz x20, Ldom_attr_get_nil
    ldr x0, [x20]
    mov x1, x19
    bl _strcasecmp
    cbz w0, Ldom_attr_get_found
    ldr x20, [x20, #16]
    b Ldom_attr_get
Ldom_attr_get_found:
    ldp x0, x1, [x20, #8]
    ldr x1, [x20, #24]
    LEAVE
Ldom_attr_get_nil:
    mov x0, #0
    mov x1, #0
    LEAVE

.globl _engine_dom_remove_attribute
_engine_dom_remove_attribute:
    ENTER
    mov x19, x0
    mov x20, x2
    bl _engine_dom_node
    cbz x0, Ldom_attr_remove_fail
    cbz x20, Ldom_attr_remove_fail
    add x21, x0, #64
Ldom_attr_remove_find:
    ldr x22, [x21]
    cbz x22, Ldom_attr_remove_done
    ldr x0, [x22]
    mov x1, x20
    bl _strcasecmp
    cbz w0, Ldom_attr_remove_found
    add x21, x22, #16
    b Ldom_attr_remove_find
Ldom_attr_remove_found:
    ldr x9, [x22, #16]
    str x9, [x21]
    ldr x1, [x22]
    mov x0, x19
    bl _dom_string_free
    ldr x1, [x22, #8]
    mov x0, x19
    bl _dom_string_free
    mov x0, x22
    bl _free
    ldr x9, [x19, #24]
    add x9, x9, #1
    str x9, [x19, #24]
Ldom_attr_remove_done:
    mov x0, #0
    LEAVE
Ldom_attr_remove_fail:
    mov x0, #-1
    LEAVE
