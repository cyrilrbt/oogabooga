# Changelog

Record user-visible changes here whenever `VERSION` changes. Keep the newest
version first, use the same SemVer as `VERSION`, and distinguish added features,
behavior changes, and fixes. Historical entries summarize the repository history.

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
