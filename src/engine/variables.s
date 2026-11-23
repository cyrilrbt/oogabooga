// Inherited custom-property chains and bounded var() expansion. Entries own
// name/value strings; each node owns only the prefix before its inherited stop.
.include "src/mac/mac.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _css_variables_free
_css_variables_free:
    ENTER
    mov x19, x0
    ldr x20, [x19, #928]
    ldr x21, [x19, #944]
Lvariables_free_next:
    cmp x20, x21
    b.eq Lvariables_free_done
    cbz x20, Lvariables_free_done
    ldr x22, [x20, #24]
    ldr x0, [x20]
    bl _free
    ldr x0, [x20, #8]
    bl _free
    mov x0, x20
    bl _free
    mov x20, x22
    b Lvariables_free_next
Lvariables_free_done:
    str xzr, [x19, #928]
    str xzr, [x19, #944]
    str xzr, [x19, #952]
    LEAVE

// meta, name start/end -> borrowed value or nil. Inherit/unset walk outward.
variables_lookup:
    ENTER
    ldr x19, [x0, #928]
    mov x20, x1
    sub x21, x2, x1
    mov x22, #4096
Lvariable_lookup_next:
    cbz x19, Lvariable_missing
    cbz x22, Lvariable_missing
    sub x22, x22, #1
    ldr x0, [x19]
    bl _strlen
    cmp x0, x21
    b.ne Lvariable_lookup_parent
    ldr x0, [x19]
    mov x1, x20
    mov x2, x21
    bl _memcmp
    cbnz w0, Lvariable_lookup_parent
    ldr x23, [x19, #8]
    cbz x23, Lvariable_missing
    mov x0, x23
    bl _strlen
    add x1, x23, x0
    mov x0, x23
    ADDR x2, variable_inherit
    bl _css_eq
    cbnz w0, Lvariable_lookup_parent
    mov x0, x23
    bl _strlen
    add x1, x23, x0
    mov x0, x23
    ADDR x2, variable_unset
    bl _css_eq
    cbnz w0, Lvariable_lookup_parent
    mov x0, x23
    bl _strlen
    add x1, x23, x0
    mov x0, x23
    ADDR x2, variable_initial
    bl _css_eq
    cbnz w0, Lvariable_missing
    mov x0, x23
    LEAVE
Lvariable_lookup_parent:
    ldr x19, [x19, #24]
    b Lvariable_lookup_next
Lvariable_missing:
    mov x0, #0
    LEAVE

// meta, declaration start/end, cascade priority. Node limits bound allocation.
.globl _css_custom_declarations
_css_custom_declarations:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
Lcustom_next:
    mov x0, x20
    mov x1, x21
    bl _css_skip
    mov x20, x0
    cmp x20, x21
    b.hs Lcustom_done
    mov x23, x20
Lcustom_colon:
    cmp x20, x21
    b.hs Lcustom_done
    ldrb w9, [x20], #1
    cmp w9, #59
    b.eq Lcustom_next
    cmp w9, #58
    b.ne Lcustom_colon
    sub x1, x20, #1
    mov x0, x23
    bl _css_trim
    stp x0, x1, [sp, #144]
    mov x24, x20
    mov x25, #0
    mov x26, #0
Lcustom_value_scan:
    cmp x20, x21
    b.hs Lcustom_value_end
    ldrb w9, [x20]
    cbz x25, Lcustom_unquoted
    cmp w9, #92
    b.eq Lcustom_escape
    cmp w9, w25
    b.ne Lcustom_scan_advance
    mov x25, #0
    b Lcustom_scan_advance
Lcustom_escape:
    add x20, x20, #1
    b Lcustom_scan_advance
Lcustom_unquoted:
    cmp w9, #34
    b.eq Lcustom_quote
    cmp w9, #39
    b.eq Lcustom_quote
    cmp w9, #40
    b.eq Lcustom_open
    cmp w9, #41
    b.eq Lcustom_close
    cbnz x26, Lcustom_scan_advance
    cmp w9, #59
    b.eq Lcustom_value_end
Lcustom_scan_advance:
    add x20, x20, #1
    b Lcustom_value_scan
Lcustom_quote:
    mov x25, x9
    b Lcustom_scan_advance
Lcustom_open:
    add x26, x26, #1
    b Lcustom_scan_advance
Lcustom_close:
    cbz x26, Lcustom_scan_advance
    sub x26, x26, #1
    b Lcustom_scan_advance
Lcustom_value_end:
    ldp x9, x10, [sp, #144]
    sub x10, x10, x9
    cmp x10, #3
    b.lo Lcustom_advance
    cmp x10, #128
    b.hi Lcustom_advance
    ldrb w10, [x9]
    cmp w10, #45
    b.ne Lcustom_advance
    ldrb w10, [x9, #1]
    cmp w10, #45
    b.ne Lcustom_advance
    mov x0, x24
    mov x1, x20
    bl _css_trim
    mov x24, x0
    mov x25, x1
    mov x26, x22
    sub x9, x25, x24
    cmp x9, #10
    b.lo Lcustom_store
    sub x0, x25, #9
    mov x1, x25
    ADDR x2, variable_important
    bl _css_eq
    cbz w0, Lcustom_store
    mov x0, x24
    sub x1, x25, #9
    bl _css_trim
    cmp x1, x0
    b.ls Lcustom_store
    ldrb w9, [x1, #-1]
    cmp w9, #33
    b.ne Lcustom_store
    sub x1, x1, #1
    mov x0, x24
    bl _css_trim
    mov x25, x1
    orr x26, x26, #0x1000000000000
Lcustom_store:
    ldr x10, [x19, #936]
    cbz x10, Lcustom_size_check
    ldr x11, [x10, #968]
    sub x9, x25, x24
    add x11, x11, x9
    mov x12, #2097152
    cmp x11, x12
    b.hi Lcustom_advance
    str x11, [x10, #968]
Lcustom_size_check:
    sub x9, x25, x24
    cmp x9, #2048
    b.hi Lcustom_advance
    ldr x27, [x19, #928]
    ldr x28, [x19, #944]
Lcustom_find_own:
    cmp x27, x28
    b.eq Lcustom_allocate
    cbz x27, Lcustom_allocate
    ldr x0, [x27]
    bl _strlen
    ldp x9, x10, [sp, #144]
    sub x10, x10, x9
    cmp x0, x10
    b.ne Lcustom_own_next
    ldr x0, [x27]
    mov x1, x9
    mov x2, x10
    bl _memcmp
    cbnz w0, Lcustom_own_next
    ldr x9, [x27, #16]
    cmp x26, x9
    b.lo Lcustom_advance
    ldr x0, [x27, #8]
    bl _free
    b Lcustom_set_value
Lcustom_own_next:
    ldr x27, [x27, #24]
    b Lcustom_find_own
Lcustom_allocate:
    ldr x10, [x19, #936]
    cbz x10, Lcustom_local_limit
    ldr x11, [x10, #960]
    mov x12, #65536
    cmp x11, x12
    b.hs Lcustom_advance
    add x11, x11, #1
    str x11, [x10, #960]
Lcustom_local_limit:
    ldr x9, [x19, #952]
    cmp x9, #512
    b.hs Lcustom_advance
    mov x0, #1
    mov x1, #32
    bl _calloc
    cbz x0, Lcustom_advance
    mov x27, x0
    ldp x0, x1, [sp, #144]
    sub x1, x1, x0
    bl _strndup
    cbz x0, Lcustom_free_entry
    str x0, [x27]
    ldr x9, [x19, #928]
    str x9, [x27, #24]
    str x27, [x19, #928]
    ldr x9, [x19, #952]
    add x9, x9, #1
    str x9, [x19, #952]
    b Lcustom_set_value
Lcustom_free_entry:
    cbnz x0, Lcustom_set_value
    mov x0, x27
    bl _free
    b Lcustom_advance
Lcustom_set_value:
    mov x0, x24
    sub x1, x25, x24
    bl _strndup
    str x0, [x27, #8]
    str x26, [x27, #16]
Lcustom_advance:
    cmp x20, x21
    b.hs Lcustom_done
    add x20, x20, #1
    b Lcustom_next
Lcustom_done:
    LEAVE

// start,end,meta -> owned expanded value. Invalid/missing/cyclic values -> nil.
.globl _css_expand
_css_expand:
    mov x3, #0
variables_expand:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    cmp x22, #16
    b.hs Lexpand_nil
    mov x0, #8193
    bl _malloc
    cbz x0, Lexpand_nil
    mov x23, x0
    mov x24, #0
    mov x25, #0                     // quote state
Lexpand_next:
    cmp x19, x20
    b.hs Lexpand_done
    ldrb w9, [x19]
    cbnz x25, Lexpand_quoted
    cmp w9, #34
    b.eq Lexpand_quote
    cmp w9, #39
    b.eq Lexpand_quote
    sub x10, x20, x19
    cmp x10, #4
    b.lo Lexpand_literal
    mov x0, x19
    ADDR x1, variable_function
    mov x2, #4
    bl _strncasecmp
    cbnz w0, Lexpand_literal
    add x26, x19, #4
    mov x27, x26
    mov x28, #1
    str xzr, [sp, #144]             // first comma at depth one
    str xzr, [sp, #152]             // quote within var()
Lexpand_find_close:
    cmp x27, x20
    b.hs Lexpand_fail
    ldrb w9, [x27]
    ldr x10, [sp, #152]
    cbz x10, Lexpand_var_unquoted
    cmp w9, w10
    b.ne Lexpand_find_advance
    str xzr, [sp, #152]
    b Lexpand_find_advance
Lexpand_var_unquoted:
    cmp w9, #34
    b.eq Lexpand_var_quote
    cmp w9, #39
    b.eq Lexpand_var_quote
    cmp w9, #40
    b.eq Lexpand_var_open
    cmp w9, #41
    b.eq Lexpand_var_close
    cmp w9, #44
    b.ne Lexpand_find_advance
    cmp x28, #1
    b.ne Lexpand_find_advance
    ldr x10, [sp, #144]
    cbnz x10, Lexpand_find_advance
    str x27, [sp, #144]
    b Lexpand_find_advance
Lexpand_var_quote:
    str x9, [sp, #152]
    b Lexpand_find_advance
Lexpand_var_open:
    add x28, x28, #1
    b Lexpand_find_advance
Lexpand_var_close:
    sub x28, x28, #1
    cbz x28, Lexpand_resolve
Lexpand_find_advance:
    add x27, x27, #1
    b Lexpand_find_close
Lexpand_resolve:
    ldr x1, [sp, #144]
    cmp x1, #0
    csel x1, x27, x1, eq
    mov x0, x26
    bl _css_trim
    mov x2, x1
    mov x1, x0
    mov x0, x21
    bl variables_lookup
    cbz x0, Lexpand_fallback
    mov x26, x0
    bl _strlen
    add x1, x26, x0
    mov x0, x26
    mov x2, x21
    add x3, x22, #1
    bl variables_expand
    cbnz x0, Lexpand_append_value
Lexpand_fallback:
    ldr x0, [sp, #144]
    cbz x0, Lexpand_fail
    add x0, x0, #1
    mov x1, x27
    mov x2, x21
    add x3, x22, #1
    bl variables_expand
    cbz x0, Lexpand_fail
Lexpand_append_value:
    mov x26, x0
    bl _strlen
    str x0, [sp, #160]
    add x9, x24, x0
    cmp x9, #8192
    b.hi Lexpand_free_fail
    add x0, x23, x24
    mov x1, x26
    ldr x2, [sp, #160]
    bl _memcpy
    ldr x9, [sp, #160]
    add x24, x24, x9
    mov x0, x26
    bl _free
    add x19, x27, #1
    b Lexpand_next
Lexpand_quoted:
    cmp w9, w25
    b.ne Lexpand_literal
    mov x25, #0
    b Lexpand_literal
Lexpand_quote:
    mov x25, x9
Lexpand_literal:
    cmp x24, #8192
    b.hs Lexpand_fail
    ldrb w9, [x19], #1
    strb w9, [x23, x24]
    add x24, x24, #1
    b Lexpand_next
Lexpand_done:
    strb wzr, [x23, x24]
    mov x0, x23
    LEAVE
Lexpand_free_fail:
    mov x0, x26
    bl _free
Lexpand_fail:
    mov x0, x23
    bl _free
Lexpand_nil:
    mov x0, #0
    LEAVE

// document,node,rules,count -> initialize inherited variables, then cascade own.
.globl _css_variables_node
_css_variables_node:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x19, #72]
    str x23, [sp, #144]
    add x23, x23, x20, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x20, x10, x9
    ldr x9, [x9, #8]
    mov x10, #0
    tbnz x9, #63, Lvariables_node_parent
    ldr x10, [x19, #72]
    add x10, x10, x9, lsl #11
    ldr x10, [x10, #928]
Lvariables_node_parent:
    ldr x9, [sp, #144]
    str x9, [x23, #936]
    str x10, [x23, #928]
    str x10, [x23, #944]
    mov x24, #0
Lvariables_node_rule:
    cmp x24, x22
    b.hs Lvariables_node_inline
    mov x9, #CSS_RULE_SIZE
    madd x25, x24, x9, x21
    ldr x9, [x25, #CSS_RULE_FLAGS]
    tbz x9, #0, Lvariables_node_advance
    mov x0, x23
    mov x1, x25
    bl _css_rule_filter_maybe
    cbz x0, Lvariables_node_advance
    mov x0, x19
    mov x1, x20
    ldr x2, [x25]
    ldr x3, [x25, #8]
    add x3, x2, x3
    bl _css_match_rule
    cbz x0, Lvariables_node_advance
    sub x0, x0, #1
    lsl x3, x0, #16
    add x9, x24, #1
    orr x3, x3, x9
    mov x0, x23
    add x9, x25, #CSS_RULE_SOURCE
    ldp x1, x2, [x9]
    bl _css_custom_declarations
Lvariables_node_advance:
    add x24, x24, #1
    b Lvariables_node_rule
Lvariables_node_inline:
    ldr x24, [x23, #16]
    cbz x24, Lvariables_node_done
    mov x0, x24
    bl _strlen
    add x2, x24, x0
    mov x1, x24
    mov x0, x23
    mov x3, #0x10000000000
    orr x3, x3, #0xffff
    bl _css_custom_declarations
Lvariables_node_done:
    LEAVE
.section __TEXT,__cstring,cstring_literals
variable_function: .asciz "var("
variable_inherit: .asciz "inherit"
variable_unset: .asciz "unset"
variable_initial: .asciz "initial"
variable_important: .asciz "important"
