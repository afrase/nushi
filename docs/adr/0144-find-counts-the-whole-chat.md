# 0144. Find counts the whole chat

Status: accepted, 2026-11-20 (#64). Amends 0026.

Amended 2026-11-24: a tool call's input and raw output count where the app shows them (`findText` copies its `showsInput` and `showsRawOutput`), so what drifts is the title and Markdown below, and an MCP call's input whose `{server, tool, arguments}` wrapper (Codex's) the app drops to show the arguments alone (`shownInput`), which the daemon counts whole.

## Context
A long chat opens with its recent part and loads the rest a page at a time (ADR 0026). ⌘F found only in what was loaded, said so under the field, and offered Load all, which laid out the whole chat. The owner wants ⌘F in a long chat to count the whole conversation at once, and a step to a match that isn't loaded to bring it in.

## Decision
- **The daemon counts what isn't loaded.** `FindInChat` (API 136) counts a query's matches in each item before the first one the app has, in order, and answers each item's id and count, 5000 items at most: the ones nearest the loaded part, searched back from it, so a step up goes to the nearest (`more` past that). It searches the daemon's own transcript as its pages give it: the items it holds, taken under the chat's lock as strings only and searched after, or a let-go chat's copy read a chunk at a time (ADR 0103). It never reads or writes the agent's files. It matches as the loaded find does: as typed, case aside (`textfind.Literal`), in what the transcript shows of an item (`findText`). The request's context ends it, so a changed query cancels the search before. Not on a device's channel: the phone has no find.
- **The app counts by item until loaded.** `ChatFind` puts a hit for each far match (`far <item> <n>`) before the matches the transcript finds as laid out. A far match counts until its item is laid out; from then the transcript's own marks count it, so the count can move by a match where the text as written and as shown differ (Markdown's syntax, a tool row's title).
- **A step loads; typing doesn't.** Typing goes to the first match loaded (or the nearest one above, without loading; the first step, either way, loads and shows that one). A step to a far match loads from it down to what's loaded, a few items above it to read (GetChatItems' `through`, API 137, 2000 items a page, asked again past that), and lands on that item's match once it's laid out. The transcript stays one run of items to the latest (ADR 0026): a part around the match alone would leave a gap that the live chat, the pins and the rewind list would all have to know about. While find is open the chat isn't trimmed back to its recent part.
- **Typing pauses first.** What's typed is looked for a quarter of a second after the last key, in what's loaded and above it alike: a first letter matches most of a long chat. ⏎ looks at once; clearing the field clears at once.
- **At the very top, a wheel or a drag up loads.** Where typing left the list at its top nothing can scroll, so no scroll says the user wants the page before: a wheel up or a drag there does.
- **An older daemon** (below API 136) finds in what's loaded, with Load all, as before.

## Consequences
Wrapping from the newest match to the first can load most of a long chat, in pages, as Load all did. A chat whose snapshot is taken again (a reconnect, a rewind) is searched again. The count is a floor ("+") past 5000 items with matches.
