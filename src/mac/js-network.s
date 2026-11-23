// Bounded, same-origin NSURLSession streaming transport, main queue only.
.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.text
.globl _mac_js_network_reset
_mac_js_network_reset:
    ENTER
    LOAD x0, mj_session
    MSG jsInvalidateCancel
    LOAD x0, mj_session
    MSG release
    STORE xzr, mj_session
    LEAVE
// Linked records remain alive until cancellation completion, independent of VM.
// next0 task8 data16 generation24 VM32 request40 status48 failed56.
mj_find:
    LOAD x9, mj_jobs
Lmj_find_next:
    cbz x9, Lmj_find_done
    ldr x10, [x9, #8]
    cmp x10, x0
    b.eq Lmj_find_done
    ldr x9, [x9]
    b Lmj_find_next
Lmj_find_done:
    mov x0, x9
    ret
mj_session_get:
    ENTER
    LOAD x0, mj_session
    cbnz x0, Lmj_session_done
    ADDR x0, mj_class_name
    bl _objc_getClass
    cbnz x0, Lmj_class_exists
    CLASS NSObject
    ADDR x1, mj_class_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    ADDR x20, mj_methods
Lmj_add_method:
    ldr x9, [x20]
    cbz x9, Lmj_class_register
    ldr x1, [x9]
    ldr x2, [x20, #8]
    ldr x3, [x20, #16]
    mov x0, x19
    bl _class_addMethod
    add x20, x20, #24
    b Lmj_add_method
Lmj_class_register:
    mov x0, x19
    bl _objc_registerClassPair
    mov x0, x19
Lmj_class_exists:
    MSG new
    mov x19, x0
    LOAD x0, _engine_session
    MSG jsConfiguration
    mov x20, x0
    cbnz x20, Lmj_configuration
    CLASS NSURLSessionConfiguration
    MSG ephemeralConfiguration
    mov x20, x0
Lmj_configuration:
    CLASS NSOperationQueue
    MSG mainQueue
    mov x21, x0
    CLASS NSURLSession
    mov x4, x21
    mov x2, x20
    mov x3, x19
    MSG sessionWithConfiguration
    MSG retain
    STORE x0, mj_session
    mov x20, x0
    mov x0, x19
    MSG release
    mov x0, x20
Lmj_session_done:
    LEAVE
.globl _mac_js_requests
_mac_js_requests:
    ENTER
Lmj_request_next:
    LOAD x19, _mac_js_vm
    cbz x19, Lmj_requests_done
    mov x0, x19
    bl _engine_js_request_next
    cbz x0, Lmj_requests_done
    mov x20, x0
    ldr x9, [x20, #8]
    cbz x9, Lmj_request_block
    ldr x0, [x9, #8]
    bl _mac_string
    mov x21, x0
    CLASS NSURL
    mov x2, x21
    LOAD x3, _engine_render_base
    MSG jsURLRelative
    MSG jsAbsoluteURL
    mov x21, x0
    cbz x21, Lmj_request_block
    MSG absoluteString
    MSG UTF8String
    mov x22, x0
    LOAD x0, _engine_url
    MSG absoluteString
    MSG UTF8String
    mov x1, x22
    bl _engine_js_same_origin
    cbz x0, Lmj_request_block
    CLASS NSMutableURLRequest
    mov x2, x21
    MSG requestWithURL
    mov x21, x0
    mov x9, #10
    scvtf d0, x9
    MSG jsTimeout
    bl mj_session_get
    mov x2, x21
    MSG dataTask
    MSG retain
    mov x21, x0
    mov x0, #1
    mov x1, #64
    bl _calloc
    cbz x0, Lmj_request_task_fail
    mov x22, x0
    LOAD x9, mj_jobs
    str x9, [x22]
    STORE x22, mj_jobs
    str x21, [x22, #8]
    LOAD x9, _mac_js_generation
    str x9, [x22, #24]
    str x19, [x22, #32]
    str x20, [x22, #40]
    CLASS NSMutableData
    MSG new
    str x0, [x22, #16]
    mov x0, x21
    MSG resume
    b Lmj_request_next
Lmj_request_task_fail:
    mov x0, x21
    MSG cancel
    mov x0, x21
    MSG release
Lmj_request_block:
    mov x0, x19
    mov x1, x20
    mov x2, #-1
    mov x3, #0
    mov x4, #0
    bl _engine_js_complete
    b Lmj_request_next
Lmj_requests_done:
    LEAVE
// Response callback must always invoke its disposition block exactly once.
_mac_js_response:
    ENTER
    mov x19, x5
    mov x20, x4
    mov x0, x3
    bl mj_find
    cbz x0, Lmj_response_no
    mov x21, x0
    ldr x9, [x21, #24]
    LOAD x10, _mac_js_generation
    cmp x9, x10
    b.ne Lmj_response_no
    mov x0, x20
    MSG expectedLength
    cmp x0, #0
    b.lt Lmj_response_status
    mov x9, #65536
    cmp x0, x9
    b.hi Lmj_response_fail
Lmj_response_status:
    mov x0, x20
    MSG statusCode
    str x0, [x21, #48]
    cmp x0, #300
    b.lt Lmj_response_mime
    cmp x0, #400
    b.lt Lmj_response_fail
Lmj_response_mime:
    ldr x9, [x21, #40]
    ldr x9, [x9]
    cmp x9, #1
    b.ne Lmj_response_yes
    mov x0, x20
    MSG MIMEType
    MSG UTF8String
    cbz x0, Lmj_response_fail
    mov x22, x0
    ADDR x1, mj_mime
    bl _strcasecmp
    cbz x0, Lmj_response_yes
    mov x0, x22
    ADDR x1, mj_mime_alt
    bl _strcasecmp
    cbnz x0, Lmj_response_fail
Lmj_response_yes:
    mov x1, #1
    b Lmj_response_call
Lmj_response_fail:
    mov x9, #1
    str x9, [x21, #56]
Lmj_response_no:
    mov x1, #0
Lmj_response_call:
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    LEAVE
_mac_js_data:
    ENTER
    mov x19, x4
    mov x0, x3
    bl mj_find
    cbz x0, Lmj_data_done
    mov x20, x0
    ldr x9, [x20, #24]
    LOAD x10, _mac_js_generation
    cmp x9, x10
    b.ne Lmj_data_done
    ldr x9, [x20, #56]
    cbnz x9, Lmj_data_done
    mov x0, x19
    MSG length
    mov x21, x0
    ldr x0, [x20, #16]
    MSG length
    add x0, x0, x21
    mov x9, #65536
    cmp x0, x9
    b.hi Lmj_data_limit
    ldr x0, [x20, #16]
    mov x2, x19
    MSG appendData
    b Lmj_data_done
Lmj_data_limit:
    mov x9, #1
    str x9, [x20, #56]
    ldr x0, [x20, #8]
    MSG cancel
Lmj_data_done:
    LEAVE
_mac_js_complete:
    ENTER
    mov x19, x4
    mov x0, x3
    bl mj_find
    cbz x0, Lmj_complete_done
    mov x20, x0
    ldr x9, [x20, #24]
    LOAD x10, _mac_js_generation
    cmp x9, x10
    b.ne Lmj_complete_free
    cbnz x19, Lmj_complete_failed
    ldr x9, [x20, #56]
    cbnz x9, Lmj_complete_failed
    CLASS NSString
    MSG alloc
    ldr x2, [x20, #16]
    mov x3, #4
    MSG initDataEncoding
    mov x21, x0
    cbz x21, Lmj_complete_failed
    MSG UTF8String
    mov x22, x0
    bl _strlen
    mov x4, x0
    ldr x0, [x20, #32]
    ldr x1, [x20, #40]
    ldr x2, [x20, #48]
    mov x3, x22
    bl _engine_js_complete
    mov x0, x21
    MSG release
    b Lmj_complete_flush
Lmj_complete_failed:
    ldr x0, [x20, #32]
    ldr x1, [x20, #40]
    mov x2, #-1
    mov x3, #0
    mov x4, #0
    bl _engine_js_complete
Lmj_complete_flush:
    bl _mac_js_flush
    bl _mac_js_requests
Lmj_complete_free:
    ADDR x21, mj_jobs
Lmj_unlink:
    ldr x9, [x21]
    cbz x9, Lmj_unlinked
    cmp x9, x20
    b.eq Lmj_unlink_found
    mov x21, x9
    b Lmj_unlink
Lmj_unlink_found:
    ldr x9, [x20]
    str x9, [x21]
Lmj_unlinked:
    ldr x0, [x20, #8]
    MSG release
    ldr x0, [x20, #16]
    MSG release
    mov x0, x20
    bl _free
Lmj_complete_done:
    LEAVE
_mac_js_redirect:
    ENTER
    mov x0, x6
    mov x1, #0
    ldr x8, [x6, #16]
    blr x8
    LEAVE
.section __DATA,__bss
.p2align 3
mj_session: .space 8
mj_jobs: .space 8
.section __TEXT,__cstring,cstring_literals
mj_class_name: .asciz "OogaScriptTransport"
mj_encoding_response: .asciz "v@:@@@@?"
mj_encoding_data: .asciz "v@:@@@"
mj_encoding_redirect: .asciz "v@:@@@@@?"
mj_configuration: .asciz "configuration"
mj_invalidate: .asciz "invalidateAndCancel"
mj_relative: .asciz "URLWithString:relativeToURL:"
mj_absolute: .asciz "absoluteURL"
mj_header: .asciz "valueForHTTPHeaderField:"
mj_timeout: .asciz "setTimeoutInterval:"
mj_mime: .asciz "text/javascript"
mj_mime_alt: .asciz "application/javascript"
.section __DATA,__data
.p2align 3
.globl _sel_jsConfiguration,_sel_jsInvalidateCancel,_sel_jsURLRelative,_sel_jsAbsoluteURL,_sel_jsTimeout
_sel_jsConfiguration: .quad mj_configuration
_sel_jsInvalidateCancel: .quad mj_invalidate
_sel_jsURLRelative: .quad mj_relative
_sel_jsAbsoluteURL: .quad mj_absolute
_sel_jsTimeout: .quad mj_timeout
mj_methods:
.quad _sel_engineResponse,_mac_js_response,mj_encoding_response
.quad _sel_engineData,_mac_js_data,mj_encoding_data
.quad _sel_engineComplete,_mac_js_complete,mj_encoding_data
.quad _sel_engineRedirect,_mac_js_redirect,mj_encoding_redirect
.quad 0,0,0

.globl _sel_jsHeader
_sel_jsHeader: .quad mj_header
