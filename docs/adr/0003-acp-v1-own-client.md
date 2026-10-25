# 0003. Agents speak ACP v1 through our own small client

(The client became the library `github.com/afrase/acp-go`: [0041](0041-acp-through-acp-go.md).)

## Context
The Agent Client Protocol (ACP) gives one structured protocol for Claude Code (through `@agentclientprotocol/claude-agent-acp`), Codex and Gemini. The Go SDKs (`coder/acp-go-sdk`, `caelis-labs/acp-go-sdk`) had edge cases the POC hit: a 1,024-message queue that closes the connection when it overflows, and a 10 MiB cap per message.

## Decision
- Every agent runs over ACP v1 on stdio, Claude first. No ACP v2.
- Nushi has its own client in the top-level `acp/` package: types generated from the pinned v1 schema, hand-written JSON-RPC framing and client on `encoding/json`, no Nushi logic, under 2,000 lines.

## Consequences
- Node is a runtime dependency: Claude's and Codex's adapters run on it (set up on request since [0037](0037-agents-you-set-up.md); npx ran them before).
- Updating the schema means regenerating the types.

## Alternatives considered
- An existing Go SDK: rejected for the queue and size limits above.
- Native transports per agent (Claude stream-json and the like): one protocol is less work.
