// Objective-C runtime registration and selector metadata, handwritten application IMPs.
// Selector slots are initialized once using sel_registerName before messaging objects.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_string
_mac_string:
    ENTER
    mov x19, x0
    cbnz x19, Lstring_nonnull
    ADDR x19, empty_string
Lstring_nonnull:
    CLASS NSString
    mov x2, x19
    MSG stringUTF8
    LEAVE

.globl _mac_register_class
_mac_register_class:
    ENTER
    bl _mac_init_selectors
    CLASS NSObject
    ADDR x1, browser_class
    mov x2, #0
    bl _objc_allocateClassPair
    cbz x0, Lregister_failed
    mov x19, x0
    ADDR x20, method_table
Lmethod_next:
    ldr x9, [x20]
    cbz x9, Lmethods_done
    ldr x1, [x9]
    ldr x2, [x20, #8]
    ldr x3, [x20, #16]
    mov x0, x19
    bl _class_addMethod
    cbz w0, Lregister_failed
    add x20, x20, #24
    b Lmethod_next
Lmethods_done:
    ADDR x20, protocol_table
Lprotocol_next:
    ldr x0, [x20], #8
    cbz x0, Lprotocols_done
    bl _objc_getProtocol
    cbz x0, Lprotocol_next
    mov x1, x0
    mov x0, x19
    bl _class_addProtocol
    b Lprotocol_next
Lprotocols_done:
    mov x0, x19
    bl _objc_registerClassPair
    mov x0, x19
    LEAVE
Lregister_failed:
    bl _abort
    LEAVE

.section __DATA,__objc_imageinfo,regular,no_dead_strip
.long 0
.long 64
.section __DATA,__const
.p2align 3
method_table:
.quad _sel_launch, _mac_launch, encoding_0
.quad _sel_focus, _mac_focus, encoding_1
.quad _sel_navigate, _mac_navigate, encoding_2
.quad _sel_goBack, _mac_back_clicked, encoding_3
.quad _sel_goForward, _mac_forward_clicked, encoding_4
.quad _sel_reload, _mac_reload, encoding_5
.quad _sel_showHistory, _mac_show_history, encoding_6
.quad _sel_refreshHistory, _mac_refresh_history, encoding_7
.quad _sel_openHistory, _mac_open_history, encoding_8
.quad _sel_loadStarted, _mac_load_started, encoding_9
.quad _sel_loadCommitted, _mac_load_committed, encoding_10
.quad _sel_loadFinished, _mac_load_finished, encoding_11
.quad _sel_loadFailed, _mac_load_failed, encoding_12
.quad _sel_loadProvisionalFailed, _mac_load_failed, encoding_13
.quad _sel_processStopped, _mac_process_stopped, encoding_14
.quad _sel_policy, _mac_policy, encoding_15
.quad _sel_authenticate, _mac_authenticate, encoding_16
.quad _sel_popupCreate, _mac_popup_create, encoding_17
.quad _sel_popupClosed, _mac_popup_closed, encoding_18
.quad _sel_webClose, _mac_web_close, encoding_19
.quad _sel_jsAlert, _mac_js_alert, encoding_20
.quad _sel_jsConfirm, _mac_js_confirm, encoding_21
.quad _sel_jsPrompt, _mac_js_prompt, encoding_22
.quad _sel_historyCount, _mac_history_count, encoding_23
.quad _sel_historyValue, _mac_history_value, encoding_24
.quad _sel_shouldQuit, _mac_should_quit, encoding_25
.quad _sel_willTerminate, _mac_terminate, encoding_26
.quad _sel_observeValue, _mac_title_changed, encoding_27
.quad _sel_engineToggle, _mac_engine_toggle, engine_encoding_0
.quad _sel_engineLink, _mac_engine_link, engine_encoding_1
.quad _sel_engineSubmit, _mac_form_submit, encoding_0
.quad _sel_windowUndo, _mac_window_undo, shortcut_undo_encoding
.quad _sel_textUndo, _mac_text_undo, shortcut_undo_encoding
.quad _sel_formToggle, _mac_form_toggle, encoding_0
.quad _sel_selectToggle, _mac_select_toggle, encoding_0
.quad _sel_windowResize, _mac_engine_resize, encoding_0
.quad _sel_engineResponse, _mac_engine_response, engine_encoding_2
.quad _sel_engineData, _mac_engine_data, engine_encoding_3
.quad _sel_engineComplete, _mac_engine_complete, engine_encoding_4
.quad _sel_engineRedirect, _mac_engine_redirect, engine_encoding_5
.quad 0, 0, 0
protocol_table:
.quad protocol_0
.quad protocol_1
.quad protocol_2
.quad protocol_3
.quad protocol_4
.quad engine_protocol_0
.quad engine_protocol_1
.quad engine_protocol_2
.quad 0
.section __TEXT,__cstring,cstring_literals
browser_class: .asciz "OogaboogaBrowser"
empty_string: .asciz ""
encoding_0: .asciz "v@:@"
encoding_1: .asciz "v@:@"
encoding_2: .asciz "v@:@"
encoding_3: .asciz "v@:@"
encoding_4: .asciz "v@:@"
encoding_5: .asciz "v@:@"
encoding_6: .asciz "v@:@"
encoding_7: .asciz "v@:@"
encoding_8: .asciz "v@:@"
encoding_9: .asciz "v@:@@"
encoding_10: .asciz "v@:@@"
encoding_11: .asciz "v@:@@"
encoding_12: .asciz "v@:@@@"
encoding_13: .asciz "v@:@@@"
encoding_14: .asciz "v@:@"
encoding_15: .asciz "v@:@@@?"
encoding_16: .asciz "v@:@@@?"
encoding_17: .asciz "@@:@@@@"
encoding_18: .asciz "v@:@"
encoding_19: .asciz "v@:@"
encoding_20: .asciz "v@:@@@@?"
encoding_21: .asciz "v@:@@@@?"
encoding_22: .asciz "v@:@@@@@?"
encoding_23: .asciz "q@:@"
encoding_24: .asciz "@@:@@q"
encoding_25: .asciz "B@:@"
encoding_26: .asciz "v@:@"
encoding_27: .asciz "v@:@@@^v"
protocol_0: .asciz "NSApplicationDelegate"
protocol_1: .asciz "WKNavigationDelegate"
protocol_2: .asciz "WKUIDelegate"
protocol_3: .asciz "NSTableViewDataSource"
protocol_4: .asciz "NSTableViewDelegate"
.globl _class_NSAlert
_class_NSAlert: .asciz "NSAlert"
.globl _class_NSApplication
_class_NSApplication: .asciz "NSApplication"
.globl _class_NSArray
_class_NSArray: .asciz "NSArray"
.globl _class_NSButton
_class_NSButton: .asciz "NSButton"
.globl _class_NSCharacterSet
_class_NSCharacterSet: .asciz "NSCharacterSet"
.globl _class_NSColor
_class_NSColor: .asciz "NSColor"
.globl _class_NSFileManager
_class_NSFileManager: .asciz "NSFileManager"
.globl _class_NSFont
_class_NSFont: .asciz "NSFont"
.globl _class_NSMenu
_class_NSMenu: .asciz "NSMenu"
.globl _class_NSMenuItem
_class_NSMenuItem: .asciz "NSMenuItem"
.globl _class_NSMutableArray
_class_NSMutableArray: .asciz "NSMutableArray"
.globl _class_NSMutableDictionary
_class_NSMutableDictionary: .asciz "NSMutableDictionary"
.globl _class_NSMutableSet
_class_NSMutableSet: .asciz "NSMutableSet"
.globl _class_NSNotificationCenter
_class_NSNotificationCenter: .asciz "NSNotificationCenter"
.globl _class_NSNumber
_class_NSNumber: .asciz "NSNumber"
.globl _class_NSObject
_class_NSObject: .asciz "NSObject"
.globl _class_NSPanel
_class_NSPanel: .asciz "NSPanel"
.globl _class_NSScrollView
_class_NSScrollView: .asciz "NSScrollView"
.globl _class_NSSearchField
_class_NSSearchField: .asciz "NSSearchField"
.globl _class_NSSecureTextField
_class_NSSecureTextField: .asciz "NSSecureTextField"
.globl _class_NSString
_class_NSString: .asciz "NSString"
.globl _class_NSTableColumn
_class_NSTableColumn: .asciz "NSTableColumn"
.globl _class_NSTableView
_class_NSTableView: .asciz "NSTableView"
.globl _class_NSTextField
_class_NSTextField: .asciz "NSTextField"
.globl _class_NSURL
_class_NSURL: .asciz "NSURL"
.globl _class_NSURLComponents
_class_NSURLComponents: .asciz "NSURLComponents"
.globl _class_NSURLCredential
_class_NSURLCredential: .asciz "NSURLCredential"
.globl _class_NSURLQueryItem
_class_NSURLQueryItem: .asciz "NSURLQueryItem"
.globl _class_NSURLRequest
_class_NSURLRequest: .asciz "NSURLRequest"
.globl _class_NSView
_class_NSView: .asciz "NSView"
.globl _class_NSWindow
_class_NSWindow: .asciz "NSWindow"
.globl _class_WKWebView
_class_WKWebView: .asciz "WKWebView"
.globl _class_WKWebViewConfiguration
_class_WKWebViewConfiguration: .asciz "WKWebViewConfiguration"
.globl _class_WKWebsiteDataStore
_class_WKWebsiteDataStore: .asciz "WKWebsiteDataStore"

.section __TEXT,__cstring,cstring_literals
method_new: .asciz "new"
method_alloc: .asciz "alloc"
method_release: .asciz "release"
method_retain: .asciz "retain"
method_autorelease: .asciz "autorelease"
method_stringUTF8: .asciz "stringWithUTF8String:"
method_whitespace: .asciz "whitespaceAndNewlineCharacterSet"
method_trim: .asciz "stringByTrimmingCharactersInSet:"
method_length: .asciz "length"
method_contains: .asciz "containsString:"
method_hasPrefix: .asciz "hasPrefix:"
method_append: .asciz "stringByAppendingString:"
method_URLWithString: .asciz "URLWithString:"
method_host: .asciz "host"
method_scheme: .asciz "scheme"
method_lowercase: .asciz "lowercaseString"
method_equal: .asciz "isEqualToString:"
method_components: .asciz "componentsWithString:"
method_queryItem: .asciz "queryItemWithName:value:"
method_arrayObject: .asciz "arrayWithObject:"
method_setQueryItems: .asciz "setQueryItems:"
method_URL: .asciz "URL"
method_sharedApplication: .asciz "sharedApplication"
method_setActivationPolicy: .asciz "setActivationPolicy:"
method_setDelegate: .asciz "setDelegate:"
method_run: .asciz "run"
method_appendPath: .asciz "stringByAppendingPathComponent:"
method_defaultManager: .asciz "defaultManager"
method_createDirectory: .asciz "createDirectoryAtPath:withIntermediateDirectories:attributes:error:"
method_fileSystemRepresentation: .asciz "fileSystemRepresentation"
method_initWindow: .asciz "initWithContentRect:styleMask:backing:defer:"
method_setReleasedWhenClosed: .asciz "setReleasedWhenClosed:"
method_setTitle: .asciz "setTitle:"
method_setContentMinSize: .asciz "setContentMinSize:"
method_center: .asciz "center"
method_contentView: .asciz "contentView"
method_button: .asciz "buttonWithTitle:target:action:"
method_setFrame: .asciz "setFrame:"
method_setBezelStyle: .asciz "setBezelStyle:"
method_setAutoresizing: .asciz "setAutoresizingMask:"
method_addSubview: .asciz "addSubview:"
method_initFrame: .asciz "initWithFrame:"
method_setPlaceholder: .asciz "setPlaceholderString:"
method_setTarget: .asciz "setTarget:"
method_setAction: .asciz "setAction:"
method_defaultDataStore: .asciz "defaultDataStore"
method_setWebsiteDataStore: .asciz "setWebsiteDataStore:"
method_initWeb: .asciz "initWithFrame:configuration:"
method_setNavigationDelegate: .asciz "setNavigationDelegate:"
method_setUIDelegate: .asciz "setUIDelegate:"
method_setGestures: .asciz "setAllowsBackForwardNavigationGestures:"
method_labelWithString: .asciz "labelWithString:"
method_systemFont: .asciz "systemFontOfSize:"
method_setFont: .asciz "setFont:"
method_secondaryColor: .asciz "secondaryLabelColor"
method_setTextColor: .asciz "setTextColor:"
method_makeKey: .asciz "makeKeyAndOrderFront:"
method_activate: .asciz "activateIgnoringOtherApps:"
method_setStringValue: .asciz "setStringValue:"
method_makeFirstResponder: .asciz "makeFirstResponder:"
method_selectText: .asciz "selectText:"
method_stringValue: .asciz "stringValue"
method_requestWithURL: .asciz "requestWithURL:"
method_loadRequest: .asciz "loadRequest:"
method_goBack: .asciz "goBack:"
method_goForward: .asciz "goForward:"
method_reload: .asciz "reload:"
method_isLoading: .asciz "isLoading"
method_stopLoading: .asciz "stopLoading"
method_canGoBack: .asciz "canGoBack"
method_canGoForward: .asciz "canGoForward"
method_setEnabled: .asciz "setEnabled:"
method_title: .asciz "title"
method_window: .asciz "window"
method_absoluteString: .asciz "absoluteString"
method_UTF8String: .asciz "UTF8String"
method_numberLongLong: .asciz "numberWithLongLong:"
method_longLongValue: .asciz "longLongValue"
method_addObserver: .asciz "addObserver:forKeyPath:options:context:"
method_removeObserver: .asciz "removeObserver:forKeyPath:"
method_code: .asciz "code"
method_localizedDescription: .asciz "localizedDescription"
method_request: .asciz "request"
method_setContentView: .asciz "setContentView:"
method_addObject: .asciz "addObject:"
method_defaultCenter: .asciz "defaultCenter"
method_observeNotification: .asciz "addObserver:selector:name:object:"
method_removeNotification: .asciz "removeObserver:name:object:"
method_object: .asciz "object"
method_removeObject: .asciz "removeObject:"
method_close: .asciz "close"
method_initIdentifier: .asciz "initWithIdentifier:"
method_capitalized: .asciz "capitalizedString"
method_setWidth: .asciz "setWidth:"
method_setVerticalScroller: .asciz "setHasVerticalScroller:"
method_setDataSource: .asciz "setDataSource:"
method_setDoubleAction: .asciz "setDoubleAction:"
method_addTableColumn: .asciz "addTableColumn:"
method_setDocumentView: .asciz "setDocumentView:"
method_reloadData: .asciz "reloadData"
method_setObjectKey: .asciz "setObject:forKey:"
method_count: .asciz "count"
method_objectAtIndex: .asciz "objectAtIndex:"
method_identifier: .asciz "identifier"
method_objectForKey: .asciz "objectForKey:"
method_clickedRow: .asciz "clickedRow"
method_setSubmenu: .asciz "setSubmenu:"
method_addItem: .asciz "addItem:"
method_addMenuItem: .asciz "addItemWithTitle:action:keyEquivalent:"
method_setMainMenu: .asciz "setMainMenu:"
method_setMessage: .asciz "setMessageText:"
method_setInformativeText: .asciz "setInformativeText:"
method_addButton: .asciz "addButtonWithTitle:"
method_runModal: .asciz "runModal"
method_setAccessoryView: .asciz "setAccessoryView:"
method_setInitialFirstResponder: .asciz "setInitialFirstResponder:"
method_protectionSpace: .asciz "protectionSpace"
method_authenticationMethod: .asciz "authenticationMethod"
method_previousFailureCount: .asciz "previousFailureCount"
method_protocol: .asciz "protocol"
method_stringFormat: .asciz "stringWithFormat:"
method_setNextKeyView: .asciz "setNextKeyView:"
method_credential: .asciz "credentialWithUser:password:persistence:"
method_launch: .asciz "applicationDidFinishLaunching:"
method_focus: .asciz "focusAddress:"
method_navigate: .asciz "navigate:"
method_showHistory: .asciz "showHistory:"
method_refreshHistory: .asciz "refreshHistory:"
method_openHistory: .asciz "openHistory:"
method_popupClosed: .asciz "popupClosed:"
method_loadStarted: .asciz "webView:didStartProvisionalNavigation:"
method_loadCommitted: .asciz "webView:didCommitNavigation:"
method_loadFinished: .asciz "webView:didFinishNavigation:"
method_loadFailed: .asciz "webView:didFailNavigation:withError:"
method_loadProvisionalFailed: .asciz "webView:didFailProvisionalNavigation:withError:"
method_processStopped: .asciz "webViewWebContentProcessDidTerminate:"
method_policy: .asciz "webView:decidePolicyForNavigationAction:decisionHandler:"
method_authenticate: .asciz "webView:didReceiveAuthenticationChallenge:completionHandler:"
method_popupCreate: .asciz "webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:"
method_webClose: .asciz "webViewDidClose:"
method_jsAlert: .asciz "webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:"
method_jsConfirm: .asciz "webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:"
method_jsPrompt: .asciz "webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:"
method_historyCount: .asciz "numberOfRowsInTableView:"
method_historyValue: .asciz "tableView:objectValueForTableColumn:row:"
method_shouldQuit: .asciz "applicationShouldTerminateAfterLastWindowClosed:"
method_willTerminate: .asciz "applicationWillTerminate:"
method_observeValue: .asciz "observeValueForKeyPath:ofObject:change:context:"
method_goBackNative: .asciz "goBack"
method_goForwardNative: .asciz "goForward"
method_reloadNative: .asciz "reload"
method_undo: .asciz "undo:"
method_cut: .asciz "cut:"
method_copy: .asciz "copy:"
method_paste: .asciz "paste:"
method_selectAll: .asciz "selectAll:"
method_terminate: .asciz "terminate:"

.section __DATA,__data
.p2align 3
.globl _sel_new
_sel_new: .quad method_new
.globl _sel_alloc
_sel_alloc: .quad method_alloc
.globl _sel_release
_sel_release: .quad method_release
.globl _sel_retain
_sel_retain: .quad method_retain
.globl _sel_autorelease
_sel_autorelease: .quad method_autorelease
.globl _sel_stringUTF8
_sel_stringUTF8: .quad method_stringUTF8
.globl _sel_whitespace
_sel_whitespace: .quad method_whitespace
.globl _sel_trim
_sel_trim: .quad method_trim
.globl _sel_length
_sel_length: .quad method_length
.globl _sel_contains
_sel_contains: .quad method_contains
.globl _sel_hasPrefix
_sel_hasPrefix: .quad method_hasPrefix
.globl _sel_append
_sel_append: .quad method_append
.globl _sel_URLWithString
_sel_URLWithString: .quad method_URLWithString
.globl _sel_host
_sel_host: .quad method_host
.globl _sel_scheme
_sel_scheme: .quad method_scheme
.globl _sel_lowercase
_sel_lowercase: .quad method_lowercase
.globl _sel_equal
_sel_equal: .quad method_equal
.globl _sel_components
_sel_components: .quad method_components
.globl _sel_queryItem
_sel_queryItem: .quad method_queryItem
.globl _sel_arrayObject
_sel_arrayObject: .quad method_arrayObject
.globl _sel_setQueryItems
_sel_setQueryItems: .quad method_setQueryItems
.globl _sel_URL
_sel_URL: .quad method_URL
.globl _sel_sharedApplication
_sel_sharedApplication: .quad method_sharedApplication
.globl _sel_setActivationPolicy
_sel_setActivationPolicy: .quad method_setActivationPolicy
.globl _sel_setDelegate
_sel_setDelegate: .quad method_setDelegate
.globl _sel_run
_sel_run: .quad method_run
.globl _sel_appendPath
_sel_appendPath: .quad method_appendPath
.globl _sel_defaultManager
_sel_defaultManager: .quad method_defaultManager
.globl _sel_createDirectory
_sel_createDirectory: .quad method_createDirectory
.globl _sel_fileSystemRepresentation
_sel_fileSystemRepresentation: .quad method_fileSystemRepresentation
.globl _sel_initWindow
_sel_initWindow: .quad method_initWindow
.globl _sel_setReleasedWhenClosed
_sel_setReleasedWhenClosed: .quad method_setReleasedWhenClosed
.globl _sel_setTitle
_sel_setTitle: .quad method_setTitle
.globl _sel_setContentMinSize
_sel_setContentMinSize: .quad method_setContentMinSize
.globl _sel_center
_sel_center: .quad method_center
.globl _sel_contentView
_sel_contentView: .quad method_contentView
.globl _sel_button
_sel_button: .quad method_button
.globl _sel_setFrame
_sel_setFrame: .quad method_setFrame
.globl _sel_setBezelStyle
_sel_setBezelStyle: .quad method_setBezelStyle
.globl _sel_setAutoresizing
_sel_setAutoresizing: .quad method_setAutoresizing
.globl _sel_addSubview
_sel_addSubview: .quad method_addSubview
.globl _sel_initFrame
_sel_initFrame: .quad method_initFrame
.globl _sel_setPlaceholder
_sel_setPlaceholder: .quad method_setPlaceholder
.globl _sel_setTarget
_sel_setTarget: .quad method_setTarget
.globl _sel_setAction
_sel_setAction: .quad method_setAction
.globl _sel_defaultDataStore
_sel_defaultDataStore: .quad method_defaultDataStore
.globl _sel_setWebsiteDataStore
_sel_setWebsiteDataStore: .quad method_setWebsiteDataStore
.globl _sel_initWeb
_sel_initWeb: .quad method_initWeb
.globl _sel_setNavigationDelegate
_sel_setNavigationDelegate: .quad method_setNavigationDelegate
.globl _sel_setUIDelegate
_sel_setUIDelegate: .quad method_setUIDelegate
.globl _sel_setGestures
_sel_setGestures: .quad method_setGestures
.globl _sel_labelWithString
_sel_labelWithString: .quad method_labelWithString
.globl _sel_systemFont
_sel_systemFont: .quad method_systemFont
.globl _sel_setFont
_sel_setFont: .quad method_setFont
.globl _sel_secondaryColor
_sel_secondaryColor: .quad method_secondaryColor
.globl _sel_setTextColor
_sel_setTextColor: .quad method_setTextColor
.globl _sel_makeKey
_sel_makeKey: .quad method_makeKey
.globl _sel_activate
_sel_activate: .quad method_activate
.globl _sel_setStringValue
_sel_setStringValue: .quad method_setStringValue
.globl _sel_makeFirstResponder
_sel_makeFirstResponder: .quad method_makeFirstResponder
.globl _sel_selectText
_sel_selectText: .quad method_selectText
.globl _sel_stringValue
_sel_stringValue: .quad method_stringValue
.globl _sel_requestWithURL
_sel_requestWithURL: .quad method_requestWithURL
.globl _sel_loadRequest
_sel_loadRequest: .quad method_loadRequest
.globl _sel_goBack
_sel_goBack: .quad method_goBack
.globl _sel_goForward
_sel_goForward: .quad method_goForward
.globl _sel_reload
_sel_reload: .quad method_reload
.globl _sel_isLoading
_sel_isLoading: .quad method_isLoading
.globl _sel_stopLoading
_sel_stopLoading: .quad method_stopLoading
.globl _sel_canGoBack
_sel_canGoBack: .quad method_canGoBack
.globl _sel_canGoForward
_sel_canGoForward: .quad method_canGoForward
.globl _sel_setEnabled
_sel_setEnabled: .quad method_setEnabled
.globl _sel_title
_sel_title: .quad method_title
.globl _sel_window
_sel_window: .quad method_window
.globl _sel_absoluteString
_sel_absoluteString: .quad method_absoluteString
.globl _sel_UTF8String
_sel_UTF8String: .quad method_UTF8String
.globl _sel_numberLongLong
_sel_numberLongLong: .quad method_numberLongLong
.globl _sel_longLongValue
_sel_longLongValue: .quad method_longLongValue
.globl _sel_addObserver
_sel_addObserver: .quad method_addObserver
.globl _sel_removeObserver
_sel_removeObserver: .quad method_removeObserver
.globl _sel_code
_sel_code: .quad method_code
.globl _sel_localizedDescription
_sel_localizedDescription: .quad method_localizedDescription
.globl _sel_request
_sel_request: .quad method_request
.globl _sel_setContentView
_sel_setContentView: .quad method_setContentView
.globl _sel_addObject
_sel_addObject: .quad method_addObject
.globl _sel_defaultCenter
_sel_defaultCenter: .quad method_defaultCenter
.globl _sel_observeNotification
_sel_observeNotification: .quad method_observeNotification
.globl _sel_removeNotification
_sel_removeNotification: .quad method_removeNotification
.globl _sel_object
_sel_object: .quad method_object
.globl _sel_removeObject
_sel_removeObject: .quad method_removeObject
.globl _sel_close
_sel_close: .quad method_close
.globl _sel_initIdentifier
_sel_initIdentifier: .quad method_initIdentifier
.globl _sel_capitalized
_sel_capitalized: .quad method_capitalized
.globl _sel_setWidth
_sel_setWidth: .quad method_setWidth
.globl _sel_setVerticalScroller
_sel_setVerticalScroller: .quad method_setVerticalScroller
.globl _sel_setDataSource
_sel_setDataSource: .quad method_setDataSource
.globl _sel_setDoubleAction
_sel_setDoubleAction: .quad method_setDoubleAction
.globl _sel_addTableColumn
_sel_addTableColumn: .quad method_addTableColumn
.globl _sel_setDocumentView
_sel_setDocumentView: .quad method_setDocumentView
.globl _sel_reloadData
_sel_reloadData: .quad method_reloadData
.globl _sel_setObjectKey
_sel_setObjectKey: .quad method_setObjectKey
.globl _sel_count
_sel_count: .quad method_count
.globl _sel_objectAtIndex
_sel_objectAtIndex: .quad method_objectAtIndex
.globl _sel_identifier
_sel_identifier: .quad method_identifier
.globl _sel_objectForKey
_sel_objectForKey: .quad method_objectForKey
.globl _sel_clickedRow
_sel_clickedRow: .quad method_clickedRow
.globl _sel_setSubmenu
_sel_setSubmenu: .quad method_setSubmenu
.globl _sel_addItem
_sel_addItem: .quad method_addItem
.globl _sel_addMenuItem
_sel_addMenuItem: .quad method_addMenuItem
.globl _sel_setMainMenu
_sel_setMainMenu: .quad method_setMainMenu
.globl _sel_setMessage
_sel_setMessage: .quad method_setMessage
.globl _sel_setInformativeText
_sel_setInformativeText: .quad method_setInformativeText
.globl _sel_addButton
_sel_addButton: .quad method_addButton
.globl _sel_runModal
_sel_runModal: .quad method_runModal
.globl _sel_setAccessoryView
_sel_setAccessoryView: .quad method_setAccessoryView
.globl _sel_setInitialFirstResponder
_sel_setInitialFirstResponder: .quad method_setInitialFirstResponder
.globl _sel_protectionSpace
_sel_protectionSpace: .quad method_protectionSpace
.globl _sel_authenticationMethod
_sel_authenticationMethod: .quad method_authenticationMethod
.globl _sel_previousFailureCount
_sel_previousFailureCount: .quad method_previousFailureCount
.globl _sel_protocol
_sel_protocol: .quad method_protocol
.globl _sel_stringFormat
_sel_stringFormat: .quad method_stringFormat
.globl _sel_setNextKeyView
_sel_setNextKeyView: .quad method_setNextKeyView
.globl _sel_credential
_sel_credential: .quad method_credential
.globl _sel_launch
_sel_launch: .quad method_launch
.globl _sel_focus
_sel_focus: .quad method_focus
.globl _sel_navigate
_sel_navigate: .quad method_navigate
.globl _sel_showHistory
_sel_showHistory: .quad method_showHistory
.globl _sel_refreshHistory
_sel_refreshHistory: .quad method_refreshHistory
.globl _sel_openHistory
_sel_openHistory: .quad method_openHistory
.globl _sel_popupClosed
_sel_popupClosed: .quad method_popupClosed
.globl _sel_loadStarted
_sel_loadStarted: .quad method_loadStarted
.globl _sel_loadCommitted
_sel_loadCommitted: .quad method_loadCommitted
.globl _sel_loadFinished
_sel_loadFinished: .quad method_loadFinished
.globl _sel_loadFailed
_sel_loadFailed: .quad method_loadFailed
.globl _sel_loadProvisionalFailed
_sel_loadProvisionalFailed: .quad method_loadProvisionalFailed
.globl _sel_processStopped
_sel_processStopped: .quad method_processStopped
.globl _sel_policy
_sel_policy: .quad method_policy
.globl _sel_authenticate
_sel_authenticate: .quad method_authenticate
.globl _sel_popupCreate
_sel_popupCreate: .quad method_popupCreate
.globl _sel_webClose
_sel_webClose: .quad method_webClose
.globl _sel_jsAlert
_sel_jsAlert: .quad method_jsAlert
.globl _sel_jsConfirm
_sel_jsConfirm: .quad method_jsConfirm
.globl _sel_jsPrompt
_sel_jsPrompt: .quad method_jsPrompt
.globl _sel_historyCount
_sel_historyCount: .quad method_historyCount
.globl _sel_historyValue
_sel_historyValue: .quad method_historyValue
.globl _sel_shouldQuit
_sel_shouldQuit: .quad method_shouldQuit
.globl _sel_willTerminate
_sel_willTerminate: .quad method_willTerminate
.globl _sel_observeValue
_sel_observeValue: .quad method_observeValue
.globl _sel_goBackNative
_sel_goBackNative: .quad method_goBackNative
.globl _sel_goForwardNative
_sel_goForwardNative: .quad method_goForwardNative
.globl _sel_reloadNative
_sel_reloadNative: .quad method_reloadNative
.globl _sel_undo
_sel_undo: .quad method_undo
.globl _sel_cut
_sel_cut: .quad method_cut
.globl _sel_copy
_sel_copy: .quad method_copy
.globl _sel_paste
_sel_paste: .quad method_paste
.globl _sel_selectAll
_sel_selectAll: .quad method_selectAll
.globl _sel_terminate
_sel_terminate: .quad method_terminate

.section __TEXT,__cstring,cstring_literals
engine_method_engineToggle: .asciz "toggleAssemblyEngine:"
engine_method_engineLink: .asciz "textView:clickedOnLink:atIndex:"
engine_method_engineResponse: .asciz "URLSession:dataTask:didReceiveResponse:completionHandler:"
engine_method_engineData: .asciz "URLSession:dataTask:didReceiveData:"
engine_method_engineComplete: .asciz "URLSession:task:didCompleteWithError:"
engine_method_engineRedirect: .asciz "URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:"
engine_method_setState: .asciz "setState:"
engine_method_setHidden: .asciz "setHidden:"
engine_method_setEditable: .asciz "setEditable:"
engine_method_setSelectable: .asciz "setSelectable:"
engine_method_setRichText: .asciz "setRichText:"
engine_method_setAutomaticLinks: .asciz "setAutomaticLinkDetectionEnabled:"
engine_method_setImportsGraphics: .asciz "setImportsGraphics:"
engine_method_setHorizontallyResizable: .asciz "setHorizontallyResizable:"
engine_method_setVerticallyResizable: .asciz "setVerticallyResizable:"
engine_method_setMinSize: .asciz "setMinSize:"
engine_method_setMaxSize: .asciz "setMaxSize:"
engine_method_setTextInset: .asciz "setTextContainerInset:"
engine_method_ephemeralConfiguration: .asciz "ephemeralSessionConfiguration"
engine_method_mainQueue: .asciz "mainQueue"
engine_method_sessionWithConfiguration: .asciz "sessionWithConfiguration:delegate:delegateQueue:"
engine_method_dataTask: .asciz "dataTaskWithRequest:"
engine_method_resume: .asciz "resume"
engine_method_cancel: .asciz "cancel"
engine_method_expectedLength: .asciz "expectedContentLength"
engine_method_statusCode: .asciz "statusCode"
engine_method_MIMEType: .asciz "MIMEType"
engine_method_appendData: .asciz "appendData:"
engine_method_initDataEncoding: .asciz "initWithData:encoding:"
engine_method_bytes: .asciz "bytes"
engine_method_removeLastObject: .asciz "removeLastObject"
engine_method_initBytesEncoding: .asciz "initWithBytes:length:encoding:"
engine_method_initString: .asciz "initWithString:"
engine_method_monospacedFont: .asciz "monospacedSystemFontOfSize:weight:"
engine_method_addAttribute: .asciz "addAttribute:value:range:"
engine_method_textColor: .asciz "textColor"
engine_method_relativeURL: .asciz "URLWithString:relativeToURL:"
engine_method_absoluteURL: .asciz "absoluteURL"
engine_method_textStorage: .asciz "textStorage"
engine_method_setAttributedString: .asciz "setAttributedString:"
engine_method_setFrameSize: .asciz "setFrameSize:"
engine_method_scrollRange: .asciz "scrollRangeToVisible:"
engine_encoding_0: .asciz "v@:@"
engine_encoding_1: .asciz "B@:@@Q"
engine_encoding_2: .asciz "v@:@@@@?"
engine_encoding_3: .asciz "v@:@@@"
engine_encoding_4: .asciz "v@:@@@"
engine_encoding_5: .asciz "v@:@@@@@?"
engine_protocol_0: .asciz "NSTextViewDelegate"
engine_protocol_1: .asciz "NSURLSessionDataDelegate"
engine_protocol_2: .asciz "NSURLSessionTaskDelegate"
.globl _class_NSTextView
_class_NSTextView: .asciz "NSTextView"
.globl _class_NSMutableData
_class_NSMutableData: .asciz "NSMutableData"
.globl _class_NSMutableAttributedString
_class_NSMutableAttributedString: .asciz "NSMutableAttributedString"
.globl _class_NSOperationQueue
_class_NSOperationQueue: .asciz "NSOperationQueue"
.globl _class_NSURLSession
_class_NSURLSession: .asciz "NSURLSession"
.globl _class_NSURLSessionConfiguration
_class_NSURLSessionConfiguration: .asciz "NSURLSessionConfiguration"

.section __DATA,__data
.p2align 3
.globl _sel_engineToggle
_sel_engineToggle: .quad engine_method_engineToggle
.globl _sel_engineLink
_sel_engineLink: .quad engine_method_engineLink
.globl _sel_engineResponse
_sel_engineResponse: .quad engine_method_engineResponse
.globl _sel_engineData
_sel_engineData: .quad engine_method_engineData
.globl _sel_engineComplete
_sel_engineComplete: .quad engine_method_engineComplete
.globl _sel_engineRedirect
_sel_engineRedirect: .quad engine_method_engineRedirect
.globl _sel_setState
_sel_setState: .quad engine_method_setState
.globl _sel_setHidden
_sel_setHidden: .quad engine_method_setHidden
.globl _sel_setEditable
_sel_setEditable: .quad engine_method_setEditable
.globl _sel_setSelectable
_sel_setSelectable: .quad engine_method_setSelectable
.globl _sel_setRichText
_sel_setRichText: .quad engine_method_setRichText
.globl _sel_setAutomaticLinks
_sel_setAutomaticLinks: .quad engine_method_setAutomaticLinks
.globl _sel_setImportsGraphics
_sel_setImportsGraphics: .quad engine_method_setImportsGraphics
.globl _sel_setHorizontallyResizable
_sel_setHorizontallyResizable: .quad engine_method_setHorizontallyResizable
.globl _sel_setVerticallyResizable
_sel_setVerticallyResizable: .quad engine_method_setVerticallyResizable
.globl _sel_setMinSize
_sel_setMinSize: .quad engine_method_setMinSize
.globl _sel_setMaxSize
_sel_setMaxSize: .quad engine_method_setMaxSize
.globl _sel_setTextInset
_sel_setTextInset: .quad engine_method_setTextInset
.globl _sel_ephemeralConfiguration
_sel_ephemeralConfiguration: .quad engine_method_ephemeralConfiguration
.globl _sel_mainQueue
_sel_mainQueue: .quad engine_method_mainQueue
.globl _sel_sessionWithConfiguration
_sel_sessionWithConfiguration: .quad engine_method_sessionWithConfiguration
.globl _sel_dataTask
_sel_dataTask: .quad engine_method_dataTask
.globl _sel_resume
_sel_resume: .quad engine_method_resume
.globl _sel_cancel
_sel_cancel: .quad engine_method_cancel
.globl _sel_expectedLength
_sel_expectedLength: .quad engine_method_expectedLength
.globl _sel_statusCode
_sel_statusCode: .quad engine_method_statusCode
.globl _sel_MIMEType
_sel_MIMEType: .quad engine_method_MIMEType
.globl _sel_appendData
_sel_appendData: .quad engine_method_appendData
.globl _sel_initDataEncoding
_sel_initDataEncoding: .quad engine_method_initDataEncoding
.globl _sel_bytes
_sel_bytes: .quad engine_method_bytes
.globl _sel_removeLastObject
_sel_removeLastObject: .quad engine_method_removeLastObject
.globl _sel_initBytesEncoding
_sel_initBytesEncoding: .quad engine_method_initBytesEncoding
.globl _sel_initString
_sel_initString: .quad engine_method_initString
.globl _sel_monospacedFont
_sel_monospacedFont: .quad engine_method_monospacedFont
.globl _sel_addAttribute
_sel_addAttribute: .quad engine_method_addAttribute
.globl _sel_textColor
_sel_textColor: .quad engine_method_textColor
.globl _sel_relativeURL
_sel_relativeURL: .quad engine_method_relativeURL
.globl _sel_absoluteURL
_sel_absoluteURL: .quad engine_method_absoluteURL
.globl _sel_textStorage
_sel_textStorage: .quad engine_method_textStorage
.globl _sel_setAttributedString
_sel_setAttributedString: .quad engine_method_setAttributedString
.globl _sel_setFrameSize
_sel_setFrameSize: .quad engine_method_setFrameSize
.globl _sel_scrollRange
_sel_scrollRange: .quad engine_method_scrollRange

.section __TEXT,__cstring,cstring_literals
engine_method_setHorizontalScroller: .asciz "setHasHorizontalScroller:"
.section __DATA,__data
.p2align 3
.globl _sel_setHorizontalScroller
_sel_setHorizontalScroller: .quad engine_method_setHorizontalScroller
.section __TEXT,__cstring,cstring_literals
charset_method_textEncodingName: .asciz "textEncodingName"
charset_method_dataUsingEncoding: .asciz "dataUsingEncoding:"

.section __DATA,__data
.p2align 3
.globl _sel_textEncodingName
_sel_textEncodingName: .quad charset_method_textEncodingName
.globl _sel_dataUsingEncoding
_sel_dataUsingEncoding: .quad charset_method_dataUsingEncoding

.section __TEXT,__cstring,cstring_literals
css_method_sRGBColor: .asciz "colorWithSRGBRed:green:blue:alpha:"
css_method_systemFontWeight: .asciz "systemFontOfSize:weight:"
css_method_fontNameSize: .asciz "fontWithName:size:"
css_method_sharedFontManager: .asciz "sharedFontManager"
css_method_convertFontTrait: .asciz "convertFont:toHaveTrait:"
css_method_setAlignment: .asciz "setAlignment:"
css_method_setParagraphBefore: .asciz "setParagraphSpacingBefore:"
css_method_setParagraphAfter: .asciz "setParagraphSpacing:"
css_method_setHeadIndent: .asciz "setHeadIndent:"
css_method_setFirstIndent: .asciz "setFirstLineHeadIndent:"
css_method_setTailIndent: .asciz "setTailIndent:"
css_method_setMinimumLine: .asciz "setMinimumLineHeight:"
css_method_setMaximumLine: .asciz "setMaximumLineHeight:"
css_method_setBackgroundColor: .asciz "setBackgroundColor:"
css_method_textBackgroundColor: .asciz "textBackgroundColor"
css_method_setDrawsBackground: .asciz "setDrawsBackground:"
css_method_setLinkTextAttributes: .asciz "setLinkTextAttributes:"
css_method_textContainer: .asciz "textContainer"
css_method_setContainerSize: .asciz "setContainerSize:"
css_method_setWidthTracksView: .asciz "setWidthTracksTextView:"
css_method_layoutManager: .asciz "layoutManager"
css_method_ensureTextLayout: .asciz "ensureLayoutForTextContainer:"
css_method_usedTextRect: .asciz "usedRectForTextContainer:"
.globl _class_NSFontManager
_class_NSFontManager: .asciz "NSFontManager"
.globl _class_NSMutableParagraphStyle
_class_NSMutableParagraphStyle: .asciz "NSMutableParagraphStyle"

.section __DATA,__data
.p2align 3
.globl _sel_sRGBColor
_sel_sRGBColor: .quad css_method_sRGBColor
.globl _sel_systemFontWeight
_sel_systemFontWeight: .quad css_method_systemFontWeight
.globl _sel_fontNameSize
_sel_fontNameSize: .quad css_method_fontNameSize
.globl _sel_sharedFontManager
_sel_sharedFontManager: .quad css_method_sharedFontManager
.globl _sel_convertFontTrait
_sel_convertFontTrait: .quad css_method_convertFontTrait
.globl _sel_setAlignment
_sel_setAlignment: .quad css_method_setAlignment
.globl _sel_setParagraphBefore
_sel_setParagraphBefore: .quad css_method_setParagraphBefore
.globl _sel_setParagraphAfter
_sel_setParagraphAfter: .quad css_method_setParagraphAfter
.globl _sel_setHeadIndent
_sel_setHeadIndent: .quad css_method_setHeadIndent
.globl _sel_setFirstIndent
_sel_setFirstIndent: .quad css_method_setFirstIndent
.globl _sel_setTailIndent
_sel_setTailIndent: .quad css_method_setTailIndent
.globl _sel_setMinimumLine
_sel_setMinimumLine: .quad css_method_setMinimumLine
.globl _sel_setMaximumLine
_sel_setMaximumLine: .quad css_method_setMaximumLine
.globl _sel_setBackgroundColor
_sel_setBackgroundColor: .quad css_method_setBackgroundColor
.globl _sel_textBackgroundColor
_sel_textBackgroundColor: .quad css_method_textBackgroundColor
.globl _sel_setDrawsBackground
_sel_setDrawsBackground: .quad css_method_setDrawsBackground
.globl _sel_setLinkTextAttributes
_sel_setLinkTextAttributes: .quad css_method_setLinkTextAttributes
.globl _sel_textContainer
_sel_textContainer: .quad css_method_textContainer
.globl _sel_setContainerSize
_sel_setContainerSize: .quad css_method_setContainerSize
.globl _sel_setWidthTracksView
_sel_setWidthTracksView: .quad css_method_setWidthTracksView
.globl _sel_layoutManager
_sel_layoutManager: .quad css_method_layoutManager
.globl _sel_ensureTextLayout
_sel_ensureTextLayout: .quad css_method_ensureTextLayout
.globl _sel_usedTextRect
_sel_usedTextRect: .quad css_method_usedTextRect


.section __TEXT,__cstring,cstring_literals
feature_method_resourceRequest: .asciz "requestWithURL:cachePolicy:timeoutInterval:"
feature_method_initData: .asciz "initWithData:"
feature_method_setSize: .asciz "setSize:"
feature_method_setObjectKey: .asciz "setObject:forKey:"
feature_method_objectKey: .asciz "objectForKey:"
feature_method_hasPrefix: .asciz "hasPrefix:"
.globl _class_NSImage
_class_NSImage: .asciz "NSImage"

.section __DATA,__data
.p2align 3
.globl _sel_resourceRequest
_sel_resourceRequest: .quad feature_method_resourceRequest
.globl _sel_initData
_sel_initData: .quad feature_method_initData
.globl _sel_setSize
_sel_setSize: .quad feature_method_setSize
.globl _sel_objectKey
_sel_objectKey: .quad feature_method_objectKey


.section __TEXT,__cstring,cstring_literals
feature_method_blockWidth: .asciz "setContentWidth:type:"
feature_method_blockValue: .asciz "setValue:type:forDimension:"
feature_method_blockEdge: .asciz "setWidth:type:forLayer:edge:"
feature_method_blockBorderColor: .asciz "setBorderColor:"
feature_method_setTextBlocks: .asciz "setTextBlocks:"
feature_method_insertObjectIndex: .asciz "insertObject:atIndex:"
feature_method_attributeIndex: .asciz "attribute:atIndex:effectiveRange:"
feature_method_mutableCopy: .asciz "mutableCopy"
feature_method_size: .asciz "size"
feature_method_setImage: .asciz "setImage:"
feature_method_setBounds: .asciz "setBounds:"
feature_method_initTextCell: .asciz "initTextCell:"
feature_method_setAttachmentCell: .asciz "setAttachmentCell:"
feature_method_setCellSize: .asciz "setCellSize:"
feature_method_subviews: .asciz "subviews"
feature_method_removeFromSuperview: .asciz "removeFromSuperview"
feature_method_glyphRange: .asciz "glyphRangeForCharacterRange:actualCharacterRange:"
feature_method_glyphRect: .asciz "boundingRectForGlyphRange:inTextContainer:"
feature_method_setTag: .asciz "setTag:"
feature_method_tag: .asciz "tag"
feature_method_engineSubmit: .asciz "engineSubmit:"
feature_method_queryItems: .asciz "queryItems"
feature_method_componentsURL: .asciz "componentsWithURL:resolvingAgainstBaseURL:"
feature_method_setQueryItems: .asciz "setQueryItems:"
feature_method_queryItem: .asciz "queryItemWithName:value:"
feature_method_setPlaceholder: .asciz "setPlaceholderString:"
.globl _class_NSTextBlock
_class_NSTextBlock: .asciz "NSTextBlock"
.globl _class_NSTextAttachment
_class_NSTextAttachment: .asciz "NSTextAttachment"
.globl _class_NSTextAttachmentCell
_class_NSTextAttachmentCell: .asciz "NSTextAttachmentCell"

.section __DATA,__data
.p2align 3
.globl _sel_blockWidth
_sel_blockWidth: .quad feature_method_blockWidth
.globl _sel_blockValue
_sel_blockValue: .quad feature_method_blockValue
.globl _sel_blockEdge
_sel_blockEdge: .quad feature_method_blockEdge
.globl _sel_blockBorderColor
_sel_blockBorderColor: .quad feature_method_blockBorderColor
.globl _sel_setTextBlocks
_sel_setTextBlocks: .quad feature_method_setTextBlocks
.globl _sel_insertObjectIndex
_sel_insertObjectIndex: .quad feature_method_insertObjectIndex
.globl _sel_attributeIndex
_sel_attributeIndex: .quad feature_method_attributeIndex
.globl _sel_mutableCopy
_sel_mutableCopy: .quad feature_method_mutableCopy
.globl _sel_size
_sel_size: .quad feature_method_size
.globl _sel_setImage
_sel_setImage: .quad feature_method_setImage
.globl _sel_setBounds
_sel_setBounds: .quad feature_method_setBounds
.globl _sel_initTextCell
_sel_initTextCell: .quad feature_method_initTextCell
.globl _sel_setAttachmentCell
_sel_setAttachmentCell: .quad feature_method_setAttachmentCell
.globl _sel_setCellSize
_sel_setCellSize: .quad feature_method_setCellSize
.globl _sel_subviews
_sel_subviews: .quad feature_method_subviews
.globl _sel_removeFromSuperview
_sel_removeFromSuperview: .quad feature_method_removeFromSuperview
.globl _sel_glyphRange
_sel_glyphRange: .quad feature_method_glyphRange
.globl _sel_glyphRect
_sel_glyphRect: .quad feature_method_glyphRect
.globl _sel_setTag
_sel_setTag: .quad feature_method_setTag
.globl _sel_tag
_sel_tag: .quad feature_method_tag
.globl _sel_engineSubmit
_sel_engineSubmit: .quad feature_method_engineSubmit
.globl _sel_queryItems
_sel_queryItems: .quad feature_method_queryItems
.globl _sel_componentsURL
_sel_componentsURL: .quad feature_method_componentsURL


.section __TEXT,__cstring,cstring_literals
feature_method_initSize: .asciz "initWithSize:"
feature_method_setEncodedQuery: .asciz "setPercentEncodedQuery:"
feature_method_formAppend: .asciz "appendString:"
feature_method_setBordered: .asciz "setBordered:"

.section __DATA,__data
.p2align 3
.globl _sel_initSize
_sel_initSize: .quad feature_method_initSize
.globl _sel_setEncodedQuery
_sel_setEncodedQuery: .quad feature_method_setEncodedQuery
.globl _sel_formAppend
_sel_formAppend: .quad feature_method_formAppend
.globl _sel_setBordered
_sel_setBordered: .quad feature_method_setBordered


.section __TEXT,__cstring,cstring_literals
.globl _class_NSMutableString
_class_NSMutableString: .asciz "NSMutableString"

.section __DATA,__data
.p2align 3


.section __TEXT,__cstring,cstring_literals
feature_method_tableColumns: .asciz "setNumberOfColumns:"
feature_method_tableBlock: .asciz "initWithTable:startingRow:rowSpan:startingColumn:columnSpan:"
.globl _class_NSTextTable
_class_NSTextTable: .asciz "NSTextTable"
.globl _class_NSTextTableBlock
_class_NSTextTableBlock: .asciz "NSTextTableBlock"

.section __DATA,__data
.p2align 3
.globl _sel_tableColumns
_sel_tableColumns: .quad feature_method_tableColumns
.globl _sel_tableBlock
_sel_tableBlock: .quad feature_method_tableBlock


.section __TEXT,__cstring,cstring_literals
feature_method_appearanceNamed: .asciz "appearanceNamed:"
feature_method_setAppearance: .asciz "setAppearance:"
feature_method_lockFocus: .asciz "lockFocus"
feature_method_unlockFocus: .asciz "unlockFocus"
feature_method_drawTextPoint: .asciz "drawAtPoint:withAttributes:"
feature_method_accessibilityChildren: .asciz "accessibilityChildren"
feature_method_setAccessibilityChildren: .asciz "setAccessibilityChildren:"
feature_method_setImageDescription: .asciz "setAccessibilityDescription:"
.globl _class_NSAppearance
_class_NSAppearance: .asciz "NSAppearance"

.section __DATA,__data
.p2align 3
.globl _sel_appearanceNamed
_sel_appearanceNamed: .quad feature_method_appearanceNamed
.globl _sel_setAppearance
_sel_setAppearance: .quad feature_method_setAppearance
.globl _sel_lockFocus
_sel_lockFocus: .quad feature_method_lockFocus
.globl _sel_unlockFocus
_sel_unlockFocus: .quad feature_method_unlockFocus
.globl _sel_drawTextPoint
_sel_drawTextPoint: .quad feature_method_drawTextPoint
.globl _sel_accessibilityChildren
_sel_accessibilityChildren: .quad feature_method_accessibilityChildren
.globl _sel_setAccessibilityChildren
_sel_setAccessibilityChildren: .quad feature_method_setAccessibilityChildren
.globl _sel_setImageDescription
_sel_setImageDescription: .quad feature_method_setImageDescription


.section __TEXT,__cstring,cstring_literals
next_method_windowResize: .asciz "windowDidResize:"
next_method_bounds: .asciz "bounds"
next_method_contentSize: .asciz "contentSize"
next_method_copyObject: .asciz "copy"

.section __DATA,__data
.p2align 3
.globl _sel_windowResize
_sel_windowResize: .quad next_method_windowResize
.globl _sel_bounds
_sel_bounds: .quad next_method_bounds
.globl _sel_contentSize
_sel_contentSize: .quad next_method_contentSize
.globl _sel_copyObject
_sel_copyObject: .quad next_method_copyObject


.section __TEXT,__cstring,cstring_literals
next_method_initCache: .asciz "initWithMemoryCapacity:diskCapacity:diskPath:"
next_method_setURLCache: .asciz "setURLCache:"
.globl _class_NSURLCache
_class_NSURLCache: .asciz "NSURLCache"

.section __DATA,__data
.p2align 3
.globl _sel_initCache
_sel_initCache: .quad next_method_initCache
.globl _sel_setURLCache
_sel_setURLCache: .quad next_method_setURLCache


.section __TEXT,__cstring,cstring_literals
next_method_setButtonType: .asciz "setButtonType:"
next_method_state: .asciz "state"
next_method_formToggle: .asciz "engineFormToggle:"
next_method_selectToggle: .asciz "engineSelectToggle:"
next_method_initPopup: .asciz "initWithFrame:pullsDown:"
next_method_menu: .asciz "menu"
next_method_setAutoenables: .asciz "setAutoenablesItems:"
next_method_setRepresentedObject: .asciz "setRepresentedObject:"
next_method_representedObject: .asciz "representedObject"
next_method_selectItem: .asciz "selectItem:"
next_method_selectedItem: .asciz "selectedItem"
next_method_itemArray: .asciz "itemArray"
next_method_setString: .asciz "setString:"
next_method_string: .asciz "string"
next_method_documentView: .asciz "documentView"
next_method_setHTTPMethod: .asciz "setHTTPMethod:"
next_method_setHTTPBody: .asciz "setHTTPBody:"
next_method_setHTTPHeader: .asciz "setValue:forHTTPHeaderField:"
.globl _class_NSPopUpButton
_class_NSPopUpButton: .asciz "NSPopUpButton"
.globl _class_NSMutableURLRequest
_class_NSMutableURLRequest: .asciz "NSMutableURLRequest"

.section __DATA,__data
.p2align 3
.globl _sel_setButtonType
_sel_setButtonType: .quad next_method_setButtonType
.globl _sel_state
_sel_state: .quad next_method_state
.globl _sel_formToggle
_sel_formToggle: .quad next_method_formToggle
.globl _sel_selectToggle
_sel_selectToggle: .quad next_method_selectToggle
.globl _sel_initPopup
_sel_initPopup: .quad next_method_initPopup
.globl _sel_menu
_sel_menu: .quad next_method_menu
.globl _sel_setAutoenables
_sel_setAutoenables: .quad next_method_setAutoenables
.globl _sel_setRepresentedObject
_sel_setRepresentedObject: .quad next_method_setRepresentedObject
.globl _sel_representedObject
_sel_representedObject: .quad next_method_representedObject
.globl _sel_selectItem
_sel_selectItem: .quad next_method_selectItem
.globl _sel_selectedItem
_sel_selectedItem: .quad next_method_selectedItem
.globl _sel_itemArray
_sel_itemArray: .quad next_method_itemArray
.globl _sel_setString
_sel_setString: .quad next_method_setString
.globl _sel_string
_sel_string: .quad next_method_string
.globl _sel_documentView
_sel_documentView: .quad next_method_documentView
.globl _sel_setHTTPMethod
_sel_setHTTPMethod: .quad next_method_setHTTPMethod
.globl _sel_setHTTPBody
_sel_setHTTPBody: .quad next_method_setHTTPBody
.globl _sel_setHTTPHeader
_sel_setHTTPHeader: .quad next_method_setHTTPHeader


.section __TEXT,__cstring,cstring_literals
next_method_isEnabled: .asciz "isEnabled"

.section __DATA,__data
.p2align 3
.globl _sel_isEnabled
_sel_isEnabled: .quad next_method_isEnabled


.section __TEXT,__cstring,cstring_literals
next_method_superview: .asciz "superview"

.section __DATA,__data
.p2align 3
.globl _sel_superview
_sel_superview: .quad next_method_superview


.section __TEXT,__cstring,cstring_literals
next_method_cell: .asciz "cell"
next_method_setAltersState: .asciz "setAltersStateOfSelectedItem:"

.section __DATA,__data
.p2align 3
.globl _sel_cell
_sel_cell: .quad next_method_cell
.globl _sel_setAltersState
_sel_setAltersState: .quad next_method_setAltersState


.section __TEXT,__cstring,cstring_literals
next_method_verticalScroller: .asciz "verticalScroller"
next_method_horizontalScroller: .asciz "horizontalScroller"

.section __DATA,__data
.p2align 3
.globl _sel_verticalScroller
_sel_verticalScroller: .quad next_method_verticalScroller
.globl _sel_horizontalScroller
_sel_horizontalScroller: .quad next_method_horizontalScroller


.section __TEXT,__cstring,cstring_literals
next_method_frame: .asciz "frame"
next_method_glyphLocation: .asciz "locationForGlyphAtIndex:"
next_method_lineFragment: .asciz "lineFragmentRectForGlyphAtIndex:effectiveRange:"
next_method_lastBaseline: .asciz "lastBaselineOffsetFromBottom"
next_method_singleLine: .asciz "setUsesSingleLineMode:"
next_method_initImageCell: .asciz "initImageCell:"
next_method_cellBaselineOffset: .asciz "cellBaselineOffset"
.globl _class_OogaboogaControlAttachment
_class_OogaboogaControlAttachment: .asciz "OogaboogaControlAttachment"

.section __DATA,__data
.p2align 3
.globl _sel_frame
_sel_frame: .quad next_method_frame
.globl _sel_glyphLocation
_sel_glyphLocation: .quad next_method_glyphLocation
.globl _sel_lineFragment
_sel_lineFragment: .quad next_method_lineFragment
.globl _sel_lastBaseline
_sel_lastBaseline: .quad next_method_lastBaseline
.globl _sel_singleLine
_sel_singleLine: .quad next_method_singleLine
.globl _sel_initImageCell
_sel_initImageCell: .quad next_method_initImageCell
.globl _sel_cellBaselineOffset
_sel_cellBaselineOffset: .quad next_method_cellBaselineOffset


.section __TEXT,__cstring,cstring_literals
next_method_intrinsicSize: .asciz "intrinsicContentSize"
next_method_firstBaseline: .asciz "firstBaselineOffsetFromTop"
next_method_typesetter: .asciz "typesetter"
next_method_typesetterBaseline: .asciz "baselineOffsetInLayoutManager:glyphIndex:"

.section __DATA,__data
.p2align 3
.globl _sel_intrinsicSize
_sel_intrinsicSize: .quad next_method_intrinsicSize
.globl _sel_firstBaseline
_sel_firstBaseline: .quad next_method_firstBaseline
.globl _sel_typesetter
_sel_typesetter: .quad next_method_typesetter
.globl _sel_typesetterBaseline
_sel_typesetterBaseline: .quad next_method_typesetterBaseline


.section __TEXT,__cstring,cstring_literals
shortcut_keyMask: .asciz "setKeyEquivalentModifierMask:"
shortcut_redo: .asciz "redo:"
shortcut_allowsUndo: .asciz "setAllowsUndo:"
shortcut_windowUndo: .asciz "windowWillReturnUndoManager:"
shortcut_textUndo: .asciz "undoManagerForTextView:"
shortcut_undoManager: .asciz "undoManager"
shortcut_removeUndoActions: .asciz "removeAllActions"
shortcut_undo_encoding: .asciz "@@:@"
.globl _class_NSUndoManager
_class_NSUndoManager: .asciz "NSUndoManager"
.section __DATA,__data
.p2align 3
.globl _sel_setKeyMask, _sel_redo
_sel_setKeyMask: .quad shortcut_keyMask
_sel_redo: .quad shortcut_redo
.globl _sel_setAllowsUndo
_sel_setAllowsUndo: .quad shortcut_allowsUndo
.globl _sel_windowUndo, _sel_undoManager, _sel_removeUndoActions
_sel_windowUndo: .quad shortcut_windowUndo
.globl _sel_textUndo
_sel_textUndo: .quad shortcut_textUndo
_sel_undoManager: .quad shortcut_undoManager
_sel_removeUndoActions: .quad shortcut_removeUndoActions


.section __TEXT,__cstring,cstring_literals
address_scrollable: .asciz "setScrollable:"
address_wraps: .asciz "setWraps:"
address_lineBreak: .asciz "setLineBreakMode:"
address_maxLines: .asciz "setMaximumNumberOfLines:"
.section __DATA,__data
.p2align 3
.globl _sel_setScrollable, _sel_setWraps, _sel_setLineBreak, _sel_setMaximumLines
_sel_setScrollable: .quad address_scrollable
_sel_setWraps: .quad address_wraps
_sel_setLineBreak: .quad address_lineBreak
_sel_setMaximumLines: .quad address_maxLines

selector_end:
selectors_ready: .quad 0
.text
.p2align 2
.globl _mac_init_selectors
_mac_init_selectors:
    ENTER
    LOAD x0, selectors_ready
    cbnz x0, Lselectors_done
    ADDR x19, _sel_new
    ADDR x20, selector_end
Lselector_next:
    cmp x19, x20
    b.hs Lselector_finished
    ldr x0, [x19]
    bl _sel_registerName
    str x0, [x19], #8
    b Lselector_next
Lselector_finished:
    mov x0, #1
    STORE x0, selectors_ready
Lselectors_done:
    LEAVE
