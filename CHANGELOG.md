# Changelog

Record user-visible changes here whenever `VERSION` changes. Keep the newest
version first, use the same SemVer as `VERSION`, and distinguish added features,
behavior changes, and fixes. Historical entries summarize the repository history.

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
