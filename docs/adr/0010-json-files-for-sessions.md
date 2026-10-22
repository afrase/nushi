# 0010. A JSON file per session until that stops being enough

## Context
Nushi stores very little ([0008](0008-chats-belong-to-the-agent.md)). The POC used two SQLite files with migrations from the start.

## Decision
Each session is a small JSON file in the daemon's data folder. Move to SQLite when a real query or write pattern needs it.

## Consequences
- Listing sessions reads every file; fine for hundreds of chats.
