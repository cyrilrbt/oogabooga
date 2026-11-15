# Assembly Engine Roadmap

Working checklist, audited against the repository on 2026-11-15. This covers the
engine rather than browser chrome. It is a comprehensive backlog, not a promise
to implement every web standard before JavaScript. Unchecked items can have
partial groundwork; parsing a value does not mean rendering it correctly.

## Current baseline

- ARM64 HTML flow tree, CSS parsing/cascade, box/flex/table/float calculations,
  SVG subset, retained paint commands, hit regions, and local profiling.
- AppKit supplies text shaping, glyph layout/drawing, selection, and controls.
  Foundation supplies HTTP/TLS and decoding. These are platform dependencies,
  not an independent assembly implementation of those subsystems.
- Static navigation, SQLite history, an ephemeral cookie session, linked CSS,
  images, and URL-encoded GET/POST forms have integration coverage.
- Acid1 has a geometry/color comparison outside excluded glyph/widget regions.
  This does not establish a complete visual or standards-conformance pass.
- Grid has track parsing, bounded placement/sizing, and a native-cell bridge;
  it still needs broader integration and conformance coverage.
- Attribute/sibling selectors and structural/state pseudo-classes exist.
  Structural sibling/empty/nth tests use the persistent DOM; other selector
  paths still need a full document-tree audit.
- Position/inset/z-index/overflow have computed-value support and a tested
  assembly scene for transforms, clips, stacking contexts, opacity and hits.
  Native painting, mouse interaction, widget clipping and contained wheel
  scrolling are integrated; full native-widget stacking remains unfinished.
- The custom engine is macOS ARM64 only. Linux still uses WebKitGTK.

## Current implementation work

- Compatibility dashboard and nine text-free reference fixtures run in local/CI
  tests; broad saved-site coverage, memory reporting and calibrated budgets remain.
- Persistent mutation APIs and native rebuild/control/resource preservation are
  covered; complete HTML5 construction and broad selector query APIs remain.
- Margin collapse, definite/percentage heights, BFC barriers, scene painting,
  clipping controls, mouse interaction and contained scrolling are covered.
  General inline formatting and full widget compositing remain.
- Grid sparse placement, structural selectors and nested stylesheet imports are
  covered. Basic TrueType/OpenType font loading and reflow are covered;
  WOFF/WOFF2, broader flex/table cases and representative pages remain.

## Recommended order

1. Establish saved-page visual/geometry regressions and performance reporting.
2. Introduce a persistent, mutable document tree separate from layout boxes.
3. Finish formatting contexts, inline boxes, sizing, positioning, and clipping.
4. Harden flex/Grid/tables and stylesheets against representative static pages.
5. Finish interaction, navigation/session policy, and incremental updates.
6. Meet the JavaScript entry gate below; start scripting against stable APIs.

Implement engine algorithms in assembly. Keep native shaping, TLS, codecs, and
UI behind explicit adapters. Optimize measured bottlenecks; instruction language
alone does not establish speed. Test/report tooling can use C, Objective-C,
Python, and shell without shipping those implementations as the engine.

## 1. Compatibility and observability — start now

- [ ] Publish a support matrix distinguishing parsed, laid out, painted,
  interactive, and regression-tested features; reconcile the README with code.
- [ ] Build an offline fixture suite for search pages, news, articles, navigation,
  tables, forms, and documentation, with appropriate redistribution rights.
- [ ] Produce a dashboard with screenshots, geometry checks, failures, limits,
  stage timings, memory use, and version/OS/viewport metadata.
- [ ] Compare against saved reference renders with documented font/widget
  exclusions and tolerances; do not hide unexpected differences with masks.
- [ ] Import a selected, licensed set of script-free WPT reftests. Separate
  unsupported tests from failures; most API tests need a scripting harness.
- [ ] Cover legacy/overlay scrollbars, viewport breakpoints, display scale,
  resizing, progressive resources, and supported macOS runner versions.
- [ ] Track cold/warm parsing, cascade, layout, paint, and allocation budgets on
  fixed workloads. Set budgets from measurements, with hardware-aware margins.
- [ ] Add useful diagnostics: document/box-tree dumps, computed styles, box
  outlines, clipping/stacking data, rejected resources, and limit exhaustion.

## 2. Document model and HTML — required foundation

- [ ] Separate source bytes, persistent document nodes, computed styles,
  generated layout boxes, and paint commands with explicit ownership.
- [x] Preserve unknown elements, arbitrary attributes, text, comments, inert
  script text, and non-rendered elements; hiding must not delete DOM structure.
- [x] Introduce stable node handles with safe invalidation after removal.
- [ ] Support insert/remove/move, attribute changes, text replacement, and
  subtree replacement through assembly APIs, initially callable from tests.
- [ ] Maintain parent/sibling/child traversal and selector queries after edits.
- [ ] Implement HTML tokenizer states, including raw text/RCDATA and malformed
  comments, attributes, entities, nulls, and truncated input recovery.
- [ ] Improve tree construction: implied closures, active formatting elements,
  table insertion/foster parenting, document/head/body handling, and templates.
- [ ] Distinguish standards/quirks modes and define their initial scope.
- [ ] Handle HTML/SVG namespaces and foreign-content parsing correctly.
- [ ] Implement encoding sniffing precedence, BOMs, HTML meta charset, and
  deterministic recovery from malformed encodings.
- [ ] Support document base URLs and `<base href>` consistently for all resources.
- [ ] Make depth/node/text limits explicit and report graceful exhaustion.

## 3. CSS parsing, matching, and cascade

- [ ] Harden tokenization of escapes, Unicode identifiers, comments, strings,
  functions, nested constructs, invalid declarations, and recovery boundaries.
- [x] Implement bounded `@import` loading with relative bases, source order,
  supported media conditions, cycle detection, cancellation, and shared budgets.
- [ ] Audit selector matching against the actual document tree, not rendered
  visibility or a subset of retained element types.
- [ ] Complete attribute matching, sibling combinators, `:not()` specificity,
  selector lists, and malformed-selector rejection.
- [ ] Add `:nth-child`, `:nth-of-type`, `:is`, `:where`, and state selectors;
  defer expensive relational selectors until matching budgets are measured.
- [ ] Connect `:hover`, `:active`, `:focus`, `:focus-visible`, and `:checked` to
  current interaction state and targeted style invalidation.
- [ ] Define user-agent defaults, presentational hints, cascade origins/layers,
  shorthand resets, and `revert` behavior.
- [ ] Complete custom-property cycles, fallbacks, invalid-at-computed-value
  behavior, and dependency tracking across style changes.
- [ ] Add `calc`, `min`, `max`, `clamp`, viewport units, and consistent percentage,
  em/rem and absolute-length resolution, including negative values where valid.
- [ ] Expand media queries and add `@supports` with honest capability answers.
- [ ] Remove incidental property-count/packed-value constraints where they block
  correctness; retain explicit, tested resource bounds.

## 4. Box tree and normal layout — highest rendering priority

- [ ] Build explicit block/inline/replaced/anonymous boxes from computed styles.
- [ ] Establish block and inline formatting contexts, `flow-root`, float
  containment, and overflow-created formatting contexts.
- [ ] Implement margin collapsing, including adjoining/empty/nested blocks.
- [ ] Complete containing-block rules and consistent content/border-box sizing.
- [ ] Resolve auto widths/heights, shrink-to-fit, min/max constraints, intrinsic
  aspect ratios, and percentage heights with definite/indefinite ancestors.
- [ ] Support mixed inline/block content without synthetic separator artifacts.
- [ ] Make general inline/inline-block boxes independent of the styled-link
  special case, including padding, borders, backgrounds, margins, and baselines.
- [ ] Correct line-height, baseline/vertical alignment, wrapping, whitespace
  modes, nonbreaking spaces, overflow wrapping, and text overflow/ellipsis.
- [ ] Cover bidi direction, mixed scripts, combining marks, emoji, font fallback,
  and byte/UTF-16/glyph mapping across wrapping, selection, and mutation.
- [ ] Implement list markers, numbering, nesting, and generated marker placement.
- [ ] Validate float intrusion, clearance, auto heights, nested contexts, and
  interactions with replaced elements, flex/Grid, and ordinary blocks.
- [ ] Gradually replace native table/paragraph layout dependencies with assembly
  box geometry while retaining native shaping primitives and visual regressions.

## 5. Positioning, stacking, and overflow — unfinished milestone

- [x] Implement relative positioning without changing the element's flow slot.
- [ ] Implement absolute positioning, static-position fallback, containing blocks,
  insets, auto sizing/margins, and percentage offsets.
- [ ] Implement viewport-fixed positioning across document scrolling/resizing.
- [ ] Add sticky positioning with scroll-container constraints.
- [ ] Implement stacking contexts and stable paint order for boxes, text, images,
  and controls; a global z-index sort is insufficient.
- [ ] Implement overflow per axis, inherited clipping, scroll extents, and nested
  scroll containers, including wheel/trackpad routing and keyboard scrolling.
- [ ] Apply the same transforms/clips to paint, hit testing, cursors, focus rings,
  selection, and native control overlays.
- [ ] Add basic transforms and correct transformed hit coordinates; expand
  compositing only after the basic geometry is reliable.

## 6. Flex, Grid, and table compatibility

- [ ] Complete flex basis/auto minimum sizes, shrink freezing, min/max clamping,
  multiline cross sizing, alignment, order, reversed axes, and baseline cases.
- [ ] Integrate Grid with images/controls, nested layouts, resize, and mutations.
- [ ] Correct Grid auto-placement, implicit tracks, explicit placement, spans,
  overlap, and row/column gaps with constrained/intrinsic content.
- [ ] Expand Grid track sizing: `minmax`, auto/min/max-content, fractional sizing,
  repeat forms, alignment, and named lines. Treat subgrid as later work.
- [ ] Complete table intrinsic/percentage sizing, captions, column/row groups,
  row/column spans, empty cells, vertical alignment, spacing, and border collapse.
- [ ] Cover nested tables and tables inside/outside flex/Grid without introducing
  artificial native table wrappers around ordinary CSS boxes.

## 7. Painting and visual resources

- [ ] Complete per-side border styles/colors, radius geometry, clipping, outlines,
  box/text shadows, and background layers/images/position/size/repeat.
- [ ] Implement subtree opacity and grouped compositing rather than independent
  child alpha where a single composited group is required.
- [ ] Add generated `::before`/`::after` content and counters with real boxes.
- [x] Support bounded TrueType/OpenType font-face loading, selection/fallback,
  and reflow on load.
- [ ] Add WOFF/WOFF2, font collections, local sources, variable axes, synthesis,
  unicode-range and conditional font-face behavior.
- [ ] Add responsive images (`srcset`/`sizes`/`picture`), object fit/position, and
  reliable intrinsic dimensions before and after resource arrival.
- [ ] Expand SVG deliberately: text, gradients, clipping/masks, references, and
  external-resource policy, with recursion and allocation limits.
- [ ] Introduce animation/image frame scheduling only with bounded work and
  visibility-aware repaint. Video/audio can remain a later milestone.
- [ ] Ensure paint damage, retained-command capacity fallback, and clipping never
  change the rendered result or leave stale hit regions.

## 8. Interaction, forms, and accessibility

- [ ] Implement fragment anchors, same-document navigation, and scroll restoration
  after resource/layout changes and back/forward traversal.
- [ ] Cover keyboard tab order, focus visibility, label activation, selection,
  copying, link activation variants, and context menus.
- [ ] Add password controls, reset/default values, form ownership, submitter
  overrides, validation, successful-control rules, and disabled fieldsets.
- [ ] Add bounded multipart submission/file selection when uploads are in scope.
- [ ] Preserve live values, focus, caret/selection, and checkbox/radio/select state
  across reflow, stylesheet changes, and document edits.
- [ ] Expose document semantics and actionable links/controls through the platform
  accessibility tree; test keyboard-only and screen-reader navigation.
- [ ] Ensure zoom/scale and high-contrast settings keep layout and hit targets
  consistent. Expand print/paged layout later.

## 9. Loading, sessions, and security

- [ ] Centralize URL parsing/resolution, redirects, origin identities, fragment
  handling, supported schemes, MIME checks, and resource-type policy.
- [ ] Add bounded concurrent resource scheduling, priorities, deduplication, and
  cancellation; preserve stylesheet order despite out-of-order completion.
- [ ] Audit cache/reload behavior, redirects, response limits, compressed/decoded
  sizes, image/font metadata, timeout handling, and stale completion isolation.
- [ ] Implement deliberate persistent-cookie storage and clear-session controls;
  audit Domain/Path/expiry/Secure/HttpOnly/SameSite semantics.
- [ ] Define origin checks for reads and cross-document access before scripting;
  distinguish cross-origin embedding, navigation, and readable fetch responses.
- [ ] Enforce applicable CSP, mixed-content, referrer, and credential policies;
  prepare CORS enforcement for script-readable resource APIs.
- [ ] Decide and document iframe/subdocument scope, sandboxing, per-document
  session/state ownership, and cross-origin isolation boundaries.
- [ ] Isolate untrusted parsing/rendering from browser UI and credentials; plan
  the renderer process boundary before adding arbitrary script execution.

## 10. Incremental updates and performance

- [ ] Track dirty style/layout/paint subtrees and resource/viewport dependencies.
- [ ] Recompute affected selectors and inherited/custom properties after edits.
- [ ] Batch changes and schedule bounded layout/paint work without rebuilding
  the whole attributed document for every small state/resource change.
- [ ] Keep retained commands and interaction maps synchronized with tree edits.
- [ ] Benchmark wide/deep trees, long text, many selectors, nested layouts,
  large scroll areas, repeated resizes, and rapid navigation/cancellation.
- [ ] Measure allocations/cache locality and index selectors/resources where
  profiling supports it; verify gains against correctness fixtures.
- [ ] Bound total work per document and per interaction, not just input bytes.

## 11. Reliability and portability

- [ ] Expand parser/style/layout fuzzing, malformed/truncated corpora, guard-page
  and allocator checks, overflow checks, and deterministic timeout tests.
- [ ] Check callback signatures, register preservation, stack alignment, ownership,
  and pointer lifetimes across asynchronous navigation and native adapters.
- [ ] Record unsupported/fallback behavior explicitly; never mark parsing-only
  support as a rendered conformance pass.
- [ ] Separate platform-neutral engine contracts from AppKit implementation details.
- [ ] Bring the custom engine to Linux: x86-64 implementations and native shaping,
  painting, input, and accessibility adapters with shared fixtures.
- [ ] Decide later whether ARM64 Linux and Windows are separate supported targets.

## JavaScript entry gate

Start a small scripting milestone when all of these are demonstrated; finishing
every item above is not required:

- [x] A persistent document tree supports safe mutation with stable handles.
- [ ] Style/layout/paint update correctly after insertion, removal, text/attribute
  changes, class changes, and focus/control-state changes, without scripting.
- [ ] Common static-page layouts pass a published fixture suite; supported
  positioning, clipping, stacking, flex, and Grid subsets have clear limits.
- [ ] Resource completion, navigation cancellation, timers/tasks, and document
  lifetime have explicit scheduling contracts with no stale callbacks.
- [ ] Event targets, hit testing, focus, default actions, capture/bubble phases,
  and cancellation have a testable native/assembly model.
- [ ] Origin identities, access rules, cookie/credential policy, and renderer
  isolation are specified and tested for the initial scripting scope.
- [ ] Regression, fuzz, allocation, and performance budgets are reproducible in CI.

The first script milestone should target DOM lookup, text/class/style mutations,
event listeners, and scheduled callbacks on local fixtures. The VM, garbage
collector, bindings, parser-blocking execution, microtasks, and full web API
surface are their own roadmap. Full CSS, advanced SVG, media, subgrid, printing,
and every platform port can continue alongside that work.

## Standards and test references

- [HTML parsing and tree construction](https://html.spec.whatwg.org/multipage/parsing.html)
- [DOM](https://dom.spec.whatwg.org/)
- [CSS display and formatting contexts](https://www.w3.org/TR/css-display/)
- [Web Platform Tests: writing tests](https://web-platform-tests.org/writing-tests/)
- [WPT rendering comparisons](https://web-platform-tests.org/writing-tests/reftests.html)

Update this checklist when features land. Check off completion only alongside
behavioral tests, documented limits, and relevant supported-platform validation.
