// Bounded HTML tokenizer and flow-tree builder. Script/style bodies and comments
// are skipped, never interpreted. This deliberately implements a static subset,
// not HTML5 tree construction. Every scan uses an explicit end pointer.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _engine_parse
_engine_parse:
    ENTER
    sub sp, sp, #1024
    mov x20, x0
    cbz x0, Lparse_nil
    mov x9, #ENGINE_MAX_INPUT
    cmp x1, x9
    b.hi Lparse_nil
    add x21, x0, x1
    add x22, x1, #16
    mov x0, #1
    mov x1, #80
    bl _calloc
    cbz x0, Lparse_nil
    mov x19, x0
    str x22, [x19, #40]
    mov x0, #1
    mov x1, x22
    bl _calloc
    str x0, [x19]
    cbz x0, Lparse_error
    mov x0, #ENGINE_MAX_NODES
    mov x1, #40
    bl _calloc
    str x0, [x19, #16]
    cbz x0, Lparse_error
    mov x0, #1
    mov x1, #1025
    bl _calloc
    str x0, [x19, #32]
    cbz x0, Lparse_error
    ldr x9, [x19, #16]
    mov x10, #-1
    str x10, [x9, #8]
    mov x10, #1
    str x10, [x19, #24]
    mov x24, #0                      // current parent index
    mov x25, #1                      // root is on the open-element stack
    mov x26, #0                      // flags: pre=1, title=2
    add x28, sp, #256
    str xzr, [x28]
Lparse_next:
    cmp x20, x21
    b.hs Lparse_finish
    ldrb w9, [x20]
    cmp w9, #60                      // '<'
    b.eq Lparse_tag
    // One text node per uninterrupted text run; entity decoding preserves ranges.
    ldr x22, [x19, #8]
Lparse_text:
    cmp x20, x21
    b.hs Lparse_text_end
    ldrb w9, [x20]
    cmp w9, #60
    b.eq Lparse_text_end
    cmp w9, #38
    b.ne Lparse_literal
    mov x0, x20
    mov x1, x21
    add x2, sp, #144
    bl _engine_entity
    cbz x0, Lparse_literal
    add x20, x20, x0
    mov x2, x1
    add x1, sp, #144
    b Lparse_emit
Lparse_literal:
    mov x1, x20
    mov x2, #1
    add x20, x20, #1
Lparse_emit:
    mov x0, x19
    mov x3, x26
    bl _engine_append
    b Lparse_text
Lparse_text_end:
    ldr x23, [x19, #8]
    cmp x23, x22
    b.eq Lparse_next
    mov x0, x19
    mov x1, #NODE_TEXT
    mov x2, x24
    mov x3, x22
    mov x4, #0
    bl _engine_node
    tbnz x0, #63, Lparse_error
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x0, x10, x9
    str x23, [x9, #24]
    b Lparse_next
Lparse_tag:
    sub x9, x21, x20
    cmp x9, #4
    b.lo Lparse_tag_name
    mov x0, x20
    ADDR x1, comment_open
    mov x2, #4
    bl _memcmp
    cbnz w0, Lparse_tag_name
    add x0, x20, #4
    sub x1, x21, x0
    ADDR x2, comment_close
    mov x3, #3
    bl _memmem
    cbz x0, Lparse_finish
    add x20, x0, #3
    b Lparse_next
Lparse_tag_name:
    add x22, x20, #1
    cmp x22, x21
    b.hs Lparse_less_than
    mov x27, #0                      // closing flag
    ldrb w9, [x22]
    cmp w9, #33
    b.eq Lparse_declaration
    cmp w9, #63
    b.eq Lparse_declaration
    cmp w9, #47
    b.ne Lparse_name_start
    mov x27, #1
    add x22, x22, #1
    b Lparse_name_start
Lparse_declaration:
    str xzr, [sp, #168]
    str x22, [sp, #160]
    mov x23, x22
    mov w10, #0
    b Lparse_tag_end
Lparse_name_start:
    mov x23, x22
Lparse_name_scan:
    cmp x23, x21
    b.hs Lparse_less_than
    ldrb w9, [x23]
    orr w10, w9, #32
    cmp w10, #97
    b.lo Lparse_name_digit
    cmp w10, #122
    b.ls Lparse_name_advance
Lparse_name_digit:
    cmp w9, #48
    b.lo Lparse_name_end
    cmp w9, #57
    b.hi Lparse_name_end
Lparse_name_advance:
    add x23, x23, #1
    b Lparse_name_scan
Lparse_name_end:
    cmp x23, x22
    b.eq Lparse_less_than
    str x23, [sp, #160]              // attributes start
    mov x0, x22
    sub x1, x23, x22
    bl _engine_tag
    str x0, [sp, #168]               // tag type (0=unsupported)
    mov w10, #0                      // quote delimiter
Lparse_tag_end:
    cmp x23, x21
    b.hs Lparse_finish               // unfinished markup is discarded, bounded
    ldrb w9, [x23], #1
    cbz w10, Lparse_quote_start
    cmp w9, w10
    b.ne Lparse_tag_end
    mov w10, #0
    b Lparse_tag_end
Lparse_quote_start:
    cmp w9, #34
    b.eq Lparse_quote
    cmp w9, #39
    b.eq Lparse_quote
    cmp w9, #62
    b.ne Lparse_tag_end
    b Lparse_tag_ready
Lparse_quote:
    mov w10, w9
    b Lparse_tag_end
Lparse_tag_ready:
    sub x9, x23, #1
    str x9, [sp, #176]               // exclusive attribute end (the '>')
    ldr x22, [sp, #168]
    mov x20, x23                    // advance input before dispatch
    cmp x22, #TAG_SCRIPT
    b.eq Lparse_hidden
    cmp x22, #TAG_STYLE
    b.eq Lparse_hidden
    cmp x22, #TAG_TITLE
    b.eq Lparse_title
    tbnz x26, #1, Lparse_next        // unsupported markup inside title is not visible
    cbz x22, Lparse_next
    cmp x22, #TAG_BR
    b.eq Lparse_br
    cmp x22, #TAG_HR
    b.eq Lparse_br
    cbnz x27, Lparse_close
    cmp x22, #NODE_A
    b.eq Lparse_open
    mov x0, x19
    mov x1, #2
    cmp x22, #NODE_LI
    csel x1, xzr, x1, eq
    cbnz x1, Lparse_open_break
    mov x1, #1
Lparse_open_break:
    bl _engine_break
Lparse_open:
    cmp x25, #ENGINE_MAX_DEPTH
    b.hs Lparse_error
    mov x23, #0                      // optional owned href
    cmp x22, #NODE_A
    b.ne Lparse_node_open
    ldr x0, [sp, #160]
    ldr x1, [sp, #176]
    bl _engine_href
    mov x23, x0
Lparse_node_open:
    mov x0, x19
    mov x1, x22
    mov x2, x24
    ldr x3, [x19, #8]
    mov x4, x23
    bl _engine_node
    tbnz x0, #63, Lparse_error
    mov x24, x0
    str x0, [x28, x25, lsl #3]
    add x25, x25, #1
    cmp x22, #NODE_LI
    b.ne Lparse_check_pre
    mov x0, x19
    ADDR x1, list_marker
    mov x2, #4
    mov x3, #0
    bl _engine_append
Lparse_check_pre:
    cmp x22, #NODE_PRE
    b.ne Lparse_next
    orr x26, x26, #1
    b Lparse_next
Lparse_close:
    // Unwind to a matching supported element, ignoring unmatched closing tags.
    mov x23, x25
Lparse_close_find:
    cmp x23, #1
    b.ls Lparse_next
    sub x23, x23, #1
    ldr x9, [x28, x23, lsl #3]
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x9, x11, x10
    ldr x11, [x10]
    cmp x11, x22
    b.ne Lparse_close_find
    ldr x12, [x19, #8]
Lparse_close_unwind:
    sub x25, x25, #1
    ldr x9, [x28, x25, lsl #3]
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x9, x11, x10
    str x12, [x10, #24]
    ldr x11, [x10]
    cmp x11, #NODE_PRE
    b.ne Lparse_unwind_next
    and x26, x26, #-2
Lparse_unwind_next:
    cmp x25, x23
    b.hi Lparse_close_unwind
    sub x9, x25, #1
    ldr x24, [x28, x9, lsl #3]
    cmp x22, #NODE_A
    b.eq Lparse_next
    b Lparse_br
Lparse_br:
    mov x0, x19
    mov x1, #1
    bl _engine_break
    b Lparse_next
Lparse_title:
    cbnz x27, Lparse_title_end
    orr x26, x26, #2
    b Lparse_next
Lparse_title_end:
    and x26, x26, #-3
    b Lparse_next
Lparse_hidden:
    cbnz x27, Lparse_next
    mov x0, x20
    mov x1, x21
    cmp x22, #TAG_SCRIPT
    b.ne Lparse_style
    ADDR x2, script_close
    mov x3, #8
    b Lparse_skip
Lparse_style:
    ADDR x2, style_close
    mov x3, #7
Lparse_skip:
    bl _engine_find_close
    mov x20, x0
    b Lparse_next
Lparse_less_than:
    mov x0, x19
    mov x1, x20
    mov x2, #1
    mov x3, x26
    bl _engine_append
    add x20, x20, #1
    b Lparse_next
Lparse_finish:
    // Finalize all unclosed nodes without walking beyond the bounded stack.
    ldr x22, [x19, #8]
Lparse_finalize_nodes:
    cbz x25, Lparse_success
    sub x25, x25, #1
    ldr x9, [x28, x25, lsl #3]
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x9, x11, x10
    str x22, [x10, #24]
    b Lparse_finalize_nodes
Lparse_success:
    mov x0, x19
    bl _engine_trim_title
    mov x0, x19
    add sp, sp, #1024
    LEAVE
Lparse_error:
    mov x0, x19
    bl _engine_document_free
Lparse_nil:
    mov x0, #0
    add sp, sp, #1024
    LEAVE

// A byte cap must not leave a partial UTF-8 scalar in the title/history record.
_engine_trim_title:
    ENTER
    mov x19, x0
    ldr x20, [x19, #32]
    mov x21, x20
    ldr x9, [x19, #48]
    add x22, x20, x9
Ltitle_validate:
    cmp x21, x22
    b.hs Ltitle_validated
    mov x0, x21
    mov x1, x22
    bl _engine_utf8
    cbz x0, Ltitle_validated
    add x21, x21, x0
    b Ltitle_validate
Ltitle_validated:
    strb wzr, [x21]
    sub x9, x21, x20
    str x9, [x19, #48]
    LEAVE

// Append decoded bytes, collapsing ASCII whitespace unless in a <pre> element.
_engine_append:
    ENTER
    mov x19, x0
    mov x20, x1
    add x21, x1, x2
    mov x22, x3
    tbnz x22, #1, Lappend_title
    ldr x23, [x19]
    ldr x24, [x19, #8]
    ldr x25, [x19, #40]
    sub x25, x25, #1
    b Lappend_loop
Lappend_title:
    ldr x23, [x19, #32]
    ldr x24, [x19, #48]
    mov x25, #1024
Lappend_loop:
    cmp x20, x21
    b.hs Lappend_done
    cmp x24, x25
    b.hs Lappend_done
    ldrb w9, [x20], #1
    cbz w9, Lappend_loop             // embedded NUL is ignored
    tbnz x22, #0, Lappend_byte
    cmp w9, #32
    b.hi Lappend_byte
    cbz x24, Lappend_loop
    sub x10, x24, #1
    ldrb w10, [x23, x10]
    cmp w10, #32
    b.ls Lappend_loop
    mov w9, #32
Lappend_byte:
    strb w9, [x23, x24]
    add x24, x24, #1
    b Lappend_loop
Lappend_done:
    strb wzr, [x23, x24]
    tbnz x22, #1, Lappend_title_length
    str x24, [x19, #8]
    LEAVE
Lappend_title_length:
    str x24, [x19, #48]
    LEAVE

_engine_break:
    ldr x2, [x0]
    ldr x3, [x0, #8]
    cbz x3, Lbreak_return
Lbreak_count:
    mov x4, x3
    mov x6, #0
Lbreak_scan:
    cbz x4, Lbreak_insert
    sub x4, x4, #1
    ldrb w5, [x2, x4]
    cmp w5, #10
    b.ne Lbreak_insert
    add x6, x6, #1
    b Lbreak_scan
Lbreak_insert:
    cmp x6, x1
    b.hs Lbreak_save
    ldr x4, [x0, #40]
    sub x4, x4, #1
    cmp x3, x4
    b.hs Lbreak_save
    mov w5, #10
    strb w5, [x2, x3]
    add x3, x3, #1
    add x6, x6, #1
    b Lbreak_insert
Lbreak_save:
    str x3, [x0, #8]
    strb wzr, [x2, x3]
Lbreak_return:
    ret

// Add node; takes ownership of href even on failure.
_engine_node:
    ldr x5, [x0, #24]
    cmp x5, #ENGINE_MAX_NODES
    b.hs Lnode_full
    ldr x6, [x0, #16]
    mov x7, #40
    madd x6, x5, x7, x6
    stp x1, x2, [x6]
    stp x3, x3, [x6, #16]
    str x4, [x6, #32]
    add x7, x5, #1
    str x7, [x0, #24]
    mov x0, x5
    ret
Lnode_full:
    ENTER
    mov x0, x4
    bl _free
    mov x0, #-1
    LEAVE

.globl _engine_document_free
_engine_document_free:
    cbz x0, Lfree_return
    ENTER
    mov x19, x0
    ldr x20, [x19, #16]
    ldr x21, [x19, #24]
    cbz x20, Lfree_buffers
Lfree_nodes:
    cbz x21, Lfree_buffers
    ldr x0, [x20, #32]
    bl _free
    add x20, x20, #40
    sub x21, x21, #1
    b Lfree_nodes
Lfree_buffers:
    ldr x0, [x19]
    bl _free
    ldr x0, [x19, #16]
    bl _free
    ldr x0, [x19, #32]
    bl _free
    mov x0, x19
    bl _free
    LEAVE
Lfree_return:
    ret

// Resolve supported tag names without allocating or requiring a NUL terminator.
_engine_tag:
    ENTER
    mov x19, x0
    mov x20, x1
    ADDR x21, tag_table
Ltag_next:
    ldr x1, [x21]
    cbz x1, Ltag_unknown
    ldr x9, [x21, #8]
    cmp x9, x20
    b.ne Ltag_advance
    mov x0, x19
    mov x2, x20
    bl _strncasecmp
    cbz w0, Ltag_found
Ltag_advance:
    add x21, x21, #24
    b Ltag_next
Ltag_found:
    ldr x0, [x21, #16]
    LEAVE
Ltag_unknown:
    mov x0, #0
    LEAVE

_engine_find_close:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
Lfind_loop:
    sub x9, x20, x19
    cmp x9, x22
    b.lo Lfind_end
    ldrb w9, [x19]
    cmp w9, #60
    b.ne Lfind_advance
    mov x0, x19
    mov x1, x21
    mov x2, x22
    bl _strncasecmp
    cbnz w0, Lfind_advance
    add x9, x19, x22
    cmp x9, x20
    b.hs Lfind_end
    ldrb w9, [x9]
    cmp w9, #62
    b.eq Lfind_found
    cmp w9, #32
    b.ls Lfind_found
Lfind_advance:
    add x19, x19, #1
    b Lfind_loop
Lfind_end:
    mov x19, x20
Lfind_found:
    mov x0, x19
    LEAVE

.section __DATA,__const
.p2align 3
tag_table:
.quad tag_p, 1, NODE_P
.quad tag_h1, 2, NODE_H1
.quad tag_h2, 2, NODE_H2
.quad tag_h3, 2, NODE_H3
.quad tag_a, 1, NODE_A
.quad tag_pre, 3, NODE_PRE
.quad tag_li, 2, NODE_LI
.quad tag_div, 3, NODE_DIV
.quad tag_ul, 2, NODE_UL
.quad tag_ol, 2, NODE_OL
.quad tag_quote, 10, NODE_QUOTE
.quad tag_br, 2, TAG_BR
.quad tag_hr, 2, TAG_HR
.quad tag_title, 5, TAG_TITLE
.quad tag_script, 6, TAG_SCRIPT
.quad tag_style, 5, TAG_STYLE
.quad 0, 0, 0
.section __TEXT,__cstring,cstring_literals
list_marker: .asciz "• "
tag_p: .asciz "p"
tag_h1: .asciz "h1"
tag_h2: .asciz "h2"
tag_h3: .asciz "h3"
tag_a: .asciz "a"
tag_pre: .asciz "pre"
tag_li: .asciz "li"
tag_div: .asciz "div"
tag_ul: .asciz "ul"
tag_ol: .asciz "ol"
tag_quote: .asciz "blockquote"
tag_br: .asciz "br"
tag_hr: .asciz "hr"
tag_title: .asciz "title"
tag_script: .asciz "script"
tag_style: .asciz "style"
comment_open: .asciz "<!--"
comment_close: .asciz "-->"
script_close: .asciz "</script"
style_close: .asciz "</style"
