# 0068. An agent opens a preview with a `show` tool, which its harness asks about

Status: accepted, 2026-10-31.

## Context
The owner wants what Claude Code's artifacts give: the agent finishes a page or a document and it appears beside the chat. Until now a file opened in the preview only from a click: a tool row's Preview, Artifacts, a link in a message, ⌘P. On the Mac a preview of HTML or SVG runs the page, scripts and network on (NOTES.md's Security notes), so that click was the one thing standing before an agent's page running.

## Decision
- **A tool set for every chat that can take one** (`internal/features/preview`, `show` with one argument, `path`), on Nushi's MCP server ([0043](0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md)). Claude and Codex get it (`chats.Kind.ClientMCP`, in `knownagents`); Ante, oh-my-pi and PiG take no client MCP servers, so they get no server at all. This amends 0043's "a chat without an issue gets no server".
- **Nushi doesn't allow it; the harness asks.** With opening now a page's way to run unclicked, the harness's ask is the gate, so nothing weakens it: no allow rule, and the tool lists no annotations (a `readOnlyHint` could let a harness skip the ask). The card names the file and says a page runs (the daemon keeps a show call's input on its permission item: the raw tool name alone says nothing). What the user tells the harness stands: Bypass permissions, or "don't ask again" on the card, opens pages unasked.
- **The same files as a tool row's Preview, so the two can't disagree.** `filewatch.Allowed` is the check, shared with `WatchChatFile` and `FindChatFiles`: inside the chat's folder or worktree, or a file `chats.Service.Wrote` says a tool call worked on. A show call itself never counts as that. The types are the artifacts: Go's `filewatch.Artifact` and the app's `artifactKinds` are two tables (the app needs its own answer offline), and both sides' tests read one list. `filewatch.Check` refuses what isn't a regular file reached, links followed, without leaving the folder.
- **What the agent sends is bounded and stays out of the log.** A path of at most 4096 bytes, no NUL. A refusal is a tool error of fixed text naming the reason, so the agent can correct itself; `tools.Service` logs a tool's error, so it never carries the path. The answer says the pane has the file and nothing of what's in it.
- **The daemon tells the clients; only the Mac acts.** The `show` event (API 95) carries the chat and the path as the agent named it, the same string as its row's input. It has no seq: it's a nudge, not transcript.
- **The agent never moves the user.** The app keeps the latest ask per chat (`ChatState.showAsked`, in memory). The chat's pane opens it while its Chat tab shows, at once if that's now, and forgets it. Another chat, Settings, Jira, GitHub, the trust card or the Changes tab leave it waiting; a later ask replaces it, a rewind forgets it, and the chat opens it the next time its transcript shows. An app that wasn't running or connected never heard the ask.
- **The tool row reads as a preview** ("Showed report.html"), and keeps Preview once the call completed, a call waiting to be allowed or refused offering none. That's the way back to the file at any time, and the phone's only way: it never jumps to full screen on its own.

## Consequences
- A side chat is a fork of the chat's session and gets the chat's server (its key, its chat): its show opens beside the chat, under the chat's check, so a file only the side chat wrote outside the folder is refused. Subagents share their harness's tools, and their writes count in `Wrote`.
- The preview's limits stay: the 5 MB cap for what the daemon sends, a web view's read access, no bridge from the page to Nushi. A file over the cap shows as it would from a click.
- `Wrote` counts any tool call's locations, reads and refused calls too, so "wrote" is wider than it says: an agent can show an HTML file it only read outside the folder, if the harness allows it. Tightening it belongs to `Wrote`, for both paths.
- In a window too narrow for the pane beside the transcript, the pane doesn't open by itself: it would lie over the box and any card waiting (`Beside`). The row's Preview still opens it.
- An extra `nushid tools-mcp` per Claude or Codex session, and MCP instructions of a sentence in each.
- The app's title match (`mcp__nushi__show`, `mcp.nushi.show`) is the adapters' to change; a changed title shows a plain MCP row with no Preview.

## Alternatives considered
- Nushi auto-allowing the tool, or asking itself: the first removes the only gate, the second is a permission of Nushi's own (ADR 0007).
- The event opening the file wherever the user is: an agent would take the window from whoever's reading.
- A per-chat "latest show" kept by the daemon: durable, but more state for what the row's Preview already covers.
- Replaying the ask from the transcript when a chat opens: an old call would reopen a file on every visit.
