// Baseline-aware attachment cells reserve the native control's ascent/descent.
// The overlay control and surrounding text therefore share one actual baseline.
.include "src/mac/mac.inc"
.text
.p2align 2
.globl _mac_control_cell_class
_mac_control_cell_class:
    ENTER
    CLASS OogaboogaControlAttachment
    cbnz x0, Lcontrol_class_done
    CLASS NSTextAttachmentCell
    ADDR x1, control_class_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    SELECT x1, cellBaselineOffset
    ADDR x2, control_cell_baseline
    ADDR x3, control_point_encoding
    bl _class_addMethod
    mov x0, x19
    bl _objc_registerClassPair
    mov x0, x19
Lcontrol_class_done:
    LEAVE

// NSPoint cellBaselineOffset: negative Y is the descent below the text baseline.
control_cell_baseline:
    ENTER
    MSG representedObject
    mov x19, x0
    MSG frame
    str d3, [sp, #144]
    mov x0, x19
    bl _mac_control_baseline_top
    ldr d1, [sp, #144]
    fsub d1, d0, d1
    fmov d0, xzr
    LEAVE
.section __TEXT,__cstring,cstring_literals
control_class_name: .asciz "OogaboogaControlAttachment"
control_point_encoding: .asciz "{CGPoint=dd}@:"

.text
.p2align 2
// Baseline properties describe the natural control. Center it when CSS supplies
// extra vertical space; views without a text baseline (textarea scroll views)
// retain ordinary bottom alignment.
.globl _mac_control_baseline_top
_mac_control_baseline_top:
    ENTER
    mov x19, x0
    MSG frame
    str d3, [sp, #144]
    mov x0, x19
    MSG intrinsicSize
    str d1, [sp, #152]
    mov x0, x19
    MSG firstBaseline
    fcmp d0, #0.0
    b.le Lbaseline_bottom
    ldr d1, [sp, #152]
    fcmp d1, #0.0
    b.le Lbaseline_top_done
    ldr d2, [sp, #144]
    fsub d2, d2, d1
    fmov d3, #0.5
    fmadd d0, d2, d3, d0
Lbaseline_top_done:
    LEAVE
Lbaseline_bottom:
    ldr d0, [sp, #144]
    LEAVE
