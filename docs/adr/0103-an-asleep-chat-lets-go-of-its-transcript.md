# 0103. An asleep chat lets go of its transcript

Status: accepted, 2026-11-09.

## Context
The daemon held every chat's transcript it had looked up, text and images, for as long as it ran: a chat opened once, renamed or asked for its worktrees stayed in memory, asleep or not. A chat of 5,600 items with 200 screenshots (a 30 MB copy, 83 MB with its images) held about 85 MB of live heap after it was put to sleep, and its first open after a start read its copy twice (the lookup, then the merge with the agent's replay), to a 233 MB footprint.

## Decision
- **A chat whose agent doesn't run lets go of its items when its copy ([ADR 0047](0047-nushis-copy-of-transcripts.md)) holds them all**: copies on, nothing unsaved, no write that failed, nothing under way that reading back would end, no work, queue, side chat or subagent session. An asleep chat lets go at once, shown or not; another (archived, failed to reopen, not yet reopened) once no client shows it, looked at each minute. The items that only show (the reopen's and merge's notices, which the copy never has) stay, each with the id of the item before it.
- **A chat looked up after a start begins so**: its copy is its transcript until something needs it whole.
- **Reading doesn't take them back**: the recent part, a page and an image are read from the copy (its items' heads, then only the page's records, by an index of where each is in the file; the store keeps two chats' indexes); a whole snapshot reads it whole and lets it go. What changes the transcript (a message, a rewind, a move, a notice) reads it back first, under the chat's lock.
- **Nothing is sent either way**: a client sees the same items and the same event numbers; letting go and reading back are invisible to it.
- **A reopen's merge takes the items it holds for the copy** when they are the copy's as it stands, so a copy is read once.

## Consequences
Measured on that chat, through the API, on a dev daemon:
- Asleep, it costs its index while it's read (about 1 MB; none once two other chats are read) instead of its transcript: 85 MB of live heap became 5 MB. The first open after a start went from a 233 MB footprint to 157 MB, as its copy is read once.
- A page of 200 items of an asleep chat (images inline, as the Mac takes them) takes about 70-80 ms, against 16 ms from memory; the first read after a start or a write also reads every head (about 150 ms for a 30 MB copy).
- Waking reads the transcript back whole: a message to it was answered in 0.5-1.1 s, against 0.1 s while it held its items.
- An awake chat still held its images; it holds them as references since [ADR 0105](0105-an-awake-chat-holds-its-images-as-references.md).

## Alternatives considered
- Taking the chat out of the service: its event numbers, queue, picks and notices would go with it.
- Keeping recent pages in memory: the app keeps what it shows; the daemon would hold it twice.
