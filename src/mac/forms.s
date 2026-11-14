// Native GET controls, laid out at attachment glyphs by the assembly renderer.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_controls_reset
_mac_controls_reset:
    ENTER
    LOAD x0, _engine_controls
    MSG release
    CLASS NSMutableDictionary
    MSG new
    STORE x0, _engine_controls
    LOAD x0, _engine_scroll
    mov x2, #0
    MSG setAccessibilityChildren
    LOAD x0, _engine_text
    MSG subviews
    MSG mutableCopy
    mov x19, x0
    MSG count
    mov x20, x0
Lcontrols_remove:
    cbz x20, Lcontrols_removed
    sub x20, x20, #1
    mov x0, x19
    mov x2, x20
    MSG objectAtIndex
    MSG removeFromSuperview
    b Lcontrols_remove
Lcontrols_removed:
    mov x0, x19
    MSG release
    LEAVE

// metadata, node type -> kind (0 text, 1 submit, 2 hidden, 3 unsupported).
.globl _mac_control_kind
_mac_control_kind:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x0, [x19, #ATTR_TYPE]
    cbz x0, Lkind_default
    ldrb w9, [x0]
    cbz w9, Lkind_default
    bl _mac_string
    MSG lowercase
    mov x21, x0
    STR submit_type
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lkind_submit
    cmp x20, #NODE_BUTTON
    b.eq Lkind_unsupported
    STR hidden_type
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lkind_hidden
    ADDR x22, text_types
Lkind_text_type:
    ldr x0, [x22], #8
    cbz x0, Lkind_unsupported
    bl _mac_string
    mov x2, x0
    mov x0, x21
    MSG equal
    cbz w0, Lkind_text_type
    mov x0, #0
    LEAVE
Lkind_default:
    cmp x20, #NODE_BUTTON
    b.eq Lkind_submit
    mov x0, #0
    LEAVE
Lkind_submit:
    mov x0, #1
    LEAVE
Lkind_hidden:
    mov x0, #2
    LEAVE
Lkind_unsupported:
    mov x0, #3
    LEAVE

// create(metadata,node_type,node_index) -> native control (dictionary owns it).
.globl _mac_control_create
_mac_control_create:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _mac_control_kind
    mov x22, x0
    cmp x0, #2
    b.eq Lcontrol_none
    cmp x0, #1
    b.eq Lcontrol_button
    CLASS NSTextField
    MSG alloc
    RECT 0, 0, 220, 26
    MSG initFrame
    mov x23, x0
    ldr x0, [x19, #ATTR_VALUE]
    cmp x22, #3
    b.ne Lcontrol_text_value
    ADDR x0, unsupported_input
Lcontrol_text_value:
    bl _mac_string
    mov x2, x0
    mov x0, x23
    MSG setStringValue
    b Lcontrol_common
Lcontrol_button:
    CLASS NSButton
    MSG alloc
    RECT 0, 0, 100, 28
    MSG initFrame
    mov x23, x0
    mov x2, #1
    MSG setBezelStyle
    ldr x0, [x19, #ATTR_LABEL]
    cbnz x0, Lcontrol_button_title
    ldr x0, [x19, #ATTR_VALUE]
    cbnz x0, Lcontrol_button_title
    ADDR x0, submit_label
Lcontrol_button_title:
    bl _mac_string
    mov x2, x0
    mov x0, x23
    MSG setTitle
Lcontrol_common:
    mov x0, x23
    mov x2, x21
    MSG setTag
    mov x0, x23
    LOAD x2, _mac_delegate
    MSG setTarget
    mov x0, x23
    SELECT x2, engineSubmit
    MSG setAction
    ldr x9, [x19, #ATTR_DISABLED]
    cmp x9, #0
    cset w2, eq
    cmp x22, #3
    csel x2, xzr, x2, eq
    mov x0, x23
    MSG setEnabled
    CLASS NSNumber
    mov x2, x21
    MSG numberLongLong
    mov x3, x0
    mov x2, x23
    LOAD x0, _engine_controls
    MSG setObjectKey
    mov x0, x23
    MSG release
    mov x0, x23
    LEAVE
Lcontrol_none:
    mov x0, #0
    LEAVE

// document, layout: position each native control at its reserved glyph rectangle.
.globl _mac_controls_position
_mac_controls_position:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #0
Lposition_next:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lposition_done
    CLASS NSNumber
    mov x2, x21
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    cbz x0, Lposition_advance
    mov x22, x0
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x21, x10, x9
    ldr x10, [x9, #16]
    ldr x9, [x20, #16]
    ldr x23, [x9, x10, lsl #3]
    LOAD x0, _engine_text
    MSG layoutManager
    mov x24, x0
    mov x2, x23
    mov x3, #1
    mov x4, #0
    MSG glyphRange
    mov x25, x0
    mov x26, x1
    LOAD x0, _engine_text
    MSG textContainer
    mov x4, x0
    mov x0, x24
    mov x2, x25
    mov x3, x26
    MSG glyphRect
    NUM d4, 20                      // text container inset
    fadd d0, d0, d4
    fadd d1, d1, d4
    mov x0, x22
    MSG setFrame
    LOAD x0, _engine_text
    mov x2, x22
    MSG addSubview
Lposition_advance:
    add x21, x21, #1
    b Lposition_next
Lposition_done:
    LOAD x0, _engine_scroll
    MSG accessibilityChildren
    MSG mutableCopy
    cbnz x0, Lposition_ax_array
    CLASS NSMutableArray
    MSG new
Lposition_ax_array:
    mov x22, x0
    mov x21, #0
Lposition_ax_control:
    ldr x9, [x19, #24]
    cmp x21, x9
    b.hs Lposition_ax_install
    CLASS NSNumber
    mov x2, x21
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    cbz x0, Lposition_ax_next
    mov x2, x0
    mov x0, x22
    MSG addObject
Lposition_ax_next:
    add x21, x21, #1
    b Lposition_ax_control
Lposition_ax_install:
    LOAD x0, _engine_scroll
    mov x2, x22
    MSG setAccessibilityChildren
    mov x0, x22
    MSG release
    LEAVE

// Action from either a submit button or Return in a text field. Successful GET
// controls retain document order, duplicate names, UTF-8 and explicit submitter.
.globl _mac_form_submit
_mac_form_submit:
    ENTER
    mov x19, x2
    LOAD x20, _engine_document
    cbz x20, Lsubmit_done
    mov x0, x19
    MSG tag
    mov x21, x0                     // submitter index
    ldr x9, [x20, #24]
    cmp x21, x9
    b.hs Lsubmit_done
    mov x22, x21
Lsubmit_find_form:
    ldr x9, [x20, #16]
    mov x10, #40
    madd x9, x22, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_FORM
    b.eq Lsubmit_form
    ldr x22, [x9, #8]
    cmp x22, #3
    b.hs Lsubmit_find_form
    b Lsubmit_done
Lsubmit_form:
    ldr x23, [x20, #72]
    add x23, x23, x22, lsl #9
    ldr x0, [x23, #ATTR_METHOD]
    cbz x0, Lsubmit_action
    ldrb w9, [x0]
    cbz w9, Lsubmit_action
    bl _mac_string
    MSG lowercase
    mov x24, x0
    STR get_method
    mov x2, x0
    mov x0, x24
    MSG equal
    cbnz w0, Lsubmit_action
    STR unsupported_method
    bl _mac_status_text
    b Lsubmit_done
Lsubmit_action:
    ldr x0, [x23, #ATTR_ACTION]
    cbz x0, Lsubmit_current_url
    bl _mac_string
    mov x24, x0
    CLASS NSURL
    mov x2, x24
    LOAD x3, _engine_url
    MSG relativeURL
    MSG absoluteURL
    b Lsubmit_url
Lsubmit_current_url:
    LOAD x0, _engine_url
Lsubmit_url:
    mov x24, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lsubmit_done
    CLASS NSURLComponents
    mov x2, x24
    mov x3, #0
    MSG componentsURL
    mov x25, x0
    CLASS NSMutableString
    MSG new
    mov x26, x0                     // encoded query
    mov x27, #0
Lsubmit_control:
    ldr x9, [x20, #24]
    cmp x27, x9
    b.hs Lsubmit_navigate
    ldr x23, [x20, #72]
    add x23, x23, x27, lsl #9
    ldr x9, [x23, #ATTR_DISABLED]
    cbnz x9, Lsubmit_next
    ldr x9, [x23, #ATTR_NAME]
    cbz x9, Lsubmit_next
    ldrb w9, [x9]
    cbz w9, Lsubmit_next
    ldr x9, [x20, #16]
    mov x10, #40
    madd x9, x27, x10, x9
    ldr x1, [x9]
    cmp x1, #NODE_INPUT
    b.eq Lsubmit_owner
    cmp x1, #NODE_BUTTON
    b.ne Lsubmit_next
Lsubmit_owner:
    str x1, [sp, #192]
    ldr x28, [x9, #8]
Lsubmit_owner_walk:
    cmp x28, x22
    b.eq Lsubmit_value
    cmp x28, #3
    b.lo Lsubmit_next
    ldr x9, [x20, #16]
    mov x10, #40
    madd x9, x28, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_FORM
    b.eq Lsubmit_next
    ldr x28, [x9, #8]
    b Lsubmit_owner_walk
Lsubmit_value:
    mov x0, x23
    ldr x1, [sp, #192]
    bl _mac_control_kind
    cmp x0, #3
    b.eq Lsubmit_next
    cmp x0, #1
    b.ne Lsubmit_get_value
    cmp x27, x21
    b.ne Lsubmit_next
Lsubmit_get_value:
    mov x28, x0
    CLASS NSNumber
    mov x2, x27
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    cbz x0, Lsubmit_attribute_value
    cmp x28, #0
    b.ne Lsubmit_attribute_value
    MSG stringValue
    MSG UTF8String
    b Lsubmit_encode_value
Lsubmit_attribute_value:
    ldr x0, [x23, #ATTR_VALUE]
    cbnz x0, Lsubmit_encode_value
    ADDR x0, empty_value
Lsubmit_encode_value:
    bl _engine_form_encode
    cbz x0, Lsubmit_limit
    mov x28, x0
    mov x0, x26
    MSG length
    cbz x0, Lsubmit_name
    STR query_separator
    mov x2, x0
    mov x0, x26
    MSG formAppend
Lsubmit_name:
    ldr x0, [x23, #ATTR_NAME]
    bl _engine_form_encode
    mov x19, x0
    bl _mac_string
    mov x2, x0
    mov x0, x26
    MSG formAppend
    mov x0, x19
    bl _free
    STR query_equals
    mov x2, x0
    mov x0, x26
    MSG formAppend
    mov x0, x28
    bl _mac_string
    mov x2, x0
    mov x0, x26
    MSG formAppend
    mov x0, x28
    bl _free
Lsubmit_next:
    add x27, x27, #1
    b Lsubmit_control
Lsubmit_navigate:
    mov x0, x25
    mov x2, x26
    MSG setEncodedQuery
    mov x0, x25
    MSG URL
    bl _mac_engine_open_url
    mov x0, x26
    MSG release
Lsubmit_done:
    LEAVE
Lsubmit_limit:
    STR field_limit
    bl _mac_status_text
    mov x0, x26
    MSG release
    LEAVE
.section __TEXT,__cstring,cstring_literals
submit_type: .asciz "submit"
hidden_type: .asciz "hidden"
text_type: .asciz "text"
search_type: .asciz "search"
email_type: .asciz "email"
url_type: .asciz "url"
tel_type: .asciz "tel"
submit_label: .asciz "Submit"
get_method: .asciz "get"
unsupported_method: .asciz "Assembly engine: this form requires an unsupported method. Use WebKit with ⌘E."
empty_value: .asciz ""
query_separator: .asciz "&"
query_equals: .asciz "="
.section __DATA,__const
.p2align 3
text_types: .quad text_type, search_type, email_type, url_type, tel_type, 0
.section __DATA,__bss
.p2align 3
.globl _engine_controls
_engine_controls: .space 8

.section __TEXT,__cstring,cstring_literals
field_limit: .asciz "Assembly engine: form values must be at most 2048 UTF-8 bytes. Nothing was submitted."
unsupported_input: .asciz "Unsupported input"
