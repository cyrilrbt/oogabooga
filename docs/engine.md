# Engine implementation notes

The custom engine targets macOS ARM64 and Linux x86-64. Production algorithms live in `src/engine/`
and the `src/mac/` / `src/gtk/` assembly adapters; C/Objective-C/Python files in `tests/` and `tools/` are
verification tools. AppKit/CoreText supply native text/font services, Foundation
supplies HTTP/TLS/encoding, and ImageIO supplies raster decoding.

## Persistent documents

`engine_dom_parse(bytes,length)` and `engine_dom_new()` return owned documents.
Release with `engine_dom_free`; `engine_dom_retain` increments ownership. Use
`engine_dom_node(document,handle)` only for borrowed reads. Handles are scoped to
one document, survive moves and edits, and are never reused after removal.
Do not retain raw node/string pointers across mutations.

Assembly APIs create elements/text/comments, insert before a child (zero appends),
detach, remove a subtree, set attributes/text/text-content, and look up IDs.
Mutators return zero on success and minus one on failure; creation returns a
handle or zero. Limits are 16,384 allocated handles, depth 64, 64 attributes per
node, and 4 MiB of owned strings. These are serialized main-thread APIs.

`engine_dom_snapshot(document)` returns an owned render snapshot retaining the
same DOM. `engine_document_free` releases it. Snapshots keep separate flow nodes,
computed metadata, UTF-16 mappings, layout and paint commands. In the application,
`mac_engine_refresh()` detects the DOM version and rebuilds while preserving
stable controls and accepted resources. It does not create another history visit.

## Scene and resources

`scene.inc` defines primitive box geometry, stacking contexts, clips and scroll
state. Stable paint records stay at fixed addresses; assembly sorts indices.
Native adapters retain scene ownership alongside display data and measure text
blocks before replay. Paint, links, cursors, selection and widget hosts consume
these same transforms/clips. Native widget sibling compositing remains limited.

`imports.inc` defines a private stylesheet tree rather than synthetic DOM nodes.
Import expansion keeps source order and media wrappers; URLs use each response's
final base. Fonts use page-scoped family IDs and bounded source fallbacks, without
installing fonts in the process/system registry. See README for format limits.

## Verification

Run `./build.sh test`; inspect `build/compatibility/index.html` and its JSON/PNG
artifacts. Independent rectangle references use exact colors with one-pixel edge
tolerance. Nine text-free fixtures avoid font/widget masking; four representative static
page fixtures add visible-text checks, independent text-position/alignment checks,
and saved screenshots. A WPT sizing fixture also checks absence of red pixels.
Inline and floating-header fixtures cover 220–1000px viewports. Native integration
tests separately cover Unicode, editing, links, fonts, requests and failures.
Budgets are coarse 25-ms geometry / 50-ms static-page median limits after two warmups and five samples, not a
cross-hardware speed claim. Broader site/WPT coverage remains in `ENGINE_TODO.md`.

`tests/fixtures/ooga-test.ttf` is an Apache-2.0 test asset generated entirely by
`python3 tools/generate-test-font.py`, using only Python's standard library.
Its rectangular ASCII glyphs deliberately provide known advances for font tests.

## Sizing and inline contexts

Width limits are content-box values from `engine_width_limits`; border-box
padding/borders are deducted once and minima win conflicting maxima. Height
limits retain `-1` for indefinite/absent maxima. Replaced sizing receives bounded
natural dimensions and optional explicit axes; automatic axes preserve aspect
ratio where both-axis constraints permit it. Raster allocation still has a
4096-point safety limit. Flex items freeze at min/max limits and redistribute remaining space. Intrinsic
run/tree measurements feed shrink-to-fit floats, positioned and inline boxes.
Automatic flex minima, fractional-factor corner cases and complete Unicode break
opportunities remain incomplete.

Flow snapshots retain decoded source whitespace. `engine_layout` applies the
computed per-byte whitespace policy while building the UTF-16 map; parser-owned
block separators remain distinct from source line breaks. Block `pre`/`nowrap`
paragraphs disable native soft wrapping. Inline-blocks use separate native shaping contexts, preserving source characters
in the parent storage while reserving one whole box. Assembly resolves used
widths, border/margin geometry, empty boxes, ascent/descent, and baseline/top/
bottom/middle/text-top/text-bottom/numeric/sub/super alignment. Child blocks,
images, controls and nested inline-blocks stay in their own context. Each context
supports up to 256 direct boxes. Copied metadata and retained child storages keep
paint records independent of transient document allocations.

Paint commands retain their shaping manager, source base and content origin.
The same context lookup drives link regions, mouse indices, selection projection,
control positions and dashboard geometry checks. Synthetic boundary CR/LF is
trimmed from normal/nowrap child shaping ranges; complete explicit-break edge
semantics, ordinary inline fragmentation, `break-spaces` line edges and tab stops
remain incomplete. The existing short styled-link native adapter remains.

Keyboard contained scrolling shares the assembly wheel ancestor-chain policy.
Modified keys remain native so selection and editing commands keep their responder
behavior. Full widget stacking/group opacity and selection-aware scrolling through
all keyboard editing/scroll cases remain unfinished. `tests/fixtures/wpt/README.md` records
which imported tests are computed checks and which visual tests remain pending;
none of these checks establishes broad WPT conformance.


## Assembly JavaScript

`src/engine/js*.s` implements a bounded tokenizer, parser, stack bytecode VM,
lexical environments, values, DOM bindings and event loop. The existing build-time
assembly backend emits native x86-64 for Linux. Production code does not embed
an existing JavaScript engine. Platform adapters supply main-thread timers,
editor access, and native HTTP/TLS; parsing and execution stay in assembly.

`engine_js_new(dom)` retains the mutable document; `engine_js_free(vm)` releases
its page arena. `engine_js_prepare` collects initial handlers/classic scripts;
`engine_js_start` executes in document order, pausing at external scripts.
Adapters pull `engine_js_request_next`, validate the resolved origin and MIME,
and complete with bounded UTF-8 through `engine_js_complete`. Initial scripts run
post-parse (after initial resources on macOS). Dynamic script insertion,
parser-blocking execution, modules and full async/defer behavior are unfinished.

DOM mutations are batched into retained-document rebuilds, preserving native
editors and avoiding duplicate history visits. `engine_js_control` feeds native
entry/toggle state before event dispatch. Capture/target/bubble listeners support
cancellation and propagation control; input/change/submit/click plus
DOMContentLoaded are wired. Native entry and toggle synchronization is supported;
textarea/select script synchronization and the full browser event catalog remain.
Timers and promise reactions run on the UI thread. Navigation/switching cancels
page work; transport callbacks check generations before accessing VM memory.

Bounds: 64 KiB source/response, 8,192 tokens and bytecode instructions, 512 stack
values, 32 calls, 64 parser levels, 4 MiB arena, 256 array entries, 128 listeners,
32 script/fetch requests, 32 timer callbacks and 128 microtasks per checkpoint,
and 100,000 bytecode steps per evaluation/checkpoint. Arena memory is reclaimed on navigation;
tracing garbage collection is unfinished. Finite number-to-string formatting is
currently limited to six fractional digits and signed 64-bit integer range.

Fetch is GET-only, same-origin HTTP(S), with redirects rejected and standard TLS
validation retained. Native sessions share the page cookie jar. External scripts
require a JavaScript MIME type. Any HTTP/meta CSP declaration disables scripting
because the VM does not yet implement complete CSP policy evaluation. No native
FFI, filesystem/process access or dynamic evaluation API is exposed.

This is not an ECMAScript conformance claim. Semicolons are required except at
block/end boundaries; hoisting/TDZ, custom constructors/prototypes, classes,
exceptions, regular expressions, templates, modules, async/await and complete
built-ins/coercions remain. Selectors support simple ID/class/tag queries.
`tests/js.c` exercises the portable implementation; native browser suites test
real editors, DOM rebuilds, external scripts, fetch/JSON and CSP. The manual lab
is `/engine/javascript` (or `/fixtures/engine-javascript.html`).

## Static page comparison

After building on Apple silicon, run
`sh tools/compare-page.sh 'https://en.wikipedia.org/wiki/Assembly_language' build/page-comparison/wiki`
to capture `assembly.png`, `webkit.png` and comparison metadata. WebKit uses
a nonpersistent profile with JavaScript disabled, so the reference measures
server-rendered HTML/CSS. Live responses can vary; offline article/results
fixtures in the compatibility report provide repeatable checks. This is a
visual inspection tool, not a pixel-conformance claim.

Grid supports bounded named areas, an unquoted `rows / columns` template
shorthand, intrinsic tracks and relative `em`/`rem` tracks. Relative tracks
currently retain tenths of a unit; nested quoted template shorthands and full
Grid conformance remain incomplete. Default document typography starts at 16px.
The macOS adapter isolates nested flex/Grid and positioned contexts for native shaping;
assembly retains sizing, paint, clipping and hit testing.

For implementation references and upcoming layout regression targets, see
[Layout implementation references](layout-references.md).
