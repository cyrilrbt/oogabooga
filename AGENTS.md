# Repository Guidelines

## Project Structure & Architecture

- `src/core.s` implements the macOS ARM64 entry point and SQLite storage; `src/Browser.m` bridges AppKit and WebKit.
- `src/linux/` contains the Linux x86-64 application, written in assembly and linked directly to GTK 3, WebKitGTK 4.1, and SQLite.
- `src/history.inc` defines shared SQLite schema and insert SQL. Keep platform storage behavior consistent.
- `tests/` contains C assertion-based harnesses and a Python HTTP fixture. C harnesses are not shipped with the Linux app.
- `assets/` holds metadata templates, desktop integration, and icons; `tools/` holds build, packaging, and metadata scripts.
- `flatpak/` defines the Linux bundle; `.github/workflows/` builds and publishes downloads. Generated outputs belong in ignored `build/`.

## Build, Test, and Development Commands

Run commands from the repository root:

- `./build.sh`: build the native debug application.
- `./build.sh release`: build the optimized release; supports Apple silicon macOS 12+ and x86-64 Linux.
- `./build.sh test`: build and run SQLite storage tests.
- `./tools/test-linux.sh`: run Linux browser integration checks after a test build; requires Xvfb, Xauth, D-Bus, and Python 3.
- `open build/Oogabooga.app` or `./build/linux/oogabooga https://github.com`: launch locally.
- `python3 tests/server.py`: serve manual cookie, authentication, navigation, and popup checks at `http://localhost:8765`.
- `./tools/package-mac.sh` or `./tools/package-linux.sh`: package an existing release build.

Install Xcode tools on macOS; Linux requires GTK/WebKitGTK/SQLite development packages and `pkg-config`.

## Coding Style & Naming

Use four-space indentation in assembly and Objective-C. Linux assembly uses Intel syntax and the System V ABI; macOS uses Darwin ARM64 conventions. Preserve callee-saved registers and stack alignment. Comment ABI assumptions and callback signatures. Keep Linux application logic in assembly. Shell scripts use POSIX `sh` and `set -eu`. No formatter is configured; preserve surrounding style and run `git diff --check`.

## Testing Guidelines

No numerical coverage target is configured. Cover changed behavior with relevant storage or browser checks. Follow existing descriptive names such as `tests/history.c` and `tests/linux-browser.c`. Verify persistence, Unicode, bound SQL, navigation errors, and session behavior where affected. Keep WebKit sandboxing and TLS validation enabled.

## Commits & Pull Requests

Existing commits repeat `ooga booga browser`; no formal convention is established. Prefer concise, imperative subjects describing the change. PRs should explain behavior, affected platforms, validation performed, and limitations. Link relevant issues; include screenshots for UI changes.

## Versioning & Metadata

Change stable SemVer only in `VERSION`. Build scripts generate package metadata from templates; do not edit generated versions. Keep cookies and credentials out of commits and test with isolated profiles.
