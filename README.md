# oogabooga

A small native browser for Apple silicon macOS 12+ and x86-64 Linux, inspired by rhun's direct assembly-and-link build. The Linux application is entirely handwritten assembly and calls GTK 3, WebKitGTK 4.1, and SQLite directly. The macOS application uses an assembly core with an Objective-C UI bridge. No Electron or npm.

## Download

Pushes to `main` run the Browser downloads workflow: test both native builds, build a Linux Flatpak, and publish one GitHub Release with all downloads and SHA-256 checksums. A release is published only after all three build jobs pass. You can also run it manually from Actions on `main`. Each release points to the exact built commit.

- [Download latest Linux Flatpak](https://github.com/cyrilrbt/oogabooga/releases/latest/download/Oogabooga-linux-x86_64.flatpak)
- [Download latest Linux native archive](https://github.com/cyrilrbt/oogabooga/releases/latest/download/Oogabooga-linux-x86_64.tar.gz)
- [Download latest macOS DMG](https://github.com/cyrilrbt/oogabooga/releases/latest/download/Oogabooga-macos-arm64.dmg)
- [Download latest app ZIP](https://github.com/cyrilrbt/oogabooga/releases/latest/download/Oogabooga-macos-arm64.app.zip)
- [All releases](https://github.com/cyrilrbt/oogabooga/releases)

These links become available after the first successful workflow run. For macOS, open the DMG and drag Oogabooga into Applications. macOS builds target Apple silicon macOS 12+. They are ad-hoc signed, not Developer ID signed or notarized, so Gatekeeper may block downloaded copies. Public distribution without that warning requires Apple signing credentials and notarization.

To package locally after building, run `./tools/package-mac.sh`; files appear in `build/dist/`. GitHub Actions also retains downloads as workflow artifacts for 14 days. The workflow uses its built-in token with release write permission; no additional secrets are required. Repository or organization policies must allow Actions to create releases.

Install the Linux Flatpak with:

```sh
flatpak install --user ./Oogabooga-linux-x86_64.flatpak
flatpak run dev.oogabooga.Browser
```

Install Flatpak through your distribution first. The bundle references the GNOME 50 runtime on Flathub and installs the runtime as needed; this does not publish Oogabooga to Flathub. Bundles are downloaded from GitHub and installed manually. The app has network, display, GPU, and audio access, with no blanket access to your home directory. Its profile lives under `~/.var/app/dev.oogabooga.Browser/`. The optional native archive requires Ubuntu 24.04+ or a compatible x86-64 distribution with GTK 3, WebKitGTK 4.1, SQLite, and a sufficiently recent glibc.

## Versioning

`VERSION` is the single source of truth for the app version. Change only that file when bumping a stable SemVer release (`MAJOR.MINOR.PATCH`). Version 0.2.0 adds Linux support to the initial macOS release.

Builds generate macOS bundle versions and Flatpak release metadata from this file; AppStream release dates use the UTC build date. Generated metadata lives in `build/metadata/`, and the files in `assets/` are templates. Linux packages also include the `VERSION` file. GitHub release titles include the version, and each push gets a unique tag such as `v0.2.0+build.RUN_ID.ATTEMPT`; download filenames stay fixed for the latest-download links.

## Build and run

### Linux

On Ubuntu 24.04:

```sh
sudo apt-get install build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev libsqlite3-dev
./build.sh release
./build/linux/oogabooga https://github.com
```

`./build.sh test` runs the same assembly SQLite tests as macOS. `./tools/package-linux.sh` makes the native archive. Linux currently targets x86-64 only, using the System V ABI. Run in an X11 or Wayland desktop session.

To run browser integration tests, install `xvfb xauth dbus-x11 python3`, run `./build.sh test`, then `./tools/test-linux.sh`. The harness checks real WebKit rendering, cookie persistence across process restart, HTTP authentication, popup opener/close behavior, navigation, history search/reopening, and failed-load history exclusion. Its small C harness is test-only; no C application code is linked into the shipped Linux executable. It requires a working WebKit process sandbox and uses an isolated temporary profile and localhost fixture.

To build a Flatpak locally, install `flatpak` and `flatpak-builder`, then:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak-builder --user --install-deps-from=flathub --force-clean --repo=flatpak-repo flatpak-build flatpak/dev.oogabooga.Browser.json
flatpak build-bundle flatpak-repo build/Oogabooga-linux-x86_64.flatpak dev.oogabooga.Browser --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
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

`./build.sh test` builds the app and runs the assembly SQLite tests. `./build.sh` makes a debug build. The app is signed ad hoc for local use; distribution would require Developer ID signing and notarization.

## Features

- Address/search bar, back/forward, reload/stop, trackpad navigation.
- System WebKit renders websites and runs JavaScript with its normal TLS validation.
- Persistent WebKit profile for cookies, local storage, and website sessions. Persistent cookies survive restart according to their expiry; session cookies follow WebKit's lifecycle.
- Standard website login forms, HTTP Basic/Digest/NTLM credential prompts, and separate popup windows that preserve `window.opener` for login flows.
- SQLite visit history with titles and timestamps, searchable from the History window; double-click a result to open it. Shows the latest 1,000 matching visits.
- JavaScript alert, confirm, and prompt dialogs; normal copy/paste shortcuts.

Shortcuts: ⌘L address, ⌘R reload/stop, ⌘[ back, ⌘] forward, ⌘Y history, ⌘Q quit. Linux uses Ctrl for the same shortcuts. Linux uses the standard WebKitGTK HTTP authentication and JavaScript dialogs.

## Assembly and architecture

Rhun builds native assembly and links system libraries. Oogabooga uses that approach. The Linux app is all handwritten assembly; the macOS UI still has an Objective-C bridge:

- `src/linux/browser.s`: handwritten x86-64 GTK UI, event loop, URL handling, navigation, popup lifecycle, keyboard shortcuts, persistent WebKit profile setup, and searchable history. Calls library C ABIs directly.
- `src/linux/core.s`: handwritten x86-64 SQLite operations, bound parameters, and error propagation. Both platform cores include `src/history.inc` for the shared schema and insert statement.
- `src/core.s`: handwritten ARM64 entry point, SQLite schema initialization, prepared inserts, parameter binding, and error propagation. Uses Darwin's calling convention and preserves callee-saved registers.
- `src/Browser.m`: ARC-managed Objective-C bridge for AppKit/WebKit, URL input, authentication, and history queries. Compiled to readable ARM64 assembly in `build/asm/Browser.s`, then assembled into an object.
- `build.sh`: dispatches by OS. Linux assembles `.s` files and links GTK/WebKitGTK/SQLite into a PIE executable with RELRO, immediate binding, and a non-executable stack. macOS compiles the bridge to assembly, assembles, links, packages, and ad-hoc signs the `.app`.
- `flatpak/dev.oogabooga.Browser.json`: builds the Linux assembly app inside the GNOME 50 SDK, reusing the runtime's maintained WebKitGTK engine.

The rendering engine is the OS WebKit installation, or the maintained GNOME runtime WebKitGTK in Flatpak. Assembly does not make HTML, JavaScript, TLS, or web compatibility inexpensive to reimplement; reusing the maintained system engine keeps the application small. WebKit helper processes still consume memory separately from the executable.

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
