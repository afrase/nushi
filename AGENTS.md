# AGENTS.md

How to work in Nushi's code, for every agent (Claude Code reads it through `CLAUDE.md`). Open work, decisions to revisit, security notes, dependencies and working notes live in [`NOTES.md`](NOTES.md).

## Architecture

Nushi is an agentic development environment for macOS: coding agents (Claude, Codex, Ante, PiG, oh-my-pi) run as chats.

- **The daemon**, `nushid` (Go, `cmd/nushid`), runs each agent as the user's own CLI over the Agent Client Protocol (`github.com/afrase/acp-go`), keeps chats, worktrees and terminals, and outlives the app.
- **The app** (Flutter, `app/`) is the window. It talks to the daemon over Connect RPC on a Unix socket with a client token; the API is `proto/nushi/v1/nushi.proto`.
- **The phone** is the same Flutter app built for the web (`app/lib/phone_main.dart`, `app/lib/phone/`). It reaches the daemon through **the relay** (`cmd/nushi-relay`, `relay/`), which pairs the two over a Noise channel (`noiseconn/`) and serves the web app; the daemon sends it Web Push.
- **Layering**: features (`internal/features/<name>`) declare the interfaces they need, in their own package; `cmd/nushid/main.go` builds the concrete packages and wires them in at startup. Packages are named for what they are (`store`, `git`, `githubapi`, `keychain`): no `adapters/`, `lib/`, `ports/` or `utils` folders. Generic code (the relay, Noise, the Dart packages) lives outside `internal/`.

## Repository map

- `cmd/nushid`: main and wiring; the subcommands `ante-acp`, `pig-acp` (Nushi's bridges), `tools-mcp` (a chat's tools), `-login`.
- `internal/features/`: `chats` (sessions, turns, queue, rewind, move, sleep, worktrees, side questions, subagents), `agents` (finding, setting up, removing), `trust` (the trust card), `mcp`, `skills`, `terminals`, `memory`, `remote` (pairing, devices, `push.go`), `jira`, `github`, `tools`, `updates`.
- `internal/api`: the Connect handlers (`api.Version`); generated code in `internal/gen` and `app/lib/gen`.
- Agents: `internal/claude`, `codex`, `omp` (what each adapter or CLI does; `adapter/` holds pinned lockfiles), `ante`, `pig` (the bridges), `*trust` (what a folder brings each agent), `*skills` (`skillfile` reads a skills folder), `claudemcp`, `antemcp`, `claudehistory`, `agentproc` (an agent's process and ACP connection), `toolcall`, `acptest` (the fake agent).
- Integrations: `jiracloud`, `adf` (Jira's documents to Markdown), `githubapi`, `mdwrite` (Markdown for anyone's text), `mcpserver`, `keychain`, `webpush`, `filewatch`.
- Plumbing: `model` (plain shared types), `store` (JSON state, `settings.json`), `transcripts`, `git`, `terminal`, `events`, `logs`, `npm`, `readonly` (`sandbox-exec`), `shellenv` (the login shell's environment), `procgroup`, `secrets` (secret shapes to mask), `jsonsettings`, `atomicfile`, `folderfiles`, `filelock`, `footprint`, `sysproxy`. `internal/e2e` runs the API against the fake agent.
- `app/lib/`: one file per view or part (`chat_view`, `transcript`, `composer`, `changes_view`, `jira_*`, `github_*`, `settings_*`, `history_*`…). `theme/tokens.dart` holds every color; `controls.dart` every button, menu field, link, icon button and grip (ADR 0049), `widgets.dart` `RunButton`, `errorText`, `revealRow`; `app_actions.dart` every action (the ⌘K palette, keys, menu bar); `chat_keys.dart` the chat keys; `motion.dart` motion and Reduce Motion; `settings.dart` the app's `app.json`.
- `packages/`: `markdown` (streaming Markdown), `uds_transport`, `noise`, `remote_transport`, `svg_path`. `diff_view` is a pub package of the owner's.
- `tools/`: `lint` (pinned lint tools), `webbuild`, `mermaid`, `icongen`, `adapters.sh`, `check-bundle.sh`, `release.sh`.
- `docs/`: `adr/` (every decision and why; `README.md` indexes them), `glossary.md`, `facts/` (what each vendor does, as seen), `user/`, `history/` (`steps.md`, `summaries.md`, `demos.md`).

## Build, run, check

- **Tools**: Go (the `go` line in `go.mod`) and Flutter on `PATH`; buf, golangci-lint, govulncheck and the Dart protoc plugins come pinned (`make gen-tools`). The daemon builds with cgo (Xcode's command-line tools).
- **`make check`** (lint, then test) before every push; `make lint` needs the network (govulncheck). CI runs the same parts as parallel jobs (`.github/workflows/ci.yml`).
- **A dev daemon beside the installed Nushi**: `NUSHI_DATA=/tmp/nd1 make run` builds `bin/nushid`, starts it on that folder unless one runs there, then `flutter run`s the app; `NUSHI_DATA=/tmp/nd1 make stop`. Keep the path short (the socket's path has a length limit). Without `NUSHI_DATA` both use the owner's real data. Driving its API without the app: NOTES.md's working notes.
- **`make gen`** after editing `proto/`; the generated code is committed and CI checks it is current.
- **Others**: `make lines` (hand-written line counts), `make relay`, `make web` (the phone's app), `make icons`, `make adapters` (an adapter's lockfile). `make install` and releases: NOTES.md.

## Common changes

- **An API call**: add the rpc and its messages to `proto/nushi/v1/nushi.proto` (additive only, ADR 0004: new fields and calls, never a changed meaning), `make gen`, write the handler in `internal/api/<area>.go` against an interface the feature satisfies, and call it from `app/lib/daemon.dart`. Bump `api.Version` in `internal/api/api.go` and `apiVersion` in `app/lib/daemon.dart` together (`remote_e2e_test` fails when they differ). A call only the Mac may make goes in `macOnly` in `api.go`. Teach `FakeDaemon` (`app/test/fake_daemon.dart`) its answer when tests need it.
- **A daemon setting**: a field in `Settings` in the proto (`optional`, so SetSettings leaves it when not given), its key in the `settings` struct of `internal/store/store.go` (`settings.json`), carried through `GetSettings`/`SetSettings`; its row in the matching `app/lib/settings_*.dart` page.
- **An app preference**: a `ValueNotifier` in `app/lib/settings.dart` read from `_saved`, listened to by `_save`, its key written in `_save`'s map, and a line in the file's opening comment.
- **An agent kind**: its package in `internal/<agent>` (CLI, page, `Start`, `Resume`, dialect hooks), a `chats.Kind` and an `agents.Agent` in `cmd/nushid/main.go`, its trust (`internal/<agent>trust`) and skills (`internal/<agent>skills`), a fake in `internal/acptest`, its mark in `app/lib/agent_mark.dart`, `readyAgents()` in `fake_daemon.dart`, and its behaviour in `docs/facts/<agent>.md`.
- **A view**: a widget file in `app/lib/`, built from `controls.dart` and the theme's tokens (no raw colors or ad hoc buttons); if it takes the chat's place, a flag on `Daemon` and a branch in `main.dart`'s main area, and an `Act` in `app_actions.dart` for its key and menu item. Widget tests, goldens in both themes, and renders at full size (below).

## Code conventions

- **Go**: plain functions and small interfaces declared by their user; errors wrapped with `%w` and context, returned as `connect.NewError` with a fitting code at the API; `log/slog` with key-value attributes (never a token, a prompt or a user's text); contexts passed down, processes started under one (`procgroup`); files written whole (`atomicfile`).
- **Dart**: `very_good_analysis`; state in `ValueNotifier`s and the `Daemon` `ChangeNotifier`; colors only from `theme/tokens.dart`, controls only from `controls.dart`; one file per view or part.
- **Comments** are plain sentences that say what a thing is and why, not what the next line does; they name the ADR, step or `docs/facts` page behind a choice. Types, functions and settings carry a doc comment saying so (lint requires them only in `noiseconn` and `relay`, which could be published).
- **Words**: [`docs/glossary.md`](docs/glossary.md) names Nushi's parts and ideas for the UI, the code and the docs (the details panel is made of widgets, a side question isn't a side chat). A new user-facing term goes there first, and everything uses its word; an old word goes under its Synonyms, and code that still says it under Renames to do.
- **Size tripwires**: about 500 changed lines a step (tests included, generated code not) and about 400 lines a source file. Crossing one is allowed: say what pushed it in the step table's list and the milestone's summary, and split a file along its seams when it grows past.
- **Lint exclusions** (ADR 0040): a report wrong for one line takes `//nolint:<linter> // <why>` on it (or on the function's line), a Dart one `// ignore: <rule>` under a comment saying why; a path exclusion in `.golangci.yml` or a rule off in `analysis_options.yaml` only with the reason beside it. The whole rule: NOTES.md's Lint exclusions.
- **Docs**: an ADR for a decision someone might undo (`docs/adr/`, a page at most, one line in its README), never restated elsewhere; a vendor's behaviour in `docs/facts/`; a security-sensitive change under NOTES.md's Security notes, a new dependency under its Dependencies.

## Testing

- **Fakes, never the real thing**: Go features are tested against fakes of their interfaces (`internal/features/chats/fake_test.go`), the API end to end against the fake agent (`internal/acptest`, `internal/e2e`), HTTP clients against recorded `testdata/`. The app's tests use `FakeDaemon` (`app/test/fake_daemon.dart`: chats, agents, recorded requests, `answer` for the rest); call `loadFonts` in `setUpAll` for goldens.
- **Temp data only**: Go tests use `t.TempDir()`; an app test process makes its own data folder (`nushi-test-…` in the temp folder, even with `NUSHI_DATA` set) and deletes it when its tests end.
- **`make test`**: Go with `-race` (CI adds `GOTESTFLAGS=-shuffle=on`; a failure's log has the seed for `-shuffle=<seed>`), each Dart package, the app (`make test-app SHARD=1/2` runs every second file; `FLUTTER_TEST_FLAGS=--concurrency 3`).
- **Goldens**: `app/test/goldens`, both themes, macOS only (on Linux about a third differ by 1–4%). `cd app && flutter test --update-goldens test/<file>` rewrites them; open every PNG that changed before committing.
- **UI is looked at, full size**: render every view you build or change at real sizes (Mac: ~1700 and ~720 wide; phone: 390×844, 430×932, landscape) and read the PNGs; assert key positions (a bar's trailing buttons at its edge, nothing clipped). In a `Row`, never a `Flexible` beside a `Spacer` (it takes half the free width): put the flexible part in an `Expanded` row of its own (`github_wide_test.dart`).
- **Live tests** run only with their variables set: `NUSHI_GITHUB_LIVE` (the throwaway repository `afrase/nushi-gh-test`), `NUSHI_JIRA_TEST_SITE`/`_EMAIL`/`_TOKEN`, `NUSHI_KEYCHAIN_TEST`.

## Rules

- **Steps**: work is numbered in steps, one commit each on `main` ("Step N: …"), numbered from the one after the last `Step` commit on `origin/main` at push time (`git log origin/main --grep '^Step' -1`): other agents push steps too. Each step adds its row to `docs/history/steps.md`, `make lines`' counts each in its own column; a milestone adds its summary to `summaries.md` and its demo to `demos.md`.
- **Pushing**: work in your own git worktree and commit by path; `make check`, rebase on `origin/main`, `git push origin HEAD:main`. Never force-push or rewrite pushed history.
- **Commit messages**: a `Co-Authored-By` line is fine; never a `Claude-Session:` trailer or a session URL, in commits, PR titles or PR bodies.
- **The owner's data and credentials**: never touch the real data folder (`~/Library/Application Support/Nushi`) from a test or a dev run; never use the owner's credentials in tests (fakes instead) unless a task's prompt allows it; never print, log or store a token; never erase or set the owner's fish variables (`env -u` keeps one out of a child).
- **No synthetic input**: never send clicks, keystrokes or mouse events to a running app, the installed Nushi or a dev build, idle or not. Test through the daemon's API, widget tests and goldens.
- **Security-sensitive changes** (what reads, writes, runs or sends on the user's behalf) get their entry under NOTES.md's Security notes in the same step.
- **Stop what you start** (dev daemons, apps, simulators, relays) before you report, and remove its temp folders.
