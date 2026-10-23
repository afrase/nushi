# 0015. Deleting a chat deletes the agent's history of it, through ACP

## Context
Until step 26 a chat could only be removed: Nushi forgot it, and Claude's history of the session (and the chat's scratch folder) stayed, resumable from the terminal. Removed chats piled up in `~/.claude/projects/`, and scratch folders were never cleaned up. ADR 0008 says chats belong to the agent, so the agent's history is the agent's to delete.

## Decision
- The chat menu offers Archive (keep it) and Delete… (get rid of it); Remove is gone from the app.
- Delete asks the agent to delete its history of every session the chat had (a moved chat has one per folder) with ACP `session/delete`, on a new agent process, then deletes the chat's scratch folder (only `scratch/<chat id>` in Nushi's data folder, which Nushi made) and Nushi's record. If the agent doesn't advertise `sessionCapabilities.delete`, its history stays, and the confirmation says so.
- Nushi never deletes the agent's files itself: `internal/claudehistory` has no delete.

## Consequences
- A deleted chat can't be resumed with `claude --resume`; the confirmation lists the session ids that go.
- The daemon learns whether the agent can delete by starting it once (when the first Delete dialog opens, unless it did already).
- The `RemoveChat` RPC stays for older apps (the API only grows).
- Claude leaves the folder's (now empty) history folder behind; that's Claude's.
