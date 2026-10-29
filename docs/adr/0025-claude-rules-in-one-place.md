# 0025. Claude's rules live in internal/claude*, features take a Dialect

## Context
By 2026-10-23 the chats feature and the API knew Claude's quirks: the AIR fork meta, `_meta.claudeCode`, the subagent handback, `/context` and its parsing, the double delete, the fork title. Adding another agent (Codex, Gemini) would have meant touching the features and the app.

## Decision
- Everything that knows Claude Code or its ACP adapter is in `internal/claude` (starting the adapter, the _meta it reads and sends, its quirks, `/context`'s format) or in a package named `claude*` for Claude's files (`claudehistory`, `claudemcp`, `claudetrust`).
- `features/chats` declares what it needs from an agent beyond ACP as `chats.Dialect`, a struct of values and functions; a nil field means the agent has none of it. `cmd/nushid/main.go` fills it from `internal/claude`. The API calls no Claude package.
- The `mcp` feature stays Claude-only, and says so: moving Claude's scope model out of it would cost more than it saves until a second agent has MCP config to show.
- Features follow each other through the events hub where one reacts to another's change (terminals close when their chat is archived or deleted), not through the API handlers.

## Consequences
- A second agent means a second `Dialect` and launcher in `main`, plus its own MCP and trust packages; the app names the agent from the chat.
- The chats tests use Claude's dialect where they test what it drives (subagents, rewind).
- Milestone S did it for Codex: `chats.Kind` names each agent with its launcher, dialect, history copy and resume command; Codex's rules are in `internal/codex` and `internal/codextrust`, and each chat keeps its agent.
- Milestone T added Ante (`internal/ante`, its own ACP bridge, ADR 0030) and oh-my-pi (`internal/omp`) the same way. `Dialect.Context` lets an agent say what fills its context through an extension of its own (Ante's `_ante/context`), with no throwaway fork; the trust packages share `internal/folderfiles`.
