// Bounded top-level @font-face descriptors. Binary font parsing/shaping lives
// behind the native codec adapter; CSS declarations and policy stay assembly.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// start,end,propertyName,out{borrowed value*,length} -> BOOL; last declaration.
.globl _engine_css_descriptor
_engine_css_descriptor:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    stp xzr, xzr, [x22]
Ldescriptor_next:
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    cmp x19, x20
    b.hs Ldescriptor_done
    mov x1, x20
    mov x2, #59
    bl _css_selector_boundary
    mov x23, x0
    mov x0, x19
    mov x1, x23
    mov x2, #58
    bl _css_selector_boundary
    mov x24, x0
    cmp x24, x23
    b.hs Ldescriptor_advance
    mov x0, x19
    mov x1, x24
    bl _css_trim
    mov x2, x21
    bl _css_eq
    cbz x0, Ldescriptor_advance
    add x0, x24, #1
    mov x1, x23
    bl _css_skip
    bl _css_trim
    sub x1, x1, x0
    stp x0, x1, [x22]
Ldescriptor_advance:
    add x19, x23, #1
    b Ldescriptor_next
Ldescriptor_done:
    ldr x9, [x22]
    cmp x9, #0
    cset x0, ne
    LEAVE

// source,length,offset,out[5 qwords] -> BOOL.
// Owned family*,owned src-list*,weight,italic,nextOffset. Nested conditional
// font faces, descriptor ranges, escapes and variable-font axes are deferred.
.globl _engine_css_font_face_next
_engine_css_font_face_next:
    ENTER
    mov x19, x0
    mov x21, x3
    cbz x19, Lface_none
    mov x9, #1048576
    cmp x1, x9
    b.hi Lface_none
    cmp x2, x1
    b.hs Lface_none
    add x20, x19, x1
    add x22, x19, x2
    stp xzr, xzr, [x21]
Lface_scan:
    mov x0, x22
    mov x1, x20
    bl _css_skip
    mov x22, x0
    cmp x22, x20
    b.hs Lface_none
    mov x1, x20
    mov x2, #123
    bl _css_selector_boundary
    mov x23, x0
    mov x0, x22
    mov x1, x20
    mov x2, #59
    bl _css_selector_boundary
    cmp x0, x23
    b.hs Lface_block
    add x22, x0, #1
    b Lface_scan
Lface_block:
    cmp x23, x20
    b.hs Lface_none
    add x0, x23, #1
    mov x1, x20
    bl _css_block_end
    mov x24, x0
    cmp x24, x20
    b.hs Lface_none
    add x25, x24, #1
    mov x0, x22
    mov x1, x23
    bl _css_trim
    ADDR x2, face_keyword
    bl _css_eq
    cbz x0, Lface_advance
    add x23, x23, #1
    mov x0, x23
    mov x1, x24
    ADDR x2, face_family
    add x3, sp, #144
    bl _engine_css_descriptor
    cbz x0, Lface_advance
    ldp x0, x1, [sp, #144]
    cbz x1, Lface_advance
    add x1, x0, x1
    bl _css_trim
    cmp x0, x1
    b.hs Lface_advance
    ldrb w9, [x0]
    cmp w9, #34
    b.eq Lface_unquote
    cmp w9, #39
    b.ne Lface_family_validate
Lface_unquote:
    sub x10, x1, #1
    ldrb w11, [x10]
    cmp w9, w11
    b.ne Lface_advance
    add x0, x0, #1
    mov x1, x10
Lface_family_validate:
    sub x1, x1, x0
    cbz x1, Lface_advance
    cmp x1, #128
    b.hi Lface_advance
    mov x9, #0
Lface_name_byte:
    cmp x9, x1
    b.hs Lface_family_copy
    ldrb w10, [x0, x9]
    cmp w10, #32
    b.lo Lface_advance
    cmp w10, #44
    b.eq Lface_advance
    cmp w10, #92
    b.eq Lface_advance
    cmp w10, #34
    b.eq Lface_advance
    cmp w10, #39
    b.eq Lface_advance
    add x9, x9, #1
    b Lface_name_byte
Lface_family_copy:
    bl _strndup
    cbz x0, Lface_none
    mov x26, x0
    mov x0, x23
    mov x1, x24
    ADDR x2, face_src
    add x3, sp, #144
    bl _engine_css_descriptor
    cbz x0, Lface_free_family
    ldp x0, x1, [sp, #144]
    cbz x1, Lface_free_family
    cmp x1, #2048
    b.hi Lface_free_family
    bl _strndup
    cbz x0, Lface_free_family
    mov x27, x0
    mov x9, #400
    str x9, [sp, #192]
    str xzr, [sp, #200]
    mov x0, x23
    mov x1, x24
    ADDR x2, face_weight
    add x3, sp, #144
    bl _engine_css_descriptor
    cbz x0, Lface_style
    mov x0, #CSS_WEIGHT
    ldp x1, x2, [sp, #144]
    add x2, x1, x2
    bl _css_value
    cbz x1, Lface_style
    cmp x0, #0
    b.lt Lface_style
    str x0, [sp, #192]
Lface_style:
    mov x0, x23
    mov x1, x24
    ADDR x2, face_style
    add x3, sp, #144
    bl _engine_css_descriptor
    cbz x0, Lface_ready
    mov x0, #CSS_ITALIC
    ldp x1, x2, [sp, #144]
    add x2, x1, x2
    bl _css_value
    cbz x1, Lface_ready
    cmp x0, #0
    b.lt Lface_ready
    str x0, [sp, #200]
Lface_ready:
    stp x26, x27, [x21]
    ldp x9, x10, [sp, #192]
    stp x9, x10, [x21, #16]
    sub x9, x25, x19
    str x9, [x21, #32]
    mov x0, #1
    LEAVE
Lface_free_family:
    mov x0, x26
    bl _free
Lface_advance:
    mov x22, x25
    b Lface_scan
Lface_none:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
face_keyword: .asciz "@font-face"
face_family: .asciz "font-family"
face_src: .asciz "src"
face_weight: .asciz "font-weight"
face_style: .asciz "font-style"
