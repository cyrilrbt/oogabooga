// Named rectangular Grid areas and the unquoted rows / columns shorthand.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
// start,end,property -> pool-owned bytes, valid. Bounded ASCII names/rows.
.globl _css_grid_names
_css_grid_names:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    sub x9, x20, x19
    cmp x9, #256
    b.hi Lgrid_names_bad
    cbz x9, Lgrid_names_bad
    mov x22, x19
    mov x23, #0
Lgrid_names_char:
    cmp x22, x20
    b.hs Lgrid_names_copy
    ldrb w9, [x22], #1
    cmp x21, #CSS_GRID_AREA_NAME
    b.eq Lgrid_names_identifier
    cmp w9, #34
    b.eq Lgrid_names_quote
    cmp w9, #39
    b.eq Lgrid_names_quote
    cmp w9, #32
    b.ls Lgrid_names_char
    cmp w9, #46
    b.eq Lgrid_names_char
Lgrid_names_identifier:
    cmp w9, #45
    b.eq Lgrid_names_char
    cmp w9, #95
    b.eq Lgrid_names_char
    sub w10, w9, #48
    cmp w10, #9
    b.ls Lgrid_names_char
    orr w9, w9, #32
    sub w9, w9, #97
    cmp w9, #25
    b.hi Lgrid_names_bad
    b Lgrid_names_char
Lgrid_names_quote:
    cbz x23, Lgrid_names_open
    cmp x23, x9
    b.ne Lgrid_names_bad
    mov x23, #0
    b Lgrid_names_char
Lgrid_names_open:
    mov x23, x9
    b Lgrid_names_char
Lgrid_names_copy:
    cbnz x23, Lgrid_names_bad
    mov x0, x19
    mov x1, x20
    bl _css_background_url_copy
    cmp x0, #0
    cset x1, ne
    LEAVE
Lgrid_names_bad:
    mov x0, #0
    mov x1, #0
    LEAVE
.globl _css_grid_template
_css_grid_template:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x19
    mov x24, #0
Lgrid_template_scan:
    cmp x23, x20
    b.hs Lgrid_template_done
    ldrb w9, [x23]
    cmp w9, #40
    b.ne Lgrid_template_close
    add x24, x24, #1
Lgrid_template_close:
    cmp w9, #41
    b.ne Lgrid_template_slash
    sub x24, x24, #1
Lgrid_template_slash:
    cbnz x24, Lgrid_template_next
    cmp w9, #47
    b.eq Lgrid_template_parse
Lgrid_template_next:
    add x23, x23, #1
    b Lgrid_template_scan
Lgrid_template_parse:
    mov x0, x19
    mov x1, x23
    bl _css_grid_tracks
    cbz x1, Lgrid_template_done
    mov x24, x0
    add x0, x23, #1
    mov x1, x20
    bl _css_grid_tracks
    cbz x1, Lgrid_template_done
    mov x25, x0
    mov x0, x21
    mov x1, #CSS_GRID_ROWS
    mov x2, x22
    mov x3, x24
    bl _css_store_decl
    mov x0, x21
    mov x1, #CSS_GRID_COLUMNS
    mov x2, x22
    mov x3, x25
    bl _css_store_decl
Lgrid_template_done:
    LEAVE
// owner metadata,child metadata -> bind matching named area to numeric lines.
.globl _engine_grid_named_item
_engine_grid_named_item:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x9, #CSS_GRID_AREAS
    CSS_VALUE_ADDR x10, x19, x9
    ldr x21, [x10]
    cmp x21, #0
    b.le Lgrid_named_done
    mov x9, #CSS_GRID_AREA_NAME
    CSS_VALUE_ADDR x10, x20, x9
    ldr x22, [x10]
    cmp x22, #0
    b.le Lgrid_named_done
    mov x0, x22
    bl _strlen
    mov x23, x0
    mov x24, #0                  // row
    mov x25, #0                  // column
    mov x26, #0                  // quote
    mov x27, #0                  // first matching row, one-based
    mov x28, #0                  // first matching column
    str xzr, [sp, #144]          // last matching row
    str xzr, [sp, #152]          // last matching column
Lgrid_named_scan:
    ldrb w9, [x21]
    cbz w9, Lgrid_named_commit
    cmp w9, #34
    b.eq Lgrid_named_quote
    cmp w9, #39
    b.eq Lgrid_named_quote
    cmp w9, #32
    b.ls Lgrid_named_advance
    cbz x26, Lgrid_named_done
    mov x10, x21
Lgrid_named_token:
    ldrb w9, [x21]
    cbz w9, Lgrid_named_compare
    cmp w9, #32
    b.ls Lgrid_named_compare
    cmp x9, x26
    b.eq Lgrid_named_compare
    add x21, x21, #1
    b Lgrid_named_token
Lgrid_named_compare:
    add x25, x25, #1
    cmp x25, #16
    b.hi Lgrid_named_done
    sub x9, x21, x10
    cmp x9, x23
    b.ne Lgrid_named_scan
    mov x0, x10
    mov x1, x22
    mov x2, x23
    bl _memcmp
    cbnz x0, Lgrid_named_scan
    cbnz x27, Lgrid_named_last
    mov x27, x24
    mov x28, x25
Lgrid_named_last:
    str x24, [sp, #144]
    str x25, [sp, #152]
    b Lgrid_named_scan
Lgrid_named_quote:
    cbz x26, Lgrid_named_open
    cmp x9, x26
    b.ne Lgrid_named_done
    mov x26, #0
    b Lgrid_named_advance
Lgrid_named_open:
    mov x26, x9
    add x24, x24, #1
    cmp x24, #64
    b.hi Lgrid_named_done
    mov x25, #0
Lgrid_named_advance:
    add x21, x21, #1
    b Lgrid_named_scan
Lgrid_named_commit:
    cbnz x26, Lgrid_named_done
    cbz x27, Lgrid_named_done
    ldr x9, [sp, #144]
    sub x9, x9, x27
    add x9, x9, #1
    ldr x10, [sp, #152]
    sub x10, x10, x28
    add x10, x10, #1
    str x28, [x20, #(1840+(CSS_GRID_COLUMN-48)*8)]
    str x27, [x20, #(1840+(CSS_GRID_ROW-48)*8)]
    str x10, [x20, #(1840+(CSS_GRID_COLSPAN-48)*8)]
    str x9, [x20, #(1840+(CSS_GRID_ROWSPAN-48)*8)]
Lgrid_named_done:
    LEAVE
