.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.macro JS_EMIT op, aa, bb, cc
    mov x4, \cc
    mov x3, \bb
    mov x2, \aa
    mov x1, #\op
    mov x0, x19
    bl _js_emit
.endm
.text
.globl _js_peek
_js_peek:
    ldr x9, [x0, #JS_TOKENS]
    ldr x10, [x0, #JS_POS]
    add x9, x9, x10, lsl #5
    ldp x0, x1, [x9]
    mov x2, #0
    cmp x0, #T_IDENT
    b.eq Ljs_peek_text
    cmp x0, #T_STRING
    b.ne Ljs_peek_done
Ljs_peek_text:
    ldr x2, [x1, #8]
Ljs_peek_done:
    ret
.globl _js_accept
_js_accept:
    mov x9, x0
    ldr x10, [x9, #JS_TOKENS]
    ldr x11, [x9, #JS_POS]
    add x15, x10, x11, lsl #5
    ldr x12, [x15]
    cmp x12, x1
    b.ne Ljs_accept_no
    add x11, x11, #1
    str x11, [x9, #JS_POS]
    mov x0, #1
    ret
Ljs_accept_no:
    mov x0, #0
    ret
.globl _js_expect
_js_expect:
    ENTER
    mov x19, x0
    bl _js_accept
    cbnz x0, Ljs_expected
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_expected:
    LEAVE
// vm,word -> BOOL, consuming only an exact identifier match.
.globl _js_word
_js_word:
    ENTER
    mov x19, x0
    mov x20, x1
    bl _js_peek
    cmp x0, #T_IDENT
    b.ne Ljs_word_no
    mov x0, x2
    mov x1, x20
    bl _strcmp
    cbnz x0, Ljs_word_no
    ldr x9, [x19, #JS_POS]
    add x9, x9, #1
    str x9, [x19, #JS_POS]
    mov x0, #1
    LEAVE
Ljs_word_no:
    mov x0, #0
    LEAVE
.globl _js_emit
_js_emit:
    ldr x9, [x0, #JS_CODE_COUNT]
    mov x10, #JS_MAX_CODE
    cmp x9, x10
    b.hs Ljs_emit_full
    ldr x10, [x0, #JS_CODE]
    add x10, x10, x9, lsl #5
    stp x1, x2, [x10]
    stp x3, x4, [x10, #16]
    add x10, x9, #1
    str x10, [x0, #JS_CODE_COUNT]
    mov x0, x9
    ret
Ljs_emit_full:
    mov x9, #3
    str x9, [x0, #JS_ERROR]
    mov x0, #0
    ret
// vm,instruction index -> patch jump operand to current code end.
.globl _js_patch
_js_patch:
    ldr x9, [x0, #JS_CODE]
    add x9, x9, x1, lsl #5
    ldr x10, [x0, #JS_CODE_COUNT]
    str x10, [x9, #8]
    ret
js_parse_enter:
    ldr x9, [x0, #JS_PARSE_DEPTH]
    add x9, x9, #1
    str x9, [x0, #JS_PARSE_DEPTH]
    cmp x9, #64
    b.lo Ljs_parse_entered
    mov x9, #3
    str x9, [x0, #JS_ERROR]
Ljs_parse_entered:
    ret
js_parse_leave:
    ldr x9, [x0, #JS_PARSE_DEPTH]
    sub x9, x9, #1
    str x9, [x0, #JS_PARSE_DEPTH]
    ret
// Current identifier -> owned name pointer, or SyntaxError.
js_parse_name:
    ENTER
    mov x19, x0
    bl _js_peek
    cmp x0, #T_IDENT
    b.ne Ljs_name_bad
    mov x20, x2
    mov x0, x19
    mov x1, #T_IDENT
    bl _js_accept
    mov x0, x20
    LEAVE
Ljs_name_bad:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
// Parse a complete script; bytecode is not executed until this succeeds.
.globl _js_compile
_js_compile:
    ENTER
    mov x19, x0
Ljs_compile_next:
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_compile_done
    mov x0, x19
    bl _js_peek
    cbz x0, Ljs_compile_return
    mov x0, x19
    bl js_statement
    b Ljs_compile_next
Ljs_compile_return:
    JS_EMIT J_PUSH, #0, #0, #0
    JS_EMIT J_RETURN, #0, #0, #0
Ljs_compile_done:
    LEAVE
js_statement:
    ENTER
    mov x19, x0
    bl js_parse_enter
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_statement_done
    mov x0, x19
    mov x1, #59
    bl _js_accept
    cbnz x0, Ljs_statement_done
    mov x0, x19
    mov x1, #123
    bl _js_accept
    cbnz x0, Ljs_block
    mov x20, #0
    ADDR x21, js_decl_names
Ljs_declaration_name:
    mov x0, x19
    ldr x1, [x21, x20, lsl #3]
    bl _js_word
    cbnz x0, Ljs_declaration
    add x20, x20, #1
    cmp x20, #3
    b.lo Ljs_declaration_name
    mov x0, x19
    ADDR x1, js_kw_function
    bl _js_word
    cbnz x0, Ljs_function_declaration
    mov x0, x19
    ADDR x1, js_kw_return
    bl _js_word
    cbnz x0, Ljs_return_statement
    mov x0, x19
    ADDR x1, js_kw_if
    bl _js_word
    cbnz x0, Ljs_if_statement
    mov x0, x19
    ADDR x1, js_kw_while
    bl _js_word
    cbnz x0, Ljs_while_statement
    mov x0, x19
    ADDR x1, js_kw_for
    bl _js_word
    cbnz x0, Ljs_for_statement
    mov x0, x19
    mov x1, #0
    bl js_expression
    JS_EMIT J_POP, #0, #0, #0
    b Ljs_statement_semicolon
Ljs_block:
    JS_EMIT J_SCOPE, #0, #0, #0
Ljs_block_next:
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_statement_done
    mov x0, x19
    mov x1, #125
    bl _js_accept
    cbnz x0, Ljs_block_end
    mov x0, x19
    bl _js_peek
    cbz x0, Ljs_statement_error
    mov x0, x19
    bl js_statement
    b Ljs_block_next
Ljs_block_end:
    JS_EMIT J_UNSCOPE, #0, #0, #0
    b Ljs_statement_done
Ljs_declaration:
    add x20, x20, #1
Ljs_declaration_item:
    mov x0, x19
    bl js_parse_name
    mov x21, x0
    mov x0, x19
    mov x1, #61
    bl _js_accept
    cbz x0, Ljs_declaration_empty
    mov x0, x19
    mov x1, #0
    bl js_expression
    b Ljs_declaration_emit
Ljs_declaration_empty:
    cmp x20, #2
    b.eq Ljs_statement_error
    JS_EMIT J_PUSH, #0, #0, #0
Ljs_declaration_emit:
    JS_EMIT J_DECLARE, x21, x20, #0
    JS_EMIT J_POP, #0, #0, #0
    mov x0, x19
    mov x1, #44
    bl _js_accept
    cbnz x0, Ljs_declaration_item
    b Ljs_statement_semicolon
Ljs_function_declaration:
    mov x0, x19
    bl js_parse_name
    mov x20, x0
    mov x0, x19
    mov x1, #0
    mov x2, #0
    bl js_function_parse
    JS_EMIT J_DECLARE, x20, #3, #0
    JS_EMIT J_POP, #0, #0, #0
    b Ljs_statement_done
Ljs_return_statement:
    ldr x9, [x19, #JS_SOURCE_DEPTH]
    cbz x9, Ljs_statement_error
    mov x0, x19
    bl _js_peek
    cmp x0, #59
    b.eq Ljs_return_empty
    cmp x0, #125
    b.eq Ljs_return_empty
    cbz x0, Ljs_return_empty
    mov x0, x19
    mov x1, #0
    bl js_expression
    b Ljs_return_emit
Ljs_return_empty:
    JS_EMIT J_PUSH, #0, #0, #0
Ljs_return_emit:
    JS_EMIT J_RETURN, #0, #0, #0
    b Ljs_statement_semicolon
Ljs_if_statement:
    mov x0, x19
    mov x1, #40
    bl _js_expect
    mov x0, x19
    mov x1, #0
    bl js_expression
    mov x0, x19
    mov x1, #41
    bl _js_expect
    JS_EMIT J_FALSE, #0, #0, #0
    mov x20, x0
    mov x0, x19
    bl js_statement
    JS_EMIT J_JUMP, #0, #0, #0
    mov x21, x0
    mov x0, x19
    mov x1, x20
    bl _js_patch
    mov x0, x19
    ADDR x1, js_kw_else
    bl _js_word
    cbz x0, Ljs_if_end
    mov x0, x19
    bl js_statement
Ljs_if_end:
    mov x0, x19
    mov x1, x21
    bl _js_patch
    b Ljs_statement_done
Ljs_while_statement:
    ldr x20, [x19, #JS_CODE_COUNT]
    mov x0, x19
    mov x1, #40
    bl _js_expect
    mov x0, x19
    mov x1, #0
    bl js_expression
    mov x0, x19
    mov x1, #41
    bl _js_expect
    JS_EMIT J_FALSE, #0, #0, #0
    mov x21, x0
    mov x0, x19
    bl js_statement
    JS_EMIT J_JUMP, x20, #0, #0
    mov x0, x19
    mov x1, x21
    bl _js_patch
    b Ljs_statement_done
Ljs_for_statement:
    mov x0, x19
    mov x1, #40
    bl _js_expect
    JS_EMIT J_SCOPE, #0, #0, #0
    mov x0, x19
    bl js_statement
    ldr x20, [x19, #JS_CODE_COUNT]
    mov x0, x19
    mov x1, #59
    bl _js_accept
    cbnz x0, Ljs_for_true
    mov x0, x19
    mov x1, #0
    bl js_expression
    mov x0, x19
    mov x1, #59
    bl _js_expect
    b Ljs_for_condition
Ljs_for_true:
    JS_EMIT J_PUSH, #3, #0, #0
Ljs_for_condition:
    JS_EMIT J_FALSE, #0, #0, #0
    mov x21, x0
    JS_EMIT J_JUMP, #0, #0, #0
    mov x22, x0
    ldr x23, [x19, #JS_CODE_COUNT]
    mov x0, x19
    mov x1, #41
    bl _js_accept
    cbnz x0, Ljs_for_increment_done
    mov x0, x19
    mov x1, #0
    bl js_expression
    JS_EMIT J_POP, #0, #0, #0
    mov x0, x19
    mov x1, #41
    bl _js_expect
Ljs_for_increment_done:
    JS_EMIT J_JUMP, x20, #0, #0
    mov x0, x19
    mov x1, x22
    bl _js_patch
    mov x0, x19
    bl js_statement
    JS_EMIT J_JUMP, x23, #0, #0
    mov x0, x19
    mov x1, x21
    bl _js_patch
    JS_EMIT J_UNSCOPE, #0, #0, #0
    b Ljs_statement_done
Ljs_statement_semicolon:
    mov x0, x19
    mov x1, #59
    bl _js_accept
    cbnz x0, Ljs_statement_done
    mov x0, x19
    bl _js_peek
    cbz x0, Ljs_statement_done
    cmp x0, #125
    b.eq Ljs_statement_done
Ljs_statement_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_statement_done:
    mov x0, x19
    bl js_parse_leave
    LEAVE
// Pratt expression parser. Last load/get instruction also encodes the lvalue.
js_expression:
    ENTER
    mov x19, x0
    mov x20, x1
    bl js_parse_enter
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_expression_done
    mov x0, x19
    bl js_atom
Ljs_expression_next:
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_expression_done
    mov x0, x19
    bl _js_peek
    mov x21, x0
    bl js_precedence
    mov x22, x0
    cbz x22, Ljs_expression_done
    cmp x22, x20
    b.lo Ljs_expression_done
    cmp x21, #61
    b.eq Ljs_assignment
    cmp x21, #T_ADD_SET
    b.eq Ljs_assignment
    cmp x21, #T_SUB_SET
    b.eq Ljs_assignment
    mov x0, x19
    mov x1, x21
    bl _js_accept
    cmp x21, #T_AND
    b.eq Ljs_short_and
    cmp x21, #T_OR
    b.eq Ljs_short_or
    mov x0, x19
    add x1, x22, #1
    bl js_expression
    JS_EMIT J_BINARY, x21, #0, #0
    b Ljs_expression_next
Ljs_short_and:
    mov x23, #J_FALSE
    b Ljs_short_begin
Ljs_short_or:
    mov x23, #J_TRUE
Ljs_short_begin:
    JS_EMIT J_DUP, #0, #0, #0
    mov x0, x19
    mov x1, x23
    mov x2, #0
    mov x3, #0
    mov x4, #0
    bl _js_emit
    mov x24, x0
    JS_EMIT J_POP, #0, #0, #0
    mov x0, x19
    add x1, x22, #1
    bl js_expression
    mov x0, x19
    mov x1, x24
    bl _js_patch
    b Ljs_expression_next
Ljs_assignment:
    ldr x9, [x19, #JS_CODE_COUNT]
    cbz x9, Ljs_expression_error
    sub x9, x9, #1
    ldr x10, [x19, #JS_CODE]
    add x10, x10, x9, lsl #5
    ldp x23, x24, [x10]
    cmp x23, #J_LOAD
    b.eq Ljs_assignment_valid
    cmp x21, #61
    b.ne Ljs_expression_error
    cmp x23, #J_GET
    b.eq Ljs_assignment_valid
    cmp x23, #J_INDEX
    b.ne Ljs_expression_error
Ljs_assignment_valid:
    cmp x21, #61
    b.ne Ljs_assignment_keep
    str x9, [x19, #JS_CODE_COUNT]
Ljs_assignment_keep:
    mov x0, x19
    mov x1, x21
    bl _js_accept
    mov x0, x19
    mov x1, #1
    bl js_expression
    cmp x21, #61
    b.eq Ljs_assignment_store
    mov x25, #43
    cmp x21, #T_SUB_SET
    mov x9, #45
    csel x25, x9, x25, eq
    JS_EMIT J_BINARY, x25, #0, #0
Ljs_assignment_store:
    mov x25, #J_STORE
    cmp x23, #J_GET
    mov x9, #J_SET
    csel x25, x9, x25, eq
    cmp x23, #J_INDEX
    mov x9, #J_PUT_INDEX
    csel x25, x9, x25, eq
    mov x0, x19
    mov x1, x25
    mov x2, x24
    mov x3, #0
    mov x4, #0
    bl _js_emit
    b Ljs_expression_next
Ljs_expression_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_expression_done:
    mov x0, x19
    bl js_parse_leave
    LEAVE
// token -> binding power (0 means not an infix operator).
js_precedence:
    cmp x0, #61
    b.eq Ljs_prec_assign
    cmp x0, #T_ADD_SET
    b.eq Ljs_prec_assign
    cmp x0, #T_SUB_SET
    b.eq Ljs_prec_assign
    cmp x0, #T_OR
    b.eq Ljs_prec_or
    cmp x0, #T_AND
    b.eq Ljs_prec_and
    cmp x0, #T_EQ
    b.lo Ljs_prec_ascii
    cmp x0, #T_STRICT_NE
    b.ls Ljs_prec_equal
    cmp x0, #T_LE
    b.eq Ljs_prec_compare
    cmp x0, #T_GE
    b.eq Ljs_prec_compare
    b Ljs_prec_none
Ljs_prec_ascii:
    cmp x0, #60
    b.eq Ljs_prec_compare
    cmp x0, #62
    b.eq Ljs_prec_compare
    cmp x0, #43
    b.eq Ljs_prec_add
    cmp x0, #45
    b.eq Ljs_prec_add
    cmp x0, #42
    b.eq Ljs_prec_mul
    cmp x0, #47
    b.eq Ljs_prec_mul
    cmp x0, #37
    b.eq Ljs_prec_mul
Ljs_prec_none:
    mov x0, #0
    ret
Ljs_prec_assign:
    mov x0, #1
    ret
Ljs_prec_or:
    mov x0, #2
    ret
Ljs_prec_and:
    mov x0, #3
    ret
Ljs_prec_equal:
    mov x0, #4
    ret
Ljs_prec_compare:
    mov x0, #5
    ret
Ljs_prec_add:
    mov x0, #6
    ret
Ljs_prec_mul:
    mov x0, #7
    ret
// Prefix/primary expression followed by member accesses and calls.
js_atom:
    ENTER
    mov x19, x0
    bl _js_peek
    mov x20, x0
    mov x21, x1
    mov x22, x2
    cmp x20, #33
    b.eq Ljs_unary
    cmp x20, #45
    b.eq Ljs_unary
    cmp x20, #43
    b.eq Ljs_unary
    cmp x20, #T_IDENT
    b.ne Ljs_atom_literal
    mov x0, x19
    ADDR x1, js_kw_typeof
    bl _js_word
    cbnz x0, Ljs_atom_typeof
    mov x0, x19
    ADDR x1, js_kw_function
    bl _js_word
    cbnz x0, Ljs_atom_function
    mov x0, x19
    ADDR x1, js_kw_new
    bl _js_word
    cbnz x0, Ljs_atom_new
    mov x0, x19
    mov x1, #T_IDENT
    bl _js_accept
    mov x0, x19
    bl _js_peek
    cmp x0, #T_ARROW
    b.eq Ljs_atom_arrow_id
    JS_EMIT J_LOAD, x22, #0, #0
    b Ljs_postfix
Ljs_atom_typeof:
    mov x20, #513
    mov x0, x19
    bl js_atom
    // typeof an unbound bare identifier does not throw.
    ldr x9, [x19, #JS_CODE_COUNT]
    cbz x9, Ljs_unary_emit
    sub x9, x9, #1
    ldr x10, [x19, #JS_CODE]
    add x10, x10, x9, lsl #5
    ldr x9, [x10]
    cmp x9, #J_LOAD
    b.ne Ljs_unary_emit
    mov x9, #1
    str x9, [x10, #16]
    b Ljs_unary_emit
Ljs_atom_function:
    mov x0, x19
    mov x1, #0
    mov x2, #0
    bl js_function_parse
    b Ljs_postfix
Ljs_atom_arrow_id:
    mov x0, x19
    mov x1, #2
    mov x2, x22
    bl js_function_parse
    b Ljs_postfix
Ljs_atom_new:
    // Constructors have the same bounded native call path. General custom
    // constructor/prototype semantics are deliberately not implemented yet.
    mov x0, x19
    bl js_parse_name
    mov x22, x0
    cbz x22, Ljs_constructor_unsupported
    mov x0, x22
    ADDR x1, js_constructor_promise
    bl _strcmp
    cbz x0, Ljs_constructor_ok
    mov x0, x22
    ADDR x1, js_constructor_array
    bl _strcmp
    cbz x0, Ljs_constructor_ok
    mov x0, x22
    ADDR x1, js_constructor_object
    bl _strcmp
    cbnz x0, Ljs_constructor_unsupported
Ljs_constructor_ok:
    JS_EMIT J_LOAD, x22, #0, #0
    b Ljs_postfix
Ljs_constructor_unsupported:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
    b Ljs_atom_done
Ljs_unary:
    mov x0, x19
    mov x1, x20
    bl _js_accept
    mov x0, x19
    bl js_atom
Ljs_unary_emit:
    JS_EMIT J_UNARY, x20, #0, #0
    b Ljs_atom_done
Ljs_atom_literal:
    cmp x20, #T_NUMBER
    b.eq Ljs_atom_push
    cmp x20, #T_STRING
    b.eq Ljs_atom_push
    cmp x20, #40
    b.eq Ljs_atom_parenthesis
    cmp x20, #123
    b.eq Ljs_atom_object
    cmp x20, #91
    b.eq Ljs_atom_array
    b Ljs_atom_error
Ljs_atom_push:
    mov x0, x19
    mov x1, x20
    bl _js_accept
    JS_EMIT J_PUSH, x21, #0, #0
    b Ljs_postfix
Ljs_atom_parenthesis:
    // Recognize only a bounded parameter-list prefix followed by =>.
    ldr x9, [x19, #JS_POS]
    add x9, x9, #1
    ldr x10, [x19, #JS_TOKENS]
    mov x11, #0
Ljs_arrow_scan:
    add x15, x10, x9, lsl #5
    ldr x12, [x15]
    cmp x12, #41
    b.eq Ljs_arrow_close
    cmp x12, #T_IDENT
    b.ne Ljs_atom_grouped
    add x11, x11, #1
    cmp x11, #8
    b.hi Ljs_atom_grouped
    add x9, x9, #1
    add x15, x10, x9, lsl #5
    ldr x12, [x15]
    cmp x12, #41
    b.eq Ljs_arrow_close
    cmp x12, #44
    b.ne Ljs_atom_grouped
    add x9, x9, #1
    b Ljs_arrow_scan
Ljs_arrow_close:
    add x9, x9, #1
    add x15, x10, x9, lsl #5
    ldr x12, [x15]
    cmp x12, #T_ARROW
    b.ne Ljs_atom_grouped
    mov x0, x19
    mov x1, #1
    mov x2, #0
    bl js_function_parse
    b Ljs_postfix
Ljs_atom_grouped:
    mov x0, x19
    mov x1, #40
    bl _js_expect
    mov x0, x19
    mov x1, #0
    bl js_expression
    mov x0, x19
    mov x1, #41
    bl _js_expect
    b Ljs_postfix
Ljs_atom_object:
    mov x0, x19
    mov x1, #123
    bl _js_accept
    JS_EMIT J_OBJECT, #0, #0, #0
Ljs_object_next:
    mov x0, x19
    mov x1, #125
    bl _js_accept
    cbnz x0, Ljs_postfix
    mov x0, x19
    bl _js_peek
    cmp x0, #T_IDENT
    b.eq Ljs_object_key
    cmp x0, #T_STRING
    b.ne Ljs_atom_error
Ljs_object_key:
    mov x20, x2
    mov x21, x0
    mov x0, x19
    mov x1, x21
    bl _js_accept
    JS_EMIT J_DUP, #0, #0, #0
    mov x0, x19
    mov x1, #58
    bl _js_accept
    cbz x0, Ljs_object_shorthand
    mov x0, x19
    mov x1, #0
    bl js_expression
    b Ljs_object_store
Ljs_object_shorthand:
    cmp x21, #T_IDENT
    b.ne Ljs_atom_error
    JS_EMIT J_LOAD, x20, #0, #0
Ljs_object_store:
    JS_EMIT J_SET, x20, #0, #0
    JS_EMIT J_POP, #0, #0, #0
    mov x0, x19
    mov x1, #44
    bl _js_accept
    cbnz x0, Ljs_object_next
    mov x0, x19
    mov x1, #125
    bl _js_expect
    b Ljs_postfix
Ljs_atom_array:
    mov x0, x19
    mov x1, #91
    bl _js_accept
    JS_EMIT J_ARRAY, #0, #0, #0
    mov x20, #0
Ljs_array_next:
    mov x0, x19
    mov x1, #93
    bl _js_accept
    cbnz x0, Ljs_postfix
    cmp x20, #256
    b.hs Ljs_atom_error
    mov x0, x19
    mov x1, x20
    bl _js_integer
    mov x1, x0
    mov x0, x19
    bl _js_to_string
    cbz x0, Ljs_atom_error
    ldr x21, [x0, #8]
    JS_EMIT J_DUP, #0, #0, #0
    mov x0, x19
    mov x1, #0
    bl js_expression
    JS_EMIT J_SET, x21, #0, #0
    JS_EMIT J_POP, #0, #0, #0
    add x20, x20, #1
    mov x0, x19
    mov x1, #44
    bl _js_accept
    cbnz x0, Ljs_array_next
    mov x0, x19
    mov x1, #93
    bl _js_expect
Ljs_postfix:
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_atom_done
    mov x0, x19
    mov x1, #46
    bl _js_accept
    cbnz x0, Ljs_postfix_member
    mov x0, x19
    mov x1, #91
    bl _js_accept
    cbnz x0, Ljs_postfix_index
    mov x0, x19
    mov x1, #40
    bl _js_accept
    cbnz x0, Ljs_postfix_call
    mov x0, x19
    bl _js_peek
    mov x20, x0
    cmp x20, #T_INC
    b.eq Ljs_postfix_increment
    cmp x20, #T_DEC
    b.eq Ljs_postfix_increment
    b Ljs_atom_done
Ljs_postfix_member:
    mov x0, x19
    bl js_parse_name
    mov x20, x0
    JS_EMIT J_GET, x20, #0, #0
    b Ljs_postfix
Ljs_postfix_index:
    mov x0, x19
    mov x1, #0
    bl js_expression
    mov x0, x19
    mov x1, #93
    bl _js_expect
    JS_EMIT J_INDEX, #0, #0, #0
    b Ljs_postfix
Ljs_postfix_call:
    mov x20, #0
    mov x0, x19
    mov x1, #41
    bl _js_accept
    cbnz x0, Ljs_postfix_call_emit
Ljs_call_argument:
    cmp x20, #8
    b.hs Ljs_atom_error
    mov x0, x19
    mov x1, #0
    bl js_expression
    add x20, x20, #1
    mov x0, x19
    mov x1, #44
    bl _js_accept
    cbnz x0, Ljs_call_argument
    mov x0, x19
    mov x1, #41
    bl _js_expect
Ljs_postfix_call_emit:
    JS_EMIT J_CALL, x20, #0, #0
    b Ljs_postfix
Ljs_postfix_increment:
    ldr x9, [x19, #JS_CODE_COUNT]
    cbz x9, Ljs_atom_error
    sub x9, x9, #1
    ldr x10, [x19, #JS_CODE]
    add x10, x10, x9, lsl #5
    ldr x9, [x10]
    cmp x9, #J_LOAD
    b.ne Ljs_atom_error
    ldr x21, [x10, #8]
    mov x0, x19
    mov x1, x20
    bl _js_accept
    JS_EMIT J_DUP, #0, #0, #0
    mov x0, x19
    mov x1, #1
    bl _js_integer
    JS_EMIT J_PUSH, x0, #0, #0
    mov x22, #43
    mov x9, #45
    cmp x20, #T_DEC
    csel x22, x9, x22, eq
    JS_EMIT J_BINARY, x22, #0, #0
    JS_EMIT J_STORE, x21, #0, #0
    JS_EMIT J_POP, #0, #0, #0
    b Ljs_atom_done
Ljs_atom_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
Ljs_atom_done:
    LEAVE
// mode 0=function,1=parenthesized arrow,2=single-name arrow; x2 name for mode2.
js_function_parse:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x1, #64
    bl _js_alloc
    cbz x0, Ljs_function_done
    mov x22, x0
    mov x23, #0
    cmp x20, #2
    b.eq Ljs_function_single
    mov x0, x19
    mov x1, #40
    bl _js_expect
    mov x0, x19
    mov x1, #41
    bl _js_accept
    cbnz x0, Ljs_function_parameters_done
Ljs_function_parameter:
    cmp x23, #8
    b.hs Ljs_function_error
    mov x0, x19
    bl js_parse_name
    str x0, [x22, x23, lsl #3]
    add x23, x23, #1
    mov x0, x19
    mov x1, #44
    bl _js_accept
    cbnz x0, Ljs_function_parameter
    mov x0, x19
    mov x1, #41
    bl _js_expect
    b Ljs_function_parameters_done
Ljs_function_single:
    str x21, [x22]
    mov x23, #1
Ljs_function_parameters_done:
    cbz x20, Ljs_function_body
    mov x0, x19
    mov x1, #T_ARROW
    bl _js_expect
Ljs_function_body:
    JS_EMIT J_JUMP, #0, #0, #0
    mov x24, x0
    ldr x25, [x19, #JS_CODE_COUNT]
    ldr x26, [x19, #JS_SOURCE_DEPTH]
    add x9, x26, #1
    str x9, [x19, #JS_SOURCE_DEPTH]
    mov x0, x19
    bl _js_peek
    cmp x0, #123
    b.eq Ljs_function_block
    cbz x20, Ljs_function_error
    mov x0, x19
    mov x1, #0
    bl js_expression
    JS_EMIT J_RETURN, #0, #0, #0
    b Ljs_function_finish
Ljs_function_block:
    mov x0, x19
    bl js_statement
    JS_EMIT J_PUSH, #0, #0, #0
    JS_EMIT J_RETURN, #0, #0, #0
Ljs_function_finish:
    str x26, [x19, #JS_SOURCE_DEPTH]
    mov x0, x19
    mov x1, x24
    bl _js_patch
    JS_EMIT J_FUNCTION, x25, x22, x23
Ljs_function_done:
    LEAVE
Ljs_function_error:
    mov x9, #1
    str x9, [x19, #JS_ERROR]
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_kw_let: .asciz "let"
js_kw_const: .asciz "const"
js_kw_var: .asciz "var"
js_kw_function: .asciz "function"
js_kw_return: .asciz "return"
js_kw_if: .asciz "if"
js_kw_else: .asciz "else"
js_kw_while: .asciz "while"
js_kw_for: .asciz "for"
js_kw_typeof: .asciz "typeof"
js_kw_new: .asciz "new"
.section __DATA,__const
.p2align 3
js_decl_names: .quad js_kw_let,js_kw_const,js_kw_var
.text
// Compile an event attribute as a function, without eval or global variables.
.globl _js_inline_handler
_js_inline_handler:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x19, #JS_CODE_COUNT]
    str xzr, [x19, #JS_ERROR]
    str xzr, [x19, #JS_PARSE_DEPTH]
    mov x9, #1
    str x9, [x19, #JS_SOURCE_DEPTH]
    mov x0, x22
    bl _strlen
    mov x2, x0
    mov x1, x22
    mov x0, x19
    bl _js_lex
    cbz x0, Ljs_inline_invalid
    mov x0, x19
    bl _js_compile
    ldr x9, [x19, #JS_ERROR]
    cbnz x9, Ljs_inline_invalid
    mov x0, x19
    mov x1, #64
    bl _js_alloc
    cbz x0, Ljs_inline_invalid
    mov x24, x0
    ADDR x9, js_inline_event_parameter
    str x9, [x24]
    mov x0, x19
    mov x1, #JS_FUNCTION
    bl _js_value
    cbz x0, Ljs_inline_invalid
    str x23, [x0, #8]
    ldr x9, [x19, #JS_ENV]
    str x9, [x0, #16]
    str x24, [x0, #24]
    mov x3, x0
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x4, #1
    bl _js_listen
    b Ljs_inline_done
Ljs_inline_invalid:
    str x23, [x19, #JS_CODE_COUNT]
    str xzr, [x19, #JS_ERROR]
Ljs_inline_done:
    str xzr, [x19, #JS_SOURCE_DEPTH]
    LEAVE
.section __TEXT,__cstring,cstring_literals
js_inline_event_parameter: .asciz "event"

js_constructor_promise: .asciz "Promise"
js_constructor_array: .asciz "Array"
js_constructor_object: .asciz "Object"
