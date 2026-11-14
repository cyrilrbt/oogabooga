// Plain text for native button titles. Strip markup before decoding entities so
// escaped '<' remains text. Never feed HTML or SVG source to an AppKit control.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _engine_button_label
_engine_button_label:
    ENTER
    mov x19, x0
    mov x20, x1
    sub x1, x1, x0
    add x1, x1, #1
    mov x0, #1
    bl _calloc
    cbz x0, Llabel_return
    mov x21, x0
    mov x22, #0
Llabel_next:
    cmp x19, x20
    b.hs Llabel_decode
    ldrb w9, [x19]
    cmp w9, #60
    b.eq Llabel_tag
    add x19, x19, #1
    cmp w9, #32
    b.hi Llabel_copy
    cbz x22, Llabel_next
    sub x10, x22, #1
    ldrb w10, [x21, x10]
    cmp w10, #32
    b.eq Llabel_next
    mov w9, #32
Llabel_copy:
    strb w9, [x21, x22]
    add x22, x22, #1
    b Llabel_next
Llabel_tag:
    sub x9, x20, x19
    cmp x9, #4
    b.lo Llabel_scan_tag
    mov x0, x19
    ADDR x1, label_comment
    mov x2, #4
    bl _memcmp
    cbnz w0, Llabel_check_raw
    add x0, x19, #4
    sub x1, x20, x0
    ADDR x2, label_comment_end
    mov x3, #3
    bl _memmem
    cbz x0, Llabel_decode
    add x19, x0, #3
    b Llabel_next
Llabel_check_raw:
    ADDR x23, label_raw_tags
Llabel_raw_next:
    ldr x2, [x23]
    cbz x2, Llabel_scan_tag
    ldr x24, [x23, #8]
    add x0, x19, #1
    sub x9, x20, x0
    cmp x9, x24
    b.ls Llabel_raw_advance
    mov x1, x2
    mov x2, x24
    bl _strncasecmp
    cbnz w0, Llabel_raw_advance
    add x9, x19, x24
    ldrb w9, [x9, #1]
    cmp w9, #62
    b.eq Llabel_skip_raw
    cmp w9, #32
    b.ls Llabel_skip_raw
Llabel_raw_advance:
    add x23, x23, #24
    b Llabel_raw_next
Llabel_skip_raw:
    mov x0, x19
    mov x1, x20
    ldr x2, [x23, #16]
    add x3, x24, #2
    bl _engine_find_close
    mov x19, x0
Llabel_scan_tag:
    mov x23, #0
Llabel_tag_byte:
    cmp x19, x20
    b.hs Llabel_decode
    ldrb w9, [x19], #1
    cbz x23, Llabel_unquoted
    cmp w9, w23
    b.ne Llabel_tag_byte
    mov x23, #0
    b Llabel_tag_byte
Llabel_unquoted:
    cmp w9, #34
    b.eq Llabel_quote
    cmp w9, #39
    b.eq Llabel_quote
    cmp w9, #62
    b.eq Llabel_next
    b Llabel_tag_byte
Llabel_quote:
    mov x23, x9
    b Llabel_tag_byte
Llabel_decode:
    mov x0, x21
    add x1, x21, x22
    bl _css_trim
    bl _engine_decode_attribute
    mov x19, x0
    mov x0, x21
    bl _free
    mov x0, x19
Llabel_return:
    LEAVE
.section __DATA,__const
.p2align 3
label_raw_tags:
.quad label_svg, 3, label_svg_end
.quad label_script, 6, label_script_end
.quad label_style, 5, label_style_end
.quad 0, 0, 0
.section __TEXT,__cstring,cstring_literals
label_svg: .asciz "svg"
label_svg_end: .asciz "</svg"
label_script: .asciz "script"
label_script_end: .asciz "</script"
label_style: .asciz "style"
label_style_end: .asciz "</style"
label_comment: .asciz "<!--"
label_comment_end: .asciz "-->"
