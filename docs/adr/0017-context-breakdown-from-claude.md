# 0017. The context card reads Claude's /context output

## Context

Claude Code's desktop app shows what fills the context (system prompt,
tools, MCP tools, agents, memory files, skills, messages, free space, the
autocompact buffer). ACP's `usage_update` gives only used and size.
claude-agent-acp 0.94.0 answers Claude's `/context` command itself (no model
call, no cost, left out of `session/load` replay) with markdown that has an
"Estimated usage by category" table.

## Decision

The daemon sends `/context` on its own while the chat is idle and keeps its
answer out of the transcript; `internal/claude` reads the table, and
the API returns both the categories and the markdown. Amended (API 141):
it also reads the lists after the table (MCP tools, custom agents,
skills, memory files) into `GetContextUsageResponse.lists`, and marks
which category is the conversation and which the buffer
(`ContextCategory.part`), so the app reads none of Claude's format. The app shows the
markdown as it is when no categories could be read, rather than guessing.
An agent without a `context` command gets the card as before.

## Consequences

This depends on Claude's private output format and on the adapter treating
`/context` as local; either can change without notice, which then shows as
the raw markdown.

Claude keeps `/context`'s answer in a conversation (5–7k tokens each time),
so it runs in a throwaway fork of the session (deleted right after), which
leaves the chat's conversation alone; the card asks on its own after a
turn, at most once a minute, while it is open. Agents that can't fork
aren't asked (a run in the chat's own session, which they once had,
went on 2026-10-24). Codex has no such command: its card shows the
context used and its size only.
