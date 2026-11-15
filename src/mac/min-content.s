// Native shaping measures word advances; assembly chooses break opportunities
// and the largest unbreakable run. No HTML/CSS importer is used.
.include "src/mac/mac.inc"
.text
.p2align 2
// NSString, font attributes -> minimum content width, rounded outwards.
.globl _mac_min_content
_mac_min_content:
    ENTER
    mov x19, x0
    mov x20, x1
    MSG length
    mov x21, x0
    mov x22, #0
    mov x23, #0
    mov x24, #0
Lmin_scan:
    cmp x22, x21
    b.hs Lmin_tail
    mov x0, x19
    mov x2, x22
    MSG characterAtIndex
    cmp x0, #32
    b.ls Lmin_separator
    mov x9, #0x200b
    cmp x0, x9
    b.eq Lmin_separator
    cmp x0, #45                    // hyphen is retained in its preceding run
    b.ne Lmin_next
    add x25, x22, #1
    bl min_measure_run
    add x22, x22, #1
    mov x23, x22
    b Lmin_scan
Lmin_separator:
    mov x25, x22
    bl min_measure_run
    add x22, x22, #1
    mov x23, x22
    b Lmin_scan
Lmin_next:
    add x22, x22, #1
    b Lmin_scan
Lmin_tail:
    mov x25, x21
    bl min_measure_run
    mov x0, x24
    LEAVE
min_measure_run:
    stp x29, x30, [sp, #-16]!
    cmp x25, x23
    b.ls Lmin_run_done
    mov x0, x19
    mov x2, x23
    sub x3, x25, x23
    MSG intrinsicSubstring
    mov x2, x20
    MSG sizeAttributes
    fcvtps x9, d0
    cmp x9, x24
    csel x24, x9, x24, gt
Lmin_run_done:
    ldp x29, x30, [sp], #16
    ret
