// Two-bit class Bloom filter. Negatives skip repeated class-list scans; positives
// still use the exact escaped-identifier matcher, so collisions change no styles.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _css_class_filter_build
_css_class_filter_build:
    str xzr, [x0, #1600]
    str xzr, [x0, #1608]
    str xzr, [x0, #1616]
    str xzr, [x0, #1624]
    mov x9, #1
    str x9, [x0, #1632]
    ldr x1, [x0, #8]
    cbz x1, Lclass_build_done
Lclass_build_next:
    ldrb w2, [x1]
    cbz w2, Lclass_build_done
    cmp w2, #32
    b.hi Lclass_build_start
    add x1, x1, #1
    b Lclass_build_next
Lclass_build_start:
    mov x3, #5381
Lclass_build_byte:
    ldrb w2, [x1]
    cbz w2, Lclass_build_store
    cmp w2, #32
    b.ls Lclass_build_store
    add x4, x3, x3, lsl #5
    eor x3, x4, x2
    add x1, x1, #1
    b Lclass_build_byte
Lclass_build_store:
    and x4, x3, #255
    lsr x5, x4, #6
    add x6, x0, #1600
    ldr x7, [x6, x5, lsl #3]
    mov x8, #1
    lsl x8, x8, x4
    orr x7, x7, x8
    str x7, [x6, x5, lsl #3]
    ubfx x4, x3, #8, #8
    lsr x5, x4, #6
    ldr x7, [x6, x5, lsl #3]
    mov x8, #1
    lsl x8, x8, x4
    orr x7, x7, x8
    str x7, [x6, x5, lsl #3]
    b Lclass_build_next
Lclass_build_done:
    ret

.globl _css_class_filter_maybe
_css_class_filter_maybe:
    ldr x9, [x0, #1632]
    cbz x9, Lclass_maybe_yes
    mov x3, #5381
Lclass_hash_byte:
    cmp x1, x2
    b.hs Lclass_hash_test
    ldrb w4, [x1], #1
    cmp w4, #92
    b.ne Lclass_hash_add
    cmp x1, x2
    b.hs Lclass_maybe_no
    ldrb w4, [x1], #1
Lclass_hash_add:
    add x5, x3, x3, lsl #5
    eor x3, x5, x4
    b Lclass_hash_byte
Lclass_hash_test:
    add x9, x0, #1600
    and x4, x3, #255
    lsr x5, x4, #6
    ldr x6, [x9, x5, lsl #3]
    mov x7, #1
    lsl x7, x7, x4
    tst x6, x7
    b.eq Lclass_maybe_no
    ubfx x4, x3, #8, #8
    lsr x5, x4, #6
    ldr x6, [x9, x5, lsl #3]
    mov x7, #1
    lsl x7, x7, x4
    tst x6, x7
    b.eq Lclass_maybe_no
Lclass_maybe_yes:
    mov x0, #1
    ret
Lclass_maybe_no:
    mov x0, #0
    ret
