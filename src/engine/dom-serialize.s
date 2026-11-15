.include "src/mac/mac.inc"
.include "src/engine/dom.inc"
.text
.p2align 2
// Bounded HTML snapshot builder. Context: data,len,capacity,error,depth.
.globl _dom_emit
_dom_emit:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x19, #24]
    cbnz x9, Lemit_fail
    ldr x9, [x19, #8]
    adds x22, x9, x21
    b.cs Lemit_fail
    mov x10, #1048576
    cmp x22, x10
    b.hi Lemit_fail
    add x23, x22, #1
    ldr x24, [x19, #16]
    cmp x23, x24
    b.ls Lemit_copy
    mov x9, #4096
    cmp x24, x9
    csel x24, x9, x24, lo
Lemit_grow:
    cmp x24, x23
    b.hs Lemit_realloc
    lsl x24, x24, #1
    b Lemit_grow
Lemit_realloc:
    ldr x0, [x19]
    mov x1, x24
    bl _realloc
    cbz x0, Lemit_fail
    str x0, [x19]
    str x24, [x19, #16]
Lemit_copy:
    ldr x0, [x19]
    ldr x9, [x19, #8]
    add x0, x0, x9
    mov x1, x20
    mov x2, x21
    cbz x21, Lemit_end
    bl _memcpy
Lemit_end:
    ldr x9, [x19]
    strb wzr, [x9, x22]
    str x22, [x19, #8]
    mov x0, #0
    LEAVE
Lemit_fail:
    mov x9, #1
    str x9, [x19, #24]
    mov x0, #-1
    LEAVE

dom_emit_string:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x1
    bl _strlen
    mov x2, x0
    mov x0, x19
    mov x1, x20
    bl _dom_emit
    LEAVE

// Escape text and double-quoted attribute values without changing UTF-8.
dom_escape:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x1
Lescape_scan:
    ldrb w9, [x20]
    cbz w9, Lescape_finish
    ADDR x22, dom_amp
    mov x23, #5
    cmp w9, #38
    b.eq Lescape_entity
    ADDR x22, dom_lt
    mov x23, #4
    cmp w9, #60
    b.eq Lescape_entity
    ADDR x22, dom_gt
    cmp w9, #62
    b.eq Lescape_entity
    ADDR x22, dom_quot
    mov x23, #6
    cmp w9, #34
    b.eq Lescape_entity
    add x20, x20, #1
    b Lescape_scan
Lescape_entity:
    mov x0, x19
    mov x1, x21
    sub x2, x20, x21
    bl _dom_emit
    cbnz x0, Lescape_done
    mov x0, x19
    mov x1, x22
    mov x2, x23
    bl _dom_emit
    cbnz x0, Lescape_done
    add x20, x20, #1
    mov x21, x20
    b Lescape_scan
Lescape_finish:
    mov x0, x19
    mov x1, x21
    sub x2, x20, x21
    bl _dom_emit
Lescape_done:
    LEAVE

.globl _dom_is_void
_dom_is_void:
    ENTER
    mov x19, x0
    ADDR x20, dom_void_names
Lvoid_next:
    ldr x1, [x20], #8
    cbz x1, Lvoid_no
    mov x0, x19
    bl _strcmp
    cbnz w0, Lvoid_next
    mov x0, #1
    LEAVE
Lvoid_no:
    mov x0, #0
    LEAVE

// doc,handle,builder -> 0/-1. Only connected descendants are serialized.
dom_serialize_node:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x21, #32]
    add x9, x9, #1
    str x9, [x21, #32]
    cmp x9, #DOM_MAX_DEPTH
    b.hi Lserialize_bad
    bl _engine_dom_node
    cbz x0, Lserialize_bad
    mov x22, x0
    ldr x9, [x22]
    cmp x9, #DOM_DOCUMENT
    b.eq Lserialize_type_ready
    ldr x10, [x21, #8]
    str x10, [x22, #80]
    ldr x10, [x19, #24]
    str x10, [x22, #88]
Lserialize_type_ready:
    cmp x9, #DOM_DOCUMENT
    b.eq Lserialize_children
    cmp x9, #DOM_TEXT
    b.eq Lserialize_text
    cmp x9, #DOM_COMMENT
    b.eq Lserialize_comment
    cmp x9, #DOM_ELEMENT
    b.ne Lserialize_bad
    mov x0, x21
    ADDR x1, dom_open
    bl dom_emit_string
    mov x0, x21
    ldr x1, [x22, #48]
    bl dom_emit_string
    ldr x23, [x22, #64]
Lserialize_attribute:
    cbz x23, Lserialize_tag_end
    mov x0, x21
    ADDR x1, dom_space
    bl dom_emit_string
    mov x0, x21
    ldr x1, [x23]
    bl dom_emit_string
    mov x0, x21
    ADDR x1, dom_equals
    bl dom_emit_string
    mov x0, x21
    ldr x1, [x23, #8]
    bl dom_escape
    mov x0, x21
    ADDR x1, dom_quote
    bl dom_emit_string
    ldr x23, [x23, #16]
    b Lserialize_attribute
Lserialize_tag_end:
    mov x0, x21
    ADDR x1, dom_close
    bl dom_emit_string
    ldr x0, [x22, #48]
    bl _dom_is_void
    cbnz x0, Lserialize_ok
Lserialize_children:
    ldr x23, [x22, #16]
Lserialize_child:
    cbz x23, Lserialize_end_tag
    mov x0, x19
    mov x1, x23
    mov x2, x21
    bl dom_serialize_node
    cbnz x0, Lserialize_bad
    mov x0, x19
    mov x1, x23
    bl _engine_dom_node
    ldr x23, [x0, #40]
    b Lserialize_child
Lserialize_end_tag:
    ldr x9, [x22]
    cmp x9, #DOM_DOCUMENT
    b.eq Lserialize_ok
    mov x0, x21
    ADDR x1, dom_end_open
    bl dom_emit_string
    mov x0, x21
    ldr x1, [x22, #48]
    bl dom_emit_string
    mov x0, x21
    ADDR x1, dom_close
    bl dom_emit_string
    b Lserialize_ok
Lserialize_text:
    mov x0, x19
    ldr x1, [x22, #8]
    bl _engine_dom_node
    cbz x0, Lserialize_escaped
    ldr x23, [x0, #48]
    cbz x23, Lserialize_escaped
    mov x0, x23
    ADDR x1, dom_style
    bl _strcmp
    cbz w0, Lserialize_raw_style
    mov x0, x23
    ADDR x1, dom_script
    bl _strcmp
    cbnz w0, Lserialize_escaped
    ADDR x1, dom_script_end
    b Lserialize_raw
Lserialize_raw_style:
    ADDR x1, dom_style_end
Lserialize_raw:
    ldr x0, [x22, #56]
    bl _strcasestr
    cbnz x0, Lserialize_bad
    mov x0, x21
    ldr x1, [x22, #56]
    bl dom_emit_string
    b Lserialize_ok
Lserialize_escaped:
    mov x0, x21
    ldr x1, [x22, #56]
    bl dom_escape
    b Lserialize_ok
Lserialize_comment:
    ldr x0, [x22, #56]
    ADDR x1, dom_comment_close
    bl _strstr
    cbnz x0, Lserialize_bad
    mov x0, x21
    ADDR x1, dom_comment_open
    bl dom_emit_string
    mov x0, x21
    ldr x1, [x22, #56]
    bl dom_emit_string
    mov x0, x21
    ADDR x1, dom_comment_close
    bl dom_emit_string
Lserialize_ok:
    ldr x0, [x21, #24]
    neg x0, x0
    b Lserialize_leave
Lserialize_bad:
    mov x9, #1
    str x9, [x21, #24]
    mov x0, #-1
Lserialize_leave:
    ldr x9, [x21, #32]
    sub x9, x9, #1
    str x9, [x21, #32]
    LEAVE

// doc,out_length* -> owned HTML snapshot or nil; no persistent node is changed.
.globl _engine_dom_serialize
_engine_dom_serialize:
    ENTER
    sub sp, sp, #64
    mov x19, x0
    mov x20, x1
    cbz x20, Lsnapshot_init
    str xzr, [x20]
Lsnapshot_init:
    stp xzr, xzr, [sp]
    stp xzr, xzr, [sp, #16]
    str xzr, [sp, #32]
    cbz x19, Lsnapshot_fail
    mov x0, x19
    mov x1, #1
    mov x2, sp
    bl dom_serialize_node
    cbnz x0, Lsnapshot_fail
    mov x0, sp
    ADDR x1, dom_empty
    mov x2, #0
    bl _dom_emit
    cbnz x0, Lsnapshot_fail
    cbz x20, Lsnapshot_done
    ldr x9, [sp, #8]
    str x9, [x20]
Lsnapshot_done:
    ldr x0, [sp]
    add sp, sp, #64
    LEAVE
Lsnapshot_fail:
    ldr x0, [sp]
    bl _free
    mov x0, #0
    add sp, sp, #64
    LEAVE

// Adapter to the existing flow renderer. Ownership of the returned snapshot
// follows engine_parse; the persistent DOM and its handles remain unchanged.
.globl _engine_dom_snapshot
_engine_dom_snapshot:
    ENTER
    mov x21, x0
    mov x1, #0
    bl _engine_dom_serialize
    cbz x0, Lsnapshot_flow_done
    mov x19, x0
    bl _strlen
    mov x1, x0
    mov x0, x19
    bl _engine_parse
    mov x20, x0
    cbz x0, Lsnapshot_flow_free_html
    ldr x0, [x20, #96]
    bl _engine_dom_free
    mov x0, x21
    bl _engine_dom_retain
    str x0, [x20, #96]
    mov x1, x20
    bl _engine_dom_bind_flow
Lsnapshot_flow_free_html:
    mov x0, x19
    bl _free
    mov x0, x20
Lsnapshot_flow_done:
    LEAVE

.section __TEXT,__cstring,cstring_literals
dom_open: .asciz "<"
dom_close: .asciz ">"
dom_end_open: .asciz "</"
dom_space: .asciz " "
dom_equals: .asciz "=\""
dom_quote: .asciz "\""
dom_empty: .asciz ""
dom_amp: .asciz "&amp;"
dom_lt: .asciz "&lt;"
dom_gt: .asciz "&gt;"
dom_quot: .asciz "&quot;"
dom_style: .asciz "style"
dom_script: .asciz "script"
dom_style_end: .asciz "</style"
dom_script_end: .asciz "</script"
dom_comment_open: .asciz "<!--"
dom_comment_close: .asciz "-->"
dom_area: .asciz "area"
dom_base: .asciz "base"
dom_br: .asciz "br"
dom_col: .asciz "col"
dom_embed: .asciz "embed"
dom_hr: .asciz "hr"
dom_img: .asciz "img"
dom_input: .asciz "input"
dom_link: .asciz "link"
dom_meta: .asciz "meta"
dom_param: .asciz "param"
dom_source: .asciz "source"
dom_track: .asciz "track"
dom_wbr: .asciz "wbr"
.section __DATA,__const
.p2align 3
dom_void_names: .quad dom_area,dom_base,dom_br,dom_col,dom_embed,dom_hr,dom_img,dom_input,dom_link,dom_meta,dom_param,dom_source,dom_track,dom_wbr,0
