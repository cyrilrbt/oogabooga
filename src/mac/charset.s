// HTTP charset -> normalized UTF-8. Foundation supplies the maintained codecs;
// charset selection and ownership are controlled here in handwritten ARM64.
.include "src/mac/mac.inc"
.text
.p2align 2
// NSData *mac_engine_decode(NSData *data, NSString *HTTPCharset), owned (+1).
// Missing charset defaults to UTF-8; unknown/invalid declarations fail explicitly.
.globl _mac_engine_decode
_mac_engine_decode:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, #4                       // NSUTF8StringEncoding
    cbz x20, Ldecode_string
    mov x0, x20
    MSG length
    cbz x0, Ldecode_string
    mov x0, x20
    bl _CFStringConvertIANACharSetNameToEncoding
    cmn w0, #1
    b.eq Ldecode_fail
    // HTML aliases ISO-8859-1 and ASCII to Windows-1252, including C1 punctuation.
    cmp w0, #0x201                   // kCFStringEncodingISOLatin1
    b.eq Ldecode_windows
    cmp w0, #0x600                   // kCFStringEncodingASCII
    b.eq Ldecode_windows
    bl _CFStringConvertEncodingToNSStringEncoding
    mov x21, x0
    b Ldecode_string
Ldecode_windows:
    mov x21, #12                     // NSWindowsCP1252StringEncoding
Ldecode_string:
    CLASS NSString
    MSG alloc
    mov x2, x19
    mov x3, x21
    MSG initDataEncoding
    cbz x0, Ldecode_fail
    mov x20, x0
    mov x2, #4
    MSG dataUsingEncoding
    MSG retain
    mov x21, x0
    mov x0, x20
    MSG release
    mov x0, x21
    LEAVE
Ldecode_fail:
    mov x0, #0
    LEAVE
