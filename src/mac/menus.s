.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_menus
_mac_menus:
    ENTER
    CLASS NSMenu
    MSG new
    mov x19, x0
    STR app_text
    bl _mac_submenu
    mov x20, x0
    ADDR x21, app_items
    bl _mac_menu_items
    mov x0, x19
    STR edit_text
    bl _mac_submenu
    mov x20, x0
    ADDR x21, edit_items
    bl _mac_menu_items
    mov x0, x19
    STR nav_text
    bl _mac_submenu
    mov x20, x0
    ADDR x21, nav_items
    bl _mac_menu_items
    LOAD x0, _mac_app
    mov x2, x19
    MSG setMainMenu
    mov x0, x19
    MSG release
    LEAVE

// Parent menu in x19, title NSString in x0. Returns submenu retained by parent.
_mac_submenu:
    ENTER
    mov x20, x0
    CLASS NSMenuItem
    MSG new
    mov x21, x0
    mov x2, x20
    MSG setTitle
    CLASS NSMenu
    MSG new
    mov x22, x0
    mov x2, x22
    mov x0, x21
    MSG setSubmenu
    mov x0, x19
    mov x2, x21
    MSG addItem
    mov x0, x21
    MSG release
    mov x0, x22
    MSG release
    mov x0, x22
    LEAVE

// Each item: C title, selector slot, C key, target flag, native modifier mask.
_mac_menu_items:
    ENTER
    mov x19, x21
Lmenu_next:
    ldr x0, [x19]
    cbz x0, Lmenu_done
    bl _mac_string
    mov x21, x0
    ldr x0, [x19, #16]
    bl _mac_string
    mov x4, x0
    mov x2, x21
    ldr x9, [x19, #8]
    ldr x3, [x9]
    mov x0, x20
    MSG addMenuItem
    mov x22, x0
    ldr x2, [x19, #32]
    MSG setKeyMask
    ldr x9, [x19, #24]
    cbz x9, Lmenu_advance
    mov x0, x22
    LOAD x2, _mac_delegate
    MSG setTarget
Lmenu_advance:
    add x19, x19, #40
    b Lmenu_next
Lmenu_done:
    LEAVE
.section __DATA,__const
.p2align 3
app_items:
.quad quit_text, _sel_terminate, q_key, 0, 0x100000
.quad 0, 0, 0, 0, 0
edit_items:
.quad undo_text, _sel_undo, z_key, 0, 0x100000
.quad redo_text, _sel_redo, z_key, 0, 0x120000
.quad cut_text, _sel_cut, x_key, 0, 0x100000
.quad copy_text, _sel_copy, c_key, 0, 0x100000
.quad paste_text, _sel_paste, v_key, 0, 0x100000
.quad select_text, _sel_selectAll, a_key, 0, 0x100000
.quad 0, 0, 0, 0, 0
nav_items:
.quad open_text, _sel_focus, l_key, 1, 0x100000
.quad reload_text, _sel_reload, r_key, 1, 0x100000
.quad back_text, _sel_goBack, left_key, 1, 0x100000
.quad forward_text, _sel_goForward, right_key, 1, 0x100000
.quad history_text, _sel_showHistory, y_key, 1, 0x100000
.quad engine_text, _sel_engineToggle, e_key, 1, 0x100000
.quad 0, 0, 0, 0, 0
.section __TEXT,__cstring,cstring_literals
engine_text: .asciz "Use Assembly Engine (Experimental)"
e_key: .asciz "e"
app_text: .asciz "Oogabooga"
edit_text: .asciz "Edit"
nav_text: .asciz "Navigate"
quit_text: .asciz "Quit Oogabooga"
undo_text: .asciz "Undo"
redo_text: .asciz "Redo"
cut_text: .asciz "Cut"
copy_text: .asciz "Copy"
paste_text: .asciz "Paste"
select_text: .asciz "Select All"
open_text: .asciz "Open Location"
reload_text: .asciz "Reload"
back_text: .asciz "Back"
forward_text: .asciz "Forward"
history_text: .asciz "History"
q_key: .asciz "q"
z_key: .asciz "z"
x_key: .asciz "x"
c_key: .asciz "c"
v_key: .asciz "v"
a_key: .asciz "a"
l_key: .asciz "l"
r_key: .asciz "r"
left_key: .asciz "["
right_key: .asciz "]"
y_key: .asciz "y"
