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

Replace `VERSION` with the version in the downloaded filename. Install Flatpak through your distribution first. The bundle references the GNOME 50 runtime on Flathub and installs the runtime as needed; this does not publish Oogabooga to Flathub. Bundles are downloaded from GitHub and installed manually. The app has network, display, GPU, and audio access, with no blanket access to your home directory. Its profile lives under `~/.var/app/dev.oogabooga.Browser/`. The optional native archive requires Ubuntu 24.04+ or a compatible x86-64 distribution with GTK 3, WebKitGTK 4.1, SQLite, and a sufficiently recent glibc.

## Versioning

`VERSION` is the single source of truth for the app version. Change only that file when bumping a stable SemVer release (`MAJOR.MINOR.PATCH`). Update [CHANGELOG.md](CHANGELOG.md) in the same change, documenting additions, behavior changes, and fixes under the matching version and date.

Builds generate macOS bundle versions and Flatpak release metadata from this file; AppStream release dates use the UTC build date. Generated metadata lives in `build/metadata/`, and the files in `assets/` are templates. Linux packages also include the `VERSION` file. GitHub release titles include the version, and each push gets a unique tag such as `v0.2.0+build.RUN_ID.ATTEMPT`; download filenames include the stable version from `VERSION`. The latest-release page always points to the newest successful build.

## Build and run

### Linux

On Ubuntu 24.04:

```sh
sudo apt-get install build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev libsqlite3-dev
./build.sh release
./build/linux/oogabooga https://github.com
```

`./build.sh test` runs the same assembly SQLite tests as macOS. `./tools/package-linux.sh` makes the native archive. Linux currently targets x86-64 only, using the System V ABI. Run in an X11 or Wayland desktop session. The native archive includes `oogabooga.png`; keep it beside the executable for the window icon. To use the supplied desktop launcher, also install that PNG as `~/.local/share/icons/hicolor/512x512/apps/dev.oogabooga.Browser.png` and put the executable on your PATH.

To run browser integration tests, install `xvfb xauth dbus-x11 python3`, run `./build.sh test`, then `./tools/test-linux.sh`. The harness checks real WebKit rendering, cookie persistence across process restart, HTTP authentication, popup opener/close behavior, navigation, history search/reopening, and failed-load history exclusion. Its small C harness is test-only; no C application code is linked into the shipped Linux executable. It requires a working WebKit process sandbox and uses an isolated temporary profile and localhost fixture.

To build a Flatpak locally, install `flatpak` and `flatpak-builder`, then:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak-builder --user --install-deps-from=flathub --force-clean --repo=flatpak-repo flatpak-build flatpak/dev.oogabooga.Browser.json
flatpak build-bundle flatpak-repo Oogabooga-$(./tools/version.sh)-linux-x86_64.flatpak dev.oogabooga.Browser --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
```

The GitHub Flatpak job uses `tools/build-flatpak.sh` inside the preloaded GNOME 50 build image. It deliberately uses the installed SDK/runtime without `--install-deps-from`, avoiding OSTree updates on the container overlay filesystem. Refresh the container image to obtain newer SDK/runtime builds.

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
| Quit | ⌘Q | Ctrl+Q |
| Cut / copy / paste | ⌘X / ⌘C / ⌘V | Ctrl+X / Ctrl+C / Ctrl+V |
| Select all | ⌘A | Ctrl+A |
| Undo / redo | ⌘Z / ⇧⌘Z | Ctrl+Z / Ctrl+Shift+Z |

Editing commands act on the focused field/page and depend on that widget's editing support. Browser commands also work from history and popup windows; Open Location brings the main address bar forward. The experimental engine toggle is macOS-only (⌘E). Linux uses the standard WebKitGTK HTTP authentication and JavaScript dialogs.

## Experimental assembly renderer (macOS)

Choose **Navigate → Use Assembly Engine (Experimental)** or press **⌘E** to switch the current page between the assembly renderer and WebKit. WebKit remains the default. To start in assembly mode:

```sh
OOGABOOGA_ENGINE=asm build/Oogabooga.app/Contents/MacOS/oogabooga http://localhost:8765/engine/
```

The ARM64 engine tokenizes static HTML into a bounded flow tree, supplies implied `html`/`body` elements, decodes named/numeric entities, collapses whitespace, and maps UTF-8 byte offsets to native UTF-16 ranges. CSS parsing, selector matching, inheritance, and the cascade are handwritten assembly; native text layout measures styled glyphs and wraps them inside assembly-created, nested content boxes. It supports paragraphs, headings, lists, preformatted text, titles, and relative HTTP(S) links. Native AppKit text services supply glyph shaping, drawing, text selection, link hit testing, and scrolling; WebKit is not used to parse or render this mode. Back/forward/reload and SQLite history work in both modes, with independent in-window navigation stacks.

This first engine is macOS-only. Linux continues to use WebKitGTK. It does **not** implement full HTML5 tree-construction rules, JavaScript, fragment anchors, file uploads, or modern login flows. Comments and script bodies are excluded; style blocks are parsed as CSS and never displayed. Layout supports normal text flow and nested block boxes; flex/grid, floats, and positioning remain unsupported. Unsupported pages can be opened in WebKit with ⌘E.

Fetching uses `NSURLSession` with normal system TLS validation and an independent ephemeral cookie jar; it does not share WebKit logins or persist experimental-engine cookies across app restarts. Successful HTML responses are decoded using their HTTP charset header and normalized to UTF-8 before parsing. Foundation supplies the codecs; HTML Latin-1/ASCII labels use Windows-1252. Missing charset headers currently default to UTF-8; HTML meta-charset sniffing is not implemented. Unknown encodings or invalid byte sequences are rejected. Limits: 1 MiB for both the response and normalized UTF-8, 4,096 tree nodes, 64 open elements, 1,024 title bytes, and 2,048 bytes per link target. Late callbacks from canceled requests are ignored, and failed/unsupported responses are not recorded as visits.

`python3 tests/server.py` serves `/engine/` for static HTML, `/engine/css` for the CSS gallery, `/engine/features` for linked CSS, boxes, images, and GET forms, `/engine/second` for link navigation, and `/engine/redirect` for redirects. `./build.sh test` includes guarded-buffer/truncated-input parser tests, malformed-byte corpora, CSS cascade/inheritance tests, Unicode layout/range assertions, and native-view/HTTP-transport tests. The renderer integration test uses a WebKit stand-in and verifies stylesheet source order, measured nested box geometry, image dimensions and alt fallbacks, native GET submissions, Unicode encoding, duplicate field names, disabled/hidden controls, resource failures and cancellation, and style reset between pages.

### Supported CSS subset

Embedded `<style>` blocks, linked HTTP(S) stylesheets, and decoded `style` attributes are supported. Selectors cover retained flow elements: type, `*`, `.class`, `#id`, compounds such as `p.notice`, comma groups, child combinators such as `.card > p`, and descendant chains such as `body .notice a`. Identifiers are ASCII; class/id matching is case-sensitive. The cascade honors specificity, source order, inline styles, `!important`, and `inherit`/`initial`/`unset`, with inherited text properties computed before painting.

Supported properties:

- `color`, solid `background`/`background-color`: basic named colors, `#rgb`, `#rrggbb`, and comma-form `rgb()` values; transparent backgrounds are accepted.
- `font-family`: serif/sans-serif/monospace and common platform-family aliases, with comma fallbacks; `font-size`, normal/bold/numeric `font-weight`, normal/italic/oblique `font-style`, and none/underline `text-decoration`.
- `text-align`, `line-height`, `margin`, and the four `margin-*` properties map to native paragraph alignment, line metrics, spacing, and indents. `px`, `em`, and `rem` lengths are supported; font sizes and line heights also accept percentages, and line height accepts unitless multipliers. Font sizes are clamped to 6–72 pixels; spacing/line height to 200 pixels.
- `display: none` removes content from layout, including descendants and links; normal block/inline display values restore visibility but do not implement a new box-formatting model.
- Block `width`, `max-width`, `box-sizing`, and minimum content `height`, `padding` (one to four values), `padding-*`, solid `border-width` and `border-color`, and margins. Widths, padding, and margins also accept percentages of the containing content width; horizontal margins accept `auto`. Other lengths support px/em/rem and zero; `width`/`height` also accept `auto`. Boxes retain nesting and backgrounds across multiple paragraphs. Margins do not collapse; solid/none `border` shorthand is supported, alongside the longhand properties.

This is **not full CSS**. `@import`, at-rules, pseudo/attribute selectors, sibling combinators, custom properties, flex/grid, floats, positioning, background images, and responsive layout are unsupported. The text viewport follows the window width and reflows while preserving form edits and scroll position. Fixed content that exceeds it may require horizontal scrolling.

Combined embedded and linked CSS is limited to 64 KiB of complete blocks, 256 rules, 256 bytes per selector group, and eight descendant components. Over-limit blocks/rules and unsupported declarations are ignored. Selector matching has a one-million-step document budget; inline attributes retain the HTML parser's 2 KiB limit. Hidden text is excluded before UTF-16 range mapping, preserving links after hidden Unicode content.

### Images and forms

`<img>` loads relative HTTP(S) raster resources through the engine's cookie session. CSS or HTML dimensions scale images, preserving aspect ratio when one dimension is omitted; natural images fit the current containing width. Failed/unsupported images display `alt` text. SVG, CSS background images, and animation controls are unsupported.

Forms support GET and URL-encoded POST, native text/search/email/url/tel inputs, checkboxes, form-scoped radio groups, single/multiple selects, multiline textareas, hidden values, submit inputs, and simple text buttons. Multiple selects use a menu with independent checkmarks. Click Submit or press Return in a text field; Return inserts a line in a textarea. Submissions preserve document order and repeated names, exclude disabled/unchecked controls and unclicked submitters, and encode UTF-8 with CRLF-normalized line breaks. GET replaces the action's query; POST retains that query and sends `application/x-www-form-urlencoded` in the request body. Other methods/encodings, password inputs, and uploads are unsupported. Each field is limited to 2048 UTF-8 bytes. History traversal and Reload use saved URLs with GET; POST bodies are not automatically replayed.

HTML displays and records its visit immediately after parsing. Subresources then load sequentially; each result updates the displayed page without duplicating history or resetting controls. Available stylesheets are always combined in document order. The session uses a 16 MiB memory-only HTTP cache with normal HTTP freshness rules; Reload bypasses it. Limits: 32 HTTP(S) requests, ten seconds per request, 64 KiB per stylesheet, 2 MiB per image, and 8 MiB of accepted resource data per page. Raster metadata is checked before decoding (8192 pixels per dimension and 16 megapixels). Resource errors leave the HTML usable; navigation and engine switching cancel pending work. Stylesheets accept `text/css` and absent/`all`/`screen` link media; nested `@import` is not followed.

## Assembly and architecture

Rhun builds native assembly and links system libraries. Both Oogabooga applications use that approach. No compiler-generated Objective-C bridge is linked into the shipped macOS app.

- `src/engine/`: handwritten ARM64 HTML tokenizer, entity/attribute scanner, flow tree, CSS parser/selectors/cascade, form URL encoding, and UTF-16 range mapping. `css.inc` defines computed-style metadata and limits.
- `src/mac/reflow.s`, `css.s`, and `blocks.s`: computed font/color/paragraph attributes and nested native text boxes.
- `src/mac/resources.s`, `attachments.s`, and `forms.s`: ordered HTTP subresources, raster images and fallbacks, native controls, and GET/POST submission; `select.s` and `forms-extra.s` handle option menus, radio groups, multiline fields, and serialization.
- `src/mac/charset.s`: HTTP charset selection and UTF-8 normalization through platform codecs.
- `src/mac/engine.s`: native text presentation, asynchronous HTTP/TLS integration, experimental-engine navigation, and engine switching.
- `src/mac/browser.s`: ARM64 AppKit window/controls, native WebKit delegates, navigation, popup ownership, and title observation.
- `src/mac/url.s`: ARM64 address/search handling, using Foundation for Unicode and URL construction.
- `src/mac/history.s`: ARM64 history search integration and native table rendering.
- `src/mac/menus.s` and `dialogs.s`: native menus, HTTP authentication, and JavaScript dialogs. Dialogs are app-modal; WebKit completion blocks are invoked synchronously, exactly once, before returning from the delegate call.
- `src/mac/runtime.s`: Objective-C class/selector registration and method encodings; `mac.inc` documents register/stack conventions. AppKit/WebKit objects are managed with explicit retain/release ownership.
- `src/mac/start.s` and `src/core.s`: macOS executable entry and ARM64 SQLite operations.
- `src/linux/browser.s` and `core.s`: x86-64 GTK application and SQLite operations. Both platform cores expose search callbacks and updates by visit ID, using `src/history.inc` for shared SQL.
- `build.sh`: dispatches by OS, assembles handwritten `.s` files, and links the native libraries. Linux uses PIE, RELRO, immediate binding, and a non-executable stack; macOS packages and ad-hoc signs the `.app`.
- `flatpak/dev.oogabooga.Browser.json`: builds the Linux assembly app inside the GNOME 50 SDK, reusing the runtime's maintained WebKitGTK engine.

C and Objective-C sources under `tests/` are assertion harnesses only. They are not linked into either shipped application. On macOS, `OOGABOOGA_PROFILE=/path/to/profile` selects an alternate SQLite history directory for isolated testing; WebKit website data still follows the app's bundle identity.

The default rendering engine is the OS WebKit installation, or the maintained GNOME runtime WebKitGTK in Flatpak. The experimental macOS static renderer is described above. Assembly does not make HTML, JavaScript, TLS, or web compatibility inexpensive to reimplement; reusing the maintained system engine keeps the application small. WebKit helper processes still consume memory separately from the executable.

## Storage

History uses SQLite WAL. On macOS: `~/Library/Application Support/Oogabooga/history.sqlite3`. Native Linux: `$XDG_DATA_HOME/oogabooga/history.sqlite3` (default `~/.local/share/oogabooga/history.sqlite3`), with website data beside it, persistent cookies in `cookies.sqlite3`, and cache under `$XDG_CACHE_HOME/oogabooga`. Flatpak redirects these paths into its private app directory. Each successful HTTP(S) page load creates a visit, including repeated visits and popup loads. Redirects record the final URL. Failed loads are not recorded. Same-document hash/history API changes are not separately recorded.

Schema: `visits(id INTEGER PRIMARY KEY, url TEXT, title TEXT, visited_at INTEGER)`; timestamps are Unix seconds. History is plaintext on disk. Cookies are managed separately by WebKit, not duplicated into the history database. macOS uses bundle identity `dev.oogabooga.browser`; Flatpak uses `dev.oogabooga.Browser`. macOS HTTP credentials are session-only; Linux uses WebKitGTK's authentication dialog and credential policy. No application password manager is included.

## Local integration fixture

```sh
python3 tests/server.py
```

Browse to `http://localhost:8765`. Set the cookie, visit Check cookie, quit/reopen the browser, and check again. The page also provides HTTP authentication (`test` / `browser`), popup/opener/close, and back/forward checks. Check History and its search field after visiting the pages.

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
