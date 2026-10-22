# 0002. A separate Go daemon runs the agents; Flutter is the window

## Context
Agents run for minutes or hours. Quitting or updating the app must not kill them. The user prefers Go for the backend; the POC confirmed Flutter for a desktop UI with a custom diff painter.

## Decision
- `nushid`, a Go daemon, owns the agent processes and all logic. The Flutter app is a thin client over its API.
- Agents keep running when the app quits or updates; the app reconnects and picks the sessions back up.
- If the daemon itself restarts, it resumes each session through the agent's own resume (ACP `session/load`).

## Consequences
- The app must cope with a daemon that is older than itself (see [0004](0004-connect-over-unix-socket.md)).
- Anything the app shows after a reconnect (transcripts, waiting prompts) must be held or rebuildable by the daemon.

## Alternatives considered
- Agents as children of the app: simpler, but a quit or update kills every chat.
- Wails, GPUI/Rust or SwiftUI front ends (POC research): Flutter won the POC's spike.
