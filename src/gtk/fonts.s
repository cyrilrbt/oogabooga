// Page-scoped native fonts. Assembly parses descriptors, validates tables and
// selects sources; Fontconfig/Pango decode fonts and shape glyphs.
.include "src/gtk/gtk.inc"
.text
.globl _gtk_fonts_reset
_gtk_fonts_reset:
    ENTER
    bl _FcConfigGetCurrent
    bl _FcConfigAppFontClear
    LOAD x19, gtk_font_count
    ADDR x20, gtk_font_records
    STORE xzr, gtk_font_count
Lgtk_font_free:
    cbz x19, Lgtk_fonts_zero
    mov x21, #0
Lgtk_font_free_field:
    ldr x0, [x20, x21, lsl #3]
    bl _g_free
    add x21, x21, #1
    cmp x21, #3
    b.lo Lgtk_font_free_field
    ldr x0, [x20, #48]
    bl _g_free
    ldr x0, [x20, #56]
    bl _g_free
    ldr x0, [x20, #64]
    cbz x0, Lgtk_font_free_next
    bl _g_unlink
    ldr x0, [x20, #64]
    bl _g_free
Lgtk_font_free_next:
    add x20, x20, #128
    sub x19, x19, #1
    b Lgtk_font_free
Lgtk_fonts_zero:
    ADDR x0, gtk_font_records
    mov x1, #0
    mov x2, #2048
    bl _memset
    bl _engine_font_family_reset
    bl _pango_cairo_font_map_get_default
    bl _pango_fc_font_map_config_changed
    LEAVE
// CSS source,length,final base URL.
.globl _gtk_fonts_add_sheet
_gtk_fonts_add_sheet:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
Lgtk_font_face:
    LOAD x9, gtk_font_count
    cmp x9, #16
    b.hs Lgtk_fonts_added
    mov x0, x19
    mov x1, x20
    mov x2, x22
    add x3, sp, #144
    bl _engine_css_font_face_next
    cbz x0, Lgtk_fonts_added
    ldr x22, [sp, #176]
    LOAD x23, gtk_font_count
    ADDR x24, gtk_font_records
    mov x25, #0
Lgtk_font_duplicate:
    cmp x25, x23
    b.hs Lgtk_font_add
    add x26, x24, x25, lsl #7
    ldr x0, [x26]
    ldr x1, [sp, #144]
    bl _g_strcmp0
    cbnz x0, Lgtk_font_duplicate_next
    ldr x0, [x26, #8]
    ldr x1, [sp, #152]
    bl _g_strcmp0
    cbz x0, Lgtk_font_discard
Lgtk_font_duplicate_next:
    add x25, x25, #1
    b Lgtk_font_duplicate
Lgtk_font_add:
    add x24, x24, x23, lsl #7
    ldp x9, x10, [sp, #144]
    stp x9, x10, [x24]
    ldp x9, x10, [sp, #160]
    stp x9, x10, [x24, #24]
    mov x0, x21
    bl _g_strdup
    str x0, [x24, #16]
    add x23, x23, #1
    STORE x23, gtk_font_count
    b Lgtk_font_face
Lgtk_font_discard:
    ldr x0, [sp, #144]
    bl _free
    ldr x0, [sp, #152]
    bl _free
    b Lgtk_font_face
Lgtk_fonts_added:
    LEAVE
// -> borrowed resolved URL; index is retained independently of flow node count.
.globl _gtk_fonts_next
_gtk_fonts_next:
    ENTER
    mov x19, #0
    ADDR x20, gtk_font_records
Lgtk_font_source_face:
    LOAD x9, gtk_font_count
    cmp x19, x9
    b.hs Lgtk_font_source_none
    add x21, x20, x19, lsl #7
    ldr x9, [x21, #72]
    cbnz x9, Lgtk_font_source_advance
    ldr x0, [x21, #8]
    bl _strlen
    mov x1, x0
    ldr x0, [x21, #8]
    ldr x2, [x21, #40]
    add x3, sp, #144
    bl _engine_css_font_source_next
    cbz x0, Lgtk_font_source_exhausted
    ldr x9, [sp, #152]
    str x9, [x21, #40]
    ldr x0, [x21, #16]
    ldr x1, [sp, #144]
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    mov x22, x0
    ldr x0, [sp, #144]
    bl _free
    cbz x22, Lgtk_font_source_face
    ldr x0, [x21, #48]
    bl _g_free
    str x22, [x21, #48]
    mov x9, #1
    str x9, [x21, #72]
    STORE x19, _gtk_font_pending
    mov x0, x22
    LEAVE
Lgtk_font_source_exhausted:
    mov x9, #3
    str x9, [x21, #72]
Lgtk_font_source_advance:
    add x19, x19, #1
    b Lgtk_font_source_face
Lgtk_font_source_none:
    mov x0, #0
    LEAVE
// index,data,length. Keep temporary files until this document's fonts retire.
.globl _gtk_fonts_complete
_gtk_fonts_complete:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ADDR x22, gtk_font_records
    add x22, x22, x19, lsl #7
    str xzr, [x22, #72]
    cbz x20, Lgtk_font_completed
    mov x9, #1048576
    cmp x21, x9
    b.hi Lgtk_font_completed
    mov x0, x20
    mov x1, x21
    bl _engine_font_validate
    cbz x0, Lgtk_font_completed
    ADDR x0, gtk_font_template
    add x1, sp, #144
    mov x2, #0
    bl _g_file_open_tmp
    mov x23, x0
    tbnz w23, #31, Lgtk_font_completed
    ldr x24, [sp, #144]
    mov x25, #0
Lgtk_font_write:
    cmp x25, x21
    b.hs Lgtk_font_write_done
    mov x0, x23
    add x1, x20, x25
    sub x2, x21, x25
    bl _write
    cmp x0, #0
    b.le Lgtk_font_write_failed
    add x25, x25, x0
    b Lgtk_font_write
Lgtk_font_write_done:
    mov x0, x23
    bl _close
    mov x0, x24
    mov x1, #0
    mov x2, #0
    add x3, sp, #160
    bl _FcFreeTypeQuery
    cbz x0, Lgtk_font_file_failed
    mov x23, x0
    ADDR x1, gtk_font_family_property
    mov x2, #0
    add x3, sp, #152
    bl _FcPatternGetString
    cbnz x0, Lgtk_font_pattern_failed
    ldr x0, [sp, #152]
    bl _g_strdup
    str x0, [x22, #56]
    bl _FcConfigGetCurrent
    mov x1, x24
    bl _FcConfigAppFontAddFile
    cbz x0, Lgtk_font_pattern_failed
    ldr x0, [x22]
    bl _strlen
    mov x1, x0
    ldr x0, [x22]
    bl _engine_font_family_register
    cbz x0, Lgtk_font_pattern_failed
    str x0, [x22, #80]
    str x24, [x22, #64]
    mov x9, #2
    str x9, [x22, #72]
    mov x0, x23
    bl _FcPatternDestroy
    bl _pango_cairo_font_map_get_default
    bl _pango_fc_font_map_config_changed
    b Lgtk_font_completed
Lgtk_font_pattern_failed:
    mov x0, x23
    bl _FcPatternDestroy
    b Lgtk_font_file_failed
Lgtk_font_write_failed:
    mov x0, x23
    bl _close
Lgtk_font_file_failed:
    mov x0, x24
    bl _g_unlink
    mov x0, x24
    bl _g_free
Lgtk_font_completed:
    LEAVE
// loaded CSS family ID -> native decoded family name or NULL.
.globl _gtk_font_family_name
_gtk_font_family_name:
    ADDR x9, gtk_font_records
    LOAD x10, gtk_font_count
Lgtk_font_name:
    cbz x10, Lgtk_font_name_none
    ldr x11, [x9, #80]
    cmp x11, x0
    b.eq Lgtk_font_name_found
    add x9, x9, #128
    sub x10, x10, #1
    b Lgtk_font_name
Lgtk_font_name_found:
    ldr x0, [x9, #56]
    ret
Lgtk_font_name_none:
    mov x0, #0
    ret
.section __DATA,__bss
.p2align 3
gtk_font_records: .space 2048
gtk_font_count: .space 8
.globl _gtk_font_pending
_gtk_font_pending: .space 8
.section __TEXT,__cstring,cstring_literals
gtk_font_template: .asciz "oogabooga-font-XXXXXX"
gtk_font_family_property: .asciz "family"
