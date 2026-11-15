// Sequential stylesheet imports share the page's existing NSURLSession, cookies,
// cancellation identity, MIME validation and request/byte budgets.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.include "src/engine/engine.inc"
.include "src/engine/imports.inc"
.text
.p2align 2
.globl _mac_imports_reset
_mac_imports_reset:
    ENTER
    ADDR x19, import_records
    LOAD x20, import_count
    STORE xzr, import_active
    STORE xzr, _mac_import_pending
    STORE xzr, import_count
Limports_free:
    cbz x20, Limports_freed
    ldr x0, [x19, #IMPORT_SOURCE]
    bl _free
    ldr x0, [x19, #IMPORT_MEDIA]
    bl _free
    ldr x0, [x19, #IMPORT_URL]
    MSG release
    add x19, x19, #IMPORT_SIZE
    sub x20, x20, #1
    b Limports_free
Limports_freed:
    ADDR x0, import_records
    mov x1, #0
    mov x2, #8192
    bl _memset
    LEAVE

// original source*, owner flow node, final stylesheet base NSURL.
.globl _mac_imports_add
_mac_imports_add:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    cbz x19, Limports_add_done
    LOAD x22, import_count
    cmp x22, #IMPORT_MAX
    b.hs Limports_add_done
    // Rebinding or revisiting a resource must not register duplicate roots.
    ADDR x23, import_records
    mov x24, #0
Limports_existing:
    cmp x24, x22
    b.hs Limports_add_new
    add x9, x23, x24, lsl #7
    ldr x10, [x9, #IMPORT_PARENT]
    cbnz x10, Limports_existing_next
    ldr x10, [x9, #IMPORT_OWNER]
    cmp x10, x20
    b.eq Limports_add_done
Limports_existing_next:
    add x24, x24, #1
    b Limports_existing
Limports_add_new:
    mov x0, x19
    bl _strlen
    mov x24, x0
    mov x9, #1048576
    cmp x24, x9
    b.hi Limports_add_done
    mov x0, x19
    mov x1, x24
    mov x2, #0
    add x3, sp, #144
    bl _engine_css_import_next
    cbz x0, Limports_add_done
    ldr x0, [sp, #144]
    bl _free
    ldr x0, [sp, #152]
    bl _free
    mov x0, x19
    mov x1, x24
    bl _strndup
    cbz x0, Limports_add_done
    add x23, x23, x22, lsl #7
    str x0, [x23, #IMPORT_SOURCE]
    str x24, [x23, #IMPORT_LENGTH]
    str x20, [x23, #IMPORT_OWNER]
    LOAD x9, _engine_resource_doc
    ldr x9, [x9, #72]
    add x9, x9, x20, lsl #11
    ldr x9, [x9, #DOM_HANDLE]
    str x9, [x23, #112]           // stable root identity across DOM snapshots
    mov x0, x21
    bl import_canonical_url
    MSG retain
    str x0, [x23, #IMPORT_URL]
    add x22, x22, #1
    STORE x22, import_count
    STORE x22, import_active
Limports_add_done:
    LEAVE

// Returns the next import NSURL, or nil when the active root is exhausted.
.globl _mac_imports_next
_mac_imports_next:
    ENTER
    ADDR x19, import_records
    LOAD x9, _mac_import_pending
    cbz x9, Limports_scan
    sub x9, x9, #1
    add x9, x19, x9, lsl #7
    ldr x10, [x9, #IMPORT_OWNER]
    STORE x10, _mac_import_owner
    ldr x0, [x9, #IMPORT_URL]
    LEAVE
Limports_scan:
    LOAD x20, import_active
    cbz x20, Limports_none
    sub x20, x20, #1
    add x21, x19, x20, lsl #7
    ldr x0, [x21, #IMPORT_SOURCE]
    cbz x0, Limports_pop
    ldr x1, [x21, #IMPORT_LENGTH]
    ldr x2, [x21, #IMPORT_SCAN]
    add x3, sp, #144
    bl _engine_css_import_next
    cbz x0, Limports_pop
    ldr x9, [sp, #176]
    str x9, [x21, #IMPORT_SCAN]
    LOAD x22, import_count
    cmp x22, #IMPORT_MAX
    b.hs Limports_drop_descriptor
    add x23, x19, x22, lsl #7
    add x9, x20, #1
    str x9, [x23, #IMPORT_PARENT]
    ldr x9, [x21, #IMPORT_OWNER]
    str x9, [x23, #IMPORT_OWNER]
    ldp x9, x10, [sp, #160]
    stp x9, x10, [x23, #IMPORT_START]
    ldr x9, [sp, #152]
    str x9, [x23, #IMPORT_MEDIA]
    ldr x9, [x21, #IMPORT_LEVEL]
    add x9, x9, #1
    str x9, [x23, #IMPORT_LEVEL]
    ldr x10, [x21, #IMPORT_LAST]
    add x22, x22, #1
    cbz x10, Limports_first_child
    sub x10, x10, #1
    add x10, x19, x10, lsl #7
    str x22, [x10, #IMPORT_NEXT]
    b Limports_child_linked
Limports_first_child:
    str x22, [x21, #IMPORT_FIRST]
Limports_child_linked:
    str x22, [x21, #IMPORT_LAST]
    STORE x22, import_count
    cmp x9, #IMPORT_DEPTH
    b.hi Limports_drop_url
    ldr x0, [sp, #144]
    bl _mac_string
    mov x24, x0
    CLASS NSURL
    mov x2, x24
    ldr x3, [x21, #IMPORT_URL]
    MSG relativeURL
    MSG absoluteURL
    bl import_canonical_url
    cbz x0, Limports_drop_url
    mov x24, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz x0, Limports_drop_url
    // Compare canonical absolute URLs against every ancestor, including roots.
    mov x25, x21
Limports_cycle:
    ldr x0, [x25, #IMPORT_URL]
    mov x2, x24
    MSG equalObject
    cbnz x0, Limports_drop_url
    ldr x9, [x25, #IMPORT_PARENT]
    cbz x9, Limports_fetch
    sub x9, x9, #1
    add x25, x19, x9, lsl #7
    b Limports_cycle
Limports_fetch:
    mov x0, x24
    MSG retain
    str x0, [x23, #IMPORT_URL]
    STORE x22, _mac_import_pending
    ldr x9, [x23, #IMPORT_OWNER]
    STORE x9, _mac_import_owner
    ldr x0, [sp, #144]
    bl _free
    mov x0, x24
    LEAVE
Limports_drop_url:
    ldr x0, [sp, #144]
    bl _free
    b Limports_scan
Limports_drop_descriptor:
    ldr x0, [sp, #144]
    bl _free
    ldr x0, [sp, #152]
    bl _free
    b Limports_pop
Limports_pop:
    ldr x9, [x21, #IMPORT_PARENT]
    STORE x9, import_active
    b Limports_scan
Limports_none:
    mov x0, #0
    LEAVE

// decoded UTF-8 source*, length (or nil for any rejected/failed fetch).
.globl _mac_imports_complete
_mac_imports_complete:
    ENTER
    mov x19, x0
    mov x20, x1
    LOAD x21, _mac_import_pending
    cbz x21, Limports_complete_done
    STORE xzr, _mac_import_pending
    STORE x21, import_active
    sub x21, x21, #1
    ADDR x22, import_records
    add x22, x22, x21, lsl #7
    cbz x19, Limports_complete_done
    mov x9, #1048576
    cmp x20, x9
    b.hi Limports_complete_done
    mov x0, x19
    mov x1, x20
    bl _strndup
    cbz x0, Limports_complete_done
    str x0, [x22, #IMPORT_SOURCE]
    str x20, [x22, #IMPORT_LENGTH]
Limports_complete_done:
    LEAVE

// Expand roots into the normal owned stylesheet metadata. The original source
// remains private, so subsequent child arrivals preserve the same source order.
.globl _mac_imports_styles
_mac_imports_styles:
    ENTER
    LOAD x19, _engine_resource_doc
    cbz x19, Limports_styles_done
    LOAD x20, import_count
    ADDR x21, import_records
    mov x22, #0
Limports_styles_next:
    cmp x22, x20
    b.hs Limports_styles_done
    add x23, x21, x22, lsl #7
    ldr x9, [x23, #IMPORT_PARENT]
    cbnz x9, Limports_styles_advance
    ldr x24, [x23, #IMPORT_OWNER]
    ldr x9, [x19, #24]
    cmp x24, x9
    b.hs Limports_styles_advance
    mov x0, x21
    mov x1, x20
    mov x2, x22
    add x3, sp, #144
    bl _engine_css_import_expand
    cbz x0, Limports_styles_advance
    mov x25, x0
    ldr x26, [x19, #72]
    add x26, x26, x24, lsl #11
    ldr x0, [x26, #ATTR_CSS_DATA]
    bl _free
    str x25, [x26, #ATTR_CSS_DATA]
Limports_styles_advance:
    add x22, x22, #1
    b Limports_styles_next
Limports_styles_done:
    LEAVE
.section __DATA,__bss
.p2align 3
import_records: .space 8192
import_count: .space 8
import_active: .space 8
.globl _mac_import_pending, _mac_import_owner
_mac_import_pending: .space 8
_mac_import_owner: .space 8

.text
.p2align 2
// New flow snapshot after a stable-DOM mutation. Keep accepted child CSS and
// resolve owners again; canceled pending tasks can restart with their own URL.
.globl _mac_imports_rebind
_mac_imports_rebind:
    ENTER
    mov x19, x0
    ADDR x20, import_records
    LOAD x21, import_count
    mov x22, #0
Limports_rebind_next:
    cmp x22, x21
    b.hs Limports_rebind_active
    add x23, x20, x22, lsl #7
    ldr x9, [x23, #IMPORT_PARENT]
    cbnz x9, Limports_rebind_child
    ldr x24, [x23, #112]
    mov x9, #-1
    str x9, [x23, #IMPORT_OWNER]
    cbz x24, Limports_rebind_advance
    mov x25, #0
Limports_rebind_find:
    ldr x9, [x19, #24]
    cmp x25, x9
    b.hs Limports_rebind_advance
    ldr x26, [x19, #72]
    add x26, x26, x25, lsl #11
    ldr x9, [x26, #DOM_HANDLE]
    cmp x9, x24
    b.ne Limports_rebind_find_next
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x25, x10, x9
    ldr x10, [x9]
    cmp x10, #NODE_LINK
    b.eq Limports_rebind_link
    ldr x0, [x9, #32]
    ldr x1, [x23, #IMPORT_SOURCE]
    cbz x0, Limports_rebind_advance
    cbz x1, Limports_rebind_advance
    bl _strcmp
    cbnz x0, Limports_rebind_advance
    b Limports_rebind_found
Limports_rebind_link:
    ldr x9, [x26, #ATTR_CSS_DATA]
    cbz x9, Limports_rebind_advance
Limports_rebind_found:
    str x25, [x23, #IMPORT_OWNER]
    b Limports_rebind_advance
Limports_rebind_find_next:
    add x25, x25, #1
    b Limports_rebind_find
Limports_rebind_child:
    sub x9, x9, #1
    add x9, x20, x9, lsl #7
    ldr x9, [x9, #IMPORT_OWNER]
    str x9, [x23, #IMPORT_OWNER]
Limports_rebind_advance:
    add x22, x22, #1
    b Limports_rebind_next
Limports_rebind_active:
    LOAD x9, import_active
    cbz x9, Limports_rebind_pending
    sub x9, x9, #1
    add x9, x20, x9, lsl #7
    ldr x9, [x9, #IMPORT_OWNER]
    tbz x9, #63, Limports_rebind_pending
    STORE xzr, import_active
Limports_rebind_pending:
    LOAD x9, _mac_import_pending
    cbz x9, Limports_rebind_done
    sub x9, x9, #1
    add x9, x20, x9, lsl #7
    ldr x9, [x9, #IMPORT_OWNER]
    tbz x9, #63, Limports_rebind_done
    STORE xzr, _mac_import_pending
Limports_rebind_done:
    LEAVE

// Normalize dot segments and discard fragments, which never identify a
// different HTTP stylesheet. The same canonical URL drives fetches and cycles.
import_canonical_url:
    ENTER
    mov x19, x0
    cbz x19, Limport_url_nil
    CLASS NSURLComponents
    mov x2, x19
    mov x3, #1
    MSG componentsURL
    mov x19, x0
    mov x2, #0
    MSG setURLFragment
    mov x0, x19
    MSG URL
    MSG standardizedURL
    LEAVE
Limport_url_nil:
    mov x0, #0
    LEAVE

// Final response URL becomes the base for nested imports. A redirect back to an
// ancestor is a cycle too, and must be rejected before accepting response data.
.globl _mac_imports_accept_url
_mac_imports_accept_url:
    ENTER
    mov x19, x0
    LOAD x20, _mac_import_pending
    cbz x20, Limport_accept_yes
    mov x0, x19
    bl import_canonical_url
    cbz x0, Limport_accept_no
    mov x19, x0
    sub x20, x20, #1
    ADDR x21, import_records
    add x20, x21, x20, lsl #7
    ldr x22, [x20, #IMPORT_PARENT]
Limport_accept_ancestor:
    cbz x22, Limport_accept_store
    sub x22, x22, #1
    add x23, x21, x22, lsl #7
    ldr x0, [x23, #IMPORT_URL]
    mov x2, x19
    MSG equalObject
    cbnz x0, Limport_accept_no
    ldr x22, [x23, #IMPORT_PARENT]
    b Limport_accept_ancestor
Limport_accept_store:
    mov x0, x19
    MSG retain
    mov x19, x0
    ldr x0, [x20, #IMPORT_URL]
    MSG release
    str x19, [x20, #IMPORT_URL]
Limport_accept_yes:
    mov x0, #1
    LEAVE
Limport_accept_no:
    mov x0, #0
    LEAVE
