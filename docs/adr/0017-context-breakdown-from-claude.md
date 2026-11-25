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

**Amendment (2026-11-25): Claude is asked, not forked.** Claude runs through Nushi's Go agent (ADR 0066), whose library answers `_session/contextUsage` with claude's own `get_context_usage` answer, so the card asks that (detail `"full"`: a summary has no category for the conversation) as it asks Ante and Pi: no fork, no `/context`, nothing written into Claude's history. `internal/claude` maps claude's categories by their `kind` and `id`, never their English names, each a share of the window as `/context`'s table had it, and the lists the card showed (MCP tools, custom agents, memory files, skills) from claude's undocumented fields, a list it drops or retypes left out. Markdown is left empty, since the app shows it only for an answer without categories. So the card works on a new chat and a side chat, and the fork's gates went. It is still asked whenever the chat is idle, the card open or not, at most once a minute (what the app does; "while it is open" above is not). The first full ask of a session makes claude call the API's token-counting endpoint about thirty times; later ones none or two.

**Note (2026-11-25):** what of this still holds with Claude's Go agent is in [0066](0066-claude-through-nushis-go-agent.md)'s amendment of that day.
