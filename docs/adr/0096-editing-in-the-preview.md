# 0096. Files are edited in the preview, saved by the daemon

Status: accepted, 2026-11-07. Amends [0019](0019-changes-read-only-toward-git.md) and [0090](0090-a-files-pane-beside-the-chat.md), which had the preview read-only.

## Context
The owner, looking at a file in the preview: "If I clicked the file in the view I would expect to be able to just start typing." No Edit button, no mode; "light but robust; we can add later if I use it enough". The agent may write the same file at any moment, and its harness checks staleness its own way (Claude's Edit fails when its `old_string` is gone).

## Decision
- **Where**: on the Mac, a file the preview shows as source (code and text; Markdown, HTML and CSV in their Source view) is an editor (re_editor), in the preview's code font and highlighting. A click and typing edit it. A file indented with tabs (Go, Makefiles, or mostly tab-led lines) gets tabs from Tab and Return; re_editor's own indenting knows only spaces. The phone never edits.
- **Tabs** (amended 2026-11-07): a tab is drawn to the next stop of four columns (true stops: mid-line too), in the editor and the read-only source alike; a fixed four, Go's and most editors' width, not a setting. Only the drawing changes: the text, the caret's offsets, copying and saving keep the tab. Flutter draws a tab as a space, so the tab's run gets the font size at which that space spans its columns, the line held to its height by a strut. Not letter spacing, the simpler way: Skia starts a line with half its first glyph's letter spacing, so a leading tab shifted the whole line and put the carets out of step with it. Show whitespace (an app preference, off at first) draws a dot for a space and an arrow for a tab over both views, where their paragraphs put each character (the editor's through the lines re_editor tells its line numbers); never in the text.
- **Read-only, with a one-line reason**: not text, not strict UTF-8, mixed line endings or a lone CR, over 1 MiB, more than one hard link, read-only (not the user's, or no write bit), not a regular file, or bytes that don't come back the same when decoded and encoded again. The editor never edits pretty-printed or cut text (a JSON file shows as it is).
- **Bytes kept**: a BOM, LF or CRLF (each as the current disk version has it) and the final newline are kept; pasted CR and CRLF become the file's ending.
- **Only the daemon writes** (`WriteChatFile`, API 108): where `WatchChatFile` would read the file, looked up at each save, a link followed only inside the folder, a regular file with one link that the user owns and may write, 1 MiB at most, and only while its sha256 is the one the app last read (or absent, with `must_not_exist`); otherwise Stale, with the file's bytes. Saves take turns, all of them. A device's channel is refused by the handler itself, not just `macOnly`.
- **When it saves**: ⌘S (File › Save), and when the focus leaves the editor for somewhere else that takes it (the prompt box, a terminal, another file or pane, another tab or chat, another app, quit), not for a menu, the palette, a dialog, find, or a selection in the transcript or preview. No timed autosave. Nothing saves in Conflict or Deleted.
- **Changes from disk** (the watch's sum moved): a clean editor takes the new text; one with unsaved edits merges by lines (base, edits, disk): apart, they're merged in, still unsaved, with a note (Merged a change from disk · Compare); overlapping, it's a conflict: an amber dot and a bar (Changed on disk: Compare, Overwrite with mine, which saves over the sum just shown, and Use theirs). A Stale save goes the same way. Undo history is cleared after any change from outside, so ⌘Z can't silently take the agent's work back; nothing outside is applied mid-composition. A watch message with the sum from before your save is ignored until one with any other sum comes or a new watch starts (after that the old sum is a real change, such as the agent reverting); a save's Stale reply is never ignored, so a revert the watch missed still reaches the merge. A file gone with unsaved edits gets a bar (Deleted on disk: Save, Discard).
- **Unsaved shows** as a dot in the tab's ✕ place (✕ on hover). Closing a tab, the pane, or quitting saves first; text that can't be saved is never dropped silently: Discard or Cancel is asked.
- **The agent is told**: the chats whose folders hold the file (and the chat it was saved from) get a note with their next prompt: "The user edited `a.go` in Nushi since your last turn; re-read it before changing it." In memory only.

## Consequences
- A clean merge still has to be looked at (Compare), but saving it gives what saving your own edits would have.
- Undo can't reach back past a change from disk.
- Unsaved text lives in the app's memory only: a crash loses it. Two chats' editors of one file are two buffers; the second to save merges or conflicts.
- A save renames a new file over the old: extended attributes and the inode go, and watchers see a rename. Between the daemon's check and the rename an agent's write can still be lost, as in VS Code.

## Alternatives considered
- An Edit button or mode: what the owner said no to.
- Saving on a timer: agents treat every save as a deliberate change; the focus rules and quit cover losing work.
- Conflict on any outside change: the agent editing other lines is the common case, and both exits of a two-way choice lose someone's work.
- The app writing the file itself: the daemon already decides what the preview may read, and the phone mustn't write.
- Backups of unsaved text on disk, saying who changed a file, approval-card lines: left for if it's used enough.
