# 0032. Idle chats sleep

## Context
Every chat that has been opened keeps its agent running until it is archived or the daemon stops. A Claude chat costs about 240 MB (its adapter and the `claude` CLI), so a day of chats leaves gigabytes idle ([docs/history/perf-2026-10.md](../history/perf-2026-10.md)).

## Decision
- A chat can sleep: its agent stops as for Archive, and the chat stays where it is with its transcript. Opening it doesn't wake it; a message, or anything else that needs the agent (a side chat, rewind, a picker, the context breakdown), reopens the session through `session/load`, as after a daemon restart.
- Chats sleep on their own once idle for a while (30 minutes by default; off, or another time, in Settings, kept by the daemon), but only when nothing is lost: no turn runs or waits on the user, nothing is queued, no background command or subagent runs, no side chat is open, and nothing moves, rewinds or reopens it. A chat open on screen sleeps too; its terminals stay (they are the daemon's).
- Only an agent that says it can load sessions (`loadSession`) sleeps; one that can't has no Sleep.
- Waking puts the options it had back (model, effort), since an agent may reopen a session on its defaults (Claude does).
- A chat whose reopen failed isn't asleep (amended after step 214): it says it couldn't start, and its one notice says why with what helps (Set up… for an agent not set up or installed, Move… for a folder that's gone, else Try again). Showing it (picking it, the app coming to the front) tries again, once a show, unless what stopped it still holds; an agent set up, or found ready by Settings › Agents, lets its chats that failed for that try again, each when it's next shown, never all at once in the background. The notice goes once the chat runs.

## Consequences
- The first message after a sleep waits for the agent to start and replay the session (about a second or two).
- A chat not opened since the daemon started counts as asleep.
- Background commands Claude started outlive it, as after Archive; a chat with one still running doesn't sleep on its own.
