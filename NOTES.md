# Notes

## Summary (2026-10-24, after step 73)

Milestone P (steps 70–73, plus a Context card change asked for during the run) is done: one commit each on `main`, all pushed. `make test` passes (the chats feature with `-race` too). Every step was tried by hand in a development build against live Claude (claude-agent-acp 0.94.0, Claude Code 2.1.309) at 1280×800, dark, with the dev daemon and app on `NUSHI_DATA` (a `/tmp` link to the scratchpad) and a throwaway repository; prompts only listed and read its files, ran `sleep`/`echo`/`wc`, and started Explore and general-purpose agents. Before any new test ran I checked that tests can't reach the real data folder (Go tests use `t.TempDir()`, app tests `FLUTTER_TEST`'s temporary folder) and kept a copy of `app.json`: it was unchanged at the end. The installed Nushi and its daemon were left alone. `make install` put the build in `~/Applications/Nushi.app` (and the iCloud copy).

**What works**
- 70: terminals start the login shell from the user database (`id -P`: fish here), with `-l` and `$SHELL` set to it; `status is-login` holds and the prompt works. Settings… (⌘,, also from a focused terminal) picks the terminal's font among the installed monospaced families (33 here, Nerd Fonts included) and its size; JetBrains Mono stays the default. Symbols Nerd Font Mono 3.5.1 is bundled as the fallback: lsd's icons, folder, git and Apple glyphs render in JetBrains Mono and in FiraCode Nerd Font Mono; xterm paints each cell on its own, so wide glyphs, CJK and emoji keep the grid. Also fixed: a new terminal answers fish's startup query at once (fish waited 10 seconds for it).
- 71: a click on a subagent (its one-line card in the transcript, or its row in the card) opens its pane in place of the details panel: back, its name, wider (remembered), ×; its prompt folded to five lines with Show more; "Model Sonnet 5.5 · Effort Low", or the chat's "(inherited)"; state and time; its steps live; its result. Back finds the panel as it was (scroll kept). The card rows show model and effort as a tag. A replayed subagent says its steps (and report) weren't kept.
- 72: see "Background shells" below. The card is now "Background tasks": running subagents and commands, then "n finished" (or "n earlier" when it holds a command whose end isn't known). A command's row shows it, its state and time, and its last line; its pane shows the command and the output so far, live.
- 73: the subagent pane has a box, "Message Explore through Claude". The message goes to the main session (steered or queued like any) asking Claude to pass it on verbatim with SendMessage; the transcript shows "You → Explore, through Claude" and only the message. Tried four times on finished subagents (one after a daemon restart) and once on a running one: the text arrived verbatim every time, the subagent acted on it, and its pane showed it running again, then its new result.
- Context card: expanded, one line over the bar ("5% used", "51.3k / 1M", refresh), then the bar and categories, Last turn and Cost; collapsed, the ring.

**Background shells (what a client that isn't AIR sees)**: the Bash call's input (`run_in_background: true`), and an output naming the task id and the file Claude writes the command's output to, which ends with "[exited with code N]" or "[killed]" when the command does. Claude 2.1.309 has no BashOutput: it reads that file with Read; it stops one with the deferred `TaskStop` (`{task_id}`). When a command ends, Claude gets a notification Nushi never sees and runs a turn of its own; the only trace is `_claude/origin: {kind: "task-notification"}` on that turn's last `usage_update`, naming no task. So the daemon follows the file: "running" only while it has no end line and the Claude that started it still runs; with the end line, done/failed/stopped and the exit; otherwise "started" (Claude's commands outlive it: a `sleep 300` kept running after the daemon stopped). Details in "Agent facts".

**Changes to earlier behavior**
- The transcript's subagent card no longer unfolds inline: it is one line that opens the pane.
- The card "Agents" is "Background tasks": a collapse or position it had is forgotten.
- A foreground subagent's result was Claude's pointer to its report ("This agent's report was delivered…") after a reload; now it is empty, and the pane says the report wasn't kept.
- A finished subagent with new steps (run again by SendMessage) counts as running again.

**Not tried by hand**
- The light theme; a terminal font size other than 14 and 12.5; a login shell other than fish (zsh, bash fall back the same way).
- A background command started by a subagent, and a command whose output passes 64 KB (only its end is read; covered by reasoning, not a test).
- `make install`'s app with the new font list (the Swift side was only run in debug builds).

**Needs your attention**
- The API went from 38 to 41: press "Restart daemon" in the installed app. Restarting stops running turns and closes terminals.
- Security: the daemon now reads Claude's background output files (see "Security notes"), and step 73's prompt asks Claude to pass text on; Claude's history keeps that wrapped prompt (`claude --resume` shows it).

**Size**: the daemon went from 6,913 to 7,281 lines of Go, the app from 12,431 to 13,372 lines of Dart. No file is over 400 lines (`subagent_pane.dart` is 321). Two steps crossed the ~500-line tripwire, tests included: 71 (616 added, 183 removed: the pane, its prompt and model/effort header, and the inline card it replaced) and 72 (652 added: following Claude's output files in the daemon, the shell pane and rows, and their tests).

**Dependencies**: none added; one font bundled (Symbols Nerd Font Mono, MIT, 2.5 MB).

**Left behind by the testing**: nothing (the dev chats deleted with Delete, Claude's history folder for the throwaway repository and its task outputs removed, the dev data folder, its `/tmp` link, the throwaway repository and the helper scripts removed).

## Demo (milestone P)

1. Open a terminal (⌃\`): it is your login shell (fish), `status is-login` is true. ⌘, picks a font (try FiraCode Nerd Font Mono) and a size; `lsd --icon always` shows icons in any font.
2. Ask: "Use an Explore agent with the haiku model and low effort to list the files in this folder." Click its line in the transcript: the pane shows the prompt, "Model Haiku 5.5 · Effort Low", the steps as they come, the result. Back returns to the panel where it was; the expand button widens the pane.
3. In the pane, type "Also print the first line of README.md" and press Enter: the transcript shows "You → Explore, through Claude", Claude forwards it, the pane shows the subagent running again, then its answer.
4. Ask: "Run `for i in 1 2 3 4 5 6; do echo tick $i; sleep 3; done` in the background and end your turn." Background tasks lists it with its last line; click it: the output grows, then "done · exited with code 0".
5. Expand Context: one line "n% used … used / size" with refresh, then the bar.

## Line counts

Hand-written, without tests or generated code (`make lines`). Go is split into the daemon (`cmd`, `internal`) and the generic ACP client (`acp`, its type generator included, its fake test agent not). Packages are counted apart from the app.

| Step | Go daemon | Go acp | Dart app | Dart packages |
|---|---|---|---|---|
| 1. Skeleton | 114 | 0 | 95 | 131 |
| 2. One chat | 429 | 663 | 360 | 131 |
| 3. Tool calls | 524 | 663 | 432 | 131 |
| 4. Permission prompts | 646 | 677 | 549 | 131 |
| 5. Agent questions | 900 | 703 | 839 | 131 |
| 6. Pickers | 1202 | 723 | 972 | 131 |
| 7. Many chats | 1340 | 723 | 1105 | 131 |
| 8. Survive the app quitting | 1394 | 723 | 1169 | 131 |
| 9. Survive the daemon restarting | 1515 | 730 | 1169 | 131 |
| 10. Diff viewer | 1662 | 716 | 1402 | 131 |
| 11. The POC's look | 1665 | 716 | 2252 | 131 |
| 12. Markdown | 1665 | 716 | 2294 | 650 |
| 13. Tool calls | 1677 | 716 | 2579 | 650 |
| 14. Thinking and plans | 1724 | 716 | 2780 | 650 |
| 15. Turn controls | 1807 | 722 | 2911 | 650 |
| 16. The composer | 1878 | 722 | 3118 | 650 |
| 17. Long chats | 1878 | 722 | 3235 | 650 |
| 18. Ask about a selection | 2009 | 773 | 3559 | 650 |
| 19. Rename, archive, remove | 2179 | 773 | 3968 | 650 |
| 20. Usage and cost | 2219 | 793 | 4070 | 650 |
| 21. A packaged app | 2219 | 793 | 4191 | 650 |
| 22. Chats without a folder, moving a chat | 2489 | 795 | 4383 | 650 |
| 23. The details panel | 2576 | 795 | 4760 | 650 |
| 24. A minimal composer | 2576 | 795 | 4927 | 650 |
| 25. Images | 2634 | 795 | 5388 | 655 |
| 26. Delete instead of Remove | 2810 | 800 | 5501 | 655 |
| 27. Composer menus | 2810 | 800 | 5635 | 655 |
| 28. Collapsible panel cards | 2810 | 800 | 5694 | 655 |
| 29. Reply and side chat | 2810 | 800 | 6213 | 655 |
| 30. Chats in their own worktree | 3025 | 800 | 6407 | 655 |
| 31. The branch's diff | 3044 | 800 | 6449 | 655 |
| 32. Worktrees when a chat ends | 3188 | 800 | 6621 | 655 |
| 33. A trim pass | 3197 | 800 | 6364 | 655 |
| 34. Long lists and the worktree switch | 3197 | 800 | 6600 | 655 |
| 35. Worktree gaps | 3241 | 800 | 6697 | 655 |
| 36. Reorder the panel's cards | 3241 | 800 | 6745 | 655 |
| 37. A working indicator | 3241 | 800 | 6896 | 655 |
| 38. Questions one at a time | 3241 | 800 | 7069 | 655 |
| 39. Subagents you can see | 3291 | 800 | 7384 | 655 |
| 40. A detailed context card | 3456 | 800 | 7524 | 655 |
| (rename to Nushi, ADR 0018) | 3528 | 800 | 7561 | 655 |
| 41. Resizable panes | 3528 | 800 | 7695 | 655 |
| 42. A file tree in Changes | 3579 | 800 | 7943 | 655 |
| 43. Committed work in Changes | 3756 | 800 | 8232 | 655 |
| 44. Syntax highlighting in diffs | 3756 | 800 | 8410 | 655 |
| 45. Review comments | 3756 | 800 | 8990 | 655 |
| 46. Your messages as markdown | 3756 | 800 | 9003 | 666 |
| 47. Messages while the agent works | 3958 | 835 | 9190 | 666 |
| 48. Rewind like the CLI | 4117 | 836 | 9334 | 666 |
| 49. Take back a stopped message | 4163 | 836 | 9342 | 666 |
| 50. The context breakdown, automatic again | 4235 | 836 | 9395 | 666 |
| 51. Leftovers | 4235 | 836 | 9616 | 666 |
| 52. See the MCP servers | 4607 | 836 | 10135 | 666 |
| 53. Add, edit, remove MCP servers | 4896 | 836 | 10655 | 666 |
| 54. MCP on/off, approvals, sign-in | 5157 | 836 | 10793 | 666 |
| 55. Shells in the daemon | 5835 | 836 | 10794 | 666 |
| 56. The terminal panel, with tabs | 5965 | 836 | 11676 | 666 |
| 57. Terminal touches | 5965 | 836 | 12026 | 666 |
| 58. Agents that die, and turns that race | 6071 | 867 | 12026 | 666 |
| 59. What the daemon keeps | 6145 | 867 | 12026 | 666 |
| 60. Trusting a folder | 6498 | 867 | 12188 | 666 |
| (60's security fixes) | 6550 | 867 | 12188 | 666 |
| 61. Secrets and untrusted output | 6699 | 867 | 12246 | 666 |
| (61's security fixes) | 6725 | 867 | 12246 | 666 |
| 62. The app keeps what you type | 6725 | 867 | 12293 | 666 |
| 63. The app stays fast and in sync | 6725 | 867 | 12506 | 682 |
| 64. Delete (T1, T2, T4, T5) | 6650 | 867 | 12394 | 682 |
| 65. One home for Claude's rules (T6, T9, T10, T13) | 6753 | 867 | 12394 | 682 |
| 66. The app renders what the daemon decides (T7, T8) | 6913 | 867 | 12383 | 682 |
| 67. Duplicates and splits (T11, T12, T14) | 6913 | 867 | 12423 | 682 |
| 68. Tests (T15) | 6913 | 867 | 12431 | 682 |
| 69. Notes (T16) | 6913 | 867 | 12431 | 682 |
| 70. Terminal shell and fonts | 6927 | 867 | 12603 | 682 |
| 71. A subagent's own pane | 6968 | 867 | 12938 | 682 |
| 72. Background shells | 7129 | 867 | 13225 | 682 |
| 73. Message a subagent from its pane | 7281 | 867 | 13322 | 682 |
| (Context card: one line over the bar) | 7281 | 867 | 13372 | 682 |
| 74. Hostile repositories and git (D2–D4, D9, D20–D25, D41, D57) | 7458 | 867 | 13411 | 682 |

Steps over the ~500-line tripwire (code and tests, without generated code): 71 (616, the subagent pane), 72 (652, background shells), 1 (533, the socket transport), 2 (1,502, the whole ACP client and its type generator), 5 (739, the question card), 6 (639, config options), 8 (537, the fake agent and the e2e test the step asked for), 10, 11 (1,249, the POC's look), 12, 18, 19, 29, 30, 45 (580, review comments), 47 (560, the queue), 52, 53, 54, 55 (880, terminals in the daemon), 56 (1,100, the terminal panel), 60 (720, trust). Step 33 and this milestone removed more than they added.

## Agent facts (claude-agent-acp 0.94.0, Claude Code 2.1.308–309)

What the code depends on, and how the adapter behaves. Everything Nushi does about it is in `internal/claude*`.

**Sessions**
- `session/new` requires `mcpServers`: send `[]`, never `null`. Claude starts a session in the mode its settings say; it reports modes both as legacy `modes` and as a `mode` config option (Nushi shows only the option). Config options: `mode` (Manual, Accept edits, Plan, Auto, Bypass permissions), `model` (Default, Opus 5.5, Fable 5.1, Sonnet 5.5, Haiku 5.5), `effort` (category `thought_level`), `fast` (category `model_config`, a select), `agent` (no category). `set_config_option` answers with the full set.
- Claude names a session itself soon after the first prompt (`session_info_update`); until then Nushi uses the prompt's first line. A fork is titled "<title> (fork)", a fork of a fork "(fork) (fork)": ignored, so a moved or rewound chat keeps its title. Asking `/context` before the first message makes Claude name the chat after it, so it isn't asked then.
- Claude keeps a session on disk only once it has a message: `session/load` of an empty one fails, and Nushi then starts a new one. `session/load` replays the user's and agent's messages and the tool calls (final status and output, `messageId`s included), not permission prompts or questions; a cancelled turn replays as "[Request interrupted by user]". It sends no `usage_update`. Loading takes under a second once npx has the adapter.
- Claude's history folder for a session is named after its cwd: the real path (symlinks resolved, `/tmp` is `/private/tmp`), NFC, every UTF-16 unit that isn't an ASCII letter or digit replaced by `-`; past 200 characters cut, with a base-36 hash of the path. `CLAUDE_CONFIG_DIR` moves the projects folder.
- `sessionCapabilities`: `fork`, `close`, `resume`, `list`, `delete`. `session/fork` copies the transcript into a new session on the same process (updates come tagged with the fork's id); with another `cwd` it fails, since it looks for the source only in the new folder's history, so a move copies the transcript there first ([ADR 0014](docs/adr/0014-moving-a-chat-forks-it.md)). After a fork the reported cost starts again near zero.
- Forking at a message: `_meta.jetbrains.air.fork = {version: 1, messageId}` on `session/fork` keeps the conversation up to that agent message, it included, for any client, after `session/load` too ([ADR 0020](docs/adr/0020-rewind-through-a-vendor-fork.md)). The adapter is recognized by `agentInfo.name` `@agentclientprotocol/claude-agent-acp`.
- `session/delete` (for clients that aren't AIR, which get archiving) deletes `<id>.jsonl` and `<id>/` in whichever project folder has them, succeeds for a session never written, and leaves the history folder behind. Deleting a session the process has open, or closing it, makes Claude write a ~700-byte stub back as it ends; a second delete a few seconds later removes it. So side chats ended other than by closing them are deleted by a fresh agent once the one they ran on has stopped.

**Updates**
- Every `agent_message_chunk` has a `messageId`; chunks group by it. Claude sends no `agent_thought_chunk`s here (thinking is "omitted" for recent models).
- A tool call arrives as a `tool_call` with a generic title and empty `rawInput`, then `tool_call_update`s with the real title, `locations` and content; each update's content replaces the last. A command's first content is its description, the last its output in a fence; a failed command's output starts with `Exit code N`. An `Edit`'s diff holds the snippet, not the file. One update carries only `_meta.claudeCode.toolResponse`. Claude searches and lists with `Bash`, not Grep and Glob.
- Plans (`plan` updates, the full list each time) come only when Claude's todo tools are on (`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in its environment); Nushi doesn't set it.
- `available_commands_update` (about 80 commands, plugins' and skills' too) comes after `session/new` and `session/load`. A command is an ordinary prompt starting with `/name`; a `resource_link` to a `file://` URI makes Claude read the file.
- Usage: each turn ends with two `usage_update`s, `{used, size}` and the same with `cost` (USD, the session's so far; not reliable across processes). One carried `_meta._claude/rateLimit`. The prompt result's unstable `usage` sums the turn's model calls.
- `session/cancel` ends the turn in a second or two with `cancelled`; streamed text stays. A command Claude ran in the background can finish later and Claude writes on its own, outside any turn.
- Permissions: in Manual mode Claude asks with "Yes" (`allow_once`) and "No" (`reject_once`); the request names the tool call sent just before. `.claude/settings.json` = `{"permissions":{"defaultMode":"default"}}` starts a folder in Manual mode, for testing.
- Questions (AskUserQuestion) need `elicitation.form` in the client capabilities: a `tool_call` ("Asking for your input"), then `elicitation/create` in form mode tied to it. Each question is `question_N`, a `string` with `oneOf` or an `array` with `items.anyOf`, followed by an optional free-text `question_N_custom` titled "Other"; nothing is `required`, and the properties must be read in wire order. An empty accept reads to Claude as "no answer".
- Subagents: with `_meta: {"subagent-transcript": true}` in `initialize`'s client capabilities, a subagent's tool calls, text and thinking all carry `_meta.claudeCode.parentToolUseId` (tool calls also `toolName`); the Agent call's `subagent_type` is in its `rawInput`, maybe in a later update. Background subagents: the Agent call completes at once with "Async agent launched…", and the subagent ends with a `SubagentHandback` call whose `rawInput.message` is its report (its own output is only an acknowledgement). After `session/load` the Agent calls come back, but not a background subagent's steps or report.
- Subagents (Claude Code 2.1.309): foreground subagents end with a `SubagentHandback` too, and their Agent call's output is then only a pointer ("This agent's report was delivered to you as a message from \"<agentId>\" (its SubagentHandback call)…"). The Agent call's `rawInput` comes in pieces over several `tool_call_update`s: `description`, `subagent_type`, `model` (`sonnet`, `haiku`, `opus`: the model option's values), `effort` (`low`…: the effort option's values), `prompt`, `run_in_background`; `model` and `effort` only when Claude picks them. The call's last update carries `_meta.claudeCode.toolResponse` with `agentId`, `agentType`, `resolvedModel` (`claude-sonnet-5-5`: the model it ran on, even when inherited), `totalDurationMs`, `totalTokens`, `totalToolUseCount`, `usage`, `handbackReport.text`; no effort. The subagent's own updates carry only `parentToolUseId` and `toolName`, no model. `session/load` replays the Agent call with its whole `rawInput` but no `toolResponse`, and no subagent's steps or report, foreground ones included. `async_task_*` updates go only to AIR clients; the ACP subagents RFD form (child sessions) only to clients that advertise `subagents` (see Later ideas).
- Background shells (what a client that isn't AIR sees): a Bash call with `rawInput.run_in_background: true` completes at once; its last update's `_meta.claudeCode.toolResponse.backgroundTaskId` is the task's id and its output text says "Command running in background with ID: <id>. Output is being written to: <tmp>/claude-<uid>/<project>/<session>/tasks/<id>.output. You will be notified when it completes. To check interim output, use Read on that file path." That file fills as the command writes and ends with "[exited with code N]" or "[killed]". Claude 2.1.309 has no BashOutput (it said so, and reads the file with Read); stopping is the deferred `TaskStop` (found through `ToolSearch`), input `{task_id}`, response `{message, task_id, task_type: "local_bash", command}`. When a command ends, Claude gets a task notification the client never sees; Claude then runs a turn of its own, whose last `usage_update` has `_meta._claude/origin = {kind: "task-notification", producer: "session-task", runId}`, naming no task. `async_task_*` updates and the `_meta.jetbrains.air` `backgrounded` marker go only to AIR clients. A client that sets `_meta.terminal_output: true` in its capabilities gets Zed's terminal extension instead: every Bash call's output moves to `_meta.terminal_output` (content becomes a terminal reference), and a background command's `terminal_exit` (exit code null) comes when its task ends; Nushi doesn't use it, since it would change how every command reads. Background commands outlive Claude: after the daemon stopped (and Claude with it), `sleep 300` still ran, and its file never got an end line.
- Messaging a subagent: claude-agent-acp 0.94.0's child sessions (the RFD form) take only `cancel`; a v1 client has no way to prompt one. Claude Code 2.1.309's deferred `SendMessage` tool (`{to: <agentId>, message, summary, type: "message"}`) reaches a subagent by the id the Agent call's result gives (a background call's output ends "agentId: <id>"; a foreground one's names it in its pointer to the report; `toolResponse.agentId` too). It answers `{success, message: "Resuming agent …", resumedAgentId}`: a finished subagent runs again under its first Agent call (its steps carry that call's `parentToolUseId`) and ends with another `SubagentHandback`; a running one takes the message as it goes. Tried five times (three finished, one running, one finished after a daemon restart): Claude passed the text verbatim each time and the subagent acted on it; Claude then relays the reply in its own words, sometimes adding its own checks.
- Steering: `initialize`'s `_meta.steering.supported` advertises `_session/steering`, answered `injected` while a turn runs or `promptRequired` (doing nothing). An injected message pre-empts the model and moves a foreground tool to the background, so Nushi steers right after a tool call ends; the running prompt ends once the steered messages are answered; the adapter echoes nothing.
- `/context` is answered by the adapter itself (no model call, no cost), as agent text, twice (two message ids, the same markdown): "Context Usage", then an "Estimated usage by category" table (System prompt, System tools, MCP tools, MCP server instructions, MCP tools (deferred), System tools (deferred), Custom agents, Memory files, Skills, Messages, Free space, Autocompact buffer; counts like `2.5k`, `934.6k`), then more tables. Claude keeps the answer in the conversation (5–7k tokens each time), so it runs in a throwaway fork (about 1.3 s; same numbers within 0.2k). It isn't replayed.
- The adapter logs progress on stderr; nushid copies it into its log.

**MCP config (Claude Code 2.1.309)**
- User scope: `mcpServers` in `~/.claude.json` (or `$CLAUDE_CONFIG_DIR/.claude.json`, whose credentials go to a keychain item of their own). Local scope: `projects[<project>].mcpServers` in the same file, the project being the repository (its main checkout for a worktree) or the folder outside git. Project scope: `.mcp.json` in the folder or any folder above it.
- `claude mcp list` (no JSON form): "Checking MCP server health…", then `<name>: <command or URL> - <status>` per server (`✔ Connected`, `! Needs authentication`, `✘ Failed to connect — why`, `⏸ Pending approval`, `⊘ Disabled for this project`); remote URLs end ` (HTTP)`/` (SSE)`, connectors are `claude.ai <name>`, plugins' servers `plugin:<plugin>:<server>`. It starts every server; about a second. Stored configs (and `claude mcp get`) hold env and header values in clear.
- `claude mcp add-json` checks the name (letters, digits, `-`, `_`) and refuses an existing name or an unreadable config, exit 1; `remove` of a missing name too; both take `--`. `claude mcp login` needs a terminal on stdin (`script -q /dev/null` gives one), opens the browser and waits; `logout` fails for a server without OAuth.
- Approvals: `enabledMcpjsonServers` in an untracked `.claude/settings.local.json` counts only in a folder trusted in the terminal (`hasTrustDialogAccepted`); `disabledMcpjsonServers` (any settings file) rejects a server everywhere and `claude mcp list` leaves it out. `disabledMcpServers` in a settings file does nothing. The local settings file is at the repository's root.
- A chat loads its MCP servers when its session starts or loads and keeps them; it loads a "Pending approval" `.mcp.json` server without asking. MCP tools are deferred.

## Decisions to revisit

Open questions; what's settled is in `docs/adr/` or in the code.

- New in Q: a worktree's ignored files (`.env`, `node_modules`, build output) count as work that removing it loses: a fresh chat that leaves it keeps it, and Delete asks to force, naming how many. Changes stops reading file contents after 32 MB of text in one view (the rest say so); a nested repository and a submodule show as not shown, not as an error. A worktree whose base branch is gone counts from the commit it started from (worktrees made before Q: from the default branch).

- New in P: a message for a subagent goes to the main session as a prompt (steered or queued like any) asking Claude to pass it on unchanged with SendMessage ([`claude.Relay`](internal/claude/relay.go)); the transcript shows only the message, as "You → Explore, through Claude", also after a reload (the prompt is read back). Claude's history holds the whole wrapped prompt, so `claude --resume` in a terminal shows it. A subagent with steps after its last report runs again ("running").
- New in P: background commands are followed through Claude's output file (Claude's format, in `internal/claude`), polled each second; "running" only while the file has no end line and the agent that started it still runs, else "started" (it may well still run: Nushi can't tell). The Agents card is now "Background tasks", so a collapse or place it had under "Agents" is forgotten; its finished group reads "n earlier" when it holds a command whose end isn't known.
- New in P: a subagent's pane replaces the details panel; × closes the side panel altogether (the details panel too, as Claude Code's does), Back returns to the cards. A finished subagent's pane opens at the top (its prompt), a running one follows its latest step. "Inherited" model and effort are the chat's now, not when the subagent started; the Agents card's tag doesn't mark them as inherited (its tooltip does). The pane's wide width is its own (`subagent`), the narrow one the details panel's.

- New in O: the daemon decides a background subagent ran only if it saw it start; times are the daemon's clock, so they survive an app restart but not a daemon restart. The default model is "Default…" by name (Claude's), and an "Other" field is `<id>_custom` (Claude's).
- New in O: the app tells an older daemon only "Restart daemon"; nothing degrades gracefully any more (ADR 0004). A daemon newer than the app keeps working.
- Diffs: a side over 10,000 lines isn't diffed; over 20,000 characters is computed in an isolate; a side over 200,000 characters isn't highlighted; the daemon skips files over 1 MB a side.
- Markdown is healed and reparsed whole on each streamed chunk: fine for replies of a few thousand words.
- Copying a selection across blocks (paragraph, code, table) loses the line breaks between them (Flutter's `SelectionArea`).
- MCP masking is a display heuristic: a secret in a shape it doesn't recognize shows. Editing a server with hidden values works only if the config is otherwise unchanged; else they must be typed again.
- The trust card is advice the daemon doesn't enforce ([ADR 0023](docs/adr/0023-warn-before-a-folder-runs-code.md)); the token stays readable by the agent ([ADR 0024](docs/adr/0024-the-agent-can-read-the-token.md)).
- Modes have no warning styling: the adapter doesn't tag Bypass permissions, and naming it would be a per-agent table.
- Review comments are the app's (`reviews.json`), not the daemon's: they don't follow a chat to another Mac.
- A message sent while a chat reopens, rewinds or moves waits in the queue rather than being refused.
- Whether the agent can delete its history is learned by starting it once per daemon run, the first time a Delete dialog opens.
- Terminals: Option is always Meta; ⌘-click opens a path relative to where the terminal started, not the shell's current folder; ⌘K clears only the emulator.
- Drops onto the chat (`desktop_drop`) were never tried by hand.

## Later ideas

- Show the plan's usage limits (session and weekly) for subscription users, if the agent exposes them. ACP doesn't today; claude-agent-acp 0.94.0 did put a `_meta._claude/rateLimit` (five-hour and seven-day utilization) on one `usage_update` (see ACP quirks), which isn't a stable interface.
- Plain model chat with no agent (no tools, no folder) straight to an API or gateway with a key. Nushi would then own the history and model settings. For agent chats a gateway or key already works through Claude's own settings (`ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY` or `apiKeyHelper` in `~/.claude/settings.json`).
- Open a session started outside Nushi (e.g. `claude` in a terminal) as a chat: list the agent's sessions per folder through ACP `session/list` (claude-agent-acp 0.94.0 has it, under `sessionCapabilities`), pick one, and `session/load` it. No copy: the agent's history stays the source. Mind a session that's still open in a terminal (two writers to one transcript).

- Git actions from the Changes view: stage and unstage files or hunks, commit with a message, maybe push. It's read-only toward git for now ([ADR 0019](docs/adr/0019-changes-read-only-toward-git.md)); doing it would mean revisiting that ADR (git writes next to an agent that may be writing too).
- More agents: first ACP-native ones (opencode `opencode acp`, Gemini CLI, Codex through its adapter, goose), several of which can use Fireworks/DeepSeek; this proves the agent picker, non-Claude model and effort controls, and features that switch off when an agent lacks fork, steering or `/context`. Then Ante (installed on the test Mac, `~/.ante/bin/ante` 0.2.14, Fireworks/DeepSeek configured): it doesn't speak ACP; `ante serve --stdio` uses its own JSONL protocol (`OpMsg` in, events out), so it needs a small bridge to ACP shipped with Nushi, best once that protocol is documented or Ante gains an ACP mode. A coworker of the owner has Ante working with something custom: ask how before researching. Nushi never reads the agents' keys; each agent reads its own config.
- Subagents as ACP child sessions (the RFD form claude-agent-acp offers a client that advertises `subagents`): a background subagent's steps after a daemon restart, and a stop button per subagent. See step 51.

## Dependencies

- Go: `connectrpc.com/connect` v1, `google.golang.org/protobuf`, buf through `go run` (codegen), `github.com/creack/pty`, `golang.org/x/sys/unix`.
- Dart: `connectrpc` (with `http2` 2.x: 2.0.1 doesn't resolve with 3.x), `protobuf`, `flutter_markdown_plus`, `markdown`, `re_highlight`, `url_launcher`, `file_selector`, `pasteboard`, `desktop_drop`, `xterm2` (MIT; brings `xterm2_core`, `zmodem`, `quiver`, `equatable`, `convert`); fonts IBM Plex Sans and JetBrains Mono (OFL), and Symbols Nerd Font Mono from Nerd Fonts 3.5.1 (MIT; its icons come from projects under their own licenses, listed in the Nerd Fonts repository), bundled.

## Security notes to look at

- Agents run as you, through `npx --yes @agentclientprotocol/claude-agent-acp@0.94.0` (pinned by version, not hash), started in the daemon's data folder so a project's `node_modules` or `.npmrc` can't swap it. A chat's folder reaches the agent only as `cwd`.
- A panic on something the agent sent becomes a JSON-RPC error; a malformed form is refused.
- `ListFiles` lists any absolute folder a client names (names, 20,000 at most); mentioned files go to the agent as `file://` links.
- Git runs as you in the folder a client names: `core.fsmonitor` off, `--no-ext-diff`/`--no-textconv`, hooks off (`core.hooksPath=/dev/null`), signature checks off, no lazy fetch of a partial clone's missing objects (`GIT_NO_LAZY_FETCH=1`: the fetch would run the transport the repository's config names), no status inside submodules or nested repositories (`--ignore-submodules=dirty`, which would run their filters), the panel's status without the repository's own filter drivers; Changes and new worktrees still run them (git-crypt, lfs). Nushi writes into a repository only `.worktrees/` and `info/exclude`, never through a link there. Files are read only when regular, and at most 1 MB of each (64 MiB for Claude's settings and `.mcp.json`). Names starting with `-` are refused as bases and commits. Worktree removal and `branch -D` force only when the request says so, which the app sends only after showing what would be lost; the daemon checks again.
- Agent markdown: local images only from regular files of 20 MB at most, remote ones after a click; links open http(s) only, in the browser.
- Moving a chat writes a copy of the transcript (0600) into Claude's projects folder for the fork, then removes it; never replaces one there.
- MCP: Claude's config holds secrets in clear; the daemon masks them before they leave it. It runs `claude mcp add-json/remove/login/logout` (names checked, `--`), so a client can add a server Claude runs as you, as a prompt could. The on/off switch writes the project's `.claude/settings.local.json` (its two MCP lists only, atomically, keeping its mode) and may add it to `.git/info/exclude`.
- Terminals: any client with the token can open a shell as you anywhere; they must stay off remote access ([ADR 0022](docs/adr/0022-the-daemon-owns-terminals.md)). Closing kills what has the terminal as its controlling terminal.
- Background shells: the daemon reads the output file a Bash call's output names (only a regular file, no link, named `<task id>.output` in a `tasks` folder; its last 64 KB), once a second while the command runs, and shows it in the app.
- Trust reads `~/.claude.json`, never writes it; "Start anyway" goes to Nushi's `trusted.json`. Trust of the home folder (or `/`) covers that folder only, never the folders under it, and `~/.claude` is never listed as the home folder's own.
- The token (0600, made again if empty or short) sits beside the socket in a 0700 folder; anything running as you, the agent included, can read it.

## Working notes

- Screenshots of the app window are current only while it's in front: macOS stops Flutter drawing an occluded window.
- To watch the fake agent in the app: build `acp/acptest/fakeagent`, put an `npx` that execs it first on `PATH`, and start a daemon with that `PATH` and `NUSHI_DATA` (a short path: the socket path has a length limit). Its scripts answer prompt words: `permission`, `question`, `think`, `pwd`, `many`, `plan`.
- Terminals: the shell is the user's login shell from `id -P` (the user database), never the daemon's `$SHELL`. fish 4 asks the terminal's Primary Device Attributes as it starts and waits 10 seconds for the answer; the app answers queries in a replay only for a terminal it opened itself (anyone attaching later would answer twice).
- App tests get a data folder in the temporary folder (`FLUTTER_TEST`); never point them at the real one.
