// Atomic inline glyph slots retain every original character. Only the first
// glyph reserves geometry; interior glyphs (including block separators) become
// null glyphs in this shaping context. Their own context shapes the real text.
.include "src/mac/mac.inc"
.include "src/mac/atomic.inc"
.text
.p2align 2
// sorted context bytes, local UTF-16 index -> containing direct record or nil.
.globl _mac_atomic_find
_mac_atomic_find:
    cbz x0, Lat_find_none
    ldr x2, [x0]
    add x0, x0, #AT_HEADER
    mov x3, #0
Lat_find_search:
    cmp x3, x2
    b.hs Lat_find_none
    add x4, x3, x2
    lsr x4, x4, #1
    mov x5, #AT_STRIDE
    madd x5, x4, x5, x0
    ldr x6, [x5, #AT_START]
    cmp x1, x6
    b.lo Lat_find_left
    ldr x7, [x5, #AT_LENGTH]
    add x6, x6, x7
    cmp x1, x6
    b.lo Lat_find_yes
    add x3, x4, #1
    b Lat_find_search
Lat_find_left:
    mov x2, x4
    b Lat_find_search
Lat_find_yes:
    mov x0, x5
    ret
Lat_find_none:
    mov x0, #0
    ret

.globl _mac_atomic_data
_mac_atomic_data:
    ENTER
    ADDR x1, _mac_atomic_key
    bl _objc_getAssociatedObject
    MSG mutableBytes
    LEAVE

// manager, local character index -> direct record.
.globl _mac_atomic_lookup
_mac_atomic_lookup:
    ENTER
    mov x19, x1
    bl _mac_atomic_data
    mov x1, x19
    bl _mac_atomic_find
    LEAVE

// Delegate: range is entirely stack-passed because only x7 remains available.
atomic_generate:
    ENTER
    mov x19, x3
    mov x20, x4
    mov x21, x5
    mov x22, x6
    mov x23, x2
    ldp x9, x10, [sp, #224]
    stp x9, x10, [sp, #144]
    mov x0, x23
    bl _mac_atomic_data
    cbz x0, Lat_generate_default
    mov x24, x0
    ldr x9, [x24]
    cbz x9, Lat_generate_default
    ldr x9, [sp, #152]
    mov x10, #10
    mul x0, x9, x10
    bl _malloc
    cbz x0, Lat_generate_default
    mov x25, x0
    ldr x9, [sp, #152]
    add x26, x25, x9, lsl #1
    mov x27, #0
Lat_generate_loop:
    ldr x9, [sp, #152]
    cmp x27, x9
    b.hs Lat_generate_install
    ldrh w9, [x19, x27, lsl #1]
    strh w9, [x25, x27, lsl #1]
    ldr x9, [x20, x27, lsl #3]
    str x9, [x26, x27, lsl #3]
    mov x0, x24
    ldr x1, [x21, x27, lsl #3]
    bl _mac_atomic_find
    cbz x0, Lat_generate_next
    strh wzr, [x25, x27, lsl #1]
    ldr x9, [x21, x27, lsl #3]
    ldr x10, [x0, #AT_START]
    cmp x9, x10
    mov x9, #1                     // NSGlyphPropertyNull
    cinc x9, x9, eq                // first = NSGlyphPropertyControlCharacter
    str x9, [x26, x27, lsl #3]
Lat_generate_next:
    add x27, x27, #1
    b Lat_generate_loop
Lat_generate_install:
    mov x0, x23
    mov x2, x25
    mov x3, x26
    mov x4, x21
    mov x5, x22
    ldp x6, x7, [sp, #144]
    MSG atomicSetGlyphs
    mov x0, x25
    bl _free
    ldr x0, [sp, #152]
    LEAVE
Lat_generate_default:
    mov x0, #0
    LEAVE

atomic_action:
    ENTER
    mov x19, x3
    mov x20, x4
    mov x0, x2
    mov x1, x4
    bl _mac_atomic_lookup
    cbz x0, Lat_action_default
    ldr x9, [x0, #AT_START]
    cmp x9, x20
    mov x0, #1                     // zero advancement for interior controls
    cinc x0, x0, eq                // whitespace action reserves first slot
    LEAVE
Lat_action_default:
    mov x0, x19
    LEAVE

atomic_control_box:
    ENTER
    mov x0, x2
    mov x1, x5
    bl _mac_atomic_lookup
    cbz x0, Lat_control_zero
    ldr d2, [x0, #AT_WIDTH]
    ldr d3, [x0, #AT_HEIGHT]
    ldr d1, [x0, #AT_BASELINE]
    fneg d1, d1
    fmov d0, xzr
    LEAVE
Lat_control_zero:
    fmov d0, xzr
    fmov d1, xzr
    fmov d2, xzr
    fmov d3, xzr
    LEAVE

atomic_line:
    ENTER
    mov x19, x2
    mov x20, x3
    mov x21, x4
    mov x22, x5
    ldp x2, x3, [sp, #224]
    mov x0, x19
    mov x4, #0
    MSG atomicCharacterRange
    mov x23, x0
    add x24, x0, x1
    mov x0, x19
    bl _mac_atomic_data
    cbz x0, Lat_line_no
    ldr x25, [x0]
    add x26, x0, #AT_HEADER
    ldr d0, [x22]
    str d0, [sp, #144]
    ldr d1, [x20, #24]
    fsub d1, d1, d0
    str d1, [sp, #152]
    stp xzr, xzr, [sp, #160]
    str x25, [sp, #176]
    str x26, [sp, #184]
Lat_line_record:
    cbz x25, Lat_line_apply
    ldr x9, [x26, #AT_START]
    cmp x9, x23
    b.lo Lat_line_next
    cmp x9, x24
    b.hs Lat_line_next
    add x9, x26, #AT_META
    ldr x9, [x9, #880]
    cmn x9, #17
    b.eq Lat_line_top
    cmn x9, #19
    b.eq Lat_line_bottom
    ldr d0, [x26, #AT_BASELINE]
    ldr d1, [x26, #AT_HEIGHT]
    fsub d1, d1, d0
    ldr d2, [sp, #144]
    ldr d3, [sp, #152]
    fmax d2, d2, d0
    fmax d3, d3, d1
    stp d2, d3, [sp, #144]
    b Lat_line_next
Lat_line_top:
    ldr d0, [x26, #AT_HEIGHT]
    ldr d1, [sp, #160]
    fmax d0, d0, d1
    str d0, [sp, #160]
    b Lat_line_next
Lat_line_bottom:
    ldr d0, [x26, #AT_HEIGHT]
    ldr d1, [sp, #168]
    fmax d0, d0, d1
    str d0, [sp, #168]
Lat_line_next:
    add x26, x26, #AT_STRIDE
    sub x25, x25, #1
    b Lat_line_record
Lat_line_apply:
    ldp d0, d1, [sp, #144]
    ldr d2, [sp, #160]
    fsub d2, d2, d0
    fmax d1, d1, d2
    ldr d2, [sp, #168]
    fsub d2, d2, d1
    fmax d0, d0, d2
    str d0, [x22]
    fadd d2, d1, d0
    str d2, [x20, #24]
    str d2, [x21, #24]
    ldr x25, [sp, #176]
    ldr x26, [sp, #184]
Lat_line_align:
    cbz x25, Lat_line_yes
    ldr x9, [x26, #AT_START]
    cmp x9, x23
    b.lo Lat_line_align_next
    cmp x9, x24
    b.hs Lat_line_align_next
    add x9, x26, #AT_META
    ldr x9, [x9, #880]
    cmn x9, #17
    b.eq Lat_line_align_top
    cmn x9, #19
    b.ne Lat_line_align_next
    ldr d2, [x26, #AT_HEIGHT]
    fsub d2, d2, d1
    str d2, [x26, #AT_BASELINE]
    b Lat_line_align_next
Lat_line_align_top:
    str d0, [x26, #AT_BASELINE]
Lat_line_align_next:
    add x26, x26, #AT_STRIDE
    sub x25, x25, #1
    b Lat_line_align
Lat_line_yes:
    mov x0, #1
    LEAVE
Lat_line_no:
    mov x0, #0
    LEAVE

// manager, owned-by-caller NSMutableData -> install self-contained delegate.
// A retained owner array associated with data keeps all nested storages alive.
.globl _mac_atomic_install
_mac_atomic_install:
    ENTER
    mov x19, x0
    mov x20, x1
    ADDR x1, _mac_atomic_key
    mov x2, x20
    mov x3, #1
    bl _objc_setAssociatedObject
    cbnz x20, Lat_install_delegate
    mov x0, x19
    mov x2, #0
    MSG atomicSetDelegate
    mov x0, x19
    ADDR x1, atomic_delegate_key
    mov x2, #0
    mov x3, #1
    bl _objc_setAssociatedObject
    LEAVE
Lat_install_delegate:
    ADDR x0, atomic_delegate_name
    bl _objc_getClass
    cbnz x0, Lat_delegate_new
    CLASS NSObject
    ADDR x1, atomic_delegate_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x21, x0
    ADDR x22, atomic_methods
Lat_delegate_method:
    ldr x0, [x22]
    cbz x0, Lat_delegate_register
    bl _sel_registerName
    mov x1, x0
    mov x0, x21
    ldr x2, [x22, #8]
    ldr x3, [x22, #16]
    bl _class_addMethod
    add x22, x22, #24
    b Lat_delegate_method
Lat_delegate_register:
    mov x0, x21
    bl _objc_registerClassPair
    mov x0, x21
Lat_delegate_new:
    MSG new
    mov x21, x0
    mov x0, x19
    mov x2, x21
    MSG atomicSetDelegate
    mov x0, x19
    ADDR x1, atomic_delegate_key
    mov x2, x21
    mov x3, #1
    bl _objc_setAssociatedObject
    mov x0, x21
    MSG release
    LEAVE
.section __TEXT,__cstring,cstring_literals
.globl _mac_atomic_key
_mac_atomic_key: .asciz "assemblyAtomicInlineContext"
atomic_delegate_key: .asciz "assemblyAtomicInlineDelegate"
atomic_delegate_name: .asciz "OogaAtomicInlineDelegate"
atomic_generate_name: .asciz "layoutManager:shouldGenerateGlyphs:properties:characterIndexes:font:forGlyphRange:"
atomic_action_name: .asciz "layoutManager:shouldUseAction:forControlCharacterAtIndex:"
atomic_control_name: .asciz "layoutManager:boundingBoxForControlGlyphAtIndex:forTextContainer:proposedLineFragment:glyphPosition:characterIndex:"
atomic_line_name: .asciz "layoutManager:shouldSetLineFragmentRect:lineFragmentUsedRect:baselineOffset:inTextContainer:forGlyphRange:"
atomic_generate_type: .asciz "Q@:@^S^Q^Q@{_NSRange=QQ}"
atomic_action_type: .asciz "Q@:@QQ"
atomic_control_type: .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:@Q@{CGRect={CGPoint=dd}{CGSize=dd}}{CGPoint=dd}Q"
atomic_line_type: .asciz "B@:@^{CGRect}^{CGRect}^d@{_NSRange=QQ}"
.section __DATA,__const
.p2align 3
atomic_methods:
.quad atomic_generate_name,atomic_generate,atomic_generate_type
.quad atomic_action_name,atomic_action,atomic_action_type
.quad atomic_control_name,atomic_control_box,atomic_control_type
.quad atomic_line_name,atomic_line,atomic_line_type
.quad 0,0,0
