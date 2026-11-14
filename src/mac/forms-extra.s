// Form serialization, multiline native fields and radio grouping in ARM64.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// append_pair(query,name,value) -> BOOL, all-or-nothing under the field limit.
.globl _mac_form_pair
_mac_form_pair:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, x2
    bl _engine_form_encode
    cbz x0, Lpair_fail
    mov x21, x0
    mov x0, x20
    bl _engine_form_encode
    cbz x0, Lpair_free_fail
    mov x22, x0
    mov x0, x19
    MSG length
    cbz x0, Lpair_name
    STR pair_amp
    mov x2, x0
    mov x0, x19
    MSG formAppend
Lpair_name:
    mov x0, x22
    bl _mac_string
    mov x2, x0
    mov x0, x19
    MSG formAppend
    STR pair_equal
    mov x2, x0
    mov x0, x19
    MSG formAppend
    mov x0, x21
    bl _mac_string
    mov x2, x0
    mov x0, x19
    MSG formAppend
    mov x0, x22
    bl _free
    mov x0, x21
    bl _free
    mov w0, #1
    LEAVE
Lpair_free_fail:
    mov x0, x21
    bl _free
Lpair_fail:
    mov w0, #0
    LEAVE

.globl _mac_textarea_create
_mac_textarea_create:
    ENTER
    mov x19, x0
    CLASS NSScrollView
    MSG alloc
    RECT 0, 0, 220, 100
    MSG initFrame
    mov x20, x0
    mov x2, #1
    MSG setVerticalScroller
    CLASS NSTextView
    MSG alloc
    RECT 0, 0, 200, 100
    MSG initFrame
    mov x21, x0
    mov x2, #0
    MSG setRichText
    ldr x0, [x19, #ATTR_VALUE]
    bl _mac_string
    mov x2, x0
    mov x0, x21
    MSG setString
    mov x0, x21
    ldr x9, [x19, #ATTR_DISABLED]
    ldr x10, [x19, #ATTR_READONLY]
    orr x9, x9, x10
    cmp x9, #0
    cset w2, eq
    MSG setEditable
    mov x0, x21
    mov x2, #18
    MSG setAutoresizing
    mov x0, x20
    mov x2, x21
    MSG setDocumentView
    mov x0, x21
    MSG release
    mov x0, x20
    LEAVE

// Nearest form owner; nested forms never share a radio group.
.globl _mac_form_owner
_mac_form_owner:
    ldr x2, [x0, #16]
    mov x3, #40
Lowner_next:
    cmp x1, #3
    b.lo Lowner_none
    madd x4, x1, x3, x2
    ldr x5, [x4]
    cmp x5, #NODE_FORM
    b.eq Lowner_found
    ldr x1, [x4, #8]
    b Lowner_next
Lowner_found:
    mov x0, x1
    ret
Lowner_none:
    mov x0, #-1
    ret

.globl _mac_form_toggle
_mac_form_toggle:
    ENTER
    mov x1, x2
    LOAD x0, _engine_document
    bl _mac_radio_group
    LEAVE
// document, sender control: checkbox state is native; radio exclusivity follows
// the HTML form owner and exact name, independent of native sibling grouping.
.globl _mac_radio_group
_mac_radio_group:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x19, Lradio_done
    mov x0, x20
    MSG tag
    mov x21, x0
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lradio_done
    ldr x22, [x19, #72]
    add x22, x22, x21, lsl #10
    mov x0, x22
    mov x1, #NODE_INPUT
    bl _mac_control_kind
    cmp x0, #5
    b.ne Lradio_done
    mov x9, #1
    str x9, [x22, #704]
    mov x0, x20
    mov x2, #1
    MSG setState
    ldr x23, [x22, #ATTR_NAME]
    cbz x23, Lradio_done
    ldrb w9, [x23]
    cbz w9, Lradio_done
    mov x0, x19
    mov x1, x21
    bl _mac_form_owner
    mov x24, x0
    mov x25, #0
Lradio_next:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Lradio_done
    cmp x25, x21
    b.eq Lradio_advance
    ldr x26, [x19, #72]
    add x26, x26, x25, lsl #10
    ldr x1, [x26, #ATTR_NAME]
    cbz x1, Lradio_advance
    mov x0, x23
    bl _strcmp
    cbnz w0, Lradio_advance
    mov x0, x26
    mov x1, #NODE_INPUT
    bl _mac_control_kind
    cmp x0, #5
    b.ne Lradio_advance
    mov x0, x19
    mov x1, x25
    bl _mac_form_owner
    cmp x0, x24
    b.ne Lradio_restore
    str xzr, [x26, #704]
Lradio_restore:
    CLASS NSNumber
    mov x2, x25
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    ldr x2, [x26, #704]
    MSG setState
Lradio_advance:
    add x25, x25, #1
    b Lradio_next
Lradio_done:
    LEAVE

.globl _mac_engine_post
_mac_engine_post:
    ENTER
    mov x19, x0
    mov x20, x1
    CLASS NSMutableURLRequest
    mov x2, x19
    MSG requestWithURL
    mov x21, x0
    STR post_method
    mov x2, x0
    mov x0, x21
    MSG setHTTPMethod
    STR post_type
    mov x22, x0
    STR content_type
    mov x3, x0
    mov x2, x22
    mov x0, x21
    MSG setHTTPHeader
    mov x0, x20
    mov x2, #4
    MSG dataUsingEncoding
    mov x2, x0
    mov x0, x21
    MSG setHTTPBody
    mov x0, x21
    MSG retain
    STORE x0, _engine_request_override
    mov x0, x19
    bl _mac_engine_open_url
    LEAVE
.section __TEXT,__cstring,cstring_literals
pair_amp: .asciz "&"
pair_equal: .asciz "="
post_method: .asciz "POST"
post_type: .asciz "application/x-www-form-urlencoded"
content_type: .asciz "Content-Type"
.section __DATA,__bss
.p2align 3
.globl _engine_request_override, _engine_render_document
_engine_request_override: .space 8
_engine_render_document: .space 8
