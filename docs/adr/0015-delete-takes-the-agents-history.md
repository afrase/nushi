# 0015. Deleting a chat deletes the agent's history of it, through ACP

## Context
Until 2026-10-23 a chat could only be removed: Nushi forgot it, and Claude's history of the session (and the chat's scratch folder) stayed, resumable from the terminal. Removed chats piled up in `~/.claude/projects/`, and scratch folders were never cleaned up. ADR 0008 says chats belong to the agent, so the agent's history is the agent's to delete.

## Decision
- The chat menu offers Archive (keep it) and Delete… (get rid of it); Remove is gone from the app.
- Delete asks the agent to delete its history of every session the chat had (a moved chat has one per folder) with ACP `session/delete`, on a new agent process, then deletes the chat's scratch folder (only `scratch/<chat id>` in Nushi's data folder, which Nushi made) and Nushi's record. If the agent doesn't advertise `sessionCapabilities.delete`, its history stays, and the confirmation says so.
- Nushi never deletes the agent's files itself: `internal/claudehistory` has no delete.

## Consequences
- A deleted chat can't be resumed with `claude --resume`; the confirmation lists the session ids that go.
- The daemon learns whether the agent can delete by starting it once (when the first Delete dialog opens, unless it did already).
- The `RemoveChat` RPC stays for older apps (the API only grows). Since removed: it is no longer in the proto.
- Claude leaves the folder's (now empty) history folder behind; that's Claude's.
- codex-acp 2.2.2's `session/delete` archives the session (`$CODEX_HOME/archived_sessions`) rather than deleting it: `codex resume <id>` offers to unarchive it, and the dialog says so (`Agent.delete_archives`).

## Amendment (2026-10-26): a session the agent deleted takes the chat with it
Claude Code deletes sessions older than `cleanupPeriodDays` (30 by default) when it starts; Nushi keeps no transcript of its own, so such a chat could never reopen. The owner chose not to raise the limit, and to have Nushi forget the chat rather than keep a dead one.
- When it's certain the agent no longer has a chat's session, Nushi removes its own record of the chat, nothing else: the worktree, its branch and the scratch folder's files stay (an empty scratch folder goes). Certain means: the chat had messages, its folder is there, and either the agent's `session/load` says the session doesn't exist (Claude's -32002, Codex's "no rollout found", PiG's bridge's -32002) and, for Claude, its project folder for the chat's folder can be read and lacks the transcript (the adapter answers -32002 also when Claude Code quits early); or, when the chats are listed (at most hourly, no agent started), that file check alone. A history folder that's missing or unreadable (another `CLAUDE_CONFIG_DIR`, a drive not mounted) proves nothing, and a Codex session that's only archived is still Codex's.
- A chat whose worktree has uncommitted changes or commits its base lacks (or can't be checked), or whose scratch folder has files, stays, marked: its notice says the agent no longer has the session and why the chat stays, with Delete…; it never tries again and refuses messages.
- Each removal is logged (chat, agent, why) and listed once in the app ("Removed n chats whose sessions Claude deleted"), from the daemon's memory until the app dismisses it: a daemon restart before the app saw it loses only the notice.

## Amendment (2026-10-26, later): a chat with Nushi's copy stays
A chat whose session its agent deleted stays when Nushi has a copy of its transcript ([ADR 0047](0047-nushis-copy-of-transcripts.md)): read-only, the copy its transcript, with Delete… and Start a new chat here. Clearing the copy lets it go as above. Delete removes the chat's copy with the rest.

## Amendment (2026-11-22): an agent that won't start keeps its history, not the chat
When the agent can't start to say whether it deletes (its quick ready check fails, or its start does), the plan says its history stays, as for an agent without `session/delete`, and Delete removes the rest: a chat of an uninstalled or broken agent can still be deleted. Nothing is remembered of a failed start, so the next dialog asks again. When the plan said the history goes but the agent won't start at Delete, the chat stays (the user was told its history goes) and the error says so; the next Delete plans again.
Later the same day: Delete honours the plan the user last saw. When the chat's last plan said the history stays, Delete leaves it even if the agent could start by then; a Delete with no plan before it still asks the agent.
Later still: the plan says when the history stays because the agent couldn't start, and the dialog says that instead of promising its resume command opens the history (the agent may be gone).

## Amendment (2026-11-24): the file check runs each hour, not when the chats are listed
The check of the agent's files alone runs in the daemon as it starts and each hour while it runs (after the clearing of old transcript copies), not when the app lists the chats: a list ran it once per app connect (never while the app was quit), made the list wait on git, and a list cancelled midway kept a chat with a wrong reason.
Later the same day: the first check runs as the daemon starts, as the first list made it, so a chat whose agent deleted its session while the daemon was down goes at once rather than an hour later.

## Amendment (2026-11-25): only the user deletes a chat
The owner lost a chat this way: its session was gone, Nushi had no copy (it was last used before copies existed and had slept since), and Nushi removed it. He expected the opposite: Nushi's copy is there so Claude's cleanup can't take a chat, and Nushi shouldn't delete a chat because Claude did.
- A chat whose agent no longer has its session is marked and kept, copy or not, work or not, whether the hourly file check or a reopen found it, and clearing a gone chat's copy keeps it too. Nothing of it is touched (its worktrees, its branch, its scratch folder, empty or not). It shows what it has: the copy as its transcript where there is one, else its title, folder and the notice that the agent no longer has the session; Delete… and Start a new chat here either way. Its notice names its worktree's or scratch folder's work, which Delete… asks about.
- The removed chats' list is gone from the daemon: `ListChats`' `removed` is always empty and `DismissRemovedChats` does nothing (the proto keeps both, ADR 0004). API 151 says so; the app's bar stays for a daemon below it and goes with the floor (`keepsGoneChatsApi`).
Later the same day: so that such a chat still shows its transcript, Nushi makes the copy of a Claude chat that has none before Claude deletes its session ([ADR 0047](0047-nushis-copy-of-transcripts.md)'s amendment of the same day).
