# 0089. The sidebar's arrangement and sections are the Mac's

## Context
The owner wanted the sidebar arranged as Claude Code's desktop app lets you: group by date, status, folder or none, sort, pick what rows show, and sections of your own that chats are moved into (2026-11-03). Pins are the daemon's so the phone has them ([ADR 0064](0064-the-daemon-keeps-pinned-chats.md)); a project's own order is the Mac's `app.json`.

## Decision
- **The arrangement and the sections live in the Mac's `app.json`** (`sidebarGroupBy`, `sidebarSort`, `sidebarAscending`, `sidebarShows`, `sidebarSections`), as the projects' order does: a view of the chats, not something about them. A section is an id, a name, its chats' ids (the last moved in first) and whether it's collapsed; a chat deleted leaves it with the other prefs kept by chat.
- **Pinned wins.** It stays on top in every grouping; sections sit under it, above the grouping's groups. A chat moved into a section (by a drag or Move to section) is unpinned, so it shows where it was put; pinning a chat in a section shows it in Pinned and keeps its place in the section for when it's unpinned. A chat is in one section at most.
- **The order is the user's only by project and by hand** (Sort by Manual, the default, shown only there). Under another grouping or sort a drag can only move a chat into a section, or out of one onto the groups; the menu says which applies.
- **Last updated** is the daemon's: a chat's record keeps when a message was last sent to it or a turn of it last ended (`Chat.updated_unix_ms`).
- **The Arrange button shows under the pointer** (and with the focus, and always while the sidebar is arranged otherwise, with a dot), so the default sidebar looks as it did.
- Reset to defaults puts the grouping, sort and what rows show back; it keeps the sections.

## Consequences
- The phone keeps its own list (Needs you, Pinned, then projects), without the Mac's grouping, sort or sections.
- A second Mac doesn't see the first's sections.

## Alternatives considered
- Sections in the daemon, as pins: the phone and another Mac would have them, at the cost of an API for what is a way of looking at the list.
- A section keeping a pinned chat in Pinned without unpinning: a move that shows nothing.
- The Arrange button always shown: easier to find, but every sidebar golden and the default look change for a control most never touch.
