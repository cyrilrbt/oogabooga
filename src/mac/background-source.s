// Resolve CSS url() values against the final stylesheet URL before import
// expansion. Inline styles keep the page base. Foundation handles URL syntax.
.include "src/mac/mac.inc"
.text
.p2align 2
// NSData, base NSURL -> retained normalized NSData, or nil on the 1 MiB cap.
.globl _mac_background_source
_mac_background_source:
    ENTER
    mov x19, x0
    mov x20, x1
    MSG length
    mov x21, x0
    mov x0, x19
    MSG bytes
    mov x22, x0
    add x23, x22, x21
    CLASS NSMutableData
    MSG new
    mov x24, x0
Lbg_source_next:
    mov x0, x22
    mov x1, x23
    bl _css_background_url_next
    cbz x0, Lbg_source_tail
    stp x0, x1, [sp, #144]
    stp x2, x3, [sp, #160]
    sub x3, x0, x22
    mov x2, x22
    mov x0, x24
    MSG bgAppendBytes
    ldp x0, x1, [sp, #160]
    sub x1, x1, x0
    bl _strndup
    mov x25, x0
    cbz x25, Lbg_source_fail
    bl _mac_string
    mov x26, x0
    mov x0, x25
    bl _free
    CLASS NSURL
    mov x2, x26
    mov x3, x20
    MSG relativeURL
    MSG absoluteURL
    mov x25, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz x0, Lbg_source_original
    mov x0, x25
    MSG absoluteString
    MSG UTF8String
    mov x25, x0
    mov x0, x24
    ADDR x2, bg_url_open
    mov x3, #5
    MSG bgAppendBytes
    mov x0, x25
    bl _strlen
    mov x3, x0
    mov x2, x25
    mov x0, x24
    MSG bgAppendBytes
    mov x0, x24
    ADDR x2, bg_url_close
    mov x3, #2
    MSG bgAppendBytes
    b Lbg_source_advance
Lbg_source_original:
    ldp x2, x3, [sp, #144]
    sub x3, x3, x2
    mov x0, x24
    MSG bgAppendBytes
Lbg_source_advance:
    ldr x22, [sp, #152]
    mov x0, x24
    MSG length
    mov x9, #1048576
    cmp x0, x9
    b.hi Lbg_source_fail
    b Lbg_source_next
Lbg_source_tail:
    mov x0, x24
    mov x2, x22
    sub x3, x23, x22
    MSG bgAppendBytes
    mov x0, x24
    MSG length
    mov x9, #1048576
    cmp x0, x9
    b.hi Lbg_source_fail
    mov x0, x24
    LEAVE
Lbg_source_fail:
    mov x0, x24
    MSG release
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
bg_url_open: .asciz "url(\""
bg_url_close: .asciz "\")"

.text
// Preserve media attributes in the CSS source so viewport changes re-evaluate
// the normal assembly cascade, rather than permanently applying a fetched sheet.
.globl _mac_media_source
_mac_media_source:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _strlen
    mov x21, x0
    mov x0, x20
    bl _strlen
    add x0, x0, x21
    add x0, x0, #16
    mov x9, #1048576
    cmp x0, x9
    b.hi Lmedia_source_nil
    str xzr, [sp, #144]
    stp x20, x19, [sp]
    add x0, sp, #144
    ADDR x1, bg_media_format
    bl _asprintf
    cmp w0, #0
    b.lt Lmedia_source_nil
    ldr x0, [sp, #144]
    LEAVE
Lmedia_source_nil:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
bg_media_format: .asciz "@media %s {\n%s\n}\n"
