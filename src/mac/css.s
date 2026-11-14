// Apply assembly-computed CSS to native text attributes. AppKit supplies fonts,
// color objects and paragraph metrics; no HTML/CSS parser is delegated to WebKit.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.macro STYLE_ATTR symbol, value
    mov x0, x19
    adrp x9, \symbol@GOTPAGE
    ldr x9, [x9, \symbol@GOTPAGEOFF]
    ldr x2, [x9]
    mov x3, \value
    mov x4, x21
    mov x5, x22
    MSG addAttribute
.endm

// RGB24 -> autoreleased NSColor, or nil for the transparent/default sentinel.
.globl _mac_css_color
_mac_css_color:
    ENTER
    mov x19, x0
    tbnz x0, #63, Lrgb_none
    CLASS NSColor
    ubfx x9, x19, #16, #8
    ucvtf d0, x9
    ubfx x9, x19, #8, #8
    ucvtf d1, x9
    and x9, x19, #255
    ucvtf d2, x9
    NUM d4, 255
    fdiv d0, d0, d4
    fdiv d1, d1, d4
    fdiv d2, d2, d4
    fmov d3, #1.0
    MSG sRGBColor
    LEAVE
Lrgb_none:
    mov x0, #0
    LEAVE

_mac_css_font:
    ENTER
    mov x19, x0
    ldr x20, [x19, #48]
    ldr x21, [x19, #56]
    ldr x22, [x19, #120]
    CLASS NSFont
    scvtf d0, x20
    fmov d1, xzr
    cmp x21, #600
    b.lo Lfont_family
    fmov d1, #0.5
Lfont_family:
    cmp x22, #1
    b.eq Lfont_sans
    cmp x22, #2
    b.eq Lfont_serif
    MSG monospacedFont
    b Lfont_italic
Lfont_sans:
    MSG systemFontWeight
    b Lfont_italic
Lfont_serif:
    cmp x21, #600
    b.lo Lfont_serif_normal
    STR times_bold
    b Lfont_serif_named
Lfont_serif_normal:
    STR times_regular
Lfont_serif_named:
    mov x23, x0
    CLASS NSFont
    mov x2, x23
    scvtf d0, x20
    MSG fontNameSize
    cbnz x0, Lfont_italic
    CLASS NSFont
    scvtf d0, x20
    MSG systemFont
Lfont_italic:
    mov x20, x0
    ldr x9, [x19, #64]
    cbz x9, Lfont_done
    CLASS NSFontManager
    MSG sharedFontManager
    mov x2, x20
    mov x3, #1                     // NSItalicFontMask
    MSG convertFontTrait
    cbnz x0, Lfont_return
Lfont_done:
    mov x0, x20
Lfont_return:
    LEAVE

// attributes(attributed_string, metadata, location, length, node_type).
.globl _mac_css_attributes
_mac_css_attributes:
    cbz x3, Lattributes_return
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x0, x20
    bl _mac_css_font
    mov x24, x0
    STYLE_ATTR _NSFontAttributeName, x24
    ldr x0, [x20, #32]
    bl _mac_css_color
    cbnz x0, Lattributes_foreground
    CLASS NSColor
    MSG textColor
Lattributes_foreground:
    mov x24, x0
    STYLE_ATTR _NSForegroundColorAttributeName, x24
    ldr x0, [x20, #40]
    bl _mac_css_color
    cbz x0, Lattributes_underline
    mov x24, x0
    STYLE_ATTR _NSBackgroundColorAttributeName, x24
Lattributes_underline:
    CLASS NSNumber
    ldr x2, [x20, #72]
    MSG numberLongLong
    mov x24, x0
    STYLE_ATTR _NSUnderlineStyleAttributeName, x24
    // Native paragraph geometry is applied to block nodes, never inline ranges.
    cmp x23, #NODE_TEXT
    b.eq Lattributes_done
    cmp x23, #NODE_A
    b.eq Lattributes_done
    cmp x23, #NODE_SPAN
    b.eq Lattributes_done
    cmp x23, #NODE_STRONG
    b.eq Lattributes_done
    cmp x23, #NODE_EM
    b.eq Lattributes_done
    CLASS NSMutableParagraphStyle
    MSG new
    mov x24, x0
    ldr x2, [x20, #80]
    // macOS ARM64 uses the iOS alignment ABI: center=1, right=2.
    // Keep the engine's platform-neutral ordering (right=1, center=2) separate.
    cmp x2, #1
    b.lo Lparagraph_alignment
    cmp x2, #2
    b.hi Lparagraph_alignment
    eor x2, x2, #3
Lparagraph_alignment:
    MSG setAlignment
    mov x0, x24
    ldr x9, [x20, #96]
    scvtf d0, x9
    MSG setParagraphBefore
    mov x0, x24
    ldr x9, [x20, #104]
    scvtf d0, x9
    MSG setParagraphAfter
    mov x0, x24
    ldr x9, [x20, #128]
    scvtf d0, x9
    MSG setHeadIndent
    mov x0, x24
    ldr x9, [x20, #128]
    scvtf d0, x9
    MSG setFirstIndent
    mov x0, x24
    ldr x9, [x20, #136]
    neg x9, x9
    scvtf d0, x9
    MSG setTailIndent
    ldr w25, [x20, #112]            // low 32 bits are resolved line height
    cbz x25, Lattributes_paragraph
    mov x0, x24
    scvtf d0, x25
    MSG setMinimumLine
    mov x0, x24
    scvtf d0, x25
    MSG setMaximumLine
Lattributes_paragraph:
    STYLE_ATTR _NSParagraphStyleAttributeName, x24
    mov x0, x24
    MSG release
Lattributes_done:
    LEAVE
Lattributes_return:
    ret

// canvas(document, text_view, scroll_view) resets colors between styled/unstyled pages.
.globl _mac_css_canvas
_mac_css_canvas:
    ENTER
    mov x19, x1
    mov x20, x2
    ldr x9, [x0, #72]
    ldr x0, [x9, #40]
    bl _mac_css_color
    cbnz x0, Lcanvas_color
    CLASS NSColor
    MSG textBackgroundColor
Lcanvas_color:
    mov x21, x0
    mov x0, x19
    mov x2, x21
    MSG setBackgroundColor
    mov x0, x20
    mov x2, x21
    MSG setBackgroundColor
    mov x0, x20
    mov x2, #1
    MSG setDrawsBackground
    LEAVE
.section __TEXT,__cstring,cstring_literals
times_regular: .asciz "Times-Roman"
times_bold: .asciz "Times-Bold"
