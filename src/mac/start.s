// Darwin executable entry; storage tests link the core without a GUI entry point.
.text
.p2align 2
.globl _main
_main:
    b _browser_main
