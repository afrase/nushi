# 0070. Preview tabs are the pane's own, not the chat header's

Status: accepted, 2026-10-31.

## Context
The owner wants to look at more than one file at a time. A first build (3b39a57, 6bc6aa3, 16a4751, never released) put each file in the chat header as a closable segment beside Chat and Changes, with the file in the whole main area. The owner rejected it: "Those tabs look horrible", "It just pushes the other panes around". A redesign with a permanent side column was rejected too. Their answer: "the panel that you use to view the [file] could just show tabs if you preview multiple files."

## Decision
- **The tabs live in the preview pane's title row.** With one file the pane is what it always was. With two or more, the file name in that row becomes the row of tabs, in the same slot: no new row, so the pane's height and everything else on screen stay put. The header's tabs stay Chat, Changes and Pull request.
- **Plain names, not controls.** The showing tab is the primary text with a thin line under it, the others muted, a ✕ always on the showing tab and on the others under the pointer. No pill, segmented control or box. Past the room the widest shrink, with an ellipsis, to a least width, then the row scrolls. No overflow menu.
- **Every open is a tab.** A click in the chat, the Files list, ⌘P and the agent's `show` all go through `ChatState.openPreview`, which adds a tab or shows the one the file has, matched by absolute path. `show` keeps ADR 0068's rules: it opens only on the Chat tab, and only where the pane fits. There's no ⌘-click and no second kind of opening.
- **Tabs are the pane's life.** In memory, as the preview always was: never saved, cleared when the pane closes by its Close, by its last tab, or by a subagent's or command's pane taking its place. The pane keeps its one remembered width.
- **One view at a time.** A file's view is made again when its tab shows, with no keep-alive, so a page costs a web view only while it's seen. Its Source or Preview is remembered per file while the app runs.
- **⌘W closes the showing tab** while the pane is in sight (File › Close Tab, the way out of a web page). A focused terminal keeps ⌘W, and a dialog's is left alone.

## Consequences
- With tabs up, the name's menu of the chat's other files isn't in the row; the Artifacts widget, Artifacts… and ⌘P remain.
- Amended 2026-11-05: the menu is gone with one file open too. The owner: "this dropdown here I don't think makes sense". Tabs, the Files pane (ADR 0090), ⌘P and the Artifacts widget (with its pins) open every file it listed, and a menu on the name was a second way to switch that worked only with one file open. The name is plain text, its path in a tooltip; a click shows the file in the Files pane, folders above it opened, when it's in the chat's folder.
- Tabs live only in the pane's width, so they can't give a file the whole window. That went with the header tabs, along with their keys (⌃⌘4–9), restored tabs across launches, and the pane's Open in a tab.
- The phone is unchanged: its previews are full screen.

## Alternatives considered
- Tabs in the chat header: rejected by the owner, above.
- A permanent side column of open files: rejected by the owner; it takes room from every view for a list that's usually one file.
- A second row under the pane's title: it would change the pane's height with the number of files, moving what's under it.
- An overflow menu for what doesn't fit: more controls in a thin row, for what scrolling already does.
