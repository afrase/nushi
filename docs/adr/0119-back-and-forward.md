# 0119. Back and Forward through the places visited

Status: accepted, 2026-11-14.

## Context
Claude's desktop app has two chevrons right of its sidebar button, Back (⌘[) and Forward (⌘]), that step through the chats visited, as a browser's do. The owner wants the same. In Nushi ⌘[ and ⌘] were the chat before and after in the sidebar's order (ADR 0049).

## Decision
- **A visit** is what shows in the chat's place (`Visit`, `visits.dart`): a chat, by id, or Jira or GitHub, which take its place as pages do in a browser, so going back from GitHub to the chat it was opened from reads as it would there. Settings isn't one (it opens over the window, ADR 0087), nor the empty view with no chat open.
- **The daemon notes them** (`Daemon.visits`): each time it notifies, what shows is noted, unless it's the visit Back and Forward are at; a new one drops those after it, and the last 100 are kept. Noting on every notify, rather than in `select` and `go`, catches every way a chat comes to show (a pick, a key, a notification, a chat archived from under the selection).
- **A step passes over** a visit whose chat was deleted or archived, and one that's the place shown; the visit stays, so a chat unarchived is a place again. `goBack` and `goForward` (`daemon_places.dart`) open the visit stepped to as a pick does.
- **Where**: two chevrons after the sidebar's button in the title buttons (ADR 0118), "Back (⌘[)" and "Forward (⌘])", greyed out (disabled) when there's nowhere to go; View › Back and Forward in the menu bar, disabled the same; the palette's Back and Forward.
- **Keys**: ⌘[ and ⌘] from anywhere: no text field binds them on the Mac, and a terminal passes the app's ⌘ keys on. On Linux Alt+Left and Alt+Right, a browser's (Control and `[` is Escape): a text field keeps them for its own line moves, and a focused terminal for its shell, as it does every key it isn't told to pass on (ADR 0104). The chat before and after in the sidebar (View › Previous Chat, Next Chat) move to ⌥⌘↑ and ⌥⌘↓, which nothing else binds; Linux keeps Ctrl+Page Up and Page Down for them.

## Consequences
- Amends 0049 (⌘[ and ⌘] no longer switch chats), 0094 (they're the app's Back and Forward, a browser tab's own staying its buttons) and 0104 (Linux's keys for them).
- The history is the window's, kept while the app runs; it isn't saved.
