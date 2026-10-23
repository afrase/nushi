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
answer out of the transcript; `internal/claudecontext` reads the table, and
the API returns both the categories and the markdown. The app shows the
markdown as it is when no categories could be read, rather than guessing.
An agent without a `context` command gets the card as before.

## Consequences

This depends on Claude's private output format and on the adapter treating
`/context` as local; either can change without notice, which then shows as
the raw markdown. A prompt the user sends during the silent run waits for it
(a moment). Text the agent writes on its own during that moment (a background
subagent finishing) would be taken as the answer and lost from the
transcript; it hasn't been seen.
