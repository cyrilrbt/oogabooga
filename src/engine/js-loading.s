.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.include "src/engine/dom.inc"
.text
// vm,kind(1 classic script,2 fetch),url string,promise -> bounded request record.
.globl _js_request_new
_js_request_new:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x9, [x19, #JS_REQUEST_COUNT]
    cmp x9, #32
    b.hs Ljs_request_limit
    add x9, x9, #1
    str x9, [x19, #JS_REQUEST_COUNT]
    mov x1, #48
    bl _js_alloc
    cbz x0, Ljs_request_done
    stp x20, x21, [x0]
    str x22, [x0, #16]
    ldr x9, [x19, #JS_REQUEST_TAIL]
    cbz x9, Ljs_request_first
    str x0, [x9, #32]
    b Ljs_request_tail
Ljs_request_first:
    str x0, [x19, #JS_REQUEST_HEAD]
Ljs_request_tail:
    str x0, [x19, #JS_REQUEST_TAIL]
Ljs_request_done:
    LEAVE
Ljs_request_limit:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.globl _engine_js_request_next
_engine_js_request_next:
    ldr x9, [x0, #JS_REQUEST_HEAD]
    cbz x9, Ljs_request_next_done
    ldr x10, [x9, #32]
    str x10, [x0, #JS_REQUEST_HEAD]
    cbnz x10, Ljs_request_next_done
    str xzr, [x0, #JS_REQUEST_TAIL]
Ljs_request_next_done:
    mov x0, x9
    ret
.globl _js_fetch_new
_js_fetch_new:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _js_promise_new
    mov x23, x0
    cbz x0, Ljs_fetch_done
    cmp x21, #1
    b.ls Ljs_fetch_url
    cbnz x22, Ljs_fetch_unsupported
Ljs_fetch_url:
    mov x0, x19
    mov x1, x20
    bl _js_to_string
    mov x2, x0
    mov x0, x19
    mov x1, #2
    mov x3, x23
    bl _js_request_new
    b Ljs_fetch_done
Ljs_fetch_unsupported:
    mov x0, x19
    ADDR x1, js_fetch_policy
    bl _js_cstring
    mov x3, x0
    mov x0, x19
    mov x1, x23
    mov x2, #2
    bl _js_promise_settle
Ljs_fetch_done:
    mov x0, x23
    LEAVE
// vm,request,status,UTF8 body,length -> settle/execute once. Negative status
// means blocked/failed. Platform adapters validate origin and MIME before here.
.globl _engine_js_complete
_engine_js_complete:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    ldr x9, [x20, #24]
    cbnz x9, Ljs_complete_done
    mov x9, #1
    str x9, [x20, #24]
    mov x9, #0x86a0
    movk x9, #1, lsl #16
    str x9, [x19, #JS_FUEL]
    str xzr, [x19, #JS_ERROR]
    mov x9, #JS_MAX_SOURCE
    cmp x23, x9
    b.hi Ljs_complete_failed
    tbnz x21, #63, Ljs_complete_failed
    ldr x9, [x20]
    cmp x9, #1
    b.eq Ljs_complete_script
    mov x0, x19
    mov x1, x22
    mov x2, x23
    bl _js_string
    mov x24, x0
    mov x0, x19
    mov x1, #JS_RESPONSE
    bl _js_value
    cbz x0, Ljs_complete_failed
    stp x24, x21, [x0, #8]
    mov x3, x0
    mov x0, x19
    ldr x1, [x20, #16]
    mov x2, #1
    bl _js_promise_settle
    b Ljs_complete_done
Ljs_complete_script:
    cmp x21, #200
    b.lo Ljs_complete_failed
    cmp x21, #300
    b.hs Ljs_complete_failed
    mov x0, x19
    mov x1, x22
    mov x2, x23
    bl _engine_js_eval
    mov x0, x19
    bl _engine_js_start
    b Ljs_complete_done
Ljs_complete_failed:
    ldr x9, [x20]
    cmp x9, #1
    b.eq Ljs_complete_script_failed
    mov x0, x19
    ADDR x1, js_fetch_failed
    bl _js_cstring
    mov x3, x0
    mov x0, x19
    ldr x1, [x20, #16]
    mov x2, #2
    bl _js_promise_settle
    b Ljs_complete_done
Ljs_complete_script_failed:
    mov x0, x19
    ADDR x1, js_script_failed
    bl _js_cstring
    str x0, [x19, #JS_LAST_LOG]
    mov x0, x19
    bl _engine_js_start
Ljs_complete_done:
    LEAVE
// Collect post-parse classic scripts once, preserving source order. Script
// mutation cannot cause earlier scripts to run twice. Modules/async are later.
.globl _engine_js_prepare
_engine_js_prepare:
    ENTER
    mov x19, x0
    ldr x20, [x19, #JS_DOM]
    mov x21, #1
Ljs_csp_scan:
    mov x0, x20
    mov x1, x21
    bl _engine_dom_node
    cbz x0, Ljs_collect_begin
    ldr x9, [x0]
    cmp x9, #DOM_ELEMENT
    b.ne Ljs_csp_next
    ldr x0, [x0, #48]
    ADDR x1, js_script_meta
    bl _strcmp
    cbnz x0, Ljs_csp_next
    mov x0, x20
    mov x1, x21
    ADDR x2, js_script_http_equiv
    bl _engine_dom_get_attribute
    cbz x0, Ljs_csp_next
    ADDR x1, js_script_csp
    bl _strcasecmp
    cbz x0, Ljs_csp_blocked
Ljs_csp_next:
    mov x0, x20
    mov x1, x21
    bl _engine_dom_next
    mov x21, x0
    cbnz x21, Ljs_csp_scan
Ljs_collect_begin:
    mov x21, #1
    mov x22, #0
Ljs_collect_node:
    mov x0, x20
    mov x1, x21
    bl _engine_dom_node
    cbz x0, Ljs_collected
    mov x23, x0
    ldr x9, [x23]
    cmp x9, #DOM_ELEMENT
    b.ne Ljs_collect_next
    // Compile inline event attributes as functions with a scoped event argument.
    ldr x24, [x23, #64]
Ljs_collect_handler:
    cbz x24, Ljs_collect_script_test
    ldr x9, [x24]
    ldrb w10, [x9]
    cmp w10, #111
    b.ne Ljs_collect_handler_next
    ldrb w10, [x9, #1]
    cmp w10, #110
    b.ne Ljs_collect_handler_next
    mov x0, x19
    mov x1, x21
    add x2, x9, #2
    ldr x3, [x24, #8]
    bl _js_inline_handler
Ljs_collect_handler_next:
    ldr x24, [x24, #16]
    b Ljs_collect_handler
Ljs_collect_script_test:
    ldr x0, [x23, #48]
    ADDR x1, js_script_tag
    bl _strcmp
    cbnz x0, Ljs_collect_next
    mov x0, x20
    mov x1, x21
    ADDR x2, js_script_type
    bl _engine_dom_get_attribute
    cbz x0, Ljs_collect_classic
    ldrb w9, [x0]
    cbz w9, Ljs_collect_classic
    mov x25, x0
    ADDR x1, js_script_mime
    bl _strcasecmp
    cbz x0, Ljs_collect_classic
    mov x0, x25
    ADDR x1, js_script_mime_alt
    bl _strcasecmp
    cbnz x0, Ljs_collect_next
Ljs_collect_classic:
    mov x0, x19
    mov x1, #32
    bl _js_alloc
    cbz x0, Ljs_collected
    mov x24, x0
    str x21, [x24, #16]
    cbz x22, Ljs_collect_first
    str x24, [x22, #24]
    b Ljs_collect_linked
Ljs_collect_first:
    str x24, [x19, #JS_SCRIPT_CURSOR]
Ljs_collect_linked:
    mov x22, x24
    mov x0, x20
    mov x1, x21
    ADDR x2, js_script_src
    bl _engine_dom_get_attribute
    cbz x0, Ljs_collect_inline
    mov x1, x0
    mov x0, x19
    bl _js_cstring
    mov x9, #2
    stp x9, x0, [x24]
    b Ljs_collect_next
Ljs_collect_inline:
    mov x0, x19
    mov x1, x21
    bl _js_dom_text
    mov x9, #1
    stp x9, x0, [x24]
Ljs_collect_next:
    mov x0, x20
    mov x1, x21
    bl _engine_dom_next
    mov x21, x0
    cbnz x21, Ljs_collect_node
Ljs_collected:
    mov x0, #1
    LEAVE
Ljs_csp_blocked:
    mov x9, #5
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
.globl _engine_js_start
_engine_js_start:
    ENTER
    mov x19, x0
Ljs_start_next:
    ldr x20, [x19, #JS_SCRIPT_CURSOR]
    cbz x20, Ljs_start_ready
    ldr x9, [x20, #24]
    str x9, [x19, #JS_SCRIPT_CURSOR]
    ldr x9, [x20]
    ldr x21, [x20, #8]
    cmp x9, #2
    b.eq Ljs_start_external
    cbz x21, Ljs_start_next
    mov x0, x19
    ldr x1, [x21, #8]
    ldr x2, [x21, #16]
    bl _engine_js_eval
    b Ljs_start_next
Ljs_start_external:
    mov x0, x19
    mov x1, #1
    mov x2, x21
    mov x3, #0
    bl _js_request_new
    LEAVE
Ljs_start_ready:
    ldr x9, [x19, #JS_READY]
    cmp x9, #2
    b.eq Ljs_started
    mov x9, #2
    str x9, [x19, #JS_READY]
    mov x0, x19
    mov x1, #1
    ADDR x2, js_script_ready_event
    bl _engine_js_event
Ljs_started:
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_fetch_policy: .asciz "Only same-origin GET fetch is supported"
js_fetch_failed: .asciz "Request failed or was blocked by origin policy"
js_script_failed: .asciz "External script failed or was blocked"
js_script_tag: .asciz "script"
js_script_type: .asciz "type"
js_script_src: .asciz "src"
js_script_mime: .asciz "text/javascript"
js_script_mime_alt: .asciz "application/javascript"
js_script_ready_event: .asciz "DOMContentLoaded"
js_script_meta: .asciz "meta"
js_script_http_equiv: .asciz "http-equiv"
js_script_csp: .asciz "Content-Security-Policy"
