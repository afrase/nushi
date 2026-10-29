# 0008. Chats belong to the agent

## Context
Agents keep their own session history and can resume a session from the terminal. A second copy of the transcript in Nushi would drift.

## Decision
The agent's history is the source of truth. Nushi stores only what it needs to list and reopen sessions: ids, agent, folder, title, last mode. Transcripts after a daemon restart are rebuilt from the agent's history (`session/load`).

## Consequences
- Nushi can't show a transcript the agent can't replay.
- A session started in Nushi can be continued in the terminal, and the other way round.

## Amendment (2026-10-26): Nushi's copy of transcripts
Nushi keeps its own read-only copy of each chat's transcript ([ADR 0047](0047-nushis-copy-of-transcripts.md)), for what the agent doesn't replay (before a compaction, a session it deleted). The agent's history stays the source: resuming goes through it, the copy is never sent to the agent, and where the two differ the agent's replay wins for what it covers.
