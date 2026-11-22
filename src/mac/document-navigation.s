.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
// doc, NSURL -> effective base URL. Keep it alive for retained scene callbacks.
.globl _mac_document_base
_mac_document_base:
    ENTER
    mov x19, x1
    bl _engine_base_href
    cbz x0, Lmac_base_original
    bl _mac_string
    mov x20, x0
    CLASS NSURL
    mov x2, x20
    mov x3, x19
    MSG relativeURL
    MSG absoluteURL
    cbnz x0, Lmac_base_retain
Lmac_base_original:
    mov x0, x19
Lmac_base_retain:
    MSG retain
    mov x20, x0
    LOAD x0, mac_owned_base
    MSG release
    STORE x20, mac_owned_base
    mov x0, x20
    LEAVE
// Current absolute URL's decoded fragment -> native source range scroll.
.globl _mac_fragment_scroll
_mac_fragment_scroll:
    ENTER
    LOAD x0, _engine_url
    MSG navFragment
    cbz x0, Lmac_fragment_top
    MSG navDecode
    cbz x0, Lmac_fragment_done
    MSG UTF8String
    mov x1, x0
    LOAD x0, _engine_document
    cbz x0, Lmac_fragment_done
    mov x19, x0
    bl _engine_fragment_node
    tbnz x0, #63, Lmac_fragment_done
    mov x9, #40
    ldr x10, [x19, #16]
    madd x9, x0, x9, x10
    ldr x0, [x9, #16]
    // The displayed source ranges are mapped by the shared normalized layout.
    mov x20, x0
    mov x0, x19
    mov x1, #0
    bl _engine_layout
    cbz x0, Lmac_fragment_done
    mov x21, x0
    ldr x9, [x0, #16]
    ldr x20, [x9, x20, lsl #3]
    LOAD x0, _engine_text
    mov x2, x20
    mov x3, #0
    MSG scrollRange
    mov x0, x21
    bl _engine_layout_free
    b Lmac_fragment_done
Lmac_fragment_top:
    LOAD x0, _engine_text
    mov x2, #0
    mov x3, #0
    MSG scrollRange
Lmac_fragment_done:
    LEAVE
// NSURL -> handled same-document navigation, without replacing the DOM/session.
.globl _mac_fragment_navigate
_mac_fragment_navigate:
    ENTER
    mov x19, x0
    LOAD x0, _engine_url
    MSG absoluteString
    MSG UTF8String
    mov x20, x0
    mov x0, x19
    MSG absoluteString
    MSG UTF8String
    mov x1, x0
    mov x0, x20
    bl _engine_same_document
    cbz x0, Lmac_fragment_not_same
    bl _mac_navigation_save
    bl _mac_engine_cancel
    mov x0, x19
    MSG retain
    mov x19, x0
    LOAD x0, _engine_url
    MSG release
    STORE x19, _engine_url
    bl _mac_engine_record
    LOAD x9, engine_traversal
    cbz x9, Lmac_same_fragment
    bl _mac_navigation_restore
    b Lmac_same_scrolled
Lmac_same_fragment:
    bl _mac_fragment_scroll
Lmac_same_scrolled:
    mov x0, #1
    LEAVE
Lmac_fragment_not_same:
    mov x0, #0
    LEAVE
.globl _mac_navigation_save
_mac_navigation_save:
    ENTER
    LOAD x0, _engine_document
    cbz x0, Lmac_nav_saved
    LOAD x0, _mac_scroll_positions
    cbnz x0, Lmac_nav_dictionary
    CLASS NSMutableDictionary
    MSG new
    STORE x0, _mac_scroll_positions
Lmac_nav_dictionary:
    LOAD x0, _engine_text
    MSG visibleRect
    stp d0, d1, [sp, #144]
    CLASS NSValue
    ldp d0, d1, [sp, #144]
    MSG navPoint
    mov x19, x0
    CLASS NSNumber
    LOAD x2, engine_index
    MSG numberLongLong
    mov x3, x0
    mov x2, x19
    LOAD x0, _mac_scroll_positions
    MSG setObjectKey
Lmac_nav_saved:
    LEAVE
.globl _mac_navigation_restore
_mac_navigation_restore:
    ENTER
    CLASS NSNumber
    LOAD x2, engine_index
    MSG numberLongLong
    mov x2, x0
    LOAD x0, _mac_scroll_positions
    MSG objectKey
    cbz x0, Lmac_nav_restored
    MSG navPointValue
    stp d0, d1, [sp, #144]
    LOAD x0, _engine_scroll
    MSG contentView
    ldp d0, d1, [sp, #144]
    MSG inputScrollPoint
Lmac_nav_restored:
    LEAVE
.section __DATA,__bss
.p2align 3
mac_owned_base: .space 8
_mac_scroll_positions: .space 8
.section __TEXT,__cstring,cstring_literals
nav_fragment_name: .asciz "fragment"
nav_decode_name: .asciz "stringByRemovingPercentEncoding"
nav_point_name: .asciz "valueWithPoint:"
nav_point_value_name: .asciz "pointValue"
.section __DATA,__data
.p2align 3
.globl _sel_navFragment,_sel_navDecode,_sel_navPoint,_sel_navPointValue
_sel_navFragment: .quad nav_fragment_name
_sel_navDecode: .quad nav_decode_name
_sel_navPoint: .quad nav_point_name
_sel_navPointValue: .quad nav_point_value_name

.globl _mac_scroll_positions
