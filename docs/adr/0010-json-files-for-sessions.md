# 0010. A JSON file per session until that stops being enough

## Context
Nushi stores very little ([0008](0008-chats-belong-to-the-agent.md)). The POC used two SQLite files with migrations from the start.

## Decision
Each session is a small JSON file in the daemon's data folder. Move to SQLite when a real query or write pattern needs it.

## Consequences
- Listing sessions reads every file; fine for hundreds of chats.

**Amendment (2026-11-22): a file that doesn't parse is set aside as it's read.** One rule for the daemon's small JSON files: a file that doesn't parse is moved beside itself as `<name>.unreadable-<time>`, logged, and read as the empty state, so a later write replaces nothing unread; a file whose only fault is a field of another shape (a newer build's, read going back, [0108](0108-beta-versions.md)) keeps its other fields; a file that can't be read at all is an error and is never written over. Until the owner decides what a bad phone key should do, `remote-key.json`, `devices.json` and `vapid.json` keep refusing such a file in place.
