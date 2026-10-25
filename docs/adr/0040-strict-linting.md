# 0040. Strict linting: every golangci-lint linter on unless listed off with why, pinned in its own module; strict Dart analysis; CI runs both

## Context
Nushi had no Go linter: `go test`'s few `go vet` checks were all, and the Dart side had only `flutter_lints`, with `flutter analyze` run nowhere. A broad golangci-lint run found about 800 reports (errcheck 405, gosec 102, revive 65, contextcheck 37…). The owner runs Go strictly: many linters on, each exclusion there for a stated reason.

## Decision
- **golangci-lint 2.15.0, pinned in `tools/lint/go.mod`** with a `tool` directive, run as `go tool -modfile=tools/lint/go.mod golangci-lint` (since [0041](0041-acp-through-acp-go.md) built from it into `bin/`, as `-modfile` can't run beside a `go.work`): nothing on PATH or installed globally, and the daemon's `go.mod` doesn't take its dependencies (about 200 modules). In `tools/lint`, not `tools/`: a `go.mod` in `tools/` would cut `tools/icongen` out of the main module.
- **`.golangci.yml`: `default: all`**, and every linter off is listed with its reason (style that fights the code, rules that don't fit it, linters that need configuration this repository has no use for). gofmt and goimports format; gofumpt doesn't (it rewrites the compact composite literals in 60 files and checks nothing that matters).
- **A wrong report is marked where it is**: `//nolint:<linter> // why`, which nolintlint enforces. A path exclusion only where a whole package is about what the linter reports (tests' temp files for gosec, the API's proto conversions, internal/git running git), each with its reason in the config.
- **gosec's G204 and G304 aren't excluded wholesale**: starting processes and reading files at paths is what the daemon does, so each is checked and marked.
- **Dart: `analysis_options.yaml` at the root** (strict casts, inference and raw types, and 54 lint rules), included by the app and every package.
- **`make lint`** runs golangci-lint, `buf lint` and `buf format`, `flutter analyze` (infos fatal) and `dart format`; `make test` stays tests only; `make check` runs both. CI (`.github/workflows/ci.yml`, actions pinned by commit) runs `make lint` and `make test` on macOS, and the portable packages' tests on Linux.

## Consequences
- A new linter report fails `make lint` and CI: fix it, or mark it with the reason.
- About 125 `//nolint` directives, most of them gosec's on process starts and file reads (each says why that one is fine), errcheck's on read-only closes, and contextcheck's on functions that rightly start their own context.
- Upgrading golangci-lint is a change of `tools/lint/go.mod` (`go get -tool …@vX` there); new linters arrive on with `default: all`, so an upgrade may need fixes or new reasons.
- Rejected: a global or Homebrew golangci-lint (not pinned, and on PATH); its dependencies in the main `go.mod`; excluding tests wholesale from errcheck.
