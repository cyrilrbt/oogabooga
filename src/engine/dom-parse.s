// Persistent, bounded HTML tree construction. Retains unknown elements,
// attributes, hidden subtrees, comments, and inert raw script/style contents.
// This is a recovery subset, not the full HTML5 insertion-mode algorithm.
.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// bounded token,length,lowercase literal -> boolean.
dom_token_equal:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x0, x2
    bl _strlen
    cmp x0, x20
    b.ne Ltoken_no
    mov x0, x19
    mov x1, x21
    mov x2, x20
    bl _strncasecmp
    cmp w0, #0
    cset x0, eq
    LEAVE
Ltoken_no:
    mov x0, #0
    LEAVE

.globl _engine_dom_parse
_engine_dom_parse:
    ENTER
    sub sp, sp, #1024
    mov x20, x0
    str x0, [sp, #624]
    add x21, x0, x1
    bl _dom_valid_text
    cbz x0, Ldom_parse_nil
    bl _engine_dom_new
    cbz x0, Ldom_parse_nil
    mov x19, x0
    mov x24, #0
Ldom_parse_implied:
    ADDR x9, dom_implied_tags
    ldr x25, [x9, x24, lsl #3]
    mov x0, x25
    bl _strlen
    mov x2, x0
    mov x0, x19
    mov x1, x25
    bl _engine_dom_create_element
    cbz x0, Ldom_parse_fail
    mov x2, x0
    mov x0, x19
    mov x1, #2
    cmp x24, #0
    b.ne Ldom_parse_implied_attach
    mov x1, #1
Ldom_parse_implied_attach:
    mov x3, #0
    bl _engine_dom_insert_before
    cbnz x0, Ldom_parse_fail
    add x24, x24, #1
    cmp x24, #3
    b.lo Ldom_parse_implied
    mov x9, #1
    str x9, [sp]
    mov x9, #2
    str x9, [sp, #8]
Ldom_parse_body:
    mov x22, #4
    str x22, [sp, #16]
    mov x23, #3
Ldom_parse_next:
    cmp x20, x21
    b.hs Ldom_parse_done
    ldrb w9, [x20]
    cmp w9, #60
    b.eq Ldom_parse_tag
    mov x24, x20
Ldom_parse_text:
    cmp x20, x21
    b.hs Ldom_parse_text_end
    ldrb w9, [x20]
    cmp w9, #60
    b.eq Ldom_parse_text_end
    add x20, x20, #1
    b Ldom_parse_text
Ldom_parse_text_end:
    mov x0, x19
    mov x1, x22
    mov x2, x24
    mov x3, x20
    mov x4, #1
    mov x5, #DOM_TEXT
    bl _dom_parse_data
    cbnz x0, Ldom_parse_fail
    mov x0, x19
    ldr x9, [sp, #624]
    sub x2, x24, x9
    bl _dom_stamp
    b Ldom_parse_next
Ldom_parse_tag:
    sub x9, x21, x20
    cmp x9, #4
    b.lo Ldom_parse_tag_start
    mov x0, x20
    ADDR x1, dom_comment_prefix
    mov x2, #4
    bl _memcmp
    cbz w0, Ldom_parse_comment
Ldom_parse_tag_start:
    add x24, x20, #1
    cmp x24, x21
    b.hs Ldom_parse_literal
    ldrb w9, [x24]
    cmp w9, #33
    b.eq Ldom_parse_declaration
    cmp w9, #63
    b.eq Ldom_parse_declaration
    mov x25, #0
    cmp w9, #47
    b.ne Ldom_parse_name_start
    mov x25, #1
    add x24, x24, #1
    cmp x24, x21
    b.hs Ldom_parse_literal
    ldrb w9, [x24]
Ldom_parse_name_start:
    orr w9, w9, #32
    sub w9, w9, #97
    cmp w9, #25
    b.hi Ldom_parse_literal
    str x24, [sp, #512]
    str x25, [sp, #536]
Ldom_parse_name:
    cmp x24, x21
    b.hs Ldom_parse_truncated
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Ldom_parse_name_end
    cmp w9, #47
    b.eq Ldom_parse_name_end
    cmp w9, #62
    b.eq Ldom_parse_name_end
    add x24, x24, #1
    b Ldom_parse_name
Ldom_parse_name_end:
    str x24, [sp, #520]
    mov x0, x24
    mov x1, x21
    bl _dom_tag_end
    cbz x0, Ldom_parse_truncated
    str x0, [sp, #528]
    ldr x9, [sp, #536]
    cbnz x9, Ldom_parse_end_tag
    // Explicit html/head/body tags attach to their implied persistent nodes.
    ldr x0, [sp, #512]
    ldr x1, [sp, #520]
    sub x1, x1, x0
    ADDR x2, dom_html_name
    bl dom_token_equal
    mov x24, #2
    cbnz x0, Ldom_parse_attributes
    ldr x0, [sp, #512]
    ldr x1, [sp, #520]
    sub x1, x1, x0
    ADDR x2, dom_head_name
    bl dom_token_equal
    cbz x0, Ldom_parse_body_tag
    mov x22, #3
    mov x23, #3
    str x22, [sp, #16]
    mov x24, #3
    b Ldom_parse_attributes
Ldom_parse_body_tag:
    ldr x0, [sp, #512]
    ldr x1, [sp, #520]
    sub x1, x1, x0
    ADDR x2, dom_body_name
    bl dom_token_equal
    cbz x0, Ldom_parse_element
    mov x22, #4
    mov x23, #3
    str x22, [sp, #16]
    mov x24, #4
    b Ldom_parse_attributes
Ldom_parse_element:
    mov x0, x19
    ldr x1, [sp, #512]
    ldr x2, [sp, #520]
    sub x2, x2, x1
    bl _engine_dom_create_element
    cbz x0, Ldom_parse_fail
    mov x24, x0
    mov x2, x0
    mov x0, x19
    mov x1, x22
    mov x3, #0
    bl _engine_dom_insert_before
    cbnz x0, Ldom_parse_fail
Ldom_parse_attributes:
    mov x0, x19
    mov x1, x24
    ldr x2, [sp, #520]
    ldr x3, [sp, #528]
    bl _dom_parse_attributes
    cbnz x0, Ldom_parse_fail
    mov x0, x19
    mov x1, x24
    ldr x2, [sp, #512]
    ldr x9, [sp, #624]
    sub x2, x2, x9
    sub x2, x2, #1
    bl _dom_stamp
    ldr x20, [sp, #528]
    add x20, x20, #1
    cmp x24, #4
    b.ls Ldom_parse_next
    mov x0, x19
    mov x1, x24
    bl _engine_dom_node
    ldr x25, [x0, #48]
    mov x0, x25
    bl _dom_is_void
    cbnz x0, Ldom_parse_next
    cmp x23, #DOM_MAX_DEPTH
    b.hs Ldom_parse_fail
    str x24, [sp, x23, lsl #3]
    add x23, x23, #1
    mov x22, x24
    mov x0, x25
    ADDR x1, dom_script_name
    bl _strcmp
    cbz w0, Ldom_parse_raw
    mov x0, x25
    ADDR x1, dom_style_name
    bl _strcmp
    cbz w0, Ldom_parse_raw
    mov x0, x25
    ADDR x1, dom_textarea_name
    bl _strcmp
    cbz w0, Ldom_parse_rcdata
    mov x0, x25
    ADDR x1, dom_title_name
    bl _strcmp
    cbnz w0, Ldom_parse_next
Ldom_parse_rcdata:
    mov x26, #1
    b Ldom_parse_raw_scan
Ldom_parse_raw:
    mov x26, #0
Ldom_parse_raw_scan:
    mov x0, x20
    mov x1, x21
    mov x2, x25
    bl _dom_raw_end
    mov x27, x0
    mov x0, x19
    mov x1, x22
    mov x2, x20
    mov x3, x27
    mov x4, x26
    mov x5, #DOM_TEXT
    bl _dom_parse_data
    cbnz x0, Ldom_parse_fail
    mov x0, x19
    ldr x9, [sp, #624]
    sub x2, x20, x9
    bl _dom_stamp
    mov x20, x27
    b Ldom_parse_next
Ldom_parse_end_tag:
    ldr x20, [sp, #528]
    add x20, x20, #1
    ldr x0, [sp, #512]
    ldr x1, [sp, #520]
    sub x1, x1, x0
    ADDR x2, dom_head_name
    bl dom_token_equal
    cbnz x0, Ldom_parse_body
    sub x24, x23, #1
Ldom_parse_end_search:
    cmp x24, #3
    b.lo Ldom_parse_next
    ldr x1, [sp, x24, lsl #3]
    mov x0, x19
    bl _engine_dom_node
    ldr x2, [x0, #48]
    ldr x0, [sp, #512]
    ldr x1, [sp, #520]
    sub x1, x1, x0
    bl dom_token_equal
    cbnz x0, Ldom_parse_pop
    sub x24, x24, #1
    b Ldom_parse_end_search
Ldom_parse_pop:
    mov x23, x24
    sub x9, x23, #1
    ldr x22, [sp, x9, lsl #3]
    b Ldom_parse_next
Ldom_parse_literal:
    mov x24, x20
    add x20, x20, #1
    b Ldom_parse_text_end
Ldom_parse_truncated:
    mov x24, x20
    mov x20, x21
    b Ldom_parse_text_end
Ldom_parse_declaration:
    mov x0, x24
    mov x1, x21
    bl _dom_tag_end
    cbz x0, Ldom_parse_truncated
    add x20, x0, #1
    b Ldom_parse_next
Ldom_parse_comment:
    add x24, x20, #4
    mov x25, x24
Ldom_parse_comment_scan:
    add x9, x25, #2
    cmp x9, x21
    b.hs Ldom_parse_comment_eof
    ldrb w9, [x25]
    cmp w9, #45
    b.ne Ldom_parse_comment_advance
    ldrb w9, [x25, #1]
    cmp w9, #45
    b.ne Ldom_parse_comment_advance
    ldrb w9, [x25, #2]
    cmp w9, #62
    b.eq Ldom_parse_comment_end
Ldom_parse_comment_advance:
    add x25, x25, #1
    b Ldom_parse_comment_scan
Ldom_parse_comment_eof:
    mov x25, x21
    mov x20, x21
    b Ldom_parse_comment_data
Ldom_parse_comment_end:
    add x20, x25, #3
Ldom_parse_comment_data:
    mov x0, x19
    mov x1, x22
    mov x2, x24
    mov x3, x25
    mov x4, #0
    mov x5, #DOM_COMMENT
    bl _dom_parse_data
    cbnz x0, Ldom_parse_fail
    mov x0, x19
    ldr x9, [sp, #624]
    sub x2, x24, x9
    bl _dom_stamp
    b Ldom_parse_next
Ldom_parse_done:
    mov x0, x19
    add sp, sp, #1024
    LEAVE
Ldom_parse_fail:
    mov x0, x19
    bl _engine_dom_free
Ldom_parse_nil:
    mov x0, #0
    add sp, sp, #1024
    LEAVE
.section __TEXT,__cstring,cstring_literals
dom_html_name: .asciz "html"
dom_head_name: .asciz "head"
dom_body_name: .asciz "body"
dom_script_name: .asciz "script"
dom_style_name: .asciz "style"
dom_textarea_name: .asciz "textarea"
dom_title_name: .asciz "title"
dom_comment_prefix: .asciz "<!--"
.section __DATA,__const
.p2align 3
dom_implied_tags: .quad dom_html_name,dom_head_name,dom_body_name
