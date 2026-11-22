// Bounded stylesheet import forest. Expansion is shared with the macOS engine.
.include "src/gtk/gtk.inc"
.include "src/engine/imports.inc"
.text
.globl _gtk_imports_reset
_gtk_imports_reset:
    ENTER
    LOAD x19, gtk_import_count
    ADDR x20, gtk_import_records
    STORE xzr, gtk_import_count
Lgtk_import_free:
    cbz x19, Lgtk_import_zero
    ldr x0, [x20, #IMPORT_SOURCE]
    bl _free
    ldr x0, [x20, #IMPORT_URL]
    bl _g_free
    ldr x0, [x20, #IMPORT_MEDIA]
    bl _free
    add x20, x20, #IMPORT_SIZE
    sub x19, x19, #1
    b Lgtk_import_free
Lgtk_import_zero:
    ADDR x0, gtk_import_records
    mov x1, #0
    mov x2, #8192
    bl _memset
    LEAVE
// source, owning node, resolved stylesheet URL -> register original root.
.globl _gtk_imports_add
_gtk_imports_add:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    LOAD x22, gtk_import_count
    cmp x22, #IMPORT_MAX
    b.hs Lgtk_import_add_done
    ADDR x23, gtk_import_records
    mov x24, #0
Lgtk_import_find_root:
    cmp x24, x22
    b.hs Lgtk_import_add_root
    add x9, x23, x24, lsl #7
    ldr x10, [x9, #IMPORT_PARENT]
    cbnz x10, Lgtk_import_find_next
    ldr x10, [x9, #IMPORT_OWNER]
    cmp x10, x20
    b.eq Lgtk_import_add_done
Lgtk_import_find_next:
    add x24, x24, #1
    b Lgtk_import_find_root
Lgtk_import_add_root:
    add x23, x23, x22, lsl #7
    str x20, [x23, #IMPORT_OWNER]
    mov x0, x19
    bl _strlen
    str x0, [x23, #IMPORT_LENGTH]
    mov x0, x19
    bl _g_strdup
    str x0, [x23, #IMPORT_SOURCE]
    mov x0, x21
    bl _g_strdup
    str x0, [x23, #IMPORT_URL]
    mov x9, #1
    str x9, [x23, #IMPORT_STATUS]
    add x22, x22, #1
    STORE x22, gtk_import_count
Lgtk_import_add_done:
    LEAVE
// -> borrowed URL or NULL. The pending index belongs to this navigation only.
.globl _gtk_imports_next
_gtk_imports_next:
    ENTER
    mov x19, #0
    ADDR x20, gtk_import_records
Lgtk_import_scan:
    LOAD x9, gtk_import_count
    cmp x19, x9
    b.hs Lgtk_import_none
    cmp x9, #IMPORT_MAX
    b.hs Lgtk_import_none
    add x21, x20, x19, lsl #7
    ldr x9, [x21, #IMPORT_LEVEL]
    cmp x9, #IMPORT_DEPTH
    b.hs Lgtk_import_scan_advance
    ldr x0, [x21, #IMPORT_SOURCE]
    cbz x0, Lgtk_import_scan_advance
    ldr x1, [x21, #IMPORT_LENGTH]
    ldr x2, [x21, #IMPORT_SCAN]
    cmp x2, x1
    b.hs Lgtk_import_scan_advance
    add x3, sp, #144
    bl _engine_css_import_next
    cbz x0, Lgtk_import_scan_exhausted
    ldr x9, [sp, #176]
    str x9, [x21, #IMPORT_SCAN]
    ldr x0, [x21, #IMPORT_URL]
    ldr x1, [sp, #144]
    mov x2, #0
    mov x3, #0
    bl _g_uri_resolve_relative
    mov x22, x0
    ldr x0, [sp, #144]
    bl _free
    cbz x22, Lgtk_import_discard_media
    // A canonical ancestor URL cannot import itself again.
    mov x23, x19
Lgtk_import_cycle:
    add x24, x20, x23, lsl #7
    mov x0, x22
    ldr x1, [x24, #IMPORT_URL]
    bl _g_strcmp0
    cbz x0, Lgtk_import_discard_url
    ldr x23, [x24, #IMPORT_PARENT]
    cbz x23, Lgtk_import_child
    sub x23, x23, #1
    b Lgtk_import_cycle
Lgtk_import_child:
    LOAD x23, gtk_import_count
    add x24, x20, x23, lsl #7
    ldr x9, [x21, #IMPORT_OWNER]
    str x9, [x24, #IMPORT_OWNER]
    add x9, x19, #1
    str x9, [x24, #IMPORT_PARENT]
    str x22, [x24, #IMPORT_URL]
    ldr x9, [sp, #152]
    str x9, [x24, #IMPORT_MEDIA]
    ldr x9, [sp, #160]
    str x9, [x24, #IMPORT_START]
    ldr x9, [sp, #168]
    str x9, [x24, #IMPORT_END]
    ldr x9, [x21, #IMPORT_LEVEL]
    add x9, x9, #1
    str x9, [x24, #IMPORT_LEVEL]
    ldr x9, [x21, #IMPORT_LAST]
    add x10, x23, #1
    cbz x9, Lgtk_import_first_child
    sub x9, x9, #1
    add x9, x20, x9, lsl #7
    str x10, [x9, #IMPORT_NEXT]
    b Lgtk_import_child_linked
Lgtk_import_first_child:
    str x10, [x21, #IMPORT_FIRST]
Lgtk_import_child_linked:
    str x10, [x21, #IMPORT_LAST]
    STORE x10, gtk_import_count
    STORE x23, _gtk_import_pending
    mov x0, x22
    LEAVE
Lgtk_import_discard_url:
    mov x0, x22
    bl _g_free
Lgtk_import_discard_media:
    ldr x0, [sp, #152]
    bl _free
    b Lgtk_import_scan
Lgtk_import_scan_exhausted:
    ldr x9, [x21, #IMPORT_LENGTH]
    str x9, [x21, #IMPORT_SCAN]
Lgtk_import_scan_advance:
    add x19, x19, #1
    b Lgtk_import_scan
Lgtk_import_none:
    mov x0, #0
    LEAVE
// index,UTF8 or NULL,length -> record success/failure without reordering roots.
.globl _gtk_imports_complete
_gtk_imports_complete:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ADDR x22, gtk_import_records
    add x22, x22, x19, lsl #7
    cbz x20, Lgtk_import_complete_failed
    mov x0, x20
    mov x1, x21
    bl _g_strndup
    str x0, [x22, #IMPORT_SOURCE]
    str x21, [x22, #IMPORT_LENGTH]
Lgtk_import_complete_failed:
    mov x9, #1
    str x9, [x22, #IMPORT_STATUS]
    LEAVE
.globl _gtk_imports_styles
_gtk_imports_styles:
    ENTER
    LOAD x19, gtk_import_count
    ADDR x20, gtk_import_records
    mov x21, #0
Lgtk_import_expand:
    cmp x21, x19
    b.hs Lgtk_import_styles_done
    add x22, x20, x21, lsl #7
    ldr x9, [x22, #IMPORT_PARENT]
    cbnz x9, Lgtk_import_expand_next
    mov x0, x20
    mov x1, x19
    mov x2, x21
    add x3, sp, #144
    bl _engine_css_import_expand
    cbz x0, Lgtk_import_expand_next
    mov x23, x0
    ldr x0, [x22, #IMPORT_OWNER]
    bl _gtk_engine_node
    mov x24, x0
    ldr x0, [x24, #ATTR_CSS_DATA]
    bl _free
    str x23, [x24, #ATTR_CSS_DATA]
Lgtk_import_expand_next:
    add x21, x21, #1
    b Lgtk_import_expand
Lgtk_import_styles_done:
    LEAVE
.section __DATA,__bss
.p2align 3
gtk_import_records: .space 8192
gtk_import_count: .space 8
.globl _gtk_import_pending
_gtk_import_pending: .space 8
