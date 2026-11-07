# 0090. A Files pane beside the chat, listed by the daemon

Status: accepted, 2026-11-04. [0096](0096-editing-in-the-preview.md) amends it: a file it opens can be edited.

## Context
The roadmap's Files view wanted "a file tree of the chat's folder to open any file", for seeing what the agent made as Claude Code's artifacts do. The approved mocks (the roadmap links them) draw the preview pane beside the chat and no tree. A tree needs the folder's entries; the app shouldn't read the disk itself (the phone can't, and the daemon may one day run a chat elsewhere), and the phone's requests come through the relay.

## Decision
- **A side pane of its own, left of the preview** (`files`, about 260 wide): tree, then the file it opened, as an IDE has them. ⇧⌘E, View › Files, the palette and the chat's ⋯ open and close it; it's remembered per chat (`filesChats`). Opening a file goes through `ChatState.openPreview`, so it's a preview tab like any other (ADR 0070), read-only (ADR 0019). A file the preview can't show (a zip, an unknown type) is dimmed and opens nothing.
- **The daemon lists, a folder at a time** (`WatchChatFolder`, API 103): the folder's entries, folders first, then again on each change, polled each second as `WatchChatFile` is; git runs (`check-ignore`) only when something changed. The app holds one stream per folder in sight; a folder is listed when it opens.
- **What's hidden**: `.git` always, by any name (a link to it too). What git ignores is left out unless the pane's eye shows it, dimmed (one app-wide switch, `filesIgnored`). A tracked file under an ignore pattern shows, as git sees it.
- **The caps**: 500 entries a folder by default, 2,000 at most, the rest counted as "N more" (counted up to 50,000 read); three levels and 5,000 entries a call. The filter looks through git's list of the folder (`ListFiles`, 20,000 at most), so it finds what isn't listed past a cap, plus whatever is listed.
- **The path is untrusted**: relative, no `..`, no empty part, no `.git`, 4096 bytes, read through `os.Root`; a link out, a loop or a dangling link is listed as a link and never followed. Refusals are fixed text, so a client's path stays out of the log.
- **The phone** has the same tree as a screen (the chat's ⋯ › Files), each row a touch target; a file opens full screen.

## Consequences
- The files the chat wrote are marked from its tool calls (`chatWrote`: every file it wrote or edited, code too), and the folders holding them; a file changed in a terminal isn't.
- Watching costs a stat of each folder in sight and each entry it sent, each second, while the pane shows. A big open folder (node_modules, shown) costs up to 2,000 stats a second.
- A changed nested `.gitignore` is seen when its folder or an entry changes, not on its own (only the top one is watched).
- In a window too narrow for the panes beside the transcript, they lie over it, as before.

## Alternatives considered
- The tree in the details panel, under Artifacts: 264 points among other widgets, a scroll in a scroll, and nothing at all in a narrow window.
- The tree inside the preview pane: the pane exists only with a file open; a tree with no file would need a pane state of its own.
- A header tab, as Changes is: it would take the chat's place, where the point is to see the files beside it.
- The app reading the folder (`Directory.watch`): the phone can't, and every path the daemon checks would be checked twice.
- A whole-folder listing up front: a repository with node_modules would send hundreds of thousands of names.
