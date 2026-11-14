// Select options are retained HTML nodes; labels and values are decoded by our
// parser. AppKit supplies popup menus, never an HTML importer.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
// document, select index, metadata -> owned NSPopUpButton.
.globl _mac_select_create
_mac_select_create:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    CLASS NSPopUpButton
    MSG alloc
    RECT 0, 0, 220, 28
    mov x2, #0
    MSG initPopup
    mov x22, x0
    ldr x9, [x21, #ATTR_MULTIPLE]
    cbz x9, Loption_menu
    MSG cell
    mov x2, #0
    MSG setAltersState
Loption_menu:
    mov x0, x22
    MSG menu
    mov x23, x0
    mov x2, #0
    MSG setAutoenables
    add x24, x20, #1
    mov x28, #0                     // first/last selected enabled item
Loption_next:
    ldr x9, [x19, #24]
    cmp x24, x9
    b.hs Loption_finish
    ldr x25, [x19, #16]
    mov x9, #40
    madd x25, x24, x9, x25
    ldr x9, [x25]
    cmp x9, #NODE_OPTION
    b.ne Loption_advance
    ldr x9, [x25, #8]
    cmp x9, x20
    b.ne Loption_advance
    ldr x26, [x19, #72]
    add x26, x26, x24, lsl #10
    ldr x9, [x19]
    ldr x10, [x25, #16]
    add x0, x9, x10
    ldr x1, [x25, #24]
    add x1, x9, x1
    bl _css_trim
    sub x1, x1, x0
    bl _strndup
    mov x27, x0
    bl _mac_string
    str x0, [sp, #144]
    CLASS NSMenuItem
    MSG new
    mov x25, x0
    ldr x2, [sp, #144]
    MSG setTitle
    mov x0, x27
    bl _free
    ldr x0, [x26, #ATTR_VALUE]
    cbz x0, Loption_label_value
    bl _mac_string
    b Loption_value
Loption_label_value:
    ldr x0, [sp, #144]
Loption_value:
    mov x2, x0
    mov x0, x25
    MSG setRepresentedObject
    mov x0, x25
    mov x2, x24
    MSG setTag
    mov x0, x25
    ldr x9, [x26, #ATTR_DISABLED]
    cmp x9, #0
    cset w2, eq
    MSG setEnabled
    ldr x9, [x26, #ATTR_DISABLED]
    cbnz x9, Loption_add
    cbnz x28, Loption_selected
    mov x28, x25
Loption_selected:
    ldr x9, [x26, #ATTR_SELECTED]
    cbz x9, Loption_multiple
    mov x28, x25
    mov x0, x25
    mov x2, #1
    MSG setState
Loption_multiple:
    ldr x9, [x21, #ATTR_MULTIPLE]
    cbz x9, Loption_add
    mov x0, x25
    LOAD x2, _mac_delegate
    MSG setTarget
    mov x0, x25
    SELECT x2, selectToggle
    MSG setAction
Loption_add:
    mov x0, x23
    mov x2, x25
    MSG addItem
    mov x0, x25
    MSG release
Loption_advance:
    add x24, x24, #1
    b Loption_next
Loption_finish:
    cbz x28, Loption_return
    mov x0, x22
    mov x2, x28
    MSG selectItem
Loption_return:
    mov x0, x22
    LEAVE

.globl _mac_select_toggle
_mac_select_toggle:
    ENTER
    mov x19, x2
    mov x0, x19
    MSG state
    eor x2, x0, #1
    mov x0, x19
    MSG setState
    LEAVE

// popup, metadata -> autoreleased array of successful option values.
.globl _mac_select_values
_mac_select_values:
    ENTER
    mov x19, x0
    mov x20, x1
    CLASS NSMutableArray
    MSG new
    mov x21, x0
    ldr x9, [x20, #ATTR_MULTIPLE]
    cbnz x9, Lselect_multiple
    mov x0, x19
    MSG selectedItem
    cbz x0, Lselect_values_done
    mov x22, x0
    MSG isEnabled
    cbz w0, Lselect_values_done
    mov x0, x22
    MSG representedObject
    cbz x0, Lselect_values_done
    mov x2, x0
    mov x0, x21
    MSG addObject
    b Lselect_values_done
Lselect_multiple:
    mov x0, x19
    MSG itemArray
    mov x22, x0
    MSG count
    mov x23, x0
    mov x24, #0
Lselect_value_next:
    cmp x24, x23
    b.hs Lselect_values_done
    mov x0, x22
    mov x2, x24
    MSG objectAtIndex
    mov x25, x0
    MSG isEnabled
    cbz w0, Lselect_value_advance
    mov x0, x25
    MSG state
    cmp x0, #1
    b.ne Lselect_value_advance
    mov x0, x25
    MSG representedObject
    cbz x0, Lselect_value_advance
    mov x2, x0
    mov x0, x21
    MSG addObject
Lselect_value_advance:
    add x24, x24, #1
    b Lselect_value_next
Lselect_values_done:
    mov x0, x21
    MSG autorelease
    LEAVE
