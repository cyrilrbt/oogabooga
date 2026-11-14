// Address interpretation is handwritten assembly; Foundation owns Unicode and URL parsing.
.include "src/mac/mac.inc"
.text
.p2align 2
// NSURL *mac_destination(NSString *input), autoreleased (+0).
.globl _mac_destination
_mac_destination:
    ENTER
    mov x19, x0
    CLASS NSCharacterSet
    MSG whitespace
    mov x2, x0
    mov x0, x19
    MSG trim
    mov x19, x0
    MSG length
    cbz x0, Lurl_nil
    STR scheme_marker
    mov x2, x0
    mov x0, x19
    MSG contains
    cbnz w0, Lurl_parse
    // Explicit schemes such as javascript:, data:, and file: are never searched/executed.
    // A colon without :// can still be a hostname port or an IPv6 literal.
    STR space_text
    mov x2, x0
    mov x0, x19
    MSG contains
    cbnz w0, Lurl_search
    STR dot_text
    mov x2, x0
    mov x0, x19
    MSG contains
    cbnz w0, Lurl_host
    STR localhost_text
    mov x2, x0
    mov x0, x19
    MSG hasPrefix
    cbnz w0, Lurl_host
    STR bracket_text
    mov x2, x0
    mov x0, x19
    MSG hasPrefix
    cbz w0, Lurl_search
Lurl_host:
    STR localhost_text
    mov x2, x0
    mov x0, x19
    MSG hasPrefix
    cbnz w0, Lurl_http
    STR loopback_text
    mov x2, x0
    mov x0, x19
    MSG hasPrefix
    cbnz w0, Lurl_http
    STR ipv6_text
    mov x2, x0
    mov x0, x19
    MSG hasPrefix
    cbnz w0, Lurl_http
    STR https_text
    b Lurl_prefix
Lurl_http:
    STR http_text
Lurl_prefix:
    mov x2, x19
    MSG append
    mov x19, x0
Lurl_parse:
    CLASS NSURL
    mov x2, x19
    MSG URLWithString
    mov x20, x0
    cbz x0, Lurl_nil
    MSG host
    MSG length
    cbz x0, Lurl_nil
    mov x0, x20
    MSG scheme
    bl _mac_allowed_scheme
    cbz w0, Lurl_nil
    mov x0, x20
    LEAVE
Lurl_search:
    CLASS NSURLComponents
    mov x20, x0
    STR search_text
    mov x2, x0
    mov x0, x20
    MSG components
    mov x20, x0
    CLASS NSURLQueryItem
    mov x21, x0
    STR query_text
    mov x2, x0
    mov x3, x19
    mov x0, x21
    MSG queryItem
    mov x19, x0
    CLASS NSArray
    mov x2, x19
    MSG arrayObject
    mov x2, x0
    mov x0, x20
    MSG setQueryItems
    mov x0, x20
    MSG URL
    LEAVE
Lurl_nil:
    mov x0, #0
    LEAVE

// BOOL mac_allowed_scheme(NSString *scheme): HTTP(S) only, case insensitive.
.globl _mac_allowed_scheme
_mac_allowed_scheme:
    ENTER
    MSG lowercase
    mov x19, x0
    STR http_scheme
    mov x2, x0
    mov x0, x19
    MSG equal
    cbnz w0, Lscheme_done
    STR https_scheme
    mov x2, x0
    mov x0, x19
    MSG equal
Lscheme_done:
    LEAVE

.section __TEXT,__cstring,cstring_literals
scheme_marker: .asciz "://"
space_text: .asciz " "
dot_text: .asciz "."
bracket_text: .asciz "["
localhost_text: .asciz "localhost"
loopback_text: .asciz "127."
ipv6_text: .asciz "[::1]"
http_text: .asciz "http://"
https_text: .asciz "https://"
http_scheme: .asciz "http"
https_scheme: .asciz "https"
search_text: .asciz "https://duckduckgo.com/"
query_text: .asciz "q"
