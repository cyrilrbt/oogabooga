// Backgrounds share existing cancellation, MIME/codec validation and budgets.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_background_url
_mac_background_url:
    ENTER
    ldr x0, [x0, #(32+CSS_BG_IMAGE*8)]
    cbz x0, Lbg_resource_url_done
    cmp x0, #0
    b.lt Lbg_resource_url_nil
    bl _mac_string
    mov x19, x0
    CLASS NSURL
    mov x2, x19
    LOAD x3, _engine_pending_url
    MSG relativeURL
    MSG absoluteURL
    mov x19, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz x0, Lbg_resource_url_nil
    mov x0, x19
    b Lbg_resource_url_done
Lbg_resource_url_nil:
    mov x0, #0
Lbg_resource_url_done:
    LEAVE
// doc -> next uncached URL, node in x1. Reserve the cache entry before fetching
// so unavailable images cannot produce a retry loop.
.globl _mac_background_next
_mac_background_next:
    ENTER
    mov x19, x0
    mov x20, #0
Lbg_resource_next:
    ldr x9, [x19, #24]
    cmp x20, x9
    b.hs Lbg_resource_none
    ldr x0, [x19, #72]
    add x0, x0, x20, lsl #11
    bl _mac_background_url
    cbz x0, Lbg_resource_advance
    mov x21, x0
    MSG absoluteString
    mov x22, x0
    mov x2, x22
    LOAD x0, _engine_images
    MSG objectKey
    cbnz x0, Lbg_resource_advance
    CLASS NSNull
    MSG bgNull
    mov x2, x0
    mov x3, x22
    LOAD x0, _engine_images
    MSG setObjectKey
    mov x0, x21
    mov x1, x20
    LEAVE
Lbg_resource_advance:
    add x20, x20, #1
    b Lbg_resource_next
Lbg_resource_none:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
_class_NSNull: .asciz "NSNull"
