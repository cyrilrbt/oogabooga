// Native GET/POST controls, laid out at attachment glyphs by the assembly renderer.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _mac_controls_reset
_mac_controls_reset:
    ENTER
    LOAD x9, _engine_reflowing
    cbnz x9, Lcontrols_removed_keep
    bl _mac_undo_clear
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
Lcontrols_removed_keep:
    LEAVE

// metadata, node type -> kind (0 text, 1 submit, 2 hidden, 3 unsupported).
.globl _mac_control_kind
_mac_control_kind:
    ENTER
    mov x19, x0
    mov x20, x1
    cmp x20, #NODE_A
    b.eq Lkind_inline_link
    cmp x20, #NODE_SELECT
    b.eq Lkind_select
    cmp x20, #NODE_TEXTAREA
    b.eq Lkind_textarea
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
    b.eq Lkind_inert_button
    STR button_type
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lkind_inert_button
    STR reset_type
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lkind_inert_button
    STR checkbox_type
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lkind_checkbox
    STR radio_type
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lkind_radio
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
Lkind_inline_link:
    mov x0, #9
    LEAVE
Lkind_select:
    mov x0, #6
    LEAVE
Lkind_textarea:
    mov x0, #7
    LEAVE
Lkind_checkbox:
    mov x0, #4
    LEAVE
Lkind_radio:
    mov x0, #5
    LEAVE
Lkind_inert_button:
    mov x0, #8
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
    LOAD x9, _engine_reflowing
    cbz x9, Lcontrol_new
    CLASS NSNumber
    mov x2, x21
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _engine_controls
    MSG objectKey
    cbnz x0, Lcontrol_reused
Lcontrol_new:
    mov x0, x19
    mov x1, x20
    bl _mac_control_kind
    mov x22, x0
    cmp x0, #9
    b.eq Lcontrol_inline_link
    cmp x0, #2
    b.eq Lcontrol_none
    cmp x0, #4
    b.eq Lcontrol_check
    cmp x0, #5
    b.eq Lcontrol_check
    cmp x0, #6
    b.eq Lcontrol_select
    cmp x0, #7
    b.eq Lcontrol_textarea
    cmp x0, #8
    b.eq Lcontrol_button
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
    ldr x9, [x19, #ATTR_READONLY]
    cbz x9, Lcontrol_common
    mov x0, x23
    mov x2, #0
    MSG setEditable
    b Lcontrol_common
Lcontrol_inline_link:
    bl _mac_inline_button_class
    MSG alloc
    RECT 0, 0, 1, 1
    MSG initFrame
    mov x23, x0
    mov x1, x19
    mov x2, x21
    bl _mac_inline_configure
    b Lcontrol_dictionary
Lcontrol_select:
    LOAD x0, _engine_render_document
    mov x1, x21
    mov x2, x19
    bl _mac_select_create
    mov x23, x0
    b Lcontrol_common
Lcontrol_textarea:
    mov x0, x19
    bl _mac_textarea_create
    mov x23, x0
    b Lcontrol_dictionary
Lcontrol_check:
    CLASS NSButton
    MSG alloc
    RECT 0, 0, 24, 28
    MSG initFrame
    mov x23, x0
    cmp x22, #4
    mov x2, #3
    mov x9, #4
    csel x2, x2, x9, eq
    MSG setButtonType
    mov x0, x23
    ldr x9, [x19, #ATTR_CHECKED]
    cmp x9, #0
    cset w2, ne
    str x2, [x19, #704]
    MSG setState
    STR empty_value
    mov x2, x0
    mov x0, x23
    MSG setTitle
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
    cmp x22, #4
    b.lo Lcontrol_action
    SELECT x2, formToggle
Lcontrol_action:
    cmp x22, #8
    csel x2, xzr, x2, eq
    MSG setAction
    ldr x9, [x19, #ATTR_DISABLED]
    cmp x9, #0
    cset w2, eq
    cmp x22, #3
    csel x2, xzr, x2, eq
    cmp x22, #8
    csel x2, xzr, x2, eq
    mov x0, x23
    MSG setEnabled
Lcontrol_dictionary:
    CLASS NSNumber
    mov x2, x21
    MSG numberLongLong
    mov x3, x0
    mov x2, x23
    LOAD x0, _engine_controls
    MSG setObjectKey
    cmp x22, #5
    b.ne Lcontrol_release
    ldr x9, [x19, #ATTR_CHECKED]
    cbz x9, Lcontrol_release
    LOAD x0, _engine_render_document
    mov x1, x23
    bl _mac_radio_group
Lcontrol_release:
    mov x0, x23
    MSG release
    mov x0, x23
    LEAVE
Lcontrol_reused:
    cmp x20, #NODE_A
    b.ne Lcontrol_reused_done
    mov x1, x19
    mov x2, x21
    bl _mac_inline_configure
Lcontrol_reused_done:
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
    ldr x10, [x9]
    cmp x10, #NODE_A
    b.ne Lposition_visible_range
    ldr x10, [x19, #72]
    add x10, x10, x21, lsl #10
    ldr x10, [x10, #872]
    cbnz x10, Lposition_visible_range
    mov x0, x22
    mov x2, #1
    MSG setHidden
    b Lposition_advance
Lposition_visible_range:
    ldr x10, [x9, #16]
    ldr x9, [x20, #16]
    ldr x23, [x9, x10, lsl #3]
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x21, x10, x9
    ldr x10, [x9, #24]
    ldr x9, [x20, #16]
    ldr x10, [x9, x10, lsl #3]
    cmp x10, x23
    cset w2, eq
    mov x0, x22
    MSG setHidden
    ldr x9, [x19, #72]
    add x9, x9, x21, lsl #10
    ldr x9, [x9, #88]
    cmp x9, #1
    b.eq Lposition_advance
    LOAD x0, _engine_text
    MSG layoutManager
    mov x24, x0
    mov x2, x23
    mov x3, #1
    mov x4, #0
    MSG glyphRange
    mov x25, x0
    mov x26, x1
    // Locate the text baseline, not the full line/glyph bounding rectangle.
    mov x0, x24
    mov x2, x25
    mov x3, #0
    MSG lineFragment
    stp d0, d1, [sp, #144]
    str d3, [sp, #176]
    mov x0, x24
    MSG typesetter
    mov x2, x24
    mov x3, x25
    MSG typesetterBaseline
    ldr d1, [sp, #176]
    fsub d1, d1, d0                // baseline measured up from the line bottom
    ldr d2, [sp, #152]
    fadd d1, d1, d2
    NUM d4, 20
    fadd d1, d1, d4
    str d1, [sp, #184]
    mov x0, x24
    mov x2, x25
    MSG glyphLocation
    ldr d2, [sp, #144]
    fadd d0, d0, d2
    NUM d4, 20
    fadd d0, d0, d4
    str d0, [sp, #144]
    mov x0, x22
    MSG frame
    stp d2, d3, [sp, #160]          // exact attachment/control size
    mov x0, x22
    bl _mac_control_baseline_top
    ldr d1, [sp, #184]
    fsub d1, d1, d0
    str d1, [sp, #152]
    mov x0, x22
    bl _mac_inline_margins
    ldr d4, [sp, #144]
    fadd d0, d0, d4
    str d0, [sp, #144]
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    mov x0, x22
    MSG setFrame
    ldr x0, [x19, #72]
    add x0, x0, x21, lsl #10
    mov x1, #NODE_INPUT
    bl _mac_control_kind
    cmp x0, #5
    b.eq Lposition_radio
    LOAD x0, _engine_text
    mov x2, x22
    MSG addSubview
    b Lposition_advance
Lposition_radio:
    // One native parent per radio prevents AppKit from grouping controls across
    // different HTML forms. Our action applies the HTML owner/name rules.
    mov x0, x22
    MSG superview
    cbnz x0, Lposition_radio_parent
    CLASS NSView
    MSG alloc
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    MSG initFrame
    mov x23, x0
    mov x2, x22
    MSG addSubview
    LOAD x0, _engine_text
    mov x2, x23
    MSG addSubview
    mov x0, x23
    MSG release
    b Lposition_radio_frame
Lposition_radio_parent:
    mov x23, x0
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    MSG setFrame
Lposition_radio_frame:
    fmov d0, xzr
    fmov d1, xzr
    ldp d2, d3, [sp, #160]
    mov x0, x22
    MSG setFrame
Lposition_advance:
    add x21, x21, #1
    b Lposition_next
Lposition_done:
    LOAD x0, _engine_scroll
    mov x2, #0
    MSG setAccessibilityChildren
    CLASS NSMutableArray
    MSG new
    mov x22, x0
    LOAD x2, _engine_text
    MSG addObject
    LOAD x0, _engine_scroll
    MSG verticalScroller
    cbz x0, Lposition_ax_horizontal
    mov x2, x0
    mov x0, x22
    MSG addObject
Lposition_ax_horizontal:
    LOAD x0, _engine_scroll
    MSG horizontalScroller
    cbz x0, Lposition_ax_controls
    mov x2, x0
    mov x0, x22
    MSG addObject
Lposition_ax_controls:
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

// Action from either a submit button or Return in a text field. Successful form
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
    str xzr, [sp, #176]
    ldr x23, [x20, #72]
    add x23, x23, x22, lsl #10
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
    STR post_method_name
    mov x2, x0
    mov x0, x24
    MSG equal
    cbz w0, Lsubmit_unsupported
    mov x9, #1
    str x9, [sp, #176]
    ldr x0, [x23, #ATTR_ENCTYPE]
    cbz x0, Lsubmit_action
    ldrb w9, [x0]
    cbz w9, Lsubmit_action
    bl _mac_string
    MSG lowercase
    mov x24, x0
    STR form_content_type
    mov x2, x0
    mov x0, x24
    MSG equal
    cbnz w0, Lsubmit_action
Lsubmit_unsupported:
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
    add x23, x23, x27, lsl #10
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
    cmp x1, #NODE_SELECT
    b.eq Lsubmit_owner
    cmp x1, #NODE_TEXTAREA
    b.eq Lsubmit_owner
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
    cbnz x0, Lsubmit_native_value
    cmp x28, #6
    b.ne Lsubmit_attribute_value
    mov x0, x20
    mov x1, x27
    mov x2, x23
    bl _mac_select_create
    MSG autorelease
Lsubmit_native_value:
    cmp x28, #6
    b.eq Lsubmit_select_values
    cmp x28, #7
    b.eq Lsubmit_textarea_value
    cmp x28, #4
    b.eq Lsubmit_check_value
    cmp x28, #5
    b.eq Lsubmit_check_value
    cmp x28, #0
    b.ne Lsubmit_attribute_value
    MSG stringValue
    MSG UTF8String
    b Lsubmit_encode_value
Lsubmit_textarea_value:
    MSG documentView
    MSG string
    MSG UTF8String
    b Lsubmit_encode_value
Lsubmit_check_value:
    MSG state
    cmp x0, #1
    b.ne Lsubmit_next
    ldr x0, [x23, #ATTR_VALUE]
    cbnz x0, Lsubmit_encode_value
    ADDR x0, on_value
    b Lsubmit_encode_value
Lsubmit_select_values:
    mov x1, x23
    bl _mac_select_values
    mov x28, x0
    str xzr, [sp, #200]
Lsubmit_option_value:
    mov x0, x28
    MSG count
    ldr x9, [sp, #200]
    cmp x9, x0
    b.hs Lsubmit_next
    mov x0, x28
    mov x2, x9
    MSG objectAtIndex
    MSG UTF8String
    mov x2, x0
    ldr x1, [x23, #ATTR_NAME]
    mov x0, x26
    bl _mac_form_pair
    cbz w0, Lsubmit_limit
    ldr x9, [sp, #200]
    add x9, x9, #1
    str x9, [sp, #200]
    b Lsubmit_option_value
Lsubmit_attribute_value:
    cmp x28, #4
    b.eq Lsubmit_hidden_check
    cmp x28, #5
    b.ne Lsubmit_attribute_ready
Lsubmit_hidden_check:
    ldr x9, [x23, #ATTR_CHECKED]
    cbz x9, Lsubmit_next
    ldr x0, [x23, #ATTR_VALUE]
    cbnz x0, Lsubmit_encode_value
    ADDR x0, on_value
    b Lsubmit_encode_value
Lsubmit_attribute_ready:
    ldr x0, [x23, #ATTR_VALUE]
    cbnz x0, Lsubmit_encode_value
    ADDR x0, empty_value
Lsubmit_encode_value:
    mov x2, x0
    mov x0, x26
    ldr x1, [x23, #ATTR_NAME]
    bl _mac_form_pair
    cbz w0, Lsubmit_limit
    b Lsubmit_next
Lsubmit_next:
    add x27, x27, #1
    b Lsubmit_control
Lsubmit_navigate:
    ldr x9, [sp, #176]
    cbz x9, Lsubmit_get_navigate
    mov x0, x25
    MSG URL
    mov x1, x26
    bl _mac_engine_post
    b Lsubmit_release_query
Lsubmit_get_navigate:
    mov x0, x25
    mov x2, x26
    MSG setEncodedQuery
    mov x0, x25
    MSG URL
    bl _mac_engine_open_url
Lsubmit_release_query:
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

.section __TEXT,__cstring,cstring_literals
checkbox_type: .asciz "checkbox"
radio_type: .asciz "radio"
on_value: .asciz "on"
post_method_name: .asciz "post"
form_content_type: .asciz "application/x-www-form-urlencoded"

.section __TEXT,__cstring,cstring_literals
button_type: .asciz "button"
reset_type: .asciz "reset"
