# 0080. No title bar

## Context
The owner: the bar with the traffic lights and the word Nushi is wasted space. macOS lets a window's content run under a transparent title bar.

## Decision
- The Mac window has no title bar: its content reaches the top, the traffic lights over a strip left at the top of the sidebar. The chat's header sits at the top of the window.
- The bars that come and go at the top (the daemon's banner, its update, removed chats, notices) sit beside the sidebar, not across the window, or the traffic lights would cover them.
- The empty parts of the sidebar's strip, the chat's header and a pane's header do what a title bar did, through `nushi/window`: a drag moves the window, a double click zooms it (`WindowDrag`). It sits under what's in a header, so a button there keeps its clicks.

## Consequences
- The sidebar gains nothing: its strip is as tall as the bar was. The rest of the window gains 28 points.
- Jira, GitHub and Settings have their own headers, which don't drag: the sidebar's strip does.
- In full screen the strip stays, with no traffic lights in it.
