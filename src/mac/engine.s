// Experimental assembly HTML engine adapter. NSURLSession handles HTTP/TLS and
// an isolated ephemeral cookie jar. No WebKit parsing, layout, or JS is used here.
// All delegate callbacks execute on NSOperationQueue.mainQueue.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
.globl _mac_engine_toggle
_mac_engine_toggle:
    ENTER
    mov x19, x2                      // optional menu item
    LOAD x0, _mac_engine_enabled
    eor x0, x0, #1
    STORE x0, _mac_engine_enabled
    mov x20, x0
    cbz x19, Lengine_menu_done
    mov x2, x20
    mov x0, x19
    MSG setState
Lengine_menu_done:
    LOAD x0, _mac_web
    MSG stopLoading
    bl _mac_engine_cancel
    LOAD x0, engine_scroll
    cbnz x0, Lengine_view_exists
    bl _mac_engine_create
Lengine_view_exists:
    LOAD x0, _mac_web
    mov x2, x20
    MSG setHidden
    LOAD x0, engine_scroll
    eor x2, x20, #1
    MSG setHidden
    bl _mac_navigate
    LEAVE

_mac_engine_create:
    ENTER
    CLASS NSScrollView
    MSG alloc
    RECT 0, 26, 1160, 700
    MSG initFrame
    STORE x0, engine_scroll
    mov x19, x0
    mov x2, #18
    MSG setAutoresizing
    mov x0, x19
    mov x2, #1
    MSG setVerticalScroller
    mov x0, x19
    mov x2, #1
    MSG setHorizontalScroller
    CLASS NSTextView
    MSG alloc
    RECT 0, 0, 900, 700
    MSG initFrame
    STORE x0, engine_text
    mov x20, x0
    mov x2, #0
    MSG setEditable
    mov x0, x20
    mov x2, #1
    MSG setSelectable
    mov x0, x20
    mov x2, #1
    MSG setRichText
    mov x0, x20
    mov x2, #0
    MSG setAutomaticLinks
    mov x0, x20
    mov x2, #0
    MSG setImportsGraphics
    mov x0, x20
    mov x2, #1
    MSG setHorizontallyResizable
    mov x0, x20
    mov x2, #1
    MSG setVerticallyResizable
    mov x0, x20
    NUM d0, 900
    NUM d1, 0
    MSG setMinSize
    mov x0, x20
    NUM d0, 10000
    NUM d1, 1048576
    MSG setMaxSize
    mov x0, x20
    NUM d0, 20
    NUM d1, 20
    MSG setTextInset
    mov x0, x20
    LOAD x2, _mac_delegate
    MSG setDelegate
    CLASS NSMutableDictionary
    MSG new
    mov x21, x0
    mov x0, x20
    mov x2, x21
    MSG setLinkTextAttributes
    mov x0, x21
    MSG release
    mov x0, x19
    mov x2, x20
    MSG setDocumentView
    mov x0, x20
    MSG release                      // scroll view owns document view
    LOAD x0, _mac_window
    MSG contentView
    mov x2, x19
    MSG addSubview
    mov x0, x19
    MSG release                      // content view owns scroll view
    CLASS NSMutableArray
    MSG new
    STORE x0, engine_history
    mov x9, #-1
    STORE x9, engine_index
    CLASS NSURLSessionConfiguration
    MSG ephemeralConfiguration
    mov x19, x0
    CLASS NSOperationQueue
    MSG mainQueue
    mov x20, x0
    CLASS NSURLSession
    mov x2, x19
    LOAD x3, _mac_delegate
    mov x4, x20
    MSG sessionWithConfiguration
    MSG retain
    STORE x0, engine_session
    LEAVE

// Called by the ordinary address bar/history commands while this engine is active.
.globl _mac_engine_navigate
_mac_engine_navigate:
    ENTER
    LOAD x0, _mac_address
    MSG stringValue
    bl _mac_destination
    cbz x0, Lengine_invalid
    bl _mac_engine_open_url
    LEAVE
Lengine_invalid:
    STR invalid_text
    bl _mac_status_text
    LEAVE
.globl _mac_engine_open_url
_mac_engine_open_url:
    ENTER
    mov x19, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lengine_open_done
    STORE xzr, engine_traversal
    mov x0, x19
    bl _mac_engine_request
Lengine_open_done:
    LEAVE

// Start/cancel use task identity, so stale callbacks cannot replace a newer page.
_mac_engine_request:
    ENTER
    mov x19, x0
    bl _mac_engine_cancel
    LOAD x0, engine_charset
    MSG release
    STORE xzr, engine_charset
    LOAD x0, engine_pending_url
    MSG release
    mov x0, x19
    MSG retain
    STORE x0, engine_pending_url
    MSG absoluteString
    mov x2, x0
    LOAD x0, _mac_address
    MSG setStringValue
    CLASS NSMutableData
    MSG new
    STORE x0, engine_data
    CLASS NSURLRequest
    mov x2, x19
    MSG requestWithURL
    mov x2, x0
    LOAD x0, engine_session
    MSG dataTask
    MSG retain
    STORE x0, engine_task
    MSG resume
    STR loading_text
    bl _mac_status_text
    LEAVE

.globl _mac_engine_cancel
_mac_engine_cancel:
    ENTER
    LOAD x19, engine_task
    STORE xzr, engine_task
    mov x0, x19
    MSG cancel
    mov x0, x19
    MSG release
    LOAD x0, engine_data
    MSG release
    STORE xzr, engine_data
    LEAVE

.globl _mac_engine_back
_mac_engine_back:
    ENTER
    LOAD x19, engine_index
    cmp x19, #0
    b.le Lengine_back_done
    sub x19, x19, #1
    b Lengine_traverse
.globl _mac_engine_forward
_mac_engine_forward:
    ENTER
    LOAD x19, engine_index
    add x19, x19, #1
    LOAD x0, engine_history
    MSG count
    cmp x19, x0
    b.hs Lengine_back_done
Lengine_traverse:
    mov x9, #1
    STORE x9, engine_traversal
    STORE x19, engine_pending_index
    LOAD x0, engine_history
    mov x2, x19
    MSG objectAtIndex
    bl _mac_engine_request
Lengine_back_done:
    LEAVE

.globl _mac_engine_reload
_mac_engine_reload:
    ENTER
    LOAD x0, engine_task
    cbz x0, Lengine_reload_page
    bl _mac_engine_cancel
    STR stopped_text
    bl _mac_status_text
    LEAVE
Lengine_reload_page:
    LOAD x0, engine_url
    cbz x0, Lengine_reload_done
    mov x9, #1
    STORE x9, engine_traversal
    LOAD x9, engine_index
    STORE x9, engine_pending_index
    bl _mac_engine_request
Lengine_reload_done:
    LEAVE

// URLSession:dataTask:didReceiveResponse:completionHandler:
.globl _mac_engine_response
_mac_engine_response:
    ENTER
    mov x19, x5
    mov x20, x4
    LOAD x9, engine_task
    cmp x3, x9
    b.ne Lresponse_cancel
    mov x0, x20
    MSG expectedLength
    mov x9, #ENGINE_MAX_INPUT
    cmp x0, #0
    b.lt Lresponse_mime
    cmp x0, x9
    b.hi Lresponse_large
Lresponse_mime:
    mov x0, x20
    MSG statusCode
    cmp x0, #200
    b.lt Lresponse_http
    cmp x0, #300
    b.hs Lresponse_http
    mov x0, x20
    MSG MIMEType
    MSG lowercase
    mov x21, x0
    STR html_mime
    mov x2, x0
    mov x0, x21
    MSG equal
    cbnz w0, Lresponse_accept
    STR xhtml_mime
    mov x2, x0
    mov x0, x21
    MSG equal
    cbz w0, Lresponse_type
Lresponse_accept:
    LOAD x0, engine_charset
    MSG release
    mov x0, x20
    MSG textEncodingName
    MSG retain
    STORE x0, engine_charset
    LOAD x0, engine_pending_url
    MSG release
    mov x0, x20
    MSG URL
    MSG retain
    STORE x0, engine_pending_url
    mov x1, #1                       // NSURLSessionResponseAllow
    b Lresponse_complete
Lresponse_large:
    STR large_text
    b Lresponse_error
Lresponse_http:
    STR http_error
    b Lresponse_error
Lresponse_type:
    STR type_error
Lresponse_error:
    bl _mac_status_text
    bl _mac_engine_cancel
Lresponse_cancel:
    mov x1, #0
Lresponse_complete:
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    LEAVE

// URLSession:dataTask:didReceiveData:
.globl _mac_engine_data
_mac_engine_data:
    ENTER
    LOAD x9, engine_task
    cmp x3, x9
    b.ne Ldata_done
    mov x19, x4
    mov x0, x19
    MSG length
    mov x20, x0
    LOAD x0, engine_data
    MSG length
    add x0, x0, x20
    mov x9, #ENGINE_MAX_INPUT
    cmp x0, x9
    b.hi Ldata_large
    LOAD x0, engine_data
    mov x2, x19
    MSG appendData
    b Ldata_done
Ldata_large:
    STR large_text
    bl _mac_status_text
    bl _mac_engine_cancel
Ldata_done:
    LEAVE

// URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:
.globl _mac_engine_redirect
_mac_engine_redirect:
    ENTER
    mov x19, x6
    mov x20, x5
    LOAD x9, engine_task
    cmp x3, x9
    b.ne Lredirect_cancel
    mov x0, x20
    MSG URL
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lredirect_cancel
    mov x1, x20
    b Lredirect_complete
Lredirect_cancel:
    mov x1, #0
Lredirect_complete:
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    LEAVE

// URLSession:task:didCompleteWithError:
.globl _mac_engine_complete
_mac_engine_complete:
    ENTER
    LOAD x9, engine_task
    cmp x3, x9
    b.ne Lcomplete_done
    cbz x4, Lcomplete_parse
    mov x0, x4
    MSG localizedDescription
    bl _mac_status_text
    b Lcomplete_cleanup
Lcomplete_parse:
    LOAD x0, engine_data
    LOAD x1, engine_charset
    bl _mac_engine_decode
    cbz x0, Lcomplete_encoding
    mov x19, x0                      // owned normalized UTF-8 data
    MSG length
    mov x21, x0
    mov x9, #ENGINE_MAX_INPUT
    cmp x0, x9
    b.hi Lcomplete_decoded_large
    mov x0, x19
    MSG bytes
    mov x1, x21
    bl _engine_parse
    mov x21, x0
    mov x0, x19
    MSG release
    mov x0, x21
    cbz x0, Lcomplete_limit
    mov x19, x0
    LOAD x1, engine_pending_url
    bl _mac_engine_display
    cbz w0, Lcomplete_render_failed
    LOAD x0, engine_document
    bl _engine_document_free
    STORE x19, engine_document
    LOAD x0, engine_url
    MSG release
    LOAD x0, engine_pending_url
    MSG retain
    STORE x0, engine_url
    bl _mac_engine_record
    cbnz w0, Lcomplete_history_error
    STR ready_text
    bl _mac_status_text
    b Lcomplete_cleanup
Lcomplete_history_error:
    STR history_error
    bl _mac_status_text
    b Lcomplete_cleanup
Lcomplete_render_failed:
    mov x0, x19
    bl _engine_document_free
Lcomplete_limit:
    STR parse_error
    bl _mac_status_text
    b Lcomplete_cleanup
Lcomplete_decoded_large:
    mov x0, x19
    MSG release
    STR large_text
    bl _mac_status_text
    b Lcomplete_cleanup
Lcomplete_encoding:
    STR encoding_error
    bl _mac_status_text
Lcomplete_cleanup:
    bl _mac_engine_cancel
Lcomplete_done:
    LEAVE

// Record final URL/title and maintain independent engine back/forward navigation.
_mac_engine_record:
    ENTER
    LOAD x0, engine_traversal
    cbnz x0, Lrecord_traverse
    LOAD x19, engine_index
    add x19, x19, #1
Lrecord_trim_forward:
    LOAD x0, engine_history
    MSG count
    cmp x0, x19
    b.ls Lrecord_append
    LOAD x0, engine_history
    MSG removeLastObject
    b Lrecord_trim_forward
Lrecord_append:
    LOAD x0, engine_history
    LOAD x2, engine_url
    MSG addObject
    STORE x19, engine_index
    b Lrecord_history
Lrecord_traverse:
    LOAD x9, engine_pending_index
    STORE x9, engine_index
Lrecord_history:
    LOAD x0, engine_url
    MSG absoluteString
    mov x19, x0
    MSG UTF8String
    mov x20, x0
    LOAD x9, engine_document
    ldr x2, [x9, #32]
    LOAD x0, _mac_db
    mov x1, x20
    bl _history_add
    mov w21, w0
    LOAD x0, _mac_address
    mov x2, x19
    MSG setStringValue
    LOAD x0, engine_document
    ldr x0, [x0, #32]
    bl _mac_string
    mov x19, x0
    MSG length
    cbnz x0, Lrecord_title
    LOAD x0, engine_url
    MSG host
    mov x19, x0
Lrecord_title:
    STR title_suffix
    mov x2, x0
    mov x0, x19
    MSG append
    mov x2, x0
    LOAD x0, _mac_window
    MSG setTitle
    LOAD x0, engine_index
    cmp x0, #0
    cset w2, gt
    LOAD x0, _mac_back
    MSG setEnabled
    LOAD x0, engine_history
    MSG count
    LOAD x9, engine_index
    add x9, x9, #1
    cmp x9, x0
    cset w2, lo
    LOAD x0, _mac_forward
    MSG setEnabled
    mov w0, w21
    LEAVE

// BOOL textView:clickedOnLink:atIndex:. Never launch an external application.
.globl _mac_engine_link
_mac_engine_link:
    ENTER
    mov x0, x3
    bl _mac_engine_open_url
    mov w0, #1
    LEAVE

// Display a parsed tree using native glyph rendering and our assembly line/range layout.
// x0 document*, x1 base NSURL; returns BOOL. Does not take document ownership.
.globl _mac_engine_display
_mac_engine_display:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x1, #90
    bl _engine_layout
    cbz x0, Ldisplay_fail
    mov x21, x0
    CLASS NSString
    MSG alloc
    ldr x2, [x21]
    ldr x3, [x21, #8]
    mov x4, #4
    MSG initBytesEncoding
    cbz x0, Ldisplay_free_fail
    mov x22, x0
    CLASS NSMutableAttributedString
    MSG alloc
    mov x2, x22
    MSG initString
    mov x23, x0
    mov x0, x22
    MSG release
    mov x0, x19
    LOAD x1, engine_text
    LOAD x2, engine_scroll
    bl _mac_css_canvas
    ldr x26, [x19, #16]
    ldr x27, [x19, #24]
Ldisplay_node:
    cbz x27, Ldisplay_install
    ldr x9, [x21, #16]
    ldr x10, [x26, #16]
    ldr x11, [x26, #24]
    ldr x12, [x19, #8]
    cmp x11, x12
    b.hi Ldisplay_node_next
    ldr x2, [x9, x10, lsl #3]
    ldr x3, [x9, x11, lsl #3]
    sub x3, x3, x2
    ldr x9, [x19, #24]
    sub x9, x9, x27
    ldr x1, [x19, #72]
    add x1, x1, x9, lsl #8
    ldr x4, [x26]
    mov x0, x23
    bl _mac_css_attributes
    ldr x9, [x26]
    cmp x9, #NODE_A
    b.ne Ldisplay_node_next
Ldisplay_link:
    ldr x0, [x26, #32]
    cbz x0, Ldisplay_node_next
    bl _mac_string
    mov x22, x0
    CLASS NSURL
    mov x2, x22
    mov x3, x20
    MSG relativeURL
    MSG absoluteURL
    cbz x0, Ldisplay_node_next
    mov x24, x0
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Ldisplay_node_next
    adrp x9, _NSLinkAttributeName@GOTPAGE
    ldr x9, [x9, _NSLinkAttributeName@GOTPAGEOFF]
    ldr x22, [x9]
Ldisplay_attribute:
    ldr x9, [x21, #16]
    ldr x10, [x26, #16]
    ldr x11, [x26, #24]
    ldr x12, [x19, #8]
    cmp x11, x12
    b.hi Ldisplay_node_next
    ldr x4, [x9, x10, lsl #3]
    ldr x5, [x9, x11, lsl #3]
    sub x5, x5, x4
    cbz x5, Ldisplay_node_next
    mov x0, x23
    mov x2, x22
    mov x3, x24
    MSG addAttribute
Ldisplay_node_next:
    add x26, x26, #40
    sub x27, x27, #1
    b Ldisplay_node
Ldisplay_install:
    LOAD x0, engine_text
    MSG textStorage
    mov x2, x23
    MSG setAttributedString
    LOAD x0, engine_text
    MSG textContainer
    mov x24, x0
    NUM d0, 860
    NUM d1, 1048576
    MSG setContainerSize
    mov x0, x24
    mov x2, #0
    MSG setWidthTracksView
    LOAD x0, engine_text
    MSG layoutManager
    mov x25, x0
    mov x2, x24
    MSG ensureTextLayout
    mov x0, x25
    mov x2, x24
    MSG usedTextRect
    NUM d4, 60
    fadd d1, d3, d4
    NUM d0, 900
    LOAD x0, engine_text
    MSG setFrameSize
    LOAD x0, engine_text
    mov x2, #0
    mov x3, #0
    MSG scrollRange
    mov x0, x23
    MSG release
    mov x0, x21
    bl _engine_layout_free
    mov w0, #1
    LEAVE
Ldisplay_free_fail:
    mov x0, x21
    bl _engine_layout_free
Ldisplay_fail:
    mov w0, #0
    LEAVE

.section __TEXT,__cstring,cstring_literals
history_error: .asciz "Assembly engine: page loaded, but history could not be saved."
invalid_text: .asciz "Enter an HTTP(S) address or search terms."
loading_text: .asciz "Assembly engine (experimental): loading HTML…"
ready_text: .asciz "Assembly engine — static HTML and basic CSS; JavaScript and forms are not supported. ⌘E switches back to WebKit."
stopped_text: .asciz "Assembly engine: loading stopped."
large_text: .asciz "Assembly engine: this page exceeds the 1 MiB limit. Switch to WebKit with ⌘E."
http_error: .asciz "Assembly engine: the server did not return a successful page. Try WebKit for login pages."
type_error: .asciz "Assembly engine: only HTML pages are supported. Switch to WebKit with ⌘E."
parse_error: .asciz "Assembly engine: this page exceeds parser limits or could not be laid out."
encoding_error: .asciz "Assembly engine: the page character encoding is unsupported or invalid. Switch to WebKit with ⌘E."
html_mime: .asciz "text/html"
xhtml_mime: .asciz "application/xhtml+xml"
title_suffix: .asciz " — Assembly · Oogabooga"
.section __DATA,__bss
.p2align 3
.globl _mac_engine_enabled
_mac_engine_enabled: .space 8
engine_scroll: .space 8
engine_text: .space 8
engine_session: .space 8
engine_task: .space 8
engine_data: .space 8
engine_charset: .space 8
engine_pending_url: .space 8
engine_url: .space 8
engine_document: .space 8
engine_history: .space 8
engine_index: .space 8
engine_pending_index: .space 8
engine_traversal: .space 8
