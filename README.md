<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/brand/mark-dark.svg"><img src="docs/brand/mark.svg" width="88" alt=""></picture></p>

# Nushi

A macOS app for running coding agents as chats over the [Agent Client Protocol](https://agentclientprotocol.com), plus a diff viewer. A Go daemon (`nushid`) runs the agents; a Flutter app is the window.

## Requirements

- Go (current stable) and Flutter on `PATH`
- For `make gen`: `dart pub global activate protoc_plugin` and `dart pub global activate connectrpc` (buf runs through `go run`)

## Run

```sh
make run     # starts nushid in the background (if it isn't running), then the app
make stop    # stops nushid
make test    # all tests
make lint    # the linters and format checks (below)
make check   # lint, then test
make gen     # regenerate the API code after editing proto/
make lines   # hand-written line counts
make package # a release "Nushi.app" with nushid inside (ad-hoc signed)
make install # package, then copy it to ~/Applications
make icons   # redraw the app icon and the mark (tools/icongen)
```

The packaged app starts its bundled `nushid` (in `Contents/Helpers/Nushi Daemon.app`, a background-only app) when no daemon is running, and leaves it running when it quits; Settings › Start at login also starts it at login ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md), [ADR 0036](docs/adr/0036-the-daemon-is-a-background-helper-app.md)). `make package` checks the bundle's layout and signatures (`tools/check-bundle.sh`). With `make run`, start and stop the daemon yourself.

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi/`: `nushid.log` (rotated at 10 MB, two older copies), and `app.log` for what the app logged while the daemon didn't answer. Settings › Logs reveals them and turns on debug lines (or `NUSHI_LOG=debug`); one chat's lines are `grep 'chat=<id>' nushid.log` ([ADR 0038](docs/adr/0038-logs-you-can-debug-from.md) says what is logged and what never is). To try a build beside a Nushi that's in use, give both another folder: `NUSHI_DATA=~/Library/Application\ Support/Nushi\ Dev make run` (and the same for `make stop`). Everything Nushi writes outside its data folder, and why, is in [docs/user/outside-the-data-folder.md](docs/user/outside-the-data-folder.md).

## Development

`make lint` runs golangci-lint (with gofmt and goimports), govulncheck, `buf lint` and `buf format`, and `flutter analyze` and `dart format` for the app and each package; `make check` runs it and then the tests, as CI does (`.github/workflows/ci.yml`: macOS for everything, Linux for `relay` and `noiseconn`).

- **Go:** golangci-lint and govulncheck are pinned in their own module, `tools/lint/go.mod`; `make lint` builds them into `bin/` and runs them: nothing to install, and the daemon's `go.mod` doesn't take their dependencies. `.golangci.yml` turns every linter on and lists each one off with the reason. govulncheck checks the daemon, the relay and the tools against vuln.go.dev (so `make lint` needs the network) and fails on a vulnerability the code calls; the Go version is the `go` line in `go.mod`, which the go command fetches if yours is older. To format: `bin/golangci-lint fmt ./...`.
- **ACP:** agents are spoken to through the library `github.com/afrase/acp-go` (its `unstable` package), at the version in `go.mod` ([ADR 0041](docs/adr/0041-acp-through-acp-go.md)). To change it and Nushi at once, clone it beside Nushi and run `go work init . ../acp-go` here: the `go.work` (ignored by git) makes Nushi build with your checkout. Remove it to build with the tagged version again; then `go get github.com/afrase/acp-go@vX.Y.Z` once the library has the release you need.
- **Dart:** every package and the app include [very_good_analysis](https://pub.dev/packages/very_good_analysis) (strict casts, inference and raw types, and nearly every lint rule), then `analysis_options.yaml` at the root, which adds a few rules and turns off the ones that don't fit, each with why; the app also turns off `public_member_api_docs` (it isn't a library). `dart fix --apply` in a package fixes much of what it reports.
- A report that's wrong for one line takes `//nolint:<linter> // <why>` (nolintlint refuses one without both), or `// ignore: <rule>` under a comment saying why in Dart (`// ignore_for_file:` when a whole file is about it). NOTES.md says when to exclude by path instead.

## Agents

"New chat" (⌘N, or a folder's +) asks which agent to run, with the one used last picked: Enter starts it. A chat keeps its agent, and shows its mark in the sidebar ([where the marks come from](docs/user/agent-marks.md)).

The same dialog opens a session started elsewhere, such as `claude` or `codex` in a terminal: → (or "Open a … session") lists the agent's sessions in the folder (from No folder, every folder's), and Enter opens one as a chat. The agent replays it; nothing is copied, and it goes on in the same history the terminal resumes ([ADR 0035](docs/adr/0035-open-sessions-started-elsewhere.md)). A session still open elsewhere is marked: Claude and Ante let both write (Nushi asks first), Codex and oh-my-pi only one; PiG leaves no mark, and both write.

Settings › Agents shows each agent as Nushi finds it on your login shell's `PATH`: its version and path, or "Not installed" with where to get it. Finding them changes nothing: each CLI is only asked its version, with writes and the network denied. Nushi runs your own CLIs, never a copy it brings ([ADR 0037](docs/adr/0037-agents-you-set-up.md)).

- **Claude** runs your `claude` through Claude Code's ACP adapter, `@agentclientprotocol/claude-agent-acp` 0.94.0, which **Set up** installs into `~/Library/Application Support/Nushi/agents/claude` (about 9 MB from npm, from the lockfile in `internal/claude/adapter`). It uses Claude Code's own login and settings. Its `/code-review` reports its findings as a card in the transcript (Nushi sets `CLAUDE_CODE_REPORT_FINDINGS` for Claude Code); a review that writes them as JSON gets the same card, with Show JSON. A row opens to how the finding fails; its `file:line` opens the chat's Changes at that line, or the file as it is when it isn't changed.
- **Codex** runs your `codex` through `@agentclientprotocol/codex-acp` 2.2.2, set up the same way (about 2 MB). It uses Codex's own login or config (`$CODEX_HOME`, else `~/.codex`): sign in with `codex login`, or name a provider in `config.toml` ([docs/user/codex-config.md](docs/user/codex-config.md) has one for Fireworks). A provider's key comes from the environment, which agents get from your login shell when the app starts the daemon ([ADR 0028](docs/adr/0028-agents-get-the-login-shells-environment.md)). A Codex chat resumes in a terminal with `codex resume <session id>`.
- **Ante**, through Nushi's own bridge (`nushid ante-acp`, [ADR 0030](docs/adr/0030-our-own-bridge-for-ante.md)), which runs an `ante serve --stdio` per session: nothing to set up. It needs Ante 0.2.14 or newer (`ante` on `PATH`, or in `~/.ante/bin`) and uses Ante's own settings, providers and sign-in (`~/.ante`, or `$ANTE_HOME`). An Ante chat resumes in a terminal with `ante --resume <session id>`.
- **oh-my-pi** runs your `omp --mode acp` under your Bun: nothing to set up, once you've installed both. It uses omp's own config and keys (`~/.omp`, the environment: `FIREWORKS_API_KEY` for Fireworks). [docs/user/ante-omp-pig.md](docs/user/ante-omp-pig.md) has how to install it, and settings for Ante, omp and PiG. An omp chat resumes in a terminal with `omp --resume <session id>`; Nushi can't delete an omp session's history.
- **PiG** (pi-in-go.dev), through Nushi's own bridge (`nushid pig-acp`, [ADR 0039](docs/adr/0039-our-own-bridge-for-pig.md)), which runs your `pig --mode rpc` per session: nothing to set up once `pig` is on `PATH`. It follows PiG 0.5.3 and uses PiG's own settings, providers and keys (`~/.pig`, or `$PIG_HOME`; the environment: `FIREWORKS_API_KEY` for Fireworks). PiG has no permission prompts: its tools run without asking. A folder's `.pig` settings, extensions and MCP servers load only once you've trusted the folder in PiG (`/trust`). A PiG chat resumes in a terminal with `pig --session <session id>`; Delete moves its session file to the Trash, as PiG does.

Setting up needs Node and npm on the login shell's `PATH` (Nushi doesn't install them); it runs `npm ci` from the lockfile (every package's version and hash pinned, no install scripts, no optional packages such as the adapters' own Claude Code or Codex), with npm's cache in the folder and removed after. Update installs a newer adapter when Nushi pins one; Remove deletes it. `make adapters` writes the lockfiles again after a version changes. What each agent can do (fork, rewind, steering, questions, the context breakdown, MCP) follows what it reports; a control it lacks isn't shown.

A chat whose agent isn't needed can sleep: its agent stops and the chat stays, and the next message wakes it (`session/load`). Chats sleep on their own after 30 idle minutes when nothing would be lost (Settings changes the time), or from a chat's menu ([ADR 0032](docs/adr/0032-idle-chats-sleep.md)). The bar along the window's bottom counts working, awake and sleeping agents, and shows the memory Nushi takes; a click lists each awake chat's.

## Jira

Settings › Jira adds a Jira Cloud site: its address, your email and an API token (classic or scoped, from id.atlassian.com; its expiry date if you want a warning before it ends). Nushi checks it with Jira, then keeps the token in your login keychain, never in a file ([ADR 0042](docs/adr/0042-jira-cloud-through-our-own-client-tokens-in-the-keychain.md)). After an update of Nushi, macOS wants your OK before the new build reads it: Allow… asks.

⌘J (View › Jira, or Jira at the sidebar's foot) shows Jira in the chat's place, as a task list: your open issues grouped by status (or the active sprint of a board you pick, a saved search, or JQL that completes fields, operators and values as you type), each row with its key, summary, priority, the chats on it (a click opens the newest), its status (a click lists the moves its workflow allows) and Start work. With several sites, "All sites" lists your open issues from each. ⏎ or a click shows an issue's details in the list's place: description and comments, subtasks, parent, links, attachments, remote links, and a box to comment in (Markdown); Esc goes back. ↑↓ or j k pick, ⌘⏎ starts work, ⌘R refreshes, ⌘1–9 switch lists, / goes to the JQL, Esc closes. Lists and the issue are asked for again each minute while the view shows; nothing reaches Jira otherwise, and Nushi never writes to it unless you (or an agent, through its tools) do.

Start work on an issue (its row, or Start a chat in its details) picks the folder, then opens the New chat dialog with the issue picked; or, in the New chat dialog, press I (or ⌘V with an issue's link) and paste a link (`https://<site>/browse/ABC-12`), type a key, or search by words across your sites. A picked issue turns on a new worktree on a branch named after it (`ABC-12-fix-the-login`): W turns it off, B changes the branch, ⌫ clears the issue. Nothing about the issue goes into the box; the chat shows the key, and the issue's details list its chats. Claude and Codex chats on an issue get four tools for it, through an MCP server of Nushi's own, which also tells the agent which issue its chat is for: read it, comment on it, list its moves, move it; never another issue, and never the token ([ADR 0043](docs/adr/0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md)). Their own permission prompts ask before the tools run, and the issue view says which comments and moves were an agent's.

## GitHub

If you're signed in to `gh` (`gh auth login`), GitHub works as is: the daemon reads gh's token for each host gh knows, as gh does (the environment's `GH_TOKEN`, gh's config, or `gh auth token`), in its own process. Settings › GitHub shows each host, who its token is and where it's from, and what's left of GitHub's rate limits this hour (shared with your `gh` and agents that run it). For a host without gh, or instead of gh's login, add a token there (a classic one with `repo` and `read:org` covers what Nushi does; a fine-grained one sees one owner's repositories and no checks): Nushi checks it with GitHub and keeps it in your login keychain ([ADR 0045](docs/adr/0045-github-through-our-own-client-gh-login-first.md)). A token is only ever sent to its own host.

⌘G (View › GitHub, or GitHub at the sidebar's foot) shows GitHub in the chat's place, as an inbox: pull requests whose review is asked of you by name (or of your teams too: Review requested's "Only me ▾" picks, remembered), your pull requests, and issues assigned to you, in all repositories or only those of the folders Nushi knows; each row with its state, checks, review, review threads not resolved, its chats, when it changed ("12d", "5w", "3mo"; the date and time on hover), and Start work. ⏎ or a click shows the details: a pull request's header (base ← head, author, reviewers and their states, whether it can merge), its conversation (with a comment box), its checks (a failed one opens to its annotations and the end of its job's log) and its files in Nushi's diff view with the review threads at their lines (Reply, Resolve, Unresolve); select lines to write an inline comment of your review, then Review… sends it with all of them (comment, approve, request changes). The inbox is asked for again each minute while it shows, an open pull request every 30 s ([ADR 0046](docs/adr/0046-the-github-inbox-and-polling.md)); nothing reaches GitHub otherwise, and Nushi writes to it only what you send. Merging isn't offered yet.

Start work on a pull request or an issue picks a folder (a clone of its repository first), then opens the New chat dialog with it: a pull request's worktree starts on its head (fetched from the folder's remote that is its repository: a branch of it is checked out and tracks it, so a push goes to the pull request; a fork's comes from `refs/pull/<n>/head`, read-only, on `pr-<n>-<branch>`), an issue's on a branch named after it (`123-add-a-thing`). The chat's header shows the pull request's or issue's state, checks, review and threads (hover for more; a click shows it), and its details list its chats. Fix checks and Address comments write a message for the chat's agent (the failed checks with their logs' ends; the review threads, picked or all not resolved) into its box, to read and change before you send it; what GitHub holds goes in as data, never as instructions, and authors outside the repository are marked.

## Remote access

Settings → Remote access connects the daemon to a relay you name (`wss://…`), so a phone can reach it from anywhere; it's off until you turn it on, and nothing listens on the Mac: the daemon dials out, through the Mac's proxy settings (the environment's `HTTPS_PROXY`, else the system's proxy or PAC file; not WPAD, NTLM or Kerberos). While it's on, the Mac doesn't idle-sleep (`caffeinate`); a closed lid on battery still sleeps. "Pair a phone" shows a QR code; the phone then shows a six-digit code, and the Mac asks to allow it by name and code. Everything between the phone and the daemon is end-to-end encrypted with Noise, and a paired phone is a full client, like the app ([ADR 0034](docs/adr/0034-noise-between-phone-and-daemon.md), with the threat model). The phone app itself isn't built yet; `packages/remote_transport` is its side of the channel.

## The relay

A phone reaches the daemon through a relay: `nushi-relay`, one static binary that pairs two WebSocket connections on an id (only the daemon, holding its key, can listen there) and copies their messages, which are end-to-end encrypted between the phone and the daemon. It keeps nothing: no accounts, no disk, no logs beyond starting ([ADR 0033](docs/adr/0033-the-relay-is-a-dumb-pipe.md) says what it can still see). Anyone can run one; Nushi doesn't run one for you.

```sh
make relay                                   # bin/nushi-relay, no cgo
bin/nushi-relay -addr 127.0.0.1:8080         # plain ws://, e.g. behind a reverse proxy
bin/nushi-relay -host relay.example.com      # wss:// on :443 with a Let's Encrypt certificate
bin/nushi-relay -h                           # the caps: message size, rate, idle time, connections
```

Use `wss://`: company proxies tunnel 443 but often break a plain `ws://` upgrade, and iOS refuses plain connections by default.

**On a VPS** (any small Linux box): build with `GOOS=linux GOARCH=amd64 make relay`, copy the binary, point a DNS name at the box, and run it as a service with port 443 open:

```ini
# /etc/systemd/system/nushi-relay.service
[Service]
ExecStart=/usr/local/bin/nushi-relay -host relay.example.com -cert-cache /var/lib/nushi-relay
AmbientCapabilities=CAP_NET_BIND_SERVICE
DynamicUser=yes
StateDirectory=nushi-relay
Restart=always
[Install]
WantedBy=multi-user.target
```

The certificate cache is the only thing it writes; without `-cert-cache` each start asks Let's Encrypt for a new certificate, and frequent restarts run into its rate limits.

**On Fly.io** (`fly launch --no-deploy`, then `fly deploy`), with Fly terminating TLS:

```dockerfile
FROM golang:1.27 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /nushi-relay ./cmd/nushi-relay
FROM scratch
COPY --from=build /nushi-relay /nushi-relay
CMD ["/nushi-relay", "-addr", ":8080", "-ip-header", "Fly-Client-IP"]
```

```toml
# fly.toml
app = "my-nushi-relay"
[[services]]
  internal_port = 8080
  protocol = "tcp"
  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

`-ip-header` makes the per-address caps count Fly's client address rather than its proxy's. Behind a proxy of your own, name a header it sets (nginx's `X-Real-IP $remote_addr`) or one it appends to (`X-Forwarded-For` with `$proxy_add_x_forwarded_for`, HAProxy's `option forwardfor`): the relay takes the last entry, the one the proxy added, since the client writes what comes before; with several proxies in a row, `-ip-hops` says how many append. Never a header the proxy passes on as the client sent it. Fly's edge then sees what the relay sees (ids, timing, sizes, addresses), and may log requests. For TLS of the relay's own, give the port no handlers, run `-host` with `-cert-cache` on a volume, and copy `/etc/ssl/certs/ca-certificates.crt` into the image (autocert talks to Let's Encrypt over HTTPS).

Decisions are in [`docs/adr/`](docs/adr/README.md).
