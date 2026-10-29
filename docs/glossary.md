# Glossary

Nushi's words, defined once. The UI, the code and the docs use them; a new user-facing term goes here first. Each row: the term as the UI says it, what it means, the code's name when it differs, and the ADR that decided it.

## Chats and agents

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Agent** | A coding agent Nushi runs: Claude, Codex, Ante, PiG or oh-my-pi, each your own CLI with its own login, settings and history. | `features/agents`, proto `Agent` | 0037 |
| **Harness** | The agent's own program and rules (Claude Code, Codex…). Prose only: the UI says agent. It owns permissions and history. | | 0007, 0008 |
| **Adapter** | The ACP program Nushi sets up for an agent that needs one (Claude's, Codex's), from Nushi's own lockfile, into the data folder. Set up, Update, Remove. | `Adapter`, `SetUpAgent`, `internal/claude/adapter` | 0037 |
| **Bridge** | Nushi's own ACP translator for an agent without ACP: `nushid ante-acp`, `nushid pig-acp`. | `internal/ante`, `internal/pig` | 0030, 0039 |
| **ACP** | The Agent Client Protocol, how the daemon talks to agents. | `github.com/afrase/acp-go` | 0041 |
| **Chat** | A conversation with an agent as Nushi shows it: the agent's session plus what Nushi keeps (title, folder, worktree, picks). | `model.Session` (the record), `model.Chat` (a snapshot), proto `Chat` | 0008 |
| **Session** | The agent's own record of a conversation, which it keeps and resumes. A chat is on one at a time; a move or a rewind starts another. | `SessionID`, `AgentSession`, ACP `session/*` | 0008 |
| **Session started elsewhere** | A session begun in a terminal, opened as a chat from New chat's Sessions →. | `ListAgentSessions`, `OpenAgentSession`, `FoundSession` | 0035 |
| **Turn** | One message and everything the agent does for it, until it ends. Stop (Esc) ends it. | `ChatStatus.busy`, `CancelTurn` | 0044 |
| **Message** | What you send: text, mentioned files, images. | `model.Message`, `SendPrompt`, `UserMessage` | |
| **Prompt** | ACP's word for a message to the agent. The UI says message, and prompt only in "permission prompt". | `SendPrompt` | |
| **Item** | One entry of the transcript: a message, thought, tool call, permission prompt, question, plan or notice. Code only; prose says entry or names the kind. | `model.Item`, `ItemKind` | 0026 |
| **Tool call** | The agent's use of a tool (read, edit, run…), shown as a **tool row**. | `ToolCall` item, `ToolCallView` | |
| **Run** | Tool rows in a row, folded into one line: "Read 4 files, running make test". | `ToolGroupView`, `RunLine` | |
| **Thought** | The agent's thinking: "Thinking…", then "Thought for 12s". | `Thought`, `ThoughtLine` | |
| **Plan** | The agent's checklist, updated in place: "Plan · 2 of 5 done". | `Plan`, `PlanEntry` | |
| **Notice** | A quiet line in the transcript: how a turn ended when it didn't end well, or a note of the agent's own ("Stopped by safeguards", "Compacted here"). | `Notice`, `AgentNotice` | |
| **Permission prompt** | The agent asking to run a tool call, with its options (Allow, Deny…). You answer; Nushi never does. | `Permission` item, `PermissionCard`, `AnswerPermission` | 0007 |
| **Question** | A form the agent asks you to fill in (Claude's AskUserQuestion), as a question card. | `Question` item, `Field`, `QuestionCard`, `AnswerQuestion` | 0009 |
| **Needs you** | The chat waits on you: a permission prompt or a question. Amber dot, Dock badge, "Needs you ↓". | `waiting` (`ChatStatus`, `ChatPhase`), `WaitingCard` | |
| **Chat states** | A chat's dot and word: needs you, working, in background, done, asleep, idle, new, expired, couldn't start, archived. | `ChatPhase`, `phaseWord` | |
| **Done** | A turn ended while nothing showed the chat; showing it clears it. | `Unseen`, `ChatPhase.unseen` | |
| **Subagent** | A helper the agent starts for a task ("Explore: find the scroll handling"). Its steps show in its row and its pane; it can be stopped alone. | `Subagent`, `Item.Agent`, `SubagentPane` | 0044 |
| **Message to a subagent** | A message you write to a running subagent; the agent passes it on ("To Explore, through Claude"). | `Relay`, `RelayTo`, proto `to_subagent`, `relay_to` | |
| **Background task** | A subagent or command still running after the turn that started it ended. The Background tasks widget lists them; each has a Stop. | `ChatStatus.background`, `StopTask` | 0044 |
| **Background command** | A command the agent left running in the background, its output in a pane. | `Shell`, `ShellPane`, `Item.TaskID` | |
| **Queue** | Messages sent while a turn runs (⏎, Queue). Each goes at the agent's next chance: into the running turn when the agent takes steering, else as the next message. Shown as pills over the box. | `QueuedMessage`, `ChatQueue`, `SendPrompt.queue`, `Unqueue`, `QueuePills` | |
| **Steer** | "Steer: stop and send now" (⌘⏎): stops the running turn and sends at once. Not the agent's steering (Synonyms). | `SendPrompt.now` | |
| **Side question** | A fork of the chat, beside it, that knows the conversation but doesn't add to it; it ends when closed (⇧⌘B). | `ForkChat`, `CloseSideChat`, "side chat" in Go, `side_panel.dart` | |
| **Rewind** | Go back to just before one of your messages: the session forks there and the message returns to the box. Files aren't rewound. Esc Esc lists them. | `RewindChat`, `Item.ForkAt`, `Rewindable` | 0020 |
| **Sleep** | An idle chat's agent stops; the chat stays and the next message wakes it. On its own after 30 idle minutes. The chat is then asleep. | `SleepChat`, `ChatStatus.asleep` | 0032 |
| **Archive** | Put a chat away: its agent stops, it's read-only and listed last. Unarchive reopens it. | `ArchiveChat`, `Session.Archived` | |
| **Reload** | Restart the chat's agent on its session, to pick up changed MCP servers. | `ReloadChat` | |
| **Move** | The chat goes on in another folder or worktree; its session forks there. | `MoveChat` | 0014 |
| **Delete** | Remove a chat, the agent's history of it, and its worktree and branch if you say so. | `PlanDeleteChat`, `DeleteChat` | 0015 |
| **Expired** | A chat whose agent deleted its session: read-only, on Nushi's copy, with Start a new chat here. | `session_gone`, `RemovedChat` | 0015, 0047 |
| **Transcript** | The conversation as shown: your messages as chapter bands, tool rows, subagents, plans. | `transcript.dart`, `items.dart` | 0026 |
| **Nushi's copy** | Nushi's own read-only copy of each transcript as shown, for what the agent no longer replays. Settings › Chat history. | `internal/transcripts`, `TranscriptCopy` | 0047 |
| **Mode** | The agent's own permission mode (Auto, Plan…): the only permission control. The picker on the left under the box. | `ConfigOption` category `mode`, `Session.Mode` | 0007 |
| **Model**, **Effort** | The model the agent runs and how hard it thinks; the model menu under the box (Effort ▸, More models ▸). | `ConfigOption` categories `model`, `thought_level` | 0060 |
| **Picks** | The options you chose for a chat, put back whenever its session opens; an agent's last picks start its new chats. | `Session.Picks` | 0060 |
| **Ultracode** | Claude Code's standing multi-agent workflows for a chat; in ⋯ under the box, off by default. | `Session.Ultracode`, `ultracodeID` | |
| **Fast** | Claude's fast mode: one of the agent's options in ⋯ under the box, named as the agent names it. | `ConfigOption` id `fast` | |
| **Slash command** | One of the agent's `/` commands, completed in the box. | `Command`, `ChatCommands` | |
| **Context** | What fills the agent's context window, broken down in the Context widget. | `GetContextUsage`, `ContextUsage` | 0017 |
| **Findings** | A code review's result (`/code-review`), as a card in the transcript. | `Findings`, `Finding`, `FindingsCard` | |
| **Trust card** | Before an agent starts in a folder that brings code of its own (hooks, MCP servers, extensions), it lists that code; Start anyway goes on. | `features/trust`, `CheckFolder`, `TrustFolder`, `FolderRun`, `TrustCard` | 0023, 0029, 0031 |
| **Branch note** | Nushi's sentence before your next message when the worktree's branch was renamed or switched ("[Nushi] This worktree's branch was renamed from … to …"); the transcript's line then says "· told the agent". | `branchNote`, `branch_switched` | 0016 |
| **Nushi's tools** | Tools a chat's agent gets from Nushi (a Jira issue's), through an MCP server of Nushi's own. | `features/tools`, `nushid tools-mcp` | 0043 |

## The app's parts

| Term | Meaning | Code | ADR |
|---|---|---|---|
| **Daemon** | `nushid`: runs the agents, terminals and checks, and keeps running when the app quits. In the app as a background-only helper. | `cmd/nushid`, `Nushi Daemon.app` | 0002, 0036 |
| **Restart daemon** | Start the daemon again; an older daemon does it on its own once nothing runs. | `RestartWhenIdle`, `features/restart` | 0056 |
| **Sidebar** | The left column: projects and their chats, archived last; Jira, GitHub and Settings at its foot. | `sidebar.dart`, `sidebar_groups.dart` | |
| **Project** | A group in the sidebar: a folder (a repository with its worktrees) and its chats. Also the "in this project" scope of MCP servers and skills. | `sidebarGroups` | |
| **Folder** | Where a chat's agent works. A chat with No folder gets a scratch folder of its own. | `Session.Folder`, `Session.Scratch` | |
| **Worktree** | A git worktree a chat runs in, `.worktrees/<two words>` on `nushi/<two words>`: New worktree, Move. | `Worktree`, `GitWorktree` | 0016 |
| **Branch** | The branch a chat's folder has out: Rename branch… for a worktree's, the Branch row's menu to switch. | `RenameBranch`, `SwitchBranch`, `GitBranch` | 0016 |
| **Chat header** | The top bar: title, agent, model, the tabs, the terminal and details buttons, ⋯. | `ChatHeader` | |
| **Tabs** | Chat, Changes, Pull request (when the chat has one), in the header. | `chat_keys.dart` | |
| **Composer** | The message box and its pickers under the transcript. "The box" is its text field. | `Composer` | |
| **Draft** | What you've written in a chat and not sent: the box's text, mentioned files, reply cards and images, and the subagents' boxes. Kept on disk until sent, so a crash or restart doesn't lose it. | `Draft`, `Drafts`, `drafts.json` | 0062 |
| **Reply card** | A quote put into the box to send with your message: a review thread, a comment, a failed check. | `ReplyCards`, `QuoteBlock` | 0059 |
| **Side pane** | What opens beside the transcript: a subagent's pane, or the preview of an artifact. A side question opens beside it, apart. | `panes.dart`, `SubagentPane`, `PreviewPane` | |
| **Details panel** | The right column, made of widgets. Show details, Hide details. | `details_panel.dart` | |
| **Widget** | One part of the details panel: Environment, Context, Changes, Pull request, Artifacts, MCP, Background tasks. Each collapses and drags. | `PanelCard`, `panel_cards.dart` | |
| **Card** | A box in a flow or a list: a question, permission, trust, findings or reply card; the GitHub inbox's and Jira's task list's groups. Never the details panel's parts. | `cards.dart`, `CardShell` | 0009 |
| **Artifact** | A file the agent wrote that's made to be looked at (Markdown, an image, HTML, SVG, PDF, CSV, a Mermaid diagram). Listed in the Artifacts widget and Artifacts…; pinned per chat. | `artifacts_card.dart`, `FileRows` | |
| **Preview** | An artifact shown in the side pane (or full screen on the phone), kept current as it changes; Preview and Source. | `preview.dart`, `WatchChatFile`, `internal/filewatch` | 0057 |
| **Changes** | The chat's diff viewer tab: its folder's uncommitted changes, or its branch's for a worktree chat. Read-only toward git. | `changes_view.dart`, `GetDiff`, `FileChange` | 0012, 0019 |
| **Terminal** | A shell beside a chat, owned by the daemon, in tabs under it (⌃\`). | `Terminal`, `features/terminals`, `terminal_panel.dart` | 0022 |
| **Status bar** | The bottom strip: working, awake and sleeping agents, and Nushi's memory. | `StatusBar` | 0032 |
| **Palette** | ⌘K (⌘⇧P): go to a chat or run an action. | `palette.dart`, `AppAction` | |
| **Open file** | ⌘P: any file that previews in the chat's folder. | `open_file.dart`, `FindChatFiles` | |
| **Find** | ⌘F: in the chat, in Changes' files, or in a terminal's scrollback. | `TranscriptFind`, `FindBar` | |
| **Settings** | A view in the chat's place (⌘,), a nav of sections. | `settings_view.dart`, `SettingsSection` | 0053 |
| **View in the chat's place** | Settings, Jira and GitHub: they take the chat's place beside the sidebar; Esc goes back. | | 0053 |
| **Toast** | A small card in the bottom right corner: the newer release's. | `UpdateToast` | 0061 |
| **Bar** | A strip over the app or a view saying something (what didn't start, the daemon updating, the connection). | `NoticeBar`, `DaemonUpdateBar`, `ConnectionBar` | |
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
| **Pull request** (a chat's) | The pull request whose head is the chat's branch, found by itself or linked by hand (Link pull request…, Unlink). | `FindChatPull`, `LinkChatPull`, `Session.Pull`, `PullLink` | 0059 |
| **Pull request tab** | The chat's pull request in the chat's place: its head, the To do list, then conversation, checks, files with review threads. | `PullTab`, `GitHubPullPane` | 0059 |
| **Status lights** | The Pull request tab's four boxes under its head, Checks, Review, Threads and Branch, each in its state's color; a click goes to its section. | `pullLights`, `PullHeader` | |
| **Your move** | The sentence over the status lights saying whose move it is: "Your move. 5 things block the merge…", "Waiting on @team.", "Ready to merge." | `moveWords` | |
| **To do** | The Pull request tab's list of what blocks the merge: failing checks, review threads not resolved and a review bot's findings to address, each with Send; Send picked, Send all to agent. | `PullTodo`, `todoItems` | |
| **Finding** (a review bot's) | An item a review bot's comment lists under a heading such as "Must address", found by its Markdown's shape (a guess); one on a thread's lines joins that thread. | `reviewFindings`, `ReviewFinding` | |
| **PR widget** (Pull request widget) | The details panel's sum-up of the chat's pull request: state, title, the checks bar, a row a reviewer, open threads (Address), whether it can merge and by what it's blocked, comments; one line collapsed. | `pull_card.dart`, `PullRows`, `pullSummary` | 0059 |
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
| **Data folder** | `~/Library/Application Support/Nushi`: socket, token, state, copies, logs, adapters. | `NUSHI_DATA` | |
| **Start at login** | A launch agent that opens the daemon at login. | `login_item.dart` | 0036 |
| **Logs** | `nushid.log` and `app.log`; Settings › Logs & advanced. | `internal/logs` | 0038 |
| **Shell environment** | Your login shell's variables, which agents start with; read again from Settings › Agents. | `internal/shellenv`, `ShellEnv` | 0048 |
| **MCP server** | A tool server an agent uses. Settings › MCP servers lists Claude's by scope and Ante's; a switch turns one off for a project. | `McpServer`, `features/mcp`, `claudemcp`, `antemcp` | 0021, 0050, 0058 |
| **Scope** | Where an MCP server or skill is set: Yours (user), Project, Local, a plugin's, a claude.ai connector. | `McpServer.scope` | 0021 |
| **Skill** | A `SKILL.md` folder an agent loads; Settings › Skills lists each agent's, with a switch in its own way. | `Skill`, `features/skills`, `*skills` packages | 0051, 0052 |
| **Shared** | Skills in `.agents/skills` and `~/.agents/skills`, read by several agents; Link for Claude… links one in. | `SkillAgent`, `LinkSkill` | 0052 |
| **Plugin** | A Claude Code plugin: its skills, commands, agents and MCP servers; turned on and off, or uninstalled. | `Plugin`, `SetPluginOn` | 0051 |
| **Updates** | The daemon's check for a newer Nushi release; Check for updates. | `features/updates`, `UpdateCheck` | 0061 |
| **Jira site** | A Jira Cloud site with your email and API token (kept in the keychain). | `JiraSite`, `internal/jiracloud` | 0042 |
| **Task list** | The Jira view (⌘J): your open issues in a card per status, or a sprint, saved search or JQL. | `jira_tasks.dart`, `JiraSearch`, `JiraBoard` | 0042 |
| **Move** (Jira) | Change an issue's status, as its workflow allows. | `TransitionJiraIssue`, `JiraTransition` | |
| **GitHub host** | A GitHub (or Enterprise) host Nushi has a token for: gh's login, else a pasted token in the keychain. | `GitHubHost`, `internal/githubapi` | 0045 |

## Synonyms and old names

One line each; the word after the arrow wins.

- side chat → **side question** (Go and the API still say side chat: Renames to do).
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
- steering (the agent taking a queued message into its turn) is what **Queue** does when the agent can; **Steer** is the button that stops the turn and sends. Don't call queueing steer.
- transition (Jira's API) → **move** in the UI.
- unpair → **Forget this Mac** on the phone, **Revoke** on the Mac.
- Open in Finder → **Show in Finder** (it reveals the file).
- Open in the browser, for a GitHub item → **Open on GitHub**.
- omp → **oh-my-pi** in the UI; `omp` is its command.
- Nushi Next → **Nushi** (ADR 0018).
- group, for tool rows → **run**.

## Renames to do

Code that uses an old word, for the clean-up batch. Proto names stay (the API is additive, ADR 0004); a rename there is a new field or call.

- `PanelCard`, `PanelCards`, `panel_cards.dart`, `collapsedCards` → widget; `artifacts_card.dart`, `mcp_card.dart`, `pull_card.dart` → `*_widget.dart`; `agents_card.dart` holds the Background tasks widget → `background_tasks_widget.dart`. Doc comments that call them cards (`details_panel.dart`, `chat_header.dart`, `app_actions.dart`, `pull_link.dart`, `pull_states.dart`). `CardShell` and `CardList` serve the inbox's and task list's cards too: keep them.
- Side chat in Go (`features/chats`: `sides.go`, `CloseSideChat`'s comments, `Throwaway`, the log's `side` attribute, `remote/push.go`) and Dart (`daemon.dart`'s side chats, `chat.dart`'s `canFork`) → side question. `side_panel.dart` holds the side question → `side_question.dart`.
- `Relay`, `RelayTo`, `RelayCall`, `RelayState`, `RelayedBy`, `RelayStop` (`model.Item`, `model.Message`) and proto `relay_to`, `relay_stop` → a subagent message word (`ToSubagent`…), so relay means the server only.
- `model.Shell` and `ShellPane` (a background command) → `BackgroundCommand`; `Shell` is easy to take for a terminal's.
- `model.Session` is a chat's record, beside `model.Chat`, the snapshot → `ChatRecord` or similar.
- `Unseen` and `ChatPhase.unseen` → `done`, or keep unseen in code and say so here (it is precise: not yet seen).
- `ToolGroupView` → `RunView` (the UI's run).
- Steer: the button that stops the turn shares its name with the agent's steering, which is what Queue does (proto `SendPromptRequest.queue`'s comment, `composer.dart`'s "steers"). Either rename the button (Stop and send) or always qualify the agent's ("the agent's steering"). A product call: the owner's.
