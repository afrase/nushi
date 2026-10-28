<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/brand/mark-dark.svg"><img src="docs/brand/mark.svg" width="88" alt=""></picture></p>

# Nushi

An agentic development environment (ADE) for macOS: coding agents (Claude, Codex and others) run as chats over the [Agent Client Protocol](https://agentclientprotocol.com), beside a diff viewer, terminals, Jira and GitHub, and a phone web app to follow them. A Go daemon (`nushid`) runs the agents; a Flutter app is the window. Linux and Windows aren't supported yet (the daemon uses macOS's keychain, sandbox and launchd); the relay runs anywhere.

## Install

On a Mac with Apple silicon and macOS 13 or later, from the owner's Homebrew tap ([ADR 0055](docs/adr/0055-releases-and-the-homebrew-cask.md)):

```sh
brew install --cask afrase/tap/nushi
brew upgrade --cask nushi              # a newer release
brew uninstall --cask nushi            # the app; chats' data stays
brew uninstall --zap --cask nushi      # the app and Nushi's data
```

Releases are signed ad hoc, not notarized: the cask clears macOS's quarantine flag, so installing from the tap stands in for Gatekeeper's check. Without Homebrew, take `Nushi-X.Y.Z.zip` from [Releases](https://github.com/afrase/nushi/releases), check it (`shasum -a 256 -c Nushi-X.Y.Z.zip.sha256`), unzip it, move Nushi.app to Applications and open it; macOS refuses the first time: System Settings › Privacy & Security › Open Anyway.

- **Upgrading** quits the app and opens the new one; the daemon keeps running, its chats too, and restarts into the new one by itself once no chat has a turn running or waiting on you, nothing is queued and no terminal runs a command ("Nushi will update its daemon when the chats are idle", with Restart now). Chats reopen where they were on their next message; terminals at their prompt close. Each release is a new program to macOS, so after an upgrade a Jira token (and a GitHub token you pasted) needs your OK once more: Allow…, then Always Allow in macOS's prompt (Jira, below). gh's own login isn't affected.
- **Uninstalling** quits the app; the daemon stops by itself within about a minute once the app is gone (also when you drag it to the Trash), and Start at login's item goes with the app. Chats' data stays in `~/Library/Application Support/Nushi`. **`--zap` deletes it**: Nushi's copies of every chat's transcript, settings, trust answers, remote access keys and paired devices, the adapters and the logs, and the app's preferences. Not the agents' own history (`~/.claude`, `~/.codex`, `~/.ante`, `~/.omp`, `~/.pig`): those chats still resume in a terminal. The keychain's "Nushi Jira" and "Nushi GitHub" items stay (remove the sites in Settings first, or in Keychain Access).
- **On a Pi** (the relay and the phone's web app, below), each release has `nushi-relay-X.Y.Z-linux-arm64.tar.gz` (and `linux-amd64`, `darwin-arm64`: static binaries) and `nushi-web-X.Y.Z.tar.gz`; update the web app with the Mac:

```sh
tar -xzf nushi-relay-X.Y.Z-linux-arm64.tar.gz && sudo install nushi-relay /usr/local/bin/
sudo rm -rf /usr/local/share/nushi-web && sudo tar -xzf nushi-web-X.Y.Z.tar.gz -C /usr/local/share
nushi-relay -version                   # then restart its service
```

Settings › Logs & advanced shows the app's version and the running daemon's (`nushid -version` in the helper app says the same).

## Requirements

- Go (current stable) and Flutter on `PATH`
- For `make gen`: `dart pub global activate protoc_plugin` and `dart pub global activate connectrpc` (buf runs through `go run`)

## Run

```sh
make run     # starts nushid in the background (if it isn't running), then the app
make stop    # stops nushid
make test    # all tests (test-go, test-packages, test-app, test-web)
make lint    # the linters and format checks, below (lint-go, lint-dart)
make check   # lint, then test
make gen     # regenerate the API code after editing proto/
make lines   # hand-written line counts
make package # a release "Nushi.app" with nushid inside (signed: NOTES.md says with what)
tools/release.sh 1.2.0 # a release's files into dist/, as the release workflow builds them (or a part: app, relay, web)
make install # package, then copy it to ~/Applications
make icons   # redraw the app icon and the mark (tools/icongen)
```

Settings (⌘,) takes the chat's place beside the sidebar, its sections in a list on the left; Esc or Close goes back ([ADR 0053](docs/adr/0053-settings-is-a-view.md)).

The packaged app starts its bundled `nushid` (in `Contents/Helpers/Nushi Daemon.app`, a background-only app) when no daemon is running, and leaves it running when it quits; Settings › Start at login also starts it at login ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md), [ADR 0036](docs/adr/0036-the-daemon-is-a-background-helper-app.md)). `make package` checks the bundle's layout and signatures (`tools/check-bundle.sh`). A daemon whose app is deleted stops within about a minute; one whose app is replaced (an upgrade, `make install`) keeps running until you restart it. With `make run`, start and stop the daemon yourself.

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi/`: `nushid.log` (rotated at 10 MB, two older copies), and `app.log` for what the app logged while the daemon didn't answer. Settings › Logs & advanced reveals them and turns on debug lines (or `NUSHI_LOG=debug`); one chat's lines are `grep 'chat=<id>' nushid.log` ([ADR 0038](docs/adr/0038-logs-you-can-debug-from.md) says what is logged and what never is). To try a build beside a Nushi that's in use, give both another folder: `NUSHI_DATA=~/Library/Application\ Support/Nushi\ Dev make run` (and the same for `make stop`). Everything Nushi writes outside its data folder, and why, is in [docs/user/outside-the-data-folder.md](docs/user/outside-the-data-folder.md).

## Development

`make lint` runs golangci-lint (with gofmt and goimports), govulncheck, `buf lint` and `buf format`, and `flutter analyze` and `dart format` for the app and each package; `make check` runs it and then the tests. CI (`.github/workflows/ci.yml`) runs the same parts as parallel jobs, in under 3 minutes: on macOS Go's lint and tests and the web app's end-to-end test, and the app's tests in two shards (`make test-app SHARD=1/2`: every second test file); on Linux the protos' and Dart's lint, the Dart packages' tests, and the relay's and the Noise channel's Go tests.

- **Go:** golangci-lint and govulncheck are pinned in their own module, `tools/lint/go.mod`; `make lint` builds them into `bin/` and runs them: nothing to install, and the daemon's `go.mod` doesn't take their dependencies. `.golangci.yml` turns every linter on and lists each one off with the reason. govulncheck checks the daemon, the relay and the tools against vuln.go.dev (so `make lint` needs the network) and fails on a vulnerability the code calls; the Go version is the `go` line in `go.mod`, which the go command fetches if yours is older. To format: `bin/golangci-lint fmt ./...`.
- **ACP:** agents are spoken to through the library `github.com/afrase/acp-go` (its `unstable` package), at the version in `go.mod` ([ADR 0041](docs/adr/0041-acp-through-acp-go.md)). To change it and Nushi at once, clone it beside Nushi and run `go work init . ../acp-go` here: the `go.work` (ignored by git) makes Nushi build with your checkout. Remove it to build with the tagged version again; then `go get github.com/afrase/acp-go@vX.Y.Z` once the library has the release you need.
- **Dart:** every package and the app include [very_good_analysis](https://pub.dev/packages/very_good_analysis) (strict casts, inference and raw types, and nearly every lint rule), then `analysis_options.yaml` at the root, which adds a few rules and turns off the ones that don't fit, each with why; the app also turns off `public_member_api_docs` (it isn't a library). `dart fix --apply` in a package fixes much of what it reports.
- A report that's wrong for one line takes `//nolint:<linter> // <why>` (nolintlint refuses one without both), or `// ignore: <rule>` under a comment saying why in Dart (`// ignore_for_file:` when a whole file is about it). NOTES.md says when to exclude by path instead.

## Agents

"New chat" (⌘N, or a folder's +) asks which agent to run, with the one used last picked: Enter starts it. A chat keeps its agent, and shows its mark in the sidebar ([where the marks come from](docs/user/agent-marks.md)). Hold ⌘ and the sidebar numbers its first nine chats, top to bottom (archived ones left out): ⌘1–⌘9 opens one, ⌘[ and ⌘] the one before or after (View › Previous Chat, Next Chat).

A Markdown file or image a chat's agent wrote (or a subagent of it) previews beside the chat, kept current as it changes: from its tool row's Preview, from "Artifacts 4" in the chat's header (each file it wrote, the newest change first, with its folder and when it changed), from the Artifacts card in the details panel (the same list; the open one marked), or from the preview's own name, which lists them too. ⌘P (File › Open File…) opens any such file in the chat's folder that git doesn't ignore, matched as you type.

The same dialog opens a session started elsewhere, such as `claude` or `codex` in a terminal: → (or "Sessions →" on the highlighted agent's row) lists the agent's sessions in the folder (from No folder, every folder's), and Enter opens one as a chat. The agent replays it (Nushi keeps its own copy of what shows from then on, as for every chat) and it goes on in the same history the terminal resumes ([ADR 0035](docs/adr/0035-open-sessions-started-elsewhere.md)). A session still open elsewhere is marked: Claude and Ante let both write (Nushi asks first), Codex and oh-my-pi only one; PiG leaves no mark, and both write.

Settings › Agents shows each agent as Nushi finds it on your login shell's `PATH`: its version and path, or "Not installed" with where to get it. Finding them changes nothing: each CLI is only asked its version, with writes and the network denied. Nushi runs your own CLIs, never a copy it brings ([ADR 0037](docs/adr/0037-agents-you-set-up.md)).

Agents start with your login shell's environment, as a new terminal has it, however the daemon was started: the daemon runs your shell (fish, zsh, bash…) as a login, interactive shell and reads what it exports, fish's universal variables included. It reads it again when you open Settings › Agents (if it's over a minute old) or press Reload there, so a variable you add reaches the agents started after that, with no restart; a chat whose agent runs keeps what it started with. The last line of Settings › Agents says when it was read, or why it couldn't be ("Couldn't read your shell's environment: fish took over 5s"; agents then get the last one read, else the daemon's). While it's read, `NUSHI_RESOLVING_ENVIRONMENT=1` is set, so your config can skip what only a terminal wants (`if not set -q NUSHI_RESOLVING_ENVIRONMENT; …`). Nushi never logs or writes down the values, and gives them only to the agents' processes ([ADR 0048](docs/adr/0048-agents-start-with-the-login-shells-environment.md)).

- **Claude** runs your `claude` through Claude Code's ACP adapter, `@agentclientprotocol/claude-agent-acp` 0.94.0, which **Set up** installs into `~/Library/Application Support/Nushi/agents/claude` (about 9 MB from npm, from the lockfile in `internal/claude/adapter`). It uses Claude Code's own login and settings. Its `/code-review` reports its findings as a card in the transcript (Nushi sets `CLAUDE_CODE_REPORT_FINDINGS` for Claude Code); a review that writes them as JSON gets the same card, with Show JSON. A row opens to how the finding fails; its `file:line` opens the chat's Changes at that line, or the file as it is when it isn't changed. Ultracode (in the "⋯" menu under the box) turns on Claude Code's standing multi-agent workflows for the chat (off by default; "Ultracode" shows beside the model while it's on); changing it reopens the chat's session (a second or so), so it waits for a turn to end. The word "ultracode" in a message opts just that turn in, as in the terminal.
- **Codex** runs your `codex` through `@agentclientprotocol/codex-acp` 2.2.2, set up the same way (about 2 MB). It uses Codex's own login or config (`$CODEX_HOME`, else `~/.codex`): sign in with `codex login`, or name a provider in `config.toml` ([docs/user/codex-config.md](docs/user/codex-config.md) has one for Fireworks). A provider's key comes from the environment, which agents get from your login shell ([ADR 0048](docs/adr/0048-agents-start-with-the-login-shells-environment.md)). A Codex chat resumes in a terminal with `codex resume <session id>`.
- **Ante**, through Nushi's own bridge (`nushid ante-acp`, [ADR 0030](docs/adr/0030-our-own-bridge-for-ante.md)), which runs an `ante serve --stdio` per session: nothing to set up. It needs Ante 0.2.14 or newer (`ante` on `PATH`, or in `~/.ante/bin`) and uses Ante's own settings, providers and sign-in (`~/.ante`, or `$ANTE_HOME`). An Ante chat resumes in a terminal with `ante --resume <session id>`.
- **oh-my-pi** runs your `omp --mode acp` under your Bun: nothing to set up, once you've installed both. It uses omp's own config and keys (`~/.omp`, the environment: `FIREWORKS_API_KEY` for Fireworks). [docs/user/ante-omp-pig.md](docs/user/ante-omp-pig.md) has how to install it, and settings for Ante, omp and PiG. An omp chat resumes in a terminal with `omp --resume <session id>`; Nushi can't delete an omp session's history.
- **PiG** (pi-in-go.dev), through Nushi's own bridge (`nushid pig-acp`, [ADR 0039](docs/adr/0039-our-own-bridge-for-pig.md)), which runs your `pig --mode rpc` per session: nothing to set up once `pig` is on `PATH`. It follows PiG 0.5.3 and uses PiG's own settings, providers and keys (`~/.pig`, or `$PIG_HOME`; the environment: `FIREWORKS_API_KEY` for Fireworks). PiG has no permission prompts: its tools run without asking. A folder's `.pig` settings, extensions and MCP servers load only once you've trusted the folder in PiG (`/trust`). A PiG chat resumes in a terminal with `pig --session <session id>`; Delete moves its session file to the Trash, as PiG does.

Setting up needs Node and npm on the login shell's `PATH` (Nushi doesn't install them); it runs `npm ci` from the lockfile (every package's version and hash pinned, no install scripts, no optional packages such as the adapters' own Claude Code or Codex), with npm's cache in the folder and removed after. Update installs a newer adapter when Nushi pins one; Remove deletes it. `make adapters` writes the lockfiles again after a version changes. What each agent can do (fork, rewind, steering, questions, the context breakdown, MCP) follows what it reports; a control it lacks isn't shown.

A chat in a git repository can run in a worktree of its own (New worktree, under the box of a chat without messages; for that chat only: every new chat starts in the folder itself): `.worktrees/<two words>`, on a new branch `nushi/<two words>`. Once a turn ends with the chat titled, the branch is named after the chat (`nushi/bump-go-1-27-3`), unless it was pushed or renamed, and a quiet line in the transcript says so; the folder keeps its name. Rename branch… (the pencil beside the branch in the details panel) names it yourself, between turns. Either way the agent is told with your next message, in a sentence of Nushi's before yours (`[Nushi] This worktree's branch was renamed from … to …. Use the new name.`), and the line then says "· told the agent"; the agent's history keeps that sentence as part of your message, so a terminal resume shows it ([ADR 0016](docs/adr/0016-a-worktree-per-chat.md)).

A chat whose agent isn't needed can sleep: its agent stops and the chat stays, and the next message wakes it (`session/load`). Chats sleep on their own after 30 idle minutes when nothing would be lost (Settings changes the time), or from a chat's menu ([ADR 0032](docs/adr/0032-idle-chats-sleep.md)). The bar along the window's bottom counts working, awake and sleeping agents, and shows the memory Nushi takes; a click lists each awake chat's.

A chat's history is its agent's: a chat reopens from the agent's session, and resumes in a terminal from it. Nushi also keeps its own read-only copy of each chat's transcript as it was shown (Settings › Chat history, on by default; [ADR 0047](docs/adr/0047-nushis-copy-of-transcripts.md)), for what the agent no longer replays. After `/compact` (or Claude compacting on its own) Claude replays only what follows, so a reopened chat shows the earlier part from the copy, with "Compacted here" where Claude's history starts again (a click shows the summary Claude kept). If the session changed elsewhere (rewound or edited in a terminal), Claude's version shows from where they differ, after a divider. The copy is never sent to the agent. Settings › Chat history lists every chat's copy in a table (title, folder, agent, size, last used), sorted by size, last used or title, searched by title and folder, and filtered to archived chats, those whose agent no longer has them, or deleted chats' leftovers; it clears one (a row's Clear), those picked (click, ⇧-click a range, ⌘-click), all, or on their own after 30, 90 or 365 days; a row's title opens its chat. Turning it off asks whether to keep or delete the copies there are.

Claude Code deletes sessions older than `cleanupPeriodDays` (30 days by default, in Claude's settings) when it starts. A chat with a copy then stays, read-only: its transcript is the copy, with Delete… and Start a new chat here (in its folder). A chat without one is forgotten, when you open it or when Nushi finds the session's file gone from Claude's history (at most hourly, starting nothing), and the app says once which chats went. Nothing else is touched: a worktree and its branch stay. A chat whose worktree has uncommitted changes or commits stays too, saying Claude no longer has its session, with Delete… to deal with the worktree. A Codex session you archived isn't gone: `codex unarchive <id>`, then Try again ([ADR 0015](docs/adr/0015-delete-takes-the-agents-history.md)).

## MCP servers and skills

**MCP servers** (Settings › MCP servers: the sidebar's footer, or a chat's ⋯ › MCP servers…) lists the servers Claude uses in a folder, by scope, each with its state. Each user, project and local server has a switch, "in this project": a project server's approves or rejects its `.mcp.json` entry (the project's `.claude/settings.local.json`); a user or local one is turned off as `/mcp` does in a terminal, by Claude itself ([ADR 0050](docs/adr/0050-mcp-servers-off-through-claudes-own-toggle.md)), so the terminal sees it too. A plugin's server or a claude.ai connector says "Off only with /mcp in a terminal" (or turn its plugin off in Skills). A server that's off stays listed, dimmed. A running chat keeps its servers until it restarts: the details panel's MCP card says "Applies when the chat restarts" with Reload.

**Skills** (Settings › Skills: the footer, or ⋯ › Skills…, which opens that chat's agent) lists an agent's skills for a folder; pick the agent beside the title (Claude at first). Groups: yours, the project's (where that agent reads them), **Shared**, the agent's own, and for Claude each plugin's and its built-in ones together; each skill with its description, about what it costs every chat's context, and a switch that says how it acts ("everywhere" or "in this project" for Claude's `skillOverrides`; "in config.toml" for Codex; "in your settings" or "in .pig/settings.json" for PiG; "by name, everywhere" for Ante and oh-my-pi). **Shared** is `.agents/skills` (the project's, as the agents walk it) and `~/.agents/skills`, which Codex, PiG, oh-my-pi and Ante read: each skill says which agents load it ("Off for Codex", "PiG loads it once the folder is trusted"), and its switch is the picked agent's. Claude doesn't read `.agents/skills` yet: a shared skill's ⋯ › Link for Claude… makes `.claude/skills/<name>`, a relative link to it, so Claude loads it too. Search filters skills and plugins; a skill's ⋯ opens its `SKILL.md` as text, shows it in Finder, or deletes it (its folder, or the link in its place, to the Trash, naming every agent that loses it). Plugins lists what each brings (skills, commands, agents, MCP servers), turns it on or off, or uninstalls one installed for you. New skill… opens a chat with the picked agent in the folder with a request in the box to write one in `.agents/skills` (for Claude, it asks first: `.claude/skills`, or `.agents/skills` and a link). What you change in a terminal shows when the section opens or on Refresh ([ADR 0051](docs/adr/0051-the-skills-manager.md), [ADR 0052](docs/adr/0052-skills-for-every-agent-and-the-shared-folder.md)).

## Jira

Settings › Jira adds a Jira Cloud site: its address, your email and an API token (classic or scoped, from id.atlassian.com; its expiry date if you want a warning before it ends). Nushi checks it with Jira, then keeps the token in your login keychain, never in a file ([ADR 0042](docs/adr/0042-jira-cloud-through-our-own-client-tokens-in-the-keychain.md)). After an update of Nushi, macOS wants your OK before the new build reads it: Allow… asks. A daemon started before the update (or outside your login session) can't be given that OK: Nushi says so and offers Restart daemon instead.

⌘J (View › Jira, or Jira at the sidebar's foot) shows Jira in the chat's place, as a task list: your open issues in a card for each status (drag a card by its title to reorder, click it to collapse; both kept per site) (or the active sprint of a board you pick, a saved search, or JQL that completes fields, operators and values as you type), each row with its key, summary, the chats on it (a click opens the newest), then in columns its priority, its status (a click lists the moves its workflow allows) and, outside Mine, who it's assigned to (a round avatar with initials, the name on hover; a dashed circle when nobody); Start work shows on the row under the pointer and the selected one (⌘⏎), and in its right-click menu. The sprint, a saved search and JQL have "Everyone ▾" at the bar's end: Me, Unassigned or anyone the list has, remembered per site and list. With several sites, "All sites" lists your open issues from each. ⏎ or a click shows an issue's details in the list's place: description and comments, subtasks, parent, links, attachments, remote links, and a box to comment in (Markdown); Esc goes back. ↑↓ or j k pick, ⌘⏎ starts work, ⌘R refreshes, ⌥⌘1–9 switch lists, / goes to the JQL, Esc closes. What a list or an issue showed last shows at once while Jira is asked again ("Updated 5m ago · refreshing"), kept by the daemon per site in its data folder. Lists and the issue are asked for again each minute while the view shows; nothing reaches Jira otherwise, and Nushi never writes to it unless you (or an agent, through its tools) do.

Start work on an issue (its row, or Start a chat in its details) picks the folder, then opens the New chat dialog with the issue picked; or, in the New chat dialog, press I (or ⌘V with an issue's link) and paste a link (`https://<site>/browse/ABC-12`), type a key, or search by words across your sites. A picked issue turns on a new worktree on a branch named after it (`ABC-12-fix-the-login`): W turns it off, B changes the branch, ⌫ clears the issue. Nothing about the issue goes into the box; the chat shows the key, and the issue's details list its chats. Claude and Codex chats on an issue get four tools for it, through an MCP server of Nushi's own, which also tells the agent which issue its chat is for: read it, comment on it, list its moves, move it; never another issue, and never the token ([ADR 0043](docs/adr/0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md)). Their own permission prompts ask before the tools run, and the issue view says which comments and moves were an agent's.

## GitHub

If you're signed in to `gh` (`gh auth login`), GitHub works as is: the daemon reads gh's token for each host gh knows, as gh does (the environment's `GH_TOKEN`, gh's config, or `gh auth token`), in its own process. Settings › GitHub shows each host, who its token is and where it's from, and what's left of GitHub's rate limits this hour (shared with your `gh` and agents that run it). For a host without gh, or instead of gh's login, add a token there (a classic one with `repo` and `read:org` covers what Nushi does; a fine-grained one sees one owner's repositories and no checks): Nushi checks it with GitHub and keeps it in your login keychain ([ADR 0045](docs/adr/0045-github-through-our-own-client-gh-login-first.md)). A token is only ever sent to its own host.

⌘G (View › GitHub, or GitHub at the sidebar's foot) shows GitHub in the chat's place, as an inbox of three cards: pull requests whose review is asked of you by name (or of your teams too: Review requested's "Only me ▾" picks, remembered), your pull requests, and issues assigned to you. Drag a card by its title row to reorder them, click its title to collapse it; both are remembered. Each row shows its title with `owner/repo#123` under it, its chats, then its review decision, checks, review threads not resolved (else comments) and when it changed ("12d", "5w", "3mo"; the date and time on hover); Start work shows on the row under the pointer and the selected one (⌘⏎), and in its right-click menu with Open in the browser and Hide this repository. The bar picks what's listed, remembered: "Last 90 days ▾" (30 days, a year, any time; a card ends with "3 older than 90 days · Show" to see them until Nushi quits), and the repositories (all, those of the folders Nushi knows, or only some owners', such as `afrase my-org`; the owners and repositories listed, checked while shown, to hide one or show it again). The filters go into GitHub's searches, so what they leave out doesn't take the 50 places of a card. ⏎ or a click shows the details: a pull request's header (base ← head, author, reviewers and their states, whether it can merge), its conversation (with a comment box), its checks (a failed one opens to its annotations and the end of its job's log) and its files in Nushi's diff view with the review threads at their lines (Reply, Resolve, Unresolve); select lines to write an inline comment of your review, then Review… sends it with all of them (comment, approve, request changes). The inbox shows as GitHub gave it last while it's asked again. The inbox is asked for again each minute while it shows, an open pull request every 30 s ([ADR 0046](docs/adr/0046-the-github-inbox-and-polling.md)); nothing reaches GitHub otherwise, and Nushi writes to it only what you send. Merging isn't offered yet.

Start work on a pull request or an issue picks a folder (a clone of its repository first), then opens the New chat dialog with it: a pull request's worktree starts on its head (fetched from the folder's remote that is its repository: a branch of it is checked out and tracks it, so a push goes to the pull request; a fork's comes from `refs/pull/<n>/head`, read-only, on `pr-<n>-<branch>`), an issue's on a branch named after it (`123-add-a-thing`). The chat's header shows the pull request's or issue's state, checks, review and threads (hover for more; a click shows it), and its details list its chats. Fix checks and Address comments write a message for the chat's agent (the failed checks with their logs' ends; the review threads, picked or all not resolved) into its box, to read and change before you send it; what GitHub holds goes in as data, never as instructions, and authors outside the repository are marked.

## Remote access

Settings → Remote access connects the daemon to a relay you name (`wss://…`), so a phone can reach it from anywhere; it's off until you turn it on, and nothing listens on the Mac: the daemon dials out, through the Mac's proxy settings (the environment's `HTTPS_PROXY`, else the system's proxy or PAC file; not WPAD, NTLM or Kerberos). While it's on, the Mac doesn't idle-sleep (`caffeinate`); a closed lid on battery still sleeps. "Pair a phone" shows a QR code; the phone then shows a six-digit code, and the Mac asks to allow it by name and code. Everything between the phone and the daemon is end-to-end encrypted with Noise, and a paired phone is a full client, like the app ([ADR 0034](docs/adr/0034-noise-between-phone-and-daemon.md), with the threat model). Each paired device says whether it's the web app or an app and whether its notifications are on, with Send a test notification and Revoke.

## The phone

The phone is Nushi's web app, added to the Home Screen ([ADR 0054](docs/adr/0054-the-phone-is-a-web-app-with-web-push.md)): the chats with what each is doing, a chat's transcript and composer (send, Queue and Steer while a turn runs, Stop), its prompts and questions answered with a tap, a Markdown file or image the agent wrote previewed full screen (its tool row's Preview, or Artifacts in the chat's bar), New chat, and Settings. Your relay serves it (`-web`, below), so it comes from a server you run. On an iPhone (iOS 16.4 or later):

1. Open your relay's address in Safari (`https://<your relay>/`), tap Share › Add to Home Screen, and open Nushi from the Home Screen. Pair there, not in Safari: the Home Screen app keeps its own storage, and only it gets notifications.
2. On the Mac: Settings › Remote access › Pair a phone. In Nushi on the iPhone, name the device and tap Scan QR code (allow the camera), point it at the Mac's code: pairing starts. Or Copy link on the Mac and paste it (Universal Clipboard) into Pairing link, then Pair. The iPhone's own Camera opens the code in Safari, which can only say to open Nushi and scan there.
3. Check the iPhone's six-digit code is the one the Mac shows, and Allow on the Mac.
4. Settings › Notifications on, and Allow when iOS asks. A notification says only what happened ("Claude finished", "Codex needs you", "Claude has a question"); tapping it opens that chat. None comes for the chat you have open.

Forget this Mac (Settings) forgets the pairing and the device's key on the phone; revoke the device on the Mac too. The web app works in a desktop browser the same way (Chrome on a Mac gets notifications too).

When the Mac can't be reached the app says so quietly ("Reconnecting…") and keeps trying; after a couple of tries it says why ("it's asleep or offline, or its remote access is off") and when it last answered, with Try again. A long chat opens with its latest part; older parts come as you scroll up. After the first visit the app starts from its own cache; a new version shows "Nushi was updated" with Reload.

## The relay

A phone reaches the daemon through a relay: `nushi-relay`, one static binary that pairs two WebSocket connections on an id (only the daemon, holding its key, can listen there) and copies their messages, which are end-to-end encrypted between the phone and the daemon. It keeps nothing: no accounts, no disk, no logs beyond starting ([ADR 0033](docs/adr/0033-the-relay-is-a-dumb-pipe.md) says what it can still see). Anyone can run one; Nushi doesn't run one for you.

```sh
make relay                                   # bin/nushi-relay, no cgo
bin/nushi-relay -addr 127.0.0.1:8080         # plain ws://, e.g. behind a reverse proxy
bin/nushi-relay -host relay.example.com      # wss:// on :443 with a Let's Encrypt certificate
bin/nushi-relay -h                           # the caps: message size, rate, idle time, connections
make web                                     # the phone's web app, into app/build/web
bin/nushi-relay -addr 127.0.0.1:8090 -web app/build/web -origin https://relay.example.com
```

With `-web` the relay serves the phone's web app at `-origin` (the address the browser sees, scheme, host and port; with `-host`, `https://<host>` unless given) and takes WebSockets from pages there only; copy `app/build/web` to the relay's machine (`make web` writes a Brotli copy beside each file, which the relay serves to browsers that take it). Behind any HTTPS reverse proxy, `-origin` is the proxy's public address and `-ip-header` its header with the client's address. The owner's runs on a Raspberry Pi behind a Cloudflare named tunnel (`cloudflared`, which terminates TLS), as `nushi-relay -addr 127.0.0.1:8090 -ip-header CF-Connecting-IP -web /usr/local/share/nushi-web -origin https://nushi.aaronfrase.com -plain-per-ip 32`, and the Mac's relay is `wss://nushi.aaronfrase.com`; Cloudflare drops a WebSocket silent about 100 s, and both ends ping well within that. Whoever terminates TLS can serve the app's code (ADR 0054): a CDN in front is trusted for it, as the relay's host is. Tailscale Funnel worked too, but slowly (about 0.1–0.3 MB/s, seconds per connection). A web app loads a few dozen files at once, hence the higher cap on plain connections per address.

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
