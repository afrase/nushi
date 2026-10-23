# 0020. Rewinding forks the session at a message through a vendor extension

## Context
"Rewind to here" cuts a chat back to just before one of its messages, as Claude Code's CLI does. ACP v1 has no way to do that: `session/fork` (unstable) copies a whole session. claude-agent-acp 0.94.0 can fork up to a message, but only for JetBrains AIR, through vendor meta on `session/fork`: `_meta.jetbrains.air.fork = {version: 1, messageId}`, where `messageId` is the ACP `messageId` of one of the agent's messages; the fork keeps the conversation up to that message, it included.

## Decision
- Nushi rewinds by forking the chat's session at the agent's last message before the chosen one (on the chat's own agent process), or, before the first message, by starting a new session. The chat keeps its id and gets the new session id; the old session stays in the chat's earlier sessions, so Delete deletes it too (as for moves, [0014](0014-moving-a-chat-forks-it.md)).
- The vendor meta and the check for the adapter (`agentInfo.name`) live in one file, `internal/features/chats/airfork.go`. Other agents don't get the action.
- Files aren't rewound: ACP doesn't expose Claude's file checkpoints. The confirmation says so.

## Consequences
- An adapter update can drop or change the meta without notice; rewinding then fails with the adapter's error and the chat stays as it was.
- A message the agent sent without a `messageId` can't be a fork point, so the message after it isn't offered.
- Drop the vendor meta when ACP has a standard way to fork or truncate at a message.

## Alternatives considered
- Rewriting Claude's transcript file: more of Claude's private format than [0014](0014-moving-a-chat-forks-it.md)'s copy, and the session id would stay the same while its content changed under any terminal that has it open.
