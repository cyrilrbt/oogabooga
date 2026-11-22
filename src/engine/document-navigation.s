// Navigation semantics shared by native adapters; URL resolution/percent
// decoding remain platform primitives. No network request is needed for #id.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/dom.inc"
.text
// flow document -> first connected <base href>, borrowed string or NULL.
.globl _engine_base_href
_engine_base_href:
    ENTER
    ldr x19, [x0, #96]
    cbz x19, Lbase_none
    mov x20, #1
Lbase_next:
    mov x0, x19
    mov x1, x20
    bl _engine_dom_node
    cbz x0, Lbase_none
    ldr x9, [x0]
    cmp x9, #DOM_ELEMENT
    b.ne Lbase_advance
    ldr x0, [x0, #48]
    ADDR x1, base_tag
    bl _strcmp
    cbnz x0, Lbase_advance
    mov x0, x19
    mov x1, x20
    ADDR x2, base_href
    bl _engine_dom_get_attribute
    cbnz x0, Lbase_done
Lbase_advance:
    mov x0, x19
    mov x1, x20
    bl _engine_dom_next
    mov x20, x0
    cbnz x0, Lbase_next
Lbase_none:
    mov x0, #0
Lbase_done:
    LEAVE
// current absolute URL,target absolute URL -> true when either URL has a fragment
// and pre-fragment bytes match. This also handles history back to the hashless
// entry. Empty fragment means document top.
.globl _engine_same_document
_engine_same_document:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x19, Lsame_no
    cbz x20, Lsame_no
    mov x0, x20
    mov x1, #35
    bl _strchr
    mov x22, x0
    cbnz x0, Lsame_target_hash
    mov x0, x20
    bl _strlen
    add x0, x20, x0
Lsame_target_hash:
    sub x21, x0, x20
    mov x0, x19
    mov x1, #35
    bl _strchr
    cbnz x0, Lsame_current_hash
    cbz x22, Lsame_no
    mov x0, x19
    bl _strlen
    add x0, x19, x0
Lsame_current_hash:
    sub x0, x0, x19
    cmp x0, x21
    b.ne Lsame_no
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _memcmp
    cmp x0, #0
    cset x0, eq
    LEAVE
Lsame_no:
    mov x0, #0
    LEAVE
// flow document,decoded fragment -> node index or -1 if not present.
.globl _engine_fragment_node
_engine_fragment_node:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x1, Lfragment_missing
    ldrb w9, [x1]
    cbz w9, Lfragment_top
    mov x21, #1
Lfragment_node_next:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lfragment_top_keyword
    ldr x22, [x19, #72]
    add x22, x22, x21, lsl #11
    ldr x0, [x22]
    cbz x0, Lfragment_legacy
    mov x1, x20
    bl _strcmp
    cbz x0, Lfragment_found
Lfragment_legacy:
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x21, x10, x9
    ldr x9, [x9]
    cmp x9, #6
    b.ne Lfragment_node_advance
    ldr x0, [x22, #ATTR_NAME]
    cbz x0, Lfragment_node_advance
    mov x1, x20
    bl _strcmp
    cbz x0, Lfragment_found
Lfragment_node_advance:
    add x21, x21, #1
    b Lfragment_node_next
Lfragment_top_keyword:
    mov x0, x20
    ADDR x1, base_top
    bl _strcasecmp
    cbz x0, Lfragment_top
Lfragment_missing:
    mov x0, #-1
    LEAVE
Lfragment_found:
    mov x0, x21
    LEAVE
Lfragment_top:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
base_tag: .asciz "base"
base_href: .asciz "href"
base_top: .asciz "top"
