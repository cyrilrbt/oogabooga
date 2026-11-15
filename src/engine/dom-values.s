.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// doc,bytes,length -> owned NUL-terminated copy, charged to the document budget.
.globl _dom_copy
_dom_copy:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    cbz x0, Ldom_copy_fail
    cbnz x1, Ldom_copy_source
    cbnz x2, Ldom_copy_fail
Ldom_copy_source:
    mov x9, #1048576
    cmp x21, x9
    b.hi Ldom_copy_fail
    ldr x9, [x19, #32]
    add x9, x9, x21
    add x9, x9, #1
    mov x10, #DOM_MAX_BYTES
    cmp x9, x10
    b.hi Ldom_copy_fail
    str x9, [sp, #144]
    add x0, x21, #1
    bl _malloc
    cbz x0, Ldom_copy_fail
    mov x22, x0
    cbz x21, Ldom_copy_end
    mov x1, x20
    mov x2, x21
    bl _memcpy
Ldom_copy_end:
    strb wzr, [x22, x21]
    ldr x9, [sp, #144]
    str x9, [x19, #32]
    mov x0, x22
    LEAVE
Ldom_copy_fail:
    mov x0, #0
    LEAVE

.globl _dom_string_free
_dom_string_free:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x1, Ldom_string_done
    mov x0, x1
    bl _strlen
    add x0, x0, #1
    ldr x9, [x19, #32]
    sub x9, x9, x0
    str x9, [x19, #32]
    mov x0, x20
    bl _free
Ldom_string_done:
    LEAVE

// Validate a bounded UTF-8 string; document strings contain no embedded NUL.
.globl _dom_valid_text
_dom_valid_text:
    ENTER
    mov x19, x0
    mov x9, #1048576
    cmp x1, x9
    b.hi Ldom_text_invalid
    add x20, x0, x1
    cbnz x0, Ldom_text_scan
    cbnz x1, Ldom_text_invalid
Ldom_text_scan:
    cmp x19, x20
    b.hs Ldom_text_valid
    ldrb w9, [x19]
    cbz w9, Ldom_text_invalid
    mov x0, x19
    mov x1, x20
    bl _engine_utf8
    cbz x0, Ldom_text_invalid
    add x19, x19, x0
    b Ldom_text_scan
Ldom_text_valid:
    mov x0, #1
    LEAVE
Ldom_text_invalid:
    mov x0, #0
    LEAVE

// doc,name,length -> owned lowercase ASCII name (HTML namespace subset).
.globl _dom_name
_dom_name:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    cbz x1, Ldom_name_fail
    cbz x2, Ldom_name_fail
    cmp x2, #128
    b.hi Ldom_name_fail
    mov x22, #0
Ldom_name_check:
    cmp x22, x21
    b.hs Ldom_name_copy
    ldrb w9, [x20, x22]
    orr w10, w9, #32
    sub w10, w10, #97
    cmp w10, #25
    b.ls Ldom_name_next
    cmp w9, #95
    b.eq Ldom_name_next
    cmp w9, #58
    b.eq Ldom_name_next
    cbz x22, Ldom_name_fail
    sub w10, w9, #48
    cmp w10, #9
    b.ls Ldom_name_next
    cmp w9, #45
    b.eq Ldom_name_next
    cmp w9, #46
    b.ne Ldom_name_fail
Ldom_name_next:
    add x22, x22, #1
    b Ldom_name_check
Ldom_name_copy:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _dom_copy
    cbz x0, Ldom_name_fail
    mov x22, #0
Ldom_name_lower:
    cmp x22, x21
    b.hs Ldom_name_done
    ldrb w9, [x0, x22]
    sub w10, w9, #65
    cmp w10, #25
    b.hi Ldom_name_lower_next
    orr w9, w9, #32
    strb w9, [x0, x22]
Ldom_name_lower_next:
    add x22, x22, #1
    b Ldom_name_lower
Ldom_name_done:
    LEAVE
Ldom_name_fail:
    mov x0, #0
    LEAVE

.globl _engine_dom_create_element
_engine_dom_create_element:
    ENTER
    mov x19, x0
    bl _dom_name
    cbz x0, Ldom_create_fail
    mov x20, x0
    mov x2, x0
    mov x0, x19
    mov x1, #DOM_ELEMENT
    mov x3, #0
    bl _dom_allocate
    cbnz x0, Ldom_create_done
    mov x0, x19
    mov x1, x20
    bl _dom_string_free
Ldom_create_fail:
    mov x0, #0
Ldom_create_done:
    LEAVE

.globl _engine_dom_create_text
_engine_dom_create_text:
    mov x3, #DOM_TEXT
    b dom_create_data
.globl _engine_dom_create_comment
_engine_dom_create_comment:
    mov x3, #DOM_COMMENT
dom_create_data:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x0, x1
    mov x1, x2
    bl _dom_valid_text
    cbz x0, Ldom_create_data_fail
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _dom_copy
    cbz x0, Ldom_create_data_fail
    mov x23, x0
    mov x3, x0
    mov x0, x19
    mov x1, x22
    mov x2, #0
    bl _dom_allocate
    cbnz x0, Ldom_create_data_done
    mov x0, x19
    mov x1, x23
    bl _dom_string_free
Ldom_create_data_fail:
    mov x0, #0
Ldom_create_data_done:
    LEAVE

// doc,text/comment node,UTF8,length -> 0/-1, leaves prior value on failure.
.globl _engine_dom_set_text
_engine_dom_set_text:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    bl _engine_dom_node
    cbz x0, Ldom_set_text_fail
    mov x22, x0
    ldr x9, [x0]
    cmp x9, #DOM_TEXT
    b.eq Ldom_set_text_valid
    cmp x9, #DOM_COMMENT
    b.ne Ldom_set_text_fail
Ldom_set_text_valid:
    mov x0, x20
    mov x1, x21
    bl _dom_valid_text
    cbz x0, Ldom_set_text_fail
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _dom_copy
    cbz x0, Ldom_set_text_fail
    mov x23, x0
    ldr x1, [x22, #56]
    mov x0, x19
    bl _dom_string_free
    str x23, [x22, #56]
    ldr x9, [x19, #24]
    add x9, x9, #1
    str x9, [x19, #24]
    mov x0, #0
    LEAVE
Ldom_set_text_fail:
    mov x0, #-1
    LEAVE

// doc,element,UTF8,length -> 0/-1. Allocate and validate replacement before
// removing the old children. Element identity survives; child handles do not.
.globl _engine_dom_set_text_content
_engine_dom_set_text_content:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _engine_dom_node
    cbz x0, Ldom_content_fail
    mov x23, x0
    ldr x9, [x0]
    cmp x9, #DOM_TEXT
    b.eq Ldom_content_data
    cmp x9, #DOM_COMMENT
    b.eq Ldom_content_data
    cmp x9, #DOM_ELEMENT
    b.ne Ldom_content_fail
    mov x0, x21
    mov x1, x22
    bl _dom_valid_text
    cbz x0, Ldom_content_fail
    mov x24, #0
    cbz x22, Ldom_content_remove
    mov x0, x19
    mov x1, x21
    mov x2, x22
    bl _engine_dom_create_text
    cbz x0, Ldom_content_fail
    mov x24, x0
    mov x2, x0
    mov x0, x19
    mov x1, x20
    mov x3, #0
    bl _engine_dom_insert_before
    cbz x0, Ldom_content_remove
    mov x0, x19
    mov x1, x24
    bl _engine_dom_remove
    b Ldom_content_fail
Ldom_content_remove:
    ldr x1, [x23, #16]
    cbz x1, Ldom_content_done
    cmp x1, x24
    b.eq Ldom_content_done
    mov x0, x19
    bl _engine_dom_remove
    b Ldom_content_remove
Ldom_content_data:
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    bl _engine_dom_set_text
    LEAVE
Ldom_content_done:
    mov x0, #0
    LEAVE
Ldom_content_fail:
    mov x0, #-1
    LEAVE
