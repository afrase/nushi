# 0014. Moving a chat forks its Claude session

Amended 2026-11-05: the copy is gone (below).

## Context
A chat can start without a folder (a scratch folder of its own) and move to another folder later. ACP fixes a session's `cwd` when the session is created. claude-agent-acp 0.94.0's `session/fork` with a new `cwd` looks for the source session in the new folder's history (`~/.claude/projects/<folder name>/`), so across folders it fails. A copy of the session's transcript in the new folder's history, reopened there with `session/load` and the same session id, does resume (Claude remembers, and runs in the new folder), but the adapter replays a loaded session from whichever copy of that id it finds first among all folders: after a daemon restart a moved chat could show the old folder's, shorter, transcript.

## Decision
- A chat without messages simply starts a new session in the new folder.
- A chat with messages: Nushi copies the session's transcript (`<session id>.jsonl`) into the new folder's history, has a new agent `session/fork` it with the new `cwd`, then removes its copy. The fork is a new session id that exists in one folder only, with the whole conversation. Nushi's chat id stays; the chat records the new session id. The original is never touched, so the old folder's session still resumes from the terminal.
- The old agent keeps running until the new one is ready; a failed move leaves the chat as it was.
- Everything that knows Claude's file layout is in `internal/claudehistory` (one file): the projects folder, how a folder's history is named, the copy.
- Drop it when the adapter's fork works across folders (or the adapter can move a session).

## Consequences
- Depends on Claude's private layout (Claude Code 2.1.308): a change there breaks moving, not chatting. A path with decomposed Unicode accents gets another history name than Claude's (Claude normalizes to NFC first).
- `claude --resume` takes the new session id after a move (the one Nushi's Remove dialog shows); the old id resumes the conversation as it was before the move, in the old folder.
- Subagent transcripts of earlier turns stay with the original (Claude's own fork does the same). Claude titles a fork "<title> (fork)"; Nushi keeps the chat's title.

## Alternatives considered
- Copy and `session/load` with the same session id: the replay ambiguity above, since the original must stay.
- Rewriting the transcript under a new id in Nushi: more of Claude's private format than a file copy.

## Amendment (2026-11-05): the fork finds the session, no copy
Claude runs through Nushi's Go agent ([0066](0066-claude-through-nushis-go-agent.md)), whose `session/fork` with a new `cwd` finds the session in the open session's folder, else in any folder's history, and writes the fork into the new folder's. So a move is that fork alone: nothing is copied or removed, and the original stays. `model.HarnessInfo.Moves` says an agent's sessions move this way (Claude; Codex, which finds a session by its id); another agent's chat refuses the move. One edge: a copy an older daemon left in some folder's history when it died mid-move is the start of the session, and the fork may find it first and lack the turns after it.
