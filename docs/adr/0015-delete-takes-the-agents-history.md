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
- codex-acp 2.2.2's `session/delete` archives the session (`$CODEX_HOME/archived_sessions`) rather than deleting it: `codex resume <id>` offers to unarchive it, and the dialog says so (`Agent.delete_archives`).

## Amendment (steps 269–270): a session the agent deleted takes the chat with it
Claude Code deletes sessions older than `cleanupPeriodDays` (30 by default) when it starts; Nushi keeps no transcript of its own, so such a chat could never reopen. The owner chose not to raise the limit, and to have Nushi forget the chat rather than keep a dead one.
- When it's certain the agent no longer has a chat's session, Nushi removes its own record of the chat, nothing else: the worktree, its branch and the scratch folder's files stay (an empty scratch folder goes). Certain means: the chat had messages, its folder is there, and either the agent's `session/load` says the session doesn't exist (Claude's -32002, Codex's "no rollout found", PiG's bridge's -32002) and, for Claude, its project folder for the chat's folder can be read and lacks the transcript (the adapter answers -32002 also when Claude Code quits early); or, when the chats are listed (at most hourly, no agent started), that file check alone. A history folder that's missing or unreadable (another `CLAUDE_CONFIG_DIR`, a drive not mounted) proves nothing, and a Codex session that's only archived is still Codex's.
- A chat whose worktree has uncommitted changes or commits its base lacks (or can't be checked), or whose scratch folder has files, stays, marked: its notice says the agent no longer has the session and why the chat stays, with Delete…; it never tries again and refuses messages.
- Each removal is logged (chat, agent, why) and listed once in the app ("Removed n chats whose sessions Claude deleted"), from the daemon's memory until the app dismisses it: a daemon restart before the app saw it loses only the notice.
