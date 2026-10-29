# Chats

A chat is a conversation with one agent, in one folder. This page covers the window, the chats in it, and what they show. Which agents there are, and how to set them up, is in [Agents](agent-setup.md).

## The window

- **First run.** With no chat open, the pane offers New chat, Open a folder…, and the recent folders: the chats' folders, or before there are any, the folders Claude's sessions were found in. Each starts a new chat there.
- **The sidebar** lists Pinned, then the projects and their chats. Its foot has Jira, GitHub and Settings.
- **Settings** (⌘,) takes the chat's place beside the sidebar, its sections in a list on the left. Esc or Close goes back ([ADR 0053](adr/0053-settings-is-a-view.md)). Settings › General's Appearance (Light, Dark, or as the system; also in the View menu) is remembered.
- **Tabs.** A chat opens on the tab it was left on (Chat, Changes, Pull request), and on Chat when it needs you.
- **Trust.** Before an agent starts in a folder that brings code of its own (hooks, MCP servers, extensions), a trust card shows that code. Going elsewhere while it asks is a no, and a bar over the app says what didn't start ("Didn't start Claude in site: its code wasn't approved.").
- **The status bar**, along the window's bottom, counts working, awake and sleeping agents and shows the memory Nushi takes. A click lists each awake chat's.

## Starting and arranging chats

**New chat** (⌘N, or a folder's +) asks which agent to run, with the one used last picked; Enter starts it.

- A chat keeps its agent, and shows its mark in the sidebar ([where the marks come from](user/agent-marks.md)).
- It keeps the model, effort and other options you pick under the box, after it sleeps or the daemon restarts.
- A new chat starts on the options last picked for its agent (where it still offers them), in the mode last picked.

**Order.** Drag a chat within its project to reorder it; a new chat goes to the top. Drag a project by its header. A project's chevron collapses it.

**Pins.** Pin a chat with ⌘D (Chat › Pin Chat, its ⋯, its row's right-click, or the palette) and it moves to Pinned, above the projects, with its project's name beside it.

- Drag pinned chats to reorder them.
- Unpin puts a chat back where it was in its project.
- The daemon keeps the pins, so the phone has them too. Archiving unpins.

## Keys

| Keys | What they do |
|---|---|
| ⌘1 – ⌘9 | Open one of the first nine chats. Hold ⌘ and the sidebar numbers them, top to bottom, Pinned first, archived left out. |
| ⌘[ and ⌘] | The chat before or after (View › Previous Chat, Next Chat). |
| ⌃Tab, ⌃⇧Tab | Go through Chat, Changes and Pull request (when the chat has one). |
| ⌃⌘1, ⌃⌘2, ⌃⌘3 | Show Chat, Changes or Pull Request (View menu). |
| ⌘K, ⌘⇧P | The command palette. |
| ⌘F | Find. |
| ⌘P | Open file. |
| Esc | Stop a running turn. |
| Esc Esc | Rewind: list your messages. |

The chat keys work in a terminal too.

## The palette

⌘K (View › Command Palette…) opens the palette. In a terminal ⌘K clears it, so use ⌘⇧P there, which works everywhere.

- **Go to a chat** by its title: the pinned first, then the last opened. Archived chats are listed last, marked.
- **Run an action**: New chat, Open file…, Artifacts…, Chat, Changes, Pull request, show or hide the details and the terminal, Rewind…; the chat's own: Side question, Send review comments, Stop, Rename, Pin or Unpin, Sleep, Reload, Link pull request…, Archive or Unarchive, MCP servers, Skills, Delete…; and Settings, Jira, GitHub, Restart daemon.

Rows match as you type, each with its key. Actions that don't apply now are left out, and what you picked lately comes first.

**Side question** (⇧⌘B) opens a fork of the chat beside it. It knows the conversation and doesn't add to it.

The chat's own actions are also in the menu bar's Chat menu, its ⋯ menu, and its sidebar row's right-click.

## Find

⌘F (View › Find…) finds in what's showing:

- **In the chat**, the messages and tool rows with the text are marked. ⏎ and ⇧⏎ go through them; Esc closes.
- **In Changes**, it keeps the files with the text in their path or either side.
- **In a focused terminal**, it finds in its scrollback.

## Rewind

A chat whose agent can rewind goes back to just before one of your messages. Rewind forgets everything from that message on and puts the message back in the box. Files aren't rewound.

- Rewind shows on a message under the pointer, and in its right-click menu.
- Esc twice quickly in the box lists your messages, newest first, with when each was sent. Type to filter; ↑↓ and ⏎ (or a click) rewind at once.
- A single Esc stops a running turn. A turn must stop before a rewind.

## Changes and review comments

**Changes**, beside Chat, is the chat's diff viewer: its folder's uncommitted changes, or its branch's for a worktree chat (Uncommitted, Branch and Commits pick which). It only reads: Nushi doesn't stage, commit or push ([ADR 0019](adr/0019-changes-read-only-toward-git.md)).

- Select lines to write a review comment for the agent.
- **Send to agent** puts the comments into the chat's box as reply cards, to send with your next message.
- Comments not sent yet show in the header ("Changes 2") and over the box, with Send to agent and Show.

## Previews and artifacts

A file a chat's agent (or one of its subagents) wrote previews beside the chat, kept current as it changes:

- **Markdown**, rendered;
- **images**;
- **HTML pages and SVG** in a web view: the CSS, scripts and images beside them load, and the network too. A link out opens in your browser. Reload, and Open in browser;
- **PDF**;
- **CSV** as a table (its first 500 rows);
- **code and text** (JSON, YAML, logs, source files) as their source, highlighted.

Markdown, HTML, SVG and CSV have Preview and Source.

**Artifacts** are the files made to be looked at: everything but code and text, which Changes shows. Open one from:

- its tool row's Preview;
- the Artifacts widget in the details panel, the open one marked. The palette's Artifacts… shows the panel and the widget, or lists them in a window too narrow for the panel;
- the preview's own name.

Each list shows the files the chat wrote that way, each with its folder and when it changed, in the same order:

1. those you pinned (the pin shows when the pointer is over a row; pins are kept per chat);
2. the recent: what the agent wrote in the last turn, the file open now, and those you opened in the last hour, newest first;
3. the rest, folded under "Older (n)".

The widget, collapsed, counts the pinned and recent; with none of either, the three newest show. The phone's Artifacts list the same way, without pins.

**Open file** (⌘P, File › Open File…) opens any file that previews (code and text too) in the chat's folder that git doesn't ignore, matched as you type.

**Paths in messages.** A path in an agent's message, in code or plain text (`lib/a.dart:12` too), that names a file that previews, in the chat's folder or one the chat wrote, opens it too. It's underlined when the pointer is over it; on the phone it opens the full-screen preview.

### Mermaid diagrams

Mermaid diagrams draw where they appear:

- A `.mmd` or `.mermaid` file previews as its diagram, with Preview and Source.
- A ```` ```mermaid ```` block in an agent's message or a Markdown preview shows as the diagram, with Diagram and Source in its bar. It's drawn once complete; one that doesn't parse shows its source and the error.
- On the phone a file's diagram shows full screen, and a message's block has Show diagram.

Mermaid comes with Nushi (`make mermaid` fetches the pinned copy at build time), never from the network.

## Worktrees

A chat in a git repository can run in a worktree of its own, `.worktrees/<two words>`, on a new branch `nushi/<two words>` ([ADR 0016](adr/0016-a-worktree-per-chat.md)).

- **New worktree**, under the box of a chat without messages, starts one. The details panel's Worktree row does too, and also moves a chat to the repository's other worktrees. This is per chat: every new chat starts in the folder itself.
- **The branch's name.** Once a turn ends with the chat titled, the branch is named after the chat (`nushi/bump-go-1-27-3`), unless it was pushed or renamed. A quiet line in the transcript says so. The folder keeps its name.
- **Rename branch…** (the pencil beside the branch in the details panel) names it yourself, between turns.
- **The agent is told** with your next message, in a sentence of Nushi's before yours (`[Nushi] This worktree's branch was renamed from … to …. Use the new name.`), and the line then says "· told the agent". The agent's history keeps that sentence as part of your message, so a terminal resume shows it.

## Terminals

⌃\` (or the terminal button in the chat's header) shows the chat's terminals, in tabs under it, in the chat's folder ([ADR 0022](adr/0022-the-daemon-owns-terminals.md)).

- The daemon owns them, so they keep running when the app quits and reopens. A daemon restart ends them.
- The shell is your login shell. Archiving or deleting the chat closes its terminals.
- ⌘T opens another, ⌘W closes one, ⌥⌘1 – ⌥⌘9 pick one, and ⌘F finds in its scrollback.

## Sleep

A chat whose agent isn't needed can sleep: its agent stops, the chat stays, and the next message wakes it (`session/load`). Chats sleep on their own after 30 idle minutes when nothing would be lost (Settings changes the time), or from a chat's menu ([ADR 0032](adr/0032-idle-chats-sleep.md)).

## History

A chat's history is its agent's: a chat reopens from the agent's session, and resumes in a terminal from it.

**Nushi's copy.** Nushi also keeps its own read-only copy of each chat's transcript as it was shown, for what the agent no longer replays (Settings › Chat history, on by default; [ADR 0047](adr/0047-nushis-copy-of-transcripts.md)). The copy is never sent to the agent.

- After `/compact` (or Claude compacting on its own), Claude replays only what follows. A reopened chat shows the earlier part from the copy, with "Compacted here" where Claude's history starts again; a click shows the summary Claude kept.
- If the session changed elsewhere (rewound or edited in a terminal), Claude's version shows from where they differ, after a divider.

**Settings › Chat history** lists every chat's copy in a table: title, folder, agent, size, last used.

- Sort by size, last used or title; search by title and folder.
- Filter to archived chats, those whose agent no longer has them, or deleted chats' leftovers.
- Clear one (a row's Clear), those picked (click, ⇧-click a range, ⌘-click), or all; or have them cleared on their own after 30, 90 or 365 days.
- A row's title opens its chat.
- Turning the copies off asks whether to keep or delete the ones there are.

**Sessions the agent deleted.** Claude Code deletes sessions older than `cleanupPeriodDays` (30 days by default, in Claude's settings) when it starts ([ADR 0015](adr/0015-delete-takes-the-agents-history.md)).

- A chat with a copy stays, read-only. Its transcript is the copy, with Delete… and Start a new chat here (in its folder).
- A chat without one is forgotten, when you open it or when Nushi finds the session's file gone from Claude's history (at most hourly, starting nothing). The app says once which chats went.
- Nothing else is touched: a worktree and its branch stay. A chat whose worktree has uncommitted changes or commits stays too, saying Claude no longer has its session, with Delete… to deal with the worktree.
- A Codex session you archived isn't gone: run `codex unarchive <id>`, then Try again.

## Notifications

The Mac notifies you, in the phone's words, with the chat's title under each:

- when a chat needs you ("Claude needs you", "Claude has a question");
- when a turn ends ("Claude finished", 2 s after; none if the agent goes straight on or you stopped it);
- when a turn fails.

The Dock icon counts the chats that need you.

- A notification shows while Nushi isn't the app in front, or for a chat other than the one showing.
- A click opens its chat, and showing the chat clears its notifications. A "needs you" goes once the chat no longer does.
- A prompt or question ends "cancelled" when its agent stops (sleep, a crash, the daemon's restart): the agent can't take an answer then. It asks again, with a new card, if it still wants one.
- macOS asks to allow them on the first one. Settings › General › Notifications turns each kind, the sound (off at first) and the badge on or off.

Nothing leaves the Mac.
