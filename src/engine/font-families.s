// Loaded web-family aliases are page-scoped. CSS values retain small IDs, never
// pointers into temporary declarations or var() expansion buffers.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _engine_font_family_reset
_engine_font_family_reset:
    ENTER
    ADDR x19, font_families
    mov x20, #0
Lfamily_reset:
    ldr x0, [x19, x20, lsl #3]
    bl _free
    str xzr, [x19, x20, lsl #3]
    add x20, x20, #1
    cmp x20, #32
    b.lo Lfamily_reset
    LEAVE

// [start,end) -> loaded family ID >=256, or zero. ASCII case-insensitive names.
.globl _engine_font_family_lookup
_engine_font_family_lookup:
    ENTER
    mov x19, x0
    mov x20, x1
    ADDR x21, font_families
    mov x22, #0
Lfamily_lookup:
    ldr x2, [x21, x22, lsl #3]
    cbz x2, Lfamily_lookup_next
    mov x0, x19
    mov x1, x20
    bl _css_eq
    cbnz x0, Lfamily_lookup_found
Lfamily_lookup_next:
    add x22, x22, #1
    cmp x22, #32
    b.lo Lfamily_lookup
    mov x0, #0
    LEAVE
Lfamily_lookup_found:
    add x0, x22, #256
    LEAVE

// UTF8 family bytes,length -> ID, or zero when invalid/full/allocation fails.
.globl _engine_font_family_register
_engine_font_family_register:
    ENTER
    mov x19, x0
    mov x20, x1
    cbz x19, Lfamily_register_no
    cbz x20, Lfamily_register_no
    cmp x20, #128
    b.hi Lfamily_register_no
    mov x9, #0
Lfamily_register_validate:
    cmp x9, x20
    b.hs Lfamily_register_find
    ldrb w10, [x19, x9]
    cmp w10, #32
    b.lo Lfamily_register_no
    add x9, x9, #1
    b Lfamily_register_validate
Lfamily_register_find:
    mov x0, x19
    add x1, x19, x20
    bl _engine_font_family_lookup
    cbnz x0, Lfamily_register_done
    ADDR x21, font_families
    mov x22, #0
Lfamily_register_slot:
    ldr x9, [x21, x22, lsl #3]
    cbz x9, Lfamily_register_allocate
    add x22, x22, #1
    cmp x22, #32
    b.lo Lfamily_register_slot
    b Lfamily_register_no
Lfamily_register_allocate:
    mov x0, x19
    mov x1, x20
    bl _strndup
    cbz x0, Lfamily_register_no
    str x0, [x21, x22, lsl #3]
    add x0, x22, #256
Lfamily_register_done:
    LEAVE
Lfamily_register_no:
    mov x0, #0
    LEAVE
.section __DATA,__bss
.p2align 3
font_families: .space 256
