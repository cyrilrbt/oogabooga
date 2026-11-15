.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// doc,source,length -> owned entity-decoded UTF-8 string, length in x1.
.globl _dom_decode
_dom_decode:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _dom_copy
    cbz x0, Ldecode_fail
    mov x22, x0
    mov x23, #0
    mov x24, #0
Ldecode_next:
    cmp x23, x21
    b.hs Ldecode_done
    ldrb w9, [x20, x23]
    cmp w9, #38
    b.ne Ldecode_byte
    add x0, x20, x23
    add x1, x20, x21
    add x2, sp, #144
    bl _engine_entity
    cbz x0, Ldecode_literal
    add x23, x23, x0
    mov x25, x1
    add x0, x22, x24
    add x1, sp, #144
    mov x2, x25
    bl _memcpy
    add x24, x24, x25
    b Ldecode_next
Ldecode_literal:
    ldrb w9, [x20, x23]
Ldecode_byte:
    strb w9, [x22, x24]
    add x23, x23, #1
    add x24, x24, #1
    b Ldecode_next
Ldecode_done:
    strb wzr, [x22, x24]
    ldr x9, [x19, #32]
    sub x10, x21, x24
    sub x9, x9, x10
    str x9, [x19, #32]
    mov x0, x22
    mov x1, x24
    bl _dom_valid_text
    cbz x0, Ldecode_invalid
    mov x0, x22
    mov x1, x24
    LEAVE
Ldecode_invalid:
    // Account by known length even if malformed data contains an embedded NUL.
    ldr x9, [x19, #32]
    sub x9, x9, x24
    sub x9, x9, #1
    str x9, [x19, #32]
    mov x0, x22
    bl _free
Ldecode_fail:
    mov x0, #0
    mov x1, #0
    LEAVE

.globl _dom_skip_space
_dom_skip_space:
    cmp x0, x1
    b.hs Lskip_space_done
    ldrb w9, [x0]
    cmp w9, #32
    b.hi Lskip_space_done
    add x0, x0, #1
    b _dom_skip_space
Lskip_space_done:
    ret

// start,end -> unquoted '>' or nil for a truncated start tag.
.globl _dom_tag_end
_dom_tag_end:
    mov w2, #0
Ltag_end_next:
    cmp x0, x1
    b.hs Ltag_end_nil
    ldrb w9, [x0]
    cbz w2, Ltag_end_unquoted
    cmp w9, w2
    b.ne Ltag_end_advance
    mov w2, #0
    b Ltag_end_advance
Ltag_end_unquoted:
    cmp w9, #62
    b.eq Ltag_end_done
    cmp w9, #34
    b.eq Ltag_end_quote
    cmp w9, #39
    b.ne Ltag_end_advance
Ltag_end_quote:
    mov w2, w9
Ltag_end_advance:
    add x0, x0, #1
    b Ltag_end_next
Ltag_end_nil:
    mov x0, #0
Ltag_end_done:
    ret

// doc,parent,start,end,decode?,type -> 0/-1; empty runs create no node.
.globl _dom_parse_data
_dom_parse_data:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    sub x22, x3, x2
    mov x23, x4
    mov x24, x5
    cbnz x22, Lparse_data_nonempty
    cmp x24, #DOM_COMMENT
    b.ne Lparse_data_ok
Lparse_data_nonempty:
    mov x0, x19
    mov x1, x21
    mov x2, x22
    cbz x23, Lparse_data_raw
    bl _dom_decode
    b Lparse_data_owned
Lparse_data_raw:
    mov x0, x21
    mov x1, x22
    bl _dom_valid_text
    cbz x0, Lparse_data_fail
    mov x0, x19
    mov x1, x21
    mov x2, x22
    bl _dom_copy
Lparse_data_owned:
    cbz x0, Lparse_data_fail
    mov x25, x0
    mov x3, x0
    mov x0, x19
    mov x1, x24
    mov x2, #0
    bl _dom_allocate
    cbz x0, Lparse_data_allocate_fail
    mov x2, x0
    mov x26, x0
    mov x0, x19
    mov x1, x20
    mov x3, #0
    bl _engine_dom_insert_before
    mov x1, x26
    LEAVE
Lparse_data_allocate_fail:
    mov x0, x19
    mov x1, x25
    bl _dom_string_free
Lparse_data_fail:
    mov x0, #-1
    LEAVE
Lparse_data_ok:
    mov x0, #0
    mov x1, #0
    LEAVE

// doc,element,attribute start,end-at-'>' -> 0/-1. First duplicate wins.
.globl _dom_parse_attributes
_dom_parse_attributes:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x27, #0
    mov x28, #0
Lparse_attr_next:
    mov x0, x21
    mov x1, x22
    bl _dom_skip_space
    mov x21, x0
    cmp x21, x22
    b.hs Lparse_attr_ok
    ldrb w9, [x21]
    cmp w9, #47
    b.ne Lparse_attr_name_start
    add x21, x21, #1
    b Lparse_attr_next
Lparse_attr_name_start:
    mov x23, x21
Lparse_attr_name:
    cmp x21, x22
    b.hs Lparse_attr_name_end
    ldrb w9, [x21]
    cmp w9, #32
    b.ls Lparse_attr_name_end
    cmp w9, #61
    b.eq Lparse_attr_name_end
    cmp w9, #47
    b.eq Lparse_attr_name_end
    add x21, x21, #1
    b Lparse_attr_name
Lparse_attr_name_end:
    cmp x21, x23
    b.eq Lparse_attr_fail
    mov x24, x21
    mov x0, x21
    mov x1, x22
    bl _dom_skip_space
    mov x21, x0
    mov x25, x21
    mov x26, x21
    cmp x21, x22
    b.hs Lparse_attr_value_ready
    ldrb w9, [x21]
    cmp w9, #61
    b.ne Lparse_attr_value_ready
    add x0, x21, #1
    mov x1, x22
    bl _dom_skip_space
    mov x21, x0
    mov x25, x0
    cmp x21, x22
    b.hs Lparse_attr_value_empty
    ldrb w10, [x21]
    cmp w10, #34
    b.eq Lparse_attr_quote
    cmp w10, #39
    b.ne Lparse_attr_unquoted
Lparse_attr_quote:
    add x21, x21, #1
    mov x25, x21
Lparse_attr_quote_scan:
    cmp x21, x22
    b.hs Lparse_attr_fail
    ldrb w9, [x21]
    cmp w9, w10
    b.eq Lparse_attr_quote_end
    add x21, x21, #1
    b Lparse_attr_quote_scan
Lparse_attr_quote_end:
    mov x26, x21
    add x21, x21, #1
    b Lparse_attr_value_ready
Lparse_attr_unquoted:
    cmp x21, x22
    b.hs Lparse_attr_value_empty
    ldrb w9, [x21]
    cmp w9, #32
    b.ls Lparse_attr_value_empty
    add x21, x21, #1
    b Lparse_attr_unquoted
Lparse_attr_value_empty:
    mov x26, x21
Lparse_attr_value_ready:
    mov x0, x19
    mov x1, x23
    sub x2, x24, x23
    bl _dom_name
    cbz x0, Lparse_attr_next   // unsupported malformed names do not poison DOM
    mov x27, x0
    mov x0, x19
    mov x1, x20
    mov x2, x27
    bl _engine_dom_get_attribute
    cbnz x0, Lparse_attr_free_name
    mov x0, x19
    mov x1, x25
    sub x2, x26, x25
    bl _dom_decode
    cbz x0, Lparse_attr_fail
    mov x28, x0
    mov x4, x1
    mov x3, x0
    mov x0, x19
    mov x1, x20
    mov x2, x27
    bl _engine_dom_set_attribute
    str x0, [sp, #144]
    mov x0, x19
    mov x1, x28
    bl _dom_string_free
    mov x28, #0
    ldr x9, [sp, #144]
    cbnz x9, Lparse_attr_fail
Lparse_attr_free_name:
    mov x0, x19
    mov x1, x27
    bl _dom_string_free
    mov x27, #0
    b Lparse_attr_next
Lparse_attr_fail:
    mov x0, x19
    mov x1, x27
    bl _dom_string_free
    mov x0, x19
    mov x1, x28
    bl _dom_string_free
    mov x0, #-1
    LEAVE
Lparse_attr_ok:
    mov x0, #0
    LEAVE

// source,end,lowercase tag name -> matching raw-text closing tag or end.
.globl _dom_raw_end
_dom_raw_end:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x0, x2
    bl _strlen
    mov x22, x0
Lraw_next:
    add x9, x19, x22
    add x9, x9, #2
    cmp x9, x20
    b.hs Lraw_eof
    ldrb w9, [x19]
    cmp w9, #60
    b.ne Lraw_advance
    ldrb w9, [x19, #1]
    cmp w9, #47
    b.ne Lraw_advance
    add x0, x19, #2
    mov x1, x21
    mov x2, x22
    bl _strncasecmp
    cbnz w0, Lraw_advance
    add x9, x19, x22
    ldrb w9, [x9, #2]
    cmp w9, #32
    b.ls Lraw_found
    cmp w9, #62
    b.eq Lraw_found
    cmp w9, #47
    b.eq Lraw_found
Lraw_advance:
    add x19, x19, #1
    b Lraw_next
Lraw_eof:
    mov x19, x20
Lraw_found:
    mov x0, x19
    LEAVE
