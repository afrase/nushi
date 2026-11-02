# 0080. No title bar

## Context
The owner: the bar with the traffic lights and the word Nushi is wasted space. macOS lets a window's content run under a transparent title bar.

## Decision
- The Mac window has no title bar: its content reaches the top, the traffic lights over an empty header at the top of the sidebar, as high as the chat's. Its hairline runs on into the chat's, Jira's, GitHub's and Settings' headers (`PaneHeader`), so the top of the window reads as one band.
- The bars that come and go at the top (the daemon's banner, its update, removed chats, notices) sit beside the sidebar, not across the window, or the traffic lights would cover them.
- The empty parts of those headers and of a pane's do what a title bar did, through `nushi/window`: a drag moves the window, a double click zooms it (`WindowDrag`). It sits under what's in a header, so a button there keeps its clicks.
- Moving the window takes the mouse's release from Flutter, which would go on dragging. The window tells it of a release it missed: after a move, and whenever the pointer moves with no button held after a press it saw no release for.

## Consequences
- The sidebar loses 16 points to its header. A chat gains 28; Jira, GitHub and Settings gain 18, their headers growing from 34 to 44.
- The traffic lights sit a little above the header's middle: they stay where macOS puts them, since moving them means re-placing them on every resize.
- A bar over the main area moves that area's hairline down, out of line with the sidebar's until it goes.
- In full screen the sidebar's header stays, with no traffic lights in it.
- The sidebar can be hidden (⌘\, `sidebarHidden`), and then nothing stands between the main area and the traffic lights. Every top header starts past them (`lightsInset`, 84 points), with the button that shows the sidebar there, and the bars, which then run across the window, start their text past them too. In full screen those insets stay, with no lights beside them.
- A bar at the window's top doesn't move the window while the sidebar is hidden; the header under it does.
