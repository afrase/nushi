# 0064. The daemon keeps pinned chats

## Context
"I want to be able to reorder chats in a folder, and also pin chats to the top, outside the folder, in a pinned section or something." The sidebar's other choices (the projects' order, which are collapsed) live in the Mac's `app.json`, which the phone can't reach.

## Decision
- A chat's pin is the daemon's: `Session.Pin`, its place among the pinned chats from 1 (0: not pinned), sent as `Chat.pin` (API 90). `PinChats` sets the whole order: each chat listed pinned at its place, every other unpinned, an archived or unknown one left out. Archiving unpins; deleting takes the record with it.
- The app sends the whole order each time (pin at the bottom, unpin, a drag in Pinned) and shows it at once, going back if the daemon refuses.
- A project's own chat order stays the Mac's (`sidebarChats` in `app.json`): the phone keeps the newest first, as it does the projects' order.

## Consequences
- The phone shows Pinned (after Needs you) and can pin and unpin.
- Two clients changing pins at once: the last order sent wins.

## Alternatives considered
- `app.json`, as the projects' order: no API, but the phone without pins, and a chat's pin lost to another Mac.
- One call per chat (`SetChatPin` with a place): fewer bytes, but a reorder is then several calls that can cross.
