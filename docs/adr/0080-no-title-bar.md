# 0080. No title bar

## Context
The owner: the bar with the traffic lights and the word Nushi is wasted space. macOS lets a window's content run under a transparent title bar.

## Decision
- The Mac window has no title bar: its content reaches the top, the traffic lights over an empty header at the top of the sidebar, as high as the chat's. Its hairline runs on into the chat's, Jira's, GitHub's and Settings' headers (`PaneHeader`), so the top of the window reads as one band.
- The bars that come and go at the top (the daemon's banner, its update, removed chats, notices) sit beside the sidebar, not across the window, or the traffic lights would cover them.
- The empty parts of those headers and of a pane's do what a title bar did, through `nushi/window`: a drag moves the window, a double click zooms it (`WindowDrag`). It sits under what's in a header, so a button there keeps its clicks.
- Amended by [0093](0093-nushi-places-its-own-window.md): the double click acts only when macOS counted the release as a second click (its interval and distance; a third does nothing), and does what the system's title-bar setting says (zoom, minimize or nothing); the zoom stays on the window's screen.
- Amended 2026-11-05 (the owner: double clicking some icons and places zoomed the window, "kind of annoying"): a double click zooms only in a header's truly empty space, not on what's in it (the agent's mark, the status, the model, a pane's title or its file's icon, a tooltip's icon, a disabled button) nor beside it: the bar's height through, and within 6 points across, so a gap inside a group and a click just above a word are the word's. A drag moves the window from all of that too, as from the empty space. A control, which `WindowDrag` tells by the pointer it shows (the hand, the text's I-beam), keeps its clicks and drags. `WindowDrag` is the header's Stack, so this is one rule for every header (`ChatHeader`, `PaneHeader`: the sidebar's top, Jira's, GitHub's, the side panes'). A native title bar zooms on a double click on its title too; Nushi's doesn't, as asked.
- Amended 2026-11-05 again (the owner, on 0.11.4: clicking a header's buttons and tabs shrank the window): AppKit still took the top 32 points, its title bar's height, for its title bar wherever no view there says it is content, and Flutter's view says nothing. Its theme frame's double-click recognizer zoomed the window on a double click on anything drawn there (a zoomed window shrank to its frame from before), and the window server dragged the window from it. A view over the content (`TitleBarCover`) now answers AppKit's own question, the one `NSButton` answers (`_opaqueRectForWindowMoveWhenInTitlebar`, as Chromium's tab strip does), with all of itself, and takes no event: the headers alone do the title bar's work. The question is AppKit's private one; `make test-window` asks AppKit, in a window it never shows, and fails if it stops asking.
- Moving the window takes the mouse's release from Flutter, which would go on dragging. The window tells it of a release it missed: after a move, and whenever the pointer moves with no button held after a press it saw no release for.

## Consequences
- The sidebar loses 16 points to its header. A chat gains 28; Jira, GitHub and Settings gain 18, their headers growing from 34 to 44.
- The traffic lights sit a little above the header's middle: they stay where macOS puts them, since moving them means re-placing them on every resize.
- A bar over the main area moves that area's hairline down, out of line with the sidebar's until it goes.
- In full screen the sidebar's header stays, with no traffic lights in it.
- The sidebar can be hidden (⌘\, `sidebarHidden`), and then nothing stands between the main area and the traffic lights. Every top header starts past them (`lightsInset`, 84 points), with the button that shows the sidebar there, and the bars, which then run across the window, start their text past them too. In full screen those insets stay, with no lights beside them.
- A bar at the window's top doesn't move the window while the sidebar is hidden; the header under it does.
