// Collapsing vertical margin sets, in ARM64. Each endpoint is union-find state
// with max-positive/min-negative contributions; sums are never substituted for
// CSS collapsing. Scratch is bounded to 128 bytes per retained flow node.
.include "src/mac/mac.inc"
.include "src/engine/engine.inc"
.include "src/engine/css.inc"
.text
.p2align 2
.globl _engine_margin_reset
_engine_margin_reset:
    ldr x1, [x0, #72]
    ldr x2, [x0, #24]
Lmargin_reset:
    cbz x2, Lmargin_reset_done
    str xzr, [x1, #FLOW_BEFORE]
    str xzr, [x1, #FLOW_AFTER]
    add x1, x1, #CSS_META_SIZE
    sub x2, x2, #1
    b Lmargin_reset
Lmargin_reset_done:
    ret

// base,endpoint(2*node+side) -> endpoint record pointer.
margin_endpoint:
    lsr x9, x1, #1
    add x0, x0, x9, lsl #7
    and x9, x1, #1
    add x0, x0, x9, lsl #5
    ret

// base,endpoint -> root endpoint, with path compression at the queried node.
margin_find:
    mov x2, x0
    lsr x9, x1, #1
    add x3, x2, x9, lsl #7
    and x9, x1, #1
    add x3, x3, x9, lsl #5
    mov x4, x3
Lmargin_find:
    ldr x5, [x4]
    cmp x5, x1
    b.eq Lmargin_find_done
    mov x1, x5
    lsr x9, x1, #1
    add x4, x2, x9, lsl #7
    and x9, x1, #1
    add x4, x4, x9, lsl #5
    b Lmargin_find
Lmargin_find_done:
    str x1, [x3]
    mov x0, x1
    ret

// base,endpointA,endpointB. Root choice places the resulting margin outside
// the shallowest containing box; equal-depth top margins precede bottoms.
margin_union:
    ENTER
    mov x19, x0
    mov x20, x2
    bl margin_find
    mov x21, x0
    mov x0, x19
    mov x1, x20
    bl margin_find
    mov x20, x0
    cmp x20, x21
    b.eq Lmargin_union_done
    mov x0, x19
    mov x1, x21
    bl margin_endpoint
    mov x22, x0
    mov x0, x19
    mov x1, x20
    bl margin_endpoint
    mov x23, x0
    ldr x9, [x22, #24]
    ldr x10, [x23, #24]
    cmp x9, x10
    b.ls Lmargin_union_root
    mov x9, x22
    mov x22, x23
    mov x23, x9
    mov x9, x21
    mov x21, x20
    mov x20, x9
Lmargin_union_root:
    str x21, [x23]
    ldr x9, [x22, #8]
    ldr x10, [x23, #8]
    cmp x9, x10
    csel x9, x10, x9, lt
    str x9, [x22, #8]
    ldr x9, [x22, #16]
    ldr x10, [x23, #16]
    cmp x9, x10
    csel x9, x10, x9, gt
    str x9, [x22, #16]
Lmargin_union_done:
    LEAVE

// metadata,node kind -> establishes a formatting context / disallows child
// margin escape. Ordinary relative-positioned blocks still collapse margins.
.globl _engine_formatting_context
_engine_formatting_context:
margin_bfc:
    ldr x9, [x0, #88]
    cmp x9, #3
    b.hs Lmargin_bfc_yes
    ldr x9, [x0, #(32+CSS_FLOAT*8)]
    cbnz x9, Lmargin_bfc_yes
    ldr x9, [x0, #(1840+(CSS_POSITION-48)*8)]
    cmp x9, #2
    b.hs Lmargin_bfc_yes
    ldr x9, [x0, #(1840+(CSS_OVERFLOW_X-48)*8)]
    cmp x9, #1
    b.eq Lmargin_bfc_yes
    cmp x9, #2
    b.eq Lmargin_bfc_yes
    ldr x9, [x0, #(1840+(CSS_OVERFLOW_Y-48)*8)]
    cmp x9, #1
    b.eq Lmargin_bfc_yes
    cmp x9, #2
    b.eq Lmargin_bfc_yes
    cmp x1, #NODE_TABLE
    b.eq Lmargin_bfc_yes
    cmp x1, #NODE_TD
    b.eq Lmargin_bfc_yes
    cmp x1, #NODE_TH
    b.eq Lmargin_bfc_yes
    mov x0, #0
    ret
Lmargin_bfc_yes:
    mov x0, #1
    ret

// doc,index -> 0 ignored, 1 block margin endpoints, 2 other inflow content.
margin_kind:
    ldr x2, [x0, #72]
    add x2, x2, x1, lsl #11
    ldr x3, [x0, #16]
    mov x4, #40
    madd x3, x1, x4, x3
    ldr x3, [x3]
    ldr x4, [x2, #88]
    cmp x4, #1
    b.eq Lmargin_kind_ignored
    cmp x3, #NODE_SHEET
    b.eq Lmargin_kind_ignored
    cmp x3, #NODE_LINK
    b.eq Lmargin_kind_ignored
    ldr x5, [x2, #FLOW_OWNER]
    cbnz x5, Lmargin_kind_other
    ldr x5, [x2, #(32+CSS_FLOAT*8)]
    cbnz x5, Lmargin_kind_ignored
    ldr x5, [x2, #(1840+(CSS_POSITION-48)*8)]
    cmp x5, #2
    b.hs Lmargin_kind_ignored
    cmp x4, #2
    b.eq Lmargin_kind_other
    cmp x4, #5
    b.eq Lmargin_kind_other
    cmp x3, #NODE_ROOT
    b.eq Lmargin_kind_other
    cmp x3, #NODE_HTML
    b.eq Lmargin_kind_other
    cmp x3, #NODE_TEXT
    b.eq Lmargin_kind_other
    cmp x3, #NODE_BR
    b.eq Lmargin_kind_other
    cmp x3, #NODE_TR
    b.eq Lmargin_kind_other
    cmp x3, #NODE_TD
    b.eq Lmargin_kind_other
    cmp x3, #NODE_TH
    b.eq Lmargin_kind_other
    cmp x3, #NODE_TBODY
    b.eq Lmargin_kind_other
    cmp x3, #NODE_THEAD
    b.eq Lmargin_kind_other
    cmp x3, #NODE_TFOOT
    b.eq Lmargin_kind_other
    mov x0, #1
    ret
Lmargin_kind_other:
    mov x0, #2
    ret
Lmargin_kind_ignored:
    mov x0, #0
    ret

// doc,index -> own content permits an empty, collapsing-through box. Child
// nonempty state is propagated in reverse tree order by the caller.
margin_empty_seed:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #72]
    add x21, x21, x20, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x22, x20, x10, x9
    ldr x23, [x22]
    cmp x23, #NODE_TEXT
    b.eq Lmargin_empty_text
    cmp x23, #NODE_INPUT
    b.eq Lmargin_not_empty
    cmp x23, #NODE_IMG
    b.eq Lmargin_not_empty
    cmp x23, #NODE_SVG
    b.eq Lmargin_not_empty
    cmp x23, #NODE_BR
    b.eq Lmargin_not_empty
    cmp x23, #NODE_BUTTON
    b.eq Lmargin_not_empty
    cmp x23, #NODE_SELECT
    b.eq Lmargin_not_empty
    cmp x23, #NODE_TEXTAREA
    b.eq Lmargin_not_empty
    mov x0, x21
    mov x1, x23
    bl margin_bfc
    cbnz x0, Lmargin_not_empty
    ldr x9, [x21, #152]
    cmp x9, #0
    b.gt Lmargin_not_empty
    ldr x9, [x21, #(32+CSS_MIN_HEIGHT*8)]
    cmp x9, #0
    b.gt Lmargin_not_empty
    add x11, x21, #824
    ldp x9, x10, [x11]
    orr x9, x9, x10
    ldr x10, [x21, #BOX_BORDER_TOP]
    orr x9, x9, x10
    ldr x10, [x21, #BOX_BORDER_BOTTOM]
    orr x9, x9, x10
    cbnz x9, Lmargin_not_empty
    b Lmargin_is_empty
Lmargin_empty_text:
    ldr x9, [x22, #16]
    ldr x10, [x22, #24]
    ldr x11, [x19]
Lmargin_whitespace:
    cmp x9, x10
    b.hs Lmargin_is_empty
    ldrb w12, [x11, x9]
    cmp w12, #32
    b.hi Lmargin_not_empty
    add x9, x9, #1
    b Lmargin_whitespace
Lmargin_is_empty:
    mov x0, #1
    LEAVE
Lmargin_not_empty:
    mov x0, #0
    LEAVE

.globl _engine_margin_tree
_engine_margin_tree:
    ENTER
    mov x19, x0
    ldr x20, [x19, #24]
    mov x0, x20
    mov x1, #128
    bl _calloc
    cbz x0, Lmargin_tree_done
    mov x21, x0
    mov x22, #0
Lmargin_init:
    cmp x22, x20
    b.hs Lmargin_reverse_begin
    ldr x23, [x19, #72]
    add x23, x23, x22, lsl #11
    add x24, x21, x22, lsl #7
    // A repeated render starts from authored margins, not prior collapse deltas.
    ldr x9, [x23, #FLOW_OWNER]
    cbnz x9, Lmargin_init_depth
    str xzr, [x23, #FLOW_BEFORE]
    str xzr, [x23, #FLOW_AFTER]
    cbz x22, Lmargin_init_depth
    mov x0, x23
    ldr x1, [x23, #848]
    bl _engine_box_metrics
Lmargin_init_depth:
    mov x25, #0
    cbz x22, Lmargin_init_kind
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x22, x10, x9
    ldr x9, [x9, #8]
    add x9, x21, x9, lsl #7
    ldr x25, [x9, #96]
    add x25, x25, #1
Lmargin_init_kind:
    str x25, [x24, #96]
    mov x0, x19
    mov x1, x22
    bl margin_kind
    str x0, [x24, #64]
    mov x0, x19
    mov x1, x22
    bl margin_empty_seed
    str x0, [x24, #88]
    // Content itself can be empty even when padding/height prevents margin
    // collapse through the box. That distinction removes phantom marker lines.
    mov x9, #1
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x22, x11, x10
    ldr x10, [x10]
    cmp x10, #NODE_TEXT
    csel x9, x0, x9, eq
    cmp x10, #NODE_INPUT
    b.eq Lmargin_init_nonempty
    cmp x10, #NODE_IMG
    b.eq Lmargin_init_nonempty
    cmp x10, #NODE_SVG
    b.eq Lmargin_init_nonempty
    cmp x10, #NODE_BR
    b.eq Lmargin_init_nonempty
    cmp x10, #NODE_BUTTON
    b.eq Lmargin_init_nonempty
    cmp x10, #NODE_SELECT
    b.eq Lmargin_init_nonempty
    cmp x10, #NODE_TEXTAREA
    b.ne Lmargin_init_content
Lmargin_init_nonempty:
    mov x9, #0
Lmargin_init_content:
    str x9, [x24, #112]
    mov x26, #0
Lmargin_init_endpoint:
    add x27, x24, x26, lsl #5
    lsl x9, x22, #1
    add x9, x9, x26
    str x9, [x27]
    add x9, x23, #792
    ldr x9, [x9, x26, lsl #3]
    cmp x9, #0
    csel x10, x9, xzr, gt
    csel x11, x9, xzr, lt
    stp x10, x11, [x27, #8]
    lsl x10, x25, #32
    lsl x11, x26, #31
    orr x10, x10, x11
    orr x10, x10, x22
    str x10, [x27, #24]
    add x26, x26, #1
    cmp x26, #2
    b.lo Lmargin_init_endpoint
    add x22, x22, #1
    b Lmargin_init
Lmargin_reverse_begin:
    mov x22, x20
Lmargin_reverse:
    cmp x22, #1
    b.ls Lmargin_siblings_begin
    sub x22, x22, #1
    add x24, x21, x22, lsl #7
    ldr x9, [x24, #64]
    cbz x9, Lmargin_reverse
    ldr x9, [x24, #88]
    cbnz x9, Lmargin_reverse
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x22, x10, x9
    ldr x9, [x9, #8]
    add x9, x21, x9, lsl #7
    str xzr, [x9, #88]
    str xzr, [x9, #112]
    b Lmargin_reverse
Lmargin_siblings_begin:
    mov x22, #1
Lmargin_sibling:
    cmp x22, x20
    b.hs Lmargin_parents_begin
    add x24, x21, x22, lsl #7
    ldr x9, [x24, #64]
    cbz x9, Lmargin_sibling_next
    ldr x10, [x19, #16]
    mov x11, #40
    madd x10, x22, x11, x10
    ldr x10, [x10, #8]
    add x25, x21, x10, lsl #7
    cmp x9, #1
    b.ne Lmargin_sibling_inline
    ldr x9, [x25, #72]
    cbz x9, Lmargin_sibling_first
    sub x9, x9, #1
    lsl x1, x9, #1
    add x1, x1, #1
    lsl x2, x22, #1
    mov x0, x21
    bl margin_union
Lmargin_sibling_first:
    ldr x9, [x25, #104]
    cbnz x9, Lmargin_sibling_store
    add x9, x22, #1
    str x9, [x25, #80]
Lmargin_sibling_store:
    add x9, x22, #1
    str x9, [x25, #72]
    mov x9, #1
    str x9, [x25, #104]
    ldr x9, [x24, #88]
    cbz x9, Lmargin_sibling_next
    mov x0, x21
    lsl x1, x22, #1
    add x2, x1, #1
    bl margin_union
    b Lmargin_sibling_next
Lmargin_sibling_inline:
    ldr x9, [x24, #88]
    cbnz x9, Lmargin_sibling_next  // collapsible whitespace is not a barrier
    str xzr, [x25, #72]
    mov x9, #1
    str x9, [x25, #104]
Lmargin_sibling_next:
    add x22, x22, #1
    b Lmargin_sibling
Lmargin_parents_begin:
    mov x22, #1
Lmargin_parent:
    cmp x22, x20
    b.hs Lmargin_store_begin
    add x24, x21, x22, lsl #7
    ldr x9, [x24, #64]
    cmp x9, #1
    b.ne Lmargin_parent_next
    ldr x23, [x19, #72]
    add x23, x23, x22, lsl #11
    ldr x9, [x19, #16]
    mov x10, #40
    madd x9, x22, x10, x9
    ldr x1, [x9]
    mov x0, x23
    bl margin_bfc
    cbnz x0, Lmargin_parent_next
    ldr x9, [x23, #824]
    ldr x10, [x23, #BOX_BORDER_TOP]
    orr x9, x9, x10
    cbnz x9, Lmargin_parent_bottom
    ldr x9, [x24, #80]
    cbz x9, Lmargin_parent_bottom
    sub x9, x9, #1
    lsl x2, x9, #1
    lsl x1, x22, #1
    mov x0, x21
    bl margin_union
Lmargin_parent_bottom:
    ldr x9, [x23, #152]
    cmn x9, #1
    b.ne Lmargin_parent_next
    ldr x9, [x23, #(32+CSS_MIN_HEIGHT*8)]
    cmp x9, #0
    b.gt Lmargin_parent_next
    ldr x9, [x23, #832]
    ldr x10, [x23, #BOX_BORDER_BOTTOM]
    orr x9, x9, x10
    cbnz x9, Lmargin_parent_next
    ldr x9, [x24, #72]
    cbz x9, Lmargin_parent_next
    sub x9, x9, #1
    lsl x2, x9, #1
    add x2, x2, #1
    lsl x1, x22, #1
    add x1, x1, #1
    mov x0, x21
    bl margin_union
Lmargin_parent_next:
    add x22, x22, #1
    b Lmargin_parent
Lmargin_store_begin:
    mov x22, #1
Lmargin_store:
    cmp x22, x20
    b.hs Lmargin_tree_free
    add x24, x21, x22, lsl #7
    ldr x9, [x24, #64]
    cmp x9, #1
    b.ne Lmargin_store_next
    ldr x23, [x19, #72]
    add x23, x23, x22, lsl #11
    ldr x9, [x24, #112]
    str x9, [x23, #NATIVE_EMPTY]
    mov x25, #0
Lmargin_store_side:
    lsl x26, x22, #1
    add x26, x26, x25
    mov x0, x21
    mov x1, x26
    bl margin_find
    cmp x0, x26
    b.ne Lmargin_store_zero
    mov x1, x0
    mov x0, x21
    bl margin_endpoint
    ldp x9, x10, [x0, #8]
    add x27, x9, x10
    b Lmargin_store_value
Lmargin_store_zero:
    mov x27, #0
Lmargin_store_value:
    add x9, x23, #792
    ldr x10, [x9, x25, lsl #3]
    str x27, [x9, x25, lsl #3]
    sub x10, x27, x10
    add x9, x23, #FLOW_BEFORE
    str x10, [x9, x25, lsl #3]
    add x25, x25, #1
    cmp x25, #2
    b.lo Lmargin_store_side
Lmargin_store_next:
    add x22, x22, #1
    b Lmargin_store
Lmargin_tree_free:
    mov x0, x21
    bl _free
Lmargin_tree_done:
    LEAVE
