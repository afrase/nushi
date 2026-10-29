# Development

How to build, run and test Nushi from source. The rules for working in this repository (commits, size limits, words, docs) are in [AGENTS.md](../AGENTS.md); the decisions are in [`docs/adr/`](adr/README.md).

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
make package     # a release "Nushi.app" with nushid inside (signed: NOTES.md says with what)
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

**One wrong report.** A report that's wrong for one line takes `//nolint:<linter> // <why>` in Go (nolintlint refuses one without both), or `// ignore: <rule>` under a comment saying why in Dart (`// ignore_for_file:` when a whole file is about it). NOTES.md says when to exclude by path instead.

## ACP

Agents are spoken to through the library [`github.com/afrase/acp-go`](https://github.com/afrase/acp-go) (its `unstable` package), at the version in `go.mod` ([ADR 0041](adr/0041-acp-through-acp-go.md)).

To change it and Nushi at once:

1. Clone it beside Nushi and run `go work init . ../acp-go` here. The `go.work` (ignored by git) makes Nushi build with your checkout.
2. Remove it to build with the tagged version again.
3. Run `go get github.com/afrase/acp-go@vX.Y.Z` once the library has the release you need.

## CI

CI (`.github/workflows/ci.yml`) runs the same parts as `make check`, as parallel jobs, in under 3 minutes:

- on macOS: Go's lint and tests, the web app's end-to-end test, and the app's tests in two shards (`make test-app SHARD=1/2`: every second test file);
- on Linux: the protos' and Dart's lint, the Dart packages' tests, and the relay's and the Noise channel's Go tests.

## Screenshots

`make screenshots` draws the README's images (`docs/images/`) from the real app: `app/test/screenshots/readme_shots.dart` renders it on a fake daemon with made-up data (`demo.dart`), with the bundled fonts, at real window sizes. It isn't part of `make test`. Change the demo data there, never use real chats.
