# Notes

## Summary (2026-10-23, after step 21)

Milestone E (steps 19–21) is done, one commit each on `main` (not pushed). `make test` passes: Go unit tests, four end-to-end tests against the fake agent (app quit, daemon restart, stopping a turn, and now rename/archive/remove), the transport and markdown package tests, and the app's tests. Each step was looked at in the running app against live Claude (claude-agent-acp 0.94.0), at 1280×800 and 1024×700; step 21 with the installed app opened through LaunchServices (`open`, as Finder does).

**What works** (on top of milestones A–D: chats with Claude in any folder, prompts and questions as cards, pickers, a sidebar that survives app quits and daemon restarts, the diff viewer, clean markdown, readable tool calls, plans, stop, the composer, long chats and side questions)
- Rename a chat by double-clicking it in the sidebar or its title in the header, or from its menu (right-click, or ⋯ in the header). The name is kept in the chat's session file and wins over Claude's title.
- Archive: cancels a running turn (or a waiting prompt), stops the agent, moves the chat to a collapsed Archived group at the bottom of the sidebar; opened, it is read-only with Unarchive, which replays it through `session/load` and carries on.
- Remove: after a confirmation that names `claude --resume <id>`, cancels the turn, stops the agent and deletes Nushi's session file. Claude's own history stays; a removed chat was resumed from the terminal to check.
- Usage: a context ring and percentage by Send (counts and the last turn's tokens on hover), and the session's cost in the header, only from what Claude reports. It survives an app quit; after a daemon restart it comes back with the next turn.
- `make package` builds a release `Nushi Next.app` with `nushid` inside, ad-hoc signed; `make install` puts it in `~/Applications`. The app starts its bundled daemon when none answers (through your login shell, detached), never stops one by itself, and against an older daemon shows which features are unavailable and offers "Restart daemon". `make run` works as before.

**What doesn't (yet)** (carried over from step 18, still true)
- Claude sends no thoughts (recent models stream thinking "omitted"); the Thinking line is tried with the fake agent only.
- Plans show only when Claude's todo tools are on (`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in Claude's own settings).
- Copying a selection across several blocks loses the line breaks between them; command output shows when the command ends; each streamed chunk re-parses its message; one side question per chat.
- New in E: an archived chat shows no history after a daemon restart until it is unarchived (showing it would mean starting an agent). After `session/load` the cost Claude reports sometimes restarts from zero (see ACP quirks). After a reboot nothing runs until the app is opened (no launchd agent).

**Decisions to revisit**: see [the list below](#decisions-to-revisit). Most worth a look for E: starting the daemon through the login shell rather than a launchd agent ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md)); archived chats keeping their transcript only in the daemon's memory; the menu items an older daemon lacks shown disabled rather than hidden; the context ring's 70%/90% colors.

**Size**: the app is 4,191 lines of Dart (limit about 7,000), plus 650 in packages; the daemon is 2,219 lines of Go (limit 5,000) and the ACP client 793 (limit 2,000). No hand-written file is over 400 lines (the largest: `acp/internal/acpgen/main.go` 393, `app/lib/composer.dart` 379). Step 19 went over the ~500-lines-per-step tripwire (755); see "Tripwires crossed".

**Left behind by the testing**: the installed `~/Applications/Nushi Next.app`. The data folder has only its token and log again (test chats removed, daemon stopped). Claude keeps its history of the test sessions under `~/.claude/projects/` (folders named after this session's scratch directory). One test prompt ("write an essay") made Claude create a doc in your claude.ai account through your Claude Docs connector (`https://claude.ai/artifact/K66gq1HiHcMcSXbRRZZ819`, an outline about Go's history); delete it if you don't want it.

## Line counts

Hand-written, without tests or generated code (`make lines`). Packages are counted apart from the app.

Go is split into the daemon (`cmd`, `internal`) and the generic ACP client (`acp`, its type generator included, its fake test agent `acp/acptest` not: that is test support, about 200 lines).

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

Tripwires crossed:
Lines added per step, code and tests, without generated code (the tripwire is about 500): 1: 533, 2: 1,502, 3: 239, 4: 437, 5: 739, 6: 639, 7: 464, 8: 537, 9: 265, 10: 528, 11: 1,249, 12: 625, 13: 476, 14: 343, 15: 351, 16: 492, 17: 298, 18: 666, 19: 755, 20: 223, 21: 146.
- Step 1 (533): the Unix-socket transport package and its tests came with the skeleton.
- Step 2 (1,502): the whole ACP client landed in this step (JSON-RPC framing, client and the schema-to-Go type generator, about 660 lines), plus the first real chat screen and the daemon's chat feature. None of it is for later steps.
- Step 5 (739): the question card is the app's biggest widget (267 lines: options, multi-select, Other boxes, digit keys); reading the form in order, and two fixes to the type generator.
- Step 6 (639): config options on both sides (normalizing, setting, remembering, the store) and the pickers, with tests.
- Step 8 (537): the fake agent (about 200 lines) and the end-to-end test (185) that the step asks for.
- Step 10 (528): the git reader and its test, the Changes view, and the app's first Dart test.
- Step 11 (1,249 added, 399 removed): the POC's tokens, theme and small widgets (about 470 lines), and every view restyled on them (sidebar, header, transcript, tool calls, cards, composer, pickers, Changes list). Tokens are written as Dart, flat, light and dark; the POC generated them from a JSON file.
- Step 12 (625): the healer lifted from the POC (300 lines, about half of the POC's) and its tests, the code block builder, and the style mapping.
- Step 16 (492) and 18 (666): each touched both sides. Step 18 is the fork and close calls in the ACP client (hand-written, `session/fork` isn't in the pinned schema), routing a shared agent's updates to the chat or its side chats, two RPCs, a test, and in the app the selection popover, Reply, and the side panel with its own transcript and composer.
- Milestone D (steps 11–18) grew the app from 1,402 to 3,559 lines of Dart (limit about 7,000), plus 519 in the new markdown package; the daemon from 1,662 to 2,009 lines of Go and the ACP client from 716 to 773.
- Milestone E (steps 19–21) grew the app from 3,559 to 4,191 lines of Dart and the daemon from 2,009 to 2,219 lines of Go; the ACP client from 773 to 793 (the prompt result's unstable `usage`).
- Step 19 (755 added, 72 removed): both sides again. The daemon's rename/archive/remove (`manage.go`, 114) and their RPCs; an end-to-end test (75); in the app the chat menu, the remove confirmation and the inline rename field (`chat_menu.dart`, 181), the sidebar's archived group and double-click, the header's title and menu, and the archived bar.
- `acp/internal/acpgen/main.go` reached 407 lines in step 10's trim pass; it was trimmed to 393.

## Milestone A demo (steps 1–5): one working chat

(As of step 5. Since step 7, "Start a chat in a folder…" is the sidebar's "New chat in a folder…".)

1. `make run`. The window says "Daemon not running" for a moment, then "Connected". (`make stop`, and it says "Daemon not running" again within two seconds; `make daemon` brings it back.)
2. Click **Start a chat in a folder…** and pick a folder. Claude starts there (a few seconds the first time, while npx fetches the adapter).
3. Ask something; the reply streams in as markdown.
4. Ask it to run `ls -la` and read a file: each tool call shows as one collapsed line with its icon, title and status (a spinner, then a check); click it for the output.
5. Permission prompts: Claude only asks in its Manual mode (`default`), and its mode picker comes in step 6. Until then, use a folder whose `.claude/settings.json` is `{"permissions":{"defaultMode":"default"}}` and ask for `touch x.txt`: a card shows Claude's own options ("Yes", "No"). Pick one; the card says what you answered and the agent carries on (or doesn't).
6. Ask: "Use the AskUserQuestion tool to ask me my favourite colour (red/green/blue) and which fruits I like (multi-select). Then repeat what you received." A card shows both questions with an "Other" box each. Digits 1–9 pick in the active question, clicks pick anywhere, Enter or Submit sends, Skip declines. Claude repeats exactly what you picked.

## Milestone B demo (steps 6–9): many chats that survive restarts

1. `make run`. Start a chat in a folder; under the transcript are Claude's pickers: Mode, Model, Effort, Fast mode, Agent. There is one Mode picker, though Claude reports its mode twice.
2. Pick Mode ▸ Manual. Start another chat (any folder): it starts in Manual. Ask it to `touch x.txt` and it asks permission. (The pick is remembered per agent in `agents.json`; a mode Claude changes on its own isn't.)
3. The sidebar lists chats by folder. "New chat in a folder…" picks a folder; a folder's "+" opens another chat there. Click between chats; each keeps its transcript. Titles come from Claude after the first reply.
4. Quit the app (⌘Q) while a chat waits on a permission prompt, then `make app` (or `make run`). Open the chat: the transcript and the waiting card are there; answer it and the agent carries on.
5. `make stop`, then `make daemon` (the app says "Daemon not running", then reconnects). Open a chat: it shows busy for a second or two while Claude replays it (`session/load`), then the transcript is back, tool calls included, and you can keep chatting. Chats from earlier daemon runs reopen the same way.

## Milestone C demo (step 10): the diff viewer

1. `make run`, and start a chat in a folder inside a git repository.
2. Ask Claude to change a file and add one (Mode ▸ Accept edits saves answering prompts).
3. Click **Changes** at the top right. The list shows each changed file with A, M or D; pick one to see it side by side: ribbons join each change across the panes, changed words are highlighted, unchanged stretches fold to "… N unchanged lines". Binary files and files over 1 MiB are listed but not shown.
4. Ask for another change and stay on Changes: the list reloads when the turn ends (or click ↻).
5. In a folder outside git, Changes says so.

## Milestone D demo (steps 11–18): a chat worth reading

1. `make run`. The app has the POC's look: IBM Plex Sans and JetBrains Mono, a raised sidebar of chats with status dots, a chat header (agent, model, status, folder, Chat | Changes). View ▸ Light/Dark/System Appearance switches the theme.
2. Start a chat in a git repository. Ask: "Without tools, write a long reply: a heading, a paragraph with a link and **bold**, code in Go, Python (one line over 150 characters) and TypeScript, a table, a quote and lists." It streams without raw `**` or half fences; code blocks have a language label, a copy button, colors and sideways scroll; tables and quotes are styled; links open in the browser. Drag across a whole message to select it.
3. Ask Claude to explore the repo (read files, run `git log`, run `ls nope`) and make an edit. The tool calls collapse into one line ("Read 3 files, ran 3 commands, edited 1 file"); open it: each call is one line (`Read counter.go`, `$ git log`, `Edit counter.go +4 −0`), the failed one in red; open the edit to see its diff side by side.
4. Pick Mode ▸ Plan and ask for a plan for a small change, kept as a todo list. Approve it; the Plan checklist ticks off as Claude works, and the current step shows above the composer. (Claude sends no thoughts here; `acp/acptest/fakeagent` shows the Thinking line: see "Decisions to revisit".)
5. Ask for a 2,000-word essay; while it streams the header counts "working · 8s" and the composer shows Stop. Press Escape: the reply stops and "Stopped" shows. Pick Mode ▸ Manual, ask for `touch y.txt`, and switch to another chat: the first one shows amber "needs you" in the sidebar.
6. In the composer, type `/re` and pick a command with the arrows and Enter; type `@cou`, Tab to pick `counter.go`, finish the question and send: Claude reads the file. Shift-Enter adds a line; Up in an empty box brings back the last prompt.
7. Open a long chat (or the fake agent's `many`): it opens at the bottom, follows new text, stops following when you scroll up and shows "Jump to latest".
8. Select a sentence of a reply: Reply quotes it in the composer. Select another: Side question opens a panel; ask something there, and Claude answers knowing the chat. Close the panel and ask the main chat what you asked last: it never saw the side question.

## Milestone E demo (steps 19–21): loose ends

1. `make stop`, then `make install`. Open `~/Applications/Nushi Next.app` from Finder. It says "Starting the daemon…" for a moment, then the sidebar shows (`pgrep -lf nushid` shows the bundled one, its parent launchd).
2. Start a chat, ask for something that runs a command (`go version`): the agent has your PATH. Chat a few turns: the ring by Send fills (hover for the counts and the last turn's tokens) and the cost in the header goes up.
3. Ask for a 400-word story and quit the app (⌘Q) while it streams. Wait, reopen: the story is complete, the cost and ring are there.
4. Double-click the chat's title (sidebar or header), type a name, Enter. Start a long reply and pick ⋯ ▸ Archive: the reply stops, the chat moves under Archived. Open it: read-only, with Unarchive; press it, the transcript replays, and you can keep chatting.
5. Right-click another chat ▸ Remove…: the dialog says Claude keeps its history; confirm, it's gone. `claude --resume <id>` in its folder still opens it.
6. Older daemon: quit the app, `make stop`, start a step-18 build of `nushid` (`git worktree add /tmp/old a7c4381 && (cd /tmp/old && go build -o /tmp/nushid-old ./cmd/nushid) && /tmp/nushid-old &`), open the app: chats work, the menu's items are greyed out, and the sidebar offers "Restart daemon". Press it: the bundled daemon takes over and the open chat reloads.

## ACP quirks

- `session/new` requires `mcpServers`: send `[]`, never `null`.
- claude-agent-acp 0.94.0 puts a `messageId` on every `agent_message_chunk`; chunks are grouped into messages by it (by the last message when it is missing).
- The adapter logs progress (`[session/create] ...`) on stderr; nushid copies it into its log.
- Usage (claude-agent-acp 0.94.0, step 20): each turn ends with two `usage_update`s, `{used, size}` and then the same with `cost: {amount, currency: "USD"}`, the session's cost so far. `size` was 1,000,000 for Opus 5.5 here; `used` is the context after the turn. The cost is the session's so far, but across agent processes it isn't reliable: in one probe the first turn after `session/load` carried on from the earlier turns ($0.19 → $0.22), in the app after a daemon restart it started again near zero ($0.15 → $0.02). Nushi shows what is reported. `session/load` itself sends no `usage_update`, so a reopened chat has no usage until its next turn. One `usage_update` after a load also carried `_meta._claude/rateLimit` (five-hour and seven-day utilization); not shown. The prompt result carries ACP's unstable `usage` (`inputTokens`, `outputTokens`, `cachedReadTokens`, `cachedWriteTokens`, `totalTokens`, summed over the turn's model calls, so cache reads can exceed the context) and a `_meta.quota` with the same per model.
- Claude names its sessions itself: soon after the first prompt it sends `session_info_update` with a short title ("Apple" for "Reply with just the word apple."). Nushi uses the first line of the first prompt until then.
- `session/load` on Claude replays the user's messages, the agent's messages and the tool calls (with their final status and output), not permission prompts or questions. Messages carry `messageId`s in the replay too. Loading a session takes under a second once npx has the adapter.
- Claude's tool calls arrive as a `tool_call` with a generic title ("Terminal", "Read File") and empty `rawInput`, then `tool_call_update`s that set the real title (the command, "Read notes.txt"), then content. The first content is the command's description; the final one (with `status: completed`) is the output in a fenced block. Each update's `content` replaces the previous one.
- Claude 2.1.308 searches and lists with `Bash` (`grep -rn`, `ls *.md`), not its Grep and Glob tools, so searches show as commands. A failed command's output starts with `Exit code N`; there's no exit code field. An `Edit`'s ACP `diff` holds the edited snippet (`old_string`/`new_string`), not the whole file. Tool calls carry `locations` (absolute paths) once the real title arrives.
- Claude sends no `agent_thought_chunk`s here: the adapter says recent models stream thinking "omitted" (signature only), and neither `showThinkingSummaries` in the project's settings nor `MAX_THINKING_TOKENS` (Opus, Sonnet, Haiku) changed that. Thoughts are built to ACP and were tried with the fake agent only.
- Claude keeps a todo list (ACP `plan` updates, full list each time) only when its todo tools are on: `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in its environment. Without it, `TodoWrite` and `TaskCreate` aren't there and Claude says so. With it, Claude uses `TodoWrite` or `TaskCreate`/`TaskUpdate` (the adapter hides the task tool calls and sends the plan). In Plan mode Claude writes the plan before asking to leave Plan mode, so the checklist sits above the approval card.
- `session/cancel` on Claude ends the turn within a second or two with stop reason `cancelled`; the text streamed so far stays. A command Claude runs in the background can finish after the turn and Claude then writes again on its own, outside any prompt (a tool call and a message arrive while the chat is idle).
- Claude sends `available_commands_update` soon after `session/new` (and after `session/load`): about 80 commands, its own and every installed plugin's and skill's (`/code-review:code-review`). A command goes back as an ordinary prompt starting with `/name`. A `resource_link` to a `file://` URI in the prompt makes Claude read the file.
- claude-agent-acp 0.94.0 advertises `sessionCapabilities.fork` (and `close`, `resume`, `list`, `delete`). `session/fork` copies the session's transcript into a new session on the same agent process, which then knows the whole conversation; prompting it doesn't touch the original. Updates for the fork arrive on the same connection, tagged with the fork's session id. `session/close` ends it.
- Replaying (`session/load`) a turn that was cancelled shows a user message "[Request interrupted by user]": Claude stores it in its history.
- Claude also sends a `tool_call_update` carrying only `_meta.claudeCode.toolResponse` (the raw tool result) before the final one; it changes nothing we show.
- In `auto` mode Claude asked nothing for `curl -X POST` or `touch`; in Manual (`default`) mode it asks before `touch`, with two options, "Yes" (`allow_once`) and "No" (`reject_once`). A permission request names the tool call it is about (`toolCall.toolCallId`), which was sent just before as a `tool_call`.
- To test prompts without a mode picker, a folder with `.claude/settings.json` = `{"permissions":{"defaultMode":"default"}}` starts Claude in Manual mode.
- AskUserQuestion needs the client to advertise `elicitation.form`. Claude first sends a `tool_call` ("Asking for your input", kind `other`), then `elicitation/create` in form mode, tied to it by `toolCallId`. Each question is a property `question_N`: a `string` with `oneOf` (single choice, options with `const`, `title`, `description`) or an `array` whose `items.anyOf` lists the options (multi-select), followed by an optional free-text `question_N_custom` titled "Other". Nothing is `required`. An accept with empty content reads to Claude as "the user did not answer"; it reads each answered question back as `"question"="answer"`.
- The form's properties must be read in wire order (they are the questions' order), so the generated types keep maps of typed values as raw JSON.
- Claude starts new sessions in whatever mode its settings say (`auto` on this machine), and reports modes both as legacy `modes` and as a `mode` config option, as the POC found. Nushi shows only the config option.
- Claude 0.94.0's config options: `mode` (Manual, Accept edits, Plan, Auto, Bypass permissions), `model`, `effort` (category `thought_level`), `fast` (category `model_config`, a select of on/off rather than a boolean) and `agent` (no category: the subagent to run as). `set_config_option` answers with the full new set of options.

## Decisions to revisit

- The remembered mode lives in `agents.json` in the data folder (`{"claude":{"mode":"default"}}`); the agent is named "claude" in code until there's a second one.
- Modes get no warning styling: claude-agent-acp 0.94.0 doesn't tag its full-access mode (`_meta.kind`), and naming `bypassPermissions` in Nushi would be a per-agent table.
- Each chat is a file `sessions/<id>.json` in the data folder (id, agent, folder, title, last mode, created). A chat's title is the agent's (`session_info_update`) or else its first prompt's first line.
- The sidebar groups chats by folder, newest chat first; a folder's "+" opens a new chat there without a dialog.
- A reconnecting app asks for a chat's snapshot (`GetChat`) when the chat is opened. Each chat numbers its events; the snapshot says which number it includes, and the app applies only later events (held while the snapshot is on its way). Chats that aren't open only track busy/idle.
- The fake agent for end-to-end tests (`acp/acptest`) is new code, about 230 lines, scripted by prompt text, rather than a lift of the POC's 8k-line YAML-scenario agent. Its scenarios so far: echo, a permission prompt, a question, and `session/load` replay.
- After a daemon restart a chat is reopened (`session/load`) only when it is opened in the app or prompted, not all at start: each reopened chat is a Claude process. A turn that was running when the daemon stopped is lost; a permission prompt or question that was waiting is gone (the agent that asked is gone too).
- On SIGINT/SIGTERM the daemon kills its agents (their process groups) before exiting; a daemon killed with SIGKILL leaves them to exit when their stdin closes.
- The diff API (`GetDiff`) calls `internal/git` directly: there is no diff logic beyond reading git, so a `features/diffs` package would only pass through. It takes a folder (the app sends the chat's), and shows changes against HEAD, untracked files included, paths relative to the folder.
- One agent process per chat; the chat's id is the agent's session id.
- The daemon keeps each chat's transcript in memory (not on disk); events carry an item, and a streamed message sends only the new text (`append`).
- The `Events` stream's first message is empty, so a client knows its subscription is live (connect-go clients otherwise wait for the first real event).
- Markdown (step 12) is `flutter_markdown_plus` with the POC's healing step in front of it, in `packages/markdown` (the `markdown_view` package), rather than the POC's own renderer: the POC's is 3,500 lines (block splitting, caches), this is about 500 for the same look while streaming (no raw `**`, half links, open fences or half table rows). The cost: each streamed chunk reparses the whole message; fine for replies of a few thousand words, worth revisiting for very long ones. The healer skips the POC's partial-HTML-tag rule, since raw HTML isn't rendered anyway.
- Code blocks are highlighted with `re_highlight` (a highlight.js port) when the fence names a language it knows; no guessing for unlabelled blocks. Colors are the POC's three code tokens plus muted comments.
- Copying a selection that spans several blocks (paragraph, code block, table) joins them without line breaks: Flutter's `SelectionArea` adds none. The code block's copy button copies exactly.
- A tool call's text output is rendered as markdown; its ACP `diff`s travel apart (`Item.diffs`) and show with `diff_view`, side by side, as tall as the edit up to 15 lines. Terminal content (`terminal/*`) isn't supported: the client doesn't offer the terminal capability.
- Tool calls (step 13) stay collapsed, edits included; a run of two or more in a row is one line ("Read 3 files, ran 2 commands") whose failed calls show in its count and in red inside. The summary line comes from ACP alone (kind, title, locations, diffs), with no per-agent rules, so a command shows the agent's title (Claude's is the command). Paths are relative to the chat's folder when inside it.
- ACP types are generated by a small in-repo generator (`acp/internal/acpgen`, about 330 lines) from the pinned schema `schema-v1.26.0`: tagged unions become a struct with one pointer per variant, other unions of objects are merged into one struct.

- The app keeps the native macOS title bar. The POC drew its own 40 px bar (Nushi mark, breadcrumb, command palette); there's no palette here, so the folder moved into the chat's header instead.
- Light or dark follows the system; View ▸ Light/Dark/System Appearance overrides it until the app quits (not stored). The POC was dark by default.
- The POC's fonts are bundled (`app/fonts/`, IBM Plex Sans and JetBrains Mono, variable TTFs from google/fonts, OFL licenses next to them), so the app looks the same on any Mac. About 1.3 MB.
- Not lifted from the POC: density and zoom settings, the status bar, the folder rail, chat tabs, the inspector.

- Nushi doesn't change how Claude runs: its todo tools (and so plans) are on only if your Claude config turns them on. Step 14 set the variable from nushid; removed after, since the same chat should behave the same in the terminal.
- A plan updates in place: the turn's plan item (since the last prompt) is replaced; a new turn starts a new one. While the agent works, the current step also shows on one line above the composer, since the plan itself may have scrolled away.
- Thoughts show as a dim "Thinking…" line (spinner while it's the newest item and the agent works), collapsed; opening it shows the text, italic, plain (not markdown).
- The fake agent has `think` and `plan` scripts, and `acp/acptest/fakeagent` runs it on stdio. To watch them in the app: build it, put an `npx` that execs it first on `PATH`, and start `bin/nushid` with that `PATH`.

- Stopping a turn (step 15): the daemon sends `session/cancel` and answers the permission prompts and questions the turn waits on as cancelled, as ACP asks of a client. Escape anywhere in the chat stops it too.
- A turn that doesn't end normally leaves a notice in the transcript (Stopped, refused, token or request limit, or the error); so does a chat that can't be reopened. `ChatStatus.error` is no longer set (API version 11).
- A chat's status says when its turn started (the header counts up: "working · 12s") and whether it waits on the user; the sidebar marks it amber with "needs you". The list of chats carries each one's status, so the marks are right when the app starts.

- The composer (step 16): `/` at the start completes the agent's commands, `@` anywhere completes the chat folder's files; the names whose last part starts with what's typed come first, then the shortest, eight at most. Arrows move, Enter or Tab picks, Escape closes. A picked file stays in the text as `@path` and goes to the agent as a resource link (only if `@path` is still in the text when sent). The box grows to ten lines, then scrolls. Up in an empty box brings back the last prompt, with its file links.
- `ListFiles` returns the folder's files once per composer (20,000 at most): in a git repository `git ls-files` (tracked and untracked, not ignored), else a walk that skips hidden folders. The app filters them as you type. Like `GetDiff`, it calls `internal/git` from the API directly.

- The transcript (step 17) is a top-down lazy list: it opens at the bottom and sticks to it while the agent writes (re-checking whenever the list's height changes, since lazily built items change it); scrolled up by more than a line, it stays put and shows "Jump to latest". A short chat sits at the top of the pane, as on claude.ai, rather than against the composer.
- The fake agent's `many` script writes 150 tool calls and messages, to try a long chat.

- Side questions (step 18) fork the chat's session on its own agent (no new process), so a side chat can't outlive the chat's agent. It isn't stored or listed, and closing the panel, switching chats or the daemon stopping ends it (`session/close`). Only one side question per chat at a time; a second "Side question" adds the new quote to the open one. Its pickers are empty: it runs with the chat's settings.
- The selection popover shows where the pointer went up, once text is selected (a drag or a double-click), with Reply (quotes the selection as `> ` lines in the composer, cursor after it) and Side question (hidden when the agent can't fork). It works in the side panel too, where it only offers Reply.
- `session/fork` and `session/close` types in `acp/fork.go` are written by hand (fork is unstable in ACP v1 and not in the pinned schema); the fork capability is read from the raw `initialize` answer.

- Rename, archive, remove (step 19): a title you set is `Name` in the session file and wins over the agent's (`Title`, still updated); renaming to nothing goes back to the agent's. Archiving and removing cancel a running turn and give the agent five seconds to end it before its process stops; both refuse while a chat is still reopening (`session/load`), for a moment after a daemon restart.
- An archived chat keeps its transcript in the daemon's memory, so it reads as it was until the daemon restarts; after a restart it shows no history until unarchived, since showing it would mean starting an agent to replay it. Unarchiving drops the transcript and replays it through `session/load`.
- Removing deletes only `sessions/<id>.json`. The confirmation names `claude --resume <id>` (in the chat's folder), which was tried after a removal.
- The sidebar's Archived group is collapsed at each start (not remembered). A click opens a chat right away; a second click within the double-tap time renames it (Flutter's double-tap recognizer would delay every single click). Right-click, or the header's ⋯, opens the menu: Rename, Archive/Unarchive, Remove….

- Usage (step 20) is only what the agent reports: the context meter (a ring and a percentage by Send, the counts and the last turn's tokens on hover) shows once a `usage_update` arrives, and the cost sits in the chat header once one carries a cost. An update without a cost keeps the last cost shown (Claude sends one without, then one with, each turn). The daemon keeps usage in memory with the chat, so it survives an app quit but not a daemon restart; it isn't stored. The ring turns amber past 70% and red past 90%. The prompt result's `usage` is read through a hand-written `acp.PromptResult` (unstable in ACP v1, not in the pinned schema).

- The packaged app (step 21) finds `nushid` next to its own executable (`Contents/MacOS/nushid`) and starts it when a ping fails, at most every ten seconds, as `$SHELL -l -c "exec '<nushid>' >>'<data>/nushid.log' 2>&1"`, detached ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md)). A debug build (`make run`) has no bundled daemon, so it never starts one. A path with a `'` in it isn't started (quoting differs between shells).
- "Older" means the daemon's `Ping` API version is below the app's (`apiVersion` in `daemon.dart`, kept equal to `internal/api.Version`). Rename, archive and remove need 14: with an older daemon their menu items show greyed out and double-click doesn't rename. Usage (15) simply doesn't show. The banner sits at the bottom of the sidebar.
- "Restart daemon" finds the daemon with `lsof -a -c nushid -t <socket>`, sends it SIGTERM (it stops its agents), waits for pings to fail, then starts the bundled one. A turn running at that moment is lost, as with any daemon restart; the banner says so.
- `make package` is `flutter build macos --release`, `go build` into the bundle, then `codesign --force --deep --sign -` (ad-hoc). `make install` replaces `~/Applications/Nushi Next.app` with `ditto`.

- Connect for Go is v1 (`connectrpc.com/connect` v1.21), not v2: v1 is what the Dart generator's docs and the POC used, and nothing here needs v2.
- `http2` for Dart stays on 2.x: `connectrpc` 2.0.1 doesn't resolve with `http2` 3.x.
- The app runs without the macOS App Sandbox, so it can reach the daemon's socket in Application Support.

## Dependencies added

- Go: `connectrpc.com/connect`, `google.golang.org/protobuf` (API), buf through `go run` (codegen only).
- Dart: `connectrpc`, `protobuf`, `http2` (API), `flutter_markdown_plus` (rendering replies), `file_selector` (the native folder picker).
- Fonts (step 11): IBM Plex Sans and JetBrains Mono, bundled as assets (OFL).
- Dart (step 12): `re_highlight` (syntax highlighting), `markdown` (already there through `flutter_markdown_plus`, now named), `url_launcher` (opening links).

## Security notes to look at

- Agents run as you, with your environment, through `npx --yes @agentclientprotocol/claude-agent-acp@0.94.0` (downloaded from npm on first use, pinned by version, not by hash). npx runs in the daemon's data folder, never the project's, so a project's `node_modules` or `.npmrc` can't swap the adapter (flagged by the automated security review in step 3). The chat's folder must be an absolute path to an existing folder and reaches the agent only as the session's `cwd`.
- A panic while handling something the agent sent is turned into a JSON-RPC error instead of crashing the daemon, and a malformed elicitation form is refused (automated security review, step 5).
- `ListFiles` (step 16) lists any absolute folder the client names (with the client token), through `git ls-files` or a directory walk, 20,000 names at most; it reads names, not contents. Mentioned files go to the agent as `file://` links, which Claude reads with its own permissions.
- `GetDiff` runs `git` in the folder the client names, as you, with `core.fsmonitor` off and `--no-ext-diff`/`--no-textconv`. Clean filters (`filter.<name>.clean`) still run when `git diff` reads the work tree, as they would for your own `git status` there: a filter needs a config entry, which a cloned repository can't carry, so it takes someone who can already write your `.git/config` or global config. The automated review in step 10 suggested going further (an empty attribute source, or diffing blobs without git's work-tree comparison); I left that for you to decide. A symlink in the work tree is shown as its target path (as git sees it), never followed.
- Agent text is rendered as markdown; the app never loads images it names (an image URL in a tool's output could otherwise leak data to a server). Links open in the default browser on click, http and https only (step 12); a link's text can differ from where it goes, as on any web page. (Both from the automated security review in step 4. Since step 13 diffs are no longer put into markdown, so the fence that guarded them is gone.)
- The client token (`token`, mode 0600) sits next to the socket in a 0700 folder; any process running as you can read it ([ADR 0005](docs/adr/0005-clients-authenticate.md)).

## Working notes

- Screenshots of the app window are only current while the window is in front: macOS stops Flutter drawing an occluded window.
