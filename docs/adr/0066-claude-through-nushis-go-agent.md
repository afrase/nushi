# 0066. Claude through Nushi's Go agent (draft)

A draft: the Go agent is in, off by default. The default flips by an amendment once the conditions below hold.

## Context
Claude runs through claude-agent-acp 0.94.0 under the user's Node ([0037](0037-agents-you-set-up.md)): a Set up that downloads 9 MB into 73 MB, Node on `PATH`, a Node process per chat beside each `claude`, and the TypeScript Agent SDK inside, whose code is all rights reserved, so its behaviour can only be observed. Nushi reads the adapter's wire shape and a few vendor extensions (`_meta.claudeCode`, `_claude/origin`, the subagents RFD, fork-at).

`claude` itself speaks a stream-JSON control protocol on stdio when its stdout isn't a terminal: user messages in; messages, results and control requests (permissions, hooks, elicitations) out. Both official SDKs drive it that way. It is undocumented, but the Python SDK (MIT) shows it, and ships the transcript helpers (list, read, fork, delete) the adapter's SDK keeps.

## Decision
- **Two Go packages at the module's root**, outside `internal/` so they can move to repositories of their own: `claudeagent`, a client for that protocol (the process, framing, control requests, typed messages with the raw JSON kept; standard library only), with `claudeagent/sessions` for transcripts on disk, ported from the Python SDK; and `claudeacp`, an ACP agent on it (acp-go). It keeps the adapter's wire shape where Nushi reads it: Claude's session ids, the Messages API's message ids, the `_meta` keys, a turn's end at claude's result ([0044](0044-a-turn-ends-with-its-own-work.md)), fork-at ([0020](0020-rewind-through-a-vendor-fork.md)). The chats feature, its Dialect and the app don't change.
- **`nushid claude-acp`** runs it, as the Ante and PiG bridges run ([0030](0030-our-own-bridge-for-ante.md), [0039](0039-our-own-bridge-for-pig.md)): one `claude` per session, the user's own (`CLAUDE_CODE_EXECUTABLE`, as for the adapter), with the arguments the official SDKs pass (no `-p`, never `--bare`) and `CLAUDE_CODE_ENTRYPOINT=sdk-cli`, claude's own value for that. It has no authentication code: claude signs in as it always does, and claude's requests for credentials are refused.
- **Off by default.** `NUSHI_CLAUDE_ADAPTER=go` in the daemon's environment, read when it starts, picks it. Claude then has no adapter (no Node, nothing to set up) and no tested versions: nothing is pinned, and features are detected from what claude says it supports.
- **The default flips** when every parity scenario passes (runs of the adapter recorded at both ends against a fake Messages API, replayed through the Go agent: `chats/claude_parity_test.go`), the live checklist passes, the owner has used it for five working days with no chat bug traced to it, and a chat takes less memory than with Node. The choice then becomes a daemon setting; `node` stays selectable for one release, then Claude's Set up goes.
- **Licences.** `claudeagent/sessions` is ported from the Python SDK (MIT, "Copyright (c) 2025 Anthropic, PBC"), said in each file and in `claudeagent/NOTICE`. `claudeacp` follows claude-agent-acp's behaviour (Apache-2.0, Zed Industries) and is written fresh; a file translated from it says so, with a NOTICE. Nothing comes from the TypeScript SDK or the text embedded in the `claude` binary.

## Consequences
- Once the default flips, it supersedes 0037's Claude part: Claude needs no Node or Set up. Codex's adapter stays.
- Nushi depends on claude's control protocol, as both official SDKs do. The Go agent parses leniently, keeps what it doesn't know, and detects features; a protocol change breaks the SDKs too.
- Both agents write the same transcripts under the same session ids, so a chat can switch between them while asleep, if the replay's message ids match the live ones (the merge test gates the flip, [0047](0047-nushis-copy-of-transcripts.md)).
- [0017](0017-context-breakdown-from-claude.md), 0020, 0044 and [0065](0065-nushi-stops-background-commands-itself.md) stand as they are; their workarounds can go as the Go agent adds extensions, each by an amendment.
- Until real runs are recorded, the Go agent's behaviour is the adapter's as read in its source (`docs/facts/claude.md`, Go agent).

## Alternatives considered
- Staying on the adapter: Node, a Set up, a Node process a chat, and behaviour inside a bundle we can't read.
- Speaking claude's protocol from the chats feature itself: the Dialect, the transcript code and the tests would all change, and the result would serve Nushi alone; an ACP agent keeps Nushi as it is and serves any ACP client.
- One-shot `claude -p` per prompt: no live permissions, questions, steering or cancel.
