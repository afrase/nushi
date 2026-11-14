# 0119. Typing anywhere in the chat writes in its box

Status: accepted, 2026-11-14.

## Context
A key typed with the transcript focused (after a click on a message, or on the empty pane) did nothing: the box had to be clicked first. Claude's desktop app and Claude Code's take it into the message box. The owner approved the same.

## Decision
- **A character typed with nothing that takes text focused goes to the chat's box** (`typeIntoBox`, `type_to_box.dart`): at its end, the caret after it, the focus with it, as if typed there, so `/` opens the commands' list and `@` the files'. Only while the chat shows in its Chat tab (`Daemon.chatShows`) and its box is there and not locked (rewinding).
- **What counts as nothing focused**: the window's own focus (the root `Focus` in `main.dart`, which hears the key last) or the transcript's (`typesThrough`). A text field, a terminal, the preview's editor, the find bar, a rename field, a button with the focus keep their keys; so do an open menu (`openMenus`, counted by `Menu`) and a dialog over the window (its route current or not).
- **Keys that keep their meaning**: any with ⌘, Control or Option (Alt), and Esc, the arrows, Tab, Enter and Space (a space alone isn't text: it presses what has the focus, and scrolls). What the focused part does with a key comes first: the transcript's R replies to its selection (`TranscriptSelection`), Esc stops a turn and Esc Esc rewinds; Shift is allowed (a capital, `?`).
- **The Mac's and Linux's window only**: the phone's box is tapped.
