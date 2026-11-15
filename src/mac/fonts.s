// Page-scoped font faces. Assembly selects CSS families/weights and schedules
// bounded HTTP loads. CoreText decodes font tables and shapes native glyphs.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_fonts_reset
_mac_fonts_reset:
    ENTER
    ADDR x19, font_records
    LOAD x20, font_count
    STORE xzr, font_count
    STORE xzr, _mac_font_pending
Lfonts_free:
    cbz x20, Lfonts_freed
    ldr x0, [x19]
    bl _free
    ldr x0, [x19, #8]
    bl _free
    ldr x0, [x19, #16]
    MSG release
    ldr x0, [x19, #24]
    MSG release
    ldr x0, [x19, #64]
    MSG release
    add x19, x19, #128
    sub x20, x20, #1
    b Lfonts_free
Lfonts_freed:
    ADDR x0, font_records
    mov x1, #0
    mov x2, #2048
    bl _memset
    bl _engine_font_family_reset
    LEAVE

// CSS bytes,length,final stylesheet URL. Each accepted original sheet (including
// imports) is scanned separately, keeping relative font URLs tied to its base.
.globl _mac_fonts_add_sheet
_mac_fonts_add_sheet:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
Lfonts_sheet_next:
    LOAD x9, font_count
    cmp x9, #16
    b.hs Lfonts_sheet_done
    mov x0, x19
    mov x1, x20
    mov x2, x22
    add x3, sp, #144
    bl _engine_css_font_face_next
    cbz x0, Lfonts_sheet_done
    ldr x22, [sp, #176]
    ADDR x23, font_records
    LOAD x24, font_count
    mov x25, #0
Lfonts_duplicate:
    cmp x25, x24
    b.hs Lfonts_sheet_add
    add x26, x23, x25, lsl #7
    ldr x0, [x26]
    ldr x1, [sp, #144]
    bl _strcasecmp
    cbnz x0, Lfonts_duplicate_next
    ldr x0, [x26, #8]
    ldr x1, [sp, #152]
    bl _strcmp
    cbnz x0, Lfonts_duplicate_next
    ldp x9, x10, [x26, #32]
    ldp x11, x12, [sp, #160]
    cmp x9, x11
    b.ne Lfonts_duplicate_next
    cmp x10, x12
    b.ne Lfonts_duplicate_next
    ldr x0, [x26, #16]
    mov x2, x21
    MSG equalObject
    cbnz x0, Lfonts_sheet_discard
Lfonts_duplicate_next:
    add x25, x25, #1
    b Lfonts_duplicate
Lfonts_sheet_add:
    add x23, x23, x24, lsl #7
    ldp x9, x10, [sp, #144]
    stp x9, x10, [x23]
    ldp x9, x10, [sp, #160]
    stp x9, x10, [x23, #32]
    mov x0, x21
    MSG retain
    str x0, [x23, #16]
    add x24, x24, #1
    STORE x24, font_count
    mov x0, x23
    bl fonts_advance
    b Lfonts_sheet_next
Lfonts_sheet_discard:
    ldr x0, [sp, #144]
    bl _free
    ldr x0, [sp, #152]
    bl _free
    b Lfonts_sheet_next
Lfonts_sheet_done:
    LEAVE

// Select another supported source after a failed font; each retry still shares
// the page request budget. Only normal HTTP(S) URLs can reach NSURLSession.
fonts_advance:
    ENTER
    mov x19, x0
    ldr x0, [x19, #24]
    MSG release
    str xzr, [x19, #24]
Lfonts_source_next:
    ldr x0, [x19, #8]
    bl _strlen
    mov x1, x0
    ldr x0, [x19, #8]
    ldr x2, [x19, #72]
    add x3, sp, #144
    bl _engine_css_font_source_next
    cbz x0, Lfonts_source_failed
    ldr x9, [sp, #152]
    str x9, [x19, #72]
    ldr x0, [sp, #144]
    bl _mac_string
    mov x20, x0
    CLASS NSURL
    mov x2, x20
    ldr x3, [x19, #16]
    MSG relativeURL
    MSG absoluteURL
    mov x20, x0
    MSG scheme
    bl _mac_allowed_scheme
    mov x21, x0
    ldr x0, [sp, #144]
    bl _free
    cbz x21, Lfonts_source_next
    mov x0, x20
    MSG retain
    str x0, [x19, #24]
    str xzr, [x19, #48]
    LEAVE
Lfonts_source_failed:
    mov x9, #1
    str x9, [x19, #48]
    LEAVE

.globl _mac_fonts_next
_mac_fonts_next:
    LOAD x1, font_count
    ADDR x2, font_records
    mov x3, #0
Lfonts_next:
    cmp x3, x1
    b.hs Lfonts_none
    add x4, x2, x3, lsl #7
    ldr x5, [x4, #48]
    cbnz x5, Lfonts_next_record
    ldr x0, [x4, #24]
    cbz x0, Lfonts_next_record
    add x3, x3, #1
    STORE x3, _mac_font_pending
    ret
Lfonts_next_record:
    add x3, x3, #1
    b Lfonts_next
Lfonts_none:
    mov x0, #0
    ret

// NSData or nil. Font instances are scoped to this page, never installed in the
// process/system font registry or exposed through global font-name matching.
.globl _mac_fonts_complete
_mac_fonts_complete:
    ENTER
    mov x19, x0
    LOAD x20, _mac_font_pending
    STORE xzr, _mac_font_pending
    cbz x20, Lfonts_complete_done
    sub x20, x20, #1
    ADDR x21, font_records
    add x21, x21, x20, lsl #7
    cbz x19, Lfonts_complete_failed
    mov x0, x19
    MSG length
    mov x22, x0
    mov x0, x19
    MSG bytes
    mov x1, x22
    bl _engine_font_validate
    cbz x0, Lfonts_complete_failed
    mov x0, x19
    bl _CTFontManagerCreateFontDescriptorsFromData
    cbz x0, Lfonts_complete_failed
    mov x22, x0
    MSG count
    cbz x0, Lfonts_descriptors_failed
    cmp x0, #16
    b.hi Lfonts_descriptors_failed
    mov x0, x22
    mov x2, #0
    MSG objectAtIndex
    NUM d0, 14
    mov x1, #0
    bl _CTFontCreateWithFontDescriptor
    mov x23, x0
    mov x0, x22
    bl _CFRelease
    cbz x23, Lfonts_complete_failed
    ldr x0, [x21]
    bl _strlen
    mov x1, x0
    ldr x0, [x21]
    bl _engine_font_family_register
    cbz x0, Lfonts_alias_failed
    str x0, [x21, #56]
    str x23, [x21, #64]
    mov x9, #2
    str x9, [x21, #48]
    b Lfonts_complete_done
Lfonts_alias_failed:
    mov x0, x23
    bl _CFRelease
    b Lfonts_complete_failed
Lfonts_descriptors_failed:
    mov x0, x22
    bl _CFRelease
Lfonts_complete_failed:
    mov x0, x21
    bl fonts_advance
Lfonts_complete_done:
    LEAVE

// Computed metadata -> autoreleased scaled font, or nil. Explicit face variants
// win by style then nearest weight; synthesis/variable axes remain deferred.
.globl _mac_webfont_font
_mac_webfont_font:
    ENTER
    mov x19, x0
    ldr x20, [x19, #120]
    ADDR x21, font_records
    LOAD x22, font_count
    mov x23, #0
    mov x24, #65535
    mov x25, #0
Lwebfont_face:
    cmp x23, x22
    b.hs Lwebfont_selected
    add x9, x21, x23, lsl #7
    ldr x10, [x9, #48]
    cmp x10, #2
    b.ne Lwebfont_next
    ldr x10, [x9, #56]
    cmp x10, x20
    b.ne Lwebfont_next
    ldr x10, [x9, #32]
    ldr x11, [x19, #56]
    subs x10, x10, x11
    cneg x10, x10, mi
    ldr x11, [x9, #40]
    ldr x12, [x19, #64]
    cmp x11, x12
    b.eq Lwebfont_score
    add x10, x10, #1000
Lwebfont_score:
    cmp x10, x24
    b.hs Lwebfont_next
    mov x24, x10
    ldr x25, [x9, #64]
Lwebfont_next:
    add x23, x23, #1
    b Lwebfont_face
Lwebfont_selected:
    cbz x25, Lwebfont_none
    mov x0, x25
    ldr x9, [x19, #48]
    scvtf d0, x9
    mov x1, #0
    mov x2, #0
    bl _CTFontCreateCopyWithAttributes
    cbz x0, Lwebfont_none
    MSG autorelease
    LEAVE
Lwebfont_none:
    mov x0, #0
    LEAVE
.section __DATA,__bss
.p2align 3
font_records: .space 2048
font_count: .space 8
.globl _mac_font_pending
_mac_font_pending: .space 8
