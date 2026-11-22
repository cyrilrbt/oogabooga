// Stable DOM handles preserve editors and accepted resources during rebuilds.
.include "src/gtk/gtk.inc"
.text
// old,new -> BOOL. Resources transfer only with unchanged source/rel/media.
gtk_dom_transfer:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, #4097
    mov x1, #8
    bl _calloc
    cbz x0, Lgtk_dom_transfer_failed
    mov x21, x0
    mov x22, #1
Lgtk_dom_index:
    ldr x9, [x19, #24]
    cmp x22, x9
    b.hs Lgtk_dom_transfer_begin
    ldr x9, [x19, #72]
    add x9, x9, x22, lsl #11
    ldr x9, [x9, #DOM_HANDLE]
    cbz x9, Lgtk_dom_index_next
    cmp x9, #4096
    b.hi Lgtk_dom_index_next
    str x22, [x21, x9, lsl #3]
Lgtk_dom_index_next:
    add x22, x22, #1
    b Lgtk_dom_index
Lgtk_dom_transfer_begin:
    mov x22, #1
Lgtk_dom_transfer_node:
    ldr x9, [x20, #24]
    cmp x22, x9
    b.hs Lgtk_dom_transferred
    ldr x23, [x20, #72]
    add x23, x23, x22, lsl #11
    ldr x9, [x23, #DOM_HANDLE]
    cmp x9, #4096
    b.hi Lgtk_dom_transfer_next
    ldr x24, [x21, x9, lsl #3]
    cbz x24, Lgtk_dom_transfer_next
    ldr x25, [x20, #16]
    mov x9, #40
    madd x25, x22, x9, x25
    ldr x10, [x25]
    cmp x10, #NODE_LINK
    b.eq Lgtk_dom_resource
    cmp x10, #NODE_SHEET
    b.ne Lgtk_dom_transfer_next
Lgtk_dom_resource:
    ldr x26, [x19, #16]
    madd x26, x24, x9, x26
    ldr x11, [x26]
    cmp x10, x11
    b.ne Lgtk_dom_transfer_next
    ldr x0, [x25, #32]
    ldr x1, [x26, #32]
    bl _g_strcmp0
    cbnz x0, Lgtk_dom_transfer_next
    ldr x26, [x19, #72]
    add x26, x26, x24, lsl #11
    ldr x0, [x23, #ATTR_REL]
    ldr x1, [x26, #ATTR_REL]
    bl _g_strcmp0
    cbnz x0, Lgtk_dom_transfer_next
    ldr x0, [x23, #ATTR_MEDIA]
    ldr x1, [x26, #ATTR_MEDIA]
    bl _g_strcmp0
    cbnz x0, Lgtk_dom_transfer_next
    ldr x0, [x26, #ATTR_CSS_DATA]
    cbz x0, Lgtk_dom_transfer_next
    bl _g_strdup
    str x0, [x23, #ATTR_CSS_DATA]
Lgtk_dom_transfer_next:
    add x22, x22, #1
    b Lgtk_dom_transfer_node
Lgtk_dom_transferred:
    mov x0, x21
    bl _free
    mov x0, #1
    LEAVE
Lgtk_dom_transfer_failed:
    mov x0, #0
    LEAVE
// Current displayed document -> BOOL. Rebuild does not navigate or add a visit.
.globl _gtk_dom_rebuild
_gtk_dom_rebuild:
    ENTER
    mov x19, x0
    LOAD x9, _gtk_doc
    cmp x19, x9
    b.ne Lgtk_dom_rebuild_failed
    ldr x0, [x19, #96]
    bl _engine_dom_snapshot
    cbz x0, Lgtk_dom_rebuild_failed
    mov x20, x0
    mov x1, x20
    mov x0, x19
    bl gtk_dom_transfer
    cbz x0, Lgtk_dom_new_free
    bl _gtk_selection_reset
    bl _gtk_engine_cancel_load
    bl _g_cancellable_new
    STORE x0, _gtk_cancel
    bl _gtk_imports_reset
    STORE x20, _gtk_doc
    bl _gtk_resources_styles
    mov x0, x20
    LOAD x1, _gtk_width
    bl _gtk_engine_prepare
    cbz x0, Lgtk_dom_rebuild_restore
    bl _gtk_engine_place
    mov x0, x19
    bl _engine_document_free
    bl _gtk_engine_dom_changed
    LOAD x9, _gtk_session
    cbz x9, Lgtk_dom_rebuild_ready
    bl _gtk_resources_rebind
Lgtk_dom_rebuild_ready:
    mov x0, #1
    LEAVE
Lgtk_dom_rebuild_restore:
    STORE x19, _gtk_doc
    mov x0, x19
    LOAD x1, _gtk_width
    bl _gtk_engine_prepare
    bl _gtk_engine_place
Lgtk_dom_new_free:
    mov x0, x20
    bl _engine_document_free
Lgtk_dom_rebuild_failed:
    mov x0, #0
    LEAVE
