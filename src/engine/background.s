// Document-owned background URL tokens and bounded single-layer CSS parsing.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _css_background_pool_free
_css_background_pool_free:
    ENTER
    ldr x19, [x0, #72]
    cbz x19, Lbg_pool_freed
    ldr x20, [x19, #CSS_BG_POOL]
    str xzr, [x19, #CSS_BG_POOL]
    str xzr, [x19, #736]
Lbg_pool_free_next:
    cbz x20, Lbg_pool_freed
    ldr x19, [x20]
    mov x0, x20
    bl _free
    mov x20, x19
    b Lbg_pool_free_next
Lbg_pool_freed:
    LEAVE
.globl _css_background_pool_begin
_css_background_pool_begin:
    ENTER
    mov x19, x0
    bl _css_background_pool_free
    LOAD x0, background_pool_context
    ldr x9, [x19, #72]
    STORE x9, background_pool_context
    LEAVE
.globl _css_background_pool_end
_css_background_pool_end:
    STORE x0, background_pool_context
    ret

// URL contents [start,end) -> document-owned string or nil. 2048-byte cap.
.globl _css_background_url_copy
_css_background_url_copy:
    ENTER
    mov x19, x0
    sub x20, x1, x0
    cbz x20, Lbg_copy_nil
    cmp x20, #2048
    b.hi Lbg_copy_nil
    LOAD x21, background_pool_context
    cbz x21, Lbg_copy_nil
    ldr x9, [x21, #736]
    add x9, x9, x20
    add x9, x9, #9
    mov x10, #2097152
    cmp x9, x10
    b.hi Lbg_copy_nil
    str x9, [x21, #736]
    add x0, x20, #9
    bl _malloc
    cbz x0, Lbg_copy_done
    mov x22, x0
    ldr x9, [x21, #CSS_BG_POOL]
    str x9, [x22]
    str x22, [x21, #CSS_BG_POOL]
    add x0, x22, #8
    mov x1, x19
    mov x2, x20
    bl _memcpy
    add x0, x22, #8
    strb wzr, [x0, x20]
    b Lbg_copy_done
Lbg_copy_nil:
    mov x0, #0
Lbg_copy_done:
    LEAVE

// Find an actual url() outside CSS strings/comments. start,end -> token start,
// token end, contents start,end; nil if absent/malformed. No speculative reads.
.globl _css_background_url_next
_css_background_url_next:
    ENTER
    mov x19, x0
    mov x20, x1
Lbg_url_scan:
    mov x0, x19
    mov x1, x20
    bl _css_skip
    mov x19, x0
    cmp x19, x20
    b.hs Lbg_url_no
    ldrb w9, [x19]
    cmp w9, #34
    b.eq Lbg_url_skip_quote
    cmp w9, #39
    b.eq Lbg_url_skip_quote
    add x9, x19, #4
    cmp x9, x20
    b.hi Lbg_url_no
    mov x0, x19
    add x1, x19, #4
    ADDR x2, bg_url_word
    bl _css_eq
    cbnz x0, Lbg_url_found
    add x19, x19, #1
    b Lbg_url_scan
Lbg_url_skip_quote:
    mov w21, w9
Lbg_url_quote_loop:
    add x19, x19, #1
    cmp x19, x20
    b.hs Lbg_url_no
    ldrb w9, [x19]
    cmp w9, #92
    b.ne Lbg_url_quote_check
    add x19, x19, #1
    b Lbg_url_quote_loop
Lbg_url_quote_check:
    cmp w9, w21
    b.ne Lbg_url_quote_loop
    add x19, x19, #1
    b Lbg_url_scan
Lbg_url_found:
    add x0, x19, #4
    mov x1, x20
    bl _css_trim
    mov x21, x0
    cmp x21, x20
    b.hs Lbg_url_no
    ldrb w22, [x21]
    cmp w22, #34
    b.eq Lbg_url_quoted
    cmp w22, #39
    b.eq Lbg_url_quoted
    mov w22, #0
    b Lbg_url_contents
Lbg_url_quoted:
    add x21, x21, #1
Lbg_url_contents:
    mov x23, x21
Lbg_url_end:
    cmp x23, x20
    b.hs Lbg_url_no
    sub x9, x23, x21
    cmp x9, #2048
    b.hi Lbg_url_no
    ldrb w9, [x23]
    cmp w9, #92 // Escaped URLs are deliberately unsupported for now.
    b.eq Lbg_url_no
    cbz w22, Lbg_url_unquoted_end
    cmp w9, w22
    b.eq Lbg_url_quote_end
    b Lbg_url_end_next
Lbg_url_unquoted_end:
    cmp w9, #41
    b.eq Lbg_url_unquoted_done
    cmp w9, #34
    b.eq Lbg_url_no
    cmp w9, #39
    b.eq Lbg_url_no
Lbg_url_end_next:
    add x23, x23, #1
    b Lbg_url_end
Lbg_url_unquoted_done:
    mov x0, x21
    mov x1, x23
    bl _css_trim
    mov x21, x0
    mov x24, x1
    b Lbg_url_return
Lbg_url_quote_end:
    mov x24, x23
    add x0, x23, #1
    mov x1, x20
    bl _css_trim
    mov x23, x0
    cmp x23, x20
    b.hs Lbg_url_no
    ldrb w9, [x23]
    cmp w9, #41
    b.ne Lbg_url_no
Lbg_url_return:
    mov x0, x19
    add x1, x23, #1
    mov x2, x21
    mov x3, x24
    LEAVE
Lbg_url_no:
    mov x0, #0
    LEAVE

// image(start,end) -> owned URL or 0 ('none'), valid. One layer only.
.globl _css_background_image
_css_background_image:
    ENTER
    mov x19, x0
    mov x20, x1
    ADDR x2, bg_none
    bl _css_eq
    cbnz x0, Lbg_image_none
    mov x0, x19
    mov x1, x20
    bl _css_background_url_next
    cbz x0, Lbg_image_bad
    cmp x0, x19
    b.ne Lbg_image_bad
    cmp x1, x20
    b.ne Lbg_image_bad
    mov x0, x2
    mov x1, x3
    bl _css_background_url_copy
    cbz x0, Lbg_image_bad
    mov x1, #1
    LEAVE
Lbg_image_none:
    mov x0, #0
    mov x1, #1
    LEAVE
Lbg_image_bad:
    mov x0, #0
    mov x1, #0
    LEAVE

.section __DATA,__bss
.p2align 3
// CSS application runs synchronously on the engine thread. Nested applications
// restore their predecessor; strings remain owned by their document, not rules.
background_pool_context: .space 8
.section __TEXT,__cstring,cstring_literals
bg_url_word: .asciz "url("
bg_none: .asciz "none"

.text
// Scalar keywords used by background-size and background-position.
.globl _css_background_scalar
_css_background_scalar:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2 // 0 size, 1 position
    ADDR x2, bg_auto
    bl _css_eq
    cbnz x0, Lbg_scalar_auto
    mov x0, x19
    mov x1, x20
    ADDR x2, bg_cover
    bl _css_eq
    cbnz x0, Lbg_scalar_cover
    mov x0, x19
    mov x1, x20
    ADDR x2, bg_contain
    bl _css_eq
    cbnz x0, Lbg_scalar_contain
    cbz x21, Lbg_scalar_number
    mov x22, #0
    ADDR x23, bg_positions
Lbg_scalar_keyword:
    ldr x2, [x23, x22, lsl #3]
    cbz x2, Lbg_scalar_number
    mov x0, x19
    mov x1, x20
    bl _css_eq
    cbnz x0, Lbg_scalar_position
    add x22, x22, #1
    b Lbg_scalar_keyword
Lbg_scalar_position:
    mov x0, #0
    cmp x22, #2
    b.lo Lbg_scalar_valid
    mov x0, #50000
    cmp x22, #2
    b.eq Lbg_scalar_percent
    mov x0, #34464
    movk x0, #1, lsl #16
Lbg_scalar_percent:
    mov x9, #0x8000000000000000
    movk x9, #3, lsl #32
    orr x0, x0, x9
    b Lbg_scalar_valid
Lbg_scalar_number:
    mov x0, x19
    mov x1, x20
    bl _css_number
    cbz x2, Lbg_scalar_bad
    orr x0, x0, x1, lsl #32
    orr x0, x0, #0x8000000000000000
    b Lbg_scalar_valid
Lbg_scalar_auto:
    cbnz x21, Lbg_scalar_bad
    mov x0, #-1
    b Lbg_scalar_valid
Lbg_scalar_cover:
    cbnz x21, Lbg_scalar_bad
    mov x0, #-10
    b Lbg_scalar_valid
Lbg_scalar_contain:
    cbnz x21, Lbg_scalar_bad
    mov x0, #-11
Lbg_scalar_valid:
    mov x1, #1
    LEAVE
Lbg_scalar_bad:
    mov x0, #0
    mov x1, #0
    LEAVE

// start,end,decl,important,opcode (1002 size,1003 position,1004 repeat).
.globl _css_background_declarations
_css_background_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    cmp x23, #1001
    b.eq Lbg_shorthand
    cmp x23, #1004
    b.eq Lbg_repeat
    mov x24, x19
Lbg_pair_split:
    cmp x24, x20
    b.hs Lbg_pair_first
    ldrb w9, [x24]
    cmp w9, #32
    b.ls Lbg_pair_first
    add x24, x24, #1
    b Lbg_pair_split
Lbg_pair_first:
    mov x0, x19
    mov x1, x24
    cmp x23, #1003
    cset x2, eq
    bl _css_background_scalar
    cbz x1, Lbg_decl_done
    mov x25, x0
    mov x0, x24
    mov x1, x20
    bl _css_trim
    cmp x0, x1
    b.hs Lbg_pair_single
    cmp x23, #1003
    cset x2, eq
    bl _css_background_scalar
    cbz x1, Lbg_decl_done
    mov x26, x0
    cmn x25, #10
    b.eq Lbg_decl_done
    cmn x25, #11
    b.eq Lbg_decl_done
    cmp x23, #1003
    b.ne Lbg_pair_commit
    mov x0, x19
    mov x1, x24
    ADDR x2, bg_top
    bl _css_eq
    mov x27, x0
    mov x0, x19
    mov x1, x24
    ADDR x2, bg_bottom
    bl _css_eq
    orr x0, x0, x27
    cbz x0, Lbg_pair_commit
    mov x9, x25
    mov x25, x26
    mov x26, x9
    b Lbg_pair_commit
Lbg_pair_single:
    mov x26, #-1
    cmp x23, #1003
    b.ne Lbg_pair_commit
    mov x26, #50000
    mov x9, #0x8000000000000000
    movk x9, #3, lsl #32
    orr x26, x26, x9
    // A lone top/bottom controls Y, with X centered.
    mov x0, x19
    mov x1, x24
    ADDR x2, bg_top
    bl _css_eq
    mov x27, x0
    mov x0, x19
    mov x1, x24
    ADDR x2, bg_bottom
    bl _css_eq
    orr x0, x0, x27
    cbz x0, Lbg_pair_commit
    mov x9, x25
    mov x25, x26
    mov x26, x9
Lbg_pair_commit:
    mov x0, x21
    mov x1, #CSS_BG_WIDTH
    cmp x23, #1003
    mov x9, #CSS_BG_X
    csel x1, x9, x1, eq
    mov x27, x1
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
    mov x0, x21
    add x1, x27, #1
    mov x2, x22
    mov x3, x26
    bl _css_store_decl
    b Lbg_decl_done
Lbg_repeat:
    mov x24, #0
    ADDR x25, bg_repeats
Lbg_repeat_next:
    ldr x2, [x25, x24, lsl #3]
    cbz x2, Lbg_decl_done
    mov x0, x19
    mov x1, x20
    bl _css_eq
    cbnz x0, Lbg_repeat_commit
    add x24, x24, #1
    b Lbg_repeat_next
Lbg_repeat_commit:
    mov x0, x21
    mov x1, #CSS_BG_REPEAT
    mov x2, x22
    mov x3, x24
    bl _css_store_decl
    b Lbg_decl_done
Lbg_shorthand:
    mov x0, x19
    mov x1, x20
    ADDR x2, bg_none
    bl _css_eq
    cbz x0, Lbg_shorthand_url
    mov x0, x21
    mov x1, x22
    bl _css_background_reset
    mov x0, x21
    mov x1, #CSS_BACKGROUND
    mov x2, x22
    mov x3, #-1
    bl _css_store_decl
    b Lbg_decl_done
Lbg_shorthand_url:
    // Single-layer image shorthand. Reject commas rather than partially
    // applying unsupported gradients/layers over an earlier valid fallback.
    mov x0, x19
    mov x1, x20
    bl _css_background_url_next
    cbz x0, Lbg_decl_done
    str x0, [sp, #144]
    str x1, [sp, #152]
    mov x0, x2
    mov x1, x3
    bl _css_background_url_copy
    cbz x0, Lbg_decl_done
    str x0, [sp, #160]
    mov x24, x19
    mov x25, #0 // repeat
    mov x26, #0 // position x
    mov x27, #0 // position y
Lbg_shorthand_token:
    ldr x9, [sp, #144]
    cmp x24, x9
    b.ne Lbg_shorthand_space
    ldr x24, [sp, #152]
Lbg_shorthand_space:
    mov x0, x24
    mov x1, x20
    bl _css_trim
    mov x24, x0
    cmp x24, x20
    b.hs Lbg_shorthand_commit
    ldr x9, [sp, #144]
    cmp x24, x9
    b.eq Lbg_shorthand_token
    mov x28, x24
Lbg_shorthand_end:
    cmp x28, x20
    b.hs Lbg_shorthand_word
    ldrb w9, [x28]
    cmp w9, #32
    b.ls Lbg_shorthand_word
    cmp w9, #44
    b.eq Lbg_decl_done
    add x28, x28, #1
    b Lbg_shorthand_end
Lbg_shorthand_word:
    mov x0, x24
    mov x1, x28
    ADDR x2, bg_no_repeat
    bl _css_eq
    cbz x0, Lbg_shorthand_position
    mov x25, #1
    b Lbg_shorthand_next
Lbg_shorthand_position:
    mov x0, x24
    mov x1, x28
    mov x2, #1
    bl _css_background_scalar
    cbz x1, Lbg_decl_done
    mov x26, x0
    mov x27, x0
Lbg_shorthand_next:
    mov x24, x28
    b Lbg_shorthand_token
Lbg_shorthand_commit:
    mov x0, x21
    mov x1, #CSS_BACKGROUND
    mov x2, x22
    mov x3, #-1
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BG_IMAGE
    mov x2, x22
    ldr x3, [sp, #160]
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BG_REPEAT
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BG_X
    mov x2, x22
    mov x3, x26
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BG_Y
    mov x2, x22
    mov x3, x27
    bl _css_store_decl
    // A shorthand resets the image size to auto.
    mov x0, x21
    mov x1, #CSS_BG_WIDTH
    mov x2, x22
    mov x3, #-1
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_BG_HEIGHT
    mov x2, x22
    mov x3, #-1
    bl _css_store_decl
Lbg_decl_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
bg_auto: .asciz "auto"
bg_cover: .asciz "cover"
bg_contain: .asciz "contain"
bg_left: .asciz "left"
bg_top: .asciz "top"
bg_center: .asciz "center"
bg_right: .asciz "right"
bg_bottom: .asciz "bottom"
bg_repeat: .asciz "repeat"
bg_no_repeat: .asciz "no-repeat"
bg_repeat_x: .asciz "repeat-x"
bg_repeat_y: .asciz "repeat-y"
.section __DATA,__const
.p2align 3
bg_positions: .quad bg_left,bg_top,bg_center,bg_right,bg_bottom,0
bg_repeats: .quad bg_repeat,bg_no_repeat,bg_repeat_x,bg_repeat_y,0

.text
.globl _css_background_reset
_css_background_reset:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x1, #CSS_BG_IMAGE
    mov x2, x20
    mov x3, #0
    bl _css_store_decl
    mov x21, #CSS_BG_WIDTH
Lbg_reset_property:
    mov x0, x19
    mov x1, x21
    mov x2, x20
    cmp x21, #CSS_BG_HEIGHT
    mov x3, #-1
    csel x3, x3, xzr, ls
    bl _css_store_decl
    add x21, x21, #1
    cmp x21, #CSS_BG_REPEAT
    b.ls Lbg_reset_property
    LEAVE
