# 0097. Native code behind interfaces

Status: accepted, 2026-11-07.

## Context
The owner: "Any swift code should be hidden behind interfaces. We should not be writing concrete code coupled to swift. Fundamentally this is wrong for a cross platform app." Views called the Mac's Swift side over platform channels inline (the fonts in Settings › Terminal, the clipboard in the composer, notifications, the window's drag), the preview's host interfaces shared files with their WKWebViews, and the daemon's macOS-only code (cgo, darwin's sysctl, sandbox-exec, scutil) sat in files every OS compiles, so a Linux build failed. Nushi may later get a Linux daemon and a Windows (WSL) app; this builds no new platform, only the seams and the checks.

## Decision
- **The app's native edge**: each native capability is a Dart interface declared beside what uses it, in a file named for the capability (`speller.dart`'s `Speller`, `alerts.dart`'s `AlertCenter`, `login_item.dart`, `window_drag.dart`, `back_swipe.dart`, `fonts.dart`, `clipboard_files.dart`, `mermaid.dart`'s `Diagrams`, `desktop.dart`, `web_views.dart`'s `WebViews`, which makes the preview's and the browser's hosts). The Mac's implementation is `<capability>_macos.dart` beside it; only such a file holds a platform channel, `dart:ffi` or `webview_flutter_wkwebview`. A conditional-import pair stays one (`file_mode.dart`: `file_mode_macos.dart`, chmod through FFI, and the web's stub).
- **One holder, set at startup**: `native.dart`'s `Native` holds one implementation of each capability, and its top-level `native` is set once, in `main.dart`, to `macosNative()` (`native_macos.dart`). It is how the app already reaches what's shared and swapped in tests (`clock`, the prefs): a top-level a test replaces, not a widget tree's injection, since the capabilities are used deep in views the `Daemon` isn't passed to. Its constructor requires every capability but the speller (optional by design), so a new platform's set can't leave one out. No service locator: one class, its fields. The phone's web app reaches none of it (`kIsWeb`, the speller's `null`).
- **Tests** start each from the Mac's set (`flutter_test_config.dart`, no speller) and put a fake in a capability's place (`native.speller = …`, `fakeWebViews()`, `fakeDesktop()`); tests of the Mac's implementation answer its channels as before.
- **The daemon's OS edge**: macOS-specific code is in `foo_darwin.go` files behind the package's API, with `foo_other.go` (`//go:build !darwin`, `|| !cgo` for cgo) that compiles and answers as its callers already handle: `errors.ErrUnsupported` wrapped with the OS (`listeners.List`, `proctree`, `footprint.Snapshot`, `readonly.Output`, npm's install, a keychain store), or a safe empty result (no keychain item, a footprint of 0, no command line, a direct connection, nothing keeping the machine awake, no default data folder: `NUSHI_DATA` must name one). A darwin-only test is `foo_darwin_test.go`.
- **The checks**, both in `make check` and CI: `tools/native-edge` (first in `make lint-dart`, CI's Linux lint job) fails on native code in `app/lib` outside a `*_macos.dart` file; `make lint-linux` (in `make lint`, CI's Linux Go job) builds and vets every Go package with `GOOS=linux CGO_ENABLED=0`.

## Consequences
- Another platform is a `native_<os>.dart` with its own implementations, chosen in its `main`, and `_<os>.go` files where `_other.go` stands in now; nothing works on Linux yet beyond compiling.
- A new native call means an interface method and its Mac implementation, not a channel in a view.
- Left as they are: the app's data folder under `~/Library/Application Support` (`daemon.dart`) and its bundled daemon, a helper app inside the `.app` started through Launch Services, its socket's holder found with lsof (`bundled_daemon.dart`): the Mac's packaging, which another platform replaces rather than implements. In the daemon, commands that compile everywhere and fail plainly elsewhere: lsof at `/usr/sbin` (Ante's open sessions), `/usr/bin/trash` (a skill to the Trash), BSD `script` (an MCP server's sign-in).

## Alternatives considered
- Constructor injection through the widget tree: each capability is used in a few deep views; threading it through every widget between was a larger change for nothing a top-level doesn't give.
- A service locator package: more than a class with fields, and a new dependency.
- One top-level per capability (as the old function seams were): no one place says what a platform must provide.
- `_ffi` and `_web` suffixes for every implementation: the suffix names the platform, which is what the check needs to know.
