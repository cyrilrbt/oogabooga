// Construct independent inline formatting contexts while retaining full source
// characters in every parent storage. TextKit supplies shaping, not box sizing.
.include "src/mac/mac.inc"
.include "src/mac/atomic.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// doc,UTF16 map,mutable attributed source,main manager
.globl _mac_atomic_prepare
_mac_atomic_prepare:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x0, x21
    MSG copyObject
    mov x23, x0
    mov x0, x19
    mov x1, x20
    mov x2, x23
    mov x3, #0
    mov x4, x22
    mov x5, x21
    mov x6, #0
    bl atomic_build_context
    mov x0, x23
    MSG release
    LEAVE

// doc,map,immutable full source,scope index+1,manager,target storage.
atomic_build_context:
    ENTER
    sub sp, sp, #128
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    str x6, [sp, #112]
    mov x0, x24
    MSG length
    str x0, [sp, #120]
    mov x0, x19
    mov x1, x22
    bl _engine_context_reflow
    str xzr, [sp, #8]              // direct record count
    mov x27, #1
Lat_build_count:
    ldr x9, [x19, #24]
    cmp x27, x9
    b.hs Lat_build_allocate
    mov x0, x19
    mov x1, x27
    mov x2, x20
    ldr x3, [sp, #112]
    ldr x4, [sp, #120]
    bl atomic_eligible
    cbz x0, Lat_count_next
    ldr x9, [sp, #8]
    add x9, x9, #1
    str x9, [sp, #8]
Lat_count_next:
    add x27, x27, #1
    b Lat_build_count
Lat_build_allocate:
    ldr x9, [sp, #8]
    cbz x9, Lat_build_clear
    cmp x9, #256
    b.hi Lat_build_clear
    CLASS NSMutableData
    MSG new
    mov x25, x0
    ldr x9, [sp, #8]
    mov x10, #AT_STRIDE
    mul x2, x9, x10
    add x2, x2, #AT_HEADER
    MSG setLength
    mov x0, x25
    MSG mutableBytes
    str x0, [sp]
    ldr x9, [sp, #8]
    str x9, [x0]
    ldr x9, [sp, #112]
Lat_build_base:
    str x9, [x0, #8]
    CLASS NSMutableArray
    MSG new
    str x0, [sp, #16]
    mov x26, #0
    mov x27, #1
Lat_build_record:
    ldr x9, [x19, #24]
    cmp x27, x9
    b.hs Lat_build_install
    mov x0, x19
    mov x1, x27
    mov x2, x20
    ldr x3, [sp, #112]
    ldr x4, [sp, #120]
    bl atomic_eligible
    cbz x0, Lat_build_next
    ldr x9, [sp]
    mov x10, #AT_STRIDE
    madd x28, x26, x10, x9
    add x28, x28, #AT_HEADER
    str x27, [x28, #AT_NODE]
    mov x9, #40
    ldr x10, [x19, #16]
    madd x9, x27, x9, x10
    ldp x10, x11, [x9, #16]
    ldr x12, [x20, #16]
    ldr x10, [x12, x10, lsl #3]
    ldr x11, [x12, x11, lsl #3]
    ldr x12, [sp]
    ldr x12, [x12, #8]
    ldr x13, [sp, #120]
    add x13, x13, x12
    cmp x10, x12
    csel x10, x12, x10, lo
    cmp x11, x13
    csel x11, x13, x11, hi
    sub x11, x11, x10
    sub x12, x10, x12
    stp x12, x11, [x28]
    stp x10, x11, [sp, #24]        // immutable global substring range
    ldr x9, [x19, #72]
    add x9, x9, x27, lsl #11
    str x9, [sp, #40]
    // Re-evaluate containing widths after entering a narrower inline context.
    mov x10, #40
    ldr x11, [x19, #16]
    madd x10, x27, x10, x11
    ldr x10, [x10, #8]
    ldr x11, [x19, #72]
    add x10, x11, x10, lsl #11
    ldr x1, [x10, #768]
    mov x0, x9
    bl _engine_box_metrics
    ldr x9, [sp, #40]
    ldr x10, [x9, #FLOW_OWNER]
    cbz x10, Lat_build_auto_width
    ldr x0, [x9, #FLOW_WIDTH]
    b Lat_build_explicit
Lat_build_auto_width:
    ldr x10, [x9, #144]
    tbz x10, #63, Lat_build_explicit
    mov x0, x9
    ldr x1, [x9, #FLOW_MIN_CONTENT]
    ldr x2, [x9, #FLOW_MAX_CONTENT]
    ldr x3, [x9, #848]
    bl _engine_shrink_to_fit
Lat_build_explicit:
    ldr x9, [sp, #40]
    str x0, [x9, #768]
    str x0, [sp, #48]
    add x0, x28, #AT_META
    mov x1, x9
    mov x2, #CSS_META_SIZE
    bl _memcpy
    mov x0, x21
    MSG string
    ldp x1, x2, [sp, #24]
    ldr x3, [sp, #40]
    bl atomic_trim_edges
    stp x0, x1, [sp, #24]
    str x0, [x28, #AT_SOURCE_BASE]
    mov x0, x21
    ldp x2, x3, [sp, #24]
    MSG atomicAttributedSubstring
    mov x9, x0
    str x9, [sp, #56]
    CLASS NSTextStorage
    MSG alloc
    ldr x2, [sp, #56]
    MSG atomicInitAttributed
    str x0, [x28, #AT_STORAGE]
    mov x2, x0
    ldr x0, [sp, #16]
    MSG addObject
    ldr x0, [x28, #AT_STORAGE]
    MSG release
    // Root margins/padding belong to the outer box, not its text paragraph.
    add x9, x28, #AT_META
    ldr x10, [x9, #776]
    ldr x11, [x9, #784]
    stp x10, x11, [sp, #88]
    str xzr, [x9, #776]
    str xzr, [x9, #784]
    ldr x10, [x9, #792]
    ldr x11, [x9, #800]
    stp x10, x11, [sp, #64]
    str xzr, [x9, #792]
    str xzr, [x9, #800]
    mov x0, x9
    bl _mac_css_paragraph
    str x0, [sp, #80]
    add x9, x28, #AT_META
    ldp x10, x11, [sp, #88]
    str x10, [x9, #776]
    str x11, [x9, #784]
    ldp x10, x11, [sp, #64]
    str x10, [x9, #792]
    str x11, [x9, #800]
    ldr x0, [x28, #AT_STORAGE]
    adrp x9, _NSParagraphStyleAttributeName@GOTPAGE
    ldr x9, [x9, _NSParagraphStyleAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldr x3, [sp, #80]
    mov x4, #0
    ldr x5, [sp, #32]
    MSG addAttribute
    ldr x0, [sp, #80]
    MSG release
    CLASS NSLayoutManager
    MSG new
    str x0, [x28, #AT_MANAGER]
    mov x2, x0
    ldr x0, [x28, #AT_STORAGE]
    MSG atomicAddManager
    ldr x0, [x28, #AT_MANAGER]
    MSG release
    CLASS NSTextContainer
    MSG alloc
    ldr x9, [sp, #48]
    cmp x9, #1
    mov x10, #1
    csel x9, x10, x9, lt            // TextKit adapter needs a nonzero measure port
    scvtf d0, x9
    NUM d1, 1048576
    MSG atomicInitContainer
    str x0, [x28, #AT_CONTAINER]
    fmov d0, xzr
    MSG setFragmentPadding
    ldr x0, [x28, #AT_MANAGER]
    ldr x2, [x28, #AT_CONTAINER]
    MSG atomicAddContainer
    ldr x0, [x28, #AT_CONTAINER]
    MSG release
    ldr x0, [x28, #AT_MANAGER]
    mov x2, #4
    MSG setTypesetterBehavior
    mov x0, x19
    mov x1, x20
    mov x2, x21
    add x3, x27, #1
    ldr x4, [x28, #AT_MANAGER]
    ldr x5, [x28, #AT_STORAGE]
    ldr x6, [x28, #AT_SOURCE_BASE]
    bl atomic_build_context
    // Descendant block geometry belongs only to this context.
    mov x0, x19
    mov x1, x20
    ldr x2, [x28, #AT_STORAGE]
    add x3, x27, #1
    ldr x4, [x28, #AT_SOURCE_BASE]
    bl _mac_blocks
    ldr x0, [x28, #AT_MANAGER]
    ldr x2, [x28, #AT_CONTAINER]
    MSG ensureTextLayout
    ldr x0, [x28, #AT_MANAGER]
    ldr x2, [x28, #AT_CONTAINER]
    MSG usedTextRect
    fadd d0, d1, d3
    fcvtps x9, d0
    ldr x10, [sp, #40]
    ldr x10, [x10, #NATIVE_EMPTY]
    cmp x10, #0
    csel x9, xzr, x9, ne
    str x9, [sp, #88]              // natural content height
    ldr x9, [sp, #40]
    ldr x9, [x9, #NATIVE_EMPTY]
    cbnz x9, Lat_build_empty_baseline
    ldr x0, [x28, #AT_MANAGER]
    MSG atomicGlyphCount
    cbz x0, Lat_build_empty_baseline
    sub x2, x0, #1
    str x2, [sp, #96]
    ldr x0, [x28, #AT_MANAGER]
    mov x3, #0
    MSG lineFragment
    str d1, [sp, #104]
    ldr x0, [x28, #AT_MANAGER]
    ldr x2, [sp, #96]
    MSG glyphLocation
    ldr d0, [sp, #104]
    fadd d0, d0, d1
    b Lat_build_baseline_ready
Lat_build_empty_baseline:
    ldr x9, [sp, #88]
    scvtf d0, x9
Lat_build_baseline_ready:
    str d0, [sp, #104]
    ldr x9, [sp, #40]
    ldr x10, [x9, #BOX_HEIGHT]
    tbnz x10, #63, Lat_build_auto_height
    b Lat_build_height_limit
Lat_build_auto_height:
    ldr x10, [sp, #88]
Lat_build_height_limit:
    ldr x11, [x9, #BOX_MAX_HEIGHT]
    tbnz x11, #63, Lat_build_height_min
    cmp x10, x11
    csel x10, x11, x10, gt
Lat_build_height_min:
    ldr x11, [x9, #BOX_MIN_HEIGHT]
    cmp x10, x11
    csel x10, x11, x10, lt
    ldr x11, [x9, #824]
    ldr x12, [x9, #BOX_BORDER_TOP]
    add x11, x11, x12
    ldr x12, [x9, #792]
    add x11, x11, x12
    scvtf d1, x11
    ldr d0, [sp, #104]
    fadd d0, d0, d1
    str d0, [x28, #AT_BASELINE]
    add x10, x10, x11
    ldr x11, [x9, #832]
    add x10, x10, x11
    ldr x11, [x9, #BOX_BORDER_BOTTOM]
    add x10, x10, x11
    ldr x11, [x9, #800]
    add x10, x10, x11
    scvtf d0, x10
    str d0, [x28, #AT_HEIGHT]
    ldr x10, [sp, #48]
    ldr x11, [x9, #776]
    add x10, x10, x11
    ldr x11, [x9, #784]
    add x10, x10, x11
    ldr x11, [x9, #808]
    add x10, x10, x11
    ldr x11, [x9, #816]
    add x10, x10, x11
    ldr x11, [x9, #BOX_BORDER_LEFT]
    add x10, x10, x11
    ldr x11, [x9, #BOX_BORDER_RIGHT]
    add x10, x10, x11
    scvtf d0, x10
    str d0, [x28, #AT_WIDTH]
    add x9, x28, #AT_META
    ldr x10, [x9, #NATIVE_EMPTY]
    ldr x11, [x9, #(1840+(CSS_OVERFLOW_X-48)*8)]
    orr x10, x10, x11
    ldr x11, [x9, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    orr x10, x10, x11
    cbz x10, Lat_build_alignment
    ldr d0, [x28, #AT_HEIGHT]
    str d0, [x28, #AT_BASELINE]
Lat_build_alignment:
    mov x10, #40
    ldr x11, [x19, #16]
    madd x10, x27, x10, x11
    ldr x10, [x10, #8]
    ldr x11, [x19, #72]
    add x0, x11, x10, lsl #11
    bl _mac_css_font
    str x0, [sp, #96]
    add x9, x28, #AT_META
    ldr x9, [x9, #880]
    cmn x9, #18
    b.eq Lat_build_middle
    cmn x9, #20
    b.eq Lat_build_text_top
    cmn x9, #21
    b.eq Lat_build_text_bottom
    mov x0, x28
    add x0, x0, #AT_META
    bl _mac_inline_baseline
    cbz x0, Lat_build_alignment_done
    ldr d1, [x28, #AT_BASELINE]
    fadd d0, d0, d1
    b Lat_build_alignment_store
Lat_build_middle:
    ldr x0, [sp, #96]
    MSG atomicXHeight
    ldr d1, [x28, #AT_HEIGHT]
    fadd d0, d0, d1
    fmov d1, #0.5
    fmul d0, d0, d1
    b Lat_build_alignment_store
Lat_build_text_top:
    ldr x0, [sp, #96]
    MSG atomicAscender
    b Lat_build_alignment_store
Lat_build_text_bottom:
    ldr x0, [sp, #96]
    MSG atomicDescender
    ldr d1, [x28, #AT_HEIGHT]
    fadd d0, d0, d1
Lat_build_alignment_store:
    str d0, [x28, #AT_BASELINE]
Lat_build_alignment_done:
    // Attachments live in the child storage. Leaving their attributes on the
    // parent's first control glyph makes TextKit reserve the attachment width
    // instead of the complete inline border/margin box.
    mov x0, x24
    adrp x9, _NSAttachmentAttributeName@GOTPAGE
    ldr x9, [x9, _NSAttachmentAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x3, x4, [x28]
    MSG removeAttribute
    mov x0, x24
    adrp x9, _NSKernAttributeName@GOTPAGE
    ldr x9, [x9, _NSKernAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x3, x4, [x28]
    MSG removeAttribute
    mov x0, x24
    adrp x9, _NSBaselineOffsetAttributeName@GOTPAGE
    ldr x9, [x9, _NSBaselineOffsetAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldp x3, x4, [x28]
    MSG removeAttribute
    // Parent paragraphs retain their own alignment and spacing around the slot.
    mov x10, #40
    ldr x11, [x19, #16]
    madd x10, x27, x10, x11
    ldr x10, [x10, #8]
    ldr x11, [x19, #72]
    add x0, x11, x10, lsl #11
    bl _mac_css_paragraph
    str x0, [sp, #80]
    mov x0, x24
    adrp x9, _NSParagraphStyleAttributeName@GOTPAGE
    ldr x9, [x9, _NSParagraphStyleAttributeName@GOTPAGEOFF]
    ldr x2, [x9]
    ldr x3, [sp, #80]
    ldp x4, x5, [x28]
    MSG addAttribute
    ldr x0, [sp, #80]
    MSG release
    add x26, x26, #1
Lat_build_next:
    add x27, x27, #1
    b Lat_build_record
Lat_build_install:
    ldr x9, [sp]
    str x26, [x9]
    mov x0, x25
    ADDR x1, atomic_owners_key
    ldr x2, [sp, #16]
    mov x3, #1
    bl _objc_setAssociatedObject
    ldr x0, [sp, #16]
    MSG release
    mov x0, x23
    mov x1, x25
    bl _mac_atomic_install
    mov x0, x25
    MSG release
    b Lat_build_done
Lat_build_clear:
    mov x0, x23
    mov x1, #0
    bl _mac_atomic_install
Lat_build_done:
    add sp, sp, #128
    LEAVE

// Eligibility includes the current scope and a nonempty source range.
// Private helper preserves the builder's x22 scope register.
atomic_eligible:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x23, x3
    mov x24, x4
    ldr x9, [x19, #72]
    add x9, x9, x20, lsl #11
    ldr x10, [x9, #88]
    cmp x10, #5
    b.ne Lat_eligible_no
    ldr x10, [x9, #872]
    cbnz x10, Lat_eligible_no
    bl _engine_inline_owner
    cmp x0, x22
    b.ne Lat_eligible_no
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldp x10, x11, [x9, #16]
    cmp x10, x11
    b.hs Lat_eligible_no
    ldr x9, [x21, #16]
    ldr x10, [x9, x10, lsl #3]
    ldr x11, [x9, x11, lsl #3]
    cmp x11, x23
    b.ls Lat_eligible_no
    add x24, x24, x23
    cmp x10, x24
    b.hs Lat_eligible_no
    mov x0, #1
    LEAVE
Lat_eligible_no:
    mov x0, #0
    LEAVE
// NSString,start,length,metadata -> trimmed start,length. Normal/nowrap source
// newlines were already collapsed; boundary CR/LF here belong to parser blocks.
atomic_trim_edges:
    ENTER
    mov x19, x0
    mov x20, x1
    add x21, x1, x2
    ldr x9, [x3, #888]
    cbz x9, Lat_trim_left
    cmp x9, #2
    b.ne Lat_trim_done
Lat_trim_left:
    cmp x20, x21
    b.hs Lat_trim_done
    mov x0, x19
    mov x2, x20
    MSG characterAtIndex
    cmp x0, #10
    b.eq Lat_trim_left_advance
    cmp x0, #13
    b.ne Lat_trim_right
Lat_trim_left_advance:
    add x20, x20, #1
    b Lat_trim_left
Lat_trim_right:
    cmp x21, x20
    b.ls Lat_trim_done
    mov x0, x19
    sub x2, x21, #1
    MSG characterAtIndex
    cmp x0, #10
    b.eq Lat_trim_right_advance
    cmp x0, #13
    b.ne Lat_trim_done
Lat_trim_right_advance:
    sub x21, x21, #1
    b Lat_trim_right
Lat_trim_done:
    mov x0, x20
    sub x1, x21, x20
    LEAVE
.section __TEXT,__cstring,cstring_literals
atomic_owners_key: .asciz "assemblyAtomicInlineStorages"
