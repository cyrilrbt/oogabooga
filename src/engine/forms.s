// application/x-www-form-urlencoded encoding over UTF-8 bytes. The caller owns
// the returned string; bounds match the HTML attribute limit (2 KiB).
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _engine_form_encode
_engine_form_encode:
    ENTER
    mov x19, x0
    cbz x0, Lencode_nil
    bl _strlen
    cmp x0, #2048
    b.hi Lencode_nil
    mov x20, x0
    mov x9, #6
    mul x0, x0, x9
    add x0, x0, #1
    bl _malloc
    cbz x0, Lencode_nil
    mov x21, x0
    mov x22, x0
    ADDR x23, encode_hex
Lencode_next:
    cbz x20, Lencode_done
    ldrb w9, [x19], #1
    sub x20, x20, #1
    cmp w9, #13
    b.eq Lencode_cr
    cmp w9, #10
    b.eq Lencode_newline
    cmp w9, #32
    b.eq Lencode_space
    sub w10, w9, #48
    cmp w10, #9
    b.ls Lencode_literal
    orr w10, w9, #32
    sub w10, w10, #97
    cmp w10, #25
    b.ls Lencode_literal
    cmp w9, #42
    b.eq Lencode_literal
    cmp w9, #45
    b.eq Lencode_literal
    cmp w9, #46
    b.eq Lencode_literal
    cmp w9, #95
    b.eq Lencode_literal
    mov w10, #37
    strb w10, [x22], #1
    lsr w10, w9, #4
    ldrb w10, [x23, x10]
    strb w10, [x22], #1
    and w9, w9, #15
    ldrb w9, [x23, x9]
    b Lencode_literal
Lencode_cr:
    cbz x20, Lencode_newline
    ldrb w10, [x19]
    cmp w10, #10
    b.ne Lencode_newline
    add x19, x19, #1
    sub x20, x20, #1
Lencode_newline:
    ADDR x10, encoded_crlf
    mov x11, #0
Lencode_newline_copy:
    ldrb w9, [x10, x11]
    strb w9, [x22], #1
    add x11, x11, #1
    cmp x11, #6
    b.lo Lencode_newline_copy
    b Lencode_next
Lencode_space:
    mov w9, #43
Lencode_literal:
    strb w9, [x22], #1
    b Lencode_next
Lencode_done:
    strb wzr, [x22]
    mov x0, x21
    LEAVE
Lencode_nil:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
encode_hex: .asciz "0123456789ABCDEF"
encoded_crlf: .asciz "%0D%0A"
