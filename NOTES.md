# Notes

## Summary (2026-10-22, after step 10)

All ten steps are done, one commit each, on `main` (not pushed). `make test` passes: Go unit tests, two end-to-end tests against a fake agent (app quit, daemon restart), the Dart transport tests and a Dart test of the app's snapshot-plus-events logic. Every step was also tried by hand against live Claude (claude-agent-acp 0.94.0, Claude Code 2.1.308) by driving the app.

**What works**
- `make run` starts `nushid` (if it isn't running) and the app. The app connects over a Unix socket with a token, and shows "Daemon not running" when it can't.
- Chats with Claude in any folder: streaming markdown replies, tool calls as collapsed rows with status and output, permission prompts as cards with Claude's own options, AskUserQuestion as an answerable card (options, multi-select, "Other", digit keys, Enter, Skip).
- Pickers for every config option Claude sends (Mode, Model, Effort, Fast mode, Agent), one Mode picker; the last mode picked is remembered per agent and new chats start in it.
- A sidebar of chats grouped by folder; new chats in a picked folder or an existing one; switching keeps each transcript. Chats are stored as small JSON files.
- Quitting the app leaves agents running; reopening it shows each chat's transcript and any waiting prompt, which can still be answered.
- Restarting the daemon: a chat is reopened through `session/load` when opened, its transcript rebuilt from Claude's replay, in its last mode.
- A Changes tab per chat shows the folder's uncommitted changes (against HEAD, untracked files included) side by side with `diff_view` from pub.dev: ribbons, word highlights, folded unchanged lines. It reloads when the agent finishes a turn.

**What doesn't (yet)**
- No way to stop a running turn (`session/cancel`), delete or archive a chat, or rename one.
- Not shown: the agent's thoughts, plans, usage and cost; terminal output (the client doesn't offer the terminal capability).
- An agent that crashes while the daemon runs isn't noticed: its chat's next prompt fails with the error, and the chat isn't reopened until the daemon restarts.
- The sidebar doesn't mark chats that wait on you.
- Links in agent markdown aren't clickable, and images aren't loaded (on purpose, see the security notes).
- The diff covers only uncommitted changes in the chat's folder; no branch diff, no review comments. Diffing a large file runs on the UI thread.
- The app was only run in debug builds (`flutter run`); no packaged `.app`.

**Decisions to revisit**: see [the list below](#decisions-to-revisit). The ones most worth a look: chats reopen lazily after a daemon restart; the diff API calls `internal/git` directly (no feature package); `flutter_markdown_plus` instead of the POC's healing renderer; no full-access warning on modes.

**Size**: the daemon is 1,662 lines of Go (limit 5,000), the ACP client 716 (limit 2,000, its type generator included), the app 1,402 lines of Dart (limit 6,000), plus 131 in the transport package. The largest hand-written file is `acp/internal/acpgen/main.go` at 393 lines. Six steps went over the ~500-lines-per-step tripwire; what pushed each is under "Tripwires crossed".

**Test data left behind**: none in the data folder (`~/Library/Application Support/Nushi Next` has only its token; I removed the test chats and the remembered mode). Claude keeps its own history of the test sessions under `~/.claude/projects/` (folders named after this session's scratch directories).

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

Tripwires crossed:
Lines added per step, code and tests, without generated code (the tripwire is about 500): 1: 533, 2: 1,502, 3: 239, 4: 437, 5: 739, 6: 639, 7: 464, 8: 537, 9: 265, 10: 528, 11: 1,249, 12: 625, 13: 476, 14: 343.
- Step 1 (533): the Unix-socket transport package and its tests came with the skeleton.
- Step 2 (1,502): the whole ACP client landed in this step (JSON-RPC framing, client and the schema-to-Go type generator, about 660 lines), plus the first real chat screen and the daemon's chat feature. None of it is for later steps.
- Step 5 (739): the question card is the app's biggest widget (267 lines: options, multi-select, Other boxes, digit keys); reading the form in order, and two fixes to the type generator.
- Step 6 (639): config options on both sides (normalizing, setting, remembering, the store) and the pickers, with tests.
- Step 8 (537): the fake agent (about 200 lines) and the end-to-end test (185) that the step asks for.
- Step 10 (528): the git reader and its test, the Changes view, and the app's first Dart test.
- Step 11 (1,249 added, 399 removed): the POC's tokens, theme and small widgets (about 470 lines), and every view restyled on them (sidebar, header, transcript, tool calls, cards, composer, pickers, Changes list). Tokens are written as Dart, flat, light and dark; the POC generated them from a JSON file.
- Step 12 (625): the healer lifted from the POC (300 lines, about half of the POC's) and its tests, the code block builder, and the style mapping.
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

## ACP quirks

- `session/new` requires `mcpServers`: send `[]`, never `null`.
- claude-agent-acp 0.94.0 puts a `messageId` on every `agent_message_chunk`; chunks are grouped into messages by it (by the last message when it is missing).
- The adapter logs progress (`[session/create] ...`) on stderr; nushid copies it into its log.
- Between chunks Claude sends `usage_update` (context size, cost), and the `prompt` result carries a `_meta.quota` usage report. Both are ignored for now.
- Claude names its sessions itself: soon after the first prompt it sends `session_info_update` with a short title ("Apple" for "Reply with just the word apple."). Nushi uses the first line of the first prompt until then.
- `session/load` on Claude replays the user's messages, the agent's messages and the tool calls (with their final status and output), not permission prompts or questions. Messages carry `messageId`s in the replay too. Loading a session takes under a second once npx has the adapter.
- Claude's tool calls arrive as a `tool_call` with a generic title ("Terminal", "Read File") and empty `rawInput`, then `tool_call_update`s that set the real title (the command, "Read notes.txt"), then content. The first content is the command's description; the final one (with `status: completed`) is the output in a fenced block. Each update's `content` replaces the previous one.
- Claude 2.1.308 searches and lists with `Bash` (`grep -rn`, `ls *.md`), not its Grep and Glob tools, so searches show as commands. A failed command's output starts with `Exit code N`; there's no exit code field. An `Edit`'s ACP `diff` holds the edited snippet (`old_string`/`new_string`), not the whole file. Tool calls carry `locations` (absolute paths) once the real title arrives.
- Claude sends no `agent_thought_chunk`s here: the adapter says recent models stream thinking "omitted" (signature only), and neither `showThinkingSummaries` in the project's settings nor `MAX_THINKING_TOKENS` (Opus, Sonnet, Haiku) changed that. Thoughts are built to ACP and were tried with the fake agent only.
- Claude keeps a todo list (ACP `plan` updates, full list each time) only when its todo tools are on: `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in its environment. Without it, `TodoWrite` and `TaskCreate` aren't there and Claude says so. With it, Claude uses `TodoWrite` or `TaskCreate`/`TaskUpdate` (the adapter hides the task tool calls and sends the plan). In Plan mode Claude writes the plan before asking to leave Plan mode, so the checklist sits above the approval card.
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

- nushid starts Claude with `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` (unless the variable is already set) so plans show up; that's the one place Nushi changes how Claude runs.
- A plan updates in place: the turn's plan item (since the last prompt) is replaced; a new turn starts a new one. While the agent works, the current step also shows on one line above the composer, since the plan itself may have scrolled away.
- Thoughts show as a dim "Thinking…" line (spinner while it's the newest item and the agent works), collapsed; opening it shows the text, italic, plain (not markdown).
- The fake agent has `think` and `plan` scripts, and `acp/acptest/fakeagent` runs it on stdio. To watch them in the app: build it, put an `npx` that execs it first on `PATH`, and start `bin/nushid` with that `PATH`.

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
- `GetDiff` runs `git` in the folder the client names, as you, with `core.fsmonitor` off and `--no-ext-diff`/`--no-textconv`. Clean filters (`filter.<name>.clean`) still run when `git diff` reads the work tree, as they would for your own `git status` there: a filter needs a config entry, which a cloned repository can't carry, so it takes someone who can already write your `.git/config` or global config. The automated review in step 10 suggested going further (an empty attribute source, or diffing blobs without git's work-tree comparison); I left that for you to decide. A symlink in the work tree is shown as its target path (as git sees it), never followed.
- Agent text is rendered as markdown; the app never loads images it names (an image URL in a tool's output could otherwise leak data to a server). Links open in the default browser on click, http and https only (step 12); a link's text can differ from where it goes, as on any web page. (Both from the automated security review in step 4. Since step 13 diffs are no longer put into markdown, so the fence that guarded them is gone.)
- The client token (`token`, mode 0600) sits next to the socket in a 0700 folder; any process running as you can read it ([ADR 0005](docs/adr/0005-clients-authenticate.md)).

## Working notes

- Screenshots of the app window are only current while the window is in front: macOS stops Flutter drawing an occluded window.
