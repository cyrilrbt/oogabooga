// Common font shorthand: [style] [weight] size[/line-height] family-list.
// Parse into a temporary declaration set; invalid shorthand changes nothing.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _css_font_declarations
_css_font_declarations:
    ENTER
    sub sp, sp, #256
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x0, sp
    mov x1, #0
    mov x2, #240
    bl _memset
    // Shorthand resets omitted style, weight and line-height.
    mov x9, #400
    str x9, [sp, #(16 + CSS_WEIGHT * 8)]
Lfont_token:
    mov x0, x19
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x19, x20
    b.hs Lfont_decl_done
    mov x23, x19
Lfont_token_end:
    cmp x23, x20
    b.hs Lfont_classify
    ldrb w9, [x23]
    cmp w9, #32
    b.ls Lfont_classify
    cmp w9, #47
    b.eq Lfont_classify
    add x23, x23, #1
    b Lfont_token_end
Lfont_classify:
    mov x0, x19
    mov x1, x23
    bl _css_number
    cbz x2, Lfont_optional
    cbnz x1, Lfont_size
Lfont_optional:
    mov x0, #CSS_ITALIC
    mov x1, x19
    mov x2, x23
    bl _css_value
    cbz x1, Lfont_weight
    str x0, [sp, #(16 + CSS_ITALIC * 8)]
    b Lfont_optional_next
Lfont_weight:
    mov x0, #CSS_WEIGHT
    mov x1, x19
    mov x2, x23
    bl _css_value
    cbz x1, Lfont_decl_done
    str x0, [sp, #(16 + CSS_WEIGHT * 8)]
Lfont_optional_next:
    cmp x19, x23
    b.eq Lfont_decl_done
    mov x19, x23
    b Lfont_token
Lfont_size:
    mov x0, #CSS_SIZE
    mov x1, x19
    mov x2, x23
    bl _css_value
    cbz x1, Lfont_decl_done
    str x0, [sp, #(16 + CSS_SIZE * 8)]
    mov x0, x23
    mov x1, x20
    bl _css_trim
    mov x19, x0
    cmp x19, x20
    b.hs Lfont_decl_done
    ldrb w9, [x19]
    cmp w9, #47
    b.ne Lfont_family_value
    add x0, x19, #1
    mov x1, x20
    bl _css_trim
    mov x19, x0
    mov x23, x0
Lfont_line_end:
    cmp x23, x20
    b.hs Lfont_decl_done
    ldrb w9, [x23]
    cmp w9, #32
    b.ls Lfont_line_value
    add x23, x23, #1
    b Lfont_line_end
Lfont_line_value:
    mov x0, #CSS_LINE
    mov x1, x19
    mov x2, x23
    bl _css_value
    cbz x1, Lfont_decl_done
    str x0, [sp, #(16 + CSS_LINE * 8)]
    mov x19, x23
Lfont_family_value:
    mov x0, #CSS_FAMILY
    mov x1, x19
    mov x2, x20
    bl _css_value
    cbz x1, Lfont_decl_done
    str x0, [sp, #(16 + CSS_FAMILY * 8)]
    mov x23, #0
Lfont_decl_merge:
    ADDR x9, font_properties
    ldr x1, [x9, x23, lsl #3]
    add x9, sp, #16
    ldr x3, [x9, x1, lsl #3]
    mov x0, x21
    mov x2, x22
    bl _css_store_decl
    add x23, x23, #1
    cmp x23, #5
    b.lo Lfont_decl_merge
Lfont_decl_done:
    add sp, sp, #256
    LEAVE
.section __DATA,__const
.p2align 3
font_properties: .quad CSS_SIZE, CSS_WEIGHT, CSS_ITALIC, CSS_LINE, CSS_FAMILY
