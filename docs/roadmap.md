# Roadmap

What isn't built yet and the decisions still open, each checked against the code on 2026-10-31. An entry goes when its work ships, in the same commit, and a gap is checked against the code before it's written down ([AGENTS.md](../AGENTS.md)). What's built is in the user docs, why in [`docs/adr/`](adr/README.md), October's small decisions in [`history/decisions-2026-10.md`](history/decisions-2026-10.md).

## Plans

### The app

- **The empty state as a visualisation** (the owner, 2026-10-26): a gravity toy (an orrery in the empty pane) didn't look good enough and was reverted. Revisit with a fresh agent and stronger visual references (the owner has seen better ones); a prototype in an HTML artifact first, before any Flutter.
- **A redesign** (the owner, 2026-10-26): a fresh look at the whole app, not piecemeal fixes. Scope it with the owner first: what feels wrong, and which apps' look to learn from.
- **Linux and Windows** (the owner, 2026-10-27): the Flutter UI and most of the daemon are portable. What's macOS-only: the keychain (`internal/keychain`, cgo: libsecret / Windows Credential Manager), read-only runs through `sandbox-exec` (`internal/readonly`: Landlock or bubblewrap on Linux, nothing equal on Windows), launchd for Start at login (systemd user units / a Run key), the process footprint (`proc_info`: `/proc`), the app's Swift method channels (the installed fonts list), `app/linux` and `app/windows` runners, packaging. Windows also: ConPTY for terminals, AF_UNIX sockets (supported), paths and shells, and which agents' CLIs run there. Linux first.
- **A lazy transcript**, for long chats' speed and memory (ADR 0026: it fills in from the bottom over a few frames, but all of it is laid out once there; a lazy list needs known heights).
- **The subagent pane dragged wider** (the owner, 2026-10-27): it stops at 480 unless Wider is on, which the owner didn't find at first. Let the drag go up to the transcript's least (`cap` in `chat_view.dart`'s `_beside`); Wider stays as the one-click jump.
- **The side chat as Claude Code's** (the owner, 2026-10-29, from Claude Code's desktop app): there, Side chat is a pane of its own in the right-hand column (⌘;, from a ⋯ menu that also toggles Artifacts, Background tasks and Plan), with a tab and a short line saying what it is ("Chat about this session without touching the main thread … nothing here is added to the session"). Ours (⇧⌘B) lasts while hidden but opens apart from the details column, and says only "Ask in the side chat". Missing: a place in the details column, its empty state's line, and a look at the shortcut.
- **Find, next**: finding inside the shown diff (Changes' ⌘F only filters the file list), and the phone's find through the daemon's pages (the phone has no find).
- **Plain model chat** with no agent, straight to an API or gateway with a key (Nushi would own the history). Agent chats already reach a gateway through Claude's own settings (`ANTHROPIC_BASE_URL`, `apiKeyHelper`).
- **Usage limits** (session and weekly) for subscription users, if an agent exposes them; nothing shows them. claude-agent-acp 0.94.0 once put `_meta._claude/rateLimit` on a `usage_update` (`docs/facts/claude.md`), not a stable interface; the Go agent passes claude's the same way and nothing reads it.

### Previews

- **A Files view's rest** (the owner, 2026-10-27; the use case is seeing what the agent made, like Claude Code's artifacts): missing are a file tree of the chat's folder to open any file, and the web view's hardening past WebKit's free defaults. The owner trusts what the agent writes as much as a page they'd open in a browser (2026-10-28), so the network stays on, no switch. Read-only (editing beside a writing agent: ADR 0019's reasons). Mocks: https://claude.ai/artifact/TP8YD5rSCSi2L28hnsdPGP (the owner liked them).

### Changes and review

- **Review comments by an agent** (from JetBrains AIR): a side chat reviews the changes and posts comments through a small MCP tool (`add_comment(file, line, text)`); they show in Changes, and those picked go to the main chat.
- **Findings, picked** (after a finding opened the chat's Changes at its line, 2026-10-26): tick a review's findings in its card and send them back to the agent ("fix these"), or show them as comments in Changes. Each finding already has a stable id (`findingIds`: its file, line and summary).
- **Git actions** from Changes (stage, commit, maybe push): revisits [ADR 0019](adr/0019-changes-read-only-toward-git.md) (git writes beside an agent that may be writing).

### GitHub

- **Merge controls**, from the Pull request widget or tab (Orca has them; [ADR 0059](adr/0059-a-chats-pull-request.md)): the repository's methods, auto-merge, the merge queue.
- **A found pull request's chip** in the chat's header: the header's chip shows only the pull request or issue a chat started from; a found one gets just its tab.
- **The agent's own GitHub tools** on Nushi's MCP server ([ADR 0043](adr/0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md)): a `tools.Set` scoped to the chat's pull request, as Jira's chats have for their issue.
- **GitHub, next**: stacked pull requests, notifications as a source (If-Modified-Since, X-Poll-Interval), reactions, files marked viewed, Enterprise capabilities probed, a review's inline comments kept across app restarts (quitting loses them).

### Jira

- **Jira, next**: a Data Center client (v2, wiki markup, personal tokens) behind `features/jira.Client`; review-comment tools on the same MCP server; creating issues, assigning, worklogs, remote links for a chat's PR, a "plan only" mode; `/jql/parse`; counts on the tabs; change badges from `changelog/bulkfetch`; Rovo MCP's OAuth; the token's expiry from the admin API.

### Agents

- **Claude without Node** (the owner, 2026-10-29): the Go agent (`claudeagent`, `claudeacp`, [ADR 0066](adr/0066-claude-through-nushis-go-agent.md)) is in, off by default; claude-agent-acp 0.94.0 is about a third of a Claude chat's memory, and the npm setup step. Missing: the default flipped once ADR 0066's conditions hold, then Claude's Set up gone; the two packages published as repositories of their own, after checking Anthropic's terms on tools built on the Agent SDK with a subscription login. Codex later, against `codex app-server --stdio`; omp needs Bun regardless. Smaller: codex-acp's `CODEX_PATH` could name the native binary past npm's 14 MB launcher (`docs/history/perf-2026-10.md`).
- **More agents**: opencode (`opencode acp`), Gemini CLI (`gemini --acp`), goose (`goose acp`); each a `chats.Kind` and its own `internal/<agent>*` packages, reading its own keys.
- **Skills, next**: browsing and installing from marketplaces (`claude plugin list --available --json`, `install`), Codex's and omp's plugins' skills, PiG's nested skills, a Reload offer after a skill change, omp's project switch (`.omp/config.yml`), New skill… linking for Claude once written (it says to use Link for Claude…), Claude's own `/skills` numbers when a chat runs (`get_skills_dialog` over the adapter, if it exposes one).
- **Per agent**: Claude's subagents' steps from session/load (their sessions replay them since 2026-10-27; dropped while the merge isn't made for them, though a chat without a copy could show them). Codex's MCP servers in the MCP view, its background terminals and subagent sessions. Ante's subagents, background jobs, `Info` notices (and its other TUI commands: `/goal` and `/rename` have ops), native `RewindSession` (upstream `ante-acp` could take the bridge's mapping). omp's `/context`, MCP servers on `session/new`, deleting its sessions. PiG's MCP servers in the MCP view, a replayed message's images, an empty reopen (`--session-id`), `PIG_USE_PI_DIRS=1`, telling a session open in a terminal. Opening sessions started elsewhere: Ante's forks, a search, other worktrees' sessions.

### The phone

- **Mobile, next**: an `Events` filter for cellular; tool output and diffs fetched on expanding them (the API would need an item's own call); renaming the device after pairing; a native iOS app with the Keychain and Face ID if the developer program ever works out.

## Decisions to revisit

- **Findings from review bots' Markdown** (PR redesign, 2026-10-29): opt-in, and a guess at the common shapes (the owner: "really cool but it only works for our setup"). If bots start posting structured review comments (threads, or a check's annotations), read those instead.
- **A review comment as a card while it's written**: left of the UX review's idea. Comments in Changes are kept apart (`reviews.json`) and become cards only on Send to agent; the idea was one store for both.
- **A finding's path** is taken as relative to the chat's folder, though Claude's schema says relative to the repository: a chat in a subfolder misses files outside it, and an absolute path in the worktree but outside the chat's folder isn't opened.
- **Artifact pins on the phone**: pins are in the Mac's `app.json`, which the phone can't reach. Kept by the daemon, as a chat's pins are (ADR 0064), the phone could show them.
- **Sessions the agent deleted** ([ADR 0015](adr/0015-delete-takes-the-agents-history.md)), what the check doesn't cover: another `CLAUDE_CONFIG_DIR` whose project folder for the path exists (it can't tell the configs apart), Ante and omp (their errors weren't looked at), a message typed into a chat that then goes (lost with it).
- **Tried only on some agents**: the transcript merge ([ADR 0047](adr/0047-nushis-copy-of-transcripts.md)) was tried by hand only with Claude's and the fake agent's replays; Codex, Ante, omp and PiG go through it untried. The real PiG, omp and Ante were run only for the facts, not against Nushi's skill switches.
- **`sandbox-exec`** is deprecated but works on macOS 27; finding and setting up agents rely on it.
- **Settings' Remote access** is the remote widget unchanged (its own heading under the page's) until it's redone in rows.
- **Not reproduced, so not closed**: Reload's brief duplicate message (2026-10-31: `reload_test.go` holds each item once; if it's still seen, look at what the app draws), and ? boxes for Nerd Font icons in Settings' terminal preview (how to check is under `[controls]` in the archive).
