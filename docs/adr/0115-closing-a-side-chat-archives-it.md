# 0115. Closing a side chat archives it, with Undo

Status: accepted, 2026-11-14.

## Context
A side chat's × ended it and had the agent delete its conversation, so one with messages asked first (ADR 0027 keeps side chats in memory; ADR 0067's Keep as chat was the only way to keep one). The owner wants Claude's desktop app's way: × ends it at once, and a toast, "Archived 1 side chat" with an info icon, Undo and ×, says it was kept.

## Decision
- **The daemon archives it** (`ArchiveSideChat`, API 117), so every client's × does the same: a side chat with messages is kept as Keep as chat keeps it (ADR 0067: a chat of its own on its session, the chat's conversation then its own, its mode and picks, its chat's color) but archived, titled "Side chat of <the chat's title>", its running turn stopped first rather than refused. Its record says where it came from (`ChatRecord.SideOf`: the chat and how many of its items were the chat's). It shows in Archived as any archived chat, and Delete removes it as any chat; unarchiving makes it a chat of its own (`SideOf` cleared). A side chat with no messages just ends, as before.
- **Undo is one call** (`RestoreSideChat`): the chat's agent forks the archived chat's session (as it forks the chat's for a side chat), the side chat starts with its transcript, mode and picks, and the archived chat goes, its record, copy and uploads, and its session through the chat's agent as a side chat's. Refused, with a reason the app shows in the toast, when the chat it came from was deleted or archived, or has a side chat open.
- **The app's toast** is the app's toast (a `SnackBar`): an info icon, "Archived side chat", **Undo** and ×, for ten seconds. Undo opens the side chat beside its chat, shown; a refusal replaces the toast with "Couldn't undo: <why>". A daemon older than API 117, or one that refuses to archive (its agent can't reopen sessions), gets the old way: confirm, then end.
- **The phone has no side chats**: it shows an archived side chat in Archived, as any.

## Consequences
- A side chat's conversation outlives its ×: archived side chats gather in Archived until deleted.
- Undo forks rather than reopening the archived session: a side chat runs on its chat's agent, and a fork gives it a session of its own there with nothing to replay.

## Alternatives considered
- Composing Keep as chat and Archive in each client: two calls, a moment when the kept chat is listed and not archived, and a phone and Mac that could differ.
- Holding the closed side chat alive for the toast's time, then archiving: Undo would be cheaper, but the daemon (or a crash) would decide when a conversation is kept.
