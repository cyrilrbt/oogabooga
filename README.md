# Oogabooga

A small native browser for Apple silicon macOS 12+, inspired by rhun's direct assembly-and-link build. No Electron, npm, package manager, or downloaded engine. Uses the system AppKit, WebKit, and SQLite libraries.

## Build and run

Install Xcode command-line tools, then:

```sh
./build.sh release
open build/Oogabooga.app
```

Or launch with a starting URL:

```sh
build/Oogabooga.app/Contents/MacOS/oogabooga https://github.com
```

`./build.sh test` builds the app and runs the assembly SQLite tests. `./build.sh` makes a debug build. The app is signed ad hoc for local use; distribution would require Developer ID signing and notarization.

## Features

- Address/search bar, back/forward, reload/stop, trackpad navigation.
- System WebKit renders websites and runs JavaScript with its normal TLS validation.
- Persistent WebKit profile for cookies, local storage, and website sessions. Persistent cookies survive restart according to their expiry; session cookies follow WebKit's lifecycle.
- Standard website login forms, HTTP Basic/Digest/NTLM credential prompts, and separate popup windows that preserve `window.opener` for login flows.
- SQLite visit history with titles and timestamps, searchable from the History window; double-click a result to open it. Shows the latest 1,000 matching visits.
- JavaScript alert, confirm, and prompt dialogs; normal copy/paste shortcuts.

Shortcuts: ⌘L address, ⌘R reload/stop, ⌘[ back, ⌘] forward, ⌘Y history, ⌘Q quit.

## Assembly and architecture

Rhun's macOS build assembles AArch64 code and links system frameworks. Oogabooga follows that build shape, but **is not an all-assembly implementation**:

- `src/core.s`: handwritten ARM64 entry point, SQLite schema initialization, prepared inserts, parameter binding, and error propagation. Uses Darwin's calling convention and preserves callee-saved registers.
- `src/Browser.m`: ARC-managed Objective-C bridge for AppKit/WebKit, URL input, authentication, and history queries. Compiled to readable ARM64 assembly in `build/asm/Browser.s`, then assembled into an object.
- `build.sh`: compile to assembly → assemble → link system frameworks and SQLite → package and ad-hoc sign `.app`.

The rendering engine is the OS WebKit installation. Assembly does not make HTML, JavaScript, TLS, or web compatibility inexpensive to reimplement; reusing the maintained system engine keeps the application small. WebKit helper processes still consume memory separately from the executable.

## Storage

History: `~/Library/Application Support/Oogabooga/history.sqlite3`, with SQLite WAL enabled. Each successful HTTP(S) page load creates a visit, including repeated visits and popup loads. Redirects record the final URL. Failed loads are not recorded. Same-document hash/history API changes are not separately recorded.

Schema: `visits(id INTEGER PRIMARY KEY, url TEXT, title TEXT, visited_at INTEGER)`; timestamps are Unix seconds. History is plaintext on disk. Cookies are managed separately by WebKit under the app's bundle identity `dev.oogabooga.browser`, not duplicated into the history database. HTTP authentication passwords are kept only for the session; no password manager is included.

## Local integration fixture

```sh
python3 tests/server.py
```

Browse to `http://localhost:8765`. Set the cookie, visit Check cookie, quit/reopen the browser, and check again. The page also provides HTTP authentication (`test` / `browser`), popup/opener/close, and back/forward checks. Check History and its search field after visiting the pages.

## Scope

This is a minimal macOS browser: one main browsing view with separate popup windows. No tabs, downloads UI, extensions, bookmarks, password vault, default-browser registration, or Linux/Windows port. Popup windows have no navigation toolbar. External application URL schemes are blocked. Websites that prohibit embedded WebKit login, require a particular browser identity, DRM, or unsupported permissions may not work. No claim that every OAuth provider or passkey flow is supported.

## References

- [rhun source](https://github.com/vshvedov/rhun) and [macOS build](https://github.com/vshvedov/rhun/blob/main/tools/build-mac.sh)
- [Apple: persistent WebKit data stores](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)

No rhun source code is included.
