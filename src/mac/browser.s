// Native macOS browser shell. Handwritten ARM64; no compiled Objective-C bridge.
// AppKit/WebKit objects are managed explicitly. Class selectors live in runtime.s.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _browser_main
_browser_main:
    ENTER
    STORE x0, _mac_argc
    STORE x1, _mac_argv
    bl _objc_autoreleasePoolPush
    mov x19, x0
    bl _mac_register_class
    MSG new
    STORE x0, _mac_delegate
    CLASS NSApplication
    MSG sharedApplication
    STORE x0, _mac_app
    mov x2, #0                       // NSApplicationActivationPolicyRegular
    MSG setActivationPolicy
    LOAD x0, _mac_app
    LOAD x2, _mac_delegate
    MSG setDelegate
    LOAD x0, _mac_app
    MSG run
    LOAD x0, _mac_app
    mov x2, #0
    MSG setDelegate
    LOAD x0, _mac_window
    MSG release
    LOAD x0, _mac_history_window
    MSG release
    LOAD x0, _mac_popups
    MSG release
    LOAD x0, _mac_rows
    MSG release
    LOAD x0, _mac_delegate
    MSG release
    mov x0, x19
    bl _objc_autoreleasePoolPop
    mov w0, #0
    LEAVE

// applicationDidFinishLaunching:
.globl _mac_launch
_mac_launch:
    ENTER
    ADDR x0, profile_environment
    bl _getenv
    cbz x0, Llaunch_default_profile
    bl _mac_string
    mov x19, x0
    b Llaunch_profile_ready
Llaunch_default_profile:
    bl _NSHomeDirectory
    mov x19, x0
    STR profile_path
    mov x2, x0
    mov x0, x19
    MSG appendPath
    mov x19, x0
Llaunch_profile_ready:
    CLASS NSFileManager
    MSG defaultManager
    mov x2, x19
    mov x3, #1
    mov x4, #0
    add x5, sp, #144
    str xzr, [sp, #144]
    MSG createDirectory
    cbz w0, Llaunch_error
    mov x0, x19
    MSG fileSystemRepresentation
    mov w1, #448                     // profile directory mode 0700
    bl _chmod
    cbnz w0, Llaunch_error
    STR history_file
    mov x2, x0
    mov x0, x19
    MSG appendPath
    MSG fileSystemRepresentation
    ADDR x1, _mac_db
    bl _history_open
    cbnz w0, Llaunch_error
    CLASS NSMutableSet
    MSG new
    STORE x0, _mac_popups
    CLASS NSWindow
    MSG alloc
    RECT 0, 0, 1160, 780
    mov x2, #15
    mov x3, #2
    mov x4, #0
    MSG initWindow
    STORE x0, _mac_window
    mov x19, x0
    mov x2, #0
    MSG setReleasedWhenClosed
    STR app_title
    mov x2, x0
    mov x0, x19
    MSG setTitle
    mov x0, x19
    NUM d0, 640
    NUM d1, 400
    MSG setContentMinSize
    mov x0, x19
    MSG center
    mov x0, x19
    MSG contentView
    STORE x0, _mac_root
    STR back_text
    SELECT x1, goBack
    RECT 12, 738, 32, 30
    bl _mac_button
    STORE x0, _mac_back
    STR forward_text
    SELECT x1, goForward
    RECT 50, 738, 32, 30
    bl _mac_button
    STORE x0, _mac_forward
    STR reload_text
    SELECT x1, reload
    RECT 88, 738, 32, 30
    bl _mac_button
    CLASS NSTextField
    MSG alloc
    RECT 132, 738, 916, 30
    MSG initFrame
    STORE x0, _mac_address
    mov x19, x0
    STR address_hint
    mov x2, x0
    mov x0, x19
    MSG setPlaceholder
    mov x0, x19
    LOAD x2, _mac_delegate
    MSG setTarget
    mov x0, x19
    SELECT x2, navigate
    MSG setAction
    mov x0, x19
    mov x2, #10                      // NSViewWidthSizable | NSViewMinYMargin
    MSG setAutoresizing
    mov x0, x19
    bl _mac_add_root
    mov x0, x19
    MSG release
    STR history_text
    SELECT x1, showHistory
    RECT 1060, 738, 88, 30
    bl _mac_button
    mov x2, #9                       // NSViewMinXMargin | NSViewMinYMargin
    MSG setAutoresizing
    CLASS WKWebViewConfiguration
    MSG new
    mov x19, x0
    CLASS WKWebsiteDataStore
    MSG defaultDataStore
    mov x2, x0
    mov x0, x19
    MSG setWebsiteDataStore
    CLASS WKWebView
    MSG alloc
    RECT 0, 26, 1160, 700
    mov x2, x19
    MSG initWeb
    STORE x0, _mac_web
    mov x20, x0
    mov x0, x19
    MSG release
    mov x0, x20
    bl _mac_setup_web
    mov x0, x20
    mov x2, #18                      // width + height sizable
    MSG setAutoresizing
    mov x0, x20
    bl _mac_add_root
    mov x0, x20
    MSG release                      // content view now owns the web view
    CLASS NSTextField
    mov x19, x0
    STR ready_text
    mov x2, x0
    mov x0, x19
    MSG labelWithString
    STORE x0, _mac_status
    mov x19, x0
    RECT 12, 5, 1136, 16
    MSG setFrame
    mov x0, x19
    mov x2, #2
    MSG setAutoresizing
    CLASS NSFont
    NUM d0, 11
    MSG systemFont
    mov x2, x0
    mov x0, x19
    MSG setFont
    CLASS NSColor
    MSG secondaryColor
    mov x2, x0
    mov x0, x19
    MSG setTextColor
    mov x0, x19
    bl _mac_add_root
    bl _mac_menus
    LOAD x0, _mac_window
    mov x2, #0
    MSG makeKey
    LOAD x0, _mac_app
    mov x2, #1
    MSG activate
    LOAD x0, _mac_argc
    cmp x0, #1
    b.le Llaunch_home
    LOAD x9, _mac_argv
    ldr x0, [x9, #8]
    bl _mac_string
    b Llaunch_initial
Llaunch_home:
    STR home_url
Llaunch_initial:
    mov x2, x0
    LOAD x0, _mac_address
    MSG setStringValue
    bl _mac_navigate
    LEAVE
Llaunch_error:
    STR storage_title
    mov x19, x0
    STR storage_error
    mov x20, x0
    STR ok_text
    mov x2, x0
    mov x0, x19
    mov x1, x20
    mov x3, #0
    bl _mac_alert
    MSG runModal
    mov w0, #1
    bl _exit
    LEAVE

// Create an autoreleased native button, retained by the content view.
// x0 NSString title, x1 action SEL; d0-d3 frame.
_mac_button:
    ENTER
    mov x19, x0
    mov x20, x1
    stp d0, d1, [sp, #144]
    stp d2, d3, [sp, #160]
    CLASS NSButton
    mov x2, x19
    LOAD x3, _mac_delegate
    mov x4, x20
    MSG button
    mov x19, x0
    ldp d0, d1, [sp, #144]
    ldp d2, d3, [sp, #160]
    MSG setFrame
    mov x0, x19
    mov x2, #11                      // NSBezelStyleToolbar
    MSG setBezelStyle
    mov x0, x19
    mov x2, #8                       // follow top edge
    MSG setAutoresizing
    mov x0, x19
    bl _mac_add_root
    mov x0, x19
    LEAVE
_mac_add_root:
    ENTER
    mov x2, x0
    LOAD x0, _mac_root
    MSG addSubview
    LEAVE

.globl _mac_focus
_mac_focus:
    ENTER
    LOAD x0, _mac_window
    LOAD x2, _mac_address
    MSG makeFirstResponder
    LOAD x0, _mac_address
    mov x2, #0
    MSG selectText
    LEAVE
.globl _mac_navigate
_mac_navigate:
    ENTER
    LOAD x0, _mac_address
    MSG stringValue
    bl _mac_destination
    cbz x0, Lnavigate_invalid
    mov x19, x0
    CLASS NSURLRequest
    mov x2, x19
    MSG requestWithURL
    mov x2, x0
    LOAD x0, _mac_web
    MSG loadRequest
    LEAVE
Lnavigate_invalid:
    STR invalid_text
    bl _mac_status_text
    LEAVE
.globl _mac_back_clicked
_mac_back_clicked:
    ENTER
    LOAD x0, _mac_web
    MSG goBackNative
    LEAVE
.globl _mac_forward_clicked
_mac_forward_clicked:
    ENTER
    LOAD x0, _mac_web
    MSG goForwardNative
    LEAVE
.globl _mac_reload
_mac_reload:
    ENTER
    LOAD x0, _mac_web
    MSG isLoading
    cbz w0, Lreload_load
    LOAD x0, _mac_web
    MSG stopLoading
    LEAVE
Lreload_load:
    LOAD x0, _mac_web
    MSG reloadNative
    LEAVE

_mac_status_text:
    ENTER
    mov x2, x0
    LOAD x0, _mac_status
    MSG setStringValue
    LEAVE

// Configure delegates and observe document title changes without JavaScript injection.
.globl _mac_setup_web
_mac_setup_web:
    ENTER
    mov x19, x0
    LOAD x2, _mac_delegate
    MSG setNavigationDelegate
    mov x0, x19
    LOAD x2, _mac_delegate
    MSG setUIDelegate
    mov x0, x19
    mov x2, #1
    MSG setGestures
    STR title_key
    mov x3, x0
    mov x0, x19
    LOAD x2, _mac_delegate
    mov x4, #0
    mov x5, #0
    MSG addObserver
    LEAVE

// Title-only changes must not replace text the person is typing in the address bar.
_mac_sync_title:
    ENTER
    mov x19, x0
    MSG title
    mov x20, x0
    MSG length
    cbz x0, Lsync_default_title
    STR title_suffix
    mov x2, x0
    mov x0, x20
    MSG append
    b Lsync_title
Lsync_default_title:
    STR app_title
Lsync_title:
    mov x20, x0
    mov x0, x19
    MSG window
    mov x2, x20
    MSG setTitle
    LEAVE

// Navigation events synchronize the address bar and back/forward controls as well.
.globl _mac_sync
_mac_sync:
    ENTER
    mov x19, x0
    bl _mac_sync_title
    LOAD x9, _mac_web
    cmp x19, x9
    b.ne Lsync_done
    mov x0, x19
    MSG URL
    MSG absoluteString
    cbz x0, Lsync_controls
    mov x2, x0
    LOAD x0, _mac_address
    MSG setStringValue
Lsync_controls:
    mov x0, x19
    MSG canGoBack
    mov x2, x0
    LOAD x0, _mac_back
    MSG setEnabled
    mov x0, x19
    MSG canGoForward
    mov x2, x0
    LOAD x0, _mac_forward
    MSG setEnabled
Lsync_done:
    LEAVE

.globl _mac_load_started
_mac_load_started:
    ENTER
    mov x19, x2
    mov x0, x19
    ADDR x1, _mac_visit_key
    mov x2, #0
    mov x3, #1
    bl _objc_setAssociatedObject
    LOAD x9, _mac_web
    cmp x19, x9
    b.ne Lstart_done
    STR loading_text
    bl _mac_status_text
Lstart_done:
    LEAVE
.globl _mac_load_committed
_mac_load_committed:
    mov x0, x2
    b _mac_sync
.globl _mac_load_finished
_mac_load_finished:
    ENTER
    mov x19, x2
    mov x0, x19
    bl _mac_sync
    mov x0, x19
    MSG URL
    mov x20, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lfinish_done
    mov x0, x20
    MSG absoluteString
    MSG UTF8String
    mov x21, x0
    mov x0, x19
    MSG title
    MSG UTF8String
    mov x2, x0
    cbnz x2, Lfinish_insert
    ADDR x2, empty_text
Lfinish_insert:
    LOAD x0, _mac_db
    mov x1, x21
    bl _history_add
    cbnz w0, Lfinish_error
    LOAD x0, _mac_db
    bl _sqlite3_last_insert_rowid
    mov x20, x0
    CLASS NSNumber
    mov x2, x20
    MSG numberLongLong
    mov x2, x0
    mov x0, x19
    ADDR x1, _mac_visit_key
    mov x3, #1
    bl _objc_setAssociatedObject
    STR ready_text
    b Lfinish_status
Lfinish_error:
    STR history_error
Lfinish_status:
    LOAD x9, _mac_web
    cmp x19, x9
    b.ne Lfinish_done
    bl _mac_status_text
Lfinish_done:
    LEAVE

// KVO IMP: self, _cmd, keyPath, object, change, context.
.globl _mac_title_changed
_mac_title_changed:
    ENTER
    mov x19, x3
    mov x0, x19
    bl _mac_sync_title
    mov x0, x19
    ADDR x1, _mac_visit_key
    bl _objc_getAssociatedObject
    cbz x0, Ltitle_done
    MSG longLongValue
    mov x20, x0
    mov x0, x19
    MSG title
    cbz x0, Ltitle_done
    MSG UTF8String
    mov x2, x0
    LOAD x0, _mac_db
    mov x1, x20
    bl _history_update_title
Ltitle_done:
    LEAVE

.globl _mac_load_failed
_mac_load_failed:
    ENTER
    LOAD x9, _mac_web
    cmp x2, x9
    b.ne Lfailure_done
    mov x19, x4
    mov x0, x19
    MSG code
    cmn x0, #999                     // NSURLErrorCancelled
    b.eq Lfailure_done
    mov x0, x19
    MSG localizedDescription
    bl _mac_status_text
Lfailure_done:
    LEAVE
.globl _mac_process_stopped
_mac_process_stopped:
    ENTER
    LOAD x9, _mac_web
    cmp x2, x9
    b.ne Lprocess_done
    STR process_error
    bl _mac_status_text
Lprocess_done:
    LEAVE

// WKNavigationDelegate completion blocks are invoked through their public block ABI.
.globl _mac_policy
_mac_policy:
    ENTER
    mov x19, x4
    mov x0, x3
    MSG request
    MSG URL
    MSG scheme
    MSG lowercase
    mov x20, x0
    bl _mac_allowed_scheme
    cbnz w0, Lpolicy_allow
    STR about_text
    mov x2, x0
    mov x0, x20
    MSG equal
    cbnz w0, Lpolicy_allow
    mov x1, #0                       // WKNavigationActionPolicyCancel
    b Lpolicy_complete
Lpolicy_allow:
    mov x1, #1
Lpolicy_complete:
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    LEAVE

.globl _mac_popup_create
_mac_popup_create:
    ENTER
    mov x19, x3                      // preserve WebKit's supplied configuration
    CLASS WKWebView
    MSG alloc
    RECT 0, 0, 700, 720
    mov x2, x19
    MSG initWeb
    mov x19, x0
    bl _mac_setup_web
    CLASS NSWindow
    MSG alloc
    RECT 0, 0, 700, 720
    mov x2, #11
    mov x3, #2
    mov x4, #0
    MSG initWindow
    mov x20, x0
    mov x2, #0
    MSG setReleasedWhenClosed
    STR popup_title
    mov x2, x0
    mov x0, x20
    MSG setTitle
    mov x0, x20
    mov x2, x19
    MSG setContentView
    LOAD x0, _mac_popups
    mov x2, x20
    MSG addObject
    CLASS NSNotificationCenter
    MSG defaultCenter
    mov x21, x0
    LOAD x2, _mac_delegate
    SELECT x3, popupClosed
    adrp x9, _NSWindowWillCloseNotification@GOTPAGE
    ldr x9, [x9, _NSWindowWillCloseNotification@GOTPAGEOFF]
    ldr x4, [x9]
    mov x5, x20
    MSG observeNotification
    mov x0, x20
    MSG center
    mov x0, x20
    mov x2, #0
    MSG makeKey
    mov x0, x20
    MSG release                      // set retains window until its close notification
    mov x0, x19
    MSG release                      // window retains web view; WebKit receives +0
    mov x0, x19
    LEAVE
.globl _mac_popup_closed
_mac_popup_closed:
    ENTER
    mov x0, x2
    MSG object
    mov x19, x0
    MSG contentView
    mov x20, x0
    STR title_key
    mov x3, x0
    mov x0, x20
    LOAD x2, _mac_delegate
    MSG removeObserver
    CLASS NSNotificationCenter
    MSG defaultCenter
    LOAD x2, _mac_delegate
    adrp x9, _NSWindowWillCloseNotification@GOTPAGE
    ldr x9, [x9, _NSWindowWillCloseNotification@GOTPAGEOFF]
    ldr x3, [x9]
    mov x4, x19
    MSG removeNotification
    // Delay final window release until AppKit finishes dispatching the close event.
    mov x0, x19
    MSG retain
    MSG autorelease
    LOAD x0, _mac_popups
    mov x2, x19
    MSG removeObject
    LEAVE
.globl _mac_web_close
_mac_web_close:
    ENTER
    LOAD x9, _mac_web
    cmp x2, x9
    b.eq Lclose_done
    mov x0, x2
    MSG window
    MSG close
Lclose_done:
    LEAVE

.globl _mac_should_quit
_mac_should_quit:
    mov w0, #1
    ret
.globl _mac_terminate
_mac_terminate:
    ENTER
    LOAD x0, _mac_db
    bl _sqlite3_close
    STORE xzr, _mac_db
    LEAVE

.section __TEXT,__cstring,cstring_literals
app_title: .asciz "Oogabooga"
profile_environment: .asciz "OOGABOOGA_PROFILE"
profile_path: .asciz "Library/Application Support/Oogabooga"
history_file: .asciz "history.sqlite3"
storage_title: .asciz "Could not open browsing history"
storage_error: .asciz "Check that your Application Support folder is writable."
ok_text: .asciz "OK"
back_text: .asciz "←"
forward_text: .asciz "→"
reload_text: .asciz "↻"
history_text: .asciz "History"
address_hint: .asciz "Search or enter address"
ready_text: .asciz "Ready"
loading_text: .asciz "Loading…"
invalid_text: .asciz "Enter an HTTP(S) address or search terms."
history_error: .asciz "Page loaded; history could not be saved."
process_error: .asciz "Page process stopped. Press ⌘R to reload."
home_url: .asciz "https://example.com"
title_key: .asciz "title"
title_suffix: .asciz " — Oogabooga"
popup_title: .asciz "Oogabooga — New Window"
about_text: .asciz "about"
empty_text: .asciz ""
.section __DATA,__bss
.p2align 3
.globl _mac_app, _mac_delegate, _mac_window, _mac_web, _mac_address, _mac_db
.globl _mac_history_window, _mac_search, _mac_table, _mac_rows, _mac_popups
_mac_app: .space 8
_mac_delegate: .space 8
_mac_window: .space 8
_mac_web: .space 8
_mac_address: .space 8
_mac_db: .space 8
_mac_history_window: .space 8
_mac_search: .space 8
_mac_table: .space 8
_mac_rows: .space 8
_mac_popups: .space 8
_mac_root: .space 8
_mac_status: .space 8
_mac_back: .space 8
_mac_forward: .space 8
_mac_argc: .space 8
_mac_argv: .space 8
_mac_visit_key: .space 8
