# Changelog

Record user-visible changes here whenever `VERSION` changes. Keep the newest
version first, use the same SemVer as `VERSION`, and distinguish added features,
behavior changes, and fixes. Historical entries summarize the repository history.

## 0.19.0 — 2026-11-22

### Added

- Handwritten assembly JavaScript tokenizer, parser and bytecode VM on macOS
  ARM64 and Linux x86-64: basic values, lexical closures, arrays/objects and loops.
- Script-facing DOM text, attributes, classes and styles with retained editor
  rebuilds; click/input/change/submit listeners, cancellation and event phases.
- Main-thread timers, promises/microtasks, ordered classic external scripts and
  bounded same-origin GET fetch with text/JSON responses. Transport keeps native
  TLS validation, rejects redirects/cross-origin requests, and blocks scripting
  on CSP pages conservatively.
- Assembly JavaScript lab linked from the local test index, portable VM
  regressions and native browser integration tests on both platforms.

### Changed

- Non-submit buttons now accept script events. Scripted title changes update the
  macOS window and current history entry without adding another visit.
- README and engine notes describe the supported scripting subset and limits.
  Full ECMAScript, modules and modern application compatibility remain unfinished.

### Fixed

- Reduced macOS initial-page rendering cost by caching exact text/font intrinsic
  measurements across resource updates. Added shared assembly selector rejection
  keys to skip unrelated CSS rules on both platforms.

- macOS coalesces hover restyles until pointer and wheel activity settle, avoiding
  repeated full-page layout stalls while scrolling large pages such as Wikipedia.

- macOS positioned search fields remain clickable and editable on short pages,
  including the DuckDuckGo HTML homepage.

- Scope macOS float exclusions to their owning formatting context; place
  independent blocks beside preceding floats with the same assembly fitter on
  macOS and Linux. Ignore future floats and floats from other contexts.
- Include gaps in intrinsic flex sizes and take the maximum child width for
  column flex containers, avoiding unintended wrapping in nested rows.
- Preserve author link colors and underline choices in private macOS shaping
  stores while retaining scene link navigation and source accessibility.
- Add Unicode formatting-context geometry, paint and link regressions.
- Raise the bounded HTML/DOM capacity to 16,384 nodes and size the binding
  hash table accordingly, allowing long articles without truncation or a full
  table loop.
- Retain scene-owned CSS math expressions across stylesheet rebuilds and avoid
  treating tagged expression pointers as signed numeric lengths.
- Recover missing native container bounds from shaped children so clipped
  search-result URLs remain visible and clickable.
- Use a 16px default document font, composite transparent macOS box paint over
  its background, and isolate nested formatting contexts during native shaping.
- Add named Grid areas, relative tracks, template shorthand and simple state
  selectors inside `:not()`, with article/results fixtures and a WebKit screenshot
  comparison tool. Live DuckDuckGo/Wikipedia pages still have unresolved float,
  header and toolbar differences; these fixes do not establish full-page parity.

## 0.18.0 — 2026-11-22

### Added

- Shared assembly CSS dimension arithmetic: bounded nested `calc()`, `min()`,
  `max()` and `clamp()` for widths, heights, min/max constraints and flex basis.
  Percentages resolve against the actual containing block. Add `vw`, `vh`,
  `vmin` and `vmax` lengths, including viewport-height resize updates.
- Ordinary styled inline links and spans can wrap with per-line backgrounds
  and sliced border edges on both platforms; explicit inline-block links retain
  their independent native box behavior.
- Live `:hover`, `:active`, `:focus`, `:focus-visible` and checked-state matching,
  with coalesced native restyling that retains edited controls and selection.
- Unicode fragment targets, named anchors, same-document history traversal,
  saved viewport positions and first-`<base href>` resolution for relative
  links, forms and document resources.
- `/engine/foundations` manual fixture and native regressions covering these
  features together on macOS and Linux.

### Fixed

- Keep visible document overflow scrollable when the Linux root has a definite
  viewport height; retain control placement during live-state restyling.
- Traverse back from a fragment to the original hashless history entry without
  reloading the document or losing its live editor state.

## 0.17.0 — 2026-11-21

### Fixed

- Decode the Acid1 reference PNG with Cairo so its pixel comparison does not
  depend on portal-backed GdkPixbuf loaders inside the Flatpak build sandbox.
- Run Flatpak GUI regressions on the container-provided Xvfb display during
  the SDK test phase; the GNOME SDK does not include `xvfb-run`.

### Added

- Native Linux x86-64 build of the shared assembly engine core: HTML/DOM,
  CSS, layout calculations, stylesheet/font metadata, display lists and scenes.
  A bounded build-time assembly backend keeps the handwritten core shared;
  generated machine code has no ARM emulator or WebKit dependency.
- Run the shared core suites, cross-architecture instruction/ABI probes and
  Linux profiling checks from `./build.sh test`. Keep generated code under
  `build/linux/engine/`; unknown assembly instructions fail the build.
- Add the assembly-only `build/linux/engine-inspect FILE [COLUMNS]` headless
  UTF-8 flow probe (also included in the native Linux archive) and enable
  geometry benchmarks on Linux.

- Native GTK/Pango/Cairo adapter: shaped Unicode text, inline formatting contexts,
  flex/Grid/table tracks and spans, floats, retained scene painting, clipping,
  stacking/group opacity, fixed positioning and contained scrolling.
- Independent libsoup HTTP/TLS session with ephemeral cookies, native HTTP auth,
  redirects, charset decoding, cancellable progressive CSS/import/image/font loads,
  and URL-encoded GET/POST forms. Shared assembly SVG and background geometry run
  on Cairo; native GTK editors retain values, selection and focus across reflow.
- Source-based selection/copy, scene-aware links and pointer cursors, stable DOM
  rebuilds/resource reuse, visited-link CSS and title-only history updates.
- Linux regressions cover the same 20 saved-page fixtures and Acid1 geometry
  comparison used on macOS, plus native transport, forms, editors and DOM checks.

### Changed

- Default Linux to the assembly engine, matching macOS. Ctrl+E switches to
  WebKitGTK; `OOGABOOGA_ENGINE=webkit` retains an explicit fallback launch path.
- Include the central version in Linux window titles and index history URLs for
  bound visited-link lookups on both platforms.
- Run custom-engine Linux checks from `./build.sh test`, including Flatpak builds.

## 0.16.2 — 2026-11-15

### Fixed

- Seed native control scene boxes from their measured widget frames. Absolutely
  positioned image buttons no longer drift offscreen when their hidden
  attachment glyphs provide no text geometry, including DuckDuckGo's search
  button. Cover placement within the form as well as background-image pixels.

### Changed

- Open DuckDuckGo's HTML homepage by default on both macOS and Linux.
- Add a brief done/partial/todo assembly-engine status table to the README.

## 0.16.1 — 2026-11-15

### Fixed

- Remove AppKit bezels and native focus outlines from assembly webpage text
  inputs. Keep the visible default/CSS border, website colors and backgrounds.
- Use one padded, vertically centered rectangle for displayed text and the
  native field editor. Preserve live text, selection and horizontal scrolling
  through reflow; keep fields inside the surrounding CSS form geometry.
- Add `/engine/inputs` to the local test lab and regressions for active-editor
  bounds, CSS padding, parent outline alignment and resize preservation.

## 0.16.0 — 2026-11-15

### Added

- Assembly support for comma-separated screen media alternatives in stylesheets
  and linked stylesheet media attributes, including `handheld, all`.
- Single-layer CSS background images with stylesheet-relative URLs, raster/SVG
  decoding, auto/explicit/percentage sizes, cover/contain, position keywords and
  percentages, repeat modes and rounded clipping. Native buttons paint their
  image backgrounds while retaining native interaction.
- Background image gallery at `/engine/backgrounds`, linked from the test lab,
  with rendering regressions for media matching, relative URLs, missing-image
  fallback, placement, tiling and native button pixels.

### Fixed

- Load DuckDuckGo HTML's stylesheet and its logo/search-image resources. Google
  remains the homepage; typed URLs are unchanged. Gradient/multiple-image
  backgrounds and escaped CSS URLs remain unsupported.

## 0.15.1 — 2026-11-15

### Changed

- Set Google (`https://www.google.com/`) as the startup homepage on macOS and Linux.

### Added

- Local test-lab index with engine/form galleries, all saved HTML compatibility
  fixtures and suggested viewports, browser interaction checks, and links to
  generated screenshot reports. The index works without JavaScript.

## 0.15.0 — 2026-11-15

### Added

- Assembly CSS button styling: replace native bezels when a website supplies
  visual styles, apply background/text colors, uniform borders and corner radii,
  and measure/place titles using CSS padding. Keep native activation, focus and
  accessibility, with native appearance for unstyled buttons.

### Changed

- Start both applications at DuckDuckGo's JavaScript-free HTML homepage
  (`https://html.duckduckgo.com/html/`). Typed URLs are unchanged; DuckDuckGo's
  main JavaScript-dependent homepage is not redirected automatically.

## 0.14.2 — 2026-11-15

### Fixed

- Add the native macOS Hide menu item (Command-H) and route Hide/Quit
  (Command-Q) directly to the application. Retain Linux Control-Q and
  desktop-managed window hiding/minimizing.

## 0.14.1 — 2026-11-15

### Fixed

- Give native text inputs a visible default outline on white pages while
  preserving explicit border:none, uniform border colors/widths and corner radii.
  Keep the field editor, focus ring and live editing state through reflow.

## 0.14.0 — 2026-11-15

### Added

- Add independent, nested inline-block formatting contexts for mixed text,
  block children, images and controls. Retain source characters for copying;
  reserve whole margin/border boxes, line ascent/descent and vertical alignment.
  Support sized empty inline boxes and keep internal separators out of parent
  line layout.
- Measure min/max content runs, combine intrinsic sizes through the flow tree,
  freeze constrained flex items and redistribute remaining space on both axes.
  Reflow flex/Grid/table children after float/positioned/inline parent sizing.
- Use shared shaping-context origins for retained paint, links, selection and
  native control placement. Measure and reuse the actual controls before layout;
  project logical selection colors into nested inline text.
- Add nested inline/control/border geometry, alignment, resize/wrapping, selection,
  and inner-link integration checks. Add inline-box fixtures at 220/400/640px and
  floating flex headers at 320/640/1000px to the offline dashboard.
- Show the VERSION value after Oogabooga in macOS window titles, including
  assembly, WebKit, initial and popup windows.

- Preserve decoded source whitespace until CSS cascade, with inherited `normal`,
  `pre`, `nowrap`, `pre-wrap`, `pre-line`, and `break-spaces` flow policies.
  Native block paragraphs honor preformatted/no-wrap lines. Apply text tracking,
  additional word spacing, numeric baseline offsets, and sub/super shifts in the
  assembly text adapter.
- Share assembly min/max content-width constraints across normal and positioned
  boxes. Resolve `max-height` against definite containing heights, preserve
  intrinsic image ratios when constraints allow, and stretch automatic positioned
  heights between opposing insets. Preserve zero-width content boxes.
- Route unmodified arrow, Page Up/Down, Home, and End keys to contained CSS scroll
  ports using the text selection, retaining native handling for modified keys.
- Add offline search, news, documentation, and forms fixtures with screenshots,
  visible-text/position checks, and timing budgets. Vendor attributed WPT sizing/whitespace
  sources; test the invalid negative maximum/zero-width computed geometry and no-red
  visual assertion.
  The Ahem-dependent whitespace visual test remains pending.

### Fixed

- Keep extended CSS declarations independent in cascade/important/inheritance
  handling, including stylesheets containing only extended properties.
- Prevent normal block whitespace cleanup from trimming adjacent preformatted
  source text; retain monotonic Unicode range maps.
- Size SVG declaration scratch storage for the full declaration ABI.
- Apply ordinary block width, padding and border geometry to styled forms.

## 0.13.0 — 2026-11-15

### Added

- Retain a separate assembly document tree with stable handles, arbitrary
  attributes, unknown elements, comments, inert script text, and bounded
  insert/move/remove/text APIs. Rebuild native rendering after mutations while
  preserving live controls, accepted styles/images, and history.
- Generate an offline compatibility dashboard with saved renders, independent
  geometry references, per-stage timings, viewport/OS/version metadata, and
  CI artifacts. Add positive/negative margin and percentage-height fixtures.
- Load bounded nested stylesheet imports with relative response bases, media
  wrappers, source-order expansion, ancestor-cycle checks, cancellation, and
  the existing page resource budgets.
- Add assembly scene transforms, relative/absolute/fixed positioning, stacking
  contexts, grouped opacity, per-axis clipping, contained wheel scrolling, and
  consistent link/cursor/selection coordinates. Clip native controls without
  squeezing their editors and preserve scroll/editor state through reflow.
- Load bounded top-level `@font-face` TrueType/OpenType sources, retry supported
  fallbacks, select declared style/weight variants, and reflow on font arrival.
  Keep fonts page-scoped and share existing HTTP/byte/cancellation budgets.
- Match structural selectors against retained document siblings, including
  forward/reverse `:nth-child()` and `:nth-of-type()` formulas.

### Fixed

- Resolve percentage heights only against definite parent content heights;
  preserve auto height under indefinite parents and handle border-box minimums.
- Collapse positive, negative, empty-chain, and eligible parent/child margins
  in assembly, with padding, border and formatting-context barriers.
- Place explicit Grid items before automatic items, preserve sparse row-major
  gaps, and support standalone `grid-column: span N` placement.
- Expand overflow shorthand in declaration order and compute paired overflow
  axes while keeping `clip` distinct from scrolling containers.
- Make native renderer tests use legacy scrollbars consistently and exercise
  both sides of the flex form's media breakpoint using actual page viewport
  widths, rather than assuming a window's outer width determines its layout.
- Render ordinary CSS containers with the assembly CSS-block adapter instead of
  artificial one-cell native tables, which can make nested flex/table/Grid cells
  all receive the entire text-container rectangle. Add a standalone reproducer
  and regression checks for the corrected wrapper geometry.
- Explicitly select TextKit's table-capable typesetter compatibility mode before
  layout instead of inheriting a linked-framework-dependent default.
- Initialize the custom layout manager as its actual class, rather than changing
  an already-initialized native layout manager's class during each render.
- Test flex cell geometry directly, restore modern layout after a forced legacy
  mode, and include typesetter/cell diagnostics when integration checks fail.

## 0.12.0 — 2026-11-14

### Added

- An assembly retained display list for ordered box fills/borders, glyph/image
  ranges, and line-specific link hit regions. Painting culls commands against
  the graphics damage rectangle, and cursor rectangles use the same hit data.
- Opt-in local nanosecond profiling for parsing, CSS, geometry, intrinsic
  measurement, native text/attribute layout, display-list compilation and paint.
  `./tools/benchmark-page.sh` measures warmed offline page rendering with cached
  fixture resources; no telemetry or network requests are involved.
- A full-canvas Acid1 geometry comparison against its historical reference:
  140,302 pixels outside text/widget regions, with one-pixel edge tolerance.
  `./tools/benchmark-page.sh --reference` also writes `build/acid1-assembly.png`.
- `/engine/floats` manual fixture plus regression coverage for empty blocks,
  auto heights and widths, nested floats, padded/percentage containing widths,
  normal content between floats, paint order, clipping, and hit regions.

### Fixed

- Reconcile float positions and clearance with actual shaped content, including
  nested float extents, rather than relying only on pre-layout height estimates.
- Preserve background order between floated parents and ordinary child boxes.
- Honor tight CSS line heights for text while allowing images and controls to
  enlarge their line boxes. Retain invisible layout ranges for empty block boxes.
- Avoid repeatedly measuring ordinary containers and shaping image placeholders;
  propagate replaced-element metrics through ancestors instead. The warmed
  flex/table/SVG benchmark improved from about 9.1 to 2.2 ms/page on the development
  machine; results vary by hardware and exclude network access.

### Limits

- Native font rasterization and widgets remain platform-dependent. The Acid1
  comparison verifies geometry/colors outside those regions, not byte-identical
  screenshots. Full CSS formatting-context rules, margin collapsing, grid and
  positioned layout remain outside the supported subset.

## 0.11.0 — 2026-11-14

### Added

- ARM64 float placement for left/right margin boxes, nested float contexts,
  collision bands, and `clear: left/right/both`. Assembly line exclusion restores
  available text width below floats; native controls and links retain their
  existing text ranges. Out-of-flow boxes contribute to scrollable extent.
- Per-side solid block border widths and one-to-four-value `border-width`.
- Definition-list and address elements, including omitted `dt`/`dd` closing tags,
  and the Verdana font alias used by Acid1.
- An attributed local Acid1 fixture at `/engine/acid1`, geometry/color regression
  checks, two-sided text wrapping and tall-float tests, and a geometry-only
  benchmark (`./tools/benchmark-layout.sh`).

### Fixed

- Honor `border: 0`, round percentage box widths to the nearest pixel, keep list
  markers out of explicitly block-displayed list items, and preserve paragraph
  boundaries inside inline forms.
- Keep a styled document's canvas background distinct from its body background,
  exclude margins from box painting, and remove the browser's extra reading inset
  when the page explicitly sets body margins.

### Limits

- This is an initial float implementation, capped at 128 floats per formatting
  context. Auto heights use intrinsic measurements; intervening padded block
  containers, empty float boxes, complex mixed normal/float source order, and
  full CSS formatting-context rules still need work. Acid1 geometry and sampled
  colors are regression-tested; this is not a claim of pixel-perfect conformance.

## 0.10.0 — 2026-11-14

### Added

- Assembly flex layout for rows and columns, wrapping rows, grow/shrink factors,
  flex basis/shorthand, one/two-value gaps, main-axis justification, and cross-axis
  alignment. Native form controls participate in flex sizing and retain edits
  during responsive reflow.
- Inherited CSS custom properties, `:root`, nested `var()` fallbacks, cycle and
  expansion limits, space-separated `rgb()`/`rgba()`, alpha channels, and four/
  eight-digit hex colors.
- Inline and HTTP(S) SVG images drawn from assembly-parsed XML, common shapes,
  absolute/relative path commands (including curves and arcs), viewBox, inherited
  paint/currentColor, alpha, groups, and affine transforms.
- HTML table rows, headers, row groups, implicit cell/row closing, cell sizing,
  colspan/rowspan, and legacy width/alignment/padding/spacing hints.
- `/engine/layout` fixture and SVG pixel/guarded-input tests covering the features
  together, alongside native flex/table/form/transport regression checks.

### Fixed

- Avoid painting alpha backgrounds twice behind text inside CSS boxes, and avoid
  duplicating a styled link's box/padding when it is a flex item.
- Remove TextKit's extra cell inset so flex/table positions match CSS geometry.
- Validate supported selectors once and filter impossible class matches cheaply,
  keeping large utility stylesheets within the existing selector work budget.
- Keep visited selectors limited to foreground color, including variable-based
  declarations; custom-property definitions cannot depend on visited state.

## 0.9.0 — 2026-11-14

### Added

- Measured inline boxes for short, single-line styled links, including padded
  backgrounds, solid borders, rounded corners, minimum width/height, horizontal
  text alignment, and baseline/middle vertical alignment.
- Native link hit areas covering the whole box, pointing-hand cursors, keyboard
  activation, and accessibility labels. Google’s sign-in link now renders as a
  padded rounded button instead of a strip behind its text.
- Assembly layout mapping for inline attachments so following Unicode text,
  links, and form controls retain their correct positions and actions.

### Fixed

- Preserve outside margins around boxed links and refresh their geometry/colors
  without recreating controls during resize or stylesheet updates.
- Hide stale native boxes when responsive CSS changes a boxed link back into
  ordinary text; retain ordinary flow for links containing images, controls, or
  explicit line breaks.

## 0.8.2 — 2026-11-14

### Fixed

- Preserve explicit and consecutive HTML line breaks when surrounding elements
  use inline/inline-block flow, keeping search buttons below search fields.
- Apply horizontal inline margins/padding as glyph spacing so adjacent footer
  links no longer run together, including links ending in Unicode characters.
- Remove attributed-text background paint behind native form controls to avoid
  stray colored strips around buttons and text fields.
- Preserve website-defined link colors alongside visited-state and cursor support.

## 0.8.1 — 2026-11-14

### Fixed

- Restore the pointing-hand cursor over clickable assembly-engine links while
  preserving their authored colors and underline styles.
- Distinguish unvisited and visited links using resolved HTTP(S) URLs in SQLite
  history, including CSS `:link` and `:visited` selectors and a visited default
  color. Visited selectors change foreground color only, never page layout.

## 0.8.0 — 2026-11-14

### Added

- Screen `@media` queries with pixel `min-width`/`max-width`, including nested
  queries and viewport updates on window resize.
- Simple punctuation escapes in CSS class/id selectors, including responsive
  utility names such as `md:block` and fractional widths such as `w-1/2`.
- Common `font` shorthand, legacy `<center>`, HTML `hidden`, icon-button
  `aria-label` fallbacks, and common punctuation/copyright entities.

### Changed

- Start macOS in the assembly engine by default. Press ⌘E for WebKit, or launch
  with `OOGABOOGA_ENGINE=webkit`. Linux continues to use WebKitGTK.
- Accept up to 1 MiB of combined CSS and per stylesheet, with 4,096 supported
  rules and a bounded 134,217,728-step selector budget, so larger utility
  stylesheets such as Yahoo's are no longer rejected outright.
- Keep simple CSS inline/inline-block containers in text flow. Flex/grid values
  restore visibility with block-flow fallback; their layout remains unsupported.

### Fixed

- Preserve inline span/emphasis flow without unwanted closing-tag line breaks.
- Resolve paragraph margins against their containing width; `margin:auto` no
  longer squeezes centered footer links into a one-character column.
- Size default buttons to fit their titles and strip nested HTML, SVG, comments,
  and script/style bodies from native button labels.
- Render non-submit buttons as disabled buttons instead of unsupported text
  fields; keep their actions from submitting forms without JavaScript support.
- Keep the engine menu checkmark synchronized when starting in assembly mode.
- Reuse computed styles when image resources finish loading instead of rerunning
  the full stylesheet cascade for every image.

## 0.7.5 — 2026-11-14

### Fixed

- Trim excess transparent padding around the project logo and regenerate macOS,
  Linux, and Flatpak icons so the artwork fills more of the available space.

## 0.7.4 — 2026-11-14

### Changed

- Adopt the supplied artwork as the project logo, macOS application icon, Linux
  window/desktop icon, and Flatpak icon, preserving its colors and transparency.
- Include the native Linux icon in release archives and generate macOS icon sizes
  from the original PNG during macOS builds.

## 0.7.3 — 2026-11-14

### Fixed

- Center the macOS URL field vertically using its native single-line control
  height, keeping display text and the editing caret aligned.
- Disable URL wrapping and enable horizontal scrolling while editing long URLs.

## 0.7.2 — 2026-11-14

### Fixed

- Use explicit Command menu shortcuts on macOS and native Control accelerators on
  Linux for equivalent browser commands, including history and popup windows.
- Open Location brings the main browser forward and selects the address on both
  platforms; unrelated modifier combinations no longer trigger Linux commands.
- Add macOS Shift-Command-Z Redo and enable undo/redo in assembly-engine textareas,
  while preserving focused-widget editing shortcuts and clearing stale form actions
  when navigating to a new document.

## 0.7.1 — 2026-11-14

### Changed

- Include the central `VERSION` in macOS ZIP/DMG, Linux archive, Flatpak bundle,
  and checksum filenames, both locally and in GitHub releases.
- Update release notes, workflow download links, and README download instructions
  for versioned assets.

## 0.7.0 — 2026-11-14

### Added

- Responsive assembly-engine layout: window resizing, percentage widths and
  spacing, `max-width`, `box-sizing`, and centered auto margins.
- CSS child selectors and solid/none `border` shorthand.
- Progressive page display and ordered stylesheet/image updates, with a 16 MiB
  session-only HTTP cache; Reload bypasses cached responses.
- Native checkboxes, form-scoped radio groups, single/multiple selects, textareas,
  and URL-encoded POST submissions, including Unicode and CRLF normalization.
- Apache License 2.0 and this versioned changelog.

### Fixed

- Preserve native form values, selection state, and scroll position during reflow
  and resource updates; avoid duplicate history records for resource refreshes.
- Keep native radio grouping within HTML form/name boundaries and preserve
  independent checkmarks in multiple-selection menus.
- Align widget and input-text baselines with surrounding text and use natural
  checkbox/radio widths to avoid excess label spacing.
- Keep page text/links accessible alongside native controls and honor maximum
  widths on replaced image/control elements.

## 0.6.0 — 2026-11-14

### Added

- Linked stylesheets in document order, nested CSS boxes with widths, padding,
  borders and margins, raster images with aspect-ratio scaling and alt fallbacks.
- Native GET forms with text inputs, hidden values, submit buttons, repeated names,
  disabled-control handling, and UTF-8 form encoding.
- Bounded, cancellable HTTP subresource loading and raster metadata validation.

## 0.5.0 — 2026-11-13

### Added

- Assembly CSS parsing, type/class/ID/descendant selectors, cascade and inheritance.
- Embedded/inline styles for colors, fonts, alignment, spacing, and visibility.

## 0.4.1 — 2026-11-13

### Added

- Experimental macOS assembly HTML engine with native text rendering, links,
  navigation, and SQLite history, alongside the default WebKit renderer.

### Fixed

- Decode HTTP character sets and normalize HTML Latin-1/ASCII labels to
  Windows-1252 so legacy-encoded pages remain readable.

## 0.3.0 — 2026-11-13

### Changed

- Replace the macOS Objective-C application bridge with handwritten ARM64 UI,
  navigation, history, URL handling, and native delegate implementations.
- Expand assembly SQLite search and visit-update operations on both platforms.

## 0.2.0 — 2026-11-13

### Added

- Linux x86-64 assembly application using GTK, WebKitGTK, and SQLite.
- Native Linux archives, Flatpak packaging, and shared GitHub release downloads.
- Central `VERSION` file and generated macOS/Flatpak release metadata.
