# Development

How to build, run and test Nushi from source. The rules for working in this repository (commits, size limits, words, docs) are in [AGENTS.md](../AGENTS.md); the decisions are in [`docs/adr/`](adr/README.md), the security notes in [`security.md`](security.md), the plans in [`roadmap.md`](roadmap.md).

## What you need

- Go (current stable) and Flutter on `PATH`.
- For `make gen`, nothing more: it activates the Dart protoc plugins at the versions it pins, and buf runs through `go run`.

## Make targets

```sh
make run         # starts nushid in the background (if it isn't running), then the app
make stop        # stops nushid
make test        # all tests (test-go, test-packages, test-app, test-web)
make lint        # the linters and format checks, below (lint-go, lint-dart)
make check       # lint, then test
make gen         # regenerate the API code after editing proto/
make lines       # hand-written line counts
make package     # a release "Nushi.app" with nushid inside (signed: Install, below, says with what)
make install     # package, then copy it to ~/Applications
make icons       # redraw the app icon and the mark (tools/icongen)
make adapters    # an adapter's lockfile again after its version changed
make relay       # the relay, bin/nushi-relay
make web         # the phone's web app, into app/build/web
make screenshots # the README's screenshots, into docs/images
tools/release.sh 1.2.0   # a release's files into dist/, as the release workflow builds them
                         # (or one part: app, relay, web)
```

- With `make run`, start and stop the daemon yourself.
- `make package` checks the bundle's layout and signatures (`tools/check-bundle.sh`).
- To try a build beside a Nushi that's in use, give both another data folder: `NUSHI_DATA=~/Library/Application\ Support/Nushi\ Dev make run` (and the same for `make stop`).

## Lint

`make lint` runs:

- golangci-lint (with gofmt and goimports) and govulncheck;
- `buf lint` and `buf format`;
- `flutter analyze` and `dart format`, for the app and each package.

`make check` runs it and then the tests.

**Go.** golangci-lint and govulncheck are pinned in their own module, `tools/lint/go.mod`. `make lint` builds them into `bin/` and runs them: nothing to install, and the daemon's `go.mod` doesn't take their dependencies.

- `.golangci.yml` turns every linter on, and lists each one that's off with the reason.
- govulncheck checks the daemon, the relay and the tools against vuln.go.dev (so `make lint` needs the network), and fails on a vulnerability the code calls.
- The Go version is the `go` line in `go.mod`, which the go command fetches if yours is older.
- To format: `bin/golangci-lint fmt ./...`.

**Dart.** Every package and the app include [very_good_analysis](https://pub.dev/packages/very_good_analysis) (strict casts, inference and raw types, and nearly every lint rule), then `analysis_options.yaml` at the root, which adds a few rules and turns off the ones that don't fit, each with why. The app also turns off `public_member_api_docs`, since it isn't a library. `dart fix --apply` in a package fixes much of what it reports.

### Lint exclusions

The whole rule (ADR 0040; AGENTS.md has it in brief). A report wrong for one line: `//nolint:<linter> // <why>` on it, or on the function's line when it covers the function (contextcheck's mark on a function that rightly starts its own context stops the report spreading to callers); nolintlint refuses one without both, or one that silences nothing. Exclude by path in `.golangci.yml`'s `exclusions.rules` only where a whole package or kind of file is what the linter reports on (tests' temp files for gosec, the proto int32s), with a comment why; `disable` a linter only when it doesn't fit the code at all, the reason on its line. No comment needed for `_ = json.Unmarshal(…)` on an agent's payload (best effort; what's missing stays zero) or `defer f.Close() //nolint:errcheck // read-only`. Dart: `// ignore: <rule>` below a comment saying why, `// ignore_for_file:` when the whole file is about it; a rule that doesn't fit goes `false` in `analysis_options.yaml` with the reason. govulncheck: a standard-library finding is fixed by the `go` line's patch version (`go.mod` and `tools/lint/go.mod`), a module's by `go get` of the fix; one with no fix goes under [Security notes](security.md) with its id.

## ACP

Agents are spoken to through the library [`github.com/afrase/acp-go`](https://github.com/afrase/acp-go) (its `unstable` package), at the version in `go.mod` ([ADR 0041](adr/0041-acp-through-acp-go.md)).

To change it and Nushi at once:

1. Clone it beside Nushi and run `go work init . ../acp-go` here. The `go.work` (ignored by git) makes Nushi build with your checkout.
2. Remove it to build with the tagged version again.
3. Run `go get github.com/afrase/acp-go@vX.Y.Z` once the library has the release you need.

With a `go.work`, `make lint` builds golangci-lint into `bin/` because `go tool -modfile` refuses a workspace; before committing a version change, `GOWORK=off make check` against the tag in `go.mod`. A library fix is its own release there, then `go get` here.

## CI

CI (`.github/workflows/ci.yml`) runs the same parts as `make check`, as parallel jobs, in under 3 minutes:

- on macOS: Go's lint and tests, the web app's end-to-end test, and the app's tests in two shards (`make test-app SHARD=1/2`: every second test file);
- on Linux: the protos' and Dart's lint, the Dart packages' tests, and the relay's and the Noise channel's Go tests.

## Install, releases, logs

- **Install**: `make install` packages a release app (`make package`: the app, the daemon in `Contents/Helpers/Nushi Daemon.app`, signed with the first "Apple Development" identity in the keychain (or `NUSHI_SIGN`; ad hoc when there is none, and then the keychain asks again after every install), checked by `tools/check-bundle.sh`), puts it in `~/Applications`, and copies it to `COPY_TO` from `local.mk` (not committed): the owner's iCloud Downloads, so the work Mac gets it. The running installed daemon keeps the old build until it restarts: restart it only when no chat's agent runs (stop it by its PID, then `open -n -g "$HOME/Applications/Nushi.app/Contents/Helpers/Nushi Daemon.app" --args -login` as the app does, and check `nushid started … api=<n>` in `nushid.log`); otherwise say so: an app of API 77 on asks it to restart itself once nothing runs (ADR 0056).
- **Releases** (ADR 0055): publishing a GitHub release (tag `vX.Y.Z` on `main`) runs `.github/workflows/release.yml` (about 5 minutes): the app (macOS), the relays and the web app (Linux) in parallel jobs, each `tools/release.sh X.Y.Z <part>` (try it here: with no part it writes all three into `dist/`), and the commit checked (a passing CI run on it, else CI's own workflow, called); then the files attached to the release, and the cask (`packaging/homebrew/nushi.rb`) pushed to `afrase/homebrew-tap` with the `HOMEBREW_TAP_TOKEN` secret, for the latest release only. `make package` stamps `NUSHI_VERSION` (else the newest tag's) and the commit count into the app, the helper and the daemon (`api.Release`, Ping's `version`), and builds for macOS 13 (`MACOS_MIN`). Never tag, publish or push to the tap unless the owner asks.
- **Debugging from the logs**: `nushid.log` in the data folder (Settings › Logs; `.1` and `.2` are older, 10 MB each), `app.log` beside it for what the app wrote while the daemon didn't answer; `NUSHI_LOG=debug` or the Settings switch for debug lines. One chat: `grep 'chat=<id>' nushid.log` (side chats name theirs); an agent's processes: `grep 'pid=<pid>'`; a recovered panic's stack: `printf '%b\n' "$(grep panicked nushid.log)"`. What each failure looks like: `docs/history/debugging-from-the-logs.md`.

## Screenshots

`make screenshots` draws the README's images (`docs/images/`) from the real app: `app/test/screenshots/readme_shots.dart` renders it on a fake daemon with made-up data (`demo.dart`), with the bundled fonts, at real window sizes. It isn't part of `make test`. Change the demo data there, never use real chats.

## Dependencies

Added on purpose, each for real work (`.golangci.yml` leaves depguard off for this list).

- **Go**: `github.com/andybalholm/brotli` (`tools/webbuild` only: the web build's Brotli copies; MIT, no dependencies), `github.com/afrase/acp-go` (ACP, ADR 0041; the owner's, MIT), `connectrpc.com/connect`, `google.golang.org/protobuf`, `github.com/creack/pty`, `golang.org/x/sys/unix`, `github.com/flynn/noise`, `github.com/gorilla/websocket`, `golang.org/x/crypto` (autocert), `gopkg.in/yaml.v3` (skills' front matter), `github.com/BurntSushi/toml` (Codex's config), `github.com/yuin/goldmark` (Markdown to ADF and GitHub's rendering; MIT, no dependencies), `github.com/cli/go-gh/v2` v2.17.0 (only `pkg/auth` and `pkg/config`'s Reload, bringing `cli/safeexec`; MIT), `golang.org/x/net` (`html`). cgo for `internal/keychain` (Security, CoreFoundation).
- **Dev tools**, none on `PATH`: golangci-lint 2.15.0 and govulncheck 1.9.0 through `tools/lint/go.mod` (built into `bin/`), buf 1.75.0 through `go run`, `very_good_analysis` 11.0.0 for the app and every package; HarfBuzz's `hb-subset` (Homebrew) only for `make web-plex`. CI's actions are pinned by commit.
- **Agents**: Node and npm (yours) for Claude's and Codex's adapters, pinned by `internal/{claude,codex}/adapter/package-lock.json`, installed only on Set up; Claude needs neither with the Go agent on (ADR 0066).
- **Claude's Go agent** (`claudeagent`, `claudeacp`, ADR 0066): no new modules. `claudeagent` and its `sessions` and `claudetest` use the standard library only, `claudeacp` adds acp-go; neither imports `internal/`, so they can move to repositories of their own. The recording tools (`claudetest/fakeapi`, `claudetest/cmd/claude-tee`, `claudetest/cmd/fakeapi`, `claudetest/cmd/mcp-echo`) are standard library too; `tools/claude-record` uses acp-go's types and Nushi's `internal/claude`, `internal/npm` and `internal/proctree`.
- **Dart**: `diff_view`, `connectrpc` (with `http2` 2.x: 2.0.1 doesn't resolve with 3.x), `protobuf`, `fixnum` (the API's int64s), `cryptography`, `qr`, `flutter_markdown_plus`, `markdown`, `re_highlight`, `url_launcher`, `web` (the browser's APIs, for the phone's web app and the relay socket on the web), `flutter_web_plugins` (Flutter's own: no URL routing in the phone's app), `crypto` (the key fingerprint's SHA-256; tests: `async`, `stream_channel`), `file_selector`, `pasteboard`, `desktop_drop`, `webview_flutter_wkwebview` and `webview_flutter_platform_interface` (BSD-3, the Flutter team's; the Mac's web view for previews, without the umbrella package's Android part), `xterm2` (MIT; brings `xterm2_core`, `zmodem`, `quiver`, `equatable`, `convert`). Fonts bundled: IBM Plex Sans and JetBrains Mono (OFL), Symbols Nerd Font Mono 3.5.1 (MIT; its icons under their projects' licenses). Vendored: jsQR 1.4.0 (Apache-2.0) in `app/web/qr_worker.js`, for Scan. Fetched at build time, pinned: mermaid.js 12.2.0 (MIT; `dist/mermaid.min.js`, 5.4 MB, `tools/mermaid/mermaid.lock`; its licence beside it in `app/assets/mermaid/`), for diagrams (ADR 0057).

## Working notes

- **Claude through the Go agent**: Settings › Agents' "Use Nushi's Go agent" (no restart: the next start of a Claude chat's agent uses it). `NUSHI_CLAUDE_ADAPTER=go NUSHI_DATA=/tmp/nd1 make run` forces it for a dev daemon whatever the setting says (the variable reaches the dev daemon; the installed one never has it); Settings › Agents then shows Claude with no Set up. Its parity tests replay scenarios in `internal/features/chats/testdata/claude-parity` (`go test ./internal/features/chats -run ClaudeParity`).
- **Recording ACP by hand**: a `node` first on `PATH` that, for a command line naming `claude-agent-acp`, runs `tee -a in.jsonl | node "$@" | tee -a out.jsonl` (and execs the real node otherwise), and a dev daemon with `NUSHI_SHELL_ENV=off` so the agent gets that `PATH`; `testdata/subagents` in `internal/features/chats` were made so.
- **The fake agent in the app**: build `internal/acptest/fakeagent`, put a `node` that execs it and a `claude` (any script) first on `PATH`, fake Claude's setup (`<data>/agents/claude/node_modules/@agentclientprotocol/claude-agent-acp/package.json` = `{"version": "0.94.0", "bin": {"claude-agent-acp": "dist/index.js"}}`, as `app/test/remote_e2e_test.dart` does), and start a daemon with that `PATH` and a short `NUSHI_DATA`. Prompt words: `permission`, `question`, `think`, `pwd`, `many`, `plan`, `tool`, `run`, `stderr`, `garbage`, `safeguards` (a response stopped by Claude's safeguards), `wait` (until stopped); `FAKEAGENT_LOAD_DELAY` slows `session/load`.
- **Codex, Ante and omp by hand**: a dev daemon with `CODEX_HOME` (holding `docs/user/codex-config.md`'s config) or `ANTE_HOME` at a temp folder, `HOME` at one for omp (`~/.omp`), and `FIREWORKS_API_KEY` read from `fish -l -c` (real `HOME`) inside the launching script, never on a command line or in a file. Quit the dev app before stopping the dev daemon (an app that finds none starts its bundled one with the real `HOME`).
- **TUIs by hand**: a pty driver (Python's `pty`) answering the terminal's queries (cursor, device attributes, colours) and typing what's written to a FIFO runs Codex's and Ante's (`codex resume` too); a FIFO write blocks once the driver is gone. Set Codex's `check_for_update_on_startup = false` first (its prompt takes Enter and updates the global Codex). Claude's TUI stops at its trust prompt, and answering writes `~/.claude.json`: use `claude -p` (`--resume`). Headless: `codex exec`, `ante -p --permission-mode strict --session-save`, `omp -p`.
- **Terminals**: the shell is the login shell from `id -P`, never the daemon's `$SHELL`. fish 4 asks Primary Device Attributes at start and waits 10 s; the app answers queries in a replay only for a terminal it opened.
- **The window**: no agent clicks or types into it (AGENTS.md: no synthetic input). Screenshots are 2× points, current only while the window is in front. A phone by hand: decode the QR code from a screenshot (Vision's `VNDetectBarcodesRequest`) and pair from a Dart script on `packages/remote_transport`; a raw Connect call is a POST of `{}` (`content-type: application/json`) on its `makeRequest`.
- **The Dock and launchd**: `osascript -e 'tell application "System Events" to get name of every UI element of list 1 of application process "Dock"'` lists Dock items; `lsappinfo list` says why a quit app keeps one; `launchctl print gui/$(id -u)/com.nushihq.Nushi.daemon` shows the login item; `/usr/bin/log` (not fish's `log`) shows launchd's reasons.
- **The icon** ("the still lake"): `make icons` writes `app/macos/Runner/AppIcon.icon` (Icon Composer, Liquid Glass on macOS 26+), PNGs for older macOS and `docs/brand/`; `app/lib/logo.dart` draws the mark. `NSWorkspace.shared.icon(forFile:)` shows what macOS made of it; a deleted working folder fails actool until `pkill ibtoold`.
- **Slow diffs**: git runs with `GIT_OPTIONAL_LOCKS=0`, so a stale index stays stale (`git diff` ~0.16 s instead of ~0.02 s until a `git status`).
- **The phone in the iOS Simulator**: a simulator of your own (`xcrun simctl create`, deleted after), the relay and a dev daemon on localhost. Real touches and typing come from an XCUITest bundle whose test loops over commands in a file (`XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")`, coordinates from SpringBoard; a hand-written `project.pbxproj` with one UI-testing target, `xcodebuild test-without-building`). The software keyboard needs the simulated hardware keyboard off (CoreSimulator's `-[SimDevice setHardwareKeyboardEnabled:keyboardType:error:]`; a safaridriver session turns it back on, and its synthetic taps don't count as a user's, so no keyboard). JavaScript in the page through the Web Inspector protocol on the `webinspectord_sim.socket` launchd_sim holds (binary plists: `_rpc_reportIdentifier:`, `_rpc_forwardGetListing:`, `_rpc_forwardSocketSetup:`, then `Target.sendMessageToTarget`; `launchctl kickstart user/foreground/com.apple.webinspectord` in the simulator after a boot): pair from a Dart script on `remote_transport` and put the record in IndexedDB. The 18.3 simulator opens Home Screen web apps in Safari ("In your region…"), so only a Safari tab is testable there. Another agent may have a simulator booted too: take the inspector socket your own `launchd_sim` holds (`lsof -U -a -p <its pid>`; its command line names the device's UDID), give the driver a command file of its own, and after a new build activate the waiting service worker (`postMessage('skipWaiting')`) before reloading, or the page stays on the old build. iOS 26.5's runtime (installed with `xcodebuild -downloadPlatform iOS -buildVersion 26.5`) runs Home Screen web apps as apps (Safari's ⋯ › Share › View More › Add to Home Screen; its own storage, so put the record in again); there XCUITest's drags never start Safari's edge swipe, but a path of XCTest's own does (`XCPointerEventPath` `initForTouchAtPoint:offset:`, `moveToPoint:atOffset:`, `liftUpAtOffset:` in an `XCSynthesizedEventRecord`, `synthesizeWithError:`; 0.4 s from x = 1). On a Flutter page a slower one (0.5 s to 330 points) is taken back by iOS about three times in eight, the same at 56c9bb4's build, and never on a plain page. A new tab per run: `simctl openurl` with a query of its own.
