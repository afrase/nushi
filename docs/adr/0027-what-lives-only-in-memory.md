# 0027. What lives only in memory

## Context
Nushi keeps little on disk: a JSON file per chat (ADR 0010), the remembered mode, the trusted folders, and the app's settings. The agent keeps the conversation (ADR 0008).

## Decision
- The daemon keeps in memory only: each chat's transcript (rebuilt from the agent with `session/load` after a restart), its queue of messages, its usage and cost, side chats, terminals, and whether the agent can delete its history (learned by starting it once per run).
- The app keeps in memory only: what is written in each chat's box (its draft, side question included), the last context breakdown per chat, and checked MCP states per folder. It keeps on disk, in the data folder, `app.json` (panel, cards, panes, scopes, worktree choices, open terminal panels) and `reviews.json` (review comments, the app's drafts).
- After a daemon restart chats reopen only when opened or prompted (each is an agent process); an archived chat shows no history until unarchived.

## Consequences
- A daemon restart loses queues, usage, running turns and pending prompts, side chats and terminals; quitting the app loses drafts.
- Storing any of these needs a reason and a new place on disk.
