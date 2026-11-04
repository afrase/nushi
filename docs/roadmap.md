# Roadmap

What isn't built yet and the decisions still open, each checked against the code on 2026-10-31. An entry goes when its work ships, in the same commit, and a gap is checked against the code before it's written down ([AGENTS.md](../AGENTS.md)). What's built is in the user docs, why in [`docs/adr/`](adr/README.md), October's small decisions in [`history/decisions-2026-10.md`](history/decisions-2026-10.md).

## Plans

### The app

- **The empty state as a visualisation** (the owner, 2026-10-26): a gravity toy (an orrery in the empty pane) didn't look good enough and was reverted. Revisit with a fresh agent and stronger visual references (the owner has seen better ones); a prototype in an HTML artifact first, before any Flutter.
- **The jump button as Nushi's mark** (the owner, 2026-11-01, from Claude Code): while you're scrolled up and the agent works, the round mark animates in place of `JumpChip`; under the pointer it turns into the jump-to-latest arrow. Nushi's icon is already circular.
- **Pinned messages as Claude's desktop app has them** (the owner, 2026-11-04): what shipped (ADR 0085: a pin in the hover row, a chip at the transcript's top left with its list) isn't how they work there. The owner will show how they do; redo it to match then.
- **Icons for chats** (the owner, 2026-11-02): an icon of the user's choice on a chat's row, beside its color, to tell chats apart when the names blend together.
- **The phone's list, arranged** (after the Mac's sidebar got its Arrange menu, 2026-11-04, ADR 0089): Group by and Sort by on the phone's chat list. The grouping and sort are shared code (`arrangement.dart`'s `groupChats`, `sortChats`); missing are a control in the phone's header, the choice kept in the phone's own storage (`platform_web.dart`, as its theme is), and how its Needs you group fits beside a Status grouping.
- **Opt-in metrics and crash logs** (the owner, 2026-11-01): off unless you turn them on, with nothing sent before that. Stack traces and counts only, never prompts, paths or tokens; what's collected is written down.
- **A redesign** (the owner, 2026-10-26): a fresh look at the whole app, not piecemeal fixes. Scope it with the owner first: what feels wrong, and which apps' look to learn from.
- **Linux and Windows** (the owner, 2026-10-27): the Flutter UI and most of the daemon are portable. What's macOS-only: the keychain (`internal/keychain`, cgo: libsecret / Windows Credential Manager), read-only runs through `sandbox-exec` (`internal/readonly`: Landlock or bubblewrap on Linux, nothing equal on Windows), launchd for Start at login (systemd user units / a Run key), the process footprint (`proc_info`: `/proc`), the app's Swift method channels (the installed fonts list), `app/linux` and `app/windows` runners, packaging. Windows also: ConPTY for terminals, AF_UNIX sockets (supported), paths and shells, and which agents' CLIs run there. Linux first.
- **A lazy transcript**, for long chats' speed and memory (ADR 0026: it fills in from the bottom over a few frames, but all of it is laid out once there; a lazy list needs known heights). The way in would be the phone's pages (`GetChatRequest.recent`, `GetChatItems`) on the Mac too, at the cost of a scrollbar over only what's loaded and ⌘F over the same; the owner kept the full layout (2026-11-04) while long chats don't feel slow.
- **A modular window** (the owner, 2026-11-04): panes you can drag anywhere and arrange as you like — the transcript, side chat, subagent, preview, details, terminal — docked or split, the layout remembered. "Maybe that's a future task." Today each pane has its place beside the transcript and only its width is dragged (`beside.dart`).
- **The side chat as Claude Code's** (the owner, 2026-10-29, from Claude Code's desktop app): there, Side chat is a pane of its own in the right-hand column (⌘;, from a ⋯ menu that also toggles Artifacts, Background tasks and Plan), with a tab and a short line saying what it is ("Chat about this session without touching the main thread … nothing here is added to the session"). Ours (⇧⌘B) lasts while hidden but opens apart from the details column, and says only "Ask in the side chat". Missing: a place in the details column, its empty state's line, and a look at the shortcut.
- **Find, next**: finding inside the shown diff (Changes' ⌘F only filters the file list), and the phone's find through the daemon's pages (the phone has no find).
- **Plain model chat** with no agent, straight to an API or gateway with a key (Nushi would own the history). Agent chats already reach a gateway through Claude's own settings (`ANTHROPIC_BASE_URL`, `apiKeyHelper`).
- **Usage limits** (session and weekly) for subscription users, if an agent exposes them; nothing shows them. claude-agent-acp 0.94.0 once put `_meta._claude/rateLimit` on a `usage_update` (`docs/facts/claude.md`), not a stable interface; the Go agent passes claude's the same way and nothing reads it.

### Previews

- **A Files view's rest** (the owner, 2026-10-27; the use case is seeing what the agent made, like Claude Code's artifacts): missing is the web view's hardening past WebKit's free defaults (the Files pane, ADR 0090, has the tree). The owner trusts what the agent writes as much as a page they'd open in a browser (2026-10-28), so the network stays on, no switch. Read-only (editing beside a writing agent: ADR 0019's reasons). Mocks: https://claude.ai/artifact/TP8YD5rSCSi2L28hnsdPGP (the owner liked them).

### Changes and review

- **Review comments by an agent** (from JetBrains AIR): a side chat reviews the changes and posts comments through a small MCP tool (`add_comment(file, line, text)`); they show in Changes, and those picked go to the main chat.
- **Findings, picked** (after a finding opened the chat's Changes at its line, 2026-10-26): tick a review's findings in its card and send them back to the agent ("fix these"), or show them as comments in Changes. Each finding already has a stable id (`findingIds`: its file, line and summary).
- **More git from Changes**: push, and staging by hunk ([ADR 0079](adr/0079-stage-and-commit-from-changes.md) has whole files; diff_view has no per-hunk controls yet).
- **Review comments on a related worktree** (the owner, 2026-11-02): off for now. They'd go to the orchestrator, since the subagent has usually exited (ADR 0081).
- **A related worktree's pull request**: its row says "merged" only from git, so a squash merge reads "removed". A pull request could say otherwise, but finding one by branch is a GitHub call for each row, which the row's refresh shouldn't make.

### GitHub

- **A found pull request's chip** in the chat's header: the header's chip shows only the pull request or issue a chat started from; a found one gets just its tab.
- **The agent's own GitHub tools** on Nushi's MCP server ([ADR 0043](adr/0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md)): a `tools.Set` scoped to the chat's pull request, as Jira's chats have for their issue.
- **GitHub, next**: stacked pull requests, notifications as a source (If-Modified-Since, X-Poll-Interval), reactions, files marked viewed, Enterprise capabilities probed, a review's inline comments kept across app restarts (quitting loses them).

### Jira

- **Jira, next**: a Data Center client (v2, wiki markup, personal tokens) behind `features/jira.Client`; review-comment tools on the same MCP server; creating issues, assigning, worklogs, remote links for a chat's PR, a "plan only" mode; `/jql/parse`; counts on the tabs; change badges from `changelog/bulkfetch`; Rovo MCP's OAuth; the token's expiry from the admin API.

### Agents

- **Agents without Node** (the owner, 2026-10-29): Claude runs through the Go agent alone since 2026-11-04 ([ADR 0066](adr/0066-claude-through-nushis-go-agent.md)). Missing: `claudeagent` and `claudeacp` published as `github.com/afrase/claude-acp-go` (prepared in `~/Developer/claude-acp-go` by `make claude-acp-go`; waits on the owner's look and Anthropic's terms on tools built on the Agent SDK with a subscription login), then Nushi importing it. Codex later, against `codex app-server --stdio`; omp needs Bun regardless. Smaller: codex-acp's `CODEX_PATH` could name the native binary past npm's 14 MB launcher (`docs/history/perf-2026-10.md`).
- **Each chat in a micro VM** (the owner, 2026-11-04, after seeing Firecracker): the agent and everything it runs sandboxed in a lightweight VM per chat. Firecracker itself needs Linux's KVM and can't run on a Mac; the Mac's counterpart is Apple's Virtualization framework, which its `container` tool and Containerization package use for one small Linux VM per container. Open: a Linux guest can't run macOS tools (Xcode, Swift for Apple platforms, Homebrew's Mac binaries), so it's a choice per chat or project, not a default; the worktree shared in (virtiofs) and what else (git config, SSH agent, the agent's login, which must reach the VM without Nushi reading it); network rules; the agent CLI installed in the image; terminals and previews reaching into the VM; start time and memory per chat. The lighter step first may be the agents' own sandboxes (Claude Code's Bash sandbox, Codex's `--sandbox`) exposed as a chat option.
- **More agents**: opencode (`opencode acp`), Gemini CLI (`gemini --acp`), goose (`goose acp`); each a `Harness` type and its own `internal/<agent>*` packages, reading its own keys.
- **Skills, next**: browsing and installing from marketplaces (`claude plugin list --available --json`, `install`), Codex's and omp's plugins' skills, Pi's and PiG's nested skills, a Reload offer after a skill change, omp's project switch (`.omp/config.yml`), New skill… linking for Claude once written (it says to use Link for Claude…), Claude's own `/skills` numbers when a chat runs (`get_skills_dialog` over the adapter, if it exposes one).
- **Per agent**: Claude's subagents' steps from session/load (their sessions replay them since 2026-10-27; dropped while the merge isn't made for them, though a chat without a copy could show them). Codex's MCP servers in the MCP view, its background terminals and subagent sessions. Ante's subagents, background jobs, `Info` notices (and its other TUI commands: `/goal` and `/rename` have ops), native `RewindSession` (upstream `ante-acp` could take the bridge's mapping). omp's `/context`, MCP servers on `session/new`, deleting its sessions. Pi's and PiG's MCP servers in the MCP view, a replayed message's images, an empty reopen (`--session-id`), `PIG_USE_PI_DIRS=1`, telling a session open in a terminal. Opening sessions started elsewhere: Ante's forks, a search, other worktrees' sessions.

### The phone

- **Mobile, next**: an `Events` filter for cellular; tool output and diffs fetched on expanding them (the API would need an item's own call); renaming the device after pairing; a native iOS app with the Keychain and Face ID if the developer program ever works out.

## Decisions to revisit

- **Findings from review bots' Markdown** (PR redesign, 2026-10-29): opt-in, and a guess at the common shapes (the owner: "really cool but it only works for our setup"). If bots start posting structured review comments (threads, or a check's annotations), read those instead.
- **A review comment as a card while it's written**: left of the UX review's idea. Comments in Changes are kept apart (`reviews.json`) and become cards only on Send to agent; the idea was one store for both.
- **A finding's path** is taken as relative to the chat's folder, though Claude's schema says relative to the repository: a chat in a subfolder misses files outside it, and an absolute path in the worktree but outside the chat's folder isn't opened.
- **Artifact pins on the phone**: pins are in the Mac's `app.json`, which the phone can't reach. Kept by the daemon, as a chat's pins are (ADR 0064), the phone could show them.
- **Sessions the agent deleted** ([ADR 0015](adr/0015-delete-takes-the-agents-history.md)), what the check doesn't cover: another `CLAUDE_CONFIG_DIR` whose project folder for the path exists (it can't tell the configs apart), Ante and omp (their errors weren't looked at), a message typed into a chat that then goes (lost with it).
- **Tried only on some agents**: the transcript merge ([ADR 0047](adr/0047-nushis-copy-of-transcripts.md)) was tried by hand only with Claude's and the fake agent's replays; Codex, Ante, omp, Pi and PiG go through it untried. The real PiG, omp and Ante were run only for the facts, not against Nushi's skill switches.
- **`sandbox-exec`** is deprecated but works on macOS 27; finding and setting up agents rely on it.
- **Settings' Remote access** is the remote widget unchanged (its own heading under the page's) until it's redone in rows.
- **Not reproduced, so not closed**: Reload's brief duplicate message (2026-10-31: `reload_test.go` holds each item once; if it's still seen, look at what the app draws), and ? boxes for Nerd Font icons in Settings' terminal preview (how to check is under `[controls]` in the archive).
