// SQLite queries/callbacks and native history table. No Objective-C source bridge.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_show_history
_mac_show_history:
    ENTER
    LOAD x0, _mac_history_window
    cbnz x0, Lhistory_present
    CLASS NSPanel
    MSG alloc
    RECT 0, 0, 850, 480
    mov x2, #11
    mov x3, #2
    mov x4, #0
    MSG initWindow
    STORE x0, _mac_history_window
    mov x2, #0
    MSG setReleasedWhenClosed
    STR history_title
    mov x2, x0
    LOAD x0, _mac_history_window
    MSG setTitle
    LOAD x0, _mac_history_window
    MSG contentView
    mov x19, x0
    CLASS NSSearchField
    MSG alloc
    RECT 12, 440, 826, 28
    MSG initFrame
    STORE x0, _mac_search
    mov x20, x0
    mov x2, #10                      // width + flexible bottom margin (stay at top)
    MSG setAutoresizing
    STR search_hint
    mov x2, x0
    mov x0, x20
    MSG setPlaceholder
    mov x0, x20
    LOAD x2, _mac_delegate
    MSG setTarget
    mov x0, x20
    SELECT x2, refreshHistory
    MSG setAction
    mov x0, x19
    mov x2, x20
    MSG addSubview
    mov x0, x20
    MSG release
    CLASS NSScrollView
    MSG alloc
    RECT 12, 12, 826, 416
    MSG initFrame
    mov x20, x0
    mov x2, #18
    MSG setAutoresizing
    mov x0, x20
    mov x2, #1
    MSG setVerticalScroller
    CLASS NSTableView
    MSG new
    STORE x0, _mac_table
    mov x21, x0
    LOAD x2, _mac_delegate
    MSG setDataSource
    mov x0, x21
    LOAD x2, _mac_delegate
    MSG setDelegate
    mov x0, x21
    LOAD x2, _mac_delegate
    MSG setTarget
    mov x0, x21
    SELECT x2, openHistory
    MSG setDoubleAction
    STR key_title
    NUM d0, 200
    bl _mac_history_column
    STR key_url
    NUM d0, 390
    bl _mac_history_column
    STR key_date
    NUM d0, 200
    bl _mac_history_column
    mov x0, x20
    mov x2, x21
    MSG setDocumentView
    mov x0, x21
    MSG release
    mov x0, x19
    mov x2, x20
    MSG addSubview
    mov x0, x20
    MSG release
    LOAD x0, _mac_history_window
    MSG center
Lhistory_present:
    bl _mac_refresh_history
    LOAD x0, _mac_history_window
    mov x2, #0
    MSG makeKey
    LEAVE

_mac_history_column:
    ENTER
    mov x19, x0
    str d0, [sp, #144]
    CLASS NSTableColumn
    MSG alloc
    mov x2, x19
    MSG initIdentifier
    mov x20, x0
    mov x0, x19
    MSG capitalized
    mov x2, x0
    mov x0, x20
    MSG setTitle
    mov x0, x20
    ldr d0, [sp, #144]
    MSG setWidth
    LOAD x0, _mac_table
    mov x2, x20
    MSG addTableColumn
    mov x0, x20
    MSG release
    LEAVE

.globl _mac_refresh_history
_mac_refresh_history:
    ENTER
    CLASS NSMutableArray
    MSG new
    mov x19, x0
    LOAD x0, _mac_search
    MSG stringValue
    MSG UTF8String
    mov x1, x0
    LOAD x0, _mac_db
    ADDR x2, _mac_history_row
    mov x3, x19
    bl _history_search
    mov w20, w0
    LOAD x0, _mac_rows
    MSG release
    STORE x19, _mac_rows
    LOAD x0, _mac_table
    MSG reloadData
    cbz w20, Lrefresh_done
    STR history_error
    mov x2, x0
    LOAD x0, _mac_window
    MSG setTitle
Lrefresh_done:
    LEAVE

// history_search callback(context, url, title, date, id).
_mac_history_row:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    CLASS NSMutableDictionary
    MSG new
    mov x23, x0
    mov x0, x20
    bl _mac_string
    mov x24, x0
    STR key_url
    mov x3, x0
    mov x2, x24
    mov x0, x23
    MSG setObjectKey
    mov x0, x21
    bl _mac_string
    mov x24, x0
    STR key_title
    mov x3, x0
    mov x2, x24
    mov x0, x23
    MSG setObjectKey
    mov x0, x22
    bl _mac_string
    mov x24, x0
    STR key_date
    mov x3, x0
    mov x2, x24
    mov x0, x23
    MSG setObjectKey
    mov x0, x19
    mov x2, x23
    MSG addObject
    mov x0, x23
    MSG release
    LEAVE

.globl _mac_history_count
_mac_history_count:
    ENTER
    LOAD x0, _mac_rows
    MSG count
    LEAVE

// tableView:objectValueForTableColumn:row: -> borrowed NSString, retained by snapshot rows.
.globl _mac_history_value
_mac_history_value:
    ENTER
    mov x19, x3
    mov x20, x4
    LOAD x0, _mac_rows
    MSG count
    cmp x20, x0
    b.hs Lvalue_none
    LOAD x0, _mac_rows
    mov x2, x20
    MSG objectAtIndex
    mov x20, x0
    mov x0, x19
    MSG identifier
    mov x2, x0
    mov x0, x20
    MSG objectForKey
    LEAVE
Lvalue_none:
    mov x0, #0
    LEAVE

.globl _mac_open_history
_mac_open_history:
    ENTER
    LOAD x0, _mac_table
    MSG clickedRow
    tbnz x0, #63, Lopen_done
    mov x19, x0
    LOAD x0, _mac_rows
    MSG count
    cmp x19, x0
    b.hs Lopen_done
    LOAD x0, _mac_rows
    mov x2, x19
    MSG objectAtIndex
    mov x20, x0
    STR key_url
    mov x2, x0
    mov x0, x20
    MSG objectForKey
    mov x2, x0
    LOAD x0, _mac_address
    MSG setStringValue
    bl _mac_navigate
    LOAD x0, _mac_window
    mov x2, #0
    MSG makeKey
Lopen_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
history_title: .asciz "History — double-click to open"
search_hint: .asciz "Search history"
key_title: .asciz "title"
key_url: .asciz "url"
key_date: .asciz "date"
history_error: .asciz "History could not be read — Oogabooga"
