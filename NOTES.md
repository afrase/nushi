# Notes

## Summary (2026-10-24, after step 91: milestone R)

Milestone R fixed D62–D121 of the deep review (`~/Developer/nushi-deep-review-findings.md`) in steps 81, 82, 86 and 88–90, did the help-text pass in step 91, and fixed three rounds of security-review findings on the trust card in steps 83–85 and 87 (S1–S9: a `.mcp.json` that can't be read, and a skill's hooks, see "Security notes"). One commit each on `main`, all pushed. `make test` passes (Go with `-race` for the chats, e2e and acp packages too). Most fixes have a regression test that was checked to fail without the fix (by undoing it: the mutations named in D62, D63, D112–D119, and the new guards). The fakes now catch what they hid: acptest keeps history per folder (load and fork find a session only under the request's cwd; the e2e move copies through it), answers prompts and config only for sessions it opened, and ends its scripts on `session/cancel`; the chats fake runs a process per launch, which Stop ends, after any last words.

**By id**
- Fixed: D62–D76, D78–D80, D82–D92, D94, D96–D102, D104–D107, D109–D119, D121.
- Same bug as another: D77 (D75, fixed once: events held while the list is on its way), D93 (D86), D120 (D105).
- Already fixed in Q (checked against the code): D81 (the "New worktree" choice is saved after the move), D103 (a fresh chat's move keeps on record a worktree that holds work), D108 (Archive keeps the queue, held). Partly in Q: D84 (a folder inside the worktree; R adds other chats and terminals), D85 (nil checks, ids never reused; R cancels a pending prompt on Reload), D95 (the catch's guard; R guards the clear too), D121 (the fork itself; R the rewind's new session and close).
- Partly done: D88 doesn't replace the earlier failure notice (it no longer repeats: one per try the user starts). D90's ranking of up to 20,000 files on each keystroke stays (the stale list and the wrong folder are fixed). D114's GIT_ scrub in `worktreeSet` has no test: no way found for the environment to change what `git config --file` reads. D116: the guard in `chat()` stays untested; each method it covers refuses on its own.
- Nothing deferred, nothing found wrong.

**Tried by hand** (dev daemon and app on `NUSHI_DATA`, a `/tmp` link, live Claude, two throwaway repositories, 1280×800 dark): the trust card for a `.mcp.json` Claude's parser would reject (its text shown) and a skill's hooks (its front matter in a box that scrolls), and its shorter text; Start anyway, then a real turn; the "A newer daemon is installed" bar after a rebuild, and Restart daemon (the chat reopened); the Delete dialog's shorter lines; the MCP view; the context card's "Not reported yet" after a reopen.

**Not tried by hand**: the Delete dialog during a slow delete (it finished too fast to catch; `PopScope` and a disabled Cancel), a failed daemon launch and a nushell login shell, the Send review list and a review taken out of the queue, a half-written comment kept across files (no test either: the comment box didn't open under the test's tap), @ completions refetching, a call's output staying open as the next call makes a group, the MCP form opening as JSON, title reports in a live terminal (an app test covers it), D70 in a terminal tab (a daemon test covers it), and the light theme.

**Needs your attention**
- The API went from 42 to 43 (Ping reports the daemon's build): press "Restart daemon" in the installed app. From now on the app also offers a restart, in a bar, when it bundles another build of the daemon than the one running.
- Product calls, in "Decisions to revisit" under "New in R": a fresh chat's worktree stays while another chat or a terminal is in it; a failed reopen isn't retried on its own; Send now goes before the queue; "Send review" lists every unsent comment; a `.mcp.json` Claude would skip is left out of the MCP list but shown on the trust card.
- Security: the trust card fails closed (S1–S9). A skill whose front matter has hooks (by text or YAML key) shows it raw instead of the commands Nushi guessed; a `.mcp.json` Nushi can't read shows whole. That added `gopkg.in/yaml.v3`.
- The app's launcher passes the daemon's paths as `NUSHID_BIN`/`NUSHID_LOG`; the daemon's children (agents) inherit them. Harmless, but visible in `ps`.

**Size**: the daemon went from 7,813 to 8,128 lines of Go, the app from 13,624 to 13,918 lines of Dart (the ACP client stays at 929). Every step stayed under the ~500-line tripwire (the largest, 81, added 468 lines, nearly all tests). Files at the ~400-line tripwire: `app/lib/daemon.dart` (400, after the launcher moved out), `internal/git/git.go` (400), `internal/model/model.go` (400), `internal/features/chats/chats_test.go` (401); `chats.go` went past it and was split (`close.go`).

**Dependencies**: `gopkg.in/yaml.v3` (Go, step 87: a skill's front matter for the trust card).

**Left behind by the testing**: nothing (the dev chats deleted with Delete; the empty history folders Claude left, the dev data folder, its `/tmp` links and the throwaway repositories removed; the helper tools stay in the session's scratchpad).

## Demo (milestone R)

1. Put a `.claude/skills/x/SKILL.md` with a `hooks:` block in a repository and start a chat there: the trust card shows the skill's front matter, raw, in a box that scrolls.
2. Rebuild and reinstall the app while its daemon runs: a bar says a newer daemon is installed, with Restart daemon.
3. Queue a review while Claude works, then take it out of the queue: its comments count as unsent again.
4. In a worktree chat without messages, open a terminal, then move the chat back to the repository: the worktree stays, and Delete offers it.
5. Open a chat whose folder is gone: one "Couldn't reopen" notice, not one per look.

## Demo (milestone Q)

1. In a repository, ask Claude in Manual mode to run a long command that writes a file: the permission card shows the whole command, wrapped.
2. Open a terminal in the chat, run `sleep 300`, then pick Archive: it asks first, naming `sleep 300`.
3. With the terminal focused, ask Claude to use AskUserQuestion: Enter and digits stay in the terminal.
4. Ask Claude to run a 30-second foreground command, then stop the daemon: the command ends at once; after a restart the chat shows it interrupted.
5. In Changes, an untracked repository inside the folder reads "Not shown: … is a repository of its own" instead of failing the view.

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
| 75. Processes and throwaway sessions (D1, D10, D12, D13, D27, D29, D45, D54, D60, D61) | 7604 | 929 | 13411 | 682 |
| 76. A chat's life (D5, D7, D11, D26, D28, D35, D46–D52, D55, D56, D58) | 7722 | 929 | 13411 | 682 |
| 77. Turns (D14–D16, D34, D42, D59) | 7782 | 929 | 13413 | 682 |
| 78. MCP (D17, D18, D44) | 7801 | 929 | 13451 | 682 |
| 79. The app: cards, composer, side chats, moves (D6, D8, D19, D30–D33, D39, D43, D53) | 7813 | 929 | 13612 | 682 |
| 80. Review comments and the Changes view (D36–D38, D40) | 7813 | 929 | 13624 | 682 |
| 81. Fakes and tests that couldn't fail (D62, D63, D112–D119) | 7813 | 929 | 13624 | 682 |
| 82. Hostile repositories, git and Claude's files (D72–D74, D76, D82, D83, D89, D92, D104) | 7888 | 929 | 13624 | 682 |
| 83. The trust card fails closed (security review S1, S2) | 7953 | 929 | 13624 | 682 |
| 84. Skill hooks read as YAML (security review S3, S4) | 8017 | 929 | 13624 | 682 |
| 85. A skill's front matter shown raw (security review S5–S7) | 7897 | 929 | 13624 | 682 |
| 86. Processes and throwaway sessions (D69–D71, D84, D87, D88, D105, D107, D120, D121) | 8026 | 929 | 13624 | 682 |
| 87. A skill's hooks found by YAML key too; files shown whole (security review S8, S9) | 8075 | 929 | 13658 | 682 |
| 88. Turns and a chat's agent (D64–D68, D85, D86, D93, D109) | 8105 | 929 | 13658 | 682 |
| 89. The app's link to the daemon (D75, D77–D80, D106, D110, D111) | 8128 | 929 | 13788 | 682 |
| 90. The app's views (D90, D91, D94–D102) | 8128 | 929 | 13962 | 682 |
| 91. Help text: less of it | 8128 | 929 | 13918 | 682 |
| 92. Agents as a list | 8235 | 929 | 13918 | 682 |
| 93. The agent's environment (ADR 0028) | 8235 | 929 | 13918 | 682 |
| 94. Codex's dialect, and a Codex-shaped fake | 8302 | 929 | 13918 | 682 |

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

- New in R: step 91 cut the app's help text to what the screen can't show: what a destructive action loses, why something is disabled, warnings and errors. Tooltips that restated a label went; empty states are a few words.
- New in R: "Send review" lists every unsent comment, those on files the view no longer shows too, each with Remove; comments sent in a review that leaves the queue without reaching the transcript (Stop, Archive, taken out) count as unsent again. A comment half written stays when its file leaves the view, until it shows again (while the app runs). A tool call's output left open stays open as the next call makes it a group. The MCP form shows a server's JSON when an argument has a line break, is empty or isn't text. Terminals ignore title reports (`CSI 20/21 t`).
- New in R: the app offers "Restart daemon" in a bar (not a blocking screen) when the daemon it bundles isn't the one running (same API, another build: its size and time). The bundled daemon starts through the login shell only for sh, zsh, bash, fish, dash and ksh (else zsh), with its paths in the environment; after three failed starts the app says so, with the log's path. A chat that finishes starting after you went elsewhere (another chat, a trust card, the MCP view) doesn't take the screen. The Delete dialog can't be closed while it deletes.
- New in R: Send now stops only the turn running when it came; if that turn ends on its own meanwhile, the message still goes next, before the queue. Reload cancels a permission prompt or question Claude asked on its own. A message taken back (Stop, Rewind, the queue) keeps its file mentions, and a side chat's queue can be edited.
- New in R: a fresh chat moving out of its worktree keeps it (on record for Delete) while another chat or any terminal is in it, the chat's own included. Delete closes the chat's terminals before it removes a worktree. A reopen that fails isn't tried again on its own: the next message, Reload, Unarchive or a move tries again; a reopen gives up after 2 minutes. Once the daemon is stopping, no agent starts, and one still opening is closed.
- New in R: a `.mcp.json` that can't be read (malformed, not a regular file) is left out of the MCP list, as Claude leaves it out; only the daemon's log says so. The trust card still lists it ("MCP servers Nushi couldn't read", with its text) and asks. A skill whose front matter has hooks shows its front matter on the trust card, raw: the word anywhere in it, a key YAML reads as hooks in any case at any depth of any of its documents (aliases and merges resolved, `gopkg.in/yaml.v3`), or YAML that doesn't decode. Nushi no longer guesses which commands Claude reads out of it (steps 82–85 left gaps each time). Front matter ends at a line of `---` alone; without one, the whole file counts. A file the card shows is shown whole, in a box that scrolls; past 256 KB only where it is. A background command's end line counts once the output file stops growing after it.

- New in Q: a question card takes the keyboard only from nothing, an empty box on the same screen, or another card: never from a terminal, a dialog or text being written. A pending permission shows its whole command, wrapped; an opened command's card shows it whole too. Archive asks first when a program runs in one of the chat's terminals. A message taken back from a subagent's queue (or by Stop or Rewind) keeps its subagent, as a chip; a replayed one can't, and says so. The "New worktree" choice is remembered only once the move worked.
- New in Q: MCP changes run to the end once begun, even when the app goes. A project server that's off or not approved gives way to a user or local one of its name, as in Claude. The MCP card says "Not checked" and why after a failed check, with Try again, and a list older than 5 minutes is asked for again when the card or view shows it.
- New in Q: a user message the agent answered without words (stopped, failed, only tool calls) can't be rewound past: the next message isn't rewindable. A background command is followed only when Claude's structured result names its task (or, replayed, its input asked for the background), never from a tool's text; the "moved to the background" variants count. Stop (and a permission or question card) also ends a turn Claude started itself; Rewind waits for it.
- New in Q: Move is refused while Claude works on its own (a turn it starts after a background command ends, seen as updates outside a turn of Nushi's, until that turn's usage report); a chat whose reopen failed is replayed once moved. A fresh chat moved into a folder of its own worktree keeps the worktree. A worktree chat can't start in a folder the repository doesn't track (the worktree wouldn't have it). What ran on an agent that's gone (calls without a result, background subagents) shows as failed, also after a replay. The scratch chats' history from the Nushi Next days is moved, not copied: a stale old copy goes at the daemon's start, when the new one holds all of it.
- New in Q: stopping the daemon cancels running turns and gives each agent up to 5 s to end it, then closes its input (claude-agent-acp then ends its sessions) and kills it after 5 s more; Archive, Delete, Reload and Move stop agents the same way. Archiving keeps the queued messages, held: they wait after Unarchive until you send something or the next turn ends. Side chats end when no app has followed the daemon for 2 minutes. A message over about 30 MB (images in base64) is refused before it joins the transcript.
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

- Go: `connectrpc.com/connect` v1, `google.golang.org/protobuf`, `gopkg.in/yaml.v3` (step 87: skills' front matter, for the trust card), buf through `go run` (codegen), `github.com/creack/pty`, `golang.org/x/sys/unix`.
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
- Trust lists any string setting named like Claude's credential helpers (`…Helper`, `…AuthRefresh`, `…CredentialExport`), a skill's raw front matter whenever it has hooks (by text or by YAML key), and a `.mcp.json` it can't read or parse (each whole, or past 256 KB where it is): it fails closed. The MCP list leaves such a file out, as Claude does.
- Trust reads `~/.claude.json`, never writes it; "Start anyway" goes to Nushi's `trusted.json`. Trust of the home folder (or `/`) covers that folder only, never the folders under it, and `~/.claude` is never listed as the home folder's own.
- The token (0600, made again if empty or short) sits beside the socket in a 0700 folder; anything running as you, the agent included, can read it.

## Working notes

- Screenshots of the app window are current only while it's in front: macOS stops Flutter drawing an occluded window.
- To watch the fake agent in the app: build `acp/acptest/fakeagent`, put an `npx` that execs it first on `PATH`, and start a daemon with that `PATH` and `NUSHI_DATA` (a short path: the socket path has a length limit). Its scripts answer prompt words: `permission`, `question`, `think`, `pwd`, `many`, `plan`, `wait` (until stopped).
- Terminals: the shell is the user's login shell from `id -P` (the user database), never the daemon's `$SHELL`. fish 4 asks the terminal's Primary Device Attributes as it starts and waits 10 seconds for the answer; the app answers queries in a replay only for a terminal it opened itself (anyone attaching later would answer twice).
- Driving the app by hand: System Events' `click at` doesn't reach a Flutter window; a few lines of Swift posting `CGEvent` mouse and key events do. Screenshots are 2× the window's points.
- App tests get a data folder in the temporary folder (`FLUTTER_TEST`); never point them at the real one.
