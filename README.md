# oogabooga

<img src="assets/oogabooga.png" alt="Oogabooga logo" width="160">

A small native browser for Apple silicon macOS 12+ and x86-64 Linux, inspired by rhun's direct assembly-and-link build. Both applications are entirely vibecoded assembly: ARM64 on macOS and x86-64 on Linux. They call native UI/WebKit and SQLite libraries directly. No Electron or npm.

## Download

Pushes to `main` run the Browser downloads workflow: test both native builds, build a Linux Flatpak, and publish one GitHub Release with all downloads and SHA-256 checksums. A release is published only after all three build jobs pass. You can also run it manually from Actions on `main`. Each release points to the exact built commit.

[Download the latest release](https://github.com/cyrilrbt/oogabooga/releases/latest) and choose the versioned asset for your platform:

- `Oogabooga-VERSION-linux-x86_64.flatpak`
- `Oogabooga-VERSION-linux-x86_64.tar.gz`
- `Oogabooga-VERSION-macos-arm64.dmg`
- `Oogabooga-VERSION-macos-arm64.app.zip`
- `SHA256SUMS-VERSION.txt`

Downloads become available after a successful workflow run. For macOS, open the DMG and drag Oogabooga into Applications. macOS builds target Apple silicon macOS 12+. They are ad-hoc signed, not Developer ID signed or notarized, so Gatekeeper may block downloaded copies. Public distribution without that warning requires Apple signing credentials and notarization.

To package locally after building, run `./tools/package-mac.sh`; files appear in `build/dist/`. GitHub Actions also retains downloads as workflow artifacts for 14 days. The workflow uses its built-in token with release write permission; no additional secrets are required. Repository or organization policies must allow Actions to create releases.

Install the Linux Flatpak with:

```sh
flatpak install --user ./Oogabooga-VERSION-linux-x86_64.flatpak
flatpak run dev.oogabooga.Browser
```

Replace `VERSION` with the version in the downloaded filename. Install Flatpak through your distribution first. The bundle references the GNOME 50 runtime on Flathub and installs the runtime as needed; this does not publish Oogabooga to Flathub. Bundles are downloaded from GitHub and installed manually. The app has network, display, GPU, and audio access, with no blanket access to your home directory. Its profile lives under `~/.var/app/dev.oogabooga.Browser/`. The optional native archive requires Ubuntu 24.04+ or a compatible x86-64 distribution with GTK 3, WebKitGTK 4.1, SQLite, libsoup 3, Pango/Cairo, Fontconfig, and a sufficiently recent glibc.

## Versioning

`VERSION` is the single source of truth for the app version. Change only that file when bumping a stable SemVer release (`MAJOR.MINOR.PATCH`). Update [CHANGELOG.md](CHANGELOG.md) in the same change, documenting additions, behavior changes, and fixes under the matching version and date.

Builds generate macOS bundle versions and Flatpak release metadata from this file; AppStream release dates use the UTC build date. Generated metadata lives in `build/metadata/`, and the files in `assets/` are templates. Linux packages also include the `VERSION` file. GitHub release titles include the version, and each push gets a unique tag such as `v0.2.0+build.RUN_ID.ATTEMPT`; download filenames include the stable version from `VERSION`. The latest-release page always points to the newest successful build.

## Build and run

### Linux

On Ubuntu 24.04:

```sh
sudo apt-get install build-essential python3 pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev libsqlite3-dev libsoup-3.0-dev libfontconfig1-dev libpango1.0-dev
./build.sh release
./build/linux/oogabooga https://github.com
```

`./build.sh test` runs shared SQLite/core suites, native instruction/ABI probes, and the custom-engine GTK rendering, networking, forms, DOM, SVG, Acid1 and saved-page checks under Xvfb. `./tools/package-linux.sh` makes the native archive. Linux currently targets x86-64 only, using the System V ABI. Run in an X11 or Wayland desktop session. The native archive includes `engine-inspect FILE [COLUMNS]` for headless core inspection and `oogabooga.png`; keep the PNG beside the browser executable for the window icon. To use the supplied desktop launcher, also install that PNG as `~/.local/share/icons/hicolor/512x512/apps/dev.oogabooga.Browser.png` and put the executable on your PATH.

The native x86-64 engine core can also be built without GTK/WebKit:

```sh
./tools/build-linux-engine.sh test
./build/linux/engine-inspect tests/fixtures/compat-docs-page.html 80
./tools/benchmark-layout.sh
```

This developer probe outputs wrapped UTF-8 flow, not a rendered page. The core
library is `build/linux/engine/liboogabooga-engine.a`. A build-time
[assembly backend](tools/asm/README.md) lowers the shared handwritten ARM64
engine into native Intel-syntax x86-64 code. Python is a build dependency only;
the probe uses libc and has no ARM emulator, GTK or WebKit dependency.
`src/gtk/` supplies the assembly GTK/Pango/Cairo adapter and independent libsoup
HTTP session; neither HTML nor SVG parsing is delegated to WebKit.

To run browser integration tests, install `xvfb xauth dbus-x11 python3`, run `./build.sh test`, then `./tools/test-linux.sh`. The harness checks real WebKit rendering, cookie persistence across process restart, HTTP authentication, popup opener/close behavior, navigation, history search/reopening, and failed-load history exclusion. It also checks the default assembly engine, toolbar/history navigation, versioned titles and switching to and from WebKit. Its C harnesses are test-only; no C application code is linked into the shipped Linux executable. It requires a working WebKit process sandbox and uses an isolated temporary profile and localhost fixture.

To build a Flatpak locally, install `flatpak` and `flatpak-builder`, then:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
xvfb-run -a flatpak-builder --user --install-deps-from=flathub --force-clean --repo=flatpak-repo flatpak-build flatpak/dev.oogabooga.Browser.json
flatpak build-bundle flatpak-repo Oogabooga-$(./tools/version.sh)-linux-x86_64.flatpak dev.oogabooga.Browser --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
```

The GitHub Flatpak job uses `tools/build-flatpak.sh` inside the preloaded GNOME 50 build image. It deliberately uses the installed SDK/runtime without `--install-deps-from`, avoiding OSTree updates on the container overlay filesystem. Refresh the container image to obtain newer SDK/runtime builds. The script starts Xvfb outside the SDK; the manifest exposes its X11 display only during the test phase. Local manifest builds also need a running X11 display (for example, wrap `flatpak-builder` in `xvfb-run -a`).

### macOS

Install Xcode command-line tools, then:

```sh
./build.sh release
open build/Oogabooga.app
```

Or launch with a starting URL:

```sh
build/Oogabooga.app/Contents/MacOS/oogabooga https://github.com
```

`./build.sh test` builds the app and runs the assembly SQLite, ARM64 URL, and delegate callback tests. The test-only Objective-C harness checks block invocation, authentication cancellation/retries, JavaScript dialogs, and default TLS handling without displaying modal dialogs. `./build.sh` makes a debug build. The app is signed ad hoc for local use; distribution would require Developer ID signing and notarization.

## Features

- Address/search bar, back/forward, reload/stop, trackpad navigation.
- System WebKit renders websites and runs JavaScript with its normal TLS validation.
- Persistent WebKit profile for cookies, local storage, and website sessions. Persistent cookies survive restart according to their expiry; session cookies follow WebKit's lifecycle.
- Standard website login forms, HTTP Basic/Digest/NTLM credential prompts, and separate popup windows that preserve `window.opener` for login flows.
- SQLite visit history with titles and timestamps, searchable from the History window; double-click a result to open it. Shows the latest 1,000 matching visits.
- JavaScript alert, confirm, and prompt dialogs; normal copy/paste shortcuts.

Use **⌘ (Command) on macOS** and **Ctrl on Linux** for the same shortcuts:

| Action | macOS | Linux |
| --- | --- | --- |
| Address/search bar | ⌘L | Ctrl+L |
| Reload/stop | ⌘R | Ctrl+R |
| Back / forward | ⌘[ / ⌘] | Ctrl+[ / Ctrl+] |
| History | ⌘Y | Ctrl+Y |
| Hide app | ⌘H | Desktop/window-manager shortcut |
| Quit | ⌘Q | Ctrl+Q |
| Cut / copy / paste | ⌘X / ⌘C / ⌘V | Ctrl+X / Ctrl+C / Ctrl+V |
| Select all | ⌘A | Ctrl+A |
| Undo / redo | ⌘Z / ⇧⌘Z | Ctrl+Z / Ctrl+Shift+Z |

Editing commands act on the focused field/page and depend on that widget's editing support. Browser commands also work from history and popup windows; Open Location brings the main address bar forward. Switch engines with ⌘E on macOS or Ctrl+E on Linux. The assembly engine has its own session-only cookies and HTTP authentication; WebKit supplies JavaScript and modern login flows in fallback mode.

## Experimental assembly renderer

See [the engine roadmap](ENGINE_TODO.md) for the audited feature backlog,
recommended implementation order, and prerequisites for starting JavaScript.

### Engine status at a glance

“Done” refers to the supported subset; this is still an experimental renderer.

| Area | Status | Current scope / remaining work |
| --- | --- | --- |
| Navigation & history | Done | Back, forward, reload and SQLite visit history. |
| Text & links | Done | Native Unicode shaping, selection, link hit testing and pointer cursors. |
| CSS cascade | Done | Supported selectors/properties, inheritance, variables and `!important`. |
| HTML & mutable DOM | Partial | Static HTML and tree mutation work; full HTML5 parsing remains. |
| Layout | Partial | Blocks, inline boxes, flex/Grid, tables and positioning; full CSS behavior and sticky positioning remain. |
| Images & backgrounds | Partial | Raster/SVG and one background image layer; gradients and multiple layers remain. |
| Forms & editing | Partial | GET/POST and common controls; passwords, uploads and full validation remain. |
| Networking & authentication | Partial | HTTPS, redirects and HTTP auth; persistent assembly cookies and modern login flows remain. |
| Compatibility testing | Partial | Acid1 geometry checks and saved-page regressions; broader standards coverage remains. |
| JavaScript & web APIs | Todo | No JavaScript execution or script-facing browser APIs yet. |
| Assembly engine on Linux | Done | Shared native core, GTK/Pango/Cairo adapter, independent transport, controls and browser integration; the supported experimental subset runs on both platforms. |

On macOS choose **Navigate → Use Assembly Engine (Experimental)** or press **⌘E**; on Linux press **Ctrl+E**. Both platforms default to the assembly engine. Both applications open [DuckDuckGo's HTML homepage](https://html.duckduckgo.com/html/) at startup; typed URLs are loaded as entered. To launch with WebKit instead:

```sh
OOGABOOGA_ENGINE=webkit build/Oogabooga.app/Contents/MacOS/oogabooga https://example.com
OOGABOOGA_ENGINE=webkit ./build/linux/oogabooga https://example.com
```

The shared assembly engine tokenizes static HTML into a bounded flow tree, supplies implied `html`/`body` elements, decodes named/numeric entities, collapses whitespace, and maps UTF-8 byte offsets to native UTF-16 ranges. CSS parsing, selector matching, inheritance, and the cascade are handwritten assembly; native text layout measures styled glyphs and wraps them inside assembly-created, nested content boxes. It supports paragraphs, headings, lists, preformatted text, titles, legacy `<center>` alignment, and relative HTTP(S) links. Inline span/emphasis tags stay in text flow; inline-blocks have independent nested shaping contexts with retained source text. Native AppKit or Pango/Cairo services supply glyph shaping and drawing; assembly retains source maps, selection/hit regions and scene scrolling; WebKit is not used to parse or render this mode. Back/forward/reload and SQLite history work in both modes, with independent in-window navigation stacks. Clickable links show the pointing-hand cursor; authored link colors remain authoritative, including sites that intentionally use purple for unvisited links.

The custom adapters use AppKit on macOS and GTK/Pango/Cairo on Linux. The Linux backend emits native x86-64 assembly from the shared source; Python is never used at runtime. Both run the same 20 saved-page fixtures and Acid1 geometry reference, excluding glyph/widget regions and allowing a one-pixel edge tolerance. Native fonts and widgets can differ between platforms. It does **not** implement full HTML5 tree-construction rules, JavaScript, fragment anchors, file uploads, or modern login flows. Comments and inert script bodies are retained in a separate mutable document tree and excluded from rendering; style blocks are parsed as CSS and never displayed. Layout supports normal text flow, nested boxes, bounded flexbox/Grid subsets, and HTML tables. Relative/absolute/fixed positioning, stacking contexts, group opacity, clipping, and contained wheel scrolling have regression coverage; sticky positioning and full CSS box behavior remain incomplete. Unsupported pages can be opened in WebKit with ⌘E / Ctrl+E.

Website-styled submit buttons use assembly-configured native cells with CSS
background/text colors, uniform borders, corner radii and title padding. Native
tracking, keyboard focus and accessibility remain available; unstyled buttons
keep their platform appearance. Native buttons also support single-layer CSS background images. Per-side border
colors on native controls are not implemented yet.

Webpage text fields use a shared CSS content rectangle for displayed text and
native editing, with padding and vertical centering. Native bezels and focus
rings are disabled; default/CSS borders and backgrounds are painted explicitly.
The toolbar address field retains its native behavior. Try `/engine/inputs` on
the local fixture server.

CSS backgrounds support one raster/SVG image layer, stylesheet-relative URLs,
`background-size` (auto, lengths, percentages, cover/contain), basic positions,
repeat modes and rounded clipping. Images use the existing HTTP, cancellation
and decoding budgets; missing images preserve background colors. Comma-separated
screen media alternatives work for linked sheets and `@media`. Gradients,
multiple layers, escaped URLs and four-value edge-offset positions remain
unsupported. Try `http://localhost:8766/engine/backgrounds` in the local test lab.

Fetching uses `NSURLSession` with normal system TLS validation and an independent ephemeral cookie jar; it does not share WebKit logins or persist experimental-engine cookies across app restarts. Successful HTML responses are decoded using their HTTP charset header and normalized to UTF-8 before parsing. Foundation supplies the codecs; HTML Latin-1/ASCII labels use Windows-1252. Missing charset headers currently default to UTF-8; HTML meta-charset sniffing is not implemented. Unknown encodings or invalid byte sequences are rejected. Limits: 1 MiB for both the response and normalized UTF-8, 4,096 tree nodes, 64 open elements, 1,024 title bytes, and 2,048 bytes per link target. Late callbacks from canceled requests are ignored, and failed/unsupported responses are not recorded as visits.

`python3 tests/server.py` serves `/engine/` for static HTML, `/engine/css` for the CSS gallery, `/engine/features` for linked CSS, boxes, images, and GET forms, `/engine/layout` for flexbox, variables, SVG, and tables, `/engine/second` for link navigation, and `/engine/redirect` for redirects. `./build.sh test` includes guarded-buffer/truncated-input parser tests, malformed-byte corpora, CSS cascade/inheritance tests, Unicode layout/range assertions, and native-view/HTTP-transport tests. The renderer integration test uses a WebKit stand-in and verifies stylesheet source order, measured nested box geometry, image dimensions and alt fallbacks, native GET submissions, Unicode encoding, duplicate field names, disabled/hidden controls, resource failures and cancellation, and style reset between pages.

### Supported CSS subset

Embedded `<style>` blocks, linked HTTP(S) stylesheets, and decoded `style` attributes are supported. Selectors cover retained elements: type, `*`, `.class`, `#id`, compounds such as `p.notice`, comma groups, child combinators such as `.card > p`, and descendant chains such as `body .notice a`. Identifiers are ASCII with simple punctuation escapes (for example `.md\:block` and `.w-1\/2`); class/id matching is case-sensitive. Hex escapes remain unsupported. `:root` targets the document element. Links support `:link` and `:visited`; visited state uses exact resolved HTTP(S) URLs in SQLite history, and visited rules affect foreground color only. Attribute selectors, adjacent/general sibling combinators, simple `:not()`, and structural pseudo-classes are supported. `:first-child`, `:last-child`, `:only-child`, `:empty`, and forward/reverse `:nth-child()`/`:nth-of-type()` use the persistent document tree; hidden elements count as siblings and comments do not. The cascade honors specificity, source order, inline styles, `!important`, and `inherit`/`initial`/`unset`, with inherited text properties computed before painting.

Supported properties:

- `color`, solid `background`/`background-color`: basic named colors, `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, comma/space-separated `rgb()` and `rgba()`, and numeric/percentage alpha channels. Background and text colors preserve alpha.
- Common `font: [style] [weight] size[/line-height] family-list` shorthand and `font-family`: serif/sans-serif/monospace and common platform-family aliases, with comma fallbacks; `font-size`, normal/bold/numeric `font-weight`, normal/italic/oblique `font-style`, and none/underline `text-decoration`.
- `text-align`, `line-height`, `margin`, and the four `margin-*` properties map to native paragraph alignment, line metrics, spacing, and indents. `px`, `em`, and `rem` lengths are supported; font sizes and line heights also accept percentages, and line height accepts unitless multipliers. Font sizes are clamped to 6–72 pixels; spacing/line height to 200 pixels.
- `display:none` and HTML `hidden` remove content from layout, including descendants and links. Inline-block containers reserve independent margin/border boxes and support nested block text, controls, padding, borders, backgrounds, empty sized boxes, and baseline/top/bottom/middle/text-top/text-bottom alignment. Numeric and sub/super baseline shifts work. Ordinary inline text still has limited fragment-edge spacing/borders; full inline fragmentation remains in progress. `display:flex` and `display:grid` enable the bounded layouts below.
- Block `width`, `max-width`, `box-sizing`, and minimum content `height`, `padding` (one to four values), `padding-*`, solid `border-width` (one to four values), per-side `border-*-width`, and `border-color`, and margins. Widths, padding, and margins also accept percentages of the containing content width; horizontal margins accept `auto`. Other lengths support px/em/rem and zero; `width`/`height` also accept `auto`. Boxes retain nesting and backgrounds across multiple paragraphs. Eligible block margins collapse in assembly; padding, border, and formatting contexts prevent collapse. Solid/none `border` shorthand is supported alongside the longhand properties.

`float:left/right/none` and `clear:left/right/both/none` use assembly-computed
margin boxes and collision bands. Text lines exclude preceding floats and regain
width below them. Nested floated elements establish independent contexts. Float
geometry, exclusions, and rectangle painting are ARM64 assembly; AppKit supplies
glyph shaping, native controls, and drawing primitives. There is no WebKit layout
or third-party CSS layout library in this path.

The float path allows 128 floats per context. Empty block boxes retain a layout
range, auto heights reconcile with shaped text and nested float extents, and
placement follows intervening normal content. Padded containers constrain auto
and percentage widths. Assembly margin collapse covers adjacent blocks, eligible parent/child edges,
empty chains, and mixed-sign margins. Padding, borders, floats, flex/Grid items,
and supported formatting contexts establish barriers. Relative/absolute/fixed boxes use a retained assembly scene for painting and
interaction. General inline formatting, sticky positioning, scrollbars inside
CSS containers, and complete sizing/containing-block rules remain incomplete.

Run `python3 tests/server.py --port 8766` and open `/engine/floats` for manual
checks or `/engine/acid1` for the historical test. The test suite compares 140,302
canvas pixels against Acid1's reference, excluding text/widget regions and
allowing one-pixel edge differences. This verifies geometry and colors; native
font rasterization and form widgets remain platform-dependent. Fixture attribution
is in [`tests/fixtures/ACID1-LICENSE.md`](tests/fixtures/ACID1-LICENSE.md).

### Retained rendering and profiling

The ARM64 display list retains box fills/borders, disjoint native glyph/image
ranges, and per-line link hit regions. Positioned, clipped, or translucent pages
use assembly stacking-context order and grouped compositing; ordinary pages keep
the simple source-order replay path. Redraws replay commands that
intersect the damaged graphics region; scrolling and cursor changes do not run
HTML/CSS layout again. Native text services still shape glyphs and draw selections.
The command buffer is bounded (at most 32,768 commands); overflow falls back to
native glyph drawing rather than dropping page text.

After building, run `./tools/benchmark-layout.sh` for geometry-only timings, or
`./tools/benchmark-page.sh` for warmed offline parse/CSS/layout/paint timings.
The page benchmark paints a 600×500 viewport with local prefetched resources,
includes bitmap capture in its wall time, and reports inclusive display time
separately from individual phases. Profiling is disabled in normal use and sends
no telemetry. `./tools/benchmark-page.sh --reference` runs the Acid1 comparison
and exports `build/acid1-assembly.png`.

Run `sh tools/compatibility-report.sh` for the saved offline fixture dashboard at
`build/compatibility/index.html`. `./build.sh test` generates it automatically;
GitHub workflows retain the screenshots, independent references, JSON results,
and HTML report as artifacts. See [ENGINE_TODO.md](ENGINE_TODO.md) for remaining
engine work.

Screen `@media` queries support `screen`/`all`, `only`, `and`, and pixel `min-width`/`max-width`, including fractional thresholds and up to eight nested queries. They update on window resize; unsupported conditions and comma query lists remain inactive. Link media still accepts absent/`all`/`screen` only.

This is **not full CSS**. Bounded Grid and stylesheet imports are supported; sticky positioning, background images, `:is()`/`:where()`, and many other at-rules/selectors remain incomplete. The text viewport follows the window width and reflows while preserving form edits and scroll position. Fixed content that exceeds it may require horizontal scrolling.

Combined embedded and linked CSS is limited to 1 MiB of complete blocks, 4,096 rules, 256 bytes per selector group, and eight descendant components. Over-limit blocks/rules and unsupported declarations are ignored. Selector matching has a 134,217,728-step document budget; inline attributes retain the HTML parser's 2 KiB limit. Hidden text is excluded before UTF-16 range mapping, preserving links after hidden Unicode content.

### Web fonts and scene limits

Top-level `@font-face` supports HTTP(S) TrueType/OpenType URL sources, quoted
family names, declared weight/style variants, and ordered source fallbacks.
Assembly checks SFNT table bounds before CoreText decodes and shapes glyphs.
Fonts remain scoped to the page; arrival recomputes styles/layout while retaining
live controls. Limits: 16 faces, 2 MiB per font, 128 SFNT tables, 8,192 glyphs,
and the shared 32-request/8-MiB page budget. WOFF/WOFF2, collections, `local()`,
variable axes, font synthesis, and nested conditional font-face rules are deferred.

Scene coordinates cover box/glyph painting, link hit testing, cursor regions,
mouse selection, native widget clips, and contained wheel scrolling. Contained
scroll offsets survive reflow by stable DOM identity. Native controls still use
platform views: arbitrary sibling overlap/compositing with glyphs and controls,
complete keyboard scroll routing and ordinary inline-fragment border/padding layout remain
in the [engine backlog](ENGINE_TODO.md). These are bounded static-page features,
not complete CSS conformance.

### Variables, flexbox, and tables

Custom properties inherit through the retained element tree and honor selector
specificity, inline styles, source order, and `!important`. `var(--name, fallback)`
expands nested references before parsing normal declarations. Missing/cyclic
references without a usable fallback discard that declaration. Limits: 128-byte
names, 2 KiB values, 512 own definitions per node, 65,536 definitions and 2 MiB of
accepted definition-value bytes per page, 16 expansion levels, and 8 KiB output
per expanded value. Escaped custom-property names and `@property` are unsupported.

Flex supports `flex-direction:row`/`column`, row wrapping, `flex-grow`,
`flex-shrink`, `flex-basis`, common `flex` shorthand, one/two-value `gap`,
`row-gap`, `column-gap`, `justify-content` (start/end/center/space distribution),
`align-items`, and `align-self`. Native glyph measurement supplies preferred sizes;
assembly partitions rows and distributes space. Each container supports up to 256
items. Min/max freezing redistributes remaining space on both axes; floated and positioned parents reflow child contexts against their used widths. This is a bounded layout subset: automatic minimums, fractional-factor corner cases, CSS order, column wrapping, and complete Unicode intrinsic-size rules are not implemented. TextKit table cells
supply drawing; some unequal-height flex backgrounds can stretch to the row.

Tables retain `table`, `tr`, `td`, `th`, row groups, and captions, including omitted
cell/row end tags. Column sizes account for preferred content, explicit/percentage
widths, and available space. `colspan`/`rowspan`, header alignment, borders,
backgrounds, and legacy `width`, `align`, `cellpadding`, and `cellspacing` work.
Limits are 64 columns, 256 rows, and spans up to 64. CSS border collapsing, column
objects, and the complete HTML table-sizing algorithm remain unsupported.

### Styled inline links

Short, single-line `<a>` elements with backgrounds, padding, borders, or a minimum
height use measured native inline boxes. They support all four padding/margin
edges, solid borders, single-value `border-radius` (pixels or percentages),
`width`/`height`, `min-width`/`min-height`, `max-width`, `box-sizing`, `text-align`,
and `vertical-align:baseline`/`middle`. The full box activates the link and shows
a pointing-hand cursor; its text remains available through an accessibility link
label. Website text/background colors are preserved.

This path handles text-only link contents up to 2 KiB, including simple nested
text markup. Links with hidden content, line breaks, images, or form controls
retain ordinary text flow. Nested text is drawn using the anchor’s computed text
style. General inline-block containers use the independent formatting contexts above; this short styled-link adapter remains a separate optimized path. Multiline ordinary-inline box fragmentation remains unsupported. Resize and progressive stylesheet updates preserve native link
controls and update their geometry or return them to ordinary text as needed.

### Images and forms

`<img>` loads relative HTTP(S) raster and SVG resources through the engine's cookie session. CSS or HTML dimensions scale images, preserving aspect ratio when one dimension is omitted; natural images fit the current containing width. Failed/unsupported images display `alt` text. CSS background images and animation controls remain unsupported.

Inline `<svg>` and `image/svg+xml` responses support rect/rounded rect, circle,
ellipse, line, polyline, polygon, and path elements. Paths cover absolute/relative
M/L/H/V/C/S/Q/T/A/Z commands; elliptical arcs use bounded samples. Groups inherit
fill/stroke/currentColor, width, opacity, fill rule, line caps/joins, and transforms
(translate, scale, rotate, matrix). `viewBox` uses centered aspect-preserving fit.
XML/path interpretation is assembly; CoreGraphics draws the geometry. Limits:
64 KiB inline markup, 256 KiB external SVG, 1–1024 pixels per dimension, 31 nested
groups, 1,024 elements, and 2 KiB per attribute. SVG scripts, external references,
text, gradients, masks, clipping, internal stylesheet selectors, and animation are
unsupported; definitions and script/resource containers are skipped.

Forms support GET and URL-encoded POST, native text/search/email/url/tel inputs, checkboxes, form-scoped radio groups, single/multiple selects, multiline textareas, hidden values, submit inputs, and buttons with nested text markup or `aria-label` icon fallbacks. Non-submit button/reset controls are displayed disabled because their JavaScript/reset behavior is not implemented. Default button widths fit their titles; explicit CSS widths remain authoritative. Multiple selects use a menu with independent checkmarks. Click Submit or press Return in a text field; Return inserts a line in a textarea. Submissions preserve document order and repeated names, exclude disabled/unchecked controls and unclicked submitters, and encode UTF-8 with CRLF-normalized line breaks. GET replaces the action's query; POST retains that query and sends `application/x-www-form-urlencoded` in the request body. Other methods/encodings, password inputs, and uploads are unsupported. Each field is limited to 2048 UTF-8 bytes. History traversal and Reload use saved URLs with GET; POST bodies are not automatically replayed.

HTML displays and records its visit immediately after parsing. Subresources then load sequentially; each result updates the displayed page without duplicating history or resetting controls. Available stylesheets are always combined in document order. The session uses a 16 MiB memory-only HTTP cache with normal HTTP freshness rules; Reload bypasses it. Limits: 32 HTTP(S) requests, ten seconds per request, 1 MiB per stylesheet, 2 MiB per image/font, and 8 MiB of accepted resource data per page. Raster metadata is checked before decoding (8192 pixels per dimension and 16 megapixels). Resource errors leave the HTML usable; navigation and engine switching cancel pending work. Stylesheets accept `text/css` and absent/`all`/`screen` link media; nested `@import` follows HTTP(S) relative URLs using the final stylesheet response URL as its base. Import expansion preserves source order and width media queries, rejects ancestor URL cycles (including fragments), and shares the request/byte/cancellation limits. The private import tree is limited to 64 sheets and eight import levels. Escaped import URLs, cascade layers, and import `supports()` conditions are not supported.

## Assembly and architecture

Rhun builds native assembly and links system libraries. Both Oogabooga applications use that approach. No compiler-generated Objective-C bridge is linked into the shipped macOS app.

- `src/engine/`: handwritten ARM64 HTML tokenizer, entity/attribute scanner, flow tree, CSS parser/selectors/cascade, form URL encoding, and UTF-16 range mapping. `css.inc` defines computed-style metadata and limits.
- `src/mac/reflow.s`, `css.s`, and `blocks.s`: computed font/color/paragraph attributes and nested native text boxes.
- `src/mac/resources.s`, `attachments.s`, and `forms.s`: ordered HTTP subresources, raster images and fallbacks, native controls, and GET/POST submission; `select.s` and `forms-extra.s` handle option menus, radio groups, multiline fields, and serialization.
- `src/mac/charset.s`: HTTP charset selection and UTF-8 normalization through platform codecs.
- `src/engine/flex-layout.s`, `table-layout.s`, `variables.s`, and `colors.s`: flex/table geometry, custom-property resolution, and modern colors.
- `src/mac/flow.s` and `svg*.s`: native cell measurement/drawing and assembly SVG interpretation over CoreGraphics.
- `src/engine/flow.s`, `font.s`, `media.s`, and `labels.s`: inline flow, font shorthand, width queries, and plain-text button labels in ARM64 assembly.
- `src/mac/engine.s`: native text presentation, asynchronous HTTP/TLS integration, experimental-engine navigation, and engine switching.
- `src/mac/browser.s`: ARM64 AppKit window/controls, native WebKit delegates, navigation, popup ownership, and title observation.
- `src/mac/url.s`: ARM64 address/search handling, using Foundation for Unicode and URL construction.
- `src/mac/history.s`: ARM64 history search integration and native table rendering.
- `src/mac/menus.s` and `dialogs.s`: native menus, HTTP authentication, and JavaScript dialogs. Dialogs are app-modal; WebKit completion blocks are invoked synchronously, exactly once, before returning from the delegate call.
- `src/mac/runtime.s`: Objective-C class/selector registration and method encodings; `mac.inc` documents register/stack conventions. AppKit/WebKit objects are managed with explicit retain/release ownership.
- `src/mac/start.s` and `src/core.s`: macOS executable entry and ARM64 SQLite operations.
- `src/linux/browser.s` and `core.s`: x86-64 GTK application and SQLite operations. Both platform cores expose search callbacks and updates by visit ID, using `src/history.inc` for shared SQL.
- `build.sh`: dispatches by OS, assembles handwritten `.s` files, and links the native libraries. Linux uses PIE, RELRO, immediate binding, and a non-executable stack; macOS packages and ad-hoc signs the `.app`.
- `src/gtk/`: assembly text/scene adapter, native controls, resources and HTTP session; common SVG/background geometry is shared with macOS.
- `flatpak/dev.oogabooga.Browser.json`: builds and tests both Linux rendering paths inside the GNOME 50 SDK.

C and Objective-C sources under `tests/` are assertion harnesses only. They are not linked into either shipped application. On macOS, `OOGABOOGA_PROFILE=/path/to/profile` selects an alternate SQLite history directory for isolated testing; WebKit website data still follows the app's bundle identity.

Both platforms default to the experimental assembly renderer. WebKit remains available through ⌘E / Ctrl+E, including the maintained GNOME runtime engine in Flatpak. Native libraries provide UI, glyph shaping, raster codecs and HTTP/TLS; our assembly owns HTML/CSS/SVG parsing, layout, scenes and application behavior. WebKit helper processes consume memory separately when the fallback is used.

## Storage

History uses SQLite WAL. On macOS: `~/Library/Application Support/Oogabooga/history.sqlite3`. Native Linux: `$XDG_DATA_HOME/oogabooga/history.sqlite3` (default `~/.local/share/oogabooga/history.sqlite3`), with website data beside it, persistent cookies in `cookies.sqlite3`, and cache under `$XDG_CACHE_HOME/oogabooga`. Flatpak redirects these paths into its private app directory. Each successful HTTP(S) page load creates a visit, including repeated visits and popup loads. Redirects record the final URL. Failed loads are not recorded. Same-document hash/history API changes are not separately recorded.

Schema: `visits(id INTEGER PRIMARY KEY, url TEXT, title TEXT, visited_at INTEGER)`; timestamps are Unix seconds. History is plaintext on disk. Cookies are managed separately by WebKit, not duplicated into the history database. macOS uses bundle identity `dev.oogabooga.browser`; Flatpak uses `dev.oogabooga.Browser`. Assembly HTTP credentials and cookies are session-only on both platforms. Linux uses a separate libsoup session; WebKitGTK retains its own cookie profile and authentication policy in fallback mode. No application password manager is included.

## Local integration fixture

```sh
python3 tests/server.py
```

Browse to `http://localhost:8765` (or use `python3 tests/server.py --port 8766`). The index links engine galleries, saved compatibility fixtures, Acid1, browser interaction checks and the latest generated compatibility report. It works without JavaScript. Set the cookie, visit Check cookie, quit/reopen the browser, and check again. The page also provides HTTP authentication (`test` / `browser`), popup/opener/close, and back/forward checks. Check History and its search field after visiting the pages.

## Scope

This is a minimal native browser: one main browsing view with separate popup windows. No tabs, downloads UI, extensions, bookmarks, password vault, default-browser registration, or Windows port. Linux ARM64 is not implemented yet. Popup windows have no navigation toolbar. External application URL schemes are blocked. Websites that prohibit embedded WebKit login, require a particular browser identity, DRM, or unsupported permissions may not work. No claim that every OAuth provider or passkey flow is supported.

## References

- [rhun source](https://github.com/vshvedov/rhun) and [macOS build](https://github.com/vshvedov/rhun/blob/main/tools/build-mac.sh)
- [WebKitGTK API](https://webkitgtk.org/reference/webkit2gtk/stable/)
- [Flatpak build documentation](https://docs.flatpak.org/en/latest/first-build.html)
- [Apple: persistent WebKit data stores](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)

No rhun source code is included.

## License

Licensed under the [Apache License 2.0](LICENSE).
