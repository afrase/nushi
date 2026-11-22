# 0010. A JSON file per session until that stops being enough

## Context
Nushi stores very little ([0008](0008-chats-belong-to-the-agent.md)). The POC used two SQLite files with migrations from the start.

## Decision
Each session is a small JSON file in the daemon's data folder. Move to SQLite when a real query or write pattern needs it.

## Consequences
- Listing sessions reads every file; fine for hundreds of chats.

**Amendment (2026-11-22): a file that doesn't parse is set aside as it's read.** One rule for the daemon's small JSON files: a file that doesn't parse is moved beside itself as `<name>.unreadable-<time>`, logged, and read as the empty state, so a later write replaces nothing unread; a file whose only fault is a field of another shape (a newer build's, read going back, [0108](0108-beta-versions.md)) keeps its other fields; a file that can't be read at all is an error and is never written over. `remote-key.json`, `devices.json` and `vapid.json` are set aside too, and remote access starts over ([0034](0034-noise-between-phone-and-daemon.md)'s 2026-11-22 amendment). A session's file is never set aside (nothing writes over a chat that isn't listed): one that doesn't read is left as it is, and its id goes to the app as `ListChatsResponse.unreadable` (API 144), so the app never forgets that chat's draft, review comments or prefs.

**Amendment (2026-11-22, later): a value of another shape reads as not set.** A value whose type doesn't match (a newer build's) is taken out of the file's JSON at the decoder's path and the rest decoded again, so it reads as its default, never as the zero a decoder makes up (a `sleepAfterMinutes` of `"x"` is 30 minutes, not "never sleep"); the next write leaves it out. A file whose whole value is of another shape (an array where an object goes) counts as one that doesn't parse, and so does a chat's record of that kind, or one without the id its file is named for (null, `{}`, another chat's id): it's named unreadable, never listed as a chat whose saves go to another file.
