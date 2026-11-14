// Supply native editing with a window-owned undo manager. AppKit routes menu
// actions through the focused responder; no custom clipboard/key interception.
.include "src/mac/mac.inc"
.text
.p2align 2
// NSUndoManager *windowWillReturnUndoManager:(NSWindow *)window
.globl _mac_window_undo
_mac_window_undo:
    ENTER
    mov x19, x2
    mov x0, x19
    ADDR x1, undo_key
    bl _objc_getAssociatedObject
    cbnz x0, Lundo_manager_done
    CLASS NSUndoManager
    MSG new
    mov x20, x0
    mov x0, x19
    ADDR x1, undo_key
    mov x2, x20
    mov x3, #1                      // OBJC_ASSOCIATION_RETAIN_NONATOMIC
    bl _objc_setAssociatedObject
    mov x0, x20
    MSG release
    mov x0, x20
Lundo_manager_done:
    LEAVE

// Nested textareas must bypass the surrounding read-only document text view's
// undo responder. They still share the native window's editing manager.
.globl _mac_text_undo
_mac_text_undo:
    ENTER
    mov x0, x2
    MSG window
    MSG undoManager
    LEAVE

// New documents must not retain undo actions targeting removed form controls.
.globl _mac_undo_clear
_mac_undo_clear:
    ENTER
    LOAD x0, _mac_window
    MSG undoManager
    MSG removeUndoActions
    LEAVE
.section __DATA,__bss
.p2align 3
undo_key: .space 8
