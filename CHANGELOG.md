# Changelog

Record user-visible changes here whenever `VERSION` changes. Keep the newest
version first, use the same SemVer as `VERSION`, and distinguish added features,
behavior changes, and fixes. Historical entries summarize the repository history.

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
