# Glossary

Nushi's words, defined once. The UI, the code and the docs use them; a new user-facing term goes here first. Each row: the term as the UI says it, what it means, the code's name when it differs, and the ADR that decided it.

## Chats and agents

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Agent** | A coding agent Nushi runs: Claude, Codex, Ante, Pi, PiG, oh-my-pi or OpenCode, each your own CLI with its own login, settings and history. | `features/agents`, proto `Agent` | 0037 |
| **Harness** | The agent's own program and rules (Claude Code, Codex…). Not in the UI, which says agent. It owns permissions and history. | `chats.Harness`, `claude.Harness`… | 0007, 0008, 0077 |
| **Adapter** | The ACP program Nushi sets up for an agent that needs one (Codex's; Claude's until 2026-11-04), from Nushi's own lockfile, into the data folder. Set up, Update, Remove. | `Adapter`, `SetUpAgent`, `internal/codex/adapter` | 0037 |
| **Bridge** | Nushi's own ACP translator for an agent without ACP: `nushid ante-acp`, `nushid pi-acp`, `nushid pig-acp`. | `internal/ante`, `internal/pi` | 0030, 0039, 0078 |
| **Go agent** | Nushi's own ACP agent for Claude, run on your `claude` for every Claude chat, with no Node and nothing to set up. | `claudeacp`, `nushid claude-acp` | 0066 |
| **ACP** | The Agent Client Protocol, how the daemon talks to agents. | `github.com/afrase/acp-go` | 0041 |
| **Chat** | A conversation with an agent as Nushi shows it: the agent's session plus what Nushi keeps (title, folder, worktree, picks). | `model.ChatRecord` (the record), `model.Chat` (a snapshot), proto `Chat` | 0008 |
| **Session** | The agent's own record of a conversation, which it keeps and resumes. A chat is on one at a time; a move or a rewind starts another. | `SessionID`, `AgentSession`, ACP `session/*` | 0008 |
| **Session started elsewhere** | A session begun in a terminal, opened as a chat from New chat's Sessions →. | `ListAgentSessions`, `OpenAgentSession`, `FoundSession` | 0035 |
| **Turn** | One message and everything the agent does for it, until it ends. Stop (Esc) ends it. | `ChatStatus.busy`, `CancelTurn` | 0044 |
| **Turn's end** | How the daemon judged a turn as it ended: done (the agent ended it), failed (an error, or the agent quit or crashed mid-turn) or stopped (you, or Nushi stopping the agent). Notifications, pushes and the receipt go by it. | `model.TurnEnd`, `ChatStatus.ended`, `ChatState.ended` | 0054 |
| **Message** | What you send: text, mentioned and attached files, images. | `model.Message`, `SendPrompt`, `UserMessage` | |
| **Prompt** | ACP's word for a message to the agent. The UI says message, and prompt only in "permission prompt". | `SendPrompt` | |
| **Item** | One entry of the transcript: a message, thought, tool call, permission prompt, question, plan or notice. Code only; prose says entry or names the kind. | `model.Item`, `ItemKind` | 0026 |
| **Tool call** | The agent's use of a tool (read, edit, run…), shown as a **tool row**: one line on a card's fill, its icon in the tools' color (red once it failed), a spinner at its end while it runs; open, its output on code's surface. | `ToolCall` item, `ToolCallView` | |
| **Run** | Tool rows in a row, folded into one line: "Read 4 files, running make test", with what its edits added and removed; open, a card of its calls' rows. | `RunView`, `RunLine` | |
| **Thought** | The agent's thinking: "Thinking…", then "Thought for 12s". | `Thought`, `ThoughtLine` | |
| **Plan** | The agent's checklist on a card, updated in place: "Plan · 2 of 5 done", and that count as a thin bar. | `Plan`, `PlanEntry`, `plan_view.dart` | |
| **Notice** | A quiet line in the transcript: how a turn ended when it didn't end well, or a note of the agent's own ("Stopped by safeguards", "Compacted here"). | `Notice`, `AgentNotice` | |
| **Permission prompt** | The agent asking to run a tool call, with its options (Allow, Deny…). You answer; Nushi never does. | `Permission` item, `PermissionCard`, `AnswerPermission` | 0007 |
| **Question** | A form the agent asks you to fill in (Claude's AskUserQuestion), as a question card. | `Question` item, `Field`, `QuestionCard`, `AnswerQuestion` | 0009 |
| **Needs you** | The chat waits on you: a permission prompt or a question. Amber dot, Dock badge, "Needs you ↓". | `waiting` (`ChatStatus`, `ChatPhase`), `WaitingCard` | |
| **Chat states** | A chat's dot and word: needs you, working, in background, done, asleep, idle, new, expired, couldn't start, archived. | `ChatPhase`, `phaseWord` | |
| **Done** | A turn ended, done or failed, while nothing showed the chat; showing it clears it. | `ChatRecord.Done`, proto `Chat.done`, `ChatState.done`, `ChatPhase.done` | |
| **Subagent** | A helper the agent starts for a task ("Explore: find the scroll handling"). Its steps show in its row and its pane; it can be stopped alone, if its agent has a way (Ante's stops only with the turn). | `Subagent`, `Item.Agent`, `SubagentPane` | 0044 |
| **Message to a subagent** | A message you write to a running subagent; the agent passes it on ("To Explore, through Claude"). | `model.ToSubagent`, `Item.ToSubagentName`, `claude/subagents.go`, `to_subagent.go`, proto `to_subagent`, `to_subagent_name`, `Draft.toSubagent` | |
| **Background task** | A subagent or command still running after the turn that started it ended. The Background tasks widget lists them, each with a Stop, and keeps those that finished, to open again. | `ChatStatus.background`, `StopTask` | 0044 |
| **Background command** | A command the agent left running in the background, its output in a pane. | `BackgroundCommand` (Go and proto), `background_commands.dart`, `BackgroundCommandPane`, `Item.TaskID`, `background.go` | |
| **Queue** | Messages sent while a turn runs (⏎, or the box's Queue button). Each goes at the agent's next chance: into the running turn when the agent takes steering, else as the next message. Shown as pills over the box. | `QueuedMessage`, `ChatQueue`, `SendPrompt.queue`, `Unqueue`, `QueuePills` | |
| **Stop and send** | ⌘⏎ while a turn runs, or the box's Stop and send button: stops the turn and sends the message at once, which starts a new turn. Not steering, which is what Queue does (Synonyms). | `SendPrompt.now` | |
| **Side chat** | A fork of the chat, beside it, that knows the conversation but doesn't add to it; you can go back and forth in it, as in Claude Code's side chat. It ends when closed (×), unless kept (Keep as chat: it becomes a fork in the sidebar); ⇧⌘B hides and shows it. | `ForkChat`, `CloseSideChat`, `KeepSideChat`, `sides.go`, `side_chat.dart`, `Daemon.openSide` | 0067 |
| **Fork** | A new chat from this one's conversation, all of it (Fork chat) or up to one of the agent's messages (Fork from here), going on separately: same agent, folder and worktree, picks, title marked "(fork)". The original is untouched. | `ForkAsChat`, `Item.forkable`, `forks.go`, `fork_chat.dart` | 0067 |
| **Pinned message** | One of the agent's messages marked with a pin (Pin, Unpin among its actions), listed by its title in the rail's menu, which goes to it; the daemon keeps them and their titles, so the phone lists them too. Not a pinned chat. | `Chat.pinned_messages`, `Chat.message_pins`, `ChatRecord.Pins`, `MessagePin`, `PinMessage`, `message_pins.dart` | 0085 |
| **Pins rail** | The dashes in the transcript's left margin at its top while a chat has pinned messages: Session start and each pin, the current one long and bright; pointing at it opens its menu. | `Rail` (`rail.dart`, `rail_dashes.dart`, `rail_menu.dart`), `message_pins.dart` | 0085 |
| **Rewind** | Go back to just before one of your messages: the session forks there and the message returns to the box. Files aren't rewound. Esc Esc lists them. | `RewindChat`, `Item.ForkAt`, `Rewindable` | 0020 |
| **Sleep** | An idle chat's agent stops; the chat stays and the next message wakes it. On its own after 30 idle minutes. The chat is then asleep. | `SleepChat`, `ChatStatus.asleep` | 0032 |
| **Archive** | Put a chat away: its agent stops, it's read-only and listed last. Unarchive reopens it. | `ArchiveChat`, `ChatRecord.Archived` | |
| **Reload** | Restart the chat's agent on its session, to pick up changed MCP servers. | `ReloadChat` | |
| **Move** | The chat goes on in another folder or worktree; its session forks there. | `MoveChat` | 0014 |
| **Delete** | Remove a chat, the agent's history of it, and its worktree and branch if you say so. | `PlanDeleteChat`, `DeleteChat` | 0015 |
| **Expired** | A chat whose agent deleted its session: read-only, on Nushi's copy, with Start a new chat here. | `session_gone`, `RemovedChat` | 0015, 0047 |
| **Transcript** | The conversation as shown: your messages as bubbles (bands on the phone), tool rows, subagents, plans. | `transcript.dart`, `items.dart` | 0026 |
| **Earlier messages** | The part of a long chat before what's loaded: it comes a page at a time as you scroll up, under a spinner ("Couldn't load earlier messages · Try again" when it fails). What's loaded first is the **recent part**. | `ChatState.older`, `Daemon.loadOlder`, `EarlierMessages`, `GetChatRequest.recent`, `GetChatItems` | 0026 |
| **Nushi's copy** | Nushi's own read-only copy of each transcript as shown, for what the agent no longer replays. Settings › Chat history. | `internal/transcripts`, `TranscriptCopy` | 0047 |
| **Mode** | The agent's own permission mode (Auto, Plan…): the only permission control. The picker on the left under the box. | `ConfigOption` category `mode`, `ChatRecord.Mode` | 0007 |
| **Model**, **Effort** | The model the agent runs and how hard it thinks; the model menu under the box (Effort ▸, More models ▸). | `ConfigOption` categories `model`, `thought_level` | 0060 |
| **Picks** | The options you chose for a chat, put back whenever its session opens; an agent's last picks start its new chats. | `ChatRecord.Picks` | 0060 |
| **Ultracode** | Claude Code's standing multi-agent workflows for a chat; in ⋯ under the box, off by default. | `ChatRecord.Ultracode`, `ultracodeID` | |
| **Fast** | Claude's fast mode: one of the agent's options in ⋯ under the box, named as the agent names it. | `ConfigOption` id `fast` | |
| **Slash command** | One of the agent's `/` commands, completed in the box. A few are Nushi's: `/copy` the app answers, and Claude's `/plan`, which Claude refuses outside its terminal, the daemon runs in its place. | `Command`, `ChatCommands`, `TerminalCommands`, `OptionCommand`, `SendPromptResponse.ran_command` | 0075, 0088 |
| **Context** | What fills the agent's context window, broken down in the Context widget. | `GetContextUsage`, `ContextUsage` | 0017 |
| **Findings** | A code review's result (`/code-review`), as a card in the transcript. | `Findings`, `Finding`, `FindingsCard` | |
| **Trust card** | Before an agent starts in a folder that brings code of its own (hooks, MCP servers, extensions), it lists that code; Start anyway goes on. | `features/trust`, `CheckFolder`, `TrustFolder`, `FolderRun`, `TrustCard` | 0023, 0029, 0031 |
| **Branch note** | Nushi's sentence before your next message when the worktree's branch was renamed or switched ("[Nushi] This worktree's branch was renamed from … to …"); the transcript's line then says "· told the agent". | `branchNote`, `branch_switched` | 0016 |
| **Nushi's tools** | Tools a chat's agent gets from Nushi (a Jira issue's; `show`, which opens a file in the preview or a page of this Mac in a browser tab; `preview_list`, `preview_start`, `preview_stop` and `preview_logs`, the folder's dev servers by name), through an MCP server of Nushi's own. | `features/tools`, `features/preview`, `servers.AgentTools`, `nushid tools-mcp` | 0043, 0068, 0100 |

## The app's parts

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Daemon** | `nushid`: runs the agents, terminals and checks, and keeps running when the app quits. In the app as a background-only helper. | `cmd/nushid`, `Nushi Daemon.app` | 0002, 0036 |
| **Restart daemon** | Start the daemon again; an older daemon does it on its own once nothing runs. | `RestartWhenIdle`, `features/restart` | 0056 |
| **Sidebar** | The left column: Pinned, then sections, then projects and their chats (or another grouping, from the Arrange menu), archived last; Jira, GitHub and Settings at its foot, over the status card. It sits on the window's background, with no pane of its own. ⌘\ hides it, and the main area takes the window. | `sidebar.dart`, `sidebar_links.dart`, `sidebar_row.dart`, `sidebar_groups.dart`, `sidebar_group_header.dart`, `sidebar_grouped.dart`, `sidebar_rows.dart`, `slide_list.dart`, `list_motion.dart`, `sidebar_button.dart`, `sidebarHidden` | 0080 |
| **Project** | A group in the sidebar: a folder (a repository with its worktrees) and its chats, in the order they were dragged into. It stays with no chats ("No chats") until Remove from sidebar, and comes back with its next chat. Also the "in this project" scope of MCP servers and skills. | `sidebarGroups`, `sidebarProjects`, `sidebarChats` | |
| **Arrange menu** | The sidebar's button at its top (shown under the pointer, or with a dot while it's arranged otherwise) and its menu: Group by, Sort by, Show, New section, Reset to defaults, View all. | `ArrangeButton`, `sidebar_arrange.dart`, `arrangement.dart`, `arrangeSidebar` | 0089 |
| **Section** | A group of the user's own in the sidebar, under Pinned: named, chats moved into it by a drag or Move to section, its order dragged. The Mac's, not the daemon's. Not a details widget's or a menu's heading. | `Section`, `sidebarSections`, `sidebar_sections.dart` | 0089 |
| **Pinned** | The sidebar's section above the projects, shown while a chat is pinned: Pin chat and Unpin chat (⌘D). A pinned chat leaves its project's list; the daemon keeps which and in what order, so the phone has them too. Not an artifact's pin, nor a pinned message. | `Chat.pin`, `ChatRecord.Pin`, `PinChats`, `PinnedSection`, `chat_pins.dart` | 0064 |
| **Chat color** | One of eight names (blue, teal, violet, amber, rust, magenta, slate, green), or none, set on a chat's menu's Color row; it shows as a chip at the end of its row, on the phone too, and before the title in the chat's header while the sidebar is hidden. The daemon keeps the name, never a hex, and each theme draws it its own way. | `Chat.color`, `ChatRecord.Color`, `SetChatColor`, `ChatColor`, `ColorChip`, `Tokens.avatars`, `chat_colors.dart` | |
| **Theme** | A named palette, a dark and a light set of the tokens, picked in Settings › Appearance (the phone's Settings too); Appearance picks which set shows. Built in, or your own: a theme file in the data folder's `themes`. | `ColorTheme`, `builtInThemes`, `colorTheme`, `ThemeFiles`, `theme_file.dart` | 0086 |
| **Folder** | Where a chat's agent works. A chat with No folder gets a scratch folder of its own. | `ChatRecord.Folder`, `ChatRecord.Scratch` | |
| **Worktree** | A git worktree a chat runs in, `.worktrees/<two words>` on `nushi/<two words>`: New worktree, Move. | `Worktree`, `GitWorktree` | 0016 |
| **Related worktree** | A worktree one of a chat's subagents works in, which the chat doesn't run in: found in git's list by what the subagent's tool calls name, and kept after it goes, with the last commit seen. Nushi neither makes nor removes it, and only reads it: the Changes tab's menu shows one, its diff only on a click, with review comments of its own for the chat's agent. **Merged** when git shows its last commit on the chat's branch or base, **removed** when it's gone and git doesn't: a squash merge reads as removed. | `RelatedWorktree`, `GetRelatedWorktrees`, `GetRelatedWorktreeStats`, `related.go`, `related_worktrees.dart` | 0081 |
| **Branch** | The branch a chat's folder has out: Rename branch… for a worktree's, the Branch row's menu to switch. | `RenameBranch`, `SwitchBranch`, `GitBranch` | 0016 |
| **Chat header** | The top bar: title, agent, model, the tabs, the terminal and details buttons, ⋯. | `ChatHeader` | |
| **Tabs** | Chat, Changes, Pull request (when the chat has one), in the header, as a segmented control. | `chat_keys.dart`, `Segmented` | 0071, 0111 |
| **Composer** | The message box under the transcript: a card holding the text and, under it, one row of controls (the +, the agent's pickers, then Send, or Queue, Stop and send and Stop while a turn runs). "The box" is its text field. A box too narrow for that row (a phone's, a side chat's) is one row, its pickers under it. | `Composer` | |
| **Spell check** | The composer's dotted underline under misspelled words, on the Mac, from macOS's own checker. A click on one, or ⌘; (**Next Typo**), opens its suggestions. The UI calls a flagged word a typo. | `SpellCheck`, `SpellMenu`, `Speller`, `ComposerText`, pref `checkSpelling` | 0083 |
| **Draft** | What you've written in a chat and not sent: the box's text, mentioned files, file cards, reply cards and images, and the subagents' boxes. Kept on disk until sent, so a crash or restart doesn't lose it. A comment box's (GitHub's, Jira's) and your review's inline comments are kept on disk too, by what they answer. | `Draft`, `Drafts`, `drafts.json`, `commentDraft` | 0062, 0027 |
| **Reply card** | A quote put into the box to send with your message: a review thread, a comment, a failed check. A GitHub one asks the agent to do something with it (**what it asks**, Settings › GitHub's What reply cards ask), then says its quote is data. | `ReplyCards`, `QuoteBlock`, `CardAsk`, `cardAsks` | 0059 |
| **Side pane** | What opens beside the transcript: the Files pane, a subagent's pane, or the preview of an artifact. A side chat opens beside it, apart. | `beside.dart` (`Beside`, `SidePane`), `panes.dart`, `SubagentPane`, `PreviewPane` | |
| **Details panel** | The right column of the chat's pane, under its header, made of widgets: one width, shown or hidden only. Show details, Hide details. | `details_panel.dart`, `DetailsPanel.width` | 0092, 0111 |
| **Widget** | One part of the details panel: Environment, Context, Changes, Pull request, Worktrees (the chat's related worktrees), Artifacts, MCP, Background tasks. Drawn as a rounded card in the panel's column; its title's triangle folds it and the title drags it. Called a widget all the same, never a card. | `PanelWidget`, `panel_widgets.dart`, `collapsedWidgets`, `widgetOrder` | 0092, 0111 |
| **Card** | A box in a flow or a list: a question, permission, trust, findings or reply card; the GitHub inbox's and Jira's task list's groups. Never the details panel's parts. | `cards.dart`, `CardShell`, `CardList` (`card_list.dart`) | 0009 |
| **Artifact** | A file the agent wrote that's made to be looked at (Markdown, an image, HTML, SVG, PDF, CSV, a Mermaid diagram). Listed in the Artifacts widget (Claude Code's rail calls them Outputs) and Artifacts…; pinned per chat (the app's, unlike a chat's pin). | `artifacts_widget.dart`, `FileRows`, the phone's `ArtifactsScreen` | |
| **Preview** | An artifact shown in the side pane (or full screen on the phone), kept current as it changes; its path line over it. | `preview.dart`, `WatchChatFile`, `internal/filewatch` | 0057 |
| **Path line** | The line over a file's preview: its path (a click copies it) and, for a file that renders, the source button (`</>`, View source, View preview). | `PathLine`, `SourceButton`, `preview_path.dart` | 0106 |
| **Outline** | The rail of dashes left of a Markdown preview's text, one per heading, the current section's long and in the accent; pointing at it lists the headings. | `OutlinedMarkdown`, `markdown_outline.dart`, `Rail` | 0106 |
| **Unsaved changes** | What you typed into a file in the preview and haven't saved: a dot in its tab's ✕ place. Save, Discard. Changed on disk (a conflict: Compare, Overwrite with mine, Use theirs), Deleted on disk, Merged a change from disk. Not a draft (a message's). | `FileEdit`, `ChatState.edits`, `EditBars`, `WriteChatFile`, `internal/filesave` | 0096 |
| **Files pane** | The tree of the chat's folder, in a side pane left of the preview (⇧⌘E); the phone's Files screen. A file opens as a preview. | `FilesPane`, `FolderTree`, `WatchChatFolder`, `internal/folderlist`, the phone's `FilesScreen` | 0090 |
| **Preview tab** | One of the files or browser tabs open in the preview, when two or more are: names in the side pane's title row, in place of the file's. In memory, and gone with the pane. Only the one showing has a view. | `ChatState.previewTabs`, `PreviewEntry`, `preview_tabs.dart` | 0070 |
| **Browser tab** | A preview tab that shows a web page at an address, any site or a server on this Mac (`localhost:3000`), with Back, Forward, Reload and its address field. New browser tab: the + at the tab row's end, the header's globe, the palette. Its tab is a chip; Expand gives it the whole chat area, Collapse gives it back; its ⋯ menu is the browser menu. A chat's links to this Mac or the local network open in one, with Open local links in built-in browser on. Not the default browser, which the docs call your browser. | `BrowserTab`, `BrowserPane`, `BrowserPage`, `browser_bar.dart`, `browser_address.dart` | 0094 |
| **Local network access** | Whether a site's page in a browser tab may reach this Mac (a dev server) and the local network (a router, a printer): blocked, unless the page is there itself or the site is let through. Claude desktop's word. | `localNetworkSites`, `browser_local.dart`, `LocalNetwork` | 0094 |
| **Allowed sites** | The sites whose pages in a browser tab have Local network access, as you let them through: Manage allowed sites… in the browser's ⋯ menu lists them and adds one. Claude desktop's word (its list also says which sites its agent may use; Nushi's agents don't drive pages). | `localNetworkSites`, `AllowedSites` (`allowed_sites.dart`) | 0094 |
| **Dev server** | A project's web server for development (`npm run dev`), as its launch files configure it: one entry, which runs a command, or opens a server already running at its address. Running, it's the daemon's, shared by the chats in its folder: starting, running, not answering (no answer in 180 s), failed or stopped. | `launchfile.Entry`, `servers.Service`, `DevServer` | 0095, 0098 |
| **Servers menu** | The menu of the Servers button, left of a browser tab's ⋯: the chat's folder's dev servers, each with ▶ (Run) or ■ (Stop), Stop all servers, and Add server, which puts a request for the agent in the box. Claude desktop's word. | `ServersButton`, `servers_menu.dart`, `DevServers` | 0098 |
| **Logs drawer** | A dev server's output, live and in its colours, read-only, in a drawer docked at the bottom of the browser tab's pane: its name, port and state, Stop while it runs, and a close. Opened by a Servers menu row's Logs. | `server_logs.dart` (`ServerLogsDrawer`, `ServerLog`), `WatchServerLog`, `DevServer.log_id` | 0100 |
| **Launch file** | A folder's `.agents/launch.json` or `.claude/launch.json` (Claude desktop's), in Claude's format; its dev servers are both files' entries merged by written name, `.agents`' winning. | `internal/launchfile` | 0095 |
| **Changes** | The chat's diff viewer tab: its folder's uncommitted changes, or its branch's for a worktree chat. Stages and commits in Uncommitted. | `changes_view.dart`, `GetDiff`, `FileChange` | 0012, 0019, 0079 |
| **Side by side, unified** | How a diff shows: two panes, old on the left; or one column, each change's deleted lines above its inserted ones, both line numbers in the gutter. One switch for every diff; an added or a deleted file and a narrow diff are always unified. Not split or inline (see below). | `diffUnified`, `DiffBox`, diff_view's `SideBySideDiff` and `UnifiedDiff` | 0107 |
| **Commit box** | Under Uncommitted's files: what's staged, the message, Commit. | `CommitBox`, `StageCheck`, `StageFiles`, `CommitStaged` | 0079 |
| **Terminal** | A shell beside a chat, owned by the daemon, in tabs under it (⌃\`). | `Terminal`, `features/terminals`, `terminal_panel.dart` | 0022 |
| **Run** (a code block's) | ▷ on an agent's shell block: the block typed into the chat's terminal, its newest output under the block, its exit once it ends. | `CodeRuns`, `CodeRun`, `RunnableBlock`, `ShellMarks` | 0084 |
| **File card** | A file attached to the message being written, in the box: its kind, name and size. Sent as a link to the file; the phone's go whole. In a sent message, a **file chip**. | `AttachedFile`, `FileCard`, `FileChip`, `Draft.files`, `SendPromptRequest.uploads` | 0091 |
| **Output card** | A run's output in the box, sent after your next message's text: only from a run that ended on its own. | `OutputCard`, `Draft.outputs`, `RunOutput`, `withOutputs` | 0084 |
| **Status card** | The card at the sidebar's foot: working, awake and sleeping agents, and Nushi's memory. With the sidebar hidden, the same on a line under the main pane. | `StatusBar` | 0032, 0111 |
| **Pane** | A rounded surface floating on the window's background: the main area, with a view's header at its top. A side pane is a column inside it. | `Pane`, `PaneHeader`, `NushiTheme.windowPad`, `paneGap` | 0111 |
| **Palette** | ⌘K (⌘⇧P): go to a chat or run an action. | `palette.dart`, `AppAction` | |
| **Open file** | ⌘P: any file that previews in the chat's folder. | `open_file.dart`, `FindChatFiles` | |
| **Find** | ⌘F: in the chat, in Changes' files and diffs, in a terminal's scrollback, or in the preview's file while its editor has the focus. | `TranscriptFind`, `ChangesFind`, `TerminalFind`, `EditorFind` (each in a `FindBar`), `TextMarks` | 0082, 0096 |
| **Settings** | A modal over the window (⌘,), a nav of sections; it never takes the chat's place. | `settings_modal.dart`, `settings_view.dart`, `SettingsSection`, `Daemon.settingsOpen` | 0053, 0087 |
| **View in the chat's place** | Jira and GitHub: they take the chat's place beside the sidebar; Esc goes back. | `Place`, `Daemon.go`, `back` | 0053 |
| **Toast** | A small card in the bottom right corner: the newer release's. | `UpdateToast` | 0061 |
| **Bar** | A strip over the app or a view saying something (what didn't start, the daemon updating, the connection). | `NoticeBar`, `DaemonUpdateBar`, `ConnectionBar`, `BarSlide` | |
| **Jump chip** | "Jump to latest" over a transcript scrolled up; "Needs you ↓" when something below waits. | `JumpChip` | |
| **Notifications** | The Mac's notices when a chat needs you or a turn ends or fails; the Dock badge counts chats that need you. | `alerts.dart` | |

## Review and GitHub

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Review comment** | A comment you write on a line in Changes, for the agent: Add to review, then Send review comments to agent. | `ReviewComment` | |
| **Send to agent** | Put a GitHub comment, thread or failed check into the box as a reply card, to send when you're ready. Never sends by itself. | `SendToAgent` | 0059 |
| **Fix checks**, **Address** | Put the failed checks, or the review threads, into the box as reply cards: the Checks section's and the PR widget's buttons, in the send look. | `checkReplies`, `threadReplies` | 0059 |
| **Re-run failed** | Ask GitHub to re-run the failed jobs of a pull request's failed checks' workflow runs. | `RerunGitHubChecks` | |
| **Activity** | The Pull request tab's conversation, under To do: the description, comments and reviews, a bot's comment one line, a long review its start. | `PullActivity` | |
| **GitHub view** | ⌘G: GitHub in the chat's place: the inbox, and an item's details. | `github_view.dart` | 0046 |
| **Inbox** | The GitHub view's three cards: Review requested, My pull requests, Assigned issues. | `ListGitHubInbox`, `github_inbox.dart` | 0046 |
| **Item** (GitHub) | A pull request or an issue in the inbox. | `GitHubItem`, `GitHubRef` | |
| **Start work** | Start a chat on an issue or pull request: pick a folder, then New chat with it, in a worktree. | `StartChatRequest`, `new_chat_issue.dart` | |
| **Pull request** (a chat's) | The pull request whose head is the chat's branch, found by itself or linked by hand (Link pull request…, Unlink). | `FindChatPull`, `LinkChatPull`, `ChatRecord.Pull`, `PullLink` | 0059 |
| **Pull request tab** | The chat's pull request in the chat's place: its head, the To do list, then conversation, checks, files with review threads. | `PullTab`, `GitHubPullPane` | 0059 |
| **Status lights** | The Pull request tab's four boxes under its head, Checks, Review, Threads and Branch, each in its state's color; a click goes to its section. | `pullLights`, `PullHeader` | |
| **Your move** | The sentence over the status lights saying whose move it is: "Your move. 5 things block the merge…", "Waiting on @team.", "Ready to merge." | `moveWords` | |
| **To do** | The Pull request tab's list of what blocks the merge: failing checks, reviews that requested changes, review threads not resolved (an outdated one marked), and, with Findings from review bots on, a review bot's findings to address; each with Send; Send picked, Send all to agent. | `PullTodo`, `todo` | |
| **Finding** (a review bot's) | An item a review bot's newest message lists under a heading such as "Must address" (Settings › GitHub › Findings from review bots, off at first: which bots, which headings), found by its Markdown's shape; one on a thread's lines joins that thread. | `readFindings`, `ReviewFinding` | |
| **Findings from review bots** | Settings › GitHub's opt-in for findings in To do: the bots' logins and the headings that start them. | `githubFindings`, `FindingsGroup` | |
| **PR widget** (Pull request widget) | The details panel's sum-up of the chat's pull request: state, title, the checks bar, a row a reviewer, open threads (Address), whether it can merge and by what it's blocked, comments; one line collapsed. | `pull_widget.dart`, `PullRows`, `pullSummary` | 0059 |
| **Merge control** | Under the Pull request tab's head and in the PR widget: ready to merge or exactly why not, and what you may do (a method as a split button, Enable auto-merge, Add to queue, Merge when ready). | `MergeControl`, `mergeView`, `MergeBlocks` | 0069 |
| **Clean up…** | After a chat's pull request merged or closed: delete its worktree, its local branch and the branch on GitHub, and archive the chat, each ticked in a dialog that says what it costs; Not now hides the PR widget's offer. | `showCleanUp`, `CleanUpJob`, `RemoveChatWorktree`, `DeleteChatBranch`, `DeleteGitHubBranch` | 0063 |
| **Restore branch** | Make the pull request's branch on GitHub again at its head, after a clean-up deleted it. | `RestoreGitHubBranch` | 0063 |
| **Review thread** | A GitHub inline comment and its replies at a line: Reply, Resolve, Unresolve. | `GitHubThread` | |
| **Your review** | Inline comments you wrote on a pull request, not sent until Review… (comment, approve, request changes). | `GitHubDraft`, `SubmitGitHubReview` | |
| **Check** | A CI check of a pull request; a failed one opens to its annotations and its job's log. | `GitHubCheck`, `GetGitHubJobLog` | |

## The phone and the relay

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Remote access** | The daemon connected to your relay so a phone can reach it; off until turned on. | `features/remote`, `Remote` | 0033, 0034 |
| **Relay** | Your server that passes Noise traffic between the phone and the daemon and serves the phone's web app. Keeps nothing. | `cmd/nushi-relay`, `relay/` | 0033, 0054 |
| **The phone** | Nushi's web app on the phone's Home Screen: chats, prompts, questions, previews, notifications. A full client. | `lib/phone/`, `phone_main.dart` | 0054 |
| **Pairing** | Adding a device: Pair a phone on the Mac shows a QR code (or Copy link); the phone shows a six-digit code; Allow on the Mac. | `StartPairing`, `ConfirmPairing`, `Pairing` | 0034, 0054 |
| **Pairing link** | The QR code's link, which the phone pastes when it can't scan. | | 0054 |
| **Device** | A paired client, listed on the Mac with Revoke and Send a test notification. | `Device`, `RevokeDevice` | 0034 |
| **Forget this Mac** | On the phone: drop the pairing and the device's key. | `UnpairThisDevice` | |
| **Notification** (phone) | A Web Push from the daemon, saying only what happened. | `internal/webpush`, `features/remote/push.go` | 0054 |
| **Noise** | The end-to-end encryption between the phone and the daemon. | `noiseconn`, `packages/noise` | 0034 |

## Settings and integrations

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Data folder** | `~/Library/Application Support/Nushi` (on Linux `$XDG_DATA_HOME/nushi`, else `~/.local/share/nushi`): socket, token, state, copies, logs, adapters. | `NUSHI_DATA`, `AppInstall.dataFolder` | 0101, 0104 |
| **Start at login** | A launch agent that opens the daemon at login. | `login_item.dart` | 0036 |
| **Logs** | `nushid.log` and `app.log`; Settings › Logs & advanced. | `internal/logs` | 0038 |
| **Shell environment** | Your login shell's variables, which agents start with; read again from Settings › Agents. | `internal/shellenv`, `ShellEnv` | 0048 |
| **MCP server** | A tool server an agent uses. Settings › MCP servers lists Claude's by scope and Ante's; a switch turns one off for a project. | `McpServer`, `features/mcp`, `claudemcp`, `antemcp` | 0021, 0050, 0058 |
| **Scope** | Where an MCP server or skill is set: Yours (user), Project, Local, a plugin's, a claude.ai connector. | `McpServer.scope` | 0021 |
| **Skill** | A `SKILL.md` folder an agent loads; Settings › Skills lists each agent's, with a switch in its own way. | `Skill`, `features/skills`, `*skills` packages | 0051, 0052 |
| **Shared** | Skills in `.agents/skills` and `~/.agents/skills`, read by several agents; Link for Claude… links one in. | `SkillAgent`, `LinkSkill` | 0052 |
| **Plugin** | A Claude Code plugin: its skills, commands, agents and MCP servers; turned on and off, or uninstalled. | `Plugin`, `SetPluginOn` | 0051 |
| **Updates** | The daemon's check for a newer Nushi release; Check for updates. | `features/updates`, `UpdateCheck` | 0061 |
| **Update** | The card's button that installs the newer version: the daemon runs Homebrew's upgrade of the app's cask. "Updating…" while it runs; Retry after a failure. | `InstallUpdate`, `updates.Service.Install`, `internal/homebrew` | 0109 |
| **Beta version** | A version to try before its release (0.29.0-beta.1), a GitHub pre-release; the `nushi@beta` cask follows them. "A beta" for short. | `updates.Service.Beta`, `betaCask`, `isBeta`, `tools/cask.sh` | 0108 |
| **Jira site** | A Jira Cloud site with your email and API token (kept in the keychain). | `JiraSite`, `internal/jiracloud` | 0042 |
| **Task list** | The Jira view (⌘J): your open issues in a card per status, or a sprint, saved search or JQL. | `jira_tasks.dart`, `JiraSearch`, `JiraBoard` | 0042 |
| **Move** (Jira) | Change an issue's status, as its workflow allows. | `TransitionJiraIssue`, `JiraTransition` | |
| **GitHub host** | A GitHub (or Enterprise) host Nushi has a token for: gh's login, else a pasted token in the keychain. | `GitHubHost`, `internal/githubapi` | 0045 |

## Synonyms and old names

One line each; the word after the arrow wins.

- status bar → **status card** (it left the window's bottom for the sidebar's foot, ADR 0111).
- side question → **side chat** (the owner, 2026-10-29: "side chat, since you can go back and forth").
- card, for the details panel's parts → **widget** (Context card, Artifacts card, MCP card, Pull request card: all widgets). Older ADRs' titles say card; they stay as written.
- details pane → **details panel**. Panel is the details panel and the terminals'; pane is the side pane and what's in it.
- PR → **pull request** in the UI and docs; commit messages may say PR.
- prompt (your message) → **message**. Prompt stays for ACP and "permission prompt".
- prompt box, message box → **composer**; "the box" is its text field.
- session, for a chat → **chat**. Session is the agent's.
- unseen → **done** (the chat state's word).
- waiting → **needs you**.
- relay, for a message to a subagent → **message to a subagent**. Relay is the server only.
- shell, for a background command → **background command**. Shell is a terminal's.
- inline, split (diff views) → **unified**, **side by side** (the owner asked for an "inline diff view", 2026-11-09).
- steer, for the button that stops the turn and sends → **Stop and send** (the owner, 2026-10-29). Steering (the agent taking a message into its running turn, as other harnesses use the word) is what **Queue** does when the agent can.
- transition (Jira's API) → **move** in the UI.
- unpair → **Forget this Mac** on the phone, **Revoke** on the Mac.
- Open in Finder → **Show in Finder** (it reveals the file).
- Open in the browser, for a GitHub item → **Open on GitHub**.
- omp → **oh-my-pi** in the UI; `omp` is its command.
- opencode → **OpenCode** in the UI; `opencode` is its command.
- Nushi Next → **Nushi** (ADR 0018).
- group, for tool rows → **run**.
- built-in browser → **browser tab**. Only the setting Open local links in built-in browser says it, after Claude desktop's words.

## Renames to do

Code that uses an old word, for the clean-up batch. A proto field or message is renamed in place, its number and type kept (ADR 0004's amendment): the old name goes in its comment.

None left.
