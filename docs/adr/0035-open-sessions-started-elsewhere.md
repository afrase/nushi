# 0035. Sessions started elsewhere open as chats, not copies

## Context
An agent's sessions outlive Nushi's chats: started with `claude` or `codex` in a terminal, or by another app. Nushi keeps no transcript of its own (ADR 0008, 0027), and every agent but ACP lists its sessions (`session/list`) and reopens one (`session/load`). A session may still be open where it started.

## Decision
- The New chat dialog's second step lists the picked agent's sessions in the folder (from No folder, every folder's) that aren't Nushi's: not a chat's, nor one a chat had before a move or rewind, nor a throwaway fork; and not a fork at all (each agent's own mark: Claude's `forkedFrom`, Codex's `forked_from_id`, omp's `parentSession`), nor a subagent's (the agents leave those out themselves). Opening one makes it a chat in that folder through `session/load`, as after a daemon restart; nothing is copied, and Delete then deletes (or archives) its history as for any chat.
- Listing follows capabilities: an agent without `session/list` and `session/load` has no list.
- Two writers: warn, don't block. Where it's cheap and reliable, Nushi tells a session open elsewhere, and only looks: Claude's running CLIs' records (`~/.claude/sessions/<pid>.json`, the process alive and started when the record says), Codex's thread writer lock and omp's session owner lock (F_GETLK, never taken), Ante's `events.jsonl` held open (lsof; Ante takes no lock). Claude and Ante let both write: opening asks first, saying neither will see the other's turns. Codex and omp let one process write (Codex refuses the second, omp moves it to a new session), so such a session isn't offered until it's closed there.

## Consequences
- A session opened from a terminal is a chat like any other: sleep, archive, rewind, move, open in a terminal, delete.
- The checks for open sessions and forks read the agents' private files; a new agent version can change them (each lives in the agent's own package).
- A user's own fork (`claude --fork-session`, `codex fork`) isn't listed either.
- Deleting an omp chat leaves omp's history, so its session can be opened again.

## Alternatives considered
- Copying the transcript into Nushi: a second history that drifts (ADR 0008).
- Refusing a session open elsewhere for every agent: Claude and Ante handle two writers, and Nushi doesn't decide how agents are run.
