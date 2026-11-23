.include "src/mac/mac.inc"
.include "src/engine/js.inc"
.include "src/engine/dom.inc"
.text
// vm,handle,create -> stable native-control/expando record (64 bytes).
.globl _js_control_record
_js_control_record:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #232]
Ljs_control_find:
    cbz x22, Ljs_control_create
    ldr x9, [x22]
    cmp x9, x20
    b.eq Ljs_control_found
    ldr x22, [x22, #24]
    b Ljs_control_find
Ljs_control_create:
    cbz x21, Ljs_control_found
    mov x0, x19
    mov x1, #64
    bl _js_alloc
    mov x22, x0
    cbz x0, Ljs_control_found
    str x20, [x22]
    ldr x9, [x19, #232]
    str x9, [x22, #24]
    str x22, [x19, #232]
Ljs_control_found:
    mov x0, x22
    LEAVE
.globl _js_node
_js_node:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x0, [x19, #JS_DOM]
    bl _engine_dom_node
    cbz x0, Ljs_node_null
    mov x0, x19
    mov x1, x20
    mov x2, #1
    bl _js_control_record
    cbz x0, Ljs_node_null
    mov x21, x0
    ldr x0, [x21, #40]
    cbnz x0, Ljs_node_done
    mov x0, x19
    mov x1, #JS_NODE
    bl _js_value
    cbz x0, Ljs_node_done
    str x20, [x0, #8]
    str x0, [x21, #40]
    b Ljs_node_done
Ljs_node_null:
    mov x0, #1
Ljs_node_done:
    LEAVE
// dom,handle,output or NULL,offset -> UTF8 bytes. Recursion follows bounded DOM.
js_text_walk:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    bl _engine_dom_node
    cbz x0, Ljs_text_walk_done
    mov x22, x0
    ldr x9, [x22]
    cmp x9, #DOM_TEXT
    b.eq Ljs_text_walk_leaf
    cmp x9, #DOM_COMMENT
    b.eq Ljs_text_walk_done
    ldr x23, [x22, #16]
Ljs_text_walk_child:
    cbz x23, Ljs_text_walk_done
    mov x0, x19
    mov x1, x23
    mov x2, x20
    mov x3, x21
    bl js_text_walk
    mov x21, x0
    mov x0, x19
    mov x1, x23
    bl _engine_dom_node
    ldr x23, [x0, #40]
    b Ljs_text_walk_child
Ljs_text_walk_leaf:
    ldr x22, [x22, #56]
    cbz x22, Ljs_text_walk_done
    mov x0, x22
    bl _strlen
    mov x24, x0
    cbz x20, Ljs_text_walk_add
    add x0, x20, x21
    mov x1, x22
    mov x2, x24
    bl _memcpy
Ljs_text_walk_add:
    add x21, x21, x24
Ljs_text_walk_done:
    mov x0, x21
    LEAVE
.globl _js_dom_text
_js_dom_text:
    ENTER
    mov x19, x0
    mov x20, x1
    ldr x0, [x19, #JS_DOM]
    mov x2, #0
    mov x3, #0
    bl js_text_walk
    mov x21, x0
    mov x9, #JS_MAX_SOURCE
    cmp x21, x9
    b.hi Ljs_dom_text_limit
    mov x0, x19
    add x1, x21, #1
    bl _js_alloc
    cbz x0, Ljs_dom_text_done
    mov x22, x0
    ldr x0, [x19, #JS_DOM]
    mov x1, x20
    mov x2, x22
    mov x3, #0
    bl js_text_walk
    mov x0, x19
    mov x1, x22
    mov x2, x21
    bl _js_string
Ljs_dom_text_done:
    LEAVE
Ljs_dom_text_limit:
    mov x9, #3
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
// vm,handle,attribute -> JS string (empty if absent).
.globl _js_attribute
_js_attribute:
    ENTER
    mov x19, x0
    ldr x0, [x19, #JS_DOM]
    bl _engine_dom_get_attribute
    cbnz x0, Ljs_attribute_text
    ADDR x0, js_dom_empty
Ljs_attribute_text:
    mov x1, x0
    mov x0, x19
    bl _js_cstring
    LEAVE
// vm,receiver,key -> JS value.
.globl _js_dom_get
_js_dom_get:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x20, #8]
    ldr x23, [x20]
    cmp x23, #JS_STYLE
    b.eq Ljs_dom_get_style
    cmp x23, #JS_CLASSES
    b.eq Ljs_dom_get_classes
    ADDR x24, js_dom_methods
Ljs_dom_method:
    ldr x1, [x24]
    cbz x1, Ljs_dom_properties
    mov x0, x21
    bl _strcmp
    cbz x0, Ljs_dom_method_found
    add x24, x24, #16
    b Ljs_dom_method
Ljs_dom_method_found:
    ldr x1, [x24, #8]
    b Ljs_dom_bind
Ljs_dom_properties:
    mov x0, x21
    ADDR x1, js_dom_text_key
    bl _strcmp
    cbz x0, Ljs_dom_get_text
    mov x0, x21
    ADDR x1, js_dom_style_key
    bl _strcmp
    cbz x0, Ljs_dom_get_style_object
    mov x0, x21
    ADDR x1, js_dom_classlist_key
    bl _strcmp
    cbz x0, Ljs_dom_get_classes_object
    mov x0, x21
    ADDR x1, js_dom_children_key
    bl _strcmp
    cbz x0, Ljs_dom_get_children
    mov x0, x21
    ADDR x1, js_dom_parent_key
    bl _strcmp
    cbz x0, Ljs_dom_get_parent
    mov x0, x21
    ADDR x1, js_dom_first_key
    bl _strcmp
    cbz x0, Ljs_dom_get_first
    mov x0, x21
    ADDR x1, js_dom_next_key
    bl _strcmp
    cbz x0, Ljs_dom_get_next
    mov x0, x21
    ADDR x1, js_dom_value_key
    bl _strcmp
    cbz x0, Ljs_dom_get_value
    mov x0, x21
    ADDR x1, js_dom_checked_key
    bl _strcmp
    cbz x0, Ljs_dom_get_checked
    cmp x23, #JS_DOCUMENT
    b.eq Ljs_document_properties
Ljs_dom_attribute_property:
    mov x0, x21
    ADDR x1, js_dom_classname_key
    bl _strcmp
    cbnz x0, Ljs_dom_attribute_direct
    ADDR x21, js_dom_class_key
Ljs_dom_attribute_direct:
    ADDR x24, js_dom_attributes
Ljs_dom_attr_find:
    ldr x1, [x24], #8
    cbz x1, Ljs_dom_expando_get
    mov x0, x21
    bl _strcmp
    cbnz x0, Ljs_dom_attr_find
    mov x0, x19
    mov x1, x22
    mov x2, x21
    bl _js_attribute
    LEAVE
Ljs_dom_get_text:
    mov x0, x19
    mov x1, x22
    bl _js_dom_text
    LEAVE
Ljs_dom_get_style_object:
    mov x1, #JS_STYLE
    b Ljs_dom_wrapper
Ljs_dom_get_classes_object:
    mov x1, #JS_CLASSES
Ljs_dom_wrapper:
    mov x0, x19
    bl _js_value
    cbz x0, Ljs_dom_get_done
    str x22, [x0, #8]
Ljs_dom_get_done:
    LEAVE
Ljs_dom_get_parent:
    mov x24, #8
    b Ljs_dom_related
Ljs_dom_get_first:
    mov x24, #16
    b Ljs_dom_related
Ljs_dom_get_next:
    mov x24, #40
Ljs_dom_related:
    ldr x0, [x19, #JS_DOM]
    mov x1, x22
    bl _engine_dom_node
    cbz x0, Ljs_dom_get_null
    ldr x1, [x0, x24]
    mov x0, x19
    bl _js_node
    LEAVE
Ljs_dom_get_children:
    mov x0, x19
    mov x1, #JS_ARRAY
    bl _js_value
    mov x24, x0
    ldr x0, [x19, #JS_DOM]
    mov x1, x22
    bl _engine_dom_node
    cbz x0, Ljs_dom_get_null
    ldr x25, [x0, #16]
Ljs_dom_child_next:
    cbz x25, Ljs_dom_children_done
    ldr x0, [x19, #JS_DOM]
    mov x1, x25
    bl _engine_dom_node
    mov x26, x0
    ldr x9, [x0]
    cmp x9, #DOM_ELEMENT
    b.ne Ljs_dom_child_advance
    mov x0, x19
    mov x1, x25
    bl _js_node
    mov x2, x0
    mov x0, x19
    mov x1, x24
    bl _js_array_push
Ljs_dom_child_advance:
    ldr x25, [x26, #40]
    b Ljs_dom_child_next
Ljs_dom_children_done:
    mov x0, x24
    LEAVE
Ljs_dom_get_value:
    mov x0, x19
    mov x1, x22
    mov x2, #0
    bl _js_control_record
    cbz x0, Ljs_dom_value_attribute
    ldr x0, [x0, #8]
    cbnz x0, Ljs_dom_get_done
Ljs_dom_value_attribute:
    mov x0, x19
    mov x1, x22
    ADDR x2, js_dom_value_key
    bl _js_attribute
    LEAVE
Ljs_dom_get_checked:
    mov x0, x19
    mov x1, x22
    mov x2, #0
    bl _js_control_record
    cbz x0, Ljs_dom_checked_attribute
    ldr x0, [x0, #16]
    cbnz x0, Ljs_dom_get_done
Ljs_dom_checked_attribute:
    ldr x0, [x19, #JS_DOM]
    mov x1, x22
    ADDR x2, js_dom_checked_key
    bl _engine_dom_get_attribute
    cmp x0, #0
    cset x0, ne
    add x0, x0, #2
    LEAVE
Ljs_document_properties:
    mov x0, x21
    ADDR x1, js_dom_ready_key
    bl _strcmp
    cbz x0, Ljs_document_ready
    mov x0, x21
    ADDR x1, js_dom_body_key
    bl _strcmp
    cbz x0, Ljs_document_body
    mov x0, x21
    ADDR x1, js_dom_html_key
    bl _strcmp
    cbnz x0, Ljs_document_title_test
    ADDR x2, js_dom_html_tag
    b Ljs_document_query
Ljs_document_body:
    ADDR x2, js_dom_body_key
Ljs_document_query:
    mov x0, x19
    mov x1, #1
    mov x3, #0
    bl _js_query
    LEAVE
Ljs_document_title_test:
    mov x0, x21
    ADDR x1, js_dom_title_key
    bl _strcmp
    cbnz x0, Ljs_dom_attribute_property
    mov x0, x19
    mov x1, #1
    ADDR x2, js_dom_title_key
    mov x3, #0
    bl _js_query
    cmp x0, #3
    b.ls Ljs_dom_get_empty
    ldr x1, [x0, #8]
    mov x0, x19
    bl _js_dom_text
    LEAVE
Ljs_document_ready:
    ldr x9, [x19, #JS_READY]
    ADDR x10, js_ready_names
    ldr x1, [x10, x9, lsl #3]
    mov x0, x19
    bl _js_cstring
    LEAVE
Ljs_dom_get_classes:
    ADDR x24, js_class_methods
    b Ljs_dom_method
Ljs_dom_get_style:
    mov x0, x21
    ADDR x1, js_dom_setproperty_key
    bl _strcmp
    cbz x0, Ljs_dom_get_setproperty
    mov x0, x21
    ADDR x1, js_dom_getproperty_key
    bl _strcmp
    cbz x0, Ljs_dom_get_getproperty
    mov x0, x19
    mov x1, x22
    mov x2, x21
    bl _js_style_get
    LEAVE
Ljs_dom_get_setproperty:
    mov x1, #46
    b Ljs_dom_bind
Ljs_dom_get_getproperty:
    mov x1, #47
Ljs_dom_bind:
    mov x0, x19
    mov x2, x20
    bl _js_bound
    LEAVE
Ljs_dom_expando_get:
    mov x0, x19
    mov x1, x22
    mov x2, #0
    bl _js_control_record
    cbz x0, Ljs_dom_get_none
    ldr x0, [x0, #32]
    cbz x0, Ljs_dom_get_none
    mov x1, x21
    bl _js_property
    cbz x0, Ljs_dom_get_none
    ldr x0, [x0, #8]
    LEAVE
Ljs_dom_get_empty:
    mov x0, x19
    ADDR x1, js_dom_empty
    bl _js_cstring
    LEAVE
Ljs_dom_get_null:
    mov x0, #1
    LEAVE
Ljs_dom_get_none:
    mov x0, #0
    LEAVE
// vm,receiver,key,value -> value. DOM handles are revalidated on every write.
.globl _js_dom_set
_js_dom_set:
    ENTER
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x20, #8]
    ldr x0, [x19, #JS_DOM]
    mov x1, x23
    bl _engine_dom_node
    cbz x0, Ljs_dom_set_bad
    ldr x9, [x20]
    cmp x9, #JS_STYLE
    b.eq Ljs_dom_set_style
    mov x0, x21
    ADDR x1, js_dom_checked_key
    bl _strcmp
    cbz x0, Ljs_dom_set_checked
    mov x0, x19
    mov x1, x22
    bl _js_to_string
    cbz x0, Ljs_dom_set_bad
    mov x24, x0
    mov x0, x21
    ADDR x1, js_dom_text_key
    bl _strcmp
    cbz x0, Ljs_dom_set_text
    mov x0, x21
    ADDR x1, js_dom_value_key
    bl _strcmp
    cbz x0, Ljs_dom_set_value
    ldr x9, [x20]
    cmp x9, #JS_DOCUMENT
    b.ne Ljs_dom_set_attribute_test
    mov x0, x21
    ADDR x1, js_dom_title_key
    bl _strcmp
    cbz x0, Ljs_dom_set_title
Ljs_dom_set_attribute_test:
    mov x0, x21
    ADDR x1, js_dom_classname_key
    bl _strcmp
    cbnz x0, Ljs_dom_set_direct
    ADDR x21, js_dom_class_key
Ljs_dom_set_direct:
    ADDR x25, js_dom_attributes
Ljs_dom_set_attr_find:
    ldr x1, [x25], #8
    cbz x1, Ljs_dom_set_expando
    mov x0, x21
    bl _strcmp
    cbnz x0, Ljs_dom_set_attr_find
    ldr x0, [x19, #JS_DOM]
    mov x1, x23
    mov x2, x21
    ldr x3, [x24, #8]
    ldr x4, [x24, #16]
    bl _engine_dom_set_attribute
    b Ljs_dom_set_result
Ljs_dom_set_text:
    ldr x0, [x19, #JS_DOM]
    mov x1, x23
    ldr x2, [x24, #8]
    ldr x3, [x24, #16]
    bl _engine_dom_set_text_content
Ljs_dom_set_result:
    cbnz x0, Ljs_dom_set_bad
    mov x9, #1
    str x9, [x19, #JS_DOM_DIRTY]
    b Ljs_dom_set_done
Ljs_dom_set_title:
    mov x0, x19
    mov x1, #1
    ADDR x2, js_dom_title_key
    mov x3, #0
    bl _js_query
    cmp x0, #3
    b.hi Ljs_dom_title_existing
    ldr x0, [x19, #JS_DOM]
    ADDR x1, js_dom_title_key
    mov x2, #5
    bl _engine_dom_create_element
    mov x23, x0
    ldr x0, [x19, #JS_DOM]
    mov x1, #1
    mov x2, x23
    mov x3, #0
    bl _engine_dom_insert_before
    b Ljs_dom_set_text
Ljs_dom_title_existing:
    ldr x23, [x0, #8]
    b Ljs_dom_set_text
Ljs_dom_set_value:
    mov x0, x19
    mov x1, x23
    mov x2, #1
    bl _js_control_record
    cbz x0, Ljs_dom_set_bad
    str x24, [x0, #8]
    b Ljs_dom_control_dirty
Ljs_dom_set_checked:
    mov x0, x22
    bl _js_truth
    add x24, x0, #2
    mov x0, x19
    mov x1, x23
    mov x2, #1
    bl _js_control_record
    cbz x0, Ljs_dom_set_bad
    str x24, [x0, #16]
Ljs_dom_control_dirty:
    mov x9, #1
    str x9, [x19, #JS_CONTROL_DIRTY]
    b Ljs_dom_set_done
Ljs_dom_set_style:
    mov x0, x19
    mov x1, x23
    mov x2, x21
    mov x3, x22
    bl _js_style_set
    b Ljs_dom_set_done
Ljs_dom_set_expando:
    ldrb w9, [x21]
    cmp w9, #111
    b.ne Ljs_dom_expando_record
    ldrb w9, [x21, #1]
    cmp w9, #110
    b.ne Ljs_dom_expando_record
    mov x0, x19
    mov x1, x23
    add x2, x21, #2
    mov x3, x22
    mov x4, #1 // replace event property handler
    bl _js_listen
Ljs_dom_expando_record:
    mov x0, x19
    mov x1, x23
    mov x2, #1
    bl _js_control_record
    cbz x0, Ljs_dom_set_bad
    mov x25, x0
    ldr x0, [x25, #32]
    cbnz x0, Ljs_dom_expando_object
    mov x0, x19
    mov x1, #JS_OBJECT
    bl _js_value
    str x0, [x25, #32]
Ljs_dom_expando_object:
    mov x1, x0
    mov x0, x19
    mov x2, x21
    mov x3, x22
    mov x4, #0
    bl _js_property_set
Ljs_dom_set_done:
    mov x0, x22
    LEAVE
Ljs_dom_set_bad:
    mov x9, #4
    str x9, [x19, #JS_ERROR]
    mov x0, #0
    LEAVE
// Native editor changes update live properties without altering HTML defaults.
.globl _engine_js_control
_engine_js_control:
    ENTER
    mov x19, x0
    mov x20, x2
    mov x21, x3
    mov x22, x4
    mov x2, #1
    bl _js_control_record
    cbz x0, Ljs_control_fed
    mov x23, x0
    cbz x20, Ljs_control_feed_check
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _js_string
    str x0, [x23, #8]
Ljs_control_feed_check:
    tbnz x22, #63, Ljs_control_fed
    cmp x22, #0
    cset x9, ne
    add x9, x9, #2
    str x9, [x23, #16]
Ljs_control_fed:
    LEAVE
.globl _engine_js_control_read
_engine_js_control_read:
    mov x2, #0
    b _js_control_record
.section __TEXT,__cstring,cstring_literals
js_dom_empty: .asciz ""
js_dom_text_key: .asciz "textContent"
js_dom_style_key: .asciz "style"
js_dom_classlist_key: .asciz "classList"
js_dom_classname_key: .asciz "className"
js_dom_class_key: .asciz "class"
js_dom_children_key: .asciz "children"
js_dom_parent_key: .asciz "parentNode"
js_dom_first_key: .asciz "firstChild"
js_dom_next_key: .asciz "nextSibling"
js_dom_value_key: .asciz "value"
js_dom_checked_key: .asciz "checked"
js_dom_title_key: .asciz "title"
js_dom_ready_key: .asciz "readyState"
js_dom_body_key: .asciz "body"
js_dom_html_key: .asciz "documentElement"
js_dom_html_tag: .asciz "html"
js_dom_id_key: .asciz "id"
js_dom_href_key: .asciz "href"
js_dom_src_key: .asciz "src"
js_dom_name_key: .asciz "name"
js_dom_type_key: .asciz "type"
js_dom_disabled_key: .asciz "disabled"
js_dom_setproperty_key: .asciz "setProperty"
js_dom_getproperty_key: .asciz "getPropertyValue"
js_dom_getid: .asciz "getElementById"
js_dom_query: .asciz "querySelector"
js_dom_queryall: .asciz "querySelectorAll"
js_dom_create: .asciz "createElement"
js_dom_create_text: .asciz "createTextNode"
js_dom_append: .asciz "appendChild"
js_dom_remove: .asciz "remove"
js_dom_setattr: .asciz "setAttribute"
js_dom_getattr: .asciz "getAttribute"
js_dom_removeattr: .asciz "removeAttribute"
js_dom_listener: .asciz "addEventListener"
js_dom_unlisten: .asciz "removeEventListener"
js_class_add: .asciz "add"
js_class_remove: .asciz "remove"
js_class_toggle: .asciz "toggle"
js_class_contains: .asciz "contains"
js_ready_loading: .asciz "loading"
js_ready_interactive: .asciz "interactive"
js_ready_complete: .asciz "complete"
.section __DATA,__const
.p2align 3
js_ready_names: .quad js_ready_loading,js_ready_interactive,js_ready_complete
js_dom_attributes: .quad js_dom_id_key,js_dom_class_key,js_dom_href_key,js_dom_src_key,js_dom_name_key,js_dom_type_key,js_dom_disabled_key,0
js_dom_methods:
.quad js_dom_getid,1,js_dom_query,2,js_dom_queryall,3,js_dom_create,4,js_dom_create_text,5
.quad js_dom_append,6,js_dom_remove,7,js_dom_setattr,8,js_dom_getattr,9,js_dom_removeattr,10
.quad js_dom_listener,11,js_dom_unlisten,12,0,0
js_class_methods: .quad js_class_add,15,js_class_remove,16,js_class_toggle,17,js_class_contains,18,0,0

.text
.p2align 2
// Render snapshot, stable DOM handle -> current flow index, or -1 if removed.
.globl _engine_js_flow_index
_engine_js_flow_index:
    cbz x0, Ljs_flow_missing
    ldr x9, [x0, #24]
    ldr x10, [x0, #72]
    mov x0, #0
Ljs_flow_index_next:
    cmp x0, x9
    b.hs Ljs_flow_missing
    add x11, x10, x0, lsl #11
    ldr x11, [x11, #2008]
    cmp x11, x1
    b.eq Ljs_flow_index_done
    add x0, x0, #1
    b Ljs_flow_index_next
Ljs_flow_missing:
    mov x0, #-1
Ljs_flow_index_done:
    ret
