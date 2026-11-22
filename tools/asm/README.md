# Native x86-64 engine backend

`engine_x86.py` lowers this repository's shared handwritten assembly core into
native Intel-syntax AMD64 assembly at build time. It is not an ARM emulator, a
runtime interpreter, an HTML implementation in Python, or a general-purpose
AArch64 compiler. Engine algorithms and data layouts stay in `src/engine/`.
Python is not required at runtime.

Run on x86-64 Linux:

```sh
./tools/build-linux-engine.sh test
./build/linux/engine-inspect tests/fixtures/compat-docs-page.html 80
./tools/benchmark-layout.sh
```

Outputs live under `build/linux/engine/`, including readable generated assembly,
objects, the static core library and tests. `engine-inspect` is a developer flow
probe. The browser defaults to the shared assembly engine with the native
GTK/Pango/Cairo adapter in `src/gtk/`; Ctrl+E switches to WebKitGTK. Shared SVG
parsing and background algorithms also compile through this backend.

## ABI and lowering

- Public entry points bridge the System V C ABI to shared assembly functions.
  Core entries use up to six integer arguments; declare `CORE_C_ABI_ARGS name, 7` (or `8`)
  for an entry requiring seven (or eight) so short-arity callers are never read past
  their allocated stack arguments. Scalar FP and two-word integer returns are
  covered by the parity probes.
  Internal branches retain the core's link-register/stack-frame conventions.
- Frequently used virtual registers occupy real AMD64 registers. Remaining
  integer/vector values spill into a private per-entry stack frame; they are
  not process-global registers. The architectural stack is the native stack.
- Integer condition state is preserved independently of incidental AMD64 flag
  changes. Carry, 32-bit zero extension, division edge cases, signed zeros,
  floating-point comparisons and saturating conversion have explicit lowering.
- Data uses ELF sections, RIP-relative addressing and ordinary libc calls.
  `src/linux/engine/runtime.s` supplies the Linux monotonic-clock profiler shim.
- Emitted code uses baseline x86-64/SSE2. New opcodes, unsupported relocation
  forms and unknown external ABIs fail the build rather than being approximated.

This backend deliberately supports the engine's current instruction dialect and
C interfaces, not arbitrary AArch64 assembly, syscall code or NEON/SVE. GTK
foreign calls use an explicit symbol allowlist; only the adapter's declared
integer-only variadic calls and exported callback targets are accepted. Fused
multiply-add and floor use libm while retaining baseline SSE2 compatibility.
Add explicit lowering and parity tests
when extending that boundary. The core remains synchronous; this does not add
thread safety to shared engine state.

## Validation and maintenance

`tests/engine-abi.s` and `tests/engine-abi.c` run on both actual ARM64 macOS and
x86-64 Linux. Portable core suites cover guarded input/output buffers, Unicode,
malformed documents/declarations, DOM mutation, CSS, layout and scenes. Linux
also checks profiling, probe output, command errors, native controls, network
sessions, authentication, cookies, mutation, SVG, Acid1, saved-page references
and whole-browser engine switching. Build-tool tests cover
determinism and rejection of unsupported input.

Modify shared engine algorithms in `src/engine/`, not generated assembly. Keep
backend changes separate from browser adapter behavior, and validate both
architectures after changing lowering rules. Benchmarks report geometry only;
networking, native text shaping and drawing need their own adapter benchmarks.
