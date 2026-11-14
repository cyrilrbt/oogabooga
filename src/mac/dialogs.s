// App-modal dialogs keep completion-block lifetimes bounded to the delegate call.
// WebKit owns each incoming block until we invoke it exactly once. We neither
// fabricate stack blocks nor retain captures; invoke pointer is at block offset 16.
.include "src/mac/mac.inc"
.text
.p2align 2
// NSAlert *mac_alert(title, message, primaryButtonTitle, cancellable), owned (+1).
.globl _mac_alert
_mac_alert:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    CLASS NSAlert
    MSG new
    mov x23, x0
    mov x2, x19
    MSG setMessage
    mov x0, x23
    mov x2, x20
    MSG setInformativeText
    mov x0, x23
    mov x2, x21
    MSG addButton
    cbz x22, Lalert_created
    STR cancel_text
    mov x2, x0
    mov x0, x23
    MSG addButton
Lalert_created:
    mov x0, x23
    LEAVE

// x0 WKFrameInfo, x1 message. Returns alert title from origin host, or "Page".
_mac_origin:
    ENTER
    MSG request
    MSG URL
    MSG host
    cbnz x0, Lorigin_done
    STR page_text
Lorigin_done:
    LEAVE

.globl _mac_js_alert
_mac_js_alert:
    ENTER
    mov x19, x5
    mov x20, x3
    mov x0, x4
    bl _mac_origin
    mov x21, x0
    STR ok_text
    mov x2, x0
    mov x0, x21
    mov x1, x20
    mov x3, #0
    bl _mac_alert
    mov x20, x0
    MSG runModal
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    mov x0, x20
    MSG release
    LEAVE

.globl _mac_js_confirm
_mac_js_confirm:
    ENTER
    mov x19, x5
    mov x20, x3
    mov x0, x4
    bl _mac_origin
    mov x21, x0
    STR ok_text
    mov x2, x0
    mov x0, x21
    mov x1, x20
    mov x3, #1
    bl _mac_alert
    mov x20, x0
    MSG runModal
    cmp x0, #1000
    cset w1, eq
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    mov x0, x20
    MSG release
    LEAVE

.globl _mac_js_prompt
_mac_js_prompt:
    ENTER
    mov x19, x6
    mov x20, x3
    mov x21, x4
    mov x0, x5
    bl _mac_origin
    mov x22, x0
    STR ok_text
    mov x2, x0
    mov x0, x22
    mov x1, x20
    mov x3, #1
    bl _mac_alert
    mov x20, x0
    CLASS NSTextField
    MSG alloc
    RECT 0, 0, 300, 24
    MSG initFrame
    mov x22, x0
    cbnz x21, Lprompt_text
    STR empty_text
    mov x21, x0
Lprompt_text:
    mov x0, x22
    mov x2, x21
    MSG setStringValue
    mov x0, x20
    mov x2, x22
    MSG setAccessoryView
    mov x0, x20
    MSG window
    mov x2, x22
    MSG setInitialFirstResponder
    mov x0, x20
    MSG runModal
    cmp x0, #1000
    b.ne Lprompt_cancel
    mov x0, x22
    MSG stringValue
    mov x1, x0
    b Lprompt_complete
Lprompt_cancel:
    mov x1, #0
Lprompt_complete:
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    mov x0, x22
    MSG release
    mov x0, x20
    MSG release
    LEAVE

// Authentication retains the system default handling for server trust/client certs.
.globl _mac_authenticate
_mac_authenticate:
    ENTER
    mov x19, x4                      // completion block
    mov x20, x3                      // challenge
    mov x0, x20
    MSG protectionSpace
    mov x21, x0
    MSG authenticationMethod
    mov x22, x0
    adrp x9, _NSURLAuthenticationMethodHTTPBasic@GOTPAGE
    ldr x9, [x9, _NSURLAuthenticationMethodHTTPBasic@GOTPAGEOFF]
    ldr x2, [x9]
    MSG equal
    cbnz w0, Lauth_prompt
    mov x0, x22
    adrp x9, _NSURLAuthenticationMethodHTTPDigest@GOTPAGE
    ldr x9, [x9, _NSURLAuthenticationMethodHTTPDigest@GOTPAGEOFF]
    ldr x2, [x9]
    MSG equal
    cbnz w0, Lauth_prompt
    mov x0, x22
    adrp x9, _NSURLAuthenticationMethodNTLM@GOTPAGE
    ldr x9, [x9, _NSURLAuthenticationMethodNTLM@GOTPAGEOFF]
    ldr x2, [x9]
    MSG equal
    cbnz w0, Lauth_prompt
    mov x1, #1                       // NSURLSessionAuthChallengePerformDefaultHandling
    mov x2, #0
    b Lauth_complete
Lauth_prompt:
    mov x0, x20
    MSG previousFailureCount
    cmp x0, #3
    b.ge Lauth_cancel
    mov x22, x0
    mov x0, x21
    MSG protocol
    mov x23, x0
    mov x0, x21
    MSG host
    mov x24, x0
    cbnz x22, Lauth_retry
    STR enter_text
    b Lauth_message
Lauth_retry:
    STR retry_text
Lauth_message:
    mov x25, x0
    STR auth_format
    mov x26, x0
    CLASS NSString
    mov x2, x26
    // Darwin ARM64 variadic arguments go on the stack, not in x3-x7.
    stp x23, x24, [sp]
    str x25, [sp, #16]
    MSG stringFormat
    mov x22, x0
    STR sign_in_text
    mov x23, x0
    mov x0, x23
    mov x1, x22
    mov x2, x23
    mov x3, #1
    bl _mac_alert
    mov x22, x0
    CLASS NSView
    MSG alloc
    RECT 0, 0, 300, 64
    MSG initFrame
    mov x23, x0
    CLASS NSTextField
    MSG alloc
    RECT 0, 36, 300, 24
    MSG initFrame
    mov x24, x0
    STR username_text
    mov x2, x0
    mov x0, x24
    MSG setPlaceholder
    CLASS NSSecureTextField
    MSG alloc
    RECT 0, 0, 300, 24
    MSG initFrame
    mov x25, x0
    STR password_text
    mov x2, x0
    mov x0, x25
    MSG setPlaceholder
    mov x0, x24
    mov x2, x25
    MSG setNextKeyView
    mov x0, x25
    mov x2, x24
    MSG setNextKeyView
    mov x0, x23
    mov x2, x24
    MSG addSubview
    mov x0, x23
    mov x2, x25
    MSG addSubview
    mov x0, x22
    mov x2, x23
    MSG setAccessoryView
    mov x0, x22
    MSG window
    mov x2, x24
    MSG setInitialFirstResponder
    mov x0, x22
    MSG runModal
    mov x26, x0
    cmp x26, #1000
    b.ne Lauth_release_cancel
    mov x0, x24
    MSG stringValue
    mov x27, x0
    mov x0, x25
    MSG stringValue
    mov x28, x0
    CLASS NSURLCredential
    mov x2, x27
    mov x3, x28
    mov x4, #1                       // NSURLCredentialPersistenceForSession
    MSG credential
    mov x20, x0
    b Lauth_release
Lauth_release_cancel:
    mov x20, #0
Lauth_release:
    // Complete while all credential/dialog objects are still valid.
    mov x0, x19
    ldr x8, [x19, #16]
    mov x1, #2                       // cancel
    cmp x26, #1000
    csel x1, xzr, x1, eq             // use credential = 0
    mov x2, x20
    blr x8
    mov x0, x24
    MSG release
    mov x0, x25
    MSG release
    mov x0, x23
    MSG release
    mov x0, x22
    MSG release
    LEAVE
Lauth_cancel:
    mov x1, #2
    mov x2, #0
Lauth_complete:
    mov x0, x19
    ldr x8, [x19, #16]
    blr x8
    LEAVE
.section __TEXT,__cstring,cstring_literals
ok_text: .asciz "OK"
cancel_text: .asciz "Cancel"
page_text: .asciz "Page"
empty_text: .asciz ""
sign_in_text: .asciz "Sign In"
enter_text: .asciz "Enter your username and password."
retry_text: .asciz "Credentials were rejected. Try again."
auth_format: .asciz "%@://%@\n%@"
username_text: .asciz "Username"
password_text: .asciz "Password"
