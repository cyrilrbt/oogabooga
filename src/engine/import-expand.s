// Expand a bounded private import tree into one owned CSS source. URLs and
// network state are adapter-owned; this module only copies validated bytes.
.include "src/mac/mac.inc"
.include "src/engine/imports.inc"
.text
.p2align 2
// records,count,root,outLength* -> owned NUL-terminated bytes, or nil.
.globl _engine_css_import_expand
_engine_css_import_expand:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    cbz x22, Lexpand_fail
    str xzr, [x22]
    cbz x19, Lexpand_fail
    cmp x20, #IMPORT_MAX
    b.hi Lexpand_fail
    cmp x21, x20
    b.hs Lexpand_fail
    mov x0, #1
    mov x1, #1048576
    add x1, x1, #1
    bl _calloc
    cbz x0, Lexpand_fail
    mov x23, x0
    str x0, [sp, #144]
    str xzr, [sp, #152]
    mov x9, #1048576
    str x9, [sp, #160]
    mov x0, x19
    mov x1, x20
    mov x2, x21
    add x3, sp, #144
    mov x4, #0
    bl import_emit
    cbz x0, Lexpand_success
    mov x0, x23
    bl _free
    b Lexpand_fail
Lexpand_success:
    ldr x9, [sp, #152]
    str x9, [x22]
    mov x0, x23
    LEAVE
Lexpand_fail:
    mov x0, #0
    LEAVE

// context,bytes,length -> 0/-1; bound before copying, including overflow.
import_append:
    ENTER
    mov x19, x0
    mov x20, x2
    ldr x21, [x19, #8]
    ldr x9, [x19, #16]
    sub x9, x9, x21
    cmp x20, x9
    b.hi Lappend_fail
    cbz x20, Lappend_success
    cbz x1, Lappend_fail
    ldr x0, [x19]
    add x0, x0, x21
    bl _memcpy
    add x21, x21, x20
    str x21, [x19, #8]
Lappend_success:
    mov x0, #0
    LEAVE
Lappend_fail:
    mov x0, #-1
    LEAVE

// records,count,index,context,depth -> 0/-1. Child ranges belong to parent source.
import_emit:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    cmp x23, #IMPORT_DEPTH
    b.hi Lemit_fail
    cmp x21, x20
    b.hs Lemit_fail
    add x24, x19, x21, lsl #7
    ldr x9, [x24, #IMPORT_SOURCE]
    cbz x9, Lemit_empty
    ldr x9, [x24, #IMPORT_LENGTH]
    mov x10, #1048576
    cmp x9, x10
    b.hi Lemit_fail
    mov x25, #0                      // copied source cursor
    ldr x26, [x24, #IMPORT_FIRST]
    mov x27, x20                     // sibling/cycle budget
Lemit_child:
    cbz x26, Lemit_tail
    cbz x27, Lemit_fail
    sub x27, x27, #1
    sub x9, x26, #1
    cmp x9, x20
    b.hs Lemit_fail
    add x28, x19, x9, lsl #7
    ldr x9, [x28, #IMPORT_PARENT]
    add x10, x21, #1
    cmp x9, x10
    b.ne Lemit_fail
    ldr x9, [x28, #IMPORT_START]
    ldr x10, [x28, #IMPORT_END]
    cmp x9, x25
    b.lo Lemit_fail
    cmp x10, x9
    b.lo Lemit_fail
    ldr x11, [x24, #IMPORT_LENGTH]
    cmp x10, x11
    b.hi Lemit_fail
    mov x0, x22
    ldr x1, [x24, #IMPORT_SOURCE]
    add x1, x1, x25
    sub x2, x9, x25
    mov x25, x10
    bl import_append
    cbnz x0, Lemit_fail
    ldr x9, [x28, #IMPORT_SOURCE]
    cbz x9, Lemit_child_next          // pending/failed import contributes no rules
    ldr x9, [x28, #IMPORT_MEDIA]
    cbz x9, Lemit_recurse
    ldrb w9, [x9]
    cbz w9, Lemit_recurse
    mov x0, x22
    ADDR x1, import_media_open
    mov x2, #7
    bl import_append
    cbnz x0, Lemit_fail
    ldr x0, [x28, #IMPORT_MEDIA]
    bl _strlen
    cmp x0, #1024
    b.hi Lemit_fail
    mov x2, x0
    ldr x1, [x28, #IMPORT_MEDIA]
    mov x0, x22
    bl import_append
    cbnz x0, Lemit_fail
    mov x0, x22
    ADDR x1, import_brace_open
    mov x2, #2
    bl import_append
    cbnz x0, Lemit_fail
Lemit_recurse:
    mov x0, x19
    mov x1, x20
    sub x2, x26, #1
    mov x3, x22
    add x4, x23, #1
    bl import_emit
    cbnz x0, Lemit_fail
    ldr x9, [x28, #IMPORT_MEDIA]
    cbz x9, Lemit_separator
    ldrb w9, [x9]
    cbz w9, Lemit_separator
    mov x0, x22
    ADDR x1, import_brace_close
    mov x2, #2
    bl import_append
    cbnz x0, Lemit_fail
Lemit_separator:
    // Prevent token merging when an imported source has no trailing whitespace.
    mov x0, x22
    ADDR x1, import_newline
    mov x2, #1
    bl import_append
    cbnz x0, Lemit_fail
Lemit_child_next:
    ldr x26, [x28, #IMPORT_NEXT]
    b Lemit_child
Lemit_tail:
    ldr x1, [x24, #IMPORT_SOURCE]
    add x1, x1, x25
    ldr x2, [x24, #IMPORT_LENGTH]
    sub x2, x2, x25
    mov x0, x22
    bl import_append
    LEAVE
Lemit_empty:
    mov x0, #0
    LEAVE
Lemit_fail:
    mov x0, #-1
    LEAVE
.section __TEXT,__cstring,cstring_literals
import_media_open: .asciz "@media "
import_brace_open: .asciz "{\n"
import_brace_close: .asciz "}\n"
import_newline: .asciz "\n"
