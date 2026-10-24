# Notes

## Summary (2026-10-24, after step 100: milestone T)

Milestone T added Ante and oh-my-pi (omp) as agents, in steps 98–100 plus three rounds of security fixes. One commit each on `main`, all pushed. `make test` passes.

- **Ante** runs through a bridge of Nushi's own (`nushid ante-acp`, ADR 0030), not `ante-acp`: there was no newer `ante-acp` than 0.2.0 (no commits to it since 2026-09-30; Ante 0.2.15 came out 2026-10-23 with nothing for ACP), and a first cut at filling its gaps upstream was dropped for the bridge. The bridge maps Ante 0.2.14's `serve` protocol (one `ante serve --stdio` per session) to what Nushi uses; nothing outside `internal/ante` knows that protocol.
- **oh-my-pi** speaks ACP itself (`omp --mode acp`). It needs Bun, so it starts as `npx --yes -p bun@1.4.3 -p @oh-my-pi/pi-coding-agent@18.12.6 omp --mode acp` (both pinned): npx puts the Bun omp's `#!/usr/bin/env bun` finds on the PATH.
- **Seams fixed rather than special-cased**: `Dialect.Context` (an agent says what fills its context through an extension of its own: no throwaway fork), `Agent.Call` for extensions, the agent's side of ACP in `acp` (`Peer`), and one package for the trust card's files (`internal/folderfiles`, which `codextrust` now uses too). Each new agent is otherwise its package(s), a dialect and a launch entry.

**Features per agent**

| | Claude | Codex | Ante | oh-my-pi |
|---|---|---|---|---|
| Reopen after a daemon restart | yes | yes | yes (the resume's replay) | yes |
| Side chats (fork) | yes | yes | yes (whole, while Ante is idle) | yes (whole) |
| Rewind | yes | yes (cuts after the turn) | yes (cuts after the turn) | no (no fork at a message) |
| Move to another folder | yes | yes | no | no |
| Steering | yes | yes | yes (taken at the next step) | yes |
| Stop | yes | yes | yes | yes |
| Permissions | modes | modes | strict/auto/yolo; Allow, Allow for this session, Deny | bash, delete and move ask; writes never do (not mode-driven) |
| Questions | yes | Plan mode only | yes (AskUser) | yes (its ask tool) |
| Model, effort | yes | yes | yes (the provider's catalog models; effort when the model reasons) | yes |
| Usage | used/size, cost, last turn | used/size, last turn | used/size, last turn | used/size, cost, last turn |
| Context breakdown | yes (`/context`) | no | yes (`ContextReport`) | no |
| Delete takes the history | yes | archives | yes | no (omp has no delete; the dialog says so) |
| Resume in a terminal | `claude --resume` | `codex resume` | `ante --resume` | `omp --resume` |
| Trust card | `.claude`, `.mcp.json` | `.codex` | nearest `.ante/settings.json` | every file omp loads code or settings from |
| MCP view | yes | a note | a note | a note |
| Subagents, background shells | yes | no | no | no |

**Tried by hand** (the packaged app and a dev daemon on `/tmp/ndt`, `FIREWORKS_API_KEY` only in the dev daemon's environment, `HOME` a temp folder for omp, `ANTE_HOME` the real `~/.ante`, read-only; DeepSeek V4.1 Flash; scratch folders): an Ante chat (New Ante chat, model picked, a Write with its diff and permission, a Bash command, an AskUser question, steering into a running `sleep 8`, Stop during `sleep 30`, reopen after a daemon restart, Rewind, Delete taking both of Ante's sessions), and an omp chat (model and effort picked, a command with its permission, a question with omp's Other, steering, Stop, reopen after a restart, Delete saying omp keeps its history). The bridge and omp were also driven over ACP by script (load, list, fork, close; omp's `session/delete` answers "Unknown ACP ext method").

**Not tried by hand**: `ante --resume` and `omp --resume` in a terminal; the trust cards for Ante and omp in the app (unit tests cover them); side chats and moves for Ante and omp; images for either; a multi-select AskUser; "Allow for this session" and Ante's auto mode; omp's Plan mode; a Claude or Codex chat beside them in this run (the dev daemon's `HOME` was a temp folder); a missing `ante` or Bun; Ante 0.2.15 (this Mac has 0.2.14); the light theme.

**Needs your attention**
- No API bump (still 44), but the daemon changed: press "Restart daemon" in the installed app after `make install`.
- Set-up: "Ante and oh-my-pi for you" below. Nothing to install for either; omp's first start downloads Bun and omp (about 10 s).
- Product calls, in "Decisions to revisit" under "New in T". Security: "Security notes" (the bridge, omp's project code).

**Size**: the daemon went from 8,630 to 10,862 lines of Go (the bridge is about 1,500 of them; steps 98 and 99 were over the ~500-line tripwire), `acp` from 929 to 975. The app didn't change.

**Dependencies**: none new.

**Left behind by the testing**: nothing. The dev chats were deleted with Delete; Ante's test sessions went with them, and the bridge runs' logs (`~/.ante/logs/2026-10-24/ante.{65796,71140,71141,71591,71592,71669,71670,71717}.log`) and `~/.ante/run/` (one finished background job) were removed; `~/.ante/settings.json`, `catalog.json`, `versions.json`, `user_input_history.jsonl` and `tip_history.json` are unchanged (checksums), and the rest of `~/.ante` is as it was. The temp Ante and omp homes, npm caches, the dev data folder, the Ante clone and the omp source were removed; no `~/.omp` was made. The Fireworks key is in no file under them, the scratchpad or the repository (checked with grep, the key on stdin).

## Demo (milestone T)

1. Open the menu beside "New chat" and pick Ante: the header says Ante with its model; the Context card shows Ante's own breakdown before any message.
2. Pick DeepSeek V4.1 Flash, ask Ante to write a file: a permission card with the diff (Allow, Allow for this session, Deny).
3. Ask Ante to use AskUser: a question card with an Other field.
4. Restart the daemon and open the chat: it comes back from Ante's session; Rewind on a message forks Ante's session after the turn before it.
5. Pick oh-my-pi: model and effort pickers from omp; a command asks first; Delete says omp keeps its history.

## Demo (milestone S)

1. Open the menu beside "New chat" and pick Codex: the button now reads "New Codex chat", and the header says Codex with DeepSeek V4.1 Flash; the pickers show the mode (Read-only, Workspace access, Auto review, Full access), the model and the effort.
2. In Read-only, ask Codex to run `printf hi > x.txt`: a permission card, then the command and its output in the transcript.
3. While Codex runs `sleep 8`, send another message: it goes into the running turn.
4. Restart the daemon and open the chat: it comes back from Codex's history; `codex resume <session id>` opens it in a terminal.
5. Put a `.codex/config.toml` in a repository and start a Codex chat there: the card shows the file whole.

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
| 95. Picking an agent in the app | 8302 | 929 | 14023 | 682 |
| 96. Trusting a folder for Codex (ADR 0029) | 8532 | 929 | 14031 | 682 |
| (96's security fixes) | 8623 | 929 | 14042 | 682 |
| 97. A Codex chat end to end, and the docs | 8630 | 929 | 14052 | 682 |
| 98. Ante's bridge (ADR 0030) | 10409 | 975 | 14052 | 682 |
| (98's security fixes) | 10517 | 975 | 14052 | 682 |
| 99. Ante and oh-my-pi as agents (ADR 0031) | 10784 | 975 | 14052 | 682 |
| (99's security fix) | 10852 | 975 | 14052 | 682 |
| 100. Ante and oh-my-pi by hand, and the docs | 10862 | 975 | 14052 | 682 |
| 101. Memory and speed measured; agents without npx's process | 10909 | 975 | 14052 | 682 |
| 102. Sleeping chats in the daemon (ADR 0032); API 45 | 11186 | 984 | 14052 | 682 |
| 103. Sleep in the app: menus, the sidebar's mark, the setting | 11186 | 984 | 14138 | 682 |
| 104. A status bar: agents and memory; API 46 | 11328 | 984 | 14373 | 682 |

Steps over the ~500-line tripwire (code and tests, without generated code): 98 (2,384 with its tests: Ante's whole bridge and its fake), 99 (901: two agents, two trust packages, the shared trust files), 71 (616, the subagent pane), 72 (652, background shells), 1 (533, the socket transport), 2 (1,502, the whole ACP client and its type generator), 5 (739, the question card), 6 (639, config options), 8 (537, the fake agent and the e2e test the step asked for), 10, 11 (1,249, the POC's look), 12, 18, 19, 29, 30, 45 (580, review comments), 47 (560, the queue), 52, 53, 54, 55 (880, terminals in the daemon), 56 (1,100, the terminal panel), 60 (720, trust). Step 33 removed more than it added.

## Agent facts (claude-agent-acp 0.94.0, Claude Code 2.1.308–309)

What the code depends on, and how the adapter behaves. Everything Nushi does about it is in `internal/claude*`.

**Sessions**
- `session/new` requires `mcpServers`: send `[]`, never `null`. Claude starts a session in the mode its settings say; it reports modes both as legacy `modes` and as a `mode` config option (Nushi shows only the option). Config options: `mode` (Manual, Accept edits, Plan, Auto, Bypass permissions), `model` (Default, Opus 5.5, Fable 5.1, Sonnet 5.5, Haiku 5.5), `effort` (category `thought_level`), `fast` (category `model_config`, a select), `agent` (no category). `set_config_option` answers with the full set.
- Claude names a session itself soon after the first prompt (`session_info_update`); until then Nushi uses the prompt's first line. A fork is titled "<title> (fork)", a fork of a fork "(fork) (fork)": ignored, so a moved or rewound chat keeps its title. Asking `/context` before the first message makes Claude name the chat after it, so it isn't asked then.
- Claude keeps a session on disk only once it has a message: `session/load` of an empty one fails, and Nushi then starts a new one. `session/load` replays the user's and agent's messages and the tool calls (final status and output, `messageId`s included), not permission prompts or questions; a cancelled turn replays as "[Request interrupted by user]". It sends no `usage_update`. Loading takes under a second once npx has the adapter. A loaded session is on Claude's default model and effort, not the ones picked before (Haiku came back as Opus 5.5).
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

## Agent facts (codex-acp 2.2.2, Codex 0.160.1)

What the code depends on, and how the adapter behaves. Everything Nushi does about it is in `internal/codex*`.

**Sessions**
- `initialize`: `agentInfo.name` `@agentclientprotocol/codex-acp`, `loadSession`, `sessionCapabilities` resume, list, close, delete, fork, additionalDirectories, subagents; `promptCapabilities.image`; `_meta.steering.supported`. It advertises an `api-key` auth method (ChatGPT login too, unless `NO_BROWSER`); with a provider in `config.toml` no `authenticate` is needed. Without a login or provider, `session/new` fails "Authentication required".
- `session/new` returns legacy `modes` (read-only, workspace-write, agent "Auto review" (the default), agent-full-access "Full access"), the unstable `models` list (ids carry the effort as a suffix, `gpt-6.1-sol[medium]`; Nushi doesn't read it) and config options `mode`, `collaboration_mode` (default, plan), `model` (base ids), and, when the model has reasoning levels, `reasoning_effort` (category `thought_level`) and `fast-mode`. A custom model is listed only while it is the current one: after switching to a GPT model, switching back is "Invalid params" (with a model catalog it stays listed). Agent-full-access is a mode like Claude's Bypass permissions: shown, never picked by Nushi itself.
- codex-acp starts and forks every session with `projects.<cwd>.trust_level = "trusted"` as a config override (ADR 0029).
- `session/load` replays user messages (with `messageId`), agent messages (same `msg_…` ids as live), tool calls with their output, thoughts and the title; not the model-metadata warning, permission cards or questions. `session/list` works for a `/private/…` cwd.
- `session/fork` takes another `cwd` (so a move needs no history copy) and `_meta.jetbrains.air.fork = {version: 1, messageId}` for any client: the fork keeps the turns up to the one that has the message. It replays nothing. After a fork Codex titles the session after its next prompt.
- `session/delete` is `thread/archive`: the rollout moves to `$CODEX_HOME/archived_sessions/`; `codex resume <id>` then asks "Unarchive and resume". `codex delete <id>` would delete for good. History is `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-…-<id>.jsonl`; `codex resume` in a terminal first asks to trust the folder, says when another app has the session open, and leaves a Codex app-server running in the background (`$CODEX_HOME/packages/app-server-daemon`).

**Updates**
- Commands are `exec_command` tool calls: `kind` execute (content a `terminal` reference even without the client's `terminal` capability) or read/search for listing commands (no content). A client that isn't AIR gets the output in `_meta.terminal_output_delta {data}` on `tool_call_update`s and the end in `_meta.terminal_exit {exit_code, signal}`; read commands send `rawOutput.exit_code`. After Stop a running command finishes on its own and its call completes then.
- Permission requests come before the call's `tool_call`; options "Yes, proceed" (allow_once), "Yes, and don't ask again for commands that start with …" (allow_always), "No, and tell Codex what to do differently" (reject_once). In Auto review nothing harmless asks; in Read-only writing a file does.
- Questions (`request_user_input`) only in collaboration mode Plan: an `elicitation/create` form tied to a call id it never sends as a tool call, each question a required string with `oneOf` plus "None of the above", then an optional `<id>_note` "Additional answer or note".
- `session_info_update` carries the title (the first prompt, whole) and `_meta.codex.threadStatus`. `usage_update` gives used/size (no cost); the prompt result has `usage` and `_meta.quota`. Thoughts come as `agent_thought_chunk`s with `rs_…` ids.
- Without model metadata each turn starts with an agent message without `messageId`: "Warning: Model metadata for `…` not found…", and the window is 258,400.
- Plans come as agent text: codex-acp sends `plan` updates only to clients advertising a `plan` capability.

## Agent facts (Ante 0.2.14, through the bridge)

What the bridge (`internal/ante`) depends on, seen with `ante serve --stdio`; the protocol is Ante's open `crates/protocol-shape/src/msg.rs` at v0.2.14.
- Ops go in as `{"op": …, "id": "op_<ULID>"}` (a bad id is an `Error`); events come out with `parent`, the op they answer. An input's op id is its turn's id. No greeting.
- `StartSession{cwd}` answers `SessionStart` (session id, cwd, permission mode, model with `effort` and maybe `supported_efforts`, provider); unset fields come from `~/.ante/settings.json` (the user's default model, Kimi K3 here). `ResumeSession` answers `SessionEnd` (of any running one), `SessionStart`, `ExtensionRefreshed`, then the saved event log, with no end marker: the bridge sends `ContextReport` right behind it and takes its answer as the end (the host answers ops in order). Permission mode always comes from the current settings on a resume; the model is the session's.
- Live, the host echoes every input as `UserInput` (steers too, which the docs say it doesn't); streams `MessageDelta`/`ThinkingDelta`, then repeats the whole text (dropped once deltas came; replays have only the whole texts). A turn can hold several `AgentMessage`s; the bridge names them `<turn id>.<n>`.
- An approval (`TurnPause.Approval`) comes before the call's `ToolStart`; a denied call ends with a `ToolEnd{Denied}` and no start. `AcceptAlways` would write an allow rule into `settings.json`, so the bridge never offers it. Questions are `TurnPause.Question` (AskUser), answered with `QuestionResponse`.
- `UpdateSession` (model, effort, permission mode) answers `SessionUpdated` and doesn't write `settings.json` (checked). `ForkSession{at: <input id>}` needs an idle session and saves the fork without starting it (`SessionForked`); the bridge resumes it on a host of its own.
- `ToolEnd.result_json` shapes: Bash `{"Completed":{exit_code, stdout, stderr}}` (status `Failed` when the code isn't 0), Read `{file_type:{Text:{lines}}}`, Edit `{patch, summary}`, Write `{lines_written, message}`, AskUser `{message}`, a denial a string.
- Sessions are `~/.ante/sessions/<id>/{meta.json, events.jsonl, dialog.json}` (`ANTE_HOME` moves `~/.ante`, logs included); there's no op to list or delete them, so the bridge reads `meta.json` and removes the folder. A resume rewrites `meta.json` with zero usage.
- A project's `.ante/settings.json` can't widen what Ante may do: mode, allow rules, MCP servers, system prompt, model and provider are ignored with an `Info` notice (checked).
- `ante catalog` prints every provider's models (no keys: a provider's key is named by `env_key`).

## Agent facts (oh-my-pi 18.12.6)

What the code depends on (`internal/omp*`), from driving `omp --mode acp` and its source.
- `initialize`: `agentInfo` `omp`, `loadSession`, `sessionCapabilities` list, fork, resume, close (no delete: `session/delete` fails "Unknown ACP ext method"), `promptCapabilities.image`, `_meta.steering.supported`; extensions `_omp/usage`, `_omp/extensions` and more.
- `session/new` returns legacy modes and config options `mode` (default, plan; not permissions), `model` (`<provider>/<id>`, the models of providers with a key: with `FIREWORKS_API_KEY`, 35 Fireworks ones; Kimi K3 by default) and `thinking` (category `thought_level`: off, auto, then the model's levels). A model picked stays with the session.
- Permissions: only bash, delete and move ask (Allow once, Always allow, Reject, Always reject); writes and edits never do. The request comes before the call's `tool_call`. A command's title starts with `$ ` (the dialect drops it).
- Questions: its ask tool exists only for a client with form elicitation; each question is `qN` with `oneOf`, then `qN__other`, "Other (type your own)". An empty answer ends the turn as cancelled.
- `usage_update` carries used, size and cost; the prompt result carries usage. A prompt during a turn cancels the turn; `_session/steering` injects ("injected").
- `session/load` replays user messages, tool calls and agent messages (fresh message ids each time); `session/fork` copies the whole session.
- Sessions are `~/.omp/agent/sessions/<folder name>/<time>_<id>.jsonl`; all of omp's state is under `~/.omp` (`PI_CODING_AGENT_DIR` moves only `agent/`), so a test points `HOME` at a temp folder.
- It runs only under Bun (≥ 1.3.14); npx installs Bun's npm package beside it.

## Memory and speed (step 101)

Measured on this Mac (M-series, macOS 27) with footprint (`phys_footprint`, Activity Monitor's Memory), read through `proc_pid_rusage` for each process in an agent's tree. Agents driven over ACP by a scratch harness, then a dev daemon and a profile build of the app.

**Per agent, the whole process tree** (MB; "before" is as launched through npx, "after" without npx's process, step 101):

| | started | after one short turn | after 9 turns (each a shell call and a 300-word reply) | idle 60 s later |
|---|---|---|---|---|
| Claude, before | 296 | 305 (npx 60, adapter 80, `claude` 165) | 300 (npx 45, adapter 67, `claude` 189) | 299 |
| Claude, after | 276 | 244 (adapter 80, `claude` 164) | | |
| Codex, before | 150 | 161 (npx 59, adapter 46, `codex.js` 14, `codex` 26, git 16) | 153 (`codex` 37) | 134 |
| Codex, after | 93 | 85 (adapter 46, `codex.js` 14, `codex` 25) | 100 after 16 long replies | |
| Ante (the bridge and `ante`) | 19 (bridge 7, `ante` 12) | 19 | 26 (bridge 12, `ante` 14) | 26 |
| omp, before | 373 (npx 62, Bun 311) | 306 (Bun 244) | 309 | |
| omp, after | 315 | 244 | | |

- Node's share (the "Fewer JS runtimes" idea): for Claude the adapter is about a third of a chat (67–80 MB of 244), the `claude` CLI the rest (and it grows with the chat: 141 → 189 MB over 9 turns). For Codex Node is about two thirds (adapter 46 MB and Codex's `codex.js` launcher 14 MB, against `codex` itself at 21–37 MB). Before step 101 npx's own Node process (45–62 MB) sat on top of every Claude, Codex and omp chat.
- Fixed in step 101: agents start through `internal/npx`, which asks npx where the pinned program is (`npx --yes -p <pkg> -c 'command -v <bin>'`, 0.3 s when cached) and runs it directly. Saves 45–62 MB per chat and starts faster (Claude 1.2 → 0.75 s to a session, Codex 0.95 → 0.16 s).
- Codex runs git (a `git-remote-http` too) and `ps` as it starts; Claude ran a short-lived Python (a hook of this Mac's).

**Daemon and app** (20 Claude chats in the sidebar, Haiku, one short turn each; the app's window 1399×952 points):
- 20 awake: the daemon's tree 4,618 MB (nushid 39 MB, each chat 223–247 MB).
- After a daemon restart, none awake: nushid 8 MB; the app 156 MB.
- 5 awake (opened in the app): nushid 12 MB, agents 1,105 MB, the app 323 MB. The app's growth is mostly graphics (`footprint -p`: 113 MB of graphics, 79 MB of IOSurface; the Dart heap and malloc about 110 MB).
- With a long Codex chat (16 replies of 500–3,000 words) open as well: nushid 51 MB, the app 406 MB.

**Frame times** (profile build, `Flutter.Frame` events over the VM service):
- Opening 5 chats one after another: 850 frames, p99 build 3.2 ms, one frame of 18 ms.
- A 3,000-word reply streaming (8.2k tokens in 43 s, Codex): 4,665 frames, build p50 0.5 ms, p90 9.9 ms, p99 17.8 ms, max 22 ms; 128 frames (2.7%) over 16 ms, late in the reply. The markdown is healed and parsed whole on each chunk (see Decisions to revisit): fine to a few thousand words, then frames drop now and then. Left as it is; parsing only the last block would be the fix.
- Opening the long chat (in memory): one frame of 132 ms build, the rest under 1 ms (the transcript lays out every item, ADR 0026). Its replay after a daemon restart: one frame of 88 ms. Scrolling it: 122 frames, max 0.7 ms build, 7 ms raster.
- Idle: 2 frames a second (the caret).

## Codex config for you

Put these in `~/.codex/` (I didn't write them). `config.toml`:

```toml
model = "accounts/fireworks/models/deepseek-v4p1-flash"
model_provider = "fireworks"
model_catalog_json = "models.json"   # next to this file

[model_providers.fireworks]
name = "Fireworks"
base_url = "https://api.fireworks.ai/inference/v1"
env_key = "FIREWORKS_API_KEY"
wire_api = "responses"
```

Codex has no per-model metadata in `config.toml`: it takes a model catalog (`model_catalog_json`), and each entry needs the system prompt (`base_instructions`) too; without one the catalog fails to load and Codex says "Authentication required". This builds `~/.codex/models.json` from Codex 0.160.1's own prompt (the one its fallback metadata uses), with the model's real window (Fireworks reports 1,048,576 tokens; Codex shows 95% of it, 996k) and three efforts (each tried):

```sh
curl -sL https://raw.githubusercontent.com/openai/codex/rust-v0.160.1/codex-rs/models-manager/prompt.md | jq -Rs '{models: [{
  slug: "accounts/fireworks/models/deepseek-v4p1-flash",
  display_name: "DeepSeek V4.1 Flash",
  description: "DeepSeek V4.1 Flash on Fireworks",
  base_instructions: .,
  default_reasoning_level: "medium",
  supported_reasoning_levels: [
    {effort: "low", description: "Fast responses with lighter reasoning"},
    {effort: "medium", description: "Balances speed and reasoning depth"},
    {effort: "high", description: "Greater reasoning depth for complex problems"}],
  shell_type: "unified_exec", visibility: "list", supported_in_api: true, priority: 1,
  support_verbosity: false, default_verbosity: null, apply_patch_tool_type: null,
  availability_nux: null, upgrade: null,
  truncation_policy: {mode: "bytes", limit: 10000},
  context_window: 1048576, max_context_window: 1048576,
  experimental_supported_tools: [], input_modalities: ["text", "image"]}]}' > ~/.codex/models.json
```

The catalog replaces Codex's own list, so the model picker shows only this model. `FIREWORKS_API_KEY` must be exported by fish's config (it is): agents get the login shell's environment.

## Ante and oh-my-pi for you

- **Ante**: nothing to install. The bridge is inside `nushid`; it runs the `ante` on `PATH`, else `~/.ante/bin/ante` (yours is 0.2.14, the version it follows; 0.2.15, out on 2026-10-23, changed nothing in the protocol per its notes, so `ante update` should be fine). It uses your `~/.ante` as Ante does: your default model (Kimi K3 on Fireworks) until you pick another in the chat. `FIREWORKS_API_KEY` reaches it from fish, as it reaches Codex.
- **oh-my-pi**: nothing to install. The first chat downloads Bun 1.4.3 and omp 18.12.6 through npx (about 10 s). omp reads `FIREWORKS_API_KEY` from the environment and lists Fireworks' models; it starts on Kimi K3 at max effort. To start on DeepSeek, put this in `~/.omp/agent/config.yml` (I didn't write it):

```yaml
modelRoles:
  default: fireworks/deepseek-v4.1-flash
```

  For `omp` in a terminal (`omp --resume <id>`), install Bun and omp yourself: `brew install oven-sh/bun/bun` (or `npm i -g bun`) and `bun add -g @oh-my-pi/pi-coding-agent@18.12.6`.

## Decisions to revisit

Open questions; what's settled is in `docs/adr/` or in the code.

- New in T: Ante's permission options are Allow, "Allow for this session" and Deny; Ante's own "always" (which writes an allow rule into its settings) isn't offered. A denial sends Ante no message.
- New in T: an Ante fork (side chat, rewind) needs Ante idle: while it works, the fork fails with Ante's error. A rewind forks after the turn holding the agent's last message, as Codex does.
- New in T: Ante's Delete removes the session's folder in `~/.ante/sessions` (Ante has no op for it). omp's Delete leaves omp's history (omp has none), and the dialog says so.
- New in T: the bridge drops Ante's notices (`Info`, such as "Ignoring `mcp_servers` in .ante/settings.json") and its background-job ends (`TaskEnd`); the model's own text is unchanged.
- New in T: omp starts on its default model (Kimi K3, max effort): the start mode is remembered per agent, the model isn't.
- New in T: the omp trust card shows code and settings from `.claude`, `.codex`, `.gemini`, `.opencode` and `.cursor` too, since omp loads them: a repository with Claude hooks asks once for omp as well.

- New in S: "New chat" starts the agent of the newest chat (archived ones count), else the first the daemon lists (Claude); the menu beside it, and "New chat here" on a folder, pick another. The button names the agent ("New Codex chat"). Nothing is stored for it.
- New in S: a chat whose agent the daemon no longer knows can't be opened, renamed or deleted from Nushi ("Nushi doesn't know the agent").
- New in S: Codex's Delete archives (codex-acp's `session/delete`); Nushi doesn't run `codex delete` to delete for good. Side questions and throwaway forks pile up in `archived_sessions` the same way.
- New in S: after a Rewind Codex titles the chat after the next message (its fork has no name); Claude's chats keep theirs. A Codex Rewind drops from the transcript what came after the agent's last text in that turn, which Codex's fork keeps.
- New in S: Codex's trust card shows every file in each `.codex` Codex reads for the folder, from the repository's root down to it (more than Codex loads when it trusts only the cwd, as codex-acp makes it); "Start anyway" is kept per folder and per what was shown, so each folder of a repository with a `.codex` asks once, and again after any change. A `.codex` holding a link, an unreadable or special file can't be remembered. "Start anyway" for Claude doesn't cover Codex.
- New in S: the start failing ("couldn't start Codex: …") shows in the error dialog, not in a chat: no chat is made.

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
- More agents, if wanted: opencode (`opencode acp`; Fireworks built in, no steering, delete or questions, permissions only in `opencode.json`), Gemini CLI (`gemini --acp`; Gemini API only), goose (`goose acp`). Each is a `chats.Kind` and its own `internal/<agent>*` packages. Nushi never reads the agents' keys; each agent reads its own config.
- Ante: subagents (the `Agent` tool's child events carry no parent link) and background jobs (`TaskEnd`), skills as slash commands (`SlashCommand`), Ante's `Info` notices in the transcript, and its native `RewindSession` (Nushi rewinds by forking). Upstream, `ante-acp` could take the bridge's mapping; the bridge would then be one launch entry.
- omp: its `/context` for the Context card, MCP servers sent on `session/new` (omp ignores project MCP configs in ACP mode), and deleting a session's files.
- Codex's MCP servers (its `config.toml`'s `mcp_servers`, `/mcp` over ACP) in the MCP view; Codex's background terminals and subagent sessions (codex-acp offers them to clients that negotiate them).
- Fewer JS runtimes (far off; the owner wants as little Node/JS as possible). Claude: a Go bridge in `nushid`, like Ante's (ADR 0030), speaking the `claude` CLI's stream-JSON control protocol (what the Agent SDK does: permission prompts, interrupts, resume and fork, subagent events, `/context`) in place of `claude-agent-acp` on Node. The cost is tracking that protocol, which isn't a stable interface and moves with Claude Code releases; measure the Node process's share per chat first. Codex: the same against its native `codex app-server --stdio` in place of `codex-acp`. omp needs Bun by nature.
- Subagents as ACP child sessions (the RFD form claude-agent-acp offers a client that advertises `subagents`): a background subagent's steps after a daemon restart, and a stop button per subagent. See step 51.

## Dependencies

- Go: `connectrpc.com/connect` v1, `google.golang.org/protobuf`, `gopkg.in/yaml.v3` (step 87: skills' front matter, for the trust card), `github.com/BurntSushi/toml` (step 96: Codex's config), buf through `go run` (codegen), `github.com/creack/pty`, `golang.org/x/sys/unix`.
- Dart: `connectrpc` (with `http2` 2.x: 2.0.1 doesn't resolve with 3.x), `protobuf`, `flutter_markdown_plus`, `markdown`, `re_highlight`, `url_launcher`, `file_selector`, `pasteboard`, `desktop_drop`, `xterm2` (MIT; brings `xterm2_core`, `zmodem`, `quiver`, `equatable`, `convert`); fonts IBM Plex Sans and JetBrains Mono (OFL), and Symbols Nerd Font Mono from Nerd Fonts 3.5.1 (MIT; its icons come from projects under their own licenses, listed in the Nerd Fonts repository), bundled.

## Security notes to look at

- Codex runs as you through `npx --yes @agentclientprotocol/codex-acp@2.2.2` (pinned by version, not hash; it brings `@openai/codex` 0.160.1), started like Claude's adapter. codex-acp tells Codex to trust every session's cwd, so a folder's `.codex/config.toml` (MCP servers, the environment of every command, sandbox settings, plugins) and rules load without Codex asking; Nushi's card is the only warning (ADR 0029). The card's key is a hash of every file it showed, computed with the card and checked again on "Start anyway"; links aren't followed. Codex's trust record is read, never written. Agents get the login shell's environment, secrets included (ADR 0028).
- Ante runs as you through the bridge, `nushid ante-acp`, which starts `ante serve --stdio` (the `ante` on `PATH` or in `~/.ante/bin`, 0.2.14 or newer) in the chat's folder. The bridge never reads Ante's settings; it reads `ante catalog` (models only) and each session's `meta.json`, and removes a session's folder only for an id of Ante's form (`ses_` and a ULID). A Write's old text, for its diff, is read only from a regular file of at most 1 MB, without following a link. Prompt images go to a private temp folder the bridge removes when it ends. The trust card shows the nearest `.ante/settings.json` (ADR 0031).
- omp runs as you through `npx --yes -p bun@1.4.3 -p @oh-my-pi/pi-coding-agent@18.12.6` (pinned by version, not hash) and loads a project's extensions, hooks, tools, command modules and LSP servers without asking; the trust card shows each such file whole (ADR 0031). Its bash asks first; its writes don't.
- Memory: `GetMemory` reads the footprint of the daemon's process trees, and of the process tree a client names (`app_pid`, any process of yours), for any client with the token: sizes only. Agents start from the path `npx -c 'command -v <bin>'` prints, in the daemon's folder, as npx itself would run them.
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
- To watch the fake agent in the app: build `acp/acptest/fakeagent`, put an `npx` that prints its path (agents start through `npx … -c 'command -v <bin>'`) first on `PATH`, and start a daemon with that `PATH` and `NUSHI_DATA` (a short path: the socket path has a length limit). Its scripts answer prompt words: `permission`, `question`, `think`, `pwd`, `many`, `plan`, `wait` (until stopped).
- Terminals: the shell is the user's login shell from `id -P` (the user database), never the daemon's `$SHELL`. fish 4 asks the terminal's Primary Device Attributes as it starts and waits 10 seconds for the answer; the app answers queries in a replay only for a terminal it opened itself (anyone attaching later would answer twice).
- Driving the app by hand: System Events' `click at` doesn't reach a Flutter window; a few lines of Swift posting `CGEvent` mouse and key events do. Screenshots are 2× the window's points.
- App tests get a data folder in the temporary folder (`FLUTTER_TEST`); never point them at the real one.
- Ante and omp by hand: start the dev daemon with `ANTE_HOME` set and `HOME` at a temp folder (omp keeps everything under `~/.omp`), the key read from `fish -l -c` with the real `HOME`. Quit the dev app before stopping the dev daemon: an app that finds no daemon starts its bundled one through the login shell, with the real `HOME` and none of the dev daemon's environment.
- Codex by hand: start the dev daemon with `CODEX_HOME` at a temp folder holding the config above, and `FIREWORKS_API_KEY` read from `fish -l -c` inside the launching script, never on a command line or in a file. `codex resume` in a pty needs answers to the terminal's colour and cursor queries.
