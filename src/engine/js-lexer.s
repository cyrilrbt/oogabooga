.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
// vm,source,length -> BOOL. No speculative reads past the source boundary.
.globl _js_lex
_js_lex:
    ENTER
    mov x19, x0
    mov x20, x1
    add x21, x1, x2
    mov x9, #JS_MAX_SOURCE
    cmp x2, x9
    b.hi Ljs_lex_error
    mov x1, #262144
    bl _js_alloc
    cbz x0, Ljs_lex_fail
    str x0, [x19, #JS_TOKENS]
    mov x22, x0
    mov x23, #0
Ljs_lex_next:
    cmp x20, x21
    b.hs Ljs_lex_end
    ldrb w24, [x20]
    cmp w24, #32
    b.ls Ljs_lex_space
    cmp w24, #47
    b.eq Ljs_lex_comment
Ljs_lex_classify:
    mov x25, x20
    cmp w24, #34
    b.eq Ljs_lex_string
    cmp w24, #39
    b.eq Ljs_lex_string
    cmp w24, #48
    b.lo Ljs_lex_ident_test
    cmp w24, #57
    b.ls Ljs_lex_number
Ljs_lex_ident_test:
    cmp w24, #46
    b.ne Ljs_lex_name_test
    add x9, x20, #1
    cmp x9, x21
    b.hs Ljs_lex_punctuation
    ldrb w9, [x9]
    sub w9, w9, #48
    cmp w9, #9
    b.ls Ljs_lex_number
Ljs_lex_name_test:
    mov x0, x24
    bl js_ident_start
    cbz x0, Ljs_lex_punctuation
    add x20, x20, #1
Ljs_lex_ident_more:
    cmp x20, x21
    b.hs Ljs_lex_ident_done
    ldrb w24, [x20]
    mov x0, x24
    bl js_ident_start
    cbnz x0, Ljs_lex_ident_advance
    sub w9, w24, #48
    cmp w9, #9
    b.hi Ljs_lex_ident_done
Ljs_lex_ident_advance:
    add x20, x20, #1
    b Ljs_lex_ident_more
Ljs_lex_ident_done:
    mov x0, x19
    mov x1, x25
    sub x2, x20, x25
    bl _js_string
    mov x26, x0
    mov x24, #T_IDENT
    b Ljs_lex_emit
Ljs_lex_number:
    add x20, x20, #1
Ljs_lex_number_more:
    cmp x20, x21
    b.hs Ljs_lex_number_done
    ldrb w9, [x20]
    sub w10, w9, #48
    cmp w10, #9
    b.ls Ljs_lex_number_advance
    cmp w9, #46
    b.eq Ljs_lex_number_advance
    orr w9, w9, #32
    cmp w9, #101
    b.ne Ljs_lex_number_done
    add x20, x20, #1
    cmp x20, x21
    b.hs Ljs_lex_number_done
    ldrb w9, [x20]
    cmp w9, #43
    b.eq Ljs_lex_number_advance
    cmp w9, #45
    b.eq Ljs_lex_number_advance
    b Ljs_lex_number_more
Ljs_lex_number_advance:
    add x20, x20, #1
    b Ljs_lex_number_more
Ljs_lex_number_done:
    mov x0, x19
    mov x1, x25
    sub x2, x20, x25
    bl _js_string
    cbz x0, Ljs_lex_fail
    ldr x0, [x0, #8]
    add x1, sp, #144
    bl _strtod
    ldr x9, [sp, #144]
    ldrb w9, [x9]
    cbnz w9, Ljs_lex_error
    mov x0, x19
    bl _js_number
    mov x26, x0
    mov x24, #T_NUMBER
    b Ljs_lex_emit
Ljs_lex_string:
    mov x27, x24
    add x20, x20, #1
    mov x25, x20
Ljs_lex_quote_scan:
    cmp x20, x21
    b.hs Ljs_lex_error
    ldrb w9, [x20]
    cmp w9, w27
    b.eq Ljs_lex_quote_end
    cmp w9, #10
    b.eq Ljs_lex_error
    cmp w9, #13
    b.eq Ljs_lex_error
    cmp w9, #92
    b.ne Ljs_lex_quote_advance
    add x20, x20, #1
Ljs_lex_quote_advance:
    add x20, x20, #1
    b Ljs_lex_quote_scan
Ljs_lex_quote_end:
    mov x0, x19
    mov x1, x25
    sub x2, x20, x25
    bl js_decode_string
    cbz x0, Ljs_lex_fail
    mov x26, x0
    add x20, x20, #1
    mov x24, #T_STRING
    b Ljs_lex_emit
Ljs_lex_punctuation:
    cmp w24, #127
    b.hs Ljs_lex_error
    mov x27, #0
    ADDR x28, js_operators
Ljs_lex_operator:
    ldr x9, [x28]
    cbz x9, Ljs_lex_single
    ldr x10, [x28, #8]
    add x11, x20, x10
    cmp x11, x21
    b.hi Ljs_lex_operator_next
    mov x0, x20
    mov x1, x9
    mov x2, x10
    bl _memcmp
    cbz x0, Ljs_lex_operator_found
Ljs_lex_operator_next:
    add x28, x28, #24
    b Ljs_lex_operator
Ljs_lex_operator_found:
    ldr x9, [x28, #8]
    add x20, x20, x9
    ldr x24, [x28, #16]
    b Ljs_lex_no_value
Ljs_lex_single:
    add x20, x20, #1
Ljs_lex_no_value:
    mov x26, #0
Ljs_lex_emit:
    mov x9, #8191
    cmp x23, x9
    b.hs Ljs_lex_error
    add x9, x22, x23, lsl #5
    stp x24, x26, [x9]
    mov x10, #0
    cmp x24, #T_STRING
    csel x10, x27, x10, eq
    cmp x24, #T_NUMBER
    b.ne Ljs_lex_token_aux
    sub x10, x20, x25
Ljs_lex_token_aux:
    stp x10, x25, [x9, #16]
    add x23, x23, #1
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_lex_fail
    b Ljs_lex_next
Ljs_lex_space:
    add x20, x20, #1
    b Ljs_lex_next
Ljs_lex_comment:
    add x9, x20, #1
    cmp x9, x21
    b.hs Ljs_lex_classify
    ldrb w9, [x9]
    cmp w9, #47
    b.eq Ljs_lex_line_comment
    cmp w9, #42
    b.ne Ljs_lex_classify
    add x20, x20, #2
Ljs_lex_block_comment:
    add x9, x20, #1
    cmp x9, x21
    b.hs Ljs_lex_error
    ldrb w9, [x20], #1
    cmp w9, #42
    b.ne Ljs_lex_block_comment
    ldrb w9, [x20]
    cmp w9, #47
    b.ne Ljs_lex_block_comment
    add x20, x20, #1
    b Ljs_lex_next
Ljs_lex_line_comment:
    add x20, x20, #2
Ljs_lex_line_skip:
    cmp x20, x21
    b.hs Ljs_lex_end
    ldrb w9, [x20], #1
    cmp w9, #10
    b.ne Ljs_lex_line_skip
    b Ljs_lex_next
Ljs_lex_end:
    str x23, [x19, #JS_TOKEN_COUNT]
    str xzr, [x19, #JS_POS]
    mov x0, #1
    LEAVE
Ljs_lex_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_lex_fail:
    mov x0, #0
    LEAVE
js_ident_start:
    cmp x0, #36
    b.eq Ljs_ident_yes
    cmp x0, #95
    b.eq Ljs_ident_yes
    orr x0, x0, #32
    sub x0, x0, #97
    cmp x0, #25
    cset x0, ls
    ret
Ljs_ident_yes:
    mov x0, #1
    ret
// Literal contents -> UTF-8 string. Reject unsupported escapes explicitly.
js_decode_string:
    ENTER
    mov x19, x0
    mov x20, x1
    add x21, x1, x2
    add x1, x2, #1
    bl _js_alloc
    cbz x0, Ljs_decode_done
    mov x22, x0
    mov x23, #0
Ljs_decode_next:
    cmp x20, x21
    b.hs Ljs_decode_copy
    ldrb w24, [x20], #1
    cmp w24, #92
    b.ne Ljs_decode_emit
    cmp x20, x21
    b.hs Ljs_decode_bad
    ldrb w24, [x20], #1
    cmp w24, #110
    b.ne Ljs_decode_tab
    mov w24, #10
    b Ljs_decode_emit
Ljs_decode_tab:
    cmp w24, #116
    b.ne Ljs_decode_cr
    mov w24, #9
    b Ljs_decode_emit
Ljs_decode_cr:
    cmp w24, #114
    b.ne Ljs_decode_quote
    mov w24, #13
    b Ljs_decode_emit
Ljs_decode_quote:
    cmp w24, #98
    b.ne Ljs_decode_formfeed
    mov w24, #8
    b Ljs_decode_emit
Ljs_decode_formfeed:
    cmp w24, #102
    b.ne Ljs_decode_unicode_test
    mov w24, #12
    b Ljs_decode_emit
Ljs_decode_unicode_test:
    cmp w24, #117
    b.eq Ljs_decode_unicode
    cmp w24, #47
    b.eq Ljs_decode_emit
    cmp w24, #34
    b.eq Ljs_decode_emit
    cmp w24, #39
    b.eq Ljs_decode_emit
    cmp w24, #92
    b.eq Ljs_decode_emit
    b Ljs_decode_bad
Ljs_decode_emit:
    strb w24, [x22, x23]
    add x23, x23, #1
    b Ljs_decode_next
Ljs_decode_unicode:
    mov x25, #0
    mov x26, #4
Ljs_decode_hex:
    cmp x20, x21
    b.hs Ljs_decode_bad
    ldrb w0, [x20], #1
    bl js_hex_digit
    tbnz x0, #63, Ljs_decode_bad
    lsl x25, x25, #4
    orr x25, x25, x0
    sub x26, x26, #1
    cbnz x26, Ljs_decode_hex
    mov x9, #0xd800
    cmp x25, x9
    b.lo Ljs_decode_scalar
    mov x10, #0xdbff
    cmp x25, x10
    b.hi Ljs_decode_low_or_scalar
    add x9, x20, #6
    cmp x9, x21
    b.hi Ljs_decode_replacement
    ldrb w9, [x20]
    cmp w9, #92
    b.ne Ljs_decode_replacement
    ldrb w9, [x20, #1]
    cmp w9, #117
    b.ne Ljs_decode_replacement
    mov x27, x25
    add x20, x20, #2
    mov x25, #0
    mov x26, #4
Ljs_decode_low_hex:
    ldrb w0, [x20], #1
    bl js_hex_digit
    tbnz x0, #63, Ljs_decode_bad
    lsl x25, x25, #4
    orr x25, x25, x0
    sub x26, x26, #1
    cbnz x26, Ljs_decode_low_hex
    mov x9, #0xdc00
    cmp x25, x9
    b.lo Ljs_decode_bad
    mov x10, #0xdfff
    cmp x25, x10
    b.hi Ljs_decode_bad
    sub x25, x25, x9
    mov x9, #0xd800
    sub x27, x27, x9
    add x25, x25, x27, lsl #10
    mov x9, #65536
    add x25, x25, x9
    b Ljs_decode_scalar
Ljs_decode_low_or_scalar:
    mov x9, #0xdfff
    cmp x25, x9
    b.hi Ljs_decode_scalar
Ljs_decode_replacement:
    mov x25, #0xfffd
Ljs_decode_scalar:
    cbz x25, Ljs_decode_bad // embedded NUL strings await a UTF-16 string heap
    cmp x25, #128
    b.lo Ljs_decode_scalar_one
    cmp x25, #2048
    b.lo Ljs_decode_scalar_two
    mov x9, #65536
    cmp x25, x9
    b.lo Ljs_decode_scalar_three
    lsr x9, x25, #18
    orr x9, x9, #0xf0
    strb w9, [x22, x23]
    add x23, x23, #1
    ubfx x9, x25, #12, #6
    orr x9, x9, #0x80
    b Ljs_decode_scalar_tail_two
Ljs_decode_scalar_three:
    lsr x9, x25, #12
    orr x9, x9, #0xe0
Ljs_decode_scalar_tail_two:
    strb w9, [x22, x23]
    add x23, x23, #1
    ubfx x9, x25, #6, #6
    orr x9, x9, #0x80
    b Ljs_decode_scalar_last
Ljs_decode_scalar_two:
    lsr x9, x25, #6
    orr x9, x9, #0xc0
Ljs_decode_scalar_last:
    strb w9, [x22, x23]
    add x23, x23, #1
    and x25, x25, #63
    orr x25, x25, #0x80
Ljs_decode_scalar_one:
    mov x24, x25
    b Ljs_decode_emit
Ljs_decode_copy:
    mov x0, x19
    mov x1, x22
    mov x2, x23
    bl _js_string
Ljs_decode_done:
    LEAVE
Ljs_decode_bad:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_op_se: .asciz "==="
js_op_sn: .asciz "!=="
js_op_e: .asciz "=="
js_op_n: .asciz "!="
js_op_le: .asciz "<="
js_op_ge: .asciz ">="
js_op_and: .asciz "&&"
js_op_or: .asciz "||"
js_op_arrow: .asciz "=>"
js_op_inc: .asciz "++"
js_op_dec: .asciz "--"
js_op_add: .asciz "+="
js_op_sub: .asciz "-="
.section __DATA,__const
.p2align 3
js_operators:
.quad js_op_se,3,T_STRICT_EQ,js_op_sn,3,T_STRICT_NE
.quad js_op_e,2,T_EQ,js_op_n,2,T_NE,js_op_le,2,T_LE,js_op_ge,2,T_GE
.quad js_op_and,2,T_AND,js_op_or,2,T_OR,js_op_arrow,2,T_ARROW
.quad js_op_inc,2,T_INC,js_op_dec,2,T_DEC,js_op_add,2,T_ADD_SET,js_op_sub,2,T_SUB_SET
.quad 0,0,0

.text
js_hex_digit:
    sub x9, x0, #48
    cmp x9, #9
    b.ls Ljs_hex_return
    orr x0, x0, #32
    sub x9, x0, #97
    cmp x9, #5
    b.hi Ljs_hex_bad
    add x9, x9, #10
Ljs_hex_return:
    mov x0, x9
    ret
Ljs_hex_bad:
    mov x0, #-1
    ret
