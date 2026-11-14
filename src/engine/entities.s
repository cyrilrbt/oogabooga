// Entity and attribute scanners. No unbounded reads or string-library parsing.
.include "src/mac/mac.inc"
.text
.p2align 2
// entity(input,end,output[4]) -> consumed bytes in x0, output length in x1.
.globl _engine_entity
_engine_entity:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    add x22, x0, #1
    cmp x22, x20
    b.hs Lentity_none
    ldrb w9, [x22]
    cmp w9, #35
    b.eq Lentity_numeric
    ADDR x23, entity_table
Lentity_named:
    ldr x1, [x23]
    cbz x1, Lentity_none
    ldr x24, [x23, #8]
    sub x9, x20, x22
    cmp x9, x24
    b.lo Lentity_named_next
    mov x0, x22
    mov x2, x24
    bl _memcmp
    cbnz w0, Lentity_named_next
    ldr w25, [x23, #16]
    add x26, x24, #1
    b Lentity_encode
Lentity_named_next:
    add x23, x23, #24
    b Lentity_named
Lentity_numeric:
    add x22, x22, #1
    mov x23, #10
    cmp x22, x20
    b.hs Lentity_none
    ldrb w9, [x22]
    orr w9, w9, #32
    cmp w9, #120
    b.ne Lentity_digits
    mov x23, #16
    add x22, x22, #1
Lentity_digits:
    mov w25, #0
    mov x24, #0
Lentity_digit:
    cmp x22, x20
    b.hs Lentity_none
    ldrb w9, [x22], #1
    cmp w9, #59
    b.eq Lentity_number_done
    sub w10, w9, #48
    cmp w10, #9
    b.ls Lentity_accumulate
    cmp x23, #16
    b.ne Lentity_none
    orr w9, w9, #32
    sub w10, w9, #97
    cmp w10, #5
    b.hi Lentity_none
    add w10, w10, #10
Lentity_accumulate:
    add x24, x24, #1
    cmp x24, #8
    b.hi Lentity_none
    madd w25, w25, w23, w10
    mov w9, #0xffff
    movk w9, #0x10, lsl #16
    cmp w25, w9
    b.hi Lentity_none
    b Lentity_digit
Lentity_number_done:
    cbz x24, Lentity_none
    sub x26, x22, x19
    cbz w25, Lentity_replacement
    mov w9, #0xd800
    cmp w25, w9
    b.lo Lentity_encode
    mov w9, #0xdfff
    cmp w25, w9
    b.hi Lentity_encode
Lentity_replacement:
    mov w25, #0xfffd
Lentity_encode:
    cmp w25, #128
    b.hs Lentity_two
    strb w25, [x21]
    mov x1, #1
    b Lentity_return
Lentity_two:
    cmp w25, #0x800
    b.hs Lentity_three
    lsr w9, w25, #6
    orr w9, w9, #0xc0
    strb w9, [x21]
    and w9, w25, #0x3f
    orr w9, w9, #0x80
    strb w9, [x21, #1]
    mov x1, #2
    b Lentity_return
Lentity_three:
    mov w9, #0x10000
    cmp w25, w9
    b.hs Lentity_four
    lsr w9, w25, #12
    orr w9, w9, #0xe0
    strb w9, [x21]
    lsr w9, w25, #6
    and w9, w9, #0x3f
    orr w9, w9, #0x80
    strb w9, [x21, #1]
    and w9, w25, #0x3f
    orr w9, w9, #0x80
    strb w9, [x21, #2]
    mov x1, #3
    b Lentity_return
Lentity_four:
    lsr w9, w25, #18
    orr w9, w9, #0xf0
    strb w9, [x21]
    lsr w9, w25, #12
    and w9, w9, #0x3f
    orr w9, w9, #0x80
    strb w9, [x21, #1]
    lsr w9, w25, #6
    and w9, w9, #0x3f
    orr w9, w9, #0x80
    strb w9, [x21, #2]
    and w9, w25, #0x3f
    orr w9, w9, #0x80
    strb w9, [x21, #3]
    mov x1, #4
Lentity_return:
    mov x0, x26
    LEAVE
Lentity_none:
    mov x0, #0
    mov x1, #0
    LEAVE

// href(attribute_start,tag_end) -> owned decoded string or NULL.
.globl _engine_href
_engine_href:
    ADDR x2, href_name
    b _engine_attribute
.globl _engine_attribute
_engine_attribute:
    ENTER
    mov x28, x2
    mov x19, x0
    mov x20, x1
Lhref_next:
    cmp x19, x20
    b.hs Lhref_none
    ldrb w9, [x19]
    cmp w9, #32
    b.hi Lhref_name
    add x19, x19, #1
    b Lhref_next
Lhref_name:
    mov x21, x19
Lhref_name_scan:
    cmp x19, x20
    b.hs Lhref_none
    ldrb w9, [x19]
    cmp w9, #61
    b.eq Lhref_name_done
    cmp w9, #32
    b.ls Lhref_name_done
    add x19, x19, #1
    b Lhref_name_scan
Lhref_name_done:
    sub x22, x19, x21
Lhref_equal:
    cmp x19, x20
    b.hs Lhref_none
    ldrb w9, [x19], #1
    cmp w9, #32
    b.ls Lhref_equal
    cmp w9, #61
    b.eq Lhref_value_space
    sub x19, x19, #1
    b Lhref_next
Lhref_value_space:
    cmp x19, x20
    b.hs Lhref_none
    ldrb w9, [x19]
    cmp w9, #32
    b.hi Lhref_value
    add x19, x19, #1
    b Lhref_value_space
Lhref_value:
    mov w23, #0
    cmp w9, #34
    b.eq Lhref_quoted
    cmp w9, #39
    b.ne Lhref_value_start
Lhref_quoted:
    mov w23, w9
    add x19, x19, #1
Lhref_value_start:
    mov x24, x19
Lhref_value_scan:
    cmp x19, x20
    b.hs Lhref_value_done
    ldrb w9, [x19]
    cbz w23, Lhref_unquoted
    cmp w9, w23
    b.eq Lhref_value_done
    b Lhref_value_advance
Lhref_unquoted:
    cmp w9, #32
    b.ls Lhref_value_done
Lhref_value_advance:
    add x19, x19, #1
    b Lhref_value_scan
Lhref_value_done:
    mov x25, x19
    cbz w23, Lhref_test
    cmp x19, x20
    b.hs Lhref_test
    add x19, x19, #1
Lhref_test:
    mov x0, x28
    bl _strlen
    cmp x22, x0
    b.ne Lhref_next
    mov x0, x21
    mov x1, x28
    mov x2, x22
    bl _strncasecmp
    cbnz w0, Lhref_next
    sub x22, x25, x24
    cbz x22, Lhref_none
    cmp x22, #2048
    b.hi Lhref_none
    add x0, x22, #1
    bl _malloc
    cbz x0, Lhref_none
    mov x23, x0
    mov x26, #0
Lhref_decode:
    cmp x24, x25
    b.hs Lhref_result
    ldrb w9, [x24]
    cmp w9, #38
    b.ne Lhref_literal
    mov x0, x24
    mov x1, x25
    add x2, sp, #144
    bl _engine_entity
    cbz x0, Lhref_literal
    add x24, x24, x0
    mov x22, x1
    add x27, sp, #144
Lhref_entity_copy:
    cbz x22, Lhref_decode
    ldrb w9, [x27], #1
    strb w9, [x23, x26]
    add x26, x26, #1
    sub x22, x22, #1
    b Lhref_entity_copy
Lhref_literal:
    ldrb w9, [x24], #1
    strb w9, [x23, x26]
    add x26, x26, #1
    b Lhref_decode
Lhref_result:
    strb wzr, [x23, x26]
    mov x0, x23
    LEAVE
Lhref_none:
    mov x0, #0
    LEAVE
.section __DATA,__const
.p2align 3
entity_table:
.quad entity_amp, 4, 38
.quad entity_lt, 3, 60
.quad entity_gt, 3, 62
.quad entity_quot, 5, 34
.quad entity_apos, 5, 39
.quad entity_nbsp, 5, 160
.quad 0, 0, 0
.section __TEXT,__cstring,cstring_literals
entity_amp: .asciz "amp;"
entity_lt: .asciz "lt;"
entity_gt: .asciz "gt;"
entity_quot: .asciz "quot;"
entity_apos: .asciz "apos;"
entity_nbsp: .asciz "nbsp;"
href_name: .asciz "href"
