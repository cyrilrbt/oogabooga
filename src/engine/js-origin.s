// Conservative HTTP(S) origin equality for script-readable requests. Resolve
// relative URLs with the native URL parser first. Credentials are never allowed.
.include "src/mac/mac.inc"
.text
// URL -> host pointer,length,scheme(1 http/2 https),effective port; scheme 0 bad.
js_origin_parts:
    ENTER
    mov x19, x0
    bl _strlen
    cmp x0, #7
    b.lo Ljs_origin_bad
    mov x20, x0
    mov x0, x19
    ADDR x1, js_origin_http
    mov x2, #7
    bl _strncasecmp
    cbz x0, Ljs_origin_plain
    cmp x20, #8
    b.lo Ljs_origin_bad
    mov x0, x19
    ADDR x1, js_origin_https
    mov x2, #8
    bl _strncasecmp
    cbnz x0, Ljs_origin_bad
    add x20, x19, #8
    mov x21, #2
    mov x22, #443
    b Ljs_origin_host
Ljs_origin_plain:
    add x20, x19, #7
    mov x21, #1
    mov x22, #80
Ljs_origin_host:
    mov x23, x20
    mov x24, #0
    ldrb w9, [x23]
    cmp w9, #91
    b.ne Ljs_origin_scan
    mov x24, #1
Ljs_origin_scan:
    ldrb w9, [x23]
    cbz w9, Ljs_origin_host_done
    cmp w9, #47
    b.eq Ljs_origin_host_done
    cmp w9, #63
    b.eq Ljs_origin_host_done
    cmp w9, #35
    b.eq Ljs_origin_host_done
    cmp w9, #32
    b.ls Ljs_origin_bad
    cmp w9, #64
    b.eq Ljs_origin_bad
    cmp w9, #37
    b.eq Ljs_origin_bad
    cmp w9, #92
    b.eq Ljs_origin_bad
    cmp w9, #93
    b.ne Ljs_origin_colon
    mov x24, #0
    b Ljs_origin_advance
Ljs_origin_colon:
    cmp w9, #58
    b.ne Ljs_origin_advance
    cbz x24, Ljs_origin_port
Ljs_origin_advance:
    add x23, x23, #1
    sub x9, x23, x20
    cmp x9, #1024
    b.hi Ljs_origin_bad
    b Ljs_origin_scan
Ljs_origin_port:
    sub x25, x23, x20
    add x23, x23, #1
    mov x22, #0
    mov x26, #0
Ljs_origin_port_digit:
    ldrb w9, [x23]
    cbz w9, Ljs_origin_port_done
    cmp w9, #47
    b.eq Ljs_origin_port_done
    cmp w9, #63
    b.eq Ljs_origin_port_done
    cmp w9, #35
    b.eq Ljs_origin_port_done
    sub w9, w9, #48
    cmp w9, #9
    b.hi Ljs_origin_bad
    mov x10, #10
    madd x22, x22, x10, x9
    mov x10, #65535
    cmp x22, x10
    b.hi Ljs_origin_bad
    add x26, x26, #1
    add x23, x23, #1
    b Ljs_origin_port_digit
Ljs_origin_port_done:
    cbz x26, Ljs_origin_bad
    b Ljs_origin_result
Ljs_origin_host_done:
    cbnz x24, Ljs_origin_bad
    sub x25, x23, x20
Ljs_origin_result:
    cbz x25, Ljs_origin_bad
    mov x0, x20
    mov x1, x25
    mov x2, x21
    mov x3, x22
    LEAVE
Ljs_origin_bad:
    mov x0, #0
    mov x1, #0
    mov x2, #0
    mov x3, #0
    LEAVE
.globl _engine_js_same_origin
_engine_js_same_origin:
    ENTER
    mov x19, x1
    bl js_origin_parts
    cbz x2, Ljs_origins_no
    mov x20, x0
    mov x21, x1
    mov x22, x2
    mov x23, x3
    mov x0, x19
    bl js_origin_parts
    cmp x2, x22
    b.ne Ljs_origins_no
    cmp x3, x23
    b.ne Ljs_origins_no
    cmp x1, x21
    b.ne Ljs_origins_no
    mov x1, x20
    mov x2, x21
    bl _strncasecmp
    cmp x0, #0
    cset x0, eq
    LEAVE
Ljs_origins_no:
    mov x0, #0
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_origin_http: .asciz "http://"
js_origin_https: .asciz "https://"
