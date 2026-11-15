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
tolerance. Nine text-free fixtures avoid font/widget masking; native integration
tests separately cover Unicode, editing, links, fonts, requests and failures.
Budgets are coarse 25-ms median limits after two warmups and five samples, not a
cross-hardware speed claim. Broader site/WPT coverage remains in `ENGINE_TODO.md`.

`tests/fixtures/ooga-test.ttf` is an Apache-2.0 test asset generated entirely by
`python3 tools/generate-test-font.py`, using only Python's standard library.
Its rectangular ASCII glyphs deliberately provide known advances for font tests.
