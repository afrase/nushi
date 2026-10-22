# Notes

## Line counts

Hand-written, without tests or generated code (`make lines`). Packages are counted apart from the app.

Go is split into the daemon (`cmd`, `internal`) and the generic ACP client (`acp`, its type generator included).

| Step | Go daemon | Go acp | Dart app | Dart packages |
|---|---|---|---|---|
| 1. Skeleton | 114 | 0 | 95 | 131 |
| 2. One chat | 429 | 663 | 360 | 131 |
| 3. Tool calls | 524 | 663 | 432 | 131 |
| 4. Permission prompts | 646 | 677 | 549 | 131 |
| 5. Agent questions | 900 | 703 | 839 | 131 |

Tripwires crossed:
- Step 2 added about 1,500 hand-written lines, tests included (the limit is about 500). What pushed it: the whole ACP client landed in this step (JSON-RPC framing, client and the schema-to-Go type generator, about 660 lines), plus the first real chat screen and the daemon's chat feature. None of it is for later steps.

## Milestone A demo (steps 1–5): one working chat

1. `make run`. The window says "Daemon not running" for a moment, then "Connected". (`make stop`, and it says "Daemon not running" again within two seconds; `make daemon` brings it back.)
2. Click **Start a chat in a folder…** and pick a folder. Claude starts there (a few seconds the first time, while npx fetches the adapter).
3. Ask something; the reply streams in as markdown.
4. Ask it to run `ls -la` and read a file: each tool call shows as one collapsed line with its icon, title and status (a spinner, then a check); click it for the output.
5. Permission prompts: Claude only asks in its Manual mode (`default`), and its mode picker comes in step 6. Until then, use a folder whose `.claude/settings.json` is `{"permissions":{"defaultMode":"default"}}` and ask for `touch x.txt`: a card shows Claude's own options ("Yes", "No"). Pick one; the card says what you answered and the agent carries on (or doesn't).
6. Ask: "Use the AskUserQuestion tool to ask me my favourite colour (red/green/blue) and which fruits I like (multi-select). Then repeat what you received." A card shows both questions with an "Other" box each. Digits 1–9 pick in the active question, clicks pick anywhere, Enter or Submit sends, Skip declines. Claude repeats exactly what you picked.

## ACP quirks

- `session/new` requires `mcpServers`: send `[]`, never `null`.
- claude-agent-acp 0.94.0 puts a `messageId` on every `agent_message_chunk`; chunks are grouped into messages by it (by the last message when it is missing).
- The adapter logs progress (`[session/create] ...`) on stderr; nushid copies it into its log.
- Between chunks Claude sends `usage_update` (context size, cost), and the `prompt` result carries a `_meta.quota` usage report. Both are ignored for now.
- Claude's tool calls arrive as a `tool_call` with a generic title ("Terminal", "Read File") and empty `rawInput`, then `tool_call_update`s that set the real title (the command, "Read notes.txt"), then content. The first content is the command's description; the final one (with `status: completed`) is the output in a fenced block. Each update's `content` replaces the previous one.
- Claude also sends a `tool_call_update` carrying only `_meta.claudeCode.toolResponse` (the raw tool result) before the final one; it changes nothing we show.
- In `auto` mode Claude asked nothing for `curl -X POST` or `touch`; in Manual (`default`) mode it asks before `touch`, with two options, "Yes" (`allow_once`) and "No" (`reject_once`). A permission request names the tool call it is about (`toolCall.toolCallId`), which was sent just before as a `tool_call`.
- To test prompts without a mode picker, a folder with `.claude/settings.json` = `{"permissions":{"defaultMode":"default"}}` starts Claude in Manual mode.
- AskUserQuestion needs the client to advertise `elicitation.form`. Claude first sends a `tool_call` ("Asking for your input", kind `other`), then `elicitation/create` in form mode, tied to it by `toolCallId`. Each question is a property `question_N`: a `string` with `oneOf` (single choice, options with `const`, `title`, `description`) or an `array` whose `items.anyOf` lists the options (multi-select), followed by an optional free-text `question_N_custom` titled "Other". Nothing is `required`. An accept with empty content reads to Claude as "the user did not answer"; it reads each answered question back as `"question"="answer"`.
- The form's properties must be read in wire order (they are the questions' order), so the generated types keep maps of typed values as raw JSON.
- Claude starts new sessions in whatever mode its settings say (`auto` on this machine), and reports modes both as legacy `modes` and as a `mode` config option, as the POC found.

## Decisions to revisit

- One agent process per chat; the chat's id is the agent's session id.
- The daemon keeps each chat's transcript in memory (not on disk); events carry an item, and a streamed message sends only the new text (`append`).
- The `Events` stream's first message is empty, so a client knows its subscription is live (connect-go clients otherwise wait for the first real event).
- Streaming markdown uses `flutter_markdown_plus` (pub.dev) instead of lifting the POC's healing renderer: a half-written `**bold` shows its asterisks until the closing ones arrive. Lift `heal.dart` if that bothers you.
- A tool call's output is rendered as markdown, and an ACP `diff` as a plain `-`/`+` block of the old and new text, until the diff viewer exists. Terminal content (`terminal/*`) isn't supported: the client doesn't offer the terminal capability.
- ACP types are generated by a small in-repo generator (`acp/internal/acpgen`, about 330 lines) from the pinned schema `schema-v1.26.0`: tagged unions become a struct with one pointer per variant, other unions of objects are merged into one struct.

- Connect for Go is v1 (`connectrpc.com/connect` v1.21), not v2: v1 is what the Dart generator's docs and the POC used, and nothing here needs v2.
- `http2` for Dart stays on 2.x: `connectrpc` 2.0.1 doesn't resolve with `http2` 3.x.
- The app runs without the macOS App Sandbox, so it can reach the daemon's socket in Application Support.

## Dependencies added

- Go: `connectrpc.com/connect`, `google.golang.org/protobuf` (API), buf through `go run` (codegen only).
- Dart: `connectrpc`, `protobuf`, `http2` (API), `flutter_markdown_plus` (rendering replies), `file_selector` (the native folder picker).

## Security notes to look at

- Agents run as you, with your environment, through `npx --yes @agentclientprotocol/claude-agent-acp@0.94.0` (downloaded from npm on first use, pinned by version, not by hash). npx runs in the daemon's data folder, never the project's, so a project's `node_modules` or `.npmrc` can't swap the adapter (flagged by the automated security review in step 3). The chat's folder must be an absolute path to an existing folder and reaches the agent only as the session's `cwd`.
- Agent text is rendered as markdown; the app never loads images it names (an image URL in a tool's output could otherwise leak data to a server), and links are not clickable. A diff in a tool call is fenced with a fence longer than any backtick run inside it (both from the automated security review in step 4).
- The client token (`token`, mode 0600) sits next to the socket in a 0700 folder; any process running as you can read it ([ADR 0005](docs/adr/0005-clients-authenticate.md)).

## Working notes

- Screenshots of the app window are only current while the window is in front: macOS stops Flutter drawing an occluded window.
