# Engine implementation notes

The custom engine is macOS ARM64. Production algorithms live in `src/engine/`
and `src/mac/` assembly; C/Objective-C/Python files in `tests/` and `tools/` are
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
handle or zero. Limits are 4,096 allocated handles, depth 64, 64 attributes per
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
