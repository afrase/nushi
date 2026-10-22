# 0008. Chats belong to the agent

## Context
Agents keep their own session history and can resume a session from the terminal. A second copy of the transcript in Nushi would drift.

## Decision
The agent's history is the source of truth. Nushi stores only what it needs to list and reopen sessions: ids, agent, folder, title, last mode. Transcripts after a daemon restart are rebuilt from the agent's history (`session/load`).

## Consequences
- Nushi can't show a transcript the agent can't replay.
- A session started in Nushi can be continued in the terminal, and the other way round.
