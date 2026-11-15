// Preserve source whitespace in the flow snapshot; choose CSS behavior only
// after cascade. Parser-inserted block boundaries have mode zero and stay apart.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.text
.p2align 2
// document, zeroed length+1 byte array. 1=normal,2=pre,3=nowrap,4=pre-wrap,
// 5=pre-line,6=break-spaces. Each text byte belongs to one non-overlapping run.
.globl _engine_whitespace_modes
_engine_whitespace_modes:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #16]
    ldr x22, [x19, #24]
    ldr x23, [x19, #72]
    mov x24, #0
Lwhitespace_run:
    cmp x24, x22
    b.hs Lwhitespace_done
    mov x9, #40
    madd x9, x24, x9, x21
    ldr x10, [x9]
    cmp x10, #NODE_TEXT
    b.ne Lwhitespace_next
    ldp x25, x26, [x9, #16]
    ldr x10, [x19, #8]
    cmp x26, x10
    b.hi Lwhitespace_next
    cmp x25, x26
    b.hs Lwhitespace_next
    add x9, x23, x24, lsl #11
    ldr x1, [x9, #888]
    add x1, x1, #1
    add x0, x20, x25
    sub x2, x26, x25
    bl _memset
Lwhitespace_next:
    add x24, x24, #1
    b Lwhitespace_run
Lwhitespace_done:
    LEAVE
