// Persistent-tree to native renderer bridge. Geometry and document ownership
// remain assembly; native dictionaries only retain image/control objects.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/dom.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// Current render flow index -> autoreleased dictionary key. A disjoint key
// space preserves fallback operation for snapshots without a persistent tree.
.globl _mac_control_key
_mac_control_key:
    ENTER
    mov x19, x0
    LOAD x9, _engine_render_document
    cbz x9, Lcontrol_key_ready
    ldr x10, [x9, #24]
    cmp x19, x10
    b.hs Lcontrol_key_ready
    ldr x9, [x9, #72]
    add x9, x9, x19, lsl #11
    ldr x9, [x9, #DOM_HANDLE]
    cbz x9, Lcontrol_key_ready
    orr x19, x9, #0x100000000
Lcontrol_key_ready:
    CLASS NSNumber
    mov x2, x19
    MSG numberLongLong
    LEAVE

// Nullable owned attribute strings compare by value, not allocation identity.
dom_equal_strings:
    cmp x0, x1
    b.eq Ldom_strings_yes
    cbz x0, Ldom_strings_no
    cbz x1, Ldom_strings_no
    b _strcmp
Ldom_strings_yes:
    mov x0, #0
    ret
Ldom_strings_no:
    mov x0, #1
    ret

// old,new snapshots -> BOOL. Transfer accepted resources only when the stable
// DOM element and its resource URL/media/relationship have not changed.
mac_dom_transfer:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x0, #4097
    mov x1, #8
    bl _calloc
    cbz x0, Ldom_transfer_fail
    mov x21, x0
    CLASS NSMutableDictionary
    MSG new
    mov x22, x0
    LOAD x23, _engine_images
    mov x24, #0
Ldom_transfer_index:
    ldr x9, [x20, #24]
    cmp x24, x9
    b.hs Ldom_transfer_begin
    ldr x9, [x20, #72]
    add x9, x9, x24, lsl #11
    ldr x9, [x9, #DOM_HANDLE]
    cbz x9, Ldom_transfer_index_next
    cmp x9, #DOM_MAX_NODES
    b.hi Ldom_transfer_index_next
    add x10, x24, #1
    str x10, [x21, x9, lsl #3]
Ldom_transfer_index_next:
    add x24, x24, #1
    b Ldom_transfer_index
Ldom_transfer_begin:
    mov x24, #0
Ldom_transfer_node:
    ldr x9, [x19, #24]
    cmp x24, x9
    b.hs Ldom_transfer_done
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x24, x10, x9
    ldr x10, [x9]
    str x10, [sp, #144]
    cmp x10, #NODE_LINK
    b.eq Ldom_transfer_candidate
    cmp x10, #NODE_IMG
    b.ne Ldom_transfer_next
Ldom_transfer_candidate:
    ldr x25, [x19, #72]
    add x25, x25, x24, lsl #11
    ldr x10, [x25, #DOM_HANDLE]
    cbz x10, Ldom_transfer_next
    cmp x10, #DOM_MAX_NODES
    b.hi Ldom_transfer_next
    ldr x26, [x21, x10, lsl #3]
    cbz x26, Ldom_transfer_next
    sub x26, x26, #1
    ldr x10, [x20, #16]
    mov x11, #40
    madd x10, x26, x11, x10
    ldr x11, [x10]
    ldr x12, [sp, #144]
    cmp x11, x12
    b.ne Ldom_transfer_next
    ldr x27, [x20, #72]
    add x27, x27, x26, lsl #11
    cmp x11, #NODE_IMG
    b.eq Ldom_transfer_image
    ldr x0, [x9, #32]
    ldr x1, [x10, #32]
    bl dom_equal_strings
    cbnz w0, Ldom_transfer_next
    ldr x0, [x25, #ATTR_REL]
    ldr x1, [x27, #ATTR_REL]
    bl dom_equal_strings
    cbnz w0, Ldom_transfer_next
    ldr x0, [x25, #ATTR_MEDIA]
    ldr x1, [x27, #ATTR_MEDIA]
    bl dom_equal_strings
    cbnz w0, Ldom_transfer_next
    ldr x0, [x25, #ATTR_CSS_DATA]
    cbz x0, Ldom_transfer_next
    bl _strdup
    str x0, [x27, #ATTR_CSS_DATA]
    b Ldom_transfer_next
Ldom_transfer_image:
    ldr x0, [x25, #ATTR_SRC]
    ldr x1, [x27, #ATTR_SRC]
    bl dom_equal_strings
    cbnz w0, Ldom_transfer_next
    CLASS NSNumber
    mov x2, x24
    MSG numberLongLong
    mov x2, x0
    mov x0, x23
    MSG objectKey
    cbz x0, Ldom_transfer_next
    mov x28, x0
    CLASS NSNumber
    mov x2, x26
    MSG numberLongLong
    mov x3, x0
    mov x2, x28
    mov x0, x22
    MSG setObjectKey
Ldom_transfer_next:
    add x24, x24, #1
    b Ldom_transfer_node
Ldom_transfer_done:
    STORE x22, _engine_images
    mov x0, x23
    MSG release
    mov x0, x21
    bl _free
    mov x0, #1
    LEAVE
Ldom_transfer_fail:
    mov x0, #0
    LEAVE

// Old displayed snapshot -> BOOL. No navigation/history entry is generated.
.globl _mac_dom_rebuild
_mac_dom_rebuild:
    ENTER
    mov x19, x0
    ldr x0, [x19, #96]
    bl _engine_dom_snapshot
    cbz x0, Ldom_rebuild_fail
    mov x20, x0
    mov x1, x20
    mov x0, x19
    bl mac_dom_transfer
    cbz x0, Ldom_rebuild_free
    bl _mac_engine_cancel
    mov x0, x20
    bl _mac_resources_rebind
    mov x9, #1
    STORE x9, _engine_reflowing
    mov x0, x20
    LOAD x1, _engine_url
    bl _mac_engine_display
    STORE xzr, _engine_reflowing
    cbz w0, Ldom_rebuild_restore
    STORE x20, _engine_document
    mov x0, x19
    bl _engine_document_free
    bl _mac_resources_next
    mov x0, #1
    LEAVE
Ldom_rebuild_restore:
    STORE x19, _engine_render_document
    mov x0, x19
    bl _mac_resources_rebind
Ldom_rebuild_free:
    mov x0, x20
    bl _engine_document_free
Ldom_rebuild_fail:
    mov x0, #0
    LEAVE

.globl _mac_control_epoch
_mac_control_epoch:
    ENTER
    LOAD x9, control_epoch
    add x9, x9, #1
    STORE x9, control_epoch
    CLASS NSNumber
    LOAD x2, control_epoch
    MSG numberLongLong
    LEAVE

// Hide removed elements without temporarily hiding live editors or disturbing
// their focus/caret during every style update. Cache lifetime is document-bound.
.globl _mac_controls_prune
_mac_controls_prune:
    ENTER
    mov x19, x0
    LOAD x0, _engine_controls
    MSG allValues
    mov x20, x0
    MSG count
    mov x21, x0
    mov x22, #0
Lcontrol_prune_next:
    cmp x22, x21
    b.hs Lcontrol_prune_done
    mov x0, x20
    mov x2, x22
    MSG objectAtIndex
    mov x23, x0
    ADDR x1, _mac_control_active_key
    bl _objc_getAssociatedObject
    cmp x0, x19
    b.eq Lcontrol_prune_advance
    mov x0, x23
    mov x2, #1
    MSG setHidden
Lcontrol_prune_advance:
    mov x0, x23
    MSG sceneHidden
    cbz x0, Lcontrol_prune_visible
    mov x0, x23
    bl _mac_scene_control_hide
Lcontrol_prune_visible:
    add x22, x22, #1
    b Lcontrol_prune_next
Lcontrol_prune_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
.globl _mac_control_active_key
_mac_control_active_key: .asciz "assemblyControlEpoch"
.section __DATA,__bss
.p2align 3
control_epoch: .space 8
